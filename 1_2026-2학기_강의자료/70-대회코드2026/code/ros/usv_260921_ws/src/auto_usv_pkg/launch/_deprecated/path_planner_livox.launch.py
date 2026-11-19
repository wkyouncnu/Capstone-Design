#!/usr/bin/env python3
"""
Launch pos_trans + collision_avoidance_node_livox.
/livox/lidar (PointCloud2) 를 직접 구독 — pointcloud_to_laserscan 불필요.
파라미터는 config/usv_params.yaml 에서 관리.

console_scripts (setup.py):
    pos_trans                      = auto_usv_pkg.coordinate_transformer_node:main
    collision_avoidance_node_livox = auto_usv_pkg.collision_avoidance_node_livox:main
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():

    pkg_name      = 'auto_usv_pkg'
    pkg_share_dir = get_package_share_directory(pkg_name)
    param_file    = os.path.join(pkg_share_dir, 'config', 'usv_params.yaml')

    # bag 재생 테스트 시 true 로 (ros2 bag play <bag> --clock 와 함께):
    #   ros2 launch auto_usv_pkg path_planner_livox.launch.py use_sim_time:=true
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

    collision_avoidance_livox_node = Node(
        package=pkg_name,
        executable='collision_avoidance_node_livox',
        name='collision_avoidance_node_livox',
        output='screen',
        emulate_tty=True,
        parameters=[param_file, {'use_sim_time': use_sim_time}],
    )

    return LaunchDescription([
        declare_use_sim_time,
        pos_trans_node,
        collision_avoidance_livox_node,
    ])
