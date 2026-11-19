#!/usr/bin/env python3
"""
LiDAR System Launch  (yaml 없이 파라미터 인라인)
================================================
Livox MID-360 드라이버 + PointCloud→LaserScan 변환을 함께 띄워
두 종류의 LiDAR 데이터를 동시에 발행한다.

발행 토픽
    /livox/lidar  (sensor_msgs/PointCloud2)  ← Livox 드라이버
    /livox/imu    (sensor_msgs/Imu)          ← Livox 드라이버
    /lidar/scan   (sensor_msgs/LaserScan)    ← pointcloud_to_laserscan

파라미터
    이 파일 상단의 SCAN_PARAMS 딕셔너리에서 직접 수정 (config yaml 제거됨)

사용처
    /livox/lidar  → collision_avoidance_node_livox, docking_3bay_pc2
    /lidar/scan   → (LaserScan 소비 노드가 있을 때만)

실행
    ros2 launch auto_usv_pkg lidar_system.launch.py
    # RViz 로 눈으로 확인하며 디버깅할 때
    ros2 launch auto_usv_pkg lidar_system.launch.py rviz:=true
    # bag 재생 디버깅: use_sim_time:=true 와 함께 ros2 bag play <bag> --clock

rviz 인자 (기본 false)
    false → auto_usv_pkg/livox_mid360_pc2.launch.py   (드라이버만, Jetson 실운용)
    true  → livox_ros_driver2/rviz_MID360_launch.py   (드라이버 + RViz, PC 디버깅)
    ⚠️ 양쪽 모두 xfer_format=0 이라 /livox/lidar 는 항상 PointCloud2 로 나온다.
       상류의 msg_MID360_launch.py 는 xfer_format=1(CustomMsg)이라 쓰지 않는다.
       그걸 쓰면 PointCloud2 를 구독하는 충돌회피·도킹 노드가 데이터를 못 받는다.
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition, UnlessCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


# ═════════════════════════════════════════════════════════════════════════
#  파라미터 (구 config/lidar_params.yaml — pointcloud_to_laserscan)
#  ⚠️ 입출력 토픽은 파라미터가 아니라 아래 remappings 에서 지정
# ═════════════════════════════════════════════════════════════════════════
SCAN_PARAMS = {
    # 타겟 프레임 (TF)
    'target_frame': 'livox_frame',   # 변환 기준 좌표계
    'transform_tolerance': 0.01,     # TF 조회 허용 지연 [s]

    # 높이 필터 (수면 제거) — 센서(livox_frame) 중심이 0.0m
    'min_height': -0.1,              # 하한 [m] (수면 노이즈 제거)
    'max_height':  1.0,              # 상한 [m] (상부 구조물 제거)

    # 스캔 각도/해상도 (MID-360, 전방만 사용)
    'angle_min': -1.57,              # [rad] (-90°)
    'angle_max':  1.57,              # [rad] (+90°)
    'angle_increment': 0.0087,       # [rad] (≈0.5°)

    # 거리/시간 필터
    'scan_time': 0.1,                # 스캔 주기 [s] → 10 Hz
    'range_min': 0.2,                # 최소 거리 [m] (자기반사 컷)
    'range_max': 7.5,                # 최대 거리 [m]

    'use_inf': True,
    'inf_epsilon': 1.0,
}


def generate_launch_description():

    livox_pkg_share = get_package_share_directory('livox_ros_driver2')
    this_pkg_share  = get_package_share_directory('auto_usv_pkg')

    use_sim_time = LaunchConfiguration('use_sim_time')
    declare_use_sim_time = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use /clock (sim time) — bag 재생 시 true',
    )

    rviz = LaunchConfiguration('rviz')
    declare_rviz = DeclareLaunchArgument(
        'rviz',
        default_value='false',
        description='true 면 RViz 를 함께 띄운다 (PC 디버깅). Jetson 실운용은 false.',
    )

    # ==========================================
    # 1. Livox MID-360 Driver  → /livox/lidar (PointCloud2)
    # ==========================================
    # 둘은 배타적이다. rviz 인자 하나로 갈아끼운다.

    # 1-a. 실운용: 드라이버만 (RViz 없음)
    livox_driver_only = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(this_pkg_share, 'launch', 'livox_mid360_pc2.launch.py')
        ),
        condition=UnlessCondition(rviz),
    )

    # 1-b. 디버깅: 드라이버 + RViz (상류 파일 그대로 사용)
    livox_with_rviz = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(livox_pkg_share, 'launch_ROS2', 'rviz_MID360_launch.py')
        ),
        condition=IfCondition(rviz),
    )

    # ==========================================
    # 2. PointCloud → LaserScan  → /lidar/scan (LaserScan)
    # ==========================================
    pointcloud_to_laserscan_node = Node(
        package='pointcloud_to_laserscan',
        executable='pointcloud_to_laserscan_node',
        name='pointcloud_to_laserscan',
        output='screen',
        parameters=[SCAN_PARAMS, {'use_sim_time': use_sim_time}],
        remappings=[
            ('cloud_in', '/livox/lidar'),
            ('scan',     '/lidar/scan'),
        ],
    )

    # ⚠️ pointcloud_to_laserscan 은 통합 스택에서 소비자가 없다.
    #    (충돌회피·도킹 모두 /livox/lidar PointCloud2 를 직접 구독)
    #    LaserScan 이 필요하면 아래 주석을 풀 것.
    return LaunchDescription([
        declare_use_sim_time,
        declare_rviz,
        livox_driver_only,              # rviz:=false (기본) — /livox/lidar (PointCloud2)
        livox_with_rviz,                # rviz:=true          — /livox/lidar (PointCloud2) + RViz
        # pointcloud_to_laserscan_node, # /lidar/scan  (소비자 없어 비활성)
    ])
