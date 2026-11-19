#!/usr/bin/env python3
"""rec_gazebo.py — 가제보 창을 일정 간격으로 뜯어 두고, 접촉(/vrx/contacts)을 함께 적는다

    export ROS_DOMAIN_ID=7; export GZ_PARTITION=hy1; source /opt/ros/humble/setup.bash
    python3 rec_gazebo.py --out ~/tp_rec --every 0.5 --max-sec 900

    끝내기 :  touch ~/tp_rec/STOP     (또는 Ctrl+C, 또는 --max-sec 가 지남)

남기는 것 (--out 폴더)
    gz_<벽시계 ms>.jpg    가제보 창. 이름의 벽시계로 GCS 프레임과 맞춘다 (TP_make_video.m)
    contacts.csv          접촉이 보고된 순간마다 한 줄 — 벽시계 ms, 가제보 시각, 맞닿은 두 충돌체

왜 화면 녹화 프로그램을 쓰지 않는가
    WSLg 창은 다른 창에 가려지면 화면 녹화에 안 잡힌다. X 서버에서 창을 직접 뜯으면
    가려져 있어도 잡힌다 (TP_vrx_lite/xcap.py 의 Grabber 를 그대로 쓴다).
"""
import argparse
import os
import sys
import time

import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'TP_vrx_lite'))
import xcap                                                    # noqa: E402

import rclpy                                                   # noqa: E402
from rclpy.qos import qos_profile_sensor_data                  # noqa: E402
from ros_gz_interfaces.msg import Contacts                     # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.expanduser('~/tp_rec'))
    ap.add_argument('--every', type=float, default=0.5, help='뜯는 간격 [s, 벽시계]')
    ap.add_argument('--max-sec', type=float, default=900.0)
    ap.add_argument('--name', default='Gazebo')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stop = os.path.join(a.out, 'STOP')
    if os.path.exists(stop):
        os.remove(stop)

    hit = xcap.pick(a.name)
    if not hit:
        print('가제보 창을 못 찾았다')
        return
    wid, w, h = hit[0], hit[1], hit[2]
    g = xcap.Grabber()
    print('창 %s  %dx%d  → %s' % (hex(wid), w, h, a.out))

    rclpy.init()
    node = rclpy.create_node('tp_rec_contacts')
    fc = open(os.path.join(a.out, 'contacts.csv'), 'w')
    fc.write('wall_ms,sim_s,collision1,collision2\n')
    n_contact = [0]

    def on_contacts(m):
        for c in m.contacts:
            n_contact[0] += 1
            fc.write('%d,%.3f,%s,%s\n' % (int(time.time() * 1000),
                                          m.header.stamp.sec + m.header.stamp.nanosec * 1e-9,
                                          c.collision1.name, c.collision2.name))
        fc.flush()

    node.create_subscription(Contacts, '/vrx/contacts', on_contacts, qos_profile_sensor_data)
    node.create_subscription(Contacts, '/vrx/contacts', on_contacts, 10)

    t0 = time.time()
    nxt, n = t0, 0
    try:
        while time.time() - t0 < a.max_sec and not os.path.exists(stop):
            rclpy.spin_once(node, timeout_sec=0.05)
            now = time.time()
            if now >= nxt:
                nxt += a.every
                im = g.grab(wid, w, h)
                if im is not None:
                    cv2.imwrite(os.path.join(a.out, 'gz_%013d.jpg' % int(now * 1000)), im,
                                [cv2.IMWRITE_JPEG_QUALITY, 88])
                    n += 1
    except KeyboardInterrupt:
        pass
    fc.close()
    print('뜯은 장수 %d  (%.1f 초),  접촉 보고 %d 건' % (n, time.time() - t0, n_contact[0]))


if __name__ == '__main__':
    main()
