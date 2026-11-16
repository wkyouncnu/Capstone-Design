#!/usr/bin/env python3
# see_obstacle_cloud.py — 장애물회피 : 라이다에 장애물 점이 나오는지 확인한다
#
#   bash goto.sh obs_gate                              # 가상경계선 진입구
#   python3 see_obstacle_cloud.py --out /tmp/obs_gate.png
#   bash goto.sh obs_front                             # 장애물 지대 맨 앞
#   python3 see_obstacle_cloud.py --out /tmp/obs_front.png
#
#   확인하는 것 (요구조건 문서 4-5 의 출발점)
#     1) 장애물 기둥이 점으로 돌아온다 — 몇 개, 어느 거리에
#     2) 각도 칸마다 "가장 가까운 거리" 표가 만들어진다
#     3) 그 표에서 빈 방향(지나갈 수 있는 틈)이 보인다
#
#   하지 않는 것
#     회피 경로를 만드는 일. VFH·APF·DWA 는 9주차에서 다룬 것이고,
#     텀프로젝트에서는 팀이 고른 방법을 Simulink·Stateflow 쪽에 붙인다.
#     이 스크립트가 내주는 "각도별 최근접 거리" 가 그 입력이다.
#
#   가상경계선 (규정 : 벗어나면 실격)
#     kaboat_term.sdf 의 virtual_boundary 는 **visual 만** 있다 — 라이다에도
#     안 잡히고 부딪히지도 않는다. 눈으로 경계를 보여 주는 표시일 뿐이다.
#     즉 경계 이탈 판정은 센서가 아니라 GPS 좌표로 한다 (동 -594 ~ -560, 북 181 ~ 211).
#     이 스크립트가 경계선을 못 보는 것이 정상이다.
#
#   장애물 (9주차 월드의 기둥 12개를 그대로 쓴다)
#     동 -588 ~ -564, 북 186 ~ 206. 지름 약 1 m, 수면 위 약 1 m.
#     높이가 1 m 라 h/0.049 = 약 20 m 까지 보인다 (see_dock_cloud.py 머리말의 계산).

import argparse

import numpy as np

import tp_percep as tp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_obstacle.png')
    ap.add_argument('--range', type=float, default=40.0, help='앞쪽 몇 m 까지 볼지')
    ap.add_argument('--fov', type=float, default=60.0, help='좌우 반각[deg]')
    ap.add_argument('--z-min', type=float, default=0.2,
                    help='수면 기준 이 높이 위만 본다 (물결 반사를 뺀다)')
    ap.add_argument('--gap', type=float, default=5.0,
                    help='이 거리보다 멀면 "열린 방향" 으로 본다')
    a = ap.parse_args()

    xyz, frame = tp.grab_cloud()
    print('포인트클라우드 : %d 점,  좌표계 %s' % (len(xyz), frame))

    front = tp.front_slab(xyz, x_max=a.range, half_fov_deg=a.fov,
                          z_min=a.z_min - 1.9, z_max=4.0)
    print('앞쪽 %.0f m · 좌우 %.0f deg · 수면 위 %.1f m 만 남기면 : %d 점'
          % (a.range, a.fov, a.z_min, len(front)))

    if len(front) == 0:
        print()
        print('점이 하나도 없다. 앞이 완전히 비어 있거나 자세가 빗나갔다.')
        print('  bash goto.sh obs_front 로 장애물 지대 앞에 세운다')
        tp.save_cloud_png(front, a.out, 'obstacles: no returns', a.range)
        return

    bins = tp.bin_nearest(front, half_fov_deg=a.fov, step_deg=5.0)
    print()
    print('각도 칸(5 deg)마다 가장 가까운 거리 — 좌현에서 우현 순')
    print('%10s %10s %8s %s' % ('방위[deg]', '거리[m]', '점수', '막힘'))
    for ang, rng, n in sorted(bins, key=lambda t: t[0]):
        bar = '#' * max(1, int(round(20 - rng / 2))) if rng < a.gap else ''
        print('%10.1f %10.2f %8d %s' % (ang, rng, n, bar))

    #  장애물을 "덩어리" 로 세어 본다 — 거리가 비슷하고 각도가 이어진 점끼리 묶는다.
    #  정식 군집화(DBSCAN 등)가 아니다. "몇 개쯤 있는지" 만 가늠하는 눈금이다.
    rng = np.hypot(front[:, 0], front[:, 1])
    ang = np.degrees(np.arctan2(front[:, 1], front[:, 0]))
    order = np.argsort(ang)
    rng, ang = rng[order], ang[order]
    clusters, cur = [], [0]
    for i in range(1, len(ang)):
        if abs(ang[i] - ang[i - 1]) < 2.0 and abs(rng[i] - rng[i - 1]) < 1.5:
            cur.append(i)
        else:
            clusters.append(cur)
            cur = [i]
    clusters.append(cur)
    clusters = [c for c in clusters if len(c) >= 3]

    print()
    print('이어진 덩어리 %d 개 (점 3개 이상) — 장애물 후보다' % len(clusters))
    print('%6s %10s %12s %8s' % ('번호', '거리[m]', '방위[deg]', '점수'))
    for i, c in enumerate(sorted(clusters, key=lambda c: rng[c].min())[:10]):
        print('%6d %10.2f %+12.1f %8d' % (i + 1, rng[c].min(), ang[c].mean(), len(c)))

    near = [t for t in bins if t[1] < a.gap]
    open_dirs = [t[0] for t in bins if t[1] >= a.gap]
    print()
    print('가장 가까운 장애물 : %.2f m,  방위 %+.1f deg' % (bins[0][1], bins[0][0]))
    print('%.0f m 안에 뭔가 있는 칸 : %d 개 / 전체 %d 칸'
          % (a.gap, len(near), len(bins)))
    if open_dirs:
        print('열린 방향(%.0f m 밖까지 비어 있음) : %s'
              % (a.gap, ', '.join('%+.0f' % d for d in open_dirs[:12])))
        print('  -> 회피 알고리즘이 고를 후보 방향이다. 고르는 일은 팀 몫이다.')
    else:
        print('열린 칸이 없다. 더 뒤로 물러나거나 --gap 을 키운다.')

    print()
    print('** 라이다로 장애물이 검출된다는 것이 확인되었다 **')

    tp.save_cloud_png(front, a.out,
                      'obstacles from lidar (%d pts, %d clusters, nearest %.1f m)'
                      % (len(front), len(clusters), bins[0][1]),
                      a.range)
    print('RViz2 로 같은 것을 보려면 :  bash rviz_term.sh')


if __name__ == '__main__':
    main()
