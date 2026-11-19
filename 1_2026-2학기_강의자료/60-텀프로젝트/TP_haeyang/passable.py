#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""passable.py — 배의 **길이와 폭**으로 코스를 실제로 빠져나갈 수 있는가를 잰다

    python3 passable.py                # 숫자만
    python3 passable.py --png out.png  # 그림까지 (matplotlib 필요)

clearance.py 와 다른 점
    clearance.py 는 배를 **점**으로 보고 통로의 폭만 잰다.
    그것만으로는 모자란다 — 배는 길이 4.9 m · 폭 2.46 m 의 **사각형**이고, 목을 돌 때
    선수·선미 모서리가 바깥으로 휘둘린다. 이 파일은 그 사각형을 길을 따라 실제로 밀어 본다.

하는 일
    1) 장애물 구간(차단벽·펜더·돔·기둥·경계 로프)과 항로추종 게이트 열을 0.1 m 격자로 그린다
    2) 장애물에서 멀리 떨어지는 길을 하나 찾는다 (여유가 클수록 싼 Dijkstra)
    3) 그 길 위의 점마다 선체 사각형을 **진행 방향으로 놓고**, 테두리에서 가장 가까운
       장애물까지의 거리를 잰다 — 그 최솟값이 "실제로 남는 틈" 이다
    4) 길의 가장 급한 굽이(선회 반경)와, 그것을 돌 때 필요한 선수동요 각속도를 낸다

판정에 쓰는 세 숫자
    선체 최소 여유   사각형 테두리에서 장애물까지. 이만큼이 **허용되는 경로 오차**다
    최소 선회 반경   이보다 작게 돌 수 있어야 한다
    keep-out 한계    회피기가 장애물을 이만큼 부풀려도 길이 남는 최대 반경 (= 통로 반폭)

좌표 : 가제보 ENU — 동 x, 북 y.  숫자의 원본은 make_haeyang_world.py 다
"""
import argparse
import heapq
import io
import contextlib
import math
import os
import sys
import tempfile

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'TP_vrx_lite', 'my_world_원본.sdf')

#  생성기를 모듈로 끌어온다. 생성기는 불러오는 순간 월드를 써내므로 버릴 자리를 준다
_argv = sys.argv
sys.argv = ['make_haeyang_world', SRC, os.path.join(tempfile.mkdtemp(), 'throwaway.sdf')]
sys.path.insert(0, HERE)
with contextlib.redirect_stdout(io.StringIO()):
    import make_haeyang_world as W                                   # noqa: E402
sys.argv = _argv

RES = 0.1
L, B = W.BOAT_L, W.BOAT_B               # 4.9 m · 2.46 m


class Grid:
    """동 x0..x1 · 북 y0..y1 을 RES 격자로. free[j, i] = True 면 물."""

    def __init__(self, x0, x1, y0, y1):
        self.x0, self.y0 = x0, y0
        self.nx = int(round((x1 - x0) / RES)) + 1
        self.ny = int(round((y1 - y0) / RES)) + 1
        self.X, self.Y = np.meshgrid(x0 + RES * np.arange(self.nx), y0 + RES * np.arange(self.ny))
        self.free = np.ones((self.ny, self.nx), bool)

    def circle(self, cx, cy, r):
        self.free &= (self.X - cx) ** 2 + (self.Y - cy) ** 2 > r * r

    def box(self, cx, cy, lx, ly, yaw):
        c, s = math.cos(yaw), math.sin(yaw)
        u = (self.X - cx) * c + (self.Y - cy) * s
        v = -(self.X - cx) * s + (self.Y - cy) * c
        self.free &= ~((np.abs(u) <= lx / 2) & (np.abs(v) <= ly / 2))

    def segment(self, x0, y0, x1, y1, half=0.15):
        d = math.hypot(x1 - x0, y1 - y0)
        self.box((x0 + x1) / 2, (y0 + y1) / 2, d, 2 * half, math.atan2(y1 - y0, x1 - x0))

    def distance(self):
        """각 칸에서 가장 가까운 장애물 칸까지 [m] — 두 번 훑는 정확한 유클리드 거리변환"""
        try:
            from scipy import ndimage
            return ndimage.distance_transform_edt(self.free) * RES
        except Exception:                                    # scipy 가 없으면 cv2
            import cv2
            return cv2.distanceTransform(self.free.astype(np.uint8), cv2.DIST_L2, 5) * RES

    def ij(self, x, y):
        return int(round((x - self.x0) / RES)), int(round((y - self.y0) / RES))


def route(g, dist, a, b, rmin):
    """a -> b. 여유가 rmin 보다 작은 칸은 못 지난다. 여유가 클수록 싸다"""
    ia, ja = g.ij(*a)
    ib, jb = g.ij(*b)
    cost = np.where(dist >= rmin, 1.0 + 25.0 / np.maximum(dist, 0.1) ** 2, np.inf)
    best = np.full(dist.shape, np.inf)
    prev = {}
    best[ja, ia] = 0.0
    pq = [(0.0, ia, ja)]
    nb = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
          (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)]
    while pq:
        c, i, j = heapq.heappop(pq)
        if (i, j) == (ib, jb):
            break
        if c > best[j, i]:
            continue
        for di, dj, w in nb:
            i2, j2 = i + di, j + dj
            if 0 <= i2 < g.nx and 0 <= j2 < g.ny and np.isfinite(cost[j2, i2]):
                c2 = c + w * cost[j2, i2]
                if c2 < best[j2, i2]:
                    best[j2, i2] = c2
                    prev[(i2, j2)] = (i, j)
                    heapq.heappush(pq, (c2, i2, j2))
    if (ib, jb) not in prev:
        return None
    p = [(ib, jb)]
    while p[-1] != (ia, ja):
        p.append(prev[p[-1]])
    p = np.array(p[::-1], float)
    return np.c_[g.x0 + RES * p[:, 0], g.y0 + RES * p[:, 1]]


def smooth(path, win_m=4.0, step=0.25):
    """같은 간격으로 다시 뽑고 이동평균으로 다듬는다 (끝점은 붙잡아 둔다)"""
    s = np.r_[0, np.cumsum(np.hypot(*np.diff(path, axis=0).T))]
    si = np.arange(0, s[-1], step)
    p = np.c_[np.interp(si, s, path[:, 0]), np.interp(si, s, path[:, 1])]
    n = max(3, int(win_m / step) | 1)
    k = np.ones(n) / n
    pad = n // 2
    q = np.c_[np.convolve(np.pad(p[:, 0], pad, 'edge'), k, 'valid'),
              np.convolve(np.pad(p[:, 1], pad, 'edge'), k, 'valid')]
    return q


def sweep(g, dist, path):
    """길 위의 점마다 선체 사각형을 진행 방향으로 놓고 테두리의 최소 여유를 잰다"""
    d = np.gradient(path, axis=0)
    th = np.unwrap(np.arctan2(d[:, 1], d[:, 0]))
    ds = np.hypot(d[:, 0], d[:, 1])
    kappa = np.gradient(th) / np.maximum(ds, 1e-6)
    e = np.r_[np.arange(-L / 2, L / 2, 0.1), L / 2]
    f = np.r_[np.arange(-B / 2, B / 2, 0.1), B / 2]
    bx = np.r_[e, e, np.full(f.size, -L / 2), np.full(f.size, L / 2)]
    by = np.r_[np.full(e.size, -B / 2), np.full(e.size, B / 2), f, f]
    clr = np.empty(len(path))
    for k, (x, y) in enumerate(path):
        c, s = math.cos(th[k]), math.sin(th[k])
        hx, hy = x + bx * c - by * s, y + bx * s + by * c
        i = np.clip(np.round((hx - g.x0) / RES).astype(int), 0, g.nx - 1)
        j = np.clip(np.round((hy - g.y0) / RES).astype(int), 0, g.ny - 1)
        clr[k] = dist[j, i].min()
    return th, kappa, clr


def report(title, g, dist, path, th, kappa, clr, u=1.0):
    k = int(np.argmin(clr))
    #  굽이는 2 m 창으로 평균해 격자 톱니를 지운다
    n = 9
    kap = np.convolve(np.abs(kappa), np.ones(n) / n, 'same')
    kc = int(np.argmax(kap[n:-n])) + n
    rmin = 1.0 / max(kap[kc], 1e-6)
    cen = np.array([dist[g.ij(x, y)[1], g.ij(x, y)[0]] for x, y in path])
    print(f'\n[{title}]')
    print(f'  길 길이                    : {np.hypot(*np.diff(path, axis=0).T).sum():.1f} m')
    kh = int(np.argmin(cen))
    print(f'  통로 반폭 (길 중심선 최소) : {cen.min():.2f} m   → 통로 폭 {2 * cen.min():.2f} m'
          f'   (동 {path[kh, 0]:.1f} · 북 {path[kh, 1]:.1f})')
    print(f'  **선체 최소 여유**         : {clr[k]:.2f} m   (동 {path[k, 0]:.1f} · 북 {path[k, 1]:.1f})')
    print(f'     배를 점으로 볼 때의 여유 : {cen.min() - B / 2:.2f} m  (반폭 {B / 2:.2f} m 만 뺀 값)')
    print(f'  최소 선회 반경             : {rmin:.1f} m   (동 {path[kc, 0]:.1f} · 북 {path[kc, 1]:.1f})')
    print(f'     {u:.1f} m/s 로 돌 때 필요한 선수동요 각속도 : {math.degrees(u / rmin):.1f} deg/s')
    return dict(clr=clr[k], at=path[k], rmin=rmin, half=cen.min())


def build_obstacle():
    g = Grid(W.OBS_X0 - 6, W.OBS_X1 + 12, W.OBS_Y0 - 3, W.OBS_Y1 + 3)
    for (x, y, a, ln) in W.BARRIERS:
        r = math.radians(a)
        g.box(x, y, ln, 0.9, r)
        for s in (-ln / 2, ln / 2):
            g.circle(x + s * math.cos(r), y + s * math.sin(r), W.FENDER_R)
    for (x, y) in W.DOMES:
        g.circle(x, y, W.DOME_R)
    for (x, y) in W.PILLARS:
        g.circle(x, y, 0.6)
    for sg in W.ROPE_SEGS:                 # 로프는 충돌체가 없지만 넘으면 실격 — 벽으로 본다
        g.segment(*sg)
    for (rx, ry, gx, gy) in (W.GATE_IN, W.GATE_OUT):
        g.circle(rx, ry, 0.75)
        g.circle(gx, gy, 0.75)
    a = (W.WP2[0], W.WP2[1])                                        # WP2 에서 출발
    b = (W.OBS_X0 - 4.0, (W.GATE_OUT[1] + W.GATE_OUT[3]) / 2)       # 종료 게이트 4 m 밖
    return g, a, b


def build_gates():
    ys = [gy for gy, _, _ in W.GATES]
    g = Grid(-12, 12, -36, W.WP1[1] + 2)
    for gy, hw, cx in W.GATES:
        g.circle(cx - hw, gy, 0.75)
        g.circle(cx + hw, gy, 0.75)
        #  게이트 바깥으로 도는 길은 길이 아니다 — 부표 바깥을 벽으로 막는다
        g.segment(cx - hw - 12, gy, cx - hw, gy)
        g.segment(cx + hw, gy, cx + hw + 12, gy)
    return g, (0.0, -32.0), (W.WP1[0], W.WP1[1]), ys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--png', default='')
    ap.add_argument('--speed', type=float, default=1.0)
    a = ap.parse_args()

    print(f'배 : 길이 {L} m · 폭 {B} m   (반폭 {B / 2:.2f} m, 제자리 선회 때 휩쓰는 반경 '
          f'{math.hypot(L, B) / 2:.2f} m)')
    out = {}

    g1, s1, e1, _ = build_gates()
    d1 = g1.distance()
    p1 = smooth(route(g1, d1, s1, e1, B / 2), 3.0)
    out['gates'] = (g1, d1, p1) + sweep(g1, d1, p1)
    r1 = report('항로추종 — 출발선 → 게이트 6 쌍 → WP1', g1, d1, p1, *out['gates'][3:], u=a.speed)

    g2, s2, e2 = build_obstacle()
    d2 = g2.distance()
    p2 = smooth(route(g2, d2, s2, e2, B / 2), 4.0)
    out['obs'] = (g2, d2, p2) + sweep(g2, d2, p2)
    r2 = report('장애물회피 — WP2 → 진입 게이트 → 차단벽 넷 → 종료 게이트', g2, d2, p2,
                *out['obs'][3:], u=a.speed)

    print('\n[판정]')
    for nm, r in (('항로추종', r1), ('장애물회피', r2)):
        ok = '지나감' if r['clr'] > 0 else '**못 지나감**'
        print(f'  {nm:6s} : {ok}.  경로 오차를 {r["clr"]:.2f} m 까지 허용함. '
              f'keep-out 반경은 {r["half"]:.2f} m 보다 작아야 길이 남음')

    if a.png:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
        fig, axs = plt.subplots(1, 2, figsize=(15, 8.2), gridspec_kw=dict(width_ratios=[1, 2.3]))
        for ax, key, ttl, r in ((axs[0], 'gates', 'Gates (start -> WP1)', r1),
                                (axs[1], 'obs', 'Obstacle section (WP2 -> goal)', r2)):
            g, dist, path, th, kappa, clr = out[key]
            ext = [g.x0, g.x0 + RES * (g.nx - 1), g.y0, g.y0 + RES * (g.ny - 1)]
            ax.imshow(np.where(g.free, np.minimum(dist, 6.0), np.nan), origin='lower', extent=ext,
                      cmap='Blues', vmin=0, vmax=6)
            ax.imshow(np.where(g.free, np.nan, 1.0), origin='lower', extent=ext, cmap='gray',
                      vmin=0, vmax=2)
            ax.plot(path[:, 0], path[:, 1], '-', color='#d97706', lw=1.6)
            for k in range(0, len(path), 12):
                c, s = math.cos(th[k]), math.sin(th[k])
                bx = np.array([-L / 2, L / 2, L / 2, -L / 2, -L / 2])
                by = np.array([-B / 2, -B / 2, B / 2, B / 2, -B / 2])
                ax.plot(path[k, 0] + bx * c - by * s, path[k, 1] + bx * s + by * c,
                        '-', color='#dc2626', lw=0.9)
            ax.plot(*r['at'], 'o', ms=13, mfc='none', mec='#dc2626', mew=2)
            ax.set_title(f'{ttl}\nmin hull clearance {r["clr"]:.2f} m, '
                         f'corridor half-width {r["half"]:.2f} m, min turn radius {r["rmin"]:.1f} m',
                         fontsize=11)
            ax.set_xlabel('east x [m]')
            ax.set_ylabel('north y [m]')
            ax.set_aspect('equal')
        fig.tight_layout()
        fig.savefig(a.png, dpi=110)
        print(f'\n그림 저장 : {a.png}')


if __name__ == '__main__':
    main()
