#!/usr/bin/env python3
"""eval_bag.py — rosbag 을 직접 읽어 부표 검출/플래너를 오프라인으로 돌려본다.

노드와 같은 core.py 를 쓰고, 이미지-라이다 짝짓기도 노드와 같은 방식(라이다 도착 시점의
가장 최근 이미지, 수신 시각 기준)으로 한다. usb_cam header stamp 는 exp1016 에서
수신 시각보다 ~0.69 s 앞서 있어 header 기준 동기화를 쓰면 안 된다.

사용:
    python3 eval_bag.py ~/rosbag_folder/exp1016 --config ../config/buoy_params.yaml \
        --start 0 --end 120 --out /tmp/buoy_eval [--video] [--every 10] [--calib new|old]

출력:
    <out>/frames.csv     프레임별 클러스터 수 / 색별 트랙 수 / 게이트 수 / 플래너 모드 / 명령
    <out>/overlay_XXXX.jpg (--every N 프레임마다) 이미지 오버레이 + BEV
    <out>/overlay.mp4    (--video)
"""
import argparse
import csv
import math
import os
import sys

import cv2
import numpy as np
import yaml

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from buoy_avoidance_pkg import core  # noqa: E402
from buoy_avoidance_pkg.viz import draw_overlay, draw_bev  # noqa: E402


def calib_path(name):
    if name.endswith('.yaml'):
        return name
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'config', f'calib_{name}.yaml')


def load_params(path, calib=None):
    with open(path) as f:
        prm = yaml.safe_load(f)['buoy_avoidance']['ros__parameters']
    if calib:
        with open(calib) as f:
            prm.update(yaml.safe_load(f)['buoy_avoidance']['ros__parameters'])
    return prm, prm


def nested(det):
    """노드 파라미터(평평한 dict) → core 함수가 쓰는 dict 들."""
    cp = {k: det[k] for k in core.DEFAULT_CLUSTER_PARAMS}
    col = {k: det[k] for k in core.DEFAULT_COLOR_PARAMS if k not in ('red_hsv_ranges', 'green_hsv_ranges')}
    col['red_hsv_ranges'] = np.array(det['red_hsv_flat']).reshape(-1, 2, 3).tolist()
    col['green_hsv_ranges'] = np.array(det['green_hsv_flat']).reshape(-1, 2, 3).tolist()
    tp = {k: det[k] for k in core.DEFAULT_TRACKER_PARAMS}
    cam = dict(fx=det['cam_fx'], fy=det['cam_fy'], cx=det['cam_cx'], cy=det['cam_cy'],
               dist=det['cam_dist'], rvec_correction=det['cam_rvec_correction'],
               tvec=det['cam_tvec'], width=det['cam_width'], height=det['cam_height'],
               valid_radius_px=det['cam_valid_radius_px'])
    return cp, col, tp, cam


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('bag')
    ap.add_argument('--config', default=os.path.join(os.path.dirname(__file__), '..', 'config', 'buoy_params.yaml'))
    ap.add_argument('--calib', default='new',
                    help='카메라 보정: new | old (config/calib_<이름>.yaml) 또는 yaml 경로')
    ap.add_argument('--start', type=float, default=0.0)
    ap.add_argument('--end', type=float, default=1e9)
    ap.add_argument('--out', default='/tmp/buoy_eval')
    ap.add_argument('--every', type=int, default=0, help='N 프레임마다 오버레이 jpg 저장 (0=안 함)')
    ap.add_argument('--video', action='store_true')
    ap.add_argument('--lidar-topic', default='/livox/lidar')
    ap.add_argument('--image-topic', default='/image_raw')
    ap.add_argument('--no-pose', action='store_true',
                    help='/usv/state/{position_ned,heading} 를 플래너에 넘기지 않음 (통과 기억 끔)')
    a = ap.parse_args()

    import rosbag2_py
    from rclpy.serialization import deserialize_message
    from sensor_msgs.msg import Image, PointCloud2
    from geometry_msgs.msg import Point
    from std_msgs.msg import Float32
    from buoy_avoidance_pkg.ros_conv import image_to_bgr, cloud_to_xyz

    det, pln = load_params(a.config, calib_path(a.calib))
    cp, col, tp, camp = nested(det)
    pp = {k: pln[k] for k in core.DEFAULT_PLANNER_PARAMS}
    camera = core.FisheyeCamera.from_params(camp)
    tracker = core.BuoyTracker(tp)
    planner = core.GatePlanner(pp)

    os.makedirs(a.out, exist_ok=True)
    reader = rosbag2_py.SequentialReader()
    reader.open(rosbag2_py.StorageOptions(uri=a.bag, storage_id='sqlite3'),
                rosbag2_py.ConverterOptions('cdr', 'cdr'))
    pose_topics = [] if a.no_pose else ['/usv/state/position_ned', '/usv/state/heading']
    reader.set_filter(rosbag2_py.StorageFilter(topics=[a.lidar_topic, a.image_topic] + pose_topics))
    pos = hdg = None
    pos_t = hdg_t = -1e9

    t0 = None
    last_img = None
    last_img_t = None
    rows = []
    writer = None
    k = 0
    while reader.has_next():
        topic, data, t_ns = reader.read_next()
        if t0 is None:
            t0 = t_ns
        s = (t_ns - t0) / 1e9
        if s > a.end:
            break
        if topic == a.image_topic:
            if s >= a.start - 1.0:
                last_img = deserialize_message(data, Image)
                last_img_t = s
            continue
        if topic == '/usv/state/position_ned':
            m = deserialize_message(data, Point)
            pos, pos_t = (m.x, m.y), s
            continue
        if topic == '/usv/state/heading':
            hdg, hdg_t = deserialize_message(data, Float32).data, s
            continue
        if s < a.start:
            continue
        cloud = cloud_to_xyz(deserialize_message(data, PointCloud2))
        bgr = None
        if last_img is not None and s - last_img_t <= det['max_image_age_sec']:
            bgr = image_to_bgr(last_img)
        clusters = core.extract_buoy_clusters(cloud, cp)
        cls = core.classify_clusters(bgr, clusters, camera, col)
        labels = [c[0] for c in cls]
        tracker.update(clusters, labels, s)
        tracks = tracker.confirmed()
        buoys = [(x, y, c) for _, x, y, c, _ in tracks]
        pose = None
        if pos is not None and hdg is not None and s - pos_t <= 0.5 and s - hdg_t <= 0.5:
            pose = (pos[0], pos[1], float(hdg))
        out = planner.plan(buoys, s, pose)

        n_r = sum(1 for b in buoys if b[2] == core.RED)
        n_g = sum(1 for b in buoys if b[2] == core.GREEN)
        rows.append(dict(k=k, t=round(s, 3), clusters=len(clusters),
                         det_red=labels.count(core.RED), det_green=labels.count(core.GREEN),
                         det_unknown=labels.count(core.UNKNOWN),
                         trk_red=n_r, trk_green=n_g, trk_unknown=len(buoys) - n_r - n_g,
                         gates=len(out['gates']),
                         gate_widths=';'.join(f"{g[4]:.2f}" for g in out['gates']),
                         mode=out['mode'], red_left=out['red_left'], passed=out['n_passed'],
                         pose=pose is not None,
                         speed=round(out['speed'], 3), bearing_deg=round(math.degrees(out['bearing']), 2)))

        want_img = (a.every and k % a.every == 0) or a.video
        if want_img and bgr is not None:
            ov = draw_overlay(bgr, clusters, cls, camera, out)
            bev = draw_bev(tracks, out, size=480, half_range=12.0)
            frame = np.hstack([ov, bev])
            cv2.putText(frame, f't={s:6.1f}s  mode={out["mode"]}', (8, 470), 0, 0.6, (0, 255, 255), 2)
            if a.every and k % a.every == 0:
                cv2.imwrite(os.path.join(a.out, f'overlay_{k:05d}.jpg'), frame)
            if a.video:
                if writer is None:
                    writer = cv2.VideoWriter(os.path.join(a.out, 'overlay.mp4'),
                                             cv2.VideoWriter_fourcc(*'mp4v'), 10, (frame.shape[1], frame.shape[0]))
                writer.write(frame)
        k += 1

    if writer is not None:
        writer.release()
    with open(os.path.join(a.out, 'frames.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    modes = {}
    for r in rows:
        modes[r['mode']] = modes.get(r['mode'], 0) + 1
    print(f'{len(rows)} frames  modes={modes}')
    print(f"det colors: red={sum(r['det_red'] for r in rows)} green={sum(r['det_green'] for r in rows)} "
          f"unknown={sum(r['det_unknown'] for r in rows)}")


if __name__ == '__main__':
    main()
