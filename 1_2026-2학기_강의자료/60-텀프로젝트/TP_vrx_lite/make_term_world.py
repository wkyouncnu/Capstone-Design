#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""학생 월드(my_world.sdf) -> 텀프로젝트 월드(kaboat_term.sdf).

고치는 것 하나
  - 게이트 서쪽 열의 파랑(0 0 0.75) -> 초록(0 0.6 0)   : 규정은 빨강·초록 한 쌍

보태는 것 (모두 ENU, x=동, y=북, z=0 이 수면)
  WP1 위치유지   주황 부표 + 반경 5 m 링        (-534, 226)
  도킹 스테이션  3 베이 ⊔ + 표식 3개            베이 중심 x -545 / -550.5 / -556, 입구 y 227
  탐색 부표      빨강 (-542,206) · 초록(기존 obs_cyl_loiter, -550,195) · 노랑 (-556,205)
  WP2 위치유지   주황 부표 + 반경 5 m 링        (-553, 188)
  가상경계선     x -594..-560, y 181..211 (진입구 · 종료구 두 군데 끊김)
  진입 게이트    (-560, 192) 빨강 · (-560, 184) 초록   (서진하므로 우현 = 북)
  종료 게이트    (-594, 200) 빨강 · (-594, 192) 초록   (서진하므로 우현 = 북)
"""
import math
import sys

SRC = sys.argv[1]
DST = sys.argv[2]

I = '    '


def mat(r, g, b, a=1.0):
    return (f'<material><ambient>{r} {g} {b} {a}</ambient>'
            f'<diffuse>{r} {g} {b} {a}</diffuse></material>')


def sphere_buoy(name, x, y, rgb, radius=0.75):
    r, g, b = rgb
    return f"""
    <model name="{name}">
      <static>true</static>
      <pose>{x} {y} {radius} 0 0 0</pose>
      <link name="link">
        <visual name="visual">
          <geometry><sphere><radius>{radius}</radius></sphere></geometry>
          {mat(r, g, b)}
        </visual>
        <collision name="collision">
          <geometry><sphere><radius>{radius}</radius></sphere></geometry>
        </collision>
      </link>
    </model>"""


def cyl_buoy(name, x, y, rgb, radius=0.6, length=2.0):
    r, g, b = rgb
    return f"""
    <model name="{name}">
      <static>true</static>
      <pose>{x} {y} {length / 2.0} 0 0 0</pose>
      <link name="link">
        <visual name="visual">
          <geometry><cylinder><radius>{radius}</radius><length>{length}</length></cylinder></geometry>
          {mat(r, g, b)}
        </visual>
        <collision name="collision">
          <geometry><cylinder><radius>{radius}</radius><length>{length}</length></cylinder></geometry>
        </collision>
      </link>
    </model>"""


def ring(name, cx, cy, radius=5.0, z=0.3, n=36, rgb=(1.0, 0.55, 0.0), alpha=0.45):
    """반경 radius 의 띠. 링크 하나에 visual 만 n 개 — 충돌체 없음(접촉 벌점 없음)."""
    r, g, b = rgb
    seg = 2.0 * math.pi * radius / n * 0.75   # 조각 사이를 조금 띄워 점선처럼
    vis = []
    for i in range(n):
        th = 2.0 * math.pi * i / n
        px, py = cx + radius * math.cos(th), cy + radius * math.sin(th)
        yaw = th + math.pi / 2.0
        vis.append(f"""
        <visual name="seg{i:02d}">
          <pose>{px:.3f} {py:.3f} {z} 0 0 {yaw:.4f}</pose>
          <geometry><box><size>{seg:.3f} 0.18 0.12</size></box></geometry>
          {mat(r, g, b, alpha)}
          <transparency>{1.0 - alpha:.2f}</transparency>
        </visual>""")
    return f"""
    <!-- {name} : 반경 {radius} m 위치유지 영역 표식 (충돌체 없음) -->
    <model name="{name}">
      <static>true</static>
      <pose>0 0 0 0 0 0</pose>
      <link name="link">{''.join(vis)}
      </link>
    </model>"""


def fence(name, segs, z=0.4, rgb=(0.9, 0.1, 0.1), alpha=0.35):
    """segs: (중심x, 중심y, 길이x, 길이y) 목록. 가상경계선 — 충돌체 없음."""
    r, g, b = rgb
    vis = []
    for i, (cx, cy, lx, ly) in enumerate(segs):
        vis.append(f"""
        <visual name="seg{i}">
          <pose>{cx} {cy} {z} 0 0 0</pose>
          <geometry><box><size>{lx} {ly} 0.5</size></box></geometry>
          {mat(r, g, b, alpha)}
          <transparency>{1.0 - alpha:.2f}</transparency>
        </visual>""")
    return f"""
    <!-- {name} : 가상경계선. 이 선을 넘으면 실격 (임무설명 Ⅲ-1) -->
    <model name="{name}">
      <static>true</static>
      <pose>0 0 0 0 0 0</pose>
      <link name="link">{''.join(vis)}
      </link>
    </model>"""


# ---------------------------------------------------------------- 도킹 스테이션
BAY_W, BAY_D, WALL_T, WALL_H = 5.0, 5.0, 0.5, 2.0
DOCK_X, DOCK_Y, DOCK_YAW = -550.5, 229.5, math.pi / 2.0
# 벽 색: VRX dock_block 과 같은 콘크리트 톤
W_AMB, W_DIF = '0.55 0.54 0.50 1', '0.82 0.80 0.74 1'


def wall(name, sx, sy, sz, px, py, pz):
    return f"""
        <link name="{name}">
          <pose>{px:.4f} {py:.4f} {pz:.4f} 0 0 0</pose>
          <collision name="{name}_collision">
            <geometry><box><size>{sx:.4f} {sy:.4f} {sz:.4f}</size></box></geometry>
          </collision>
          <visual name="{name}_visual">
            <geometry><box><size>{sx:.4f} {sy:.4f} {sz:.4f}</size></box></geometry>
            <material><ambient>{W_AMB}</ambient><diffuse>{W_DIF}</diffuse></material>
          </visual>
        </link>"""


def placard(idx, bay_y, shape, rgb):
    """후면벽 안쪽에 붙는 표식. 판(흰색) + 도형. 개구부(-x) 를 바라본다."""
    r, g, b = rgb
    zc = 1.2
    plate_x = BAY_D / 2.0 - 0.05
    sym_x = plate_x - 0.06
    if shape == 'circle':
        sym = f"""
          <visual name="symbol{idx}">
            <pose>{sym_x:.4f} {bay_y:.4f} {zc} 0 1.5707963 0</pose>
            <geometry><cylinder><radius>0.5</radius><length>0.03</length></cylinder></geometry>
            {mat(r, g, b)}
          </visual>"""
    elif shape == 'square':
        sym = f"""
          <visual name="symbol{idx}">
            <pose>{sym_x:.4f} {bay_y:.4f} {zc} 0 0 0</pose>
            <geometry><box><size>0.03 1.0 1.0</size></box></geometry>
            {mat(r, g, b)}
          </visual>"""
    else:  # triangle : VRX 기본 자산 symbol_triangle (1 x 1 평면 삼각형)
        sym = f"""
          <visual name="symbol{idx}">
            <pose>{sym_x:.4f} {bay_y - 0.5:.4f} {zc - 0.5} 1.5707963 0 1.5707963</pose>
            <geometry><mesh><uri>model://symbol_triangle/mesh/triangle.dae</uri></mesh></geometry>
            {mat(r, g, b)}
          </visual>"""
    return f"""
          <visual name="plate{idx}">
            <pose>{plate_x:.4f} {bay_y:.4f} {zc} 0 0 0</pose>
            <geometry><box><size>0.08 1.4 1.4</size></box></geometry>
            {mat(0.93, 0.93, 0.90)}
          </visual>{sym}"""


def dock_model():
    half = BAY_W * 1.5 + WALL_T * 2.0            # 8.5 : 좌우 바깥면까지
    cz = WALL_H / 2.0
    links = [wall('back_wall', WALL_T, 2.0 * half, WALL_H,
                  BAY_D / 2.0 + WALL_T / 2.0, 0.0, cz)]
    for i, ly in enumerate((-(BAY_W + WALL_T) * 1.5, -(BAY_W + WALL_T) / 2.0,
                            (BAY_W + WALL_T) / 2.0, (BAY_W + WALL_T) * 1.5)):
        links.append(wall(f'divider{i}', BAY_D, WALL_T, WALL_H, 0.0, ly, cz))
    # 표식 세 개: 베이 중심 local y = +BAY_W+WALL_T, 0, -(BAY_W+WALL_T)
    bays = [((BAY_W + WALL_T), 'triangle', (0.85, 0.05, 0.05)),   # 월드 x -556
            (0.0, 'circle', (0.05, 0.65, 0.12)),                   # 월드 x -550.5
            (-(BAY_W + WALL_T), 'square', (0.05, 0.15, 0.85))]     # 월드 x -545
    pl = ''.join(placard(i + 1, by, sh, c) for i, (by, sh, c) in enumerate(bays))
    return f"""
    <!-- 도킹 스테이션 3 베이. 개구부는 남향(-y), 벽 높이 {WALL_H} m
         local +x = 베이 안쪽, 원점 = 가운데 베이 바닥 중심
         표식: 월드 x -556 빨강삼각 / -550.5 초록원 / -545 파랑네모 -->
    <model name="kaboat_dock">
      <static>true</static>
      <pose>{DOCK_X} {DOCK_Y} 0 0 0 {DOCK_YAW:.7f}</pose>{''.join(links)}
      <link name="placards">
        <pose>0 0 0 0 0 0</pose>{pl}
      </link>
    </model>"""


# ---------------------------------------------------------------- 가상경계선
FX0, FX1, FY0, FY1 = -594.0, -560.0, 181.0, 211.0
T = 0.4
fence_segs = [
    ((FX0 + FX1) / 2.0, FY1, FX1 - FX0, T),           # 북
    ((FX0 + FX1) / 2.0, FY0, FX1 - FX0, T),           # 남
    (FX1, 182.5, T, 3.0),                             # 동 아래
    (FX1, 201.5, T, 19.0),                            # 동 위  (진입구 y 184~192)
    (FX0, 186.5, T, 11.0),                            # 서 아래
    (FX0, 205.5, T, 11.0),                            # 서 위  (종료구 y 192~200)
]

RED, GREEN, YELLOW, ORANGE = (0.85, 0.05, 0.05), (0.05, 0.6, 0.1), (0.95, 0.85, 0.05), (1.0, 0.45, 0.0)

block = ['\n\n    <!-- ===================== 텀프로젝트 추가물 ===================== -->']
# WP1
block.append('\n    <!-- WP1 위치유지 (-534, 226) -->')
block.append(sphere_buoy('wp1_buoy', -534, 226, ORANGE, 0.5))
block.append(ring('wp1_area', -534, 226))
# 도킹
block.append(dock_model())
# 탐색 부표 (초록은 기존 obs_cyl_loiter 를 그대로 쓴다)
block.append('\n    <!-- 탐색 부표. 초록은 기존 obs_cyl_loiter(-550,195) 를 그대로 쓴다.'
             '\n         규정 5.2(6): 빨강·초록 = 우현선회 / 노랑 = 좌현선회 -->')
block.append(cyl_buoy('search_red', -542, 206, RED))
block.append(cyl_buoy('search_yellow', -556, 205, YELLOW))
# WP2
block.append('\n    <!-- WP2 위치유지 (-553, 188) — 장애물 구간 바로 앞 -->')
block.append(sphere_buoy('wp2_buoy', -553, 188, ORANGE, 0.5))
block.append(ring('wp2_area', -553, 188))
# 가상경계선 + 게이트
block.append(fence('virtual_boundary', fence_segs))
#  적록 배치는 **진행 방향** 기준이다. 장애물 구간은 서쪽으로 지나가므로 우현이 북쪽이고,
#  따라서 빨강이 북(큰 y)·초록이 남(작은 y) 이다. 항로추종 구간은 북진이라 반대로
#  빨강이 동(x -520)·초록이 서(x -528) 다. 둘 다 "빨강을 우현에 두고 통과" 로 같은 규칙이다.
block.append('\n    <!-- 장애물 구간 진입 게이트 (빨강 y 192 / 초록 y 184) -->')
block.append(sphere_buoy('obs_gate_in_red', -560, 192, RED))
block.append(sphere_buoy('obs_gate_in_green', -560, 184, GREEN))
block.append('\n    <!-- 종료 게이트 (빨강 y 200 / 초록 y 192) -->')
block.append(sphere_buoy('goal_gate_red', -594, 200, RED))
block.append(sphere_buoy('goal_gate_green', -594, 192, GREEN))
block.append('\n    <!-- =========================================================== -->\n')

with open(SRC, encoding='utf-8') as f:
    src = f.read()

n_blue = src.count('0 0 0.75 1')
src = src.replace('0 0 0.75 1', '0 0.6 0 1')

# 월드 이름 = 파일 이름 (vrx_gz launch 가 basename 으로 /world/<이름>/create 를 부른다)
src = src.replace('<world name="sydney_regatta">', '<world name="kaboat_term">')

# 일시정지로 시작하지 않는다 — 원본은 true 였고, 매번 손으로 풀어야 했다
#   (풀어야 하는 서비스 : gz service -s /world/kaboat_term/control ... "pause: false")
src = src.replace('<start_paused>true</start_paused>', '<start_paused>false</start_paused>')

if '</world>' not in src:
    raise SystemExit('</world> 를 못 찾음')
out = src.replace('</world>', ''.join(block) + '  </world>')

with open(DST, 'w', encoding='utf-8') as f:
    f.write(out)

print(f'파랑->초록 바꾼 곳: {n_blue} 군데')
print(f'모델 수: 원본 {src.count("<model name=")} -> 결과 {out.count("<model name=")}')
print(f'쓴 파일: {DST}  ({len(out)} 바이트)')
