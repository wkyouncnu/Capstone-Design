#!/usr/bin/env python3
"""capture_cloud.py — 도킹 검출 파라미터를 고르기 위해 라이다 점군을 그대로 받아 적는다

왜 필요한가
  대회 코드(find_bays_pocket)의 파라미터는 1 m 급 UGV 의 0.95~1.20 m 칸 기준이다.
  해양누리 월드의 칸은 8.0 m 이고 10~21 m 앞에 있다. 파라미터를 바꾸려면
  그 거리에서 점이 실제로 어떻게 들어오는지를 먼저 숫자로 봐야 한다.

하는 일
  1) /wamv/sensors/lidars/lidar_wamv_sensor/points 를 N 프레임 받아 쌓는다
  2) 참값 오도메트리로 그 순간의 선체 위치·헤딩을 함께 적는다
  3) 라이다 좌표계 (x 전방 · y 좌현) 점군을 .npz 로 남긴다
  4) 높이·거리·방위 분포를 표로 찍는다

실행
  python3 capture_cloud.py --frames 20 --out /tmp/dock_cloud.npz
"""
import argparse
import math
import sys

import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import PointCloud2
from nav_msgs.msg import Odometry

from pc2_util import pointcloud2_to_xyz


def yaw_of(q):
    return math.atan2(2.0 * (q.w * q.z + q.x * q.y),
                      1.0 - 2.0 * (q.y * q.y + q.z * q.z))


class Capture(Node):
    def __init__(self, frames):
        super().__init__('dock_cloud_capture')
        self.frames = frames
        self.clouds = []
        self.frame_id = ''
        self.pose = None
        self.create_subscription(PointCloud2,
                                 '/wamv/sensors/lidars/lidar_wamv_sensor/points',
                                 self.cb_cloud, qos_profile_sensor_data)
        self.create_subscription(Odometry,
                                 '/wamv/sensors/position/ground_truth_odometry',
                                 self.cb_odom, qos_profile_sensor_data)

    def cb_odom(self, m):
        self.pose = (m.pose.pose.position.y, m.pose.pose.position.x,
                     yaw_of(m.pose.pose.orientation))   # (북, 동, yaw_ENU)

    def cb_cloud(self, m):
        if len(self.clouds) >= self.frames:
            return
        self.frame_id = m.header.frame_id
        xyz = pointcloud2_to_xyz(m)
        v = np.isfinite(xyz).all(1) & (np.abs(xyz).sum(1) > 0)
        self.clouds.append(xyz[v])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', type=int, default=20)
    ap.add_argument('--out', default='/tmp/dock_cloud.npz')
    a = ap.parse_args()

    rclpy.init()
    n = Capture(a.frames)
    t0 = n.get_clock().now()
    while len(n.clouds) < a.frames:
        rclpy.spin_once(n, timeout_sec=0.5)
        if (n.get_clock().now() - t0).nanoseconds > 30e9:
            print('30 초 안에 점군이 안 들어왔다'); sys.exit(1)
    if n.pose is None:
        print('참값 오도메트리가 안 들어왔다'); sys.exit(1)

    P = np.vstack(n.clouds)
    north, east, yaw = n.pose
    np.savez(a.out, points=P, pose=np.array([north, east, yaw]),
             frame_id=n.frame_id, frames=a.frames)

    d = np.hypot(P[:, 0], P[:, 1])
    az = np.degrees(np.arctan2(P[:, 1], P[:, 0]))
    print(f'프레임 {a.frames} 장  ·  점 {len(P)} 개  ·  frame_id {n.frame_id}')
    print(f'선체 : 북 {north:+.2f} · 동 {east:+.2f} m, 헤딩(ENU) {math.degrees(yaw):+.1f} 도')
    print(f'거리 : {d.min():.2f} ~ {d.max():.2f} m')
    print(f'높이 : z {P[:,2].min():+.2f} ~ {P[:,2].max():+.2f} m (라이다 좌표계)')
    print(f'방위 : {az.min():+.1f} ~ {az.max():+.1f} 도')
    print()
    print('  z 구간별 점 수 (라이다 좌표계)')
    bins = [-2.0, -1.7, -1.4, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0, 4.0]
    for lo, hi in zip(bins[:-1], bins[1:]):
        k = int(((P[:, 2] >= lo) & (P[:, 2] < hi)).sum())
        if k:
            sel = P[(P[:, 2] >= lo) & (P[:, 2] < hi)]
            dd = np.hypot(sel[:, 0], sel[:, 1])
            print(f'   {lo:+.1f} ~ {hi:+.1f} : {k:6d} 점   거리 {dd.min():5.1f} ~ {dd.max():5.1f} m')
    print(f'\n저장 : {a.out}')
    n.destroy_node(); rclpy.shutdown()


if __name__ == '__main__':
    main()
