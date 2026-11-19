#!/usr/bin/env python3
"""
Integrated colA Docking Launch  (충돌회피 + 도킹 통합 — 얇은 조합 레이어)
==========================================================================
충돌회피 스택과 도킹 검출 스택을 함께 띄운다.
★ 이 파일은 노드를 직접 띄우지 않고, 각 스택의 전용 런치파일을 include 만 한다.
  → 파라미터가 여기 중복되지 않으므로 단독 실행과 통합 실행의 튜닝이 항상 일치한다.

LiDAR 데이터는 lidar_system.launch.py 가 발행하는 토픽을 구독한다.
(이 파일은 LiDAR 드라이버/변환을 띄우지 않는다 — 반드시 먼저 lidar_system 실행)

포함하는 런치파일
    auto_usv_pkg/collision_avoidance.launch.py
        pos_trans                       : 좌표 변환 (LLA/NED, body vel)
        collision_avoidance_node_livox  : PointCloud2 직접 구독, 아크 기반 회피
        px4_cmd_pub                     : PX4 offboard 명령 발행 (50 Hz)
    ugv_docking_pkg/docking_ransac_ver2_launch.py
        docking_3bay_pc2_ransac_flight_ver2 : DBSCAN+RANSAC 4기둥 + 안쪽벽 실측/추론

데이터 흐름
    /fmu/out/*                  → pos_trans → /usv/state/{position_ned,heading,goal_ned}
    /livox/lidar (PointCloud2)  → collision_avoidance_node_livox
                                  → /vfh/command, /vfh/oa_flag
                                  → px4_cmd_pub → /fmu/in/{offboard_control_mode,trajectory_setpoint}
    /livox/lidar (PointCloud2)  → docking_3bay_pc2_ransac_flight_ver2 (PC2 직접구독)
                                  → /fmu/in/docking_test_param (10 Hz)

★ 파라미터 튜닝 위치 (단일 진실 공급원)
    충돌회피 / 좌표변환 / PX4 발행 → auto_usv_pkg/launch/collision_avoidance.launch.py
    도킹 검출                      → ugv_docking_pkg/launch/docking_ransac_ver2_launch.py
    ⚠️ 이 파일에는 파라미터를 다시 쓰지 말 것. 여기에 값을 복사하는 순간
       단독 실행(collision_avoidance / docking_ransac_ver2)과 값이 갈라진다.
    ⚠️ 두 스택은 서로 배타적인 모드에서 동작한다 (충돌회피 active_mode=3,
       도킹 active_mode=4). 즉 동시에 떠 있어도 제어 명령이 충돌하지 않는다.

실행
    # (터미널 1)  ros2 launch auto_usv_pkg lidar_system.launch.py
    # (터미널 2)  ros2 launch auto_usv_pkg Integrated_colA_docking.launch.py
    # bag 재생 디버깅: use_sim_time:=true 와 함께 ros2 bag play <bag> --clock

⚠️ [비활성화] docking_3bay_pc2 (구 y-bin 방식, ugv_docking_pkg)
    ver2 노드와 /fmu/in/docking_test_param (10Hz) 발행이 겹치므로 동시 실행 금지.
    y-bin 으로 되돌리려면 ugv_docking_pkg 쪽 런치파일에서 교체할 것.
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (
    DeclareLaunchArgument, GroupAction, IncludeLaunchDescription, OpaqueFunction,
)
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration


def _include(pkg, launch_file, use_sim_time, active_mode_value):
    """하위 런치파일을 독립 스코프로 include 한다.

    ★ scoped/forwarding 을 쓰는 이유: include 된 런치파일들은 기본적으로
      LaunchConfiguration 컨텍스트를 공유한다. 두 하위 런치파일이 모두
      'active_mode' 라는 같은 이름의 인자를 선언하므로, 스코프를 나누지 않으면
      먼저 include 된 쪽의 값이 뒤쪽의 DeclareLaunchArgument 기본값을 덮어써
      도킹이 충돌회피의 값을 물려받는 버그가 생긴다 (실측 확인됨).

    active_mode_value 가 빈 문자열이면 인자를 전달하지 않아 하위 런치파일의
    기본값이 그대로 쓰인다 (기본값 중복 방지).
    """
    args = [('use_sim_time', use_sim_time)]
    if active_mode_value:
        args.append(('active_mode', active_mode_value))

    return GroupAction(
        actions=[
            IncludeLaunchDescription(
                PythonLaunchDescriptionSource(
                    os.path.join(get_package_share_directory(pkg), 'launch', launch_file)
                ),
                launch_arguments=args,
            ),
        ],
        scoped=True,
        forwarding=False,   # 부모 컨텍스트를 물려받지 않는다 → 이름 충돌 차단
    )


def _setup(context, *_args, **_kwargs):
    # forwarding=False 이므로 부모의 LaunchConfiguration 을 하위에서 참조할 수 없다.
    # 여기서 미리 문자열로 확정해 literal 로 넘긴다.
    use_sim_time = LaunchConfiguration('use_sim_time').perform(context)
    colA_mode    = LaunchConfiguration('colA_active_mode').perform(context)
    dock_mode    = LaunchConfiguration('docking_active_mode').perform(context)

    if colA_mode and dock_mode and colA_mode == dock_mode:
        raise RuntimeError(
            f'colA_active_mode 와 docking_active_mode 가 같습니다 ({colA_mode}). '
            '두 스택이 동시에 활성화되어 PX4 제어 명령이 충돌합니다.'
        )

    return [
        # 충돌회피 스택: pos_trans + collision_avoidance_node_livox + px4_cmd_pub
        _include('auto_usv_pkg', 'collision_avoidance.launch.py',
                 use_sim_time, colA_mode),
        # 도킹 검출 스택: docking_3bay_pc2_ransac_flight_ver2
        _include('ugv_docking_pkg', 'docking_ransac_ver2_launch.py',
                 use_sim_time, dock_mode),
    ]


def generate_launch_description():

    return LaunchDescription([
        DeclareLaunchArgument(
            'use_sim_time',
            default_value='false',
            description='Use /clock (sim time) — bag 재생 시 true',
        ),
        # ★ 비워두면 각 런치파일의 기본값을 쓴다 → 통합 런치파일은 기본값을
        #   보관하지 않으므로 단독 실행과 값이 갈라질 수 없다.
        DeclareLaunchArgument(
            'colA_active_mode',
            default_value='',
            description='충돌회피 활성 operation_mode (비우면 collision_avoidance.launch.py 기본값)',
        ),
        DeclareLaunchArgument(
            'docking_active_mode',
            default_value='',
            description='도킹 활성 operation_mode (비우면 docking_ransac_ver2_launch.py 기본값)',
        ),
        OpaqueFunction(function=_setup),
    ])
