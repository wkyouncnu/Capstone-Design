import os
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='pointcloud_to_laserscan',
            executable='pointcloud_to_laserscan_node',
            name='pointcloud_to_laserscan',
            output='screen',
            parameters=[{
                # =========================================
                # 1. 타겟 프레임 (TF 설정)
                # =========================================
                # 라이다 데이터가 변환될 기준 좌표계입니다.
                # 앞서 설정한 라이다 TF 이름과 동일해야 합니다.
                # (만약 SLAM을 한다면 'base_link'로 설정하여 배 중심 기준으로 변환하기도 함)
                'target_frame': 'livox_frame', 
                'transform_tolerance': 0.01,

                # =========================================
                # 2. 높이 필터링 (USV 핵심 설정: 수면 제거)
                # =========================================
                # 라이다 센서(livox_frame) 중심을 0.0m로 봅니다.
                # USV 하단에 설치했다면, 센서 조금만 아래로 내려가도 바로 수면(물)입니다.
                
                # [min_height]: 바닥(수면) 노이즈 제거
                # -0.3으로 하면 물결이 칠 때 수면이 장애물로 인식될 위험이 큽니다.
                # 센서 위치가 낮으므로 -0.1m(센서 10cm 아래)까지만 유효 데이터로 봅니다.
                # 'min_height': -0.5, 
                # 'min_height': -0.1,  # colision avoidance
                'min_height' : -0.1,

                # [max_height]: 위쪽 구조물/천장 제거
                # 배의 상부 구조물이나 너무 높은 위치의 장애물은 충돌 위험이 적으므로 무시합니다.
                'max_height': 1.0,

                # =========================================
                # 3. 스캔 범위 및 해상도 (MID-360 특성 반영)
                # =========================================
                # [각도 범위]
                # MID-360은 360도 전방위 센서이므로 -Pi ~ +Pi 전체를 다 씁니다.
                # 만약 배 뒤쪽 구조물에 가린다면 각도를 줄여서(-2.0 ~ 2.0 등) 필터링할 수 있습니다.
                # 'angle_min': -3.141592, 
                # 'angle_max': 3.141592, 
                'angle_min': -1.57, 
                'angle_max': 1.57,

                # [각도 해상도]
                # 0.0087 rad는 약 0.5도입니다. 
                # 너무 정밀하게 하면(0.1도 등) 젯슨 CPU 부하가 심해지고, 
                # 너무 크게 하면 얇은 부표를 못 봅니다. 0.5도가 적당합니다.
                'angle_increment': 0.0087,

                # =========================================
                # 4. 거리 필터링
                # =========================================
                'scan_time': 0.1,    # 10Hz (MID-360 표준)
                
                # [최소 거리]
                # 라이다 케이스나 근처 부착물이 찍히지 않도록 0.2m 정도 띄웁니다.
                'range_min': 0.2,    
                
                # [최대 거리]
                # 해상에서는 멀리 보는 게 좋으므로 넉넉하게 100m로 잡습니다.
                # 'range_max': 100.0,  
                # 'range_max': 8.0,  
                'range_max': 10.0,  

                'use_inf': True,
                'inf_epsilon': 1.0
            }],
            
            # =========================================
            # 5. 토픽 연결 (Remapping)
            # =========================================
            remappings=[
                # [입력] Livox 드라이버가 뱉는 토픽 이름 (확인 필수!)
                # Livox ROS2 Driver 설정에 따라 '/livox/lidar/pointcloud' 일 수도 있음
                ('cloud_in', '/livox/lidar'), 
                
                # [출력] 2D 내비게이션 스택(Nav2)이나 Cartographer가 구독할 토픽
                ('scan', '/lidar/scan')
            ]
        )
    ])
