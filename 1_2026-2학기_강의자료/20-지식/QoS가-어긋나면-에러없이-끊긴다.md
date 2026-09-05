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
  - Gazebo의 고빈도 센서 토픽(LiDAR, 카메라)은 **BEST_EFFORT** 로 발행
  - 기본값으로 구독자를 만들면 그대로 이 오류에 빠짐

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

## 연결

- [[W02_ROS2_기초_노드와_토픽]]
- [[W03_Gazebo_VRX_구축과_좌표계]]
