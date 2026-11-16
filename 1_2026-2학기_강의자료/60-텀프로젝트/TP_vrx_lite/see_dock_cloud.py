#!/usr/bin/env python3
# see_dock_cloud.py — 도킹 : 라이다 포인트클라우드로 도킹 스테이션을 찾는다
#
#   bash goto.sh dock                                  # 베이 앞 12 m
#   python3 see_dock_cloud.py --out /tmp/dock_cloud.png
#
#   확인하는 것 (요구조건 문서 4-3 의 출발점)
#     1) 벽 높이 2.0 m 가 라이다에 잡히기에 충분한지 — 점이 몇 개 돌아오는지
#     2) 뒷벽과 칸막이가 거리·각도 그림에서 ⊔ 꼴로 보이는지
#     3) 빈 베이 셋의 방향이 숫자로 나오는지 (들어갈 베이를 고르는 데 쓰는 값)
#
#   하지 않는 것 : 접근 경로 생성, 크래빙, 접안. Simulink·Stateflow 몫이다.
#
#   벽 높이가 2.0 m 여야 하는 까닭 (실측값, vrx_llm_dock 에서 잰 것)
#     라이다는 세로 16빔이 약 30 deg 를 덮는다 — 빔 사이가 2.81 deg 다.
#     거리 d 에서 빔 사이 세로 간격은 d x tan(2.81 deg) ~ d x 0.049 다.
#     벽이 h 미터면 빔이 닿는 최대 거리는 대략 h / 0.049.
#       h = 0.6 m -> 12 m. 가까이 가도 한 줄 겨우 걸린다 (사실상 안 보인다)
#       h = 2.0 m -> 20 m  <- 이 월드가 쓰는 값
#       h = 4.0 m -> 30 m
#     그래서 2.0 m 가 "12 m 앞에서 확실히 보이는" 최소선이다.
#
#   눈에 보이는데 라이다에 안 잡힐 때
#     SDF 의 링크에 <visual> 만 있고 <collision> 이 없으면 물리는 통과하고,
#     반대로 <collision> 만 있으면 화면에 안 보인다. gpu_lidar 는 **그림**을 쏘므로
#     visual 을 본다. kaboat_term.sdf 의 도킹 스테이션은 둘 다 넣어 두었다.
#     (5 m 표시 링과 가상경계선은 일부러 visual 만 넣었다 — 부딪혀도 접촉 벌점이 없게)

import argparse

import numpy as np

import tp_percep as tp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_dock_cloud.png')
    ap.add_argument('--range', type=float, default=30.0, help='앞쪽 몇 m 까지 볼지')
    ap.add_argument('--z-min', type=float, default=0.3,
                    help='이 높이 위만 벽으로 본다 (수면 반사와 물결을 뺀다)')
    a = ap.parse_args()

    xyz, frame = tp.grab_cloud()
    print('포인트클라우드 : %d 점,  좌표계 %s' % (len(xyz), frame))
    print('  (라이다는 선체 기준 x 0.70 · z 1.90 m 에 있다. 위 점들은 라이다 중심 기준이다)')

    front = tp.front_slab(xyz, x_max=a.range, half_fov_deg=60.0,
                          z_min=a.z_min - 1.9, z_max=4.0)
    print('앞쪽 %.0f m · 좌우 60 deg · 수면 위 %.1f m 만 남기면 : %d 점'
          % (a.range, a.z_min, len(front)))

    if len(front) == 0:
        print()
        print('아무것도 안 잡혔다.')
        print('  확인 : bash goto.sh dock 으로 옮겼는가 / 일시정지가 풀렸는가')
        tp.save_cloud_png(front, a.out, 'dock: no returns', a.range)
        return

    bins = tp.bin_nearest(front, half_fov_deg=60.0, step_deg=5.0)
    print()
    print('각도 칸(5 deg)마다 가장 가까운 거리 — 가까운 칸부터 열 줄')
    print('%10s %10s %8s' % ('방위[deg]', '거리[m]', '점수'))
    for ang, rng, n in bins[:10]:
        print('%10.1f %10.2f %8d' % (ang, rng, n))

    #  벽인지 보려면 "높이" 를 본다. 부표는 1 m 아래, 벽은 2 m 다.
    top = front[:, 2] + 1.9                     # 라이다 기준 -> 수면 기준
    print()
    print('수면 기준 높이 : 최저 %.2f m · 최고 %.2f m · 평균 %.2f m'
          % (top.min(), top.max(), top.mean()))
    tall = front[top > 1.0]
    print('높이 1.0 m 를 넘는 점 : %d 개 (%.0f %%) — 벽으로 볼 점들이다'
          % (len(tall), 100.0 * len(tall) / len(front)))

    if len(tall) >= 20:
        rng = np.hypot(tall[:, 0], tall[:, 1])
        ang = np.degrees(np.arctan2(tall[:, 1], tall[:, 0]))
        print()
        print('도킹 스테이션으로 본 것')
        print('  거리 %.1f ~ %.1f m,  방위 %+.1f ~ %+.1f deg (폭 %.1f deg)'
              % (rng.min(), rng.max(), ang.min(), ang.max(), ang.max() - ang.min()))
        print('  이 폭을 12 m 거리에서 미터로 바꾸면 약 %.1f m — 월드의 스테이션 폭은 11 m 다'
              % (2 * rng.mean() * np.tan(np.radians((ang.max() - ang.min()) / 2))))
        print()
        print('  ** 벽 높이 2.0 m 가 이 거리에서 보인다는 것이 확인되었다 **')
        print('  팀이 이어서 할 일 : 이 점들을 선분으로 맞춰(RANSAC 등) 뒷벽 방향을 구하고,')
        print('                      칸막이 사이 빈 곳 세 군데를 베이로 집는다.')
    else:
        print()
        print('높은 점이 %d 개뿐이다. 너무 멀거나(20 m 넘음) 자세가 빗나갔다.' % len(tall))
        print('  bash goto.sh dock 은 12 m 앞이다. 더 가까이 : bash goto.sh dock_C')

    tp.save_cloud_png(front, a.out,
                      'dock station from lidar (%d pts, %d above 1.0 m)' % (len(front), len(tall)),
                      a.range)
    print()
    print('RViz2 로 같은 것을 보려면 :  bash rviz_term.sh')


if __name__ == '__main__':
    main()
