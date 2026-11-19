#!/usr/bin/env python3
"""
Collision Avoidance Launch  (충돌회피 단독 — 도킹 없음)
========================================================
충돌회피 임무 노드만 띄운다. 도킹 검출 노드는 포함하지 않는다.
LiDAR 데이터는 lidar_system.launch.py 가 발행하는 토픽을 구독한다.
(이 파일은 LiDAR 드라이버/변환을 띄우지 않는다 — 반드시 먼저 lidar_system 실행)

데이터 흐름
    /fmu/out/*                  → pos_trans → /usv/state/{position_ned,heading,goal_ned}
    /livox/lidar (PointCloud2)  ┐
    /usv/state/*                ┴→ collision_avoidance_node_livox
                                   → /vfh/command (Twist), /vfh/oa_flag (Bool)
                                   → px4_cmd_pub → /fmu/in/{offboard_control_mode,trajectory_setpoint}

파라미터
    이 파일 상단의 *_PARAMS 딕셔너리에서 직접 수정 (config yaml 없음)
    ⚠️ 값은 Integrated_colA_docking.launch.py 와 동일하게 유지할 것 —
       두 파일에 같은 값이 중복되어 있으므로 한쪽만 고치면 드리프트가 생긴다.

구성 노드
    pos_trans                       : 좌표 변환 (LLA/NED, body vel)
    collision_avoidance_node_livox  : PointCloud2 직접 구독, 아크 기반 회피
    px4_cmd_pub                     : PX4 offboard 명령 발행 (50 Hz)

실행
    # (터미널 1)  ros2 launch auto_usv_pkg lidar_system.launch.py
    # (터미널 2)  ros2 launch auto_usv_pkg collision_avoidance.launch.py
    # bag 재생 디버깅: use_sim_time:=true 와 함께 ros2 bag play <bag> --clock
"""
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


# ═════════════════════════════════════════════════════════════════════════
#  파라미터
#  ⚠️ 수정 후 --symlink-install 빌드라면 재빌드 없이 재실행만으로 반영됨
# ═════════════════════════════════════════════════════════════════════════

# ── 좌표 변환 (pos_trans) ──────────────────────────────────────────────────
POS_TRANS_PARAMS = {
    # NED 좌표계 원점 (LLA) — ECEF→NED 기준점. 운용 장소로 반드시 변경.
    'origin.latitude':  36.395991,   # 원점 위도 [deg]
    'origin.longitude': 127.401794,  # 원점 경도 [deg]
    'origin.altitude':  25.1110,     # 원점 고도 [m, WGS84]
}

# ── 충돌회피 (collision_avoidance_node_livox) ─────────────────────────────
COLA_PARAMS = {
    # System
    'sys.rate_hz': 20.0,             # 제어 루프 주기 [Hz]
    'sys.sensor_timeout_sec': 0.15,  # 센서 stale 판정 [s] (실측: 클라우드 나이 최대 0.099 s)
    # 충돌회피가 동작할 operation_mode. ★ 튜닝은 여기서 한다.
    #   ⚠️ 도킹(docking_ransac_ver2_launch.py 의 active_mode)과 반드시 달라야 한다 —
    #      같으면 두 스택이 동시에 활성화되어 PX4 제어 명령이 충돌한다.
    #   ⚠️ PX4 는 operation_mode 를 1→3→2→3→4→1 시퀀스로 보낸다(실측 bag 2건).
    #      값을 바꾸면 회피가 어느 임무 단계에서 켜지는지가 달라진다.
    'sys.active_mode': 3,
    # 목표 전용 timeout [s]. 0=무제한. goal_ned 는 WP 변경 시에만 오는 이벤트 토픽이라
    # sensor_timeout(0.15s)으로 재면 영구 HOLD 가 된다. 실측 최대 간격 119.5 s → 180 여유.
    'sys.goal_timeout_sec': 180.0,

    # Robot
    'robot.max_speed_m_s':      1.5,   # 최대 전진 속도 [m/s]
    'robot.max_yaw_rate_deg_s': 50.0,  # 최대 선회 각속도 [deg/s] (×3.0s=150° = 가드 한계, 클리핑 없음)
    'robot.safety_radius_m':    0.50,  # 아크-장애물 최소 허용 거리 [m]

    # Arc Planner
    'plan.sim_time_sec': 3.0,        # 아크 예측 시간 [s]
    'plan.sim_steps':   15,          # 아크 적분 스텝 수
    'plan.arc_count':   21,          # 후보 아크 수 (홀수 → 직진 포함)
    'plan.hysteresis_margin': 0.10,  # 회피 아크 전환 임계 (클수록 떨림↓·반응↓)
    'plan.clearance_weight':  0.50,  # [4] 0.30→0.50
    'plan.clearance_scale_m': 0.7,   # [4] 3.0→0.7. 3.0 은 여유 3.5m 에서 포화하는데
                                     #   통과 아크의 실제 여유는 중앙 0.70m 라 항의 6.6%만 쓰였다
    'plan.straight_reset_sec': 1.0,  # [5] 이 시간 연속 직진해야 히스테리시스 리셋
    'plan.blocked_speed_scale': 0.3, # 전 아크 차단(비상) 시 감속 배율 (지금은 [3] 단계축소가 대신함)
    # 비상 단계축소 배율. ★ Ackermann 차량에서는 0.15/0.08 단계를 쓰면 안 된다 —
    #   아크뱅크가 요구하는 선회반경이 v/ω 로 떨어져 0.26 m / 0.14 m 가 되는데
    #   물리적으로 불가능하다(260720 자동차 성공 코드의 최악은 고정 0.3 배 = 0.47 m).
    #   스윕 실측(7/16 자동차 bag): [0.6,0.3] 로 잘라도 비상률 8.8% 로 동일하고
    #   명령 점프는 9.7% → 9.2% 로 오히려 개선된다. 즉 손실 없이 제거 가능.
    'plan.creep_scales': [0.6, 0.3],

    # Debug
    # bag 에 녹화된 마커 토픽과 겹치지 않게 지정 → rviz2 에서 구/신 아크 동시 비교.
    #   260706_test* bag      : 녹화 '/vfh/debug_markers'  → 여기는 '/vfh/debug_markers_'
    #   rviz2_Loitering_* bag : 녹화 '/vfh/debug_markers_' → 여기는 '/vfh/debug_markers'
    # ★ 현재: rviz2_Loitering_ColA_Docking_right 로 검증 중 → 밑줄 없는 쪽 사용
    'debug.marker_topic': '/vfh/debug_markers',

    # Hold Mode
    'hold.clear_m':          1.0,    # HOLD 이탈 트리거 거리 [m]
    'hold.escape_speed_m_s': 0.6,    # HOLD 이탈 속도 [m/s]

    # Livox PointCloud2 필터 (NaN컷→높이밴드→거리→FOV→지면제거→복셀→클러스터)
    'lidar.ignore_radius_m': 0.5,    # 근접 노이즈 무시 [m] — 실측: 0.3~1.0m 에 물보라 90점,
                                     #   1.0~2.0m 에 0점. 안전반경(0.5)과 같게 둔다
    'lidar.min_height_m':   -0.1,    # 높이 하한 [m] (수면 노이즈 컷)
    'lidar.max_height_m':    1.0,    # 높이 상한 [m] (상부 구조물 컷)
    'lidar.angle_half_fov_deg': 120.0, # 전방 FOV 반각 [deg] — MID-360 은 360° 를 본다.
                                       #   90° 면 회피 선회 중 장애물이 시야 밖으로 사라짐
    'lidar.cluster_min_points': 4,     # [2] 2→4. 희소점 제거를 이름이 맞는 파라미터로.
                                       #   ★ 6 이나 지면필터 ON 은 비상률은 더 낮지만
                                       #   실제 구조물을 놓친다 (회귀시험: cl6 은 사건 right2 를
                                       #   75% 놓치고, 지면필터 ON 은 사건 center2 를 36% 놓침).
                                       #   cl4 만이 확인된 구조물 3건을 100% 유지한다.
    'lidar.cluster_max_gap_m':  0.45,  # 같은 클러스터 최대 간격 [m]
    'lidar.ground_grid_m':     0.0,    # [2] OFF 로 되돌림. 이 필터는 이름과 달리 지면이 아니라
                                       #   희소점을 지운다(버린 셀의 52%가 '셀 안에 점 1개').
                                       #   바닥은 애초에 obs 밖 — 최저점 고도각이 -3~-6.7°로
                                       #   일정한 FOV 하한선이고, 지면은 r≈10m 부터인데 max_r=6.5m
    'lidar.ground_vert_min_m': 0.08,   # 장애물 최소 수직 높이차 [m] (보수적: 점을 더 남김)
    'lidar.ground_top_min_m':  0.3,    # 셀 최고 z 유지 임계 [m] (낮은 장애물 보호)
    'lidar.voxel_size_m': 0.1,         # ★ 복셀 ON. 실측 obs 1,433→179점
    # 튜닝: 땅/물 남음→ground_vert_min_m↑ / 낮은 장애물 사라짐→ground_vert_min_m↓
}

# ── PX4 offboard 발행 (cmd_msg_pub_px4) ──────────────────────────────────
PX4_CMD_PARAMS = {
    'timer_period': 0.02,   # 발행 주기 [s] → 50 Hz
}


def generate_launch_description():

    pkg_name = 'auto_usv_pkg'

    use_sim_time = LaunchConfiguration('use_sim_time')
    declare_use_sim_time = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use /clock (sim time) — bag 재생 시 true',
    )

    # CLI 오버라이드용 인자. ★ 기본값을 COLA_PARAMS 에서 읽어오므로
    #   값은 COLA_PARAMS 한 곳에만 존재한다 (여기에 숫자를 적지 말 것).
    active_mode = LaunchConfiguration('active_mode')
    declare_active_mode = DeclareLaunchArgument(
        'active_mode',
        default_value=str(COLA_PARAMS['sys.active_mode']),
        description='이 operation_mode 일 때만 충돌회피 동작 (도킹 값과 달라야 함)',
    )

    pos_trans_node = Node(
        package=pkg_name,
        executable='pos_trans',
        name='pos_trans',
        output='screen',
        emulate_tty=True,
        parameters=[POS_TRANS_PARAMS, {'use_sim_time': use_sim_time}],
    )

    collision_avoidance_livox_node = Node(
        package=pkg_name,
        executable='collision_avoidance_node_livox',
        name='collision_avoidance_node_livox',
        output='screen',
        emulate_tty=True,
        # 뒤 딕셔너리가 앞을 덮어쓴다: 평소엔 COLA_PARAMS 값,
        # active_mode:=N 을 주면 그 값이 이긴다.
        parameters=[COLA_PARAMS,
                    {'sys.active_mode': active_mode},
                    {'use_sim_time': use_sim_time}],
    )

    px4_mission_node = Node(
        package=pkg_name,
        executable='px4_cmd_pub',
        name='cmd_msg_pub_px4',
        output='screen',
        emulate_tty=True,
        parameters=[PX4_CMD_PARAMS, {'use_sim_time': use_sim_time}],
    )

    return LaunchDescription([
        declare_use_sim_time,
        declare_active_mode,
        pos_trans_node,
        collision_avoidance_livox_node,
        px4_mission_node,
    ])
