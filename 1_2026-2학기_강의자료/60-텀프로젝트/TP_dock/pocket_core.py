#!/usr/bin/env python3
"""pocket_core.py — 대회 코드의 포켓 검출 알고리즘을 그대로 떼어낸 것

출처
  70-대회코드2026/code/ros/usv_260921_ws/src/ugv_docking_pkg/ugv_docking_pkg/
  docking_3bay_pc2_ransac_flight_ver2.py  의 DockingDetectorPC2Ransac.find_bays_pocket

왜 떼어냈는가
  원본은 메서드라 self.파라미터를 읽는다. 월드가 달라도 **식은 하나도 고치지 않고**
  파라미터만 갈아 끼우려면 함수로 떼어 놓는 쪽이 맞다.
  알고리즘 본문(1~5 단계)은 원본과 한 줄씩 같다. 바꾼 것은 다음 둘뿐이다.
    - self.xxx  ->  인자 par.xxx
    - 배경 제거 띠의 -3.0 을 par.front_cut 으로 뺐다 (원본은 숫자가 박혀 있다)
      UGV 격벽은 0.5 m 돌출, 해양누리 격벽은 7.3 m 돌출이라 이 값이 대비를 만든다

알고리즘 요약 (원본 주석대로)
  1) 먼 점만으로 안쪽 벽 직선을 RANSAC -> PCA 로 다듬는다
  2) 벽 방향(s) 칸마다 돌출량 프로파일 prof[k] 를 만든다 (+가 센서 쪽)
  3) prof 가 낮은 칸 = 포켓, 높은 칸 = 격벽
  4) 연속 구간 가운데 폭이 맞고 양 옆에 격벽이 있는 것만 후보
  5) 후보가 셋을 넘으면 폭이 가장 고른 연속 셋
"""
import math
from dataclasses import dataclass

import numpy as np


@dataclass
class PocketPar:
    """find_bays_pocket 이 읽는 값 전부. 기본값은 **해양누리 월드** 기준이다"""
    ransac_iter: int = 250
    wall_thr: float = 0.30          # 대회 0.10 — 8 m 칸, 20 m 거리에 맞춰 키움
    bin_w: float = 0.40             # 대회 0.10
    pocket_depth_min: float = 2.0   # 대회 0.35 — 격벽 돌출 7.3 m
    bay_w_min: float = 5.0          # 대회 0.55 — 칸 폭 8.0 m
    bay_w_max: float = 11.0         # 대회 1.80
    approach_dist: float = 6.0      # 대회 0.80 — 선체 길이 4.9 m
    front_cut: float = 3.0          # 원본에 박혀 있던 -3.0


def find_bays_pocket(points, par: PocketPar, rng):
    """(N,2) 점 → 베이 리스트 [{'idx','wp','psi','width'}] (벽 방향 순서)"""
    bays = []
    P = np.asarray(points, dtype=float)
    if len(P) < 30: return bays

    # 1) 안쪽 벽 직선 — 먼 점들만으로 RANSAC
    dist = np.linalg.norm(P, axis=1)
    far = P[dist > np.percentile(dist, 40)]
    if len(far) < 10: return bays
    M = len(far)
    i1 = rng.integers(0, M, par.ransac_iter)
    i2 = rng.integers(0, M, par.ransac_iter)
    ok = i1 != i2
    if not ok.any(): return bays
    p1 = far[i1[ok]]; v = far[i2[ok]] - p1
    L = np.linalg.norm(v, axis=1)
    ok2 = L > 1.0                      # 너무 가까운 두 점은 방향이 불안정
    if not ok2.any(): return bays
    p1, vh = p1[ok2], v[ok2] / L[ok2, None]
    nh_all = np.stack([-vh[:, 1], vh[:, 0]], axis=1)
    cst = -np.einsum('hd,hd->h', nh_all, p1)
    d = np.abs(far @ nh_all.T + cst[None, :])
    h = int(np.argmax((d < par.wall_thr).sum(axis=0)))
    inl = far[d[:, h] < par.wall_thr]
    if len(inl) < 10: return bays
    q = inl - inl.mean(axis=0)
    _w, _V = np.linalg.eigh(q.T @ q)
    v_hat = _V[:, np.argmax(_w)]
    p0 = inl.mean(axis=0)
    n_hat = np.array([-v_hat[1], v_hat[0]])
    if np.dot(n_hat, p0) < 0: n_hat = -n_hat     # 법선을 센서 반대(안쪽)로

    # 2) 벽 방향 깊이 프로파일 (돌출량, +가 센서 쪽)
    s = (P - p0) @ v_hat
    dep = (P - p0) @ n_hat
    m = (dep > -par.front_cut) & (dep < 0.4)     # 벽 뒤 배경 제거
    s, dep = s[m], dep[m]
    if len(s) < 30: return bays
    bins = np.arange(s.min(), s.max() + par.bin_w, par.bin_w)
    bidx = np.clip(np.digitize(s, bins) - 1, 0, len(bins) - 1)
    prof = np.full(len(bins), np.nan)
    for k in range(len(bins)):
        vv = dep[bidx == k]
        if len(vv) >= 3: prof[k] = -np.percentile(vv, 5)
    okb = ~np.isnan(prof)
    if okb.sum() < 8: return bays

    # 3) 포켓(낮음) vs 격벽(높음)
    tip = np.nanpercentile(prof, 90); base = np.nanpercentile(prof, 10)
    depth = tip - base
    if depth < par.pocket_depth_min: return bays
    is_bay = okb & (prof < base + depth * 0.5)

    # 4) 연속 구간 → 포켓 후보 (양 옆에 격벽이 있어야 포켓)
    runs = []; k = 0
    while k < len(is_bay):
        j = k
        while j < len(is_bay) and is_bay[j] == is_bay[k]: j += 1
        runs.append((bool(is_bay[k]), k, j)); k = j
    cands = []
    for b, a, z in runs:
        if not b: continue
        w = (z - a) * par.bin_w
        if not (par.bay_w_min <= w <= par.bay_w_max): continue
        if a == 0 or z >= len(is_bay): continue   # 프로파일 끝 = 개방부
        cands.append((a, z, w))

    # 5) 후보가 3개를 넘으면(옆 안벽의 틈 등) 폭이 가장 고른 연속 3개
    NB = 3
    if len(cands) > NB:
        best, bs = None, 1e9
        for k in range(len(cands) - NB + 1):
            grp = cands[k:k + NB]
            ws = np.array([g[2] for g in grp])
            sp = float(ws.max() - ws.min())
            if sp < bs: bs, best = sp, grp
        cands = best

    for a, z, w in cands[:NB]:
        sc = (bins[a] + bins[min(z, len(bins) - 1)]) / 2.0
        inner = p0 + v_hat * sc                       # 포켓 안쪽 벽 중앙
        wp = inner - n_hat * par.approach_dist        # 입구 앞 접근점
        bays.append({'idx': inner, 'wp': wp,
                     'psi': float(math.atan2(n_hat[1], n_hat[0])), 'width': w})
    return bays


def profile_debug(points, par: PocketPar, rng):
    """튜닝용 — 프로파일과 분류를 그대로 돌려준다 (알고리즘은 위와 같다)"""
    P = np.asarray(points, dtype=float)
    out = {}
    dist = np.linalg.norm(P, axis=1)
    far = P[dist > np.percentile(dist, 40)]
    M = len(far)
    i1 = rng.integers(0, M, par.ransac_iter); i2 = rng.integers(0, M, par.ransac_iter)
    ok = i1 != i2
    p1 = far[i1[ok]]; v = far[i2[ok]] - p1
    L = np.linalg.norm(v, axis=1); ok2 = L > 1.0
    p1, vh = p1[ok2], v[ok2] / L[ok2, None]
    nh_all = np.stack([-vh[:, 1], vh[:, 0]], axis=1)
    cst = -np.einsum('hd,hd->h', nh_all, p1)
    d = np.abs(far @ nh_all.T + cst[None, :])
    h = int(np.argmax((d < par.wall_thr).sum(axis=0)))
    inl = far[d[:, h] < par.wall_thr]
    q = inl - inl.mean(axis=0)
    _w, _V = np.linalg.eigh(q.T @ q)
    v_hat = _V[:, np.argmax(_w)]; p0 = inl.mean(axis=0)
    n_hat = np.array([-v_hat[1], v_hat[0]])
    if np.dot(n_hat, p0) < 0: n_hat = -n_hat
    s = (P - p0) @ v_hat; dep = (P - p0) @ n_hat
    m = (dep > -par.front_cut) & (dep < 0.4)
    s, dep = s[m], dep[m]
    bins = np.arange(s.min(), s.max() + par.bin_w, par.bin_w)
    bidx = np.clip(np.digitize(s, bins) - 1, 0, len(bins) - 1)
    prof = np.full(len(bins), np.nan)
    for k in range(len(bins)):
        vv = dep[bidx == k]
        if len(vv) >= 3: prof[k] = -np.percentile(vv, 5)
    out.update(far_n=len(far), inl_n=len(inl), v_hat=v_hat, n_hat=n_hat, p0=p0,
               bins=bins, prof=prof, masked_n=len(s))
    return out
