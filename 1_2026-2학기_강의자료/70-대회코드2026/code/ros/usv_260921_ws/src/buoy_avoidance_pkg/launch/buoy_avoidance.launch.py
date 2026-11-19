"""buoy_avoidance.launch.py — 구형 부표 수로 통과 (KABOAT 2026, operation_mode 5)

뜨는 노드:
    usb_cam               /image_raw (launch_camera:=true 이고 use_sim_time:=false 일 때만, 기본 off)
                          ★ 카메라는 auto_usv_pkg lidar_system.launch.py 가 띄운다 (2026-10-24~).
                            센서 런치 없이 이 런치만으로 카메라가 필요할 때만 launch_camera:=true
    buoy_avoidance        LiDAR 클러스터링 + 카메라 색 판정 + 게이트 계획
                          + /usv/state/{heading,position_ned,goal_ned} (pos_trans)
                          → /vfh/command, /vfh/oa_flag (operation_mode == active_mode 일 때만)
                          부표 추종 중 oa_flag True, 부표가 없으면 경유점 직진 + False (충돌회피와 동일 구조)
                          → px4_cmd_pub (auto_usv_pkg collision_avoidance.launch.py) 이 PX4 로 전달

파라미터는 config/buoy_params.yaml 한 곳에서 관리한다 (이 런치에는 운용 스위치만 둔다).
active_mode 인자는 yaml 값을 덮어쓴다.
카메라-라이다 보정값(cam_*)만 배마다 달라서 calib 인자로 고른다 (2026-11-06~):
    calib:=new   config/calib_new.yaml  새 배 (하늘색 선체)  ← 기본
    calib:=old   config/calib_old.yaml  기존 배 (노란 선체)
    calib:=/절대/경로.yaml  도 가능

auto_usv_pkg 의 Integrated_colA_docking.launch.py 가 이 런치를 include 한다 (2026-10-23~).
⚠️ 통합 런치와 이 런치를 동시에 띄우지 말 것. usv_path_planner_pkg 의
   cone_pipeline_px4.launch.py 와도 마찬가지 — mode 5 에서 /vfh/command 발행자가 두 벌이 된다.

실차:
    ros2 launch auto_usv_pkg lidar_system.launch.py
    ros2 launch auto_usv_pkg collision_avoidance.launch.py      # pos_trans, px4_cmd_pub
    ros2 launch buoy_avoidance_pkg buoy_avoidance.launch.py

bag 재생 (반드시 도메인 77):
    export ROS_DOMAIN_ID=77
    ros2 launch buoy_avoidance_pkg buoy_avoidance.launch.py use_sim_time:=true
    ros2 bag play --clock 100 ~/rosbag_folder/exp1016
    (operation_mode 를 안 넣으면 /vfh/* 는 침묵하고 인지/오버레이만 돈다)
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def _calib_file(pkg_share, name):
    """calib 인자 → yaml 경로. 이름이면 config/calib_<이름>.yaml, 경로면 그대로."""
    path = name if name.endswith('.yaml') else os.path.join(pkg_share, 'config', f'calib_{name}.yaml')
    if not os.path.isfile(path):
        avail = sorted(f[6:-5] for f in os.listdir(os.path.join(pkg_share, 'config'))
                       if f.startswith('calib_') and f.endswith('.yaml'))
        raise RuntimeError(f"calib:={name} — '{path}' 없음. 가능한 값: {avail} 또는 yaml 절대경로")
    return path


def generate_launch_description():
    pkg_share = get_package_share_directory('buoy_avoidance_pkg')
    use_sim_time = LaunchConfiguration('use_sim_time')

    args = [
        DeclareLaunchArgument('params_file', default_value=os.path.join(pkg_share, 'config', 'buoy_params.yaml'),
                              description='buoy_avoidance 노드 파라미터 yaml'),
        DeclareLaunchArgument('calib', default_value='new',
                              description='카메라-라이다 보정값: new(새 배) | old(기존 배) | yaml 절대경로'),
        DeclareLaunchArgument('use_sim_time', default_value='false',
                              description='bag 재생 시 true (+ ros2 bag play --clock). true 면 usb_cam 생략'),
        DeclareLaunchArgument('launch_camera', default_value='false',
                              description='usb_cam 기동 여부 (기본 false — lidar_system.launch.py 가 카메라를 띄움)'),
        DeclareLaunchArgument('video_device', default_value='/dev/video0',
                              description='usb_cam 장치 (/dev/v4l/by-id 심볼릭 링크는 usb_cam 0.8.1 이 못 엶)'),
        DeclareLaunchArgument('active_mode', default_value='5',
                              description='이 operation_mode 에서만 /vfh/command, /vfh/oa_flag 발행'),
    ]

    camera_node = Node(
        package='usb_cam',
        executable='usb_cam_node_exe',
        name='usb_cam',
        output='screen',
        emulate_tty=True,
        parameters=[{
            'video_device': LaunchConfiguration('video_device'),
            'image_width': 640,
            'image_height': 480,
            'pixel_format': 'yuyv',     # exp1016 과 같은 설정 (/image_raw = yuv422_yuy2, 컬러)
            'camera_name': 'usv_cam',
        }],
        condition=IfCondition(PythonExpression([
            "'", LaunchConfiguration('launch_camera'), "' == 'true' and '", use_sim_time, "' != 'true'",
        ])),
    )

    def buoy_node(context):
        calib = _calib_file(pkg_share, LaunchConfiguration('calib').perform(context))
        return [Node(
            package='buoy_avoidance_pkg',
            executable='buoy_avoidance_node',
            name='buoy_avoidance',
            output='screen',
            emulate_tty=True,
            # 뒤 파일이 앞 파일을 덮어쓴다: buoy_params → calib(cam_*) → 런치 인자
            parameters=[LaunchConfiguration('params_file'), calib, {
                'use_sim_time': use_sim_time,
                'active_mode': ParameterValue(LaunchConfiguration('active_mode'), value_type=int),
            }],
        )]

    return LaunchDescription(args + [camera_node, OpaqueFunction(function=buoy_node)])
