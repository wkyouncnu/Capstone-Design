#!/usr/bin/env python3
"""
Livox MID-360 Driver (PointCloud2, RViz 없음)
=============================================
livox_ros_driver2 의 msg_MID360_launch.py 를 복사해 xfer_format 만 0 으로
바꾼 것. 드라이버 노드 하나만 띄운다.

왜 복사본이 필요한가
    상류(livox_ros_driver2) 가 제공하는 두 launch 는 이렇게 갈린다.
        msg_MID360_launch.py   xfer_format=1 (CustomMsg),   RViz 없음
        rviz_MID360_launch.py  xfer_format=0 (PointCloud2), RViz 있음
    이 프로젝트의 소비자(collision_avoidance_node_livox, docking_3bay_pc2)는
    PointCloud2 를 구독하므로 xfer_format=0 이 필수인데, 젯슨 실운용에서는
    RViz 를 띄울 수 없다. 둘 다 만족하는 조합이 상류에 없어 여기서 만든다.

발행 토픽
    /livox/lidar  (sensor_msgs/PointCloud2)
    /livox/imu    (sensor_msgs/Imu)

직접 실행
    ros2 launch auto_usv_pkg livox_mid360_pc2.launch.py
    # 보통은 lidar_system.launch.py 가 이 파일을 대신 불러온다.
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import Node


# ═════════════════════════════════════════════════════════════════════════
#  드라이버 파라미터 (상류 msg_MID360_launch.py 와 xfer_format 만 다름)
# ═════════════════════════════════════════════════════════════════════════
xfer_format     = 0     # 0-PointCloud2(PointXYZRTL), 1-CustomMsg  ← 상류는 1
multi_topic     = 0     # 0-모든 LiDAR 가 한 토픽 공유, 1-LiDAR 당 한 토픽
data_src        = 0     # 0-lidar, 그 외-잘못된 소스
publish_freq    = 10.0  # 발행 주기 [Hz] (5.0, 10.0, 20.0, 50.0 …)
output_type     = 0
frame_id        = 'livox_frame'
lvx_file_path   = '/home/livox/livox_test.lvx'
cmdline_bd_code = 'livox0000000001'

# 설정 파일은 상류 패키지의 것을 그대로 쓴다 (호스트/라이다 IP 가 여기 있음).
_livox_share     = get_package_share_directory('livox_ros_driver2')
user_config_path = os.path.join(_livox_share, 'config', 'MID360_config.json')

livox_ros2_params = [
    {'xfer_format': xfer_format},
    {'multi_topic': multi_topic},
    {'data_src': data_src},
    {'publish_freq': publish_freq},
    {'output_data_type': output_type},
    {'frame_id': frame_id},
    {'lvx_file_path': lvx_file_path},
    {'user_config_path': user_config_path},
    {'cmdline_input_bd_code': cmdline_bd_code},
]


def generate_launch_description():
    livox_driver = Node(
        package='livox_ros_driver2',
        executable='livox_ros_driver2_node',
        name='livox_lidar_publisher',
        output='screen',
        parameters=livox_ros2_params,
    )

    return LaunchDescription([livox_driver])
