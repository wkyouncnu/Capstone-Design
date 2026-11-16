#!/usr/bin/env python3
# rec_cam.py — 전방 카메라 영상을 mp4 로 녹화한다 (ffmpeg 없이)
#
#   python3 rec_cam.py --sec 12 --out /tmp/cam_gate.mp4
#   python3 rec_cam.py --sec 12 --out /tmp/cam_gate.mp4 --overlay gate
#
#   --overlay 를 주면 영상 위에 탐지 결과를 매 장 그려 넣는다
#     gate     빨강·초록 게이트 부표
#     search   탐색 부표 (색에 따라 선회 방향까지 글자로)
#     placard  도킹 표식 (색 + 모양)
#     none     원본 그대로 (기본값)
#
#   ffmpeg 이 WSL 에 없어서 cv2.VideoWriter 로 직접 쓴다 (mp4v 코덱, 실측 동작 확인).
#   avi 로 받고 싶으면 --out 끝을 .avi 로 주면 MJPG 로 바꿔 쓴다.
#
#   주의 : 가제보가 돌고 있어야 하고, ROS_DOMAIN_ID 가 띄운 터미널과 같아야 한다.

import argparse
import os
import time

import cv2
import numpy as np
import rclpy
from cv_bridge import CvBridge
from rclpy.node import Node
from sensor_msgs.msg import Image

import tp_percep as tp


class Rec(Node):
    def __init__(self, overlay, fx_box):
        super().__init__('tp_rec_cam')
        self.bridge = CvBridge()
        self.frames = []
        self.overlay = overlay
        self.fx_box = fx_box
        self.create_subscription(Image, tp.CAM_IMAGE, self.cb, tp.SENSOR_QOS)

    def cb(self, msg):
        bgr = self.bridge.imgmsg_to_cv2(msg, 'bgr8')
        self.frames.append(self.decorate(bgr))

    def decorate(self, bgr):
        if self.overlay == 'none':
            return bgr
        fx, cx = self.fx_box
        blobs, note = [], ''
        if self.overlay == 'gate':
            red = tp.find_blobs(bgr, '빨강', 80, top=3)
            grn = tp.find_blobs(bgr, '초록', 80, top=3)
            blobs = red + grn
            if red and grn:
                note = 'gate pass %+.1f deg' % (
                    (tp.bearing_deg(red[0]['u'], fx, cx)
                     + tp.bearing_deg(grn[0]['u'], fx, cx)) / 2.0)
            else:
                note = 'gate pair not found'
        elif self.overlay == 'search':
            for c in ('빨강', '초록', '노랑'):
                blobs += tp.find_blobs(bgr, c, 300, top=1)
            blobs.sort(key=lambda b: -b['면적'])
            if blobs:
                turn = 'PORT' if blobs[0]['색'] == '노랑' else 'STARBOARD'
                note = '%s -> turn %s' % (
                    {'빨강': 'RED', '초록': 'GREEN', '노랑': 'YELLOW'}[blobs[0]['색']], turn)
            else:
                note = 'no buoy'
        elif self.overlay == 'placard':
            for c in ('빨강', '초록', '파랑', '노랑', '주황'):
                blobs += tp.find_blobs(bgr, c, 250, top=3)
            blobs.sort(key=lambda b: b['u'])
            note = 'placards: %d' % len(blobs)
        return tp.draw_blobs(bgr, blobs, note, fx, cx)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_cam.mp4')
    ap.add_argument('--sec', type=float, default=10.0)
    ap.add_argument('--fps', type=float, default=0.0, help='만들 영상의 프레임률. 0 이면 실제로 받은 속도를 그대로 쓴다')
    ap.add_argument('--overlay', default='none',
                    choices=['none', 'gate', 'search', 'placard'])
    a = ap.parse_args()

    #  내부파라미터는 camera_info 에서 읽는다 — 해상도를 바꿔도 따라간다
    _, fx, cx, _ = tp.grab_image()

    rclpy.init()
    node = Rec(a.overlay, (fx, cx))
    print('녹화 시작 : %.0f 초,  얹을 것 = %s' % (a.sec, a.overlay))
    t0 = time.time()
    while time.time() - t0 < a.sec:
        rclpy.spin_once(node, timeout_sec=0.2)
    frames = node.frames
    node.destroy_node()
    rclpy.shutdown()

    if not frames:
        print('영상이 한 장도 안 왔다. 일시정지가 풀렸는지, ROS_DOMAIN_ID 가 맞는지 본다.')
        return

    dt = time.time() - t0
    print('받은 장수 %d / %.1f 초  (약 %.1f Hz)' % (len(frames), dt, len(frames) / dt))

    h, w = frames[0].shape[:2]
    #  실제로 받은 속도로 써야 영상 길이가 실제 시간과 같다.
    #  (고정 10 fps 로 쓰면 6.8 Hz 로 받은 12 초가 8.2 초짜리 빨리감기가 된다)
    fps = a.fps if a.fps > 0 else max(1.0, len(frames) / dt)
    ext = os.path.splitext(a.out)[1].lower()
    fourcc = cv2.VideoWriter_fourcc(*('MJPG' if ext == '.avi' else 'mp4v'))
    vw = cv2.VideoWriter(a.out, fourcc, fps, (w, h))
    if not vw.isOpened():
        print('VideoWriter 를 못 열었다. --out 을 .avi 로 바꿔 본다.')
        return
    for f in frames:
        vw.write(f)
    vw.release()
    print('저장 : %s  (%d x %d, %d 장, %.1f fps -> %.1f 초)'
          % (a.out, w, h, len(frames), fps, len(frames) / fps))

    #  대표 한 장도 같은 이름으로 남긴다 — 문서에 넣을 그림
    png = os.path.splitext(a.out)[0] + '.png'
    tp.save_png(frames[len(frames) // 2], png)


if __name__ == '__main__':
    main()
