---
type: reference
title: Simulink 모델 인벤토리
date: 2026-09-03
tags: [simulink, matlab, assets]
status: done
summary: 연구실 워크스페이스의 8개 slx 모델과 실행 스크립트 — 어느 주차에 무엇을 투입하나
---

# Simulink 모델 인벤토리

- 경로: `[2025] ROS2_VRX_Gazebo_Simulink/`

> [!important] 이 수업은 **기본 후방 2추진기** WAM-V 를 쓴다
> 아래 tilt4 모델들은 **4방위추진기**용이다. 그대로 돌아가지 않는다.
> 상태추정 · LOS · 헤딩제어 · Stateflow FSM 은 재사용하고,
> **추력배분 블록(`rpi_otter`)만 2×2 차동 역변환으로 교체**한다 → [[VRX-월드와-패키지]]

- 공통 설정: 고정 스텝 `FixedStep = 0.01` (100 Hz), `StopTime = inf` (Gazebo와 실시간 협조 시뮬레이션).

## 모델

| 파일 | 내용 | 투입 |
|---|---|---|
| `X_pose_config_test_2022a.slx` | 제어기 없는 **순수 ROS 2 인터페이스·프레임 변환 테스트**. Subscribe 11 / Publish 9, Bus Assignment 9개 | **6주** |
| `GPS_INS_integration.slx` | GPS + IMU 융합 → `/gnss_ins_odom` (`nav_msgs/Odometry`) 발행. 모든 tilt4 모델이 이걸 구독 | 6주 |
| `VRX_tilt4_controller_unberthing.slx` | tilt4 **축약판** — FSM 없이 이안 + 위치/헤딩 제어만 | **7~8주** |
| `VRX_tilt4_controller_full.slx` | **완성본**. Stateflow 미션 FSM + 추력배분 + LOS + 상태추정 | 9 · 13주 |
| `VRX_manual_control.slx` | 조이스틱 수동조종 (3추진기) | 4주 |
| `RC_transimitter_test.slx` | 조이스틱 매핑 확인. ROS 없음 | 예비 |
| `VRX_control_final_docking_2022.slx` | 3추진기 접안. 내부에 WAM-V 동역학 모델 포함 → **Gazebo 없이 오프라인 실행 가능** | 대체 실습 |
| `CA_X_pose_config_test_2022a.slx` | 조이스틱 + 추력배분. ERT 코드생성된 모델 | 6주 심화 |

## VRX_tilt4_controller_full.slx 내부 구조

- 전체 아키텍처의 참조 구현이다. 13주차에 통째로 뜯는다.

### Stateflow 미션 FSM

```
Unberthing          -> Waypoint            [오차 <= threshold && |헤딩오차| <= 1 && duration >= 5s]
Waypoint            -> Dynamic_Positioning [waypoint_finished == 1]
Dynamic_Positioning -> Docking_Approach    [DP_error <= threshold && duration >= 5s]
Docking_Approach    -> Docking_Final       [approach_finished == 1]
```

- `duration >= 5s` 조건이 KABOAT 임무 2의 "정지 후 5초 유지"를 그대로 구현한 것이다.

### 주요 MATLAB Function 블록

| 블록 | 역할 |
|---|---|
| `rpi_otter` | 추력배분. 3×8 가중 의사역행렬 + **각도포화 반복 재해**(최대 100회). **← 2추진기용 2×2 역변환으로 교체 대상** |
| `waypoint_cmd` | LOS 유도. 경로 방위각 · 횡방향 오차 · 목표 헤딩 · 수락반경 웨이포인트 전환 |
| `fuseIMUGPS` | `insfilterNonholonomic` 기반 상태추정 (ENU, IMU 100 Hz, decimation 2) |
| `LLA2NED` · `ENU_to_NED` · `wrapToPi` | 좌표 변환 → [[ENU와-NED를-섞으면-조용히-틀린다]] |

## 실행 스크립트

| 파일 | 내용 |
|---|---|
| `VRX_SHIFT_MINI_Full.m` | **마스터 실행 스크립트**. 위성지도 `ginput` 으로 7점 미션 클릭(이안 / WP×3 / DP / 접근 / 도킹), 추진기 기하와 전 게인 정의 |
| `VRX_SHIFT_MINI_Unberthing.m` | 축약판. 1점만 클릭 |
| `WAMV_USV_Control_Allocation.m` | **독립 실행형 추력배분 교재**. 로직 스윕 · 4시나리오 벡터도 · Monte-Carlo 도달가능 제어집합 그림 자동 생성 → 7주차 |
| `USV_display.m` · `USV_draw.m` · `circle_draw.m` | 위성지도 위 실시간 항적 애니메이션 (7 웨이포인트 라벨링 지원) |
| `deg2utm.m` · `utm2deg.m` | WGS84 UTM 변환 유틸 |
| `mission_points.mat` | 저장된 7점 미션 |

## 주요 파라미터 (VRX_SHIFT_MINI_Full.m)

```
lla0 = [-33.72276870341191, 150.67399057896623, 1.183941401541233]   시드니 레가타 원점
lf = la = 1.5,  d = 1.027135                                          추진기 레버암 [m]
alpha_max = deg2rad(45) * [1 1 1 1]                                   틸트 한계 (4추진기 전용)
n_max = 1500, n_min = -1500                                           RPM 한계
k_pos = 0.02216/2,  k_neg = 0.01289/2                                 추력계수 (전/후진 비대칭)

Kp_u = 450,  Ki_u = 200,  Kd_u = 50       서지
Kp_psi = 1500,  Kd_psi = 250,  N = 100    헤딩
Delta = 7,  R_LOS = 5,  threshold = 1     LOS 전방주시거리 · 수락반경 · 위치 허용오차
```

## 정리 필요 사항

- `VRX_berthing_disturbance_script.m` 에 하드코딩된 절대 경로 `addpath` — 학생 환경에서 실패한다
- `VRX_SHIFT_MINI_Full.m` 이 `circle_draw.m` 을 로컬 함수로 섀도잉

## 연결

- [[VRX-월드와-패키지]]
- [[배는-급정지하지-않는다]]
- [[강의계획서]]
