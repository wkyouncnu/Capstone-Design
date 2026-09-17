---
type: knowledge
title: QoS가 어긋나면 에러 없이 끊긴다
date: 2026-09-03
tags: [ros2, qos, debugging]
status: done
summary: 토픽은 보이고 데이터도 흐르는데 내 노드만 아무것도 못 받는 상황의 정체
---

## 한 줄 요약

> 구독자의 요구가 발행자가 제공하는 것보다 **엄격하면** 연결 자체가 성립하지 않는다. 그런데 아무 메시지도 뜨지 않는다.

## 무슨 일이 일어나는가

- Reliability 조합별 결과

| 발행자 | 구독자 | 결과 |
|---|---|---|
| RELIABLE | RELIABLE | 연결 |
| RELIABLE | BEST_EFFORT | 연결 |
| **BEST_EFFORT** | **RELIABLE** | **연결 안 됨 — 조용히** |

- 왜 자주 걸리는가
  - `rclpy` 의 **기본 QoS 가 RELIABLE**
  - 실선의 고빈도 센서 드라이버(LiDAR, 카메라)는 **BEST_EFFORT** 로 발행하는 경우가 많음
  - 기본값으로 구독자를 만들면 그대로 이 오류에 빠짐

> [!note] VRX 시뮬레이터는 반대다
> `ros_gz_bridge` 가 내보내는 토픽은 LiDAR·카메라까지 **전부 RELIABLE** 이다
> (2026-09-15, `/wamv`·`/vrx` 토픽 25개 전수 확인).
> 그러므로 규칙은 "센서는 BEST_EFFORT" 가 아니라 **"발행자 쪽을 매번 확인한다"** 이다.

- 진단 도구가 정상으로 보이는 것이 혼란의 원인

| 확인 | 결과 |
|---|---|
| `ros2 topic list` | 토픽이 보임 |
| `ros2 topic hz` | 데이터가 흐른다고 나옴 (CLI 도구는 QoS를 자동 조정) |
| **내 노드** | **콜백이 한 번도 안 불림** |

- 결과: 학생이 자기 콜백 코드를 의심하며 한 시간을 씀

## 왜 중요한가 / 어디에 쓰나

- **진단은 한 줄**

```bash
ros2 topic info /토픽이름 --verbose
```

- 발행자와 구독자의 `Reliability` 를 비교
- **2주차에 일부러 재현시킴** — VRX LiDAR에서 만났을 때 스스로 알아채게 하려는 것
- Durability도 같은 종류
  - `TRANSIENT_LOCAL` 로 발행된 정적 TF·지도를 `VOLATILE` 로 구독하면 늦게 뜬 노드는 영원히 못 받음

- 일반화하면
  - **분산 시스템에서 "조용한 실패"는 시끄러운 실패보다 비쌈**
  - 그래서 진단 명령을 먼저 가르침

- 같은 성질의 조용한 실패 — **Domain ID 불일치**
  - Simulink 의 ROS 2 블록은 **ROS 네트워크 프로필**의 Domain ID 를 쓴다
  - MATLAB 의 `ros2*` 함수는 **환경변수** `ROS_DOMAIN_ID` 를 쓴다
  - 둘이 다르면 `ros2("topic","list")` 에는 토픽이 보이는데 **모델만 한 건도 못 받는다**
  - 증상: 배가 전혀 움직이지 않고 로그 좌표가 계속 0 (2026-09-15 실측)

## 연결

- [[W02_ROS2_기초_노드와_토픽]]
- [[W03_Gazebo_VRX_구축과_좌표계]]
