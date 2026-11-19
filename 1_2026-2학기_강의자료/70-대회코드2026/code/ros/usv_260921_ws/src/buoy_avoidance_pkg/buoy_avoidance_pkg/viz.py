"""viz.py — 디버그 오버레이 (카메라 이미지 + BEV)."""
import math

import cv2
import numpy as np

from .core import RED, GREEN

_BGR = {RED: (0, 0, 255), GREEN: (0, 200, 0), 'unknown': (255, 0, 255)}


def draw_overlay(bgr, clusters, cls, camera, plan=None):
    """이미지에 클러스터 투영 위치/판정 색/패치 크기를 그린다."""
    img = bgr.copy()
    for c, (lab, u, v, rpx, fr, fg) in zip(clusters, cls):
        if u < 0:
            continue
        r = max(3, int(rpx))
        cv2.circle(img, (int(u), int(v)), r, _BGR[lab], 2)
        cv2.putText(img, f'{math.hypot(c[0], c[1]):.1f}', (int(u) - 10, int(v) - r - 3), 0, 0.4, _BGR[lab], 1)
    if plan is not None and plan.get('target') is not None:
        tx, ty = plan['target']
        uv, ok = camera.project(np.array([[tx, ty, 0.2]]))
        if ok[0]:
            cv2.drawMarker(img, (int(uv[0, 0]), int(uv[0, 1])), (0, 255, 255), cv2.MARKER_CROSS, 20, 2)
    return img


def draw_bev(tracks, plan, size=480, half_range=12.0):
    """BEV: 위쪽이 전방(+x), 왼쪽이 +y. tracks = [(id, x, y, color, hits)]."""
    img = np.full((size, size, 3), 255, np.uint8)
    s = size / (2 * half_range)
    ox, oy = size // 2, int(size * 0.85)

    def pt(x, y):
        return int(ox - y * s), int(oy - x * s)

    for rr in range(2, int(half_range * 1.5), 2):
        cv2.circle(img, (ox, oy), int(rr * s), (230, 230, 230), 1)
    cv2.circle(img, (ox, oy), 4, (0, 0, 0), -1)
    for _, x, y, col, _ in tracks:
        cv2.circle(img, pt(x, y), max(3, int(0.4 * s)), _BGR.get(col, (255, 0, 255)), -1)
    if plan is not None:
        for g in plan.get('gates', []):
            cv2.line(img, pt(*g[2]), pt(*g[3]), (150, 150, 150), 1)
            cv2.circle(img, pt(g[0], g[1]), 3, (0, 0, 0), -1)
        if plan.get('target') is not None:
            cv2.line(img, (ox, oy), pt(*plan['target']), (0, 180, 255), 2)
        b = plan.get('bearing', 0.0)
        L = 4.0
        cv2.arrowedLine(img, (ox, oy), pt(L * math.cos(b), L * math.sin(b)), (255, 0, 0), 2, tipLength=0.15)
        side = plan.get('red_left')
        txt = 'red=?' if side is None else ('red=LEFT' if side else 'red=RIGHT')
        cv2.putText(img, f"{plan.get('mode', '')} v={plan.get('speed', 0):.2f} "
                         f"brg={math.degrees(b):+.0f}deg {txt}", (5, 18), 0, 0.5, (0, 0, 0), 1)
    return img
