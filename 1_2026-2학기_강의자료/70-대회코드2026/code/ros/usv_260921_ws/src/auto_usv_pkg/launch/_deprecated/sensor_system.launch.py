import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node

def generate_launch_description():
    pkg_name = 'auto_usv_pkg'
    pkg_share = get_package_share_directory(pkg_name)
    pointcloud_pkg_dir = get_package_share_directory('pointcloud_to_laserscan')
    
    # Livox driver package share directory
    livox_pkg_share = get_package_share_directory('livox_ros_driver2')

    # ==========================================
    # 1. Camera Launch
    # ==========================================
    # camera_launch = IncludeLaunchDescription(
    #     PythonLaunchDescriptionSource(
    #         os.path.join(pkg_share, 'launch', 'camera.launch.py')
    #     )
    # )

    # ==========================================
    # 2. MID360 LiDAR Launch
    # ==========================================
    # Note: 'rviz_MID360_launch.py' launches both the Driver AND RViz visualization.
    # For a headless USV system (Jetson), it is better to use 'msg_MID360_launch.py' (Driver only)
    # to save CPU/GPU resources and avoid "No Display" errors.
    
    livox_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            # Select ONE of the following (Standard installation path is usually 'launch' directory):
            
            # Option A: Driver + RViz (What you asked for - Good for debugging on PC)
            os.path.join(livox_pkg_share, 'launch_ROS2', 'rviz_MID360_launch.py')
            
            # Option B: Driver Only (RECOMMENDED for USV/Jetson operation)
            # os.path.join(livox_pkg_share, 'launch_ROS2', 'msg_MID360_launch.py')
        )
    )

    # ==========================================
    # 3. LiDAR to Scan (Pointcloud -> LaserScan)
    # ==========================================
    lidar_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(pointcloud_pkg_dir, 'launch', 'lidar_to_scan.launch.py')
        )
    )

    # ==========================================
    # 4. PX4 Mission Node
    # ==========================================
    px4_mission_node = Node(
        package=pkg_name,
        executable='px4_cmd_pub',
        name='cmd_msg_pub_px4',
        output='screen'
    )

    return LaunchDescription([
        # camera_launch,
        livox_launch,  
        lidar_launch,
        px4_mission_node
    ])
