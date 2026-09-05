---
type: reference
title: 주차별 강의자료 안내
date: 2026-09-03
tags: [index, student-guide]
status: done
summary: 학생 배포용 주차별 자료의 읽는 법과 환경 요약
---

# 주차별 강의자료

캡스톤디자인 2026-2 · VRX 기반 자율운항보트(USV) 제어 시스템 설계

> 이 폴더는 **학생 배포본**이다. 전체 계획과 평가 기준은 상위 폴더의 [[README]] 를 본다.

## 자료 목록

| 주차 | 문서 | 슬라이드 | 주제 |
|---|---|---|---|
| 1 | [[W01_개발환경_구축과_USV_자율운항_개관]] | `W01_슬라이드.html` | 자율운항 개관 · KABOAT/VRX 임무 · WSL2 설치 · 리눅스 기본기 |
| 2 | [[W02_ROS2_기초_노드와_토픽]] | — | ROS 2 설치 · 노드/토픽/메시지 · DDS와 QoS · 표본화와 에일리어싱 |
| 3 | [[W03_Gazebo_VRX_구축과_좌표계]] | — | Gazebo Garden · VRX 설치와 실행 · 6자유도 · ENU/NED · 쿼터니언 · TF2 |
| 4 | [[W04_VRX_심화_모델구조와_토픽조사]] | — | WAM-V URDF·Xacro · 센서 배치 수정 · 토픽 전수조사 · Mapviz |
| 5 | [[W05_VSCode와_Claude_에이전트_첫_제어노드]] | — | VS Code · Claude Code · 첫 제어 노드 · MATLAB 연동 |
| 6 전 | [[W06_0_Simulink_기초]] | — | **Simulink 속성 입문 (3시간 x 2회)** · 1일차 문법, 2일차 7~9주차에서 쓰는 블록 (모델 24개) |
| 6 | [[W06_Simulink_ROS2_연동과_첫_제어기]] | — | Simulink↔ROS 2 · 첫 제어기 · **오프라인 WAM-V** (모델 5개) |
| 7 | [[W07_웨이포인트_유도_atan2와_LOS]] | — | 웨이포인트 유도 · atan2 vs LOS · 조류 (모델 2개 포함) |
| 8 | [[W08_한점을_중심으로_도는_로이터링]] | — | 벡터필드 로이터링 · 방향·속도·반경 변경 (모델 2개) |
| 9 | [[W09_Stateflow_미션_웨이포인트와_로이터링]] | — | Stateflow 미션 FSM · WP → 로이터 → WP (모델 2개) |
| 10 | [[W10_틸팅추진기_추력배분과_동적위치유지]] | — | 방위추진기 ±45° · 추력 배분 · DP · 바람·파랑 (모델 2개) |
| 11~ | *(작성 예정)* | — | 인지 트랙 · 통합 |

## 읽는 방법

각 주차 문서는 같은 구조를 갖는다.

```
학습 목표          ← 이 주차가 끝나면 할 수 있어야 하는 것
1부 이론           ← 수업 중 강의. 미리 읽어오면 좋다
2부 실습           ← 명령어를 그대로 따라 실행
실습 체크리스트     ← 다음 주 수업을 따라가기 위한 최소 조건
과제               ← 제출물과 평가 배점
자주 발생하는 문제   ← 막혔을 때 여기부터
참고 자료          ← 더 깊이 볼 것
다음 주 예고        ← 준비물
```

### 막혔을 때 순서

1. 해당 주차 문서의 **"자주 발생하는 문제"** 표
2. [[WSL-VRX-환경구축]] §11 트러블슈팅
3. 팀 내 공유 → 팀 채널에 질문 (**에러 메시지 전문 포함**)
4. 조교 / 교수

## Simulink 모델 읽는 법

6~10주차 모델 25개는 모두 같은 규칙으로 그려져 있다.

| 색 | 역할 |
|---|---|
| 파랑 | 유도 Guidance |
| 보라 | 미션 판단 (Stateflow, 모드 전환) |
| 주황 | 제어 Control |
| 노랑 | 추진기 |
| 초록 | 운동모델 |
| 연보라 | ROS 통신 |
| 회색 | 로깅·표시 |
| 분홍 | 외란 (바람·파랑) |
| 흰색 | 설정값 (Constant) |

- **왼쪽에서 오른쪽으로** 읽는다 — 유도 → 제어 → 추진기 → 운동모델 → 로깅
- 선은 **직선 또는 직각**만. 대각선은 없다
- 뒤로 돌아가는 선은 **되먹임**이다. 대부분 Goto/From 태그로 보낸다

### 만지다가 흐트러졌을 때

```matlab
tidy_layout('W07_0_offline')
```

- 모델 자체가 깨졌으면 생성 스크립트를 다시 돌린다

```matlab
W07_setup
build_w07_models
```

## 슬라이드 여는 법

`W01_슬라이드.html` 을 브라우저로 열면 된다. 인터넷 연결이 필요 없다.

| 키 | 동작 |
|---|---|
| `→` `Space` | 다음 |
| `←` | 이전 |
| `F` | 전체화면 |
| `S` | 발표자 뷰 (현재/다음 슬라이드 + 노트 + 타이머) |
| `B` | 화면 암전 |

URL 끝의 `#/7` 은 7번 슬라이드를 뜻한다. 새로고침해도 자리가 유지된다.

## 환경 요약

| 항목 | 버전 |
|---|---|
| OS | Windows 11 + WSL2 + Ubuntu 22.04 |
| ROS 2 | Humble Hawksbill |
| Gazebo | Garden (`gz-garden`) |
| VRX | 2.4.x — **`humble` 브랜치** |
| MATLAB | R2024b + Simulink + ROS Toolbox |
| 개발환경 | VSCode + WSL Remote + Claude Code |

### 워크스페이스 구조

```
~/vrx_ws/          ← VRX 시뮬레이터 (3주차)
  └── src/vrx/
~/capstone_ws/     ← 본 과목에서 만드는 패키지 (2주차부터)
  └── src/usv_basics/
```

`~/.bashrc` 에 아래가 들어 있어야 한다.

```bash
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
source ~/capstone_ws/install/setup.bash
export ROS_DOMAIN_ID=<자기 팀 번호>
```

## 자주 쓰는 명령

```bash
# VRX 실행
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta

# 장애물 필드 / 도킹 월드 — 연구실 배포 파일을 vrx_ws 에 덮어써야 동작한다
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_ca
ros2 launch vrx_gz competition4docking.launch.py world:=scan_dock_deliver_full

# 토픽 진단 — 데이터를 못 받으면 QoS부터 의심
ros2 topic list | grep sensors
ros2 topic hz   /wamv/sensors/imu/imu/data
ros2 topic info /wamv/sensors/imu/imu/data --verbose

# 배 움직이기
ros2 topic pub --rate 10 /wamv/thrusters/left/thrust  std_msgs/msg/Float64 "{data: 200.0}"
ros2 topic pub --rate 10 /wamv/thrusters/right/thrust std_msgs/msg/Float64 "{data: 200.0}"

# 워크스페이스 빌드
cd ~/capstone_ws && colcon build --symlink-install && source install/setup.bash

# 시각화
rqt_graph
rviz2
ros2 run tf2_tools view_frames
```

---

*인공지능 필드 로보틱스 연구실 · 충남대학교 자율운항시스템공학과*
