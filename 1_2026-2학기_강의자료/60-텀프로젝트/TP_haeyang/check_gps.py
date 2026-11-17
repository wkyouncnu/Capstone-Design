#!/usr/bin/env python3
"""check_gps.py — 미션 지점 네 곳의 위도·경도를 **가제보에서 실제로 재어** 표와 맞춰 본다

    bash run_haeyang.sh lite gui         # 먼저 월드를 띄우고 (같은 GZ_PARTITION)
    gz topic -t /vrx/release -m gz.msgs.Empty -p ''   # 배를 풀고
    python3 check_gps.py                 # 이 파일

하는 일
    1) 지점마다 배를 순간이동시킨다 (gz service /world/<월드>/set_pose)
    2) /wamv/sensors/position/ground_truth_odometry 로 **배가 간 자리**를 읽고
    3) /wamv/sensors/gps/gps/fix 로 **GPS 가 말하는 위도·경도**를 읽어
    4) haeyang_points.m 의 표값과 m 단위로 비교한다

읽는 법 — 세 가지 차이를 따로 본다
    선체 차이   지시한 자리와 오도메트리 자리의 차이. 파도에 밀린 양 (보통 < 1 m)
    안테나 보정 GPS 안테나는 base_link 뒤 0.85 m 에 있다. 선수각만큼 돌려 더해 준다
    남은 차이   위 둘을 뺀 나머지. 환산식이 맞으면 0.2 m 안쪽이어야 한다

주의
    띄운 터미널과 **같은 GZ_PARTITION · ROS_DOMAIN_ID** 를 주어야 한다.
"""
import math
import subprocess
import sys
import time

import rclpy
from nav_msgs.msg import Odometry
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import NavSatFix

#  월드 원점 — make_haeyang_world.py 의 LAT0 / LON0 와 같아야 한다
LAT0, LON0 = 35.1862095, 128.5665903
WORLD = 'haeyangnuri'
MODEL = 'wamv'

#  GPS 안테나 자리 — wamv_term_lite.urdf 의 gps_wamv_joint origin xyz
ANT_X, ANT_Y = -0.85, 0.0          # base_link 기준 [m]

#  이름, 동(ENU x), 북(ENU y), 선수각[deg]
POINTS = [
    ('start', 0.0, -32.0, 90.0, '출발점 — 적·녹 첫 게이트 사이 시작선'),
    ('wp1',   0.0,  10.0, 90.0, 'WP1 — 도킹 스테이션 앞 위치유지점'),
    ('wp2', -20.0, -14.0, 180.0, 'WP2 — 충돌회피 진입 전 DP 위치유지점'),
    ('goal', -70.0, -39.0, 180.0, '종료점 — 충돌회피 종료 게이트 중앙'),
]

#  WGS84 곡률반경 (haeyang_points.m 과 같은 식)
_a, _f = 6378137.0, 1 / 298.257223563
_e2 = _f * (2 - _f)
_phi = math.radians(LAT0)
_W = 1 - _e2 * math.sin(_phi) ** 2
M_RAD = _a * (1 - _e2) / _W ** 1.5
N_RAD = _a / math.sqrt(_W)
DEG_PER_M_LAT = math.degrees(1.0 / M_RAD)
DEG_PER_M_LON = math.degrees(1.0 / (N_RAD * math.cos(_phi)))


def enu_to_ll(east, north):
    return LAT0 + north * DEG_PER_M_LAT, LON0 + east * DEG_PER_M_LON


def ll_to_enu(lat, lon):
    return (lon - LON0) / DEG_PER_M_LON, (lat - LAT0) / DEG_PER_M_LAT


def teleport(east, north, yaw_deg):
    h = math.radians(yaw_deg) / 2.0
    req = (f'name: "{MODEL}", position: {{x: {east}, y: {north}, z: 0.0}}, '
           f'orientation: {{z: {math.sin(h):.9f}, w: {math.cos(h):.9f}}}')
    r = subprocess.run(['gz', 'service', '-s', f'/world/{WORLD}/set_pose',
                        '--reqtype', 'gz.msgs.Pose', '--reptype', 'gz.msgs.Boolean',
                        '--timeout', '3000', '--req', req],
                       capture_output=True, text=True)
    return r.returncode == 0 and 'true' in r.stdout.lower()


class Reader(Node):
    def __init__(self):
        super().__init__('check_gps')
        self.fix = []
        self.odom = []
        self.create_subscription(NavSatFix, '/wamv/sensors/gps/gps/fix',
                                 lambda m: self.fix.append((m.latitude, m.longitude, m.altitude)),
                                 qos_profile_sensor_data)
        self.create_subscription(Odometry, '/wamv/sensors/position/ground_truth_odometry',
                                 self._odom, qos_profile_sensor_data)

    def _odom(self, m):
        p, q = m.pose.pose.position, m.pose.pose.orientation
        yaw = math.atan2(2 * (q.w * q.z + q.x * q.y),
                         1 - 2 * (q.y * q.y + q.z * q.z))
        self.odom.append((p.x, p.y, yaw))

    def collect(self, n=20, timeout=8.0):
        self.fix.clear()
        self.odom.clear()
        t0 = time.time()
        while time.time() - t0 < timeout:
            rclpy.spin_once(self, timeout_sec=0.1)
            if len(self.fix) >= n and len(self.odom) >= n:
                break
        if not self.fix or not self.odom:
            return None
        f = self.fix[-n:]
        o = self.odom[-n:]
        mean = lambda v: sum(v) / len(v)
        return (mean([x[0] for x in f]), mean([x[1] for x in f]), mean([x[2] for x in f]),
                mean([x[0] for x in o]), mean([x[1] for x in o]), o[-1][2],
                len(self.fix), len(self.odom))


def main():
    rclpy.init()
    node = Reader()
    print()
    print('월드 원점  위도 %.7f · 경도 %.7f' % (LAT0, LON0))
    print('환산       북 1 m = %.6e deg 위도,  동 1 m = %.6e deg 경도' %
          (DEG_PER_M_LAT, DEG_PER_M_LON))
    print('안테나     base_link 뒤 %.2f m (선수각만큼 돌려 보정)' % (-ANT_X))
    print()

    worst = 0.0
    rows = []
    for name, east, north, yaw, desc in POINTS:
        lat_tbl, lon_tbl = enu_to_ll(east, north)
        print('── %-5s  지시 동 %+7.1f · 북 %+7.1f · 선수각 %5.1f°   %s'
              % (name, east, north, yaw, desc))
        if not teleport(east, north, yaw):
            print('   순간이동 실패 — 가제보가 떠 있는지, GZ_PARTITION 이 같은지 본다')
            continue
        time.sleep(4.0)                       # 파도에 흔들리던 자세가 가라앉기를 기다린다
        got = node.collect()
        if got is None:
            print('   토픽이 안 옴 — ROS_DOMAIN_ID 를 본다')
            continue
        lat, lon, alt, ox, oy, oyaw, nf, no = got

        #  1) 선체 차이 — 지시한 자리 대 오도메트리 자리
        d_hull_e, d_hull_n = ox - east, oy - north

        #  2) 안테나를 선수각만큼 돌려 월드 좌표로
        ae = ox + ANT_X * math.cos(oyaw) - ANT_Y * math.sin(oyaw)
        an = oy + ANT_X * math.sin(oyaw) + ANT_Y * math.cos(oyaw)
        lat_exp, lon_exp = enu_to_ll(ae, an)

        #  3) 남은 차이 — 환산식이 맞는지
        d_lat_m = (lat - lat_exp) / DEG_PER_M_LAT
        d_lon_m = (lon - lon_exp) / DEG_PER_M_LON
        resid = math.hypot(d_lat_m, d_lon_m)
        worst = max(worst, resid)

        #  GPS 가 말하는 자리를 ENU 로 되돌려 본다 (표와 바로 견주기 위해)
        ge, gn = ll_to_enu(lat, lon)

        print('   표   위도 %12.7f · 경도 %12.7f' % (lat_tbl, lon_tbl))
        print('   실측 위도 %12.7f · 경도 %12.7f   (고도 %.2f m, 표본 GPS %d · 오도 %d)'
              % (lat, lon, alt, nf, no))
        print('   GPS 를 ENU 로 되돌리면  동 %+7.2f · 북 %+7.2f   → 표와 동 %+5.2f · 북 %+5.2f m'
              % (ge, gn, ge - east, gn - north))
        print('   선체 차이  동 %+5.2f · 북 %+5.2f m      안테나 보정  동 %+5.2f · 북 %+5.2f m'
              % (d_hull_e, d_hull_n, ae - ox, an - oy))
        print('   남은 차이  동 %+5.2f · 북 %+5.2f m  (크기 %.2f m)'
              % (d_lon_m, d_lat_m, resid))
        print()
        rows.append((name, lat_tbl, lon_tbl, lat, lon, ge - east, gn - north, resid))

    print('=' * 104)
    print('%-6s %12s %13s %12s %13s %8s %8s %7s' %
          ('이름', '표 위도', '표 경도', '실측 위도', '실측 경도', '동차[m]', '북차[m]', '환산[m]'))
    print('-' * 104)
    for r in rows:
        print('%-6s %12.7f %13.7f %12.7f %13.7f %8.2f %8.2f %7.2f' % r)
    print()
    print('환산 오차(남은 차이) 가장 큰 값 : %.2f m' % worst)
    print('  0.2 m 안쪽이면 위도·경도 환산식과 월드 원점이 맞다.')
    print('  동차·북차 는 파도에 밀린 양 + 안테나 0.85 m 이므로 1~2 m 가 보통이다.')

    node.destroy_node()
    rclpy.shutdown()
    return 0 if rows else 1


if __name__ == '__main__':
    sys.exit(main())
