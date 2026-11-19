#!/usr/bin/env python3
"""tune_pocket.py — 저장한 점군(.npz)에 포켓 검출을 돌려 파라미터를 고른다 (오프라인)

실행
  python3 tune_pocket.py /tmp/dock_wp1.npz
  python3 tune_pocket.py /tmp/dock_wp1.npz --bin-w 0.3 --front-cut 3.0 --prof
"""
import argparse
import math

import numpy as np

from pc2_util import remove_ground_to_2d
from pocket_core import PocketPar, find_bays_pocket, profile_debug
from bay_core import voxel_downsample


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('npz')
    ap.add_argument('--x-min', type=float, default=5.0)
    ap.add_argument('--x-max', type=float, default=30.0)
    ap.add_argument('--y-abs', type=float, default=20.0)
    ap.add_argument('--z-min', type=float, default=-1.8)
    ap.add_argument('--z-max', type=float, default=2.5)
    ap.add_argument('--cell', type=float, default=0.30)
    ap.add_argument('--z-wall-min', type=float, default=-1.0)
    ap.add_argument('--voxel', type=float, default=0.20)
    ap.add_argument('--wall-thr', type=float, default=0.30)
    ap.add_argument('--bin-w', type=float, default=0.40)
    ap.add_argument('--depth-min', type=float, default=2.0)
    ap.add_argument('--w-min', type=float, default=5.0)
    ap.add_argument('--w-max', type=float, default=11.0)
    ap.add_argument('--approach', type=float, default=6.0)
    ap.add_argument('--front-cut', type=float, default=3.0)
    ap.add_argument('--seed', type=int, default=0)
    ap.add_argument('--prof', action='store_true')
    a = ap.parse_args()

    z = np.load(a.npz, allow_pickle=True)
    P3 = z['points']; north, east, yaw = z['pose']

    det = remove_ground_to_2d(P3, a.z_min, a.z_max, a.x_min, a.x_max,
                              a.y_abs, a.cell, a.z_wall_min)
    print(f'원본 {len(P3)} 점 -> ROI+지면제거 {len(det)} 점')
    det = voxel_downsample(det, a.voxel) if a.voxel > 0 else det
    print(f'복셀 {a.voxel} m -> {len(det)} 점')
    if len(det) == 0:
        return

    par = PocketPar(wall_thr=a.wall_thr, bin_w=a.bin_w,
                    pocket_depth_min=a.depth_min, bay_w_min=a.w_min,
                    bay_w_max=a.w_max, approach_dist=a.approach,
                    front_cut=a.front_cut)
    rng = np.random.default_rng(a.seed)
    dbg = profile_debug(det, par, np.random.default_rng(a.seed))
    print(f"벽 RANSAC : 먼 점 {dbg['far_n']} / 인라이어 {dbg['inl_n']}  "
          f"방향 v=({dbg['v_hat'][0]:+.3f},{dbg['v_hat'][1]:+.3f}) "
          f"법선 n=({dbg['n_hat'][0]:+.3f},{dbg['n_hat'][1]:+.3f})  "
          f"p0=({dbg['p0'][0]:+.2f},{dbg['p0'][1]:+.2f})")
    pr = dbg['prof']; okb = ~np.isnan(pr)
    if okb.sum():
        tip = np.nanpercentile(pr, 90); base = np.nanpercentile(pr, 10)
        print(f"프로파일 : 칸 {len(pr)} 개 (유효 {okb.sum()})  "
              f"base {base:.2f} / tip {tip:.2f} / depth {tip-base:.2f} m  "
              f"임계 {base+(tip-base)*0.5:.2f}")
    if a.prof:
        for k, (b, p) in enumerate(zip(dbg['bins'], pr)):
            mark = '' if np.isnan(p) else ('포켓' if p < base + (tip-base)*0.5 else '격벽')
            print(f'   k{k:3d}  s={b:+7.2f}  prof={p:7.2f}  {mark}')

    bays = find_bays_pocket(det, par, rng)
    print(f'\n베이 {len(bays)} 개')
    cy, sy = math.cos(yaw), math.sin(yaw)
    for i, b in enumerate(bays):
        ix, iy = b['idx']; wx, wy = b['wp']
        # 라이다(선체) 좌표 -> 월드 ENU : x 전방, y 좌현, 헤딩 yaw(ENU)
        e_i = east + ix * cy - iy * sy
        n_i = north + ix * sy + iy * cy
        e_w = east + wx * cy - wy * sy
        n_w = north + wx * sy + wy * cy
        psi_world = yaw + b['psi']       # 벽 법선(안쪽) 방향, ENU
        # 개구부가 향하는 방위 = 법선의 반대. 방위각은 북 기준 시계방향
        open_enu = psi_world + math.pi
        az = (90.0 - math.degrees(open_enu)) % 360.0
        print(f"  bay{i}: 폭 {b['width']:.2f} m  선체계 idx=({ix:+.2f},{iy:+.2f}) "
              f"wp=({wx:+.2f},{wy:+.2f})")
        print(f"         월드 안쪽벽 중앙 북 {n_i:+.2f} 동 {e_i:+.2f} / "
              f"접근점 북 {n_w:+.2f} 동 {e_w:+.2f} / 개구부 방위 {az:.1f} 도")
        print(f"         WP1(북10,동0) 기준  dN {n_i-10.0:+.2f}  dE {e_i-0.0:+.2f} m")


if __name__ == '__main__':
    main()
