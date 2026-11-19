#!/usr/bin/env python3
"""
marker_viz.py — 도킹 검출 RViz 시각화 마커 빌더 (pc2/scan 노드 공용)
────────────────────────────────────────────────────────────────────────
발행 토픽: /docking/debug_markers (visualization_msgs/MarkerArray)
좌표계  : livox_frame (ENU: x=전방, y=좌측), 모든 마커 z=0 평면

구성
  · DELETEALL          : 매 발행마다 선행 → stale 마커 방지
  · 누적 점군 (회색)    : 지면제거/축적 후 검출에 쓰인 점
  · 베이별              : idx 구(타겟=빨강, 나머지=주황) / wp 구(초록)
                         psi 화살표(자홍) / "bay i" 라벨
  · 상태 텍스트         : ACCUM n/N → DETECTED → STABLE → LOCKED
"""
from visualization_msgs.msg import Marker, MarkerArray
from geometry_msgs.msg import Point as GPoint
import numpy as np


def _color(m, r, g, b, a=1.0):
    m.color.r, m.color.g, m.color.b, m.color.a = float(r), float(g), float(b), float(a)


def _base(stamp, frame_id, mid, mtype):
    m = Marker()
    m.header.stamp = stamp
    m.header.frame_id = frame_id
    m.ns = 'docking'
    m.id = mid
    m.type = mtype
    m.action = Marker.ADD
    m.pose.orientation.w = 1.0
    return m


def build_markers(stamp, frame_id, points, bays, target_idx,
                  status_text, locked=False):
    """
    points      : (N,2) 누적 점군 (없으면 None/빈배열)
    bays        : find_bays(_auto) 결과 리스트 (없으면 [])
    target_idx  : 목표 베이 인덱스
    status_text : 상태 문자열 (예: 'ACCUM 240/400')
    locked      : True 면 상태색 초록, 아니면 주황
    """
    ma = MarkerArray()

    # 0) 이전 마커 전부 제거 (stale 방지)
    wipe = Marker()
    wipe.header.stamp = stamp
    wipe.header.frame_id = frame_id
    wipe.ns = 'docking'
    wipe.action = Marker.DELETEALL
    ma.markers.append(wipe)

    # 1) 누적 점군
    if points is not None and len(points):
        pm = _base(stamp, frame_id, 1, Marker.POINTS)
        pm.scale.x = pm.scale.y = 0.03
        _color(pm, 0.6, 0.6, 0.6, 0.8)
        pm.points = [GPoint(x=float(p[0]), y=float(p[1]), z=0.0) for p in points]
        ma.markers.append(pm)

    # 2) 베이 마커
    for i, b in enumerate(bays):
        is_t = (i == target_idx)
        ix, iy = float(b['idx'][0]), float(b['idx'][1])
        wx, wy = float(b['wp'][0]),  float(b['wp'][1])
        psi = float(b['psi'])

        # idx 구
        s = _base(stamp, frame_id, 10 + i, Marker.SPHERE)
        s.pose.position.x, s.pose.position.y = ix, iy
        s.scale.x = s.scale.y = s.scale.z = 0.18 if is_t else 0.12
        _color(s, 1.0, 0.15, 0.15) if is_t else _color(s, 1.0, 0.6, 0.1)
        ma.markers.append(s)

        # wp 구
        w = _base(stamp, frame_id, 30 + i, Marker.SPHERE)
        w.pose.position.x, w.pose.position.y = wx, wy
        w.scale.x = w.scale.y = w.scale.z = 0.14 if is_t else 0.10
        _color(w, 0.1, 0.9, 0.2)
        ma.markers.append(w)

        # psi 화살표 (idx 에서 진입 방향으로 0.5m)
        a = _base(stamp, frame_id, 50 + i, Marker.ARROW)
        a.points = [GPoint(x=ix, y=iy, z=0.0),
                    GPoint(x=ix + 0.5 * np.cos(psi),
                           y=iy + 0.5 * np.sin(psi), z=0.0)]
        a.scale.x, a.scale.y, a.scale.z = 0.03, 0.08, 0.0
        _color(a, 0.9, 0.2, 0.9)
        ma.markers.append(a)

        # 라벨
        t = _base(stamp, frame_id, 70 + i, Marker.TEXT_VIEW_FACING)
        t.pose.position.x, t.pose.position.y, t.pose.position.z = ix, iy, 0.35
        t.scale.z = 0.18
        _color(t, 1.0, 1.0, 1.0)
        t.text = f'bay{i}' + (' ★' if is_t else '') + (' (inf)' if b.get('inferred') else '')
        ma.markers.append(t)

    # 3) 상태 텍스트 (LiDAR 원점 위)
    st = _base(stamp, frame_id, 99, Marker.TEXT_VIEW_FACING)
    st.pose.position.x, st.pose.position.y, st.pose.position.z = 0.0, 0.0, 0.8
    st.scale.z = 0.3
    _color(st, 0.2, 1.0, 0.3) if locked else _color(st, 1.0, 0.7, 0.1)
    st.text = status_text
    ma.markers.append(st)

    return ma