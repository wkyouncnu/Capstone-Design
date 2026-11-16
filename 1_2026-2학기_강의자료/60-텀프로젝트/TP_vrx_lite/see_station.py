#!/usr/bin/env python3
# see_station.py — 위치유지 : 지정위치 5 m 안에 있는지 숫자로 센다
#
#   bash goto.sh wp1                                   # WP1 부표 위
#   python3 see_station.py --wp wp1 --sec 10
#   bash goto.sh wp2
#   python3 see_station.py --wp wp2 --sec 10
#
#   확인하는 것 (요구조건 문서 4-2 의 출발점)
#     1) 위치가 ROS 로 읽힌다 — 어디에서, 몇 Hz 로
#     2) 지정 부표까지의 거리가 나온다
#     3) 그 거리가 5 m 안인지, 몇 초째 머물렀는지 세진다
#     4) 월드에 5 m 영역이 **눈에 보이게** 그려져 있다 (가제보 화면의 점선 링)
#
#   하지 않는 것
#     위치를 유지하는 제어. 그쪽이 선수추진기까지 쓰는 3자유도 제어이고
#     Simulink·Stateflow 몫이다. 이 스크립트는 "성공/실패 판정" 쪽만 만든다.
#
#   규정 (경기규정-202611)
#     위치유지 : 부표 반경 5 m 안에서 **정지 후 5초** 유지하면 성공.
#     종합점수 = 100 x (성공한 지정위치 수) / (지정위치 개수).
#     이 월드는 지정위치가 둘(WP1·WP2)이므로 한 곳 성공 = 50 점.
#
#   월드 (kaboat_term.sdf)
#     WP1 부표 (동 -534, 북 226) · WP2 부표 (동 -553, 북 188)
#     각각 반지름 5 m 점선 링(wp1_area · wp2_area)을 **visual 만** 으로 깔았다.
#     부딪혀도 접촉 벌점이 생기지 않고, 라이다에도 안 잡힌다 — 눈으로 보는 표시다.
#
#   위치를 어디서 읽는가
#     여기서는 /wamv/sensors/position/ground_truth_odometry (p3d 플러그인) 를 쓴다.
#     시뮬레이터가 주는 **참값**이라 판정 기준으로 삼기에 좋다.
#     실제 경기에서 배가 쓸 수 있는 것은 GPS + IMU 뿐이다 —
#     팀은 /wamv/sensors/gps/gps/fix 를 쓰고, 그 값이 여기 참값과 얼마나
#     벌어지는지 재 두는 것이 좋다 (그 차이가 위치유지 실패의 주범이다).

import argparse
import math
import time

import rclpy
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy

ODOM = '/wamv/sensors/position/ground_truth_odometry'

#  월드에 넣어 둔 지정위치. make_term_world.py 와 같은 값이다.
WP = {'wp1': (-534.0, 226.0),
      'wp2': (-553.0, 188.0)}

RADIUS = 5.0          # 규정상 허용 반경 [m]
HOLD = 5.0            # 규정상 유지해야 하는 시간 [s]
STOP_SPEED = 0.3      # "정지" 로 볼 속력 [m/s] — 규정에 수치가 없어 여기서 정한 값


class Watch(Node):
    def __init__(self, tx, ty):
        super().__init__('tp_see_station')
        self.tx, self.ty = tx, ty
        self.rows = []
        qos = QoSProfile(reliability=ReliabilityPolicy.RELIABLE,
                         history=HistoryPolicy.KEEP_LAST, depth=10)
        self.create_subscription(Odometry, ODOM, self.cb, qos)

    def cb(self, msg):
        p = msg.pose.pose.position
        v = msg.twist.twist.linear
        d = math.hypot(p.x - self.tx, p.y - self.ty)
        spd = math.hypot(v.x, v.y)
        self.rows.append((time.time(), p.x, p.y, d, spd))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wp', choices=sorted(WP), default='wp1')
    ap.add_argument('--sec', type=float, default=10.0, help='몇 초 동안 볼지')
    ap.add_argument('--east', type=float, default=None, help='부표 좌표를 직접 줄 때')
    ap.add_argument('--north', type=float, default=None)
    a = ap.parse_args()

    tx, ty = WP[a.wp]
    if a.east is not None and a.north is not None:
        tx, ty = a.east, a.north
    print('지정위치 %s : 동 %.1f · 북 %.1f,  허용 반경 %.1f m' % (a.wp, tx, ty, RADIUS))
    print('읽는 토픽 : %s' % ODOM)

    rclpy.init()
    node = Watch(tx, ty)
    t0 = time.time()
    while time.time() - t0 < a.sec:
        rclpy.spin_once(node, timeout_sec=0.2)
    rows = node.rows
    node.destroy_node()
    rclpy.shutdown()

    if not rows:
        print()
        print('위치 메시지가 한 건도 안 왔다.')
        print('  확인 : 일시정지가 풀렸는가 / ROS_DOMAIN_ID·GZ_PARTITION 이 띄운 터미널과 같은가')
        return

    dt = rows[-1][0] - rows[0][0]
    print('받은 메시지 %d 건 / %.1f 초  (약 %.1f Hz)' % (len(rows), dt, len(rows) / max(dt, 1e-3)))

    print()
    print('%8s %10s %10s %10s %10s %6s' % ('t[s]', '동[m]', '북[m]', '거리[m]', '속력[m/s]', '안쪽'))
    step = max(1, len(rows) // 12)        # 열두 줄쯤만 보여 준다
    for t, x, y, d, s in rows[::step]:
        print('%8.1f %10.2f %10.2f %10.2f %10.2f %6s'
              % (t - rows[0][0], x, y, d, s, 'O' if d <= RADIUS else 'X'))

    dists = [r[3] for r in rows]
    speeds = [r[4] for r in rows]
    inside = [r for r in rows if r[3] <= RADIUS]
    held = [r for r in rows if r[3] <= RADIUS and r[4] <= STOP_SPEED]

    print()
    print('거리 : 최소 %.2f · 최대 %.2f · 평균 %.2f m' % (min(dists), max(dists), sum(dists) / len(dists)))
    print('속력 : 최소 %.2f · 최대 %.2f · 평균 %.2f m/s' % (min(speeds), max(speeds), sum(speeds) / len(speeds)))
    print('5 m 안에 있던 시간 : %.1f 초 / %.1f 초' % (dt * len(inside) / len(rows), dt))
    print('5 m 안 + 정지(%.1f m/s 이하) : %.1f 초' % (STOP_SPEED, dt * len(held) / len(rows)))

    print()
    if dt * len(held) / len(rows) >= HOLD:
        print('** 규정 기준(5 m 안에서 정지 후 5초)을 채웠다 **')
    elif inside:
        print('5 m 안에는 들어왔다. 정지 유지 %.1f 초로 아직 5초에 못 미친다.'
              % (dt * len(held) / len(rows)))
        print('  여기서는 goto.sh 로 순간이동만 했으므로 속력이 0 이 아닐 수 있다 (물결·잔류 속도).')
    else:
        print('5 m 밖이다. bash goto.sh %s 로 다시 옮긴다.' % a.wp)
    print()
    print('판정에 쓸 값 셋 : 거리[m] · 속력[m/s] · 안쪽에 머문 시간[s]')
    print('Stateflow 로 넘길 값 : 부표까지의 거리와 방위 (목표점은 부표 좌표 그대로)')


if __name__ == '__main__':
    main()
