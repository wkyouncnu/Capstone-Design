#!/usr/bin/env python3
"""
Docking Mission Launch (RANSAC ver2 — 4기둥 + 안쪽벽 실측/추론)
=================================================================
노드: docking_3bay_pc2_ransac_flight_ver2
- 4기둥 조합 매칭으로 입구 확정 (강건성)
- 안쪽벽 깊이 실측으로 idx = 베이 안쪽 (3bay_pc2 와 의미 통일)
- 안쪽 가림 시 이웃 베이 깊이로 추론 (RViz 라벨 '(inf)')
- psi_ned = 1.0 은 Lock 플래그 (Simulink detect_valid 계약)

파라미터
    ★ 튜닝은 아래 DOCKING_PARAMS 딕셔너리에서만 한다 (단일 진실 공급원).
      collision_avoidance.launch.py 의 COLA_PARAMS 와 같은 형태.
    CLI 오버라이드용 launch argument 의 기본값은 이 딕셔너리에서 읽어오므로
    숫자를 두 곳에 적을 일이 없다. ARG_MAP 이 '인자 이름 → 파라미터 이름'을 잇는다.
    (인자는 언더스코어 roi_x_min, 파라미터는 점 roi.x_min 표기)

    ⚠️ ransac.seed / viz.* 는 노드 기본값을 쓰며 이 런치파일이 제어하지 않는다.

기본값: docking_v3_ransac_launch.py 실험 사용값으로 통일 (2026-07-14)
        (ver2 전용 파라미터 seg_gap/dir_tol_deg/depth_spread_tol/inner_wall 은 ver2 검증값 유지)

사용법:
    ros2 launch ugv_docking_pkg docking_ransac_ver2_launch.py
    ros2 launch ugv_docking_pkg docking_ransac_ver2_launch.py \
        roi_x_min:=2.0 bay_target_idx:=1 bay_use_inner_wall:=false
"""
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


# ═════════════════════════════════════════════════════════════════════════
#  파라미터 — ★ 여기서만 수정한다
#  ⚠️ --symlink-install 빌드라면 재빌드 없이 재실행만으로 반영됨
# ═════════════════════════════════════════════════════════════════════════
DOCKING_PARAMS = {
    # ── ROI (직사각형 영역) 및 높이 필터 ─────────────────────────────────
    'roi.x_min':      1.0,    # 최소 전방거리 [m] — 포켓 검출용으로 넓힘
                              #   (구 3.0 은 test2/3 처럼 가까이서 찍은 bag 의 벽을 잘랐다)
    'roi.x_max':      9.0,    # 최대 전방거리 [m] — 실측 안쪽벽 5.3~8.1 m 를 모두 포함
    'roi.y_abs_max':  5.0,    # |y| 이내 [m] — 스테이션 폭 실측 약 4.5 m
    'roi.z_min':     -0.6,    # 높이 하한 [m] (지면까지 받아야 셀판정 동작)
    'roi.z_max':      1.5,    # 높이 상한 [m]

    # ── 지면 제거 (pc2 전용) ──────────────────────────────────────────────
    'ground.enable':      True,
    'ground.cell':        0.10,   # 판정 격자 [m]
    'ground.z_wall_min': -0.25,   # 셀 z_max ≥ 이 값 → 벽
                                  # ⚠️ -0.15 는 왼쪽기둥(z_max=-0.16) 소실

    # ── 점 축적 / 복셀 다운샘플링 ─────────────────────────────────────────
    'accum.enable':     True,
    'accum.voxel':      0.05,  # RANSAC 검증 기준 (0.02 는 연산량↑)
    'accum.target_pts': 1000,  # ★ 포켓 검출은 깊이 프로파일이라 점이 더 필요하다.
                               #   250 은 0.1 m 구간 프로파일에 너무 희소해 베이 3개를
                               #   거의 못 채웠다 (실측: 250→3개검출 0%, 1000→최대 100%)

    # ── RANSAC 알고리즘 ───────────────────────────────────────────────────
    'ransac.dbscan_eps':            0.15,
    'ransac.dbscan_min_samples':    3,
    'ransac.iterations':            250,   # 100 은 신뢰도 30%대, 250=20/20
    'ransac.dist_threshold':        0.04,
    'ransac.min_points':            3,
    'ransac.max_lines_per_cluster': 6,     # 1 이면 기둥 4개 추출 불가
    'ransac.seg_gap':               0.15,  # 동일선상 기둥 분할 간격 [m]
    'ransac.dir_tol_deg':           30.0,  # 지배방향 허용각 (대각선 배제)

    # ── 포켓(빗살형) 베이 검출 ────────────────────────────────────────────
    #   안쪽 벽에서 격벽이 돌출해 만든 ㄷ자 포켓 3개를 깊이 프로파일로 찾는다.
    'bay.wall_thr':         0.10,   # 안쪽 벽 직선 인라이어 허용 [m]
    'bay.bin_w':            0.10,   # 벽 방향 프로파일 구간 폭 [m]
    'bay.pocket_depth_min': 0.35,   # 격벽 돌출량 최소 [m]
    'bay.width_min':        0.55,   # 포켓 폭 하한 [m] (실측 0.95~1.20)
    'bay.width_max':        1.80,   # 포켓 폭 상한 [m]

    # ── [구 방식 잔존] 4기둥 매칭 파라미터 — 현재 검출기는 사용하지 않는다 ──
    #   되돌릴 때를 위해 선언만 남겨둔다 (replay_tools/docking_node.py.bak)
    'bay.min_pillar_length':   0.10,  # 실측 최소 세그먼트 0.17 m
    'bay.max_pillar_length':   0.50,
    'bay.expected_bay_width':  0.90,  # 기둥 가장자리간 개구부 (실측 ~0.9)
    'bay.width_tolerance':     0.25,
    'bay.alignment_tolerance': 0.10,  # 가짜기둥 배제 위해 조임
    'bay.depth_spread_tol':    0.15,  # 4기둥 전면방향 산포 허용
    'bay.use_inner_wall':      True,  # 안쪽벽 실측 (False=입구 idx)
    'bay.inner_depth_min':     0.25,  # 기둥선 뒤 탐색 깊이 하한 [m]
    'bay.inner_depth_max':     0.70,  # 상한 [m]
    'bay.target_idx':          2,     # 목표 베이 (좌→우 0,1,2)
    'approach_dist':           2.0,   # v3 실험값 (ver2 검증값 0.80 — PX4 DOCKING_RADIUS < 0.4 조건)

    # ── 안정화 / Lock ─────────────────────────────────────────────────────
    'stable.thresh':        5,
    'stable.smooth_window': 15,
    'stable.lock_duration': 1.0,
    'stable.pos_tol':       0.20,
    'stable.psi_tol':       5.0,

    # ── 좌표 / 통신 / 모드 ────────────────────────────────────────────────
    'enu_to_ned':  True,
    'publish_hz':  10.0,
    # 도킹이 동작할 operation_mode. ★ 튜닝은 여기서 한다.
    #   ⚠️ 충돌회피(collision_avoidance.launch.py 의 COLA_PARAMS['sys.active_mode'])와
    #      반드시 달라야 한다 — 같으면 두 스택이 동시에 활성화되어 제어가 충돌한다.
    #   ⚠️ PX4 는 operation_mode 를 1→3→2→3→4→1 시퀀스로 보낸다(실측 bag 2건).
    'active_mode': 4,
}

# CLI 오버라이드용 '인자 이름 → 파라미터 이름' 대응.
# 인자는 언더스코어, 파라미터는 점 표기라 기계적으로 변환되지 않아 명시한다.
ARG_MAP = {
    'roi_x_min':     'roi.x_min',
    'roi_x_max':     'roi.x_max',
    'roi_y_abs_max': 'roi.y_abs_max',
    'roi_z_min':     'roi.z_min',
    'roi_z_max':     'roi.z_max',

    'ground_enable':     'ground.enable',
    'ground_cell':       'ground.cell',
    'ground_z_wall_min': 'ground.z_wall_min',

    'accum_enable':     'accum.enable',
    'accum_voxel':      'accum.voxel',
    'accum_target_pts': 'accum.target_pts',

    'ransac_dbscan_eps':            'ransac.dbscan_eps',
    'ransac_dbscan_min_samples':    'ransac.dbscan_min_samples',
    'ransac_iterations':            'ransac.iterations',
    'ransac_dist_threshold':        'ransac.dist_threshold',
    'ransac_min_points':            'ransac.min_points',
    'ransac_max_lines_per_cluster': 'ransac.max_lines_per_cluster',
    'ransac_seg_gap':               'ransac.seg_gap',
    'ransac_dir_tol_deg':           'ransac.dir_tol_deg',

    'bay_wall_thr':         'bay.wall_thr',
    'bay_bin_w':            'bay.bin_w',
    'bay_pocket_depth_min': 'bay.pocket_depth_min',
    'bay_width_min':        'bay.width_min',
    'bay_width_max':        'bay.width_max',

    'bay_min_pillar_length':   'bay.min_pillar_length',
    'bay_max_pillar_length':   'bay.max_pillar_length',
    'bay_expected_bay_width':  'bay.expected_bay_width',
    'bay_width_tolerance':     'bay.width_tolerance',
    'bay_alignment_tolerance': 'bay.alignment_tolerance',
    'bay_depth_spread_tol':    'bay.depth_spread_tol',
    'bay_use_inner_wall':      'bay.use_inner_wall',
    'bay_inner_depth_min':     'bay.inner_depth_min',
    'bay_inner_depth_max':     'bay.inner_depth_max',
    'bay_target_idx':          'bay.target_idx',
    'approach_dist':           'approach_dist',

    'stable_thresh': 'stable.thresh',
    'smooth_window': 'stable.smooth_window',
    'lock_duration': 'stable.lock_duration',
    'pos_tol':       'stable.pos_tol',
    'psi_tol':       'stable.psi_tol',

    'enu_to_ned':  'enu_to_ned',
    'publish_hz':  'publish_hz',
    'active_mode': 'active_mode',
}


def _default(param_name):
    """launch argument 기본값을 DOCKING_PARAMS 에서 읽어 문자열로 만든다.
    ★ 여기에 숫자를 직접 적지 말 것 — 값은 DOCKING_PARAMS 한 곳에만 존재한다."""
    v = DOCKING_PARAMS[param_name]
    return 'true' if v is True else 'false' if v is False else str(v)


def generate_launch_description():

    launch_args = [
        # 시간 소스 (bag 재생 디버깅: use_sim_time:=true + ros2 bag play --clock)
        DeclareLaunchArgument('use_sim_time', default_value='false'),
    ] + [
        DeclareLaunchArgument(arg, default_value=_default(param))
        for arg, param in ARG_MAP.items()
    ]

    docking_ransac_ver2_node = Node(
        package='ugv_docking_pkg',
        executable='docking_3bay_pc2_ransac_flight_ver2',
        name='docking_lidar_ransac_detector',
        output='screen',
        emulate_tty=True,
        # 뒤 딕셔너리가 앞을 덮어쓴다: 평소엔 DOCKING_PARAMS 값,
        # <인자>:=N 을 주면 그 값이 이긴다.
        parameters=[
            DOCKING_PARAMS,
            {param: LaunchConfiguration(arg) for arg, param in ARG_MAP.items()},
            {'use_sim_time': LaunchConfiguration('use_sim_time')},
        ],
    )

    return LaunchDescription(launch_args + [docking_ransac_ver2_node])
