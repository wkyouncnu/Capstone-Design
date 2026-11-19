#!/usr/bin/env python3
"""tune_bays.py — 대회 기둥기반 베이 검출(bay_core.find_bays_pillars)을
저장한 점군(.npz)에 돌려 해양누리 스케일 파라미터를 고른다 (오프라인)

왜 포켓 방식이 아니라 기둥 방식인가
  · 포켓 방식(find_bays_pocket)은 '안쪽으로 들어간 구간' 을 베이로 본다.
    WP1 에서 보면 격벽(돌출 7.3 m)이 양옆 베이의 안쪽벽을 가려 NaN 구간이
    생기고, 베이 중심이 가린 만큼 밀린다 (실측 1.4~1.6 m).
  · 기둥 방식(find_bays_pillars)은 '가장 잘 찍히는 면' 인 격벽을 검출의
    주체로 삼고, 인접 격벽 사이 간격을 베이로 본다. 안쪽 점이 비어도
    양옆 격벽만 있으면 잡힌다 — 대회 코드의 주석이 바로 이 상황을 적고 있다.
  · 두 함수 모두 대회 bay_core.py 원본 그대로이며 여기서는 호출만 한다.

실행
  python3 tune_bays.py /tmp/dock_wp1.npz
  python3 tune_bays.py /tmp/dock_wp1.npz --bin-w 0.3 --pillar-tol 0.6 --prof
"""
import argparse
import math

import numpy as np

from pc2_util import remove_ground_to_2d
from bay_core import rectify, wall_band_filter, find_bays_pillars


def main():
    ap = argparse.ArgumentParser()
    # ROI · 지면제거 (대회 노드 roi.* / ground.* 와 같은 역할)
    ap.add_argument('npz')
    ap.add_argument('--x-min', type=float, default=5.0)
    ap.add_argument('--x-max', type=float, default=30.0)
    ap.add_argument('--y-abs', type=float, default=20.0)
    ap.add_argument('--z-min', type=float, default=-1.8)
    ap.add_argument('--z-max', type=float, default=2.5)
    ap.add_argument('--cell', type=float, default=0.30)
    ap.add_argument('--z-wall-min', type=float, default=-1.0)
    # 기둥 검출 (대회 bay.* 와 같은 역할, 값만 해양누리 스케일)
    ap.add_argument('--band-depth', type=float, default=9.0)   # 대회 0.7
    ap.add_argument('--bin-w', type=float, default=0.30)       # 대회 0.10
    ap.add_argument('--min-pts', type=int, default=3)
    ap.add_argument('--depth-min', type=float, default=3.0)    # 대회 0.35
    ap.add_argument('--w-min', type=float, default=5.0)        # 대회 0.55
    ap.add_argument('--w-max', type=float, default=11.0)       # 대회 1.80
    ap.add_argument('--approach', type=float, default=6.0)     # 대회 0.80
    ap.add_argument('--pillar-tol', type=float, default=0.60)  # 대회 0.18
    ap.add_argument('--pillar-wmin', type=float, default=0.20) # 대회 0.08
    ap.add_argument('--bridge', type=int, default=1)
    ap.add_argument('--lidar-fwd', type=float, default=0.70)  # 라이다 - base_link 전방 오프셋
    ap.add_argument('--prof', action='store_true')
    a = ap.parse_args()

    z = np.load(a.npz, allow_pickle=True)
    P3 = z['points']; north, east, yaw = z['pose']

    P = remove_ground_to_2d(P3, a.z_min, a.z_max, a.x_min, a.x_max,
                            a.y_abs, a.cell, a.z_wall_min)
    print(f'원본 {len(P3)} 점 -> ROI+지면제거 {len(P)} 점')
    if len(P) < 30:
        return

    # ── find_bays_auto 와 같은 순서: 정렬 -> 벽밴드 -> 재정렬
    rp, c, theta = rectify(P)
    keep = wall_band_filter(rp, a.bin_w, a.band_depth)
    print(f'벽밴드({a.band_depth} m) : {keep.sum()} / {len(rp)} 점 남음')
    if keep.sum() >= a.min_pts * 3:
        P = P[keep]
    rp, c, theta = rectify(P)
    print(f'정렬 : theta {math.degrees(theta):+.2f} 도  중심 ({c[0]:+.2f},{c[1]:+.2f})  '
          f'x {rp[:,0].min():.2f}~{rp[:,0].max():.2f}  y {rp[:,1].min():.2f}~{rp[:,1].max():.2f}')

    y_lo = float(rp[:, 1].min()) - a.bin_w
    y_hi = float(rp[:, 1].max()) + a.bin_w
    bays, prof = find_bays_pillars(rp, y_lo, y_hi, a.bin_w, a.min_pts,
                                   a.depth_min, a.w_min, a.w_max, a.approach,
                                   pillar_tol=a.pillar_tol,
                                   pillar_width_min=a.pillar_wmin,
                                   bridge_bins=a.bridge)
    ys, xs = prof
    if len(xs):
        from bay_core import robust_pillar_baseline
        px = robust_pillar_baseline(xs)
        print(f'프로파일 {len(ys)} 칸  기둥기준 x {px:.2f} m  '
              f'기둥판정 |x-{px:.2f}|<={a.pillar_tol}  '
              f'깊음판정 x>={px + a.depth_min:.2f}')
        if a.prof:
            for yy, xx in zip(ys, xs):
                tag = '기둥' if abs(xx - px) <= a.pillar_tol else (
                      '안쪽' if xx >= px + a.depth_min else '')
                print(f'   y={yy:+7.2f}  x={xx:7.2f}  {tag}')

    # 원좌표(선체계) 복원 — find_bays_auto 와 동일
    Rinv = np.array([[np.cos(-theta), -np.sin(-theta)],
                     [np.sin(-theta),  np.cos(-theta)]])
    for b in bays:
        b['idx'] = (b['idx'] - c) @ Rinv.T + c
        b['wp'] = (b['wp'] - c) @ Rinv.T + c
        b['psi'] = float(b['psi'] - theta)

    print(f'\n베이 {len(bays)} 개   (선체 : 북 {north:+.2f} 동 {east:+.2f}, '
          f'헤딩 ENU {math.degrees(yaw):+.1f} 도)')
    cy, sy = math.cos(yaw), math.sin(yaw)
    # 점군은 라이다 좌표계, pose 는 base_link — 전방 오프셋 0.70 m 를 더한다
    e0 = east + a.lidar_fwd * cy
    n0 = north + a.lidar_fwd * sy
    TRUE_E = [-8.6, 0.0, 8.6]     # 생성기 BAYS : 서 네모 / 가운데 동그라미 / 동 세모
    TRUE_N = 22.5 + 7.0           # 뒷벽 남쪽 면 = DOCK_Y_IN + BAY_D
    for i, b in enumerate(bays):
        ix, iy = b['idx']; wx, wy = b['wp']
        e_i = e0 + ix * cy - iy * sy;  n_i = n0 + ix * sy + iy * cy
        e_w = e0 + wx * cy - wy * sy;  n_w = n0 + wx * sy + wy * cy
        open_enu = yaw + b['psi'] + math.pi          # 개구부가 향하는 방향(ENU)
        az = (90.0 - math.degrees(open_enu)) % 360.0  # 북기준 시계방향 방위각
        flag = ' (추론)' if b.get('inferred') else ' (실측)'
        print(f"  bay{i}: 폭 {b['width']:.2f} m{flag}")
        print(f"     안쪽벽 중앙  북 {n_i:+6.2f} 동 {e_i:+6.2f}   "
              f"WP1 기준 dN {n_i-10.0:+6.2f} dE {e_i:+6.2f}")
        print(f"     접근점      북 {n_w:+6.2f} 동 {e_w:+6.2f}   개구부 방위 {az:5.1f} 도")
        if i < 3:
            print(f"     참값오차     북 {n_i-TRUE_N:+5.2f} 동 {e_i-TRUE_E[i]:+5.2f} "
                  f"폭 {b['width']-8.0:+5.2f} "
                  f"방위 {((az-180.0+180)%360)-180:+5.1f} 도")


if __name__ == '__main__':
    main()
