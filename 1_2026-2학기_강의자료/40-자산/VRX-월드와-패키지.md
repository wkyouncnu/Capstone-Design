---
type: reference
title: VRX 월드와 ROS 2 패키지
date: 2026-09-03
tags: [vrx, gazebo, ros2, assets]
status: done
summary: Term Project 무대가 될 커스텀 월드와 재사용 가능한 Python 인지 노드 목록
---

# VRX 월드와 ROS 2 패키지

- 경로: `[2025] ROS2_VRX_Gazebo_Simulink/src/`
- VRX 버전: **2.4.1** (Gazebo Garden + ROS 2 Humble)

## 커스텀 월드 — Term Project 무대

- **이미 만들어져 있음. 새로 만들 필요 없음**
- 다만 일부는 **upstream VRX 에 없는 연구실 추가 파일**임

> [!caution] 2026-09-03 검증 결과
> osrf/vrx `humble` 브랜치(커밋 `dc30ed8d`, VRX 2.4.1)의 파일 목록을 `git ls-tree` 로 직접 대조함.
> 아래 표의 **연구실 추가** 항목은 upstream 에 존재하지 않음.
> 학생에게 **별도 배포 패키지**로 전달해야 함 → [[WSL-VRX-환경구축]] §5.5

| 월드 | 출처 | 구성 | 투입 |
|---|---|---|---|
| `sydney_regatta.sdf` | upstream | 기본 해역 | 3~9주 |
| `stationkeeping_task.sdf` | upstream | 위치유지 과제 | 13주 |
| `gymkhana_task.sdf` | upstream | 컬러 게이트 + 장애물 | 11주 |
| `scan_dock_deliver_task.sdf` | upstream | 표식 판독 + 도킹 (VRX 원본) | 12주 |
| `sydney_regatta_ca.sdf` | **연구실 추가** | **적색 마커부표 36개 장애물 필드** + post 13개 | 10~11주 |
| `sydney_regatta_ca_v2.sdf` | **연구실 추가** | 색상 혼합 소규모 필드 (적/녹/백/흑/주황) | 10주 |
| `scan_dock_deliver_CA.sdf` | **연구실 추가** | **부표 80개** + 도킹 플랫폼 2개 | Term Project 통합 |
| `scan_dock_deliver_full.sdf` | **연구실 추가** | `custom_docking_station` — bay1 / bay2 / bay3 | 12~13주 |

- 연구실 추가 파일의 원본 위치: `[2025] ROS2_VRX_Gazebo_Simulink/src/vrx/`
- `custom_docking_station` 모델 실체: `vrx_urdf/vrx_gazebo/models/custom_docking_station/`
  - `vrx_gz/models/` 가 아니라 다른 패키지에 있어 찾을 때 헤맬 수 있음
- 런치 파일
  - upstream: `competition.launch.py` · `spawn.launch.py` · `spawn_config.launch.py` · `usv_joy_teleop.py` · `vrx_environment.launch.py`
  - **연구실 추가**: `competition4docking.launch.py`

## 재사용할 Python 노드

| 파일 | 내용 | 투입 |
|---|---|---|
| `vrx_control/collision_avoidance_v2.py` | 고정 각도 회피. **나쁜 baseline 교보재** | 11주 |
| `vrx_control/collision_avoidance_kaboat.py` | LaserScan → 슬라이딩윈도우 장애물 밀도 → 비용 기반 안전방위 선정. 장애물 임계 5.0 m, 전방 각도범위 ±30°, 최대거리 40 m | 11주 |
| `vrx_control/wamv_pid_control_v2.py` | UTM 웨이포인트 PID, 10 Hz. 거리 게인 7.0 / 0.5, 헤딩 게인 300.0 / 0.7 | 5주 정답지 |
| `ros2_simulink/auto_berthing_seek.py` | 복셀 0.1 m → 2D 필터 3.5 m → **RANSAC 평면분할**(임계 0.05, n=3, 1000회) → 도크 법선 → `/docking_info` | 13주 |
| `pointcloud_to_laserscan/` | PointCloud2 → LaserScan. **16빔 LiDAR에 맞게 재튜닝 필요** | 10주 |

- 런치 파일: `vrx_kaboat.launch.py`, `wamv_collision_avoidance.launch.py`, `ros2_simulink.launch.py`

## WAM-V 추진기 구성

> [!important] 이 수업은 **기본 후방 2추진기**를 쓴다
> `competition.launch.py` 의 기본 스폰 구성이 그대로 이것이다 (`thruster_config:=H`).

**채택 구성 — 후방 2추진기 (`wamv_aft_thrusters.xacro`)**

```
left   (-2.373776,  1.027135, 0.318237)   장착각 0 deg
right  (-2.373776, -1.027135, 0.318237)   장착각 0 deg
```

- 좌우 반폭 **1.027 m**, 장착각 0도 → 두 추진기 모두 선수 방향
- **차동 추력배분 (2×2)**

```
X = F_L + F_R                      전진력
N = (F_L - F_R) x 1.027            요모멘트 (NED, 양수면 우선회)

F_L = X/2 + N / (2 x 1.027)
F_R = X/2 - N / (2 x 1.027)
```

- **과소구동** — 독립 입력 2개로 3자유도를 다뤄야 함. sway 직접 제어 불가
- 조인트는 `revolute` ±180° 이고 `.../pos` 토픽도 있으나 **각도는 0 고정**

**참고 구성 — 4방위추진기 (`wamv_x_thrusters.xacro`, tilt4 자산이 쓰는 것)**

```
left_front    ( 1.600,  0.700, 0.250)   mount yaw -45 deg
right_front   ( 1.600, -0.700, 0.250)   mount yaw +45 deg
left_rear     (-2.374,  1.027, 0.318)   mount yaw +45 deg
right_rear    (-2.374, -1.027, 0.318)   mount yaw -45 deg
```

- 배분: 3자유도 × 8미지수 가중 의사역행렬 + 각도포화 반복 재해 (`rpi_otter`)
- **틸트 한계 ±45°는 URDF 가 아니라 제어기의 소프트웨어 제약**
  - `engine.xacro` 조인트 한계는 `lower="-pi" upper="pi"` (±180°) — 2026-09-03 upstream 확인
  - ±45° 는 `VRX_SHIFT_MINI_Full.m` 의 `alpha_max` 와 `rpi_otter` 안에 하드코딩됨
- 7주차에 **본 과목 구성과 대조하는 비교 자료**로만 쓴다
- 그 밖: 3추진기 바우스러스터(`bow_wamv/`), 커스텀 2추진기(`my_wamv/`)

## 주요 토픽

| 토픽 | 타입 | 방향 |
|---|---|---|
| `/wamv/sensors/gps/gps/fix` | `sensor_msgs/NavSatFix` | 구독 |
| `/wamv/sensors/imu/imu/data` | `sensor_msgs/Imu` | 구독 |
| `/wamv/sensors/lidars/lidar_wamv_sensor/points` | `sensor_msgs/PointCloud2` | 구독 |
| `/wamv/sensors/lidars/lidar_wamv_sensor/scan` | `sensor_msgs/LaserScan` | 구독 |
| `/gnss_ins_odom` | `nav_msgs/Odometry` | Simulink 발행 → 구독 |
| **`/wamv/thrusters/left/thrust`** | `std_msgs/Float64` | **발행** |
| **`/wamv/thrusters/right/thrust`** | `std_msgs/Float64` | **발행** |
| `/wamv/thrusters/{left,right}/pos` | `std_msgs/Float64` | (미사용 — 0 고정) |

- 2026-09-03 VRX 를 실제로 띄워 `ros2 topic list` 로 확인함
- 4추진기 구성으로 바꾸면 `left_front` 등 8개 토픽이 나온다

## 연결

- [[Simulink-모델-인벤토리]]
- [[Term-Project-명세]]
- [[W03_Gazebo_VRX_구축과_좌표계]]
