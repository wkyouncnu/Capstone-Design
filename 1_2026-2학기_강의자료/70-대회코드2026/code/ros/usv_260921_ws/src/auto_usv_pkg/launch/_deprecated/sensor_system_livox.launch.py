import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node

def generate_launch_description():
    pkg_name  = 'auto_usv_pkg'
    pkg_share = get_package_share_directory(pkg_name)
    livox_pkg_share = get_package_share_directory('livox_ros_driver2')

    # ==========================================
    # 1. MID360 LiDAR Driver
    # ==========================================
    # pointcloud_to_laserscan 없이 /livox/lidar (PointCloud2) 만 발행.
    # collision_avoidance_node_livox 가 직접 구독.
    livox_launch = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            # Option A: Driver + RViz (PC 디버깅용)
            os.path.join(livox_pkg_share, 'launch_ROS2', 'rviz_MID360_launch.py')

            # Option B: Driver Only (Jetson 실운용 권장)
            # os.path.join(livox_pkg_share, 'launch_ROS2', 'msg_MID360_launch.py')
        )
    )

    # ==========================================
    # 2. PX4 Mission Node  (필요 시 주석 해제)
    # ==========================================
    px4_mission_node = Node(
        package=pkg_name,
        executable='px4_cmd_pub',
        name='cmd_msg_pub_px4',
        output='screen',
    )

    return LaunchDescription([
        livox_launch,
        px4_mission_node,
    ])
