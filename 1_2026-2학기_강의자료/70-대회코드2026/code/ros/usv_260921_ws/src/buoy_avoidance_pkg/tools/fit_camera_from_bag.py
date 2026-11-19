#!/usr/bin/env python3
"""fit_camera_from_bag.py — 부표 bag 으로 어안 카메라 내부/외부 파라미터를 다시 맞춘다.

체커보드 없이, 수면 위 빨강/초록 구형 부표를 타깃으로 쓴다:
    라이다 클러스터 중심(3D) ↔ 같은 시점 이미지의 색 블롭 중심(2D) 대응점을 모아
    cv2.fisheye 투영 오차를 최소화한다 (초기값 = 현재 config).
    대응점은 "투영 위치에서 gate_px 이내의 상호 최근접 블롭"으로 고르고, 매 반복마다
    오차 상위 15% 를 버려 오대응을 걸러낸다.

exp1016 결과: 대응점 ~2,300쌍, 중앙 오차 4.7 px / p90 9 px.
초기값이 너무 틀어져 있으면(블롭과 30 px 이상 어긋남) 수렴하지 않으니,
먼저 eval_bag.py 오버레이로 대략 맞는지 본 뒤 쓸 것.

사용:
    python3 fit_camera_from_bag.py ~/rosbag_folder/exp1016 --start 0 --end 120
    python3 fit_camera_from_bag.py <bag1> <bag2> ... --calib new --extrinsic-only
      (bag 여러 개: 대응점을 합쳐 한 번에 맞춘다. --start/--end 는 각 bag 에 똑같이 적용)
    → 마지막에 config/buoy_params.yaml 에 붙여넣을 cam_* 값을 출력한다.

장착만 바뀐 경우(렌즈 동일)엔 내부 파라미터를 고정하고 외부만 맞추는 게 안정적이다:
    python3 fit_camera_from_bag.py <bag> --start 14 --extrinsic-only --gate-px 40 30 20 15 10 10
    (2026-11-02 bag: 내부까지 풀면 fx 가 229~237 로 흔들렸음. 원거리 부표만으론 tvec x 와 yaw 가
     잘 안 갈리니, 구간을 나눠 돌려 값이 일관된지 확인할 것.)
"""
import argparse
import os
import sys

import cv2
import numpy as np
import yaml
from scipy.optimize import least_squares

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from buoy_avoidance_pkg import core  # noqa: E402


def image_blobs(bgr, color_p, v_band):
    """색 마스크 연결 성분 중심 [(u, v)]. 수평선 부근 v_band 안의 것만."""
    masks = core.color_masks(cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV), color_p)
    out = []
    for m in masks.values():
        m[:v_band[0]] = 0
        m[v_band[1]:] = 0
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        n, _, st, cen = cv2.connectedComponentsWithStats(m)
        for i in range(1, n):
            if st[i, cv2.CC_STAT_AREA] >= 25 and st[i, cv2.CC_STAT_WIDTH] <= 140:
                out.append(cen[i])
    return np.array(out).reshape(-1, 2)


def unpack(x, w, h):
    return core.FisheyeCamera(x[6], x[6], x[7], x[8], [x[9], x[10], 0.0, 0.0], x[0:3], x[3:6], w, h, 1e9)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('bags', nargs='+', help='bag 폴더 (여러 개면 대응점을 합쳐서 한 번에 맞춤)')
    ap.add_argument('--config', default=os.path.join(os.path.dirname(__file__), '..', 'config', 'buoy_params.yaml'))
    ap.add_argument('--calib', default='new',
                    help='초기값으로 쓸 카메라 보정: new | old (config/calib_<이름>.yaml) 또는 yaml 경로')
    ap.add_argument('--start', type=float, default=0.0)
    ap.add_argument('--end', type=float, default=1e9)
    ap.add_argument('--gate-px', type=float, nargs='+', default=[10.0],
                    help='반복마다 쓸 대응 게이트(px). 여러 개 주면 굵게→가늘게 (예: 40 20 10)')
    ap.add_argument('--extrinsic-only', action='store_true',
                    help='내부 파라미터(f, cx, cy, dist)는 config 값으로 고정하고 rvec/tvec 만 맞춤')
    ap.add_argument('--rotation-only', action='store_true',
                    help='tvec 까지 config 값으로 고정하고 rvec 만 맞춤 (원거리 부표만으론 tvec 이 회전과 잘 안 갈림)')
    ap.add_argument('--v-band', type=int, nargs=2, default=[150, 330], help='블롭을 찾을 이미지 행 범위')
    ap.add_argument('--lidar-topic', default='/livox/lidar')
    ap.add_argument('--image-topic', default='/image_raw')
    a = ap.parse_args()

    import rosbag2_py
    from rclpy.serialization import deserialize_message
    from sensor_msgs.msg import Image, PointCloud2
    from buoy_avoidance_pkg.ros_conv import cloud_to_xyz, image_to_bgr

    prm = yaml.safe_load(open(a.config))['buoy_avoidance']['ros__parameters']
    calib = a.calib if a.calib.endswith('.yaml') else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), '..', 'config', f'calib_{a.calib}.yaml')
    prm.update(yaml.safe_load(open(calib))['buoy_avoidance']['ros__parameters'])
    print(f'초기값: {os.path.normpath(calib)}')
    cp = {k: prm[k] for k in core.DEFAULT_CLUSTER_PARAMS}
    col = {'red_hsv_ranges': np.array(prm['red_hsv_flat']).reshape(-1, 2, 3).tolist(),
           'green_hsv_ranges': np.array(prm['green_hsv_flat']).reshape(-1, 2, 3).tolist()}
    W, H = prm['cam_width'], prm['cam_height']
    x = np.array(list(prm['cam_rvec_correction']) + list(prm['cam_tvec'])
                 + [0.5 * (prm['cam_fx'] + prm['cam_fy']), prm['cam_cx'], prm['cam_cy']]
                 + list(prm['cam_dist'][:2]), dtype=float)

    # ── 라이다 프레임마다 (클러스터, 직전 이미지 블롭) 수집 ──
    frames = []
    for bag in a.bags:
        reader = rosbag2_py.SequentialReader()
        reader.open(rosbag2_py.StorageOptions(uri=os.path.expanduser(bag), storage_id='sqlite3'),
                    rosbag2_py.ConverterOptions('cdr', 'cdr'))
        reader.set_filter(rosbag2_py.StorageFilter(topics=[a.lidar_topic, a.image_topic]))
        n0 = len(frames)
        t0 = None
        last_img = None
        while reader.has_next():
            topic, data, t_ns = reader.read_next()
            t0 = t_ns if t0 is None else t0
            s = (t_ns - t0) / 1e9
            if s > a.end:
                break
            if topic == a.image_topic:
                last_img = data
                continue
            if s < a.start or last_img is None:
                continue
            cl = core.extract_buoy_clusters(cloud_to_xyz(deserialize_message(data, PointCloud2)), cp)
            cl = cl[cl[:, 0] > 0.3]
            if len(cl) == 0:
                continue
            bl = image_blobs(image_to_bgr(deserialize_message(last_img, Image)), col, a.v_band)
            if len(bl):
                frames.append((np.ascontiguousarray(cl[:, :3]), bl))
        print(f'{os.path.basename(os.path.normpath(bag))}: {len(frames) - n0} frames')
    print(f'{len(frames)} frames with clusters and blobs')

    def correspondences(x, gate_px):
        cam = unpack(x, W, H)
        P, U = [], []
        for cl, bl in frames:
            uv, _ = cam.project(cl)
            d = np.linalg.norm(uv[:, None] - bl[None], axis=2)
            for i in range(len(cl)):
                j = int(np.argmin(d[i]))
                if d[i, j] < gate_px and int(np.argmin(d[:, j])) == i:
                    P.append(cl[i])
                    U.append(bl[j])
        return np.array(P), np.array(U)

    nfree = 3 if a.rotation_only else 6 if a.extrinsic_only else len(x)

    def residual(z, P, U):
        uv, _ = unpack(np.concatenate([z, x[nfree:]]), W, H).project(P)
        return (uv - U).ravel()

    gates = a.gate_px if len(a.gate_px) > 1 else a.gate_px * 4
    for it, gate in enumerate(gates):
        P, U = correspondences(x, gate)
        if len(P) < 30:
            print(f'대응점 {len(P)}개 — 너무 적음. 초기값(config)이 많이 틀어졌거나 부표 구간이 아님.')
            return
        e = np.linalg.norm(residual(x[:nfree], P, U).reshape(-1, 2), axis=1)
        keep = e < np.percentile(e, 85)
        x[:nfree] = least_squares(residual, x[:nfree], args=(P[keep], U[keep]), x_scale='jac').x
        e2 = np.linalg.norm(residual(x[:nfree], P[keep], U[keep]).reshape(-1, 2), axis=1)
        print(f'iter {it} (gate {gate:g}px): {len(P)} pairs, before med {np.median(e):.2f}px → after med {np.median(e2):.2f}px '
              f'(p90 {np.percentile(e2, 90):.2f}px)')

    print('\n# config/calib_<이름>.yaml 에 붙여넣기')
    print(f'    cam_fx: {x[6]:.2f}\n    cam_fy: {x[6]:.2f}\n    cam_cx: {x[7]:.2f}\n    cam_cy: {x[8]:.2f}')
    print(f'    cam_dist: [{x[9]:.4f}, {x[10]:.4f}, 0.0, 0.0]')
    print(f'    cam_rvec_correction: [{x[0]:.4f}, {x[1]:.4f}, {x[2]:.4f}]')
    print(f'    cam_tvec: [{x[3]:.3f}, {x[4]:.3f}, {x[5]:.3f}]')


if __name__ == '__main__':
    main()
