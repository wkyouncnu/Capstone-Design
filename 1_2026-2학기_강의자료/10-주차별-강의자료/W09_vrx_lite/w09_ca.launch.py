# w09_ca.launch.py — 9주차 장애물 월드에 배를 **정해진 자리에** 띄운다
#
#   vrx_gz 가 들고 있는 competition.launch.py 는 배 자리를 (-532, 162, yaw 1 rad) 로
#   코드에 박아 두었고 (competition.launch.py:46), 그것을 바꿀 인자가 없다.
#   이 주차의 경로 원점은 (동 -532, 북 200) 이다 — 38 m 북쪽이다.
#
#   그래서 competition.launch.py 를 그대로 베끼고 **자리 인자만 더한다.**
#   vrx 설치본은 건드리지 않는다. (텀프로젝트 TP_haeyang/haeyang.launch.py 와 같은 꼴)
#
#   쓰는 법 (run_vrx_ca.sh 가 알아서 부른다)
#     ros2 launch /절대경로/w09_ca.launch.py world:=~/capstone_ws/worlds/w09/stationkeeping_task \
#          urdf:=~/capstone_ws/wamv/wamv_ca_lite.urdf

import os

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.actions import OpaqueFunction
from launch.substitutions import LaunchConfiguration

import vrx_gz.launch
from vrx_gz.model import Model


def launch(context, *args, **kwargs):
    world_name = LaunchConfiguration('world').perform(context)
    sim_mode = LaunchConfiguration('sim_mode').perform(context)
    bridge = LaunchConfiguration('bridge_competition_topics').perform(context).lower() == 'true'
    robot_urdf = LaunchConfiguration('urdf').perform(context)
    headless = LaunchConfiguration('headless').perform(context).lower() == 'true'
    gz_paused = LaunchConfiguration('paused').perform(context).lower() == 'true'
    competition_mode = LaunchConfiguration('competition_mode').perform(context).lower() == 'true'
    extra_gz_args = LaunchConfiguration('extra_gz_args').perform(context)

    x = float(LaunchConfiguration('x').perform(context))
    y = float(LaunchConfiguration('y').perform(context))
    z = float(LaunchConfiguration('z').perform(context))
    yaw = float(LaunchConfiguration('yaw').perform(context))

    m = Model('wamv', 'wam-v', [x, y, z, 0.0, 0.0, yaw])
    if robot_urdf and robot_urdf != '':
        m.set_urdf(robot_urdf)
    models = [m]

    world_name, _ext = os.path.splitext(world_name)
    procs = list(vrx_gz.launch.simulation(world_name, headless, gz_paused, extra_gz_args))
    base = os.path.basename(world_name)
    procs += list(vrx_gz.launch.spawn(sim_mode, base, models, ''))
    if sim_mode in ('bridge', 'full') and bridge:
        procs += list(vrx_gz.launch.competition_bridges(base, competition_mode))
    return procs


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('world', default_value='stationkeeping_task'),
        DeclareLaunchArgument('sim_mode', default_value='full'),
        DeclareLaunchArgument('bridge_competition_topics', default_value='True'),
        DeclareLaunchArgument('headless', default_value='False'),
        DeclareLaunchArgument('urdf', default_value=''),
        DeclareLaunchArgument('paused', default_value='False'),
        DeclareLaunchArgument('competition_mode', default_value='False'),
        DeclareLaunchArgument('extra_gz_args', default_value=''),
        # 배를 띄울 자리 — 이 주차 경로의 원점 (W09_setup.m 의 path_east0 · path_north0)
        DeclareLaunchArgument('x', default_value='-532.0'),
        DeclareLaunchArgument('y', default_value='200.0'),
        DeclareLaunchArgument('z', default_value='0.0'),
        DeclareLaunchArgument('yaw', default_value='1.0'),
        OpaqueFunction(function=launch),
    ])
