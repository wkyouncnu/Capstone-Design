#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""3·15 해양누리공원 월드 (haeyangnuri.sdf) 를 만든다.

  기존 kaboat_term.sdf 는 건드리지 않는다. 이것은 **새 월드**다.

좌표계 : ENU, x = 동, y = 북, z = 0 이 수면.
원점   : 코스 한가운데.  위도 35.1862095 N · 경도 128.5665903 E
         (3·15해양누리공원 기준점 35.1859098/128.5643511 에서 동북동 215 m 앞바다)

육지 — OSM 실측 해안선을 그대로 따라 그린다 (2026-11-17 다시 함)
  옛 꼴 : 동서로 곧은 호안 두 장 (x = -95 와 x = +150). 위성지도와 전혀 닮지 않았다.
  새 꼴 : OSM way 563718797 (공원 쪽) · 563718811 (마산해양신도시 매립지 쪽) 의
          꼭짓점을 월드 좌표로 바꿔 박아 두고, 그 꺾은선을 따라 띠를 깐다.
          공원 쪽 물가선은 **북서–남동으로 비스듬**하다 — 곧은 벽이 아니다.
          코스 서남쪽(종료 게이트)이 물가선에서 가장 가깝고 30 m 다.

임무 사슬 (기존 월드와 같은 순서 — 강의자료를 고치지 않아도 되게)
  출발 → 항로추종 게이트 6쌍(지그재그) → WP1 위치유지 → 도킹(3 베이)
      → 탐색 부표 선회 → WP2 위치유지 → 장애물 구간 → 종료 게이트

  python3 make_haeyang_world.py <원본sdf> <나갈sdf>
"""
import math
import re
import sys

SRC = sys.argv[1]
DST = sys.argv[2]

# ---------------------------------------------------------------- 배 치수 (실측)
# wamv_base.urdf.xacro : 선체 실린더 길이 4 m 반지름 0.2, y = ±1.03
#                        선수 콘이 x = 2.3 + 0.45/2 까지
BOAT_L, BOAT_B = 4.9, 2.46          # 길이 · 폭 [m]

# ---------------------------------------------------------------- 위치
#  원점 — 2026-11-17 다시 잡았다.
#    옛 원점(35.1859098 / 128.5661096)은 OSM 실측 물가선에서 65 m 떨어져 있었는데,
#    물가선이 북서–남동으로 비스듬히 지나가는 바람에 **코스 남서쪽이 뭍 위**였다
#    (종료 게이트 −18 m, 코스 남서 모서리 −25 m. 음수는 물가선 안쪽이라는 뜻).
#    물가선에 직각인 바다 쪽(동북동)으로 55 m 밀어 코스 전체를 물 안에 넣었다.
#    → 가장 뭍에 가까운 코스 모서리도 물가선에서 30 m. 위성지도에 겹쳐 보면 맞는다.
LAT0, LON0 = 35.1862095, 128.5665903

RED = (0.85, 0.05, 0.05)
GREEN = (0.05, 0.60, 0.10)
YELLOW = (0.95, 0.85, 0.05)
ORANGE = (0.95, 0.45, 0.10)
WHITE = (0.93, 0.93, 0.93)
DOCKBLUE = (0.13, 0.17, 0.60)
GREY = (0.62, 0.62, 0.60)
DARKGREY = (0.35, 0.35, 0.34)
GRASS = (0.42, 0.52, 0.26)
ROCK = (0.45, 0.44, 0.41)
PARKLAND = (0.40, 0.47, 0.28)       # 공원 쪽 뭍 — 위에서 보면 잔디·수목이 섞인 녹갈색
FILLLAND = (0.56, 0.55, 0.51)       # 매립지 — 아직 포장·나지라 회갈색


def mat(r, g, b, a=1.0):
    return (f'<material><ambient>{r} {g} {b} {a}</ambient>'
            f'<diffuse>{r} {g} {b} {a}</diffuse></material>')


def box_vis(name, x, y, z, lx, ly, lz, yaw, rgb, collide=True):
    r, g, b = rgb
    col = (f'<collision name="{name}_c"><pose>{x} {y} {z} 0 0 {yaw:.5f}</pose>'
           f'<geometry><box><size>{lx} {ly} {lz}</size></box></geometry></collision>'
           ) if collide else ''
    return (f'<visual name="{name}"><pose>{x} {y} {z} 0 0 {yaw:.5f}</pose>'
            f'<geometry><box><size>{lx} {ly} {lz}</size></box></geometry>{mat(r, g, b)}'
            f'</visual>{col}')


def static_model(name, body, comment=''):
    c = f'\n    <!-- {comment} -->' if comment else ''
    return (f'{c}\n    <model name="{name}"><static>true</static>'
            f'<pose>0 0 0 0 0 0</pose>\n      <link name="link">{body}</link>\n    </model>')


def sphere_buoy(name, x, y, rgb, radius=0.75):
    r, g, b = rgb
    return f"""
    <model name="{name}">
      <static>true</static>
      <pose>{x} {y} {radius} 0 0 0</pose>
      <link name="link">
        <visual name="visual"><geometry><sphere><radius>{radius}</radius></sphere></geometry>{mat(r, g, b)}</visual>
        <collision name="collision"><geometry><sphere><radius>{radius}</radius></sphere></geometry></collision>
      </link>
    </model>"""


def cyl_buoy(name, x, y, rgb, radius=0.6, length=2.0):
    r, g, b = rgb
    return f"""
    <model name="{name}">
      <static>true</static>
      <pose>{x} {y} {length / 2.0} 0 0 0</pose>
      <link name="link">
        <visual name="visual"><geometry><cylinder><radius>{radius}</radius><length>{length}</length></cylinder></geometry>{mat(r, g, b)}</visual>
        <collision name="collision"><geometry><cylinder><radius>{radius}</radius><length>{length}</length></cylinder></geometry></collision>
      </link>
    </model>"""


DOME_R = 0.9          # 홀로 뜬 흰 돔 부표의 반지름 — 끝 펜더(FENDER_R)와 같은 크기로 둔다


def dome_buoy(name, x, y, radius=DOME_R):
    """영상의 흰 돔(버섯) 부표. 반쯤 잠긴 구."""
    r, g, b = WHITE
    return f"""
    <model name="{name}">
      <static>true</static>
      <pose>{x} {y} 0.15 0 0 0</pose>
      <link name="link">
        <visual name="visual"><geometry><sphere><radius>{radius}</radius></sphere></geometry>{mat(r, g, b)}</visual>
        <collision name="collision"><geometry><sphere><radius>{radius}</radius></sphere></geometry></collision>
      </link>
    </model>"""


#  차단벽 양 끝 돔 펜더의 반지름.
#  영상의 펜더는 큼직하지만, 1.2 m 로 두었더니 차단벽 끝을 도는 목이 5.7 m 로 좁아졌다
#  (배 폭 2.46 m · 제자리 선회 반경 2.74 m). 0.9 m 로 줄여 목을 7 m 대로 되돌린다.
FENDER_R = 0.9


def barrier(name, x, y, yaw_deg, length=22.0):
    """영상의 부유 차단벽 — '사다리'.

    2026-11-17 영상(SeaNU_[2] 200 s · 218 s)을 다시 보고 꼴을 고쳤다.
      - 흰 스티로폼 각재 한 줄 위에 **노란 가로대(사다리 발판)** 가 쭉 박혀 있다
      - 길이 방향으로 노란 가는 띠 두 줄이 지나간다
      - **양 끝을 큰 흰 돔 펜더가 받친다** — 이것이 뜨게 하는 물건이다
      - 경계 로프에 붙어 있지 않고 **물 위에 떠 있다** (양 끝에 틈이 있다)
    전에는 주황 난간을 세운 울타리꼴이라 영상과 달랐다.
    """
    yaw = math.radians(yaw_deg)
    w = 0.9                                   # 각재 폭
    v = []
    v.append(box_vis('hull', x, y, 0.22, length, w, 0.55, yaw, WHITE))
    #  길이 방향 노란 띠 두 줄
    for i, off in enumerate((-w / 2 + 0.08, w / 2 - 0.08)):
        px = x - off * math.sin(yaw)
        py = y + off * math.cos(yaw)
        v.append(box_vis(f'rail{i}', px, py, 0.52, length, 0.12, 0.08, yaw,
                         YELLOW, collide=False))
    #  노란 가로대 (사다리 발판) — 1.2 m 마다
    n = max(2, int(length // 1.2))
    for i in range(n + 1):
        s = -length / 2.0 + i * length / n
        px = x + s * math.cos(yaw)
        py = y + s * math.sin(yaw)
        v.append(box_vis(f'rung{i}', px, py, 0.52, 0.14, w + 0.1, 0.07, yaw,
                         YELLOW, collide=False))
    #  양 끝 흰 돔 펜더 — 영상에서 차단벽을 받치고 있는 그것
    for i, s in enumerate((-length / 2.0, length / 2.0)):
        px = x + s * math.cos(yaw)
        py = y + s * math.sin(yaw)
        r, g, b = WHITE
        v.append(f'<visual name="fender{i}"><pose>{px:.2f} {py:.2f} 0.15 0 0 0</pose>'
                 f'<geometry><sphere><radius>{FENDER_R}</radius></sphere></geometry>'
                 f'{mat(r, g, b)}</visual>')
        v.append(f'<collision name="fc{i}"><pose>{px:.2f} {py:.2f} 0.15 0 0 0</pose>'
                 f'<geometry><sphere><radius>{FENDER_R}</radius></sphere></geometry></collision>')
    return static_model(name, ''.join(v),
                        f'부유 차단벽(사다리) {length} m + 양 끝 돔 펜더  — 영상 그대로')


def rope_boundary(name, segs, float_gap=3.0):
    """노란 로프 + 노란 부표. 영상의 경계 로프. 충돌체 없음 — 넘으면 실격."""
    v = []
    k = 0
    for (x0, y0, x1, y1) in segs:
        L = math.hypot(x1 - x0, y1 - y0)
        yaw = math.atan2(y1 - y0, x1 - x0)
        v.append(box_vis(f'rope{k}', (x0 + x1) / 2, (y0 + y1) / 2, 0.30,
                         L, 0.07, 0.07, yaw, YELLOW, collide=False))
        n = max(1, int(L // float_gap))
        for i in range(n + 1):
            t = i / n
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r, g, b = YELLOW
            v.append(f'<visual name="f{k}_{i}"><pose>{px:.2f} {py:.2f} 0.22 0 0 0</pose>'
                     f'<geometry><sphere><radius>0.25</radius></sphere></geometry>{mat(r, g, b)}</visual>')
        k += 1
    return static_model(name, ''.join(v), '경계 로프 (노란 부표) — 넘으면 실격')


def ring(name, cx, cy, radius=5.0, n=36):
    r, g, b = ORANGE
    seg = 2.0 * math.pi * radius / n * 0.75
    v = []
    for i in range(n):
        th = 2.0 * math.pi * i / n
        px, py = cx + radius * math.cos(th), cy + radius * math.sin(th)
        v.append(f'<visual name="s{i:02d}"><pose>{px:.3f} {py:.3f} 0.3 0 0 {th + math.pi / 2:.4f}</pose>'
                 f'<geometry><box><size>{seg:.3f} 0.18 0.12</size></box></geometry>'
                 f'{mat(r, g, b, 0.45)}<transparency>0.55</transparency></visual>')
    return static_model(name, ''.join(v), f'{name} 위치유지 영역 반경 {radius} m (충돌체 없음)')


# ---------------------------------------------------------------- 도킹 스테이션
# 베이 치수를 배 치수에서 뽑는다 (교수님 질문: 스웨이로 들어갈 틈이 되는가)
BAY_W, BAY_D = 8.0, 7.0
#  벽 높이 2.0 m — 2026-11-17 교수님 확정 ("2.0 m 유지").
#  영상의 실제 파란 부잔교는 400 mm 쯤이지만, 그 높이로는 라이다가 벽을 못 잡는다.
#  2.0 m 라야 지금 가르치는 도킹 인지 예제(점군에서 벽면 검출)가 그대로 돌아간다.
#  닮은 꼴보다 예제 호환을 택한 것이다. 낮추려면 라이다 예제를 함께 고쳐야 한다.
WALL_T, WALL_H = 0.6, 2.0
DOCK_Y_IN = 22.5                      # 입구(남쪽) y
DOCK_CX = 0.0

BAYS = [(-(BAY_W + WALL_T), 'square', (0.08, 0.18, 0.80)),   # 파란 네모  (서)
        (0.0, 'circle', (0.05, 0.55, 0.20)),                 # 초록 동그라미 (가운데)
        ((BAY_W + WALL_T), 'triangle', (0.85, 0.12, 0.10))]   # 빨간 세모  (동)


def dock_model():
    v = []
    back_y = DOCK_Y_IN + BAY_D + WALL_T / 2.0
    full_w = 3 * BAY_W + 4 * WALL_T
    v.append(box_vis('back', DOCK_CX, back_y, WALL_H / 2.0, full_w, WALL_T, WALL_H, 0.0, DOCKBLUE))
    for i, off in enumerate((-1.5, -0.5, 0.5, 1.5)):
        lx = DOCK_CX + off * (BAY_W + WALL_T)
        v.append(box_vis(f'div{i}', lx, DOCK_Y_IN + BAY_D / 2.0, WALL_H / 2.0,
                         WALL_T, BAY_D, WALL_H, 0.0, DOCKBLUE))
    # 데크 — 영상의 파란 부잔교 느낌 (칸막이 사이를 메우지 않고 바깥 테두리만)
    for i, off in enumerate((-1.5, 1.5)):
        lx = DOCK_CX + off * (BAY_W + WALL_T)
        v.append(box_vis(f'deck{i}', lx, DOCK_Y_IN + BAY_D / 2.0, 0.25,
                         WALL_T * 2.5, BAY_D, 0.5, 0.0, DOCKBLUE, collide=False))

    # 표식 세 개 — 실제 영상처럼 **데크 위에 세운 입간판**이다 (벽에 바른 판이 아니다).
    #   2026-11-17 고침. 전에는 흰 판을 x 축으로 90° 돌려 놓아 **바닥에 눕는 널빤지**가
    #   됐고 (박스는 돌릴 필요가 없는데 돌렸다), 도형만 벽에 떠서 겹쳐 보였다.
    #   지금 : 주황 기둥 둘이 흰 판을 받치고, 판 남쪽 면에 도형을 붙인다.
    #   판 아래끝이 2.1 m 라 2.0 m 벽 위로 온전히 드러난다 — 벽에 걸면 카메라에서
    #   파란 벽과 흰 판이 겹쳐 읽히지 않는다.
    SIGN_W, SIGN_Z = 1.8, 3.0                     # 판 한 변 · 판 한가운데 높이
    sy = back_y - WALL_T / 2.0 - 0.12             # 뒷벽 남쪽 면 바로 앞
    for i, (bx, shape, rgb) in enumerate(BAYS):
        x = DOCK_CX + bx
        r, g, b = rgb
        for k, px in enumerate((x - 0.75, x + 0.75)):      # 받침 기둥 둘
            v.append(box_vis(f'post{i}{k}', px, sy + 0.10, 2.15, 0.12, 0.12, 2.3, 0.0,
                             ORANGE, collide=False))
        v.append(f'<visual name="plate{i}"><pose>{x} {sy} {SIGN_Z} 0 0 0</pose>'
                 f'<geometry><box><size>{SIGN_W} 0.08 {SIGN_W}</size></box></geometry>'
                 f'{mat(0.97, 0.97, 0.95)}</visual>')
        fy = sy - 0.06                            # 도형은 흰 판 남쪽 면에
        if shape == 'square':
            parts = [('<box><size>1.0 0.04 1.0</size></box>', f'{x} {fy} {SIGN_Z} 0 0 0')]
        elif shape == 'circle':
            parts = [('<cylinder><radius>0.52</radius><length>0.04</length></cylinder>',
                      f'{x} {fy} {SIGN_Z} 1.5707963 0 0')]
        else:
            #  세모 — <cone> 은 이 가제보 판에서 안 그려진다. 가로띠를 쌓아 만든다
            parts, n, base, hgt = [], 10, 1.15, 1.0
            for k in range(n):
                frac = 1.0 - (k + 0.5) / n                    # 위로 갈수록 좁게
                w = base * frac
                zc = SIGN_Z - hgt / 2.0 + (k + 0.5) * (hgt / n)
                parts.append((f'<box><size>{w:.3f} 0.04 {hgt / n:.3f}</size></box>',
                              f'{x} {fy} {zc:.3f} 0 0 0'))
        for k, (geo, pose) in enumerate(parts):
            v.append(f'<visual name="sym{i}_{k}"><pose>{pose}</pose>'
                     f'<geometry>{geo}</geometry>{mat(r, g, b)}</visual>')
    return static_model('haeyang_dock', ''.join(v),
                        f'도킹 스테이션 3 베이 — 베이 {BAY_W} W x {BAY_D} D m, 개구부 남향')


# ---------------------------------------------------------------- 육지
#  해안선 꼭짓점 — OpenStreetMap 에서 2026-11-17 받아 위 LAT0/LON0 기준 월드 좌표로
#  바꿔 적어 둔 것이다. 생성할 때 인터넷이 필요 없게 **값으로** 박아 둔다.
#    다시 받으려면 : Overpass 에 way["natural"="coastline"](35.17,128.545,35.205,128.59)
#  점 순서는 OSM 그대로다. OSM 규약으로 **진행 방향 왼쪽이 뭍**이므로,
#  띠를 깔 방향(뭍 쪽 법선)을 순서에서 바로 얻는다. 순서를 뒤집으면 바다에 땅이 깔린다.
SHORE_PARK = [       # OSM way 563718797 — 3·15 해양누리공원 쪽 (남 → 북)
    (3.4, -580.8), (-87.4, -393.4), (-143.7, -275.7), (-173.6, -212.7),
    (-183.8, -191.1), (-74.9, -106.2), (-74.0, -102.3), (-76.0, -98.5),
    (-151.4, 0.5), (-192.7, 54.7), (-167.8, 87.6), (-120.9, 149.7),
    (-62.0, 226.6), (-65.4, 229.6), (-58.5, 237.6), (-54.3, 235.8),
    (-9.3, 296.3), (37.0, 355.5),
]
SHORE_ISLAND = [     # OSM way 563718811 — 마산해양신도시 매립지 서쪽 끝 (북 → 남)
    (98.3, 335.4), (84.3, 299.5), (78.6, 259.1), (89.9, 165.5),
    (112.3, 128.5), (133.6, 71.9), (137.2, 52.3), (138.1, 47.2),
    (81.4, -205.1), (61.3, -253.9), (13.0, -300.4), (-7.7, -332.3),
    (-10.5, -371.0), (1.3, -424.8),
]

#  띠 = (뭍 쪽으로 중심까지 m, 폭 m, 두께 m, 윗면 z m, 색, 부딪히는가)
#  배가 닿을 수 있는 앞 두 줄만 충돌체를 둔다 — 뒤쪽까지 두면 물리 계산만 무거워진다.
#  **얇은 띠만 상자로 깐다.** 넓은 띠를 상자로 깔았더니 (2026-11-17 1 차) 마디마다
#  따로 돌아가는 바람에 꺾이는 자리에 혀가 삐져나오고 물 구멍이 뚫렸다.
#  넓은 뒤쪽 땅은 아래 land_poly() 가 **다각형 한 장**으로 메운다.
BANDS_PARK = [(4.0, 8.0, 1.8, 1.6, ROCK, True),            # 사석 호안
              (10.0, 6.0, 3.2, 3.0, GREY, True),           # 콘크리트 옹벽 + 산책로
              (36.0, 46.0, 3.0, 2.9, GRASS, False)]        # 공원 잔디밭
BANDS_ISLAND = [(3.0, 6.0, 2.6, 2.4, GREY, True)]          # 매립지 호안 벽


def poly_vis(name, pts, height, rgb):
    """꼭짓점 목록을 그대로 뽑아 올린 다각형 한 장. 모서리에 틈이 생기지 않는다."""
    r, g, b = rgb
    p = ''.join(f'<point>{x:.1f} {y:.1f}</point>' for x, y in pts)
    return (f'<visual name="{name}"><geometry><polyline>'
            f'<height>{height}</height>{p}</polyline></geometry>{mat(r, g, b)}</visual>')


def land_quads(pts, far_x):
    """해안선 마디마다 **사다리꼴 한 장**을 만들어 뭍을 메운다.

      왜 쪼개는가 : 물가선을 그대로 쓴 오목 다각형 한 장을 넘겼더니
      (2026-11-17 2 차) 삼각화가 군데군데 실패해 뭍에 구멍이 뚫렸다.
      마디 하나 + 먼 안쪽 선(far_x) 으로 만든 사다리꼴은 **늘 볼록**이라 안전하다.

      조각끼리는 꼭짓점의 북 좌표를 공유하므로 틈 없이 맞물린다
      (이 해안선은 북 좌표가 단조라 겹침도 없다).
    """
    out = []
    for p, q in zip(pts, pts[1:]):
        if abs(q[1] - p[1]) < 0.3:          # 동서로만 가는 마디는 넓이가 0 이다
            continue
        ring = [p, q, (far_x, q[1]), (far_x, p[1])]
        a = sum(ring[i][0] * ring[(i + 1) % 4][1] - ring[(i + 1) % 4][0] * ring[i][1]
                for i in range(4))
        out.append(ring if a > 0 else ring[::-1])     # 늘 반시계로 (뒤집히면 안 보인다)
    return out


def shore_band(prefix, pts, bands):
    """해안선 꺾은선을 따라 띠를 깐다. 마디마다 상자 하나씩, 모서리는 겹쳐서 메운다."""
    v = []
    for i, (p, q) in enumerate(zip(pts, pts[1:])):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        if L < 1.0:
            continue
        yaw = math.atan2(dy, dx)
        nx, ny = -dy / L, dx / L                  # 진행 방향 왼쪽 = 뭍 쪽
        cx, cy = (p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0
        for k, (off, w, h, ztop, col, hit) in enumerate(bands):
            #  마디를 조금 길게 잡아 꺾이는 자리에 틈이 벌어지지 않게 한다
            v.append(box_vis(f'{prefix}{i}_{k}', cx + nx * off, cy + ny * off,
                             ztop - h / 2.0, L + 4.0, w, h, yaw, col, collide=hit))
    return v


def land():
    m = []
    #  뭍 — 다각형 한 장. 물가선 자체가 다각형의 한 변이라 윤곽이 실측 그대로다.
    park = ''.join(poly_vis(f'park_fill{i}', r, 2.6, PARKLAND)
                   for i, r in enumerate(land_quads(SHORE_PARK, -700.0)))
    isle = ''.join(poly_vis(f'isle_fill{i}', r, 2.2, FILLLAND)
                   for i, r in enumerate(land_quads(SHORE_ISLAND, 700.0)))
    #  물가에 닿는 얇은 띠만 상자로 — 배가 부딪히는 것은 이 두 줄뿐이다
    m.append(static_model('park_shore',
                          park + ''.join(shore_band('p', SHORE_PARK, BANDS_PARK)),
                          '3·15 해양누리공원 쪽 해안선 (OSM way 563718797) — '
                          '공원 땅 + 사석 호안 + 콘크리트 옹벽'))
    m.append(static_model('island_shore',
                          isle + ''.join(shore_band('i', SHORE_ISLAND, BANDS_ISLAND)),
                          '마산해양신도시 매립지 서쪽 호안 (OSM way 563718811)'))
    #  남쪽 방파제는 **뺐다** — 실제로 없는 것이라 위성지도와 겹쳐 보면 어긋난다.
    #  수평선은 실제 해안선이 남서·남동으로 감싸는 것으로 대신한다.
    return m


# ---------------------------------------------------------------- 코스
#  항로추종 게이트 — 2026-11-17 교수님 지적으로 **넷에서 여섯 쌍으로 늘리고 지그재그**로 놓았다.
#    옛 꼴 : 넷이 모두 동 0 에 일직선. 직진만 하면 통과돼 조향을 볼 수 없었다.
#    새 꼴 : 5.5 m 간격 여섯 쌍, 중심이 0 → +2.6 → +2.6 → 0 → −2.6 → −2.6 (완만한 S 한 번).
#            구간마다 침로 변화가 최대 25° 다 — 조향은 보이되 과하지 않다.
#            (게이트 사이 5.5 m 에 좌우 2.6 m 이동 → atan(2.6/5.5) = 25°)
#  (북[y], 반폭, 중심 동[x])
GATES = [(-26.0, 4.5, 0.0),
         (-20.5, 4.0, 2.6),
         (-15.0, 4.0, 2.6),
         (-9.5, 4.0, 0.0),
         (-4.0, 4.0, -2.6),
         (1.5, 4.5, -2.6)]
WP1 = (0.0, 10.0)
#  선회 궤도 반경 — 부표 하나를 돌 때 그리는 원. 제자리 선회 반경 2.74 m 보다 크게 잡는다.
#  (속력을 가진 채 도는 쪽이 현실적이고, 학생 제어기가 거칠어도 들어가야 하므로)
TURN_R = 5.0

#  탐색 부표 셋 — 2026-11-17 교수님 지적("너무 뭉쳐 있어 선회 반경이 안 나온다")으로 벌렸다.
#  기준 : 부표 사이 >= 2 x TURN_R + 여유,  부표에서 구조물·경계까지 >= TURN_R + 여유.
#  옛 자리 (-19,14) (-25,6) (-21,-2) 는 서로 9~10 m 라 선회 궤도 둘이 겹쳤다.
#
#  **같은 날 두 번째 지적** — 벌려 놓고도 셋 전체가 도킹(북동)과 장애물 구간(남서)
#  사이에 끼어 있어, 돌다가 어느 한쪽에 닿을 여지가 있었다 (빨강→도킹 궤도 바깥 6.7 m,
#  노랑→장애물 경계 궤도 바깥 5.2 m). 셋 사이 간격은 그대로 두고 **통째로 (-10, +8)**
#  옮겼다. 도킹은 동쪽, 장애물은 남쪽에 있으므로 북서로 가면 **둘 다** 멀어진다.
#
#  **같은 날 세 번째 지적** — 셋 사이도 더 떨어뜨리라 하셔서 ("한 1.3 배 정도")
#  무게중심 (동 -43.3 · 북 19.3) 을 그대로 둔 채 세 점을 1.3 배로 밀어냈다.
#  셋을 통째로 옮기는 것이 아니라 **벌리는** 것이라 코스 안에서의 자리는 그대로다.
SEARCH = [(-31.0, 28.0, RED), (-57.0, 23.0, GREEN), (-42.0, 7.0, YELLOW)]
#  WP2 — 옛 자리 (-28,-9) 는 반경 5 m 링이 장애물 경계 로프(동 -30)와 진입구를 물고 있었다.
#  경계에서 동쪽으로 10 m 띄워, 링 바깥에서 경계까지 5 m 가 남게 했다.
WP2 = (-20.0, -14.0)

#  장애물 구간 — 북쪽 테두리가 탐색 부표와 붙어 있었다. 구간 전체를 **남으로 12 m** 옮겼다.
#  (안쪽 배치·통로 폭은 그대로다. 모든 y 에서 12 를 뺀 것뿐이다)
OBS_X0, OBS_X1 = -70.0, -30.0
OBS_Y0, OBS_Y1 = -46.0, -8.0

# 부유 차단벽 넷 — 2026-11-17 영상(SeaNU_[2] 195~240 s)을 다시 보고 배치를 고쳤다.
#   영상에서 본 것 : 사다리꼴 차단벽이 **경계 로프에 붙어 있지 않고 물 위에 떠 있다.**
#                    서로 나란하되 로프와는 몇 도 어긋나 있고, 좌우로 엇갈려 놓여 있다.
#                    양 끝은 큰 흰 돔 펜더가 받친다.
#   그래서 전처럼 12 m 짜리 둘을 이어 로프에 붙이지 않고, **21 m 한 장을 띄워** 놓는다.
#   막는 쪽 끝은 로프까지 2 m 만 남기고, 그 2 m 는 끝단 펜더(반지름 1.2)가 메운다.
#   요(yaw)를 90°에서 ±3~5° 흩뜨려 손으로 놓은 꼴을 낸다.
#   (x, y, yaw[deg], 길이[m])  — y 는 차단벽 한가운데
#   자리는 **끝을 도는 목**이 7 m 대로 남도록 잡았다. 열 간격 9.0 m, 기울기는 ±1.5° 안.
#   (기울기를 ±5° 로 주었더니 끝이 옆 열 쪽으로 0.9 m 씩 기울어 목이 5.7 m 로 좁아졌다)
BARRIERS = [(-34.5, -33.5, 91.2, 22.0),   # 남쪽을 막음 → 북쪽이 통로
            (-43.5, -20.5, 88.6, 22.0),   # 북쪽을 막음 → 남쪽이 통로
            (-52.5, -33.5, 91.6, 22.0),   # 남쪽을 막음
            (-61.5, -20.5, 88.8, 22.0)]   # 북쪽을 막음
# 홀로 뜬 흰 돔 — 영상에도 차단벽과 따로 떠 있는 것이 여럿이다.
#   앞 넷은 **목을 좁히는 것** : 뚫린 쪽 13.6 m 를 8.7 m 로 줄인다 (막지는 않는다)
#   뒤 다섯은 배가 지나지 않는 구석에 둔다 — 라이다에는 잡히고 길은 막지 않는다
DOMES = [(-34.5, -12.0), (-43.5, -42.0), (-52.5, -12.0), (-61.5, -42.0),
         (-32.3, -26.0), (-32.3, -40.0), (-48.0, -44.8), (-57.0, -10.2), (-66.0, -14.0)]
# 주황 기둥은 **로프 벽에 붙여** 둔다. 통로 한가운데 두면 차선을 둘로 쪼갠다.
PILLARS = [(-38.0, -8.6), (-57.0, -45.4), (-66.0, -8.6)]

GATE_IN = (-30.0, -20.0, -30.0, -10.0)       # 빨강(남) · 초록(북) — 서진 시 우현 빨강
GATE_OUT = (-70.0, -44.0, -70.0, -34.0)
ROPE_SEGS = [(OBS_X1, OBS_Y1, OBS_X0, OBS_Y1),           # 북
             (OBS_X1, OBS_Y0, OBS_X0, OBS_Y0),           # 남
             (OBS_X1, OBS_Y0, OBS_X1, -21.0),            # 동 아래
             (OBS_X1, -9.0, OBS_X1, OBS_Y1),             # 동 위 (진입구 y -21..-9)
             (OBS_X0, OBS_Y0, OBS_X0, -45.0),            # 서 아래
             (OBS_X0, -33.0, OBS_X0, OBS_Y1)]            # 서 위 (종료구 y -45..-33)


def course():
    m = []
    m.append('\n    <!-- ===== 항로추종 게이트 (남 -> 북). 우현 빨강 · 좌현 초록 ===== -->')
    for i, (gy, hw, cx) in enumerate(GATES, 1):
        m.append(sphere_buoy(f'gate{i}_red', cx + hw, gy, RED))
        m.append(sphere_buoy(f'gate{i}_green', cx - hw, gy, GREEN))

    m.append(f'\n    <!-- ===== WP1 위치유지 {WP1} ===== -->')
    m.append(sphere_buoy('wp1_buoy', WP1[0], WP1[1], ORANGE, 0.5))
    m.append(ring('wp1_area', *WP1))

    m.append(dock_model())

    m.append('\n    <!-- ===== 탐색 부표 — 빨강·초록 우현선회 / 노랑 좌현선회 ===== -->')
    for i, (x, y, c) in enumerate(SEARCH, 1):
        nm = {RED: 'red', GREEN: 'green', YELLOW: 'yellow'}[c]
        m.append(cyl_buoy(f'search_{nm}', x, y, c))

    m.append(f'\n    <!-- ===== WP2 위치유지 {WP2} ===== -->')
    m.append(sphere_buoy('wp2_buoy', WP2[0], WP2[1], ORANGE, 0.5))
    m.append(ring('wp2_area', *WP2))

    # 경계 로프 : 진입구·종료구만 끊는다
    m.append(rope_boundary('obs_boundary', ROPE_SEGS))

    m.append('\n    <!-- ===== 장애물 구간 — 긴 부유 차단벽 · 흰 돔 부표 · 주황 기둥 ===== -->')
    for i, (x, y, a, L) in enumerate(BARRIERS, 1):
        m.append(barrier(f'barrier{i}', x, y, a, L))
    for i, (x, y) in enumerate(DOMES, 1):
        m.append(dome_buoy(f'dome{i}', x, y))
    for i, (x, y) in enumerate(PILLARS, 1):
        m.append(cyl_buoy(f'pillar{i}', x, y, ORANGE, 0.7, 2.6))

    m.append('\n    <!-- ===== 진입 게이트 · 종료 게이트 ===== -->')
    m.append(sphere_buoy('obs_gate_in_red', GATE_IN[0], GATE_IN[1], RED))
    m.append(sphere_buoy('obs_gate_in_green', GATE_IN[2], GATE_IN[3], GREEN))
    m.append(sphere_buoy('goal_gate_red', GATE_OUT[0], GATE_OUT[1], RED))
    m.append(sphere_buoy('goal_gate_green', GATE_OUT[2], GATE_OUT[3], GREEN))
    return m


# ---------------------------------------------------------------- 쓰기
with open(SRC, encoding='utf-8') as f:
    src = f.read()

cut = src.find('<model name="obs_sph_1L">')
if cut < 0:
    raise SystemExit('원본에서 자를 자리를 못 찾음')
head = src[:cut].rstrip()
#  월드 이름은 파일 이름(haeyangnuri)과 **반드시** 같아야 한다.
#  다르면 vrx_gz 가 /world/<파일이름>/… 로 다리를 놓는데 가제보는 다른 이름으로
#  내보내므로 센서 토픽(GPS·카메라·라이다)이 하나도 안 나온다. 원본 이름이
#  sydney_regatta 일 때도, kaboat_term 일 때도 맞게 정규식으로 바꾼다.
head = re.sub(r'<world name="[^"]*">', '<world name="haeyangnuri">', head, count=1)
head = head.replace('<latitude_deg>-33.724223</latitude_deg>',
                    f'<latitude_deg>{LAT0}</latitude_deg>')
head = head.replace('<longitude_deg>150.679736</longitude_deg>',
                    f'<longitude_deg>{LON0}</longitude_deg>')
head = head.replace('Estimated latitude/longitude of sydneyregatta\n         from satellite imagery',
                    '3·15 해양누리공원 (경남 창원시 마산합포구) 앞 수역\n'
                    '         원점 = 코스 한가운데. OSM 공원 기준점에서 동쪽 160 m')

body = ['\n\n    <!-- ================= 육지 (OSM 실측 지형을 단순화) ================= -->']
body += land()
body.append('\n\n    <!-- ================= 코스 ================= -->')
body += course()
body.append('\n    <!-- ======================================================== -->\n')

out = head + ''.join(body) + '  </world>\n</sdf>\n'
with open(DST, 'w', encoding='utf-8') as f:
    f.write(out)

print(f'쓴 파일 : {DST}   ({len(out)} 바이트, 모델 {out.count("<model name=")} 개)')
print(f'위도/경도: {LAT0} / {LON0}')
print(f'배       : 길이 {BOAT_L} m · 폭 {BOAT_B} m')
print(f'도킹 베이: {BAY_W} W x {BAY_D} D m')
print(f'  선수 진입 좌우 여유 : {(BAY_W - BOAT_B) / 2:.2f} m')
print(f'  선수 진입 깊이 여유 : {BAY_D - BOAT_L:.2f} m')
print(f'  스웨이(옆) 진입 여유: {(BAY_W - BOAT_L) / 2:.2f} m   (개구부 {BAY_W} m 대 선체 길이 {BOAT_L} m)')
print(f'게이트 {len(GATES)} 쌍 — 폭 {[2 * hw for _, hw, _ in GATES]} m  → 좌우 여유 '
      f'{[round((2 * hw - BOAT_B) / 2, 2) for _, hw, _ in GATES]} m')
_path = [(0.0, -32.0)] + [(cx, gy) for gy, _, cx in GATES] + [WP1]   # 출발선 → 게이트 → WP1
_turn = []
for _i in range(1, len(_path) - 1):
    (_x0, _y0), (_x1, _y1), (_x2, _y2) = _path[_i - 1], _path[_i], _path[_i + 1]
    _a = math.degrees(math.atan2(_x1 - _x0, _y1 - _y0))
    _b = math.degrees(math.atan2(_x2 - _x1, _y2 - _y1))
    _turn.append(round(_b - _a, 1))
print(f'  지그재그 — 게이트마다 침로 변화 {_turn} deg  (가장 큰 것 '
      f'{max(abs(_t) for _t in _turn):.1f} deg)')


# ---------------------------------------------------------------- 선회·경계 여유 검산
#  2026-11-17 교수님 지적("너무 뭉쳐 있다") 뒤에 넣었다. 자리를 옮길 때마다 여기서 확인한다.
def _d(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


NAMES = ['빨강', '초록', '노랑']
DOCK_HW = (3 * BAY_W + 4 * WALL_T) / 2.0
print(f'\n탐색 부표 선회 — 궤도 반경 {TURN_R} m 로 보았을 때')
for i in range(3):
    for j in range(i + 1, 3):
        d = _d(SEARCH[i][0], SEARCH[i][1], SEARCH[j][0], SEARCH[j][1])
        print(f'  {NAMES[i]}~{NAMES[j]} 사이 {d:5.1f} m   → 궤도 둘 사이 {d - 2 * TURN_R:4.1f} m')
NEAR = {'도킹 서쪽 모서리': (DOCK_CX - DOCK_HW, DOCK_Y_IN),
        '도킹 동쪽 모서리': (DOCK_CX + DOCK_HW, DOCK_Y_IN),
        '장애물 북동 모서리': (OBS_X1, OBS_Y1),
        'WP1 부표': WP1, 'WP2 부표': WP2}
for i, (x, y, _c) in enumerate(SEARCH):
    nm, dmin = min(((k, _d(x, y, *p)) for k, p in NEAR.items()), key=lambda t: t[1])
    print(f'  {NAMES[i]} 부표에 가장 가까운 것 : {nm} {dmin:5.1f} m  → 궤도 바깥 {dmin - TURN_R:4.1f} m')
print(f'WP2 위치유지 링(반경 5 m) → 장애물 경계(동 {OBS_X1:.0f}) 까지 '
      f'{abs(WP2[0] - OBS_X1) - 5.0:.1f} m 남음')
print(f'WP2 → 진입 게이트 한가운데 ({GATE_IN[0]:.0f}, {(GATE_IN[1] + GATE_IN[3]) / 2:.0f}) '
      f'{_d(WP2[0], WP2[1], GATE_IN[0], (GATE_IN[1] + GATE_IN[3]) / 2):.1f} m')


#  코스가 정말 물 위에 있는가 — 실측 물가선까지의 거리를 마디마다 재어 가장 작은 것을 쓴다
def _to_shore(qx, qy, pts):
    best = 1e9
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        t = max(0.0, min(1.0, ((qx - ax) * dx + (qy - ay) * dy) / L2))
        best = min(best, math.hypot(qx - ax - t * dx, qy - ay - t * dy))
    return best


print('\n실측 물가선(OSM)까지 — 음수면 뭍 위라는 뜻이다')
_CHK = {'종료 게이트 남': (OBS_X0, OBS_Y0), '종료 게이트 북': (GATE_OUT[0], GATE_OUT[3]),
        '장애물 북서 모서리': (OBS_X0, OBS_Y1), '탐색 초록 부표': SEARCH[1][:2],
        '출발선': (0.0, -32.0), 'WP1': WP1, '도킹 뒷벽': (0.0, DOCK_Y_IN + BAY_D)}
for k, (x, y) in _CHK.items():
    print(f'  {k:16s} 공원 쪽 {_to_shore(x, y, SHORE_PARK):6.1f} m   '
          f'매립지 쪽 {_to_shore(x, y, SHORE_ISLAND):6.1f} m')
