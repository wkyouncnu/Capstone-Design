#!/usr/bin/env python3
"""lidar_reach.py — 장애물이 **몇 m 에서** 라이다에 잡히는가를 잰다 (해양누리공원 월드)

    export ROS_DOMAIN_ID=7; export GZ_PARTITION=hy1
    source /opt/ros/humble/setup.bash
    python3 lidar_reach.py                 # 첫 차단벽(barrier0)을 정면에서
    python3 lidar_reach.py --target dome   # 홀로 뜬 흰 돔(dome4)을 정면에서

하는 일
    배를 표적의 동쪽 d m 에 서쪽을 보게 옮겨 놓고 (goto.sh 와 같은 set_pose),
    라이다 점군을 월드 좌표로 돌려 **표적의 자리에 떨어진 점**만 센다.
    d 를 바꿔 가며 되풀이해 "거리 — 점 수 — 점의 높이" 표를 찍는다.

왜 재는가
    라이다는 높이 1.9 m 에 달려 있고 세로로 16 줄, 2 도 간격이다 (±15 도).
    낮은 물체는 **줄과 줄 사이**로 빠진다. 가장 아래 줄(−15 도)도 물체 윗면보다
    높이 지나가는 거리 안쪽에서는 물체가 **통째로 사라진다**.

        사라지는 거리 = (라이다 높이 − 물체 윗면 높이) / tan 15°

    이 값이 접촉 거리보다 크면, 회피기는 부딪히기 직전에 장애물을 놓친다.

주의
    순간이동을 쓰므로 **확인 전용**이다. 배를 풀어 둔 뒤 (gz topic -t /vrx/release) 돌린다.
"""
import argparse
import math
import os
import subprocess
import time

import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from nav_msgs.msg import Odometry
from sensor_msgs.msg import PointCloud2
from sensor_msgs_py import point_cloud2 as pc2

HERE = os.path.dirname(os.path.abspath(__file__))
LIDAR_XYZ = np.array([0.7, 0.0, 1.9])          # base_link 기준 라이다 자리 (xacro 와 같다)

#  표적 — (이름, 중심 동, 중심 북, 동쪽 반폭, 북쪽 반폭)   make_haeyang_world.py 의 자리
TARGETS = {
    'barrier': ('barrier0 (차단벽, 동 -34.0)', -34.0, -33.5, 1.0, 4.0),
    'dome':    ('dome4 (흰 돔, 동 -31.8 · 북 -26)', -31.8, -26.0, 1.0, 1.0),
}


def quat_rot(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


class Probe(Node):
    def __init__(self):
        super().__init__('lidar_reach')
        self.odom = None
        self.clouds = []
        self.create_subscription(Odometry, '/wamv/sensors/position/ground_truth_odometry',
                                 self.on_odom, qos_profile_sensor_data)
        self.create_subscription(PointCloud2, '/wamv/sensors/lidars/lidar_wamv_sensor/points',
                                 self.on_cloud, qos_profile_sensor_data)

    def on_odom(self, m):
        p, q = m.pose.pose.position, m.pose.pose.orientation
        self.odom = (np.array([p.x, p.y, p.z]), quat_rot((q.x, q.y, q.z, q.w)))

    def on_cloud(self, m):
        if self.odom is None:
            return
        #  필드의 자료형이 섞여 있어 read_points_numpy 는 못 쓴다 (x·y·z 는 float32, ring 은 uint16)
        s = pc2.read_points(m, field_names=('x', 'y', 'z'), skip_nans=True)
        a = np.stack([s['x'], s['y'], s['z']], axis=1).astype(float)
        a = a[np.isfinite(a).all(axis=1)]
        pos, R = self.odom
        self.clouds.append((a + LIDAR_XYZ) @ R.T + pos)      # 라이다 -> 선체 -> 월드

    def collect(self, n, timeout=8.0):
        self.clouds = []
        t0 = time.time()
        while len(self.clouds) < n and time.time() - t0 < timeout:
            rclpy.spin_once(self, timeout_sec=0.2)
        return self.clouds[-n:] if self.clouds else []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--target', default='barrier', choices=TARGETS)
    ap.add_argument('--dists', default='3,4,5,6,8,10,12,15,18,21,25,30')
    ap.add_argument('--scans', type=int, default=5)
    a = ap.parse_args()
    name, cx, cy, hx, hy = TARGETS[a.target]

    rclpy.init()
    node = Probe()
    print(f'\n표적 : {name}')
    print('배를 표적의 동쪽에 서쪽을 보게 놓고 잰다. 거리는 **라이다에서 표적 중심까지**.')
    print(f'스캔 {a.scans} 번의 평균.\n')
    print(f'  {"거리[m]":>8} {"점 수":>7} {"높이 최소":>9} {"높이 최대":>9}   판정')
    print('  ' + '-' * 52)
    for d in [float(s) for s in a.dists.split(',')]:
        bx = cx + d + LIDAR_XYZ[0]       # 서쪽을 보므로 라이다는 선체 중심보다 서쪽 0.7 m
        subprocess.run(['bash', os.path.join(HERE, 'goto.sh'), '--', f'{bx:.2f}', f'{cy:.2f}', '180'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t0 = time.time()
        while time.time() - t0 < 4.0:                # 옮긴 뒤 가라앉힌다
            rclpy.spin_once(node, timeout_sec=0.1)
        cl = node.collect(a.scans)
        cnt, zs = [], []
        for w in cl:
            m = (np.abs(w[:, 0] - cx) < hx) & (np.abs(w[:, 1] - cy) < hy) & (w[:, 2] > 0.05)
            cnt.append(int(m.sum()))
            zs.append(w[m, 2])
        z = np.concatenate(zs) if zs else np.array([])
        n = float(np.mean(cnt)) if cnt else 0.0
        if z.size:
            verdict = '보임' if n >= 5 else '희미함'
            print(f'  {d:8.1f} {n:7.1f} {z.min():9.2f} {z.max():9.2f}   {verdict}')
        else:
            print(f'  {d:8.1f} {n:7.1f} {"-":>9} {"-":>9}   **안 보임**')
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
