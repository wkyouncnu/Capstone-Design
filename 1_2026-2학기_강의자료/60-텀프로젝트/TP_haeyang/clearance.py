#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""장애물 구간을 0.2 m 격자로 그려 **배가 지나갈 틈이 있는지** 숫자로 확인한다.

  거리변환으로 각 칸의 '가장 가까운 장애물까지' 를 구하고,
  여유 r 이상인 칸만 통행 가능으로 본 뒤 진입구 → 종료구 연결을 본다.
  연결이 끊어지는 r 을 이분법으로 찾으면 그것이 **통로 반폭**이다.
"""
import math
import sys

import cv2
import numpy as np

sys.argv = ["m", "/home/wkyoun/Capstone-Design/1_2026-2학기_강의자료/60-텀프로젝트/TP_vrx_lite/my_world_원본.sdf", "/tmp/hy/throwaway.sdf"]
sys.path.insert(0, "/tmp/hy")
import make_haeyang_world as W                                   # noqa: E402

RES = 0.2
X0, X1 = W.OBS_X0 - 4.0, W.OBS_X1 + 4.0
Y0, Y1 = W.OBS_Y0 - 4.0, W.OBS_Y1 + 4.0
NW = int((X1 - X0) / RES)
NH = int((Y1 - Y0) / RES)


def px(x, y):
    return int((x - X0) / RES), int((y - Y0) / RES)


free = np.full((NH, NW), 255, np.uint8)       # 255 = 물, 0 = 장애물


def fill_box(cx, cy, lx, ly, yaw):
    c, s = math.cos(yaw), math.sin(yaw)
    pts = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        dx, dy = sx * lx / 2, sy * ly / 2
        pts.append(px(cx + dx * c - dy * s, cy + dx * s + dy * c))
    cv2.fillPoly(free, [np.array(pts, np.int32)], 0)


def fill_circle(cx, cy, r):
    cv2.circle(free, px(cx, cy), int(r / RES), 0, -1)


# 부유 차단벽 — 각재 폭 0.9 m. 양 끝에 돔 펜더가 달려 있다 (반지름은 생성기가 정한다)
for (x, y, a, L) in W.BARRIERS:
    rad = math.radians(a)
    fill_box(x, y, L, 0.9, rad)
    for s in (-L / 2.0, L / 2.0):
        fill_circle(x + s * math.cos(rad), y + s * math.sin(rad), W.FENDER_R)
# 흰 돔 부표 — 반지름 그대로 막는다 (중심 높이는 생성기의 DOME_Z)
for (x, y) in W.DOMES:
    fill_circle(x, y, W.DOME_R)
# 주황 기둥
for (x, y) in W.PILLARS:
    fill_circle(x, y, 0.7)
# 경계 로프 — 물리 충돌체는 없지만 넘으면 실격이므로 벽으로 본다
for (x0, y0, x1, y1) in W.ROPE_SEGS:
    cv2.line(free, px(x0, y0), px(x1, y1), 0, max(1, int(0.3 / RES)))
# 구간 안쪽만 본다 — 로프를 넘어 바깥으로 돌아가는 길은 셈에서 뺀다
outer = np.zeros_like(free)
cv2.rectangle(outer, px(W.OBS_X0, W.OBS_Y0), px(W.OBS_X1, W.OBS_Y1), 255, -1)
free = cv2.bitwise_and(free, outer)

dist = cv2.distanceTransform(free, cv2.DIST_L2, 5) * RES     # m

#  진입·종료 기준점은 **게이트 선 위에서 가장 여유 있는 칸**으로 잡는다.
#    고정 좌표(북 -15 / -39)로 박아 두었더니, 목을 좁히려 놓은 흰 돔이 하필
#    그 점 3 m 옆에 와서 기준점 자체가 2.36 m 로 좁아졌고, 이분법이 통로가 아니라
#    **기준점의 여유**를 재어 버렸다 (통로는 10 m 대인데 4.72 m 로 나왔다).
def best_on_line(x, ylo, yhi):
    """동 x 선 위, 북 ylo..yhi 구간에서 여유가 가장 큰 칸을 돌려준다."""
    cx = int((x - X0) / RES)
    j0, j1 = int((ylo - Y0) / RES), int((yhi - Y0) / RES)
    j = j0 + int(np.argmax(dist[j0:j1, cx]))
    return cx, j


A = best_on_line(W.OBS_X1 - 3.8, -21.0, -9.0)     # 진입구(북 -21..-9) 바로 안
B = best_on_line(W.OBS_X0 + 3.8, -45.0, -33.0)    # 종료구(북 -45..-33) 바로 안
print(f'격자 {NW} x {NH} @ {RES} m')
print(f'  진입 기준점 (동 {X0 + A[0] * RES:.1f} · 북 {Y0 + A[1] * RES:.1f}) '
      f'여유 {dist[A[1], A[0]]:.2f} m   '
      f'종료 기준점 (동 {X0 + B[0] * RES:.1f} · 북 {Y0 + B[1] * RES:.1f}) '
      f'여유 {dist[B[1], B[0]]:.2f} m')


def connected(r):
    m = (dist >= r).astype(np.uint8)
    if not (m[A[1], A[0]] and m[B[1], B[0]]):
        return False, None
    n, lab = cv2.connectedComponents(m, connectivity=8)
    return lab[A[1], A[0]] == lab[B[1], B[0]], (lab, lab[A[1], A[0]])


lo, hi = 0.1, 8.0
if not connected(lo)[0]:
    raise SystemExit('가장 느슨한 기준에서도 길이 막혔다 — 배치를 고쳐야 한다')
for _ in range(40):
    mid = (lo + hi) / 2
    if connected(mid)[0]:
        lo = mid
    else:
        hi = mid

half = lo
print()
print(f'  최소 통로 **반폭**      : {half:.2f} m')
print(f'  최소 통로  폭           : {2 * half:.2f} m')
print(f'  배 반폭 {W.BOAT_B / 2:.2f} m 대비 여유 : {half - W.BOAT_B / 2:.2f} m  '
      f'(폭 배수 {2 * half / W.BOAT_B:.2f}x)')
print(f'  선회 반경 여유 (길이 {W.BOAT_L} m 기준 제자리 선회 반경 '
      f'{math.hypot(W.BOAT_L, W.BOAT_B) / 2:.2f} m) : '
      f'{half - math.hypot(W.BOAT_L, W.BOAT_B) / 2:.2f} m')

# 통로를 그림으로
ok, (lab, cid) = connected(half * 0.98)
img = cv2.cvtColor(free, cv2.COLOR_GRAY2BGR)
img[free == 0] = (70, 70, 70)
img[(lab == cid)] = (120, 230, 120)
img[free == 0] = (70, 70, 70)
for (x, y, a, L) in W.BARRIERS:
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
    p0 = px(x - L / 2 * c, y - L / 2 * s)
    p1 = px(x + L / 2 * c, y + L / 2 * s)
    cv2.line(img, p0, p1, (40, 40, 220), 4)
for (x, y) in W.DOMES:
    cv2.circle(img, px(x, y), int(1.2 / RES), (200, 200, 200), -1)
    cv2.circle(img, px(x, y), int(1.2 / RES), (60, 60, 60), 1)
for (x, y) in W.PILLARS:
    cv2.circle(img, px(x, y), int(0.7 / RES), (20, 120, 230), -1)
cv2.circle(img, A, 7, (255, 0, 0), -1)
cv2.circle(img, B, 7, (255, 0, 255), -1)
img = cv2.flip(img, 0)                            # 북쪽이 위로
img = cv2.resize(img, None, fx=3, fy=3, interpolation=cv2.INTER_NEAREST)
cv2.putText(img, f'passable corridor  min half-width {half:.2f} m '
                 f'(boat half-beam {W.BOAT_B / 2:.2f} m)',
            (14, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (0, 0, 0), 2)
cv2.imwrite('/tmp/hy/clearance.png', img)
print('\n→ /tmp/hy/clearance.png', img.shape)

