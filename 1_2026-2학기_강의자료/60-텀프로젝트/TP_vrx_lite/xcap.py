#!/usr/bin/env python3
# xcap.py — 가제보 창·Rviz2 창을 PNG 로 뜯어낸다 (WSLg X11, 추가 설치 없이)
#
#   python3 xcap.py --list                                   # 창 목록
#   python3 xcap.py --name Gazebo --out /tmp/gz.png
#   python3 xcap.py --name RViz   --out /tmp/rviz.png
#   python3 xcap.py --name Gazebo --out /tmp/gz.mp4 --sec 10  # 녹화 (mp4)
#
#   왜 이 파일이 필요한가
#     볼트의 _tools/xshot.sh 는 xdotool 과 ImageMagick(import) 을 쓴다.
#     이 WSL 에는 둘 다 없고 sudo 가 비밀번호를 묻는다 (비대화형이라 설치 불가).
#     그래서 이미 깔려 있는 것만으로 같은 일을 한다 :
#       창 찾기  xwininfo -root -tree   (설치돼 있음)
#       화면 뜯기 libX11 의 XGetImage   (ctypes 로 직접 부른다)
#       PNG·mp4  OpenCV               (설치돼 있음)
#
#   속도 (2026-11-16 실측)
#     XGetImage 는 생각보다 빠르다 — 1200x1000 창을 초당 약 100 장 뜯는다.
#     그래서 오히려 상한을 걸어야 한다 : mp4(MPEG-4) 는 프레임률 분모가 65535 를
#     넘으면 코덱이 안 열린다. 101.6 fps 로 쓰려다 VideoWriter 가 실패했다.
#     --max-fps (기본 15) 로 뜯는 속도를 눌러 둔다.

import argparse
import ctypes
import os
import re
import subprocess
import time

import cv2
import numpy as np

ZPIXMAP = 2
ALLPLANES = (1 << 32) - 1


class XImage(ctypes.Structure):
    pass


XImage._fields_ = [
    ('width', ctypes.c_int), ('height', ctypes.c_int),
    ('xoffset', ctypes.c_int), ('format', ctypes.c_int),
    ('data', ctypes.POINTER(ctypes.c_char)),
    ('byte_order', ctypes.c_int), ('bitmap_unit', ctypes.c_int),
    ('bitmap_bit_order', ctypes.c_int), ('bitmap_pad', ctypes.c_int),
    ('depth', ctypes.c_int), ('bytes_per_line', ctypes.c_int),
    ('bits_per_pixel', ctypes.c_int),
    ('red_mask', ctypes.c_ulong), ('green_mask', ctypes.c_ulong),
    ('blue_mask', ctypes.c_ulong),
    ('obdata', ctypes.c_void_p),
    ('f', ctypes.c_char * 128),
]


class Grabber(object):
    """libX11 을 ctypes 로 직접 불러 창 하나를 뜯어낸다."""

    def __init__(self, display=None):
        self.x11 = ctypes.CDLL('libX11.so.6')
        self.x11.XOpenDisplay.restype = ctypes.c_void_p
        self.x11.XGetImage.restype = ctypes.POINTER(XImage)
        name = (display or os.environ.get('DISPLAY', ':0')).encode()
        self.dpy = self.x11.XOpenDisplay(name)
        if not self.dpy:
            raise RuntimeError('X 디스플레이를 못 열었다 : %s' % name.decode())

    def grab(self, wid, w, h):
        img = self.x11.XGetImage(ctypes.c_void_p(self.dpy), ctypes.c_ulong(wid),
                                 0, 0, w, h, ctypes.c_ulong(ALLPLANES), ZPIXMAP)
        if not img:
            return None
        im = img.contents
        n = im.bytes_per_line * im.height
        buf = ctypes.string_at(im.data, n)
        bpp = im.bits_per_pixel // 8
        arr = np.frombuffer(buf, dtype=np.uint8).reshape(
            im.height, im.bytes_per_line // bpp, bpp)
        arr = arr[:, :im.width, :3]          # BGRA -> BGR (알파 버림)
        out = np.ascontiguousarray(arr)
        self.x11.XDestroyImage(img)
        return out


def windows():
    """xwininfo -root -tree 를 읽어 (id, 폭, 높이, 제목) 목록을 낸다."""
    out = subprocess.run(['xwininfo', '-root', '-tree'],
                         capture_output=True, text=True,
                         env=dict(os.environ, DISPLAY=os.environ.get('DISPLAY', ':0')))
    rows = []
    pat = re.compile(r'(0x[0-9a-f]+)\s+"([^"]*)".*?\s(\d+)x(\d+)\+')
    for line in out.stdout.splitlines():
        m = pat.search(line)
        if not m:
            continue
        wid, title, w, h = int(m.group(1), 16), m.group(2), int(m.group(3)), int(m.group(4))
        if w < 300 or h < 200:               # 1x1 더미 창과 작은 자식 창은 버린다
            continue
        rows.append((wid, w, h, title))
    return rows


def pick(name):
    cands = [r for r in windows() if name.lower() in r[3].lower()]
    if not cands:
        return None
    return max(cands, key=lambda r: r[1] * r[2])   # 가장 큰 것 = 본 창


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', action='store_true', help='창 목록만 본다')
    ap.add_argument('--name', help='창 제목 조각 (Gazebo / RViz)')
    ap.add_argument('--out', default='/tmp/xcap.png')
    ap.add_argument('--sec', type=float, default=0.0,
                    help='0 보다 크면 그 초 동안 녹화한다 (--out 을 .mp4 로)')
    ap.add_argument('--fps', type=float, default=0.0,
                    help='만들 영상의 프레임률. 0 이면 실제로 뜯어낸 속도를 그대로 쓴다 '
                         '(그래야 영상 길이가 실제 시간과 같다)')
    ap.add_argument('--max-fps', type=float, default=15.0,
                    help='뜯는 속도 상한. XGetImage 는 100 Hz 까지 나오는데 그대로 쓰면 '
                         'mp4 코덱이 안 열리고 파일도 커진다. 0 이면 상한 없음')
    a = ap.parse_args()

    if a.list or not a.name:
        print('%12s %12s  %s' % ('id', '크기', '제목'))
        for wid, w, h, t in windows():
            print('%12s %12s  %s' % (hex(wid), '%dx%d' % (w, h), t))
        return

    hit = pick(a.name)
    if not hit:
        print('창을 못 찾았다 : %s   (python3 xcap.py --list 로 제목을 본다)' % a.name)
        return
    wid, w, h, title = hit
    print('창 %s  %dx%d  "%s"' % (hex(wid), w, h, title))

    g = Grabber()

    if a.sec <= 0:
        img = g.grab(wid, w, h)
        if img is None:
            print('XGetImage 실패. 창이 최소화됐거나 다른 화면에 있다.')
            return
        cv2.imwrite(a.out, img)
        print('저장 : %s  (%d x %d)' % (a.out, img.shape[1], img.shape[0]))
        return

    #  상한을 두고 뜯는다 — 이유는 머리말 "속도" 참고
    period = (1.0 / a.max_fps) if a.max_fps > 0 else 0.0
    frames, t0 = [], time.time()
    while True:
        now = time.time()
        if now - t0 >= a.sec:
            break
        img = g.grab(wid, w, h)
        if img is not None:
            frames.append(img)
        if period > 0:
            rest = period - (time.time() - now)
            if rest > 0:
                time.sleep(rest)
    dt = time.time() - t0
    print('뜯어낸 장수 %d / %.1f 초  (약 %.1f Hz)' % (len(frames), dt, len(frames) / dt))
    if not frames:
        print('한 장도 못 뜯었다.')
        return

    #  실제로 뜯어낸 속도로 써야 영상 길이가 실제 시간과 같다.
    #  (고정 3 fps 로 쓰면 1 Hz 로 뜯은 8 초가 2.7 초짜리 빨리감기가 된다)
    #  MPEG-4 는 프레임률 분모가 65535 를 넘으면 코덱이 안 열린다 — 60 fps 에서 자른다
    fps = a.fps if a.fps > 0 else max(1.0, len(frames) / dt)
    fps = min(fps, 60.0)
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
    png = os.path.splitext(a.out)[0] + '.png'
    cv2.imwrite(png, frames[len(frames) // 2])
    print('대표 장면 : %s' % png)


if __name__ == '__main__':
    main()
