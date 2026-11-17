#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""3·15 해양누리공원 월드 (haeyangnuri.sdf) 를 만든다.

  기존 kaboat_term.sdf 는 건드리지 않는다. 이것은 **새 월드**다.

좌표계 : ENU, x = 동, y = 북, z = 0 이 수면.
원점   : 코스 한가운데.  위도 35.1859098 N · 경도 128.5661096 E
         (OSM 에서 받은 3·15해양누리공원 기준점 35.1859098/128.5643511 에서 동쪽 160 m)

육지 — OSM 실측 지형을 단순화
  공원 호안(서쪽) : 월드 x = -95   ← 실제 물가선 동 65 m 와 같은 자리
  매립지 호안(동쪽): 월드 x = +150  ← 실제 마산해양신도시 서쪽 끝 동 310 m
  두 호안 사이 수로 폭 약 245 m. 코스는 그 안에 들어간다.

임무 사슬 (기존 월드와 같은 순서 — 강의자료를 고치지 않아도 되게)
  출발 → 항로추종 게이트 4쌍 → WP1 위치유지 → 도킹(3 베이)
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
LAT0, LON0 = 35.1859098, 128.5661096

QUAY_W = -95.0                      # 공원 호안 (서)
QUAY_E = 150.0                      # 매립지 호안 (동)

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


def dome_buoy(name, x, y, radius=1.2):
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


def barrier(name, x, y, yaw_deg, length=12.0):
    """영상의 '긴 구조물' — 흰 부유체 위에 주황 난간이 달린 긴 차단벽."""
    yaw = math.radians(yaw_deg)
    w = 0.8
    v = []
    v.append(box_vis('hull', x, y, 0.25, length, w, 0.50, yaw, WHITE))
    # 난간 : 위아래 가로대 두 줄 + 기둥
    for i, z in enumerate((0.78, 1.05)):
        v.append(box_vis(f'rail{i}', x, y, z, length, 0.10, 0.10, yaw, ORANGE, collide=False))
    n = int(length // 1.5)
    for i in range(n + 1):
        s = -length / 2.0 + i * length / n
        px = x + s * math.cos(yaw)
        py = y + s * math.sin(yaw)
        v.append(box_vis(f'post{i}', px, py, 0.78, 0.09, 0.09, 1.06, yaw, ORANGE, collide=False))
    return static_model(name, ''.join(v), f'긴 부유 차단벽 {length} m  (영상의 그 구조물)')


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

    # 표식 세 개 : 흰 판 + 도형, 베이 안쪽 벽(북쪽)에 건다
    pz = 1.1
    for i, (bx, shape, rgb) in enumerate(BAYS):
        x = DOCK_CX + bx
        y = back_y - WALL_T / 2.0 - 0.06
        r, g, b = rgb
        v.append(f'<visual name="plate{i}"><pose>{x} {y} {pz} 1.5707963 0 0</pose>'
                 f'<geometry><box><size>1.8 0.08 1.8</size></box></geometry>{mat(0.97, 0.97, 0.95)}</visual>')
        if shape == 'square':
            parts = [('<box><size>1.0 0.05 1.0</size></box>', f'{x} {y - 0.09} {pz} 0 0 0')]
        elif shape == 'circle':
            parts = [('<cylinder><radius>0.52</radius><length>0.05</length></cylinder>',
                      f'{x} {y - 0.09} {pz} 1.5707963 0 0')]
        else:
            #  세모 — <cone> 은 이 가제보 판에서 안 그려진다. 가로띠를 쌓아 만든다
            parts, n, base, hgt = [], 8, 1.15, 1.0
            for k in range(n):
                frac = 1.0 - (k + 0.5) / n                    # 위로 갈수록 좁게
                w = base * frac
                zc = pz - hgt / 2.0 + (k + 0.5) * (hgt / n)
                parts.append((f'<box><size>{w:.3f} 0.05 {hgt / n:.3f}</size></box>',
                              f'{x} {y - 0.09} {zc:.3f} 0 0 0'))
        for k, (geo, pose) in enumerate(parts):
            v.append(f'<visual name="sym{i}_{k}"><pose>{pose}</pose>'
                     f'<geometry>{geo}</geometry>{mat(r, g, b)}</visual>')
    return static_model('haeyang_dock', ''.join(v),
                        f'도킹 스테이션 3 베이 — 베이 {BAY_W} W x {BAY_D} D m, 개구부 남향')


# ---------------------------------------------------------------- 육지
def land():
    m = []
    LY, LN = 340.0, 0.0                               # 호안 길이 · 중심 y

    # --- 공원 쪽 (서) : 사석 호안 → 콘크리트 옹벽 → 잔디 → 난간 → 도로
    v = []
    v.append(box_vis('rock', QUAY_W + 3.0, LN, 0.6, 7.0, LY, 1.6, 0.0, ROCK))
    v.append(box_vis('wall', QUAY_W - 1.5, LN, 1.3, 3.0, LY, 3.0, 0.0, GREY))
    v.append(box_vis('walk', QUAY_W - 6.0, LN, 2.75, 6.0, LY, 0.3, 0.0, GREY))
    v.append(box_vis('lawn', QUAY_W - 20.0, LN, 2.80, 22.0, LY, 0.3, 0.0, GRASS))
    v.append(box_vis('road', QUAY_W - 38.0, LN, 2.85, 14.0, LY, 0.3, 0.0, DARKGREY))
    v.append(box_vis('back', QUAY_W - 70.0, LN, 3.5, 50.0, LY, 2.0, 0.0, GREY))
    # 난간 : 가로대 두 줄 + 기둥
    for i, z in enumerate((3.45, 3.90)):
        v.append(box_vis(f'rail{i}', QUAY_W - 3.1, LN, z, 0.08, LY, 0.08, 0.0, DARKGREY, collide=False))
    n = int(LY // 4.0)
    for i in range(n + 1):
        py = LN - LY / 2.0 + i * LY / n
        v.append(box_vis(f'rpost{i}', QUAY_W - 3.1, py, 3.45, 0.08, 0.08, 1.1, 0.0, DARKGREY, collide=False))
    m.append(static_model('park_quay', ''.join(v),
                          f'3·15 해양누리공원 호안 (서, 월드 x={QUAY_W}) — 사석·옹벽·산책로·잔디·도로'))

    # --- 매립지 쪽 (동) : 마산해양신도시 서쪽 끝
    v = []
    v.append(box_vis('wall', QUAY_E + 1.0, LN, 1.0, 2.0, 420.0, 2.4, 0.0, GREY))
    v.append(box_vis('fill', QUAY_E + 61.0, LN, 1.1, 120.0, 420.0, 2.2, 0.0, (0.55, 0.55, 0.52)))
    m.append(static_model('island_quay', ''.join(v),
                          f'마산해양신도시 매립지 호안 (동, 월드 x={QUAY_E})'))

    # --- 남쪽 방파제 — 수평선을 막아 실내 수역처럼 보이게
    v = [box_vis('bw', 25.0, -210.0, 1.0, 250.0, 8.0, 2.2, 0.0, (0.5, 0.49, 0.47))]
    m.append(static_model('south_breakwater', ''.join(v), '남쪽 방파제'))
    return m


# ---------------------------------------------------------------- 코스
GATES = [(-24.0, 4.0), (-16.0, 4.0), (-8.0, 4.5), (0.0, 4.0)]   # (y, 반폭)
WP1 = (0.0, 10.0)
SEARCH = [(-19.0, 14.0, RED), (-25.0, 6.0, GREEN), (-21.0, -2.0, YELLOW)]
WP2 = (-28.0, -9.0)

OBS_X0, OBS_X1 = -70.0, -30.0
OBS_Y0, OBS_Y1 = -34.0, 4.0

# 긴 부유 차단벽을 둘씩 이어 '손가락' 넷을 만든다 — 남·북에 번갈아 붙여 S 자로 엮는다.
# 손가락 하나가 24 m 를 막고 14 m 를 남긴다. 손가락 간격 8 m.
BARRIERS = [(-38.0, -28.0, 90.0, 12.0), (-38.0, -16.0, 90.0, 12.0),   # 남쪽 붙임
            (-46.0, -2.0, 90.0, 12.0), (-46.0, -14.0, 90.0, 12.0),    # 북쪽 붙임
            (-54.0, -28.0, 90.0, 12.0), (-54.0, -16.0, 90.0, 12.0),   # 남쪽 붙임
            (-62.0, -2.0, 90.0, 12.0), (-62.0, -14.0, 90.0, 12.0)]    # 북쪽 붙임
# 목을 좁히는 부표 — 네 목을 14 m 에서 9 m 쯤으로 줄인다. 막지는 않는다.
# 나머지는 로프 벽에 붙여 두는 장식 (통로를 건드리지 않는다)
DOMES = [(-38.0, 0.2), (-46.0, -30.8), (-54.0, 0.2), (-62.0, -30.8),
         (-42.0, -32.5), (-50.0, 2.5), (-58.0, -32.5), (-66.0, 2.5)]
# 주황 기둥은 **로프 벽에 붙여** 둔다. 통로 한가운데 두면 7.2 m 차선을 둘로 쪼갠다.
PILLARS = [(-42.0, 2.6), (-58.0, 2.6), (-68.0, -32.2)]

GATE_IN = (-30.0, -8.0, -30.0, 2.0)          # 빨강(남) · 초록(북) — 서진 시 우현 빨강
GATE_OUT = (-70.0, -32.0, -70.0, -22.0)
ROPE_SEGS = [(OBS_X1, OBS_Y1, OBS_X0, OBS_Y1),           # 북
             (OBS_X1, OBS_Y0, OBS_X0, OBS_Y0),           # 남
             (OBS_X1, OBS_Y0, OBS_X1, -9.0),             # 동 아래
             (OBS_X1, 3.0, OBS_X1, OBS_Y1),              # 동 위 (진입구 y -9..3)
             (OBS_X0, OBS_Y0, OBS_X0, -33.0),            # 서 아래
             (OBS_X0, -21.0, OBS_X0, OBS_Y1)]            # 서 위 (종료구 y -33..-21)


def course():
    m = []
    m.append('\n    <!-- ===== 항로추종 게이트 (남 -> 북). 우현 빨강 · 좌현 초록 ===== -->')
    for i, (gy, hw) in enumerate(GATES, 1):
        m.append(sphere_buoy(f'gate{i}_red', hw, gy, RED))
        m.append(sphere_buoy(f'gate{i}_green', -hw, gy, GREEN))

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
print(f'게이트 폭 : {[2 * hw for _, hw in GATES]} m  → 좌우 여유 '
      f'{[(2 * hw - BOAT_B) / 2 for _, hw in GATES]}')
