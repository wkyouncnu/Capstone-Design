#!/usr/bin/env python3
"""
Launch pos_trans + collision_avoidance_node.
파라미터는 config/usv_params.yaml 에서 관리.

console_scripts (setup.py):
    pos_trans                = auto_usv_pkg.coordinate_transformer_node:main
    collision_avoidance_node = auto_usv_pkg.collision_avoidance_node:main
    px4_cmd_pub              = auto_usv_pkg.px4_mission_msg_pub_node:main   # 필요 시 주석 해제
    dummy_state_pub          = auto_usv_pkg.dummy_state_pub_node:main       # 오프라인 테스트용
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():

    pkg_name = 'auto_usv_pkg'
    pkg_share_dir = get_package_share_directory(pkg_name)
    param_file = os.path.join(
        pkg_share_dir,
        'config',
        'usv_params.yaml'
    )

    # bag 재생 테스트 시 true 로 (ros2 bag play <bag> --clock 와 함께):
    #   ros2 launch auto_usv_pkg path_planner.launch.py use_sim_time:=true
    use_sim_time = LaunchConfiguration('use_sim_time')
    declare_use_sim_time = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Use /clock (sim time) instead of wall clock — bag 재생 시 true',
    )

    pos_trans_node = Node(
        package=pkg_name,
        executable='pos_trans',
        name='pos_trans',
        output='screen',
        emulate_tty=True,
        parameters=[param_file, {'use_sim_time': use_sim_time}],
    )

    collision_avoidance_node = Node(
        package=pkg_name,
        executable='collision_avoidance_node',
        name='collision_avoidance_node',
        output='screen',
        emulate_tty=True,
        parameters=[param_file, {'use_sim_time': use_sim_time}],
    )

    px4_mission_node = Node(
        package=pkg_name,
        executable='px4_cmd_pub',
        name='cmd_msg_pub_px4',
        output='screen',
        emulate_tty = True,
        parameters=[param_file, {'use_sim_time': use_sim_time}],
    )

    return LaunchDescription([
        declare_use_sim_time,
        # px4_mission_node,
        pos_trans_node,
        collision_avoidance_node,
    ])
