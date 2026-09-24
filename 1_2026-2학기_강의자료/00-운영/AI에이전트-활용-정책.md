---
type: plan
title: AI 에이전트 활용 정책
date: 2026-09-03
tags: [course, ai-agent, policy]
status: draft
summary: VSCode + Claude 사용을 전면 허용하면서 학습이 일어나게 만드는 규칙과 채점 방법
---

# AI 에이전트 활용 정책

> [!important] 이번 학기 **녹화 강의 영상**은 여기에 올라감 — 수업에서 놓친 부분은 영상으로 확인할 것
> **<https://youtube.com/playlist?list=PLK_f1-krzJG8>**
>
> - 매주 수업 뒤 그 주차 영상이 이 재생목록에 추가됨
> - 아래 "참조 강의" 는 **지난 학기까지의 선수 과목**이고, 이 재생목록은 **이번 학기 본 수업** 녹화임

> [!important] 강의자료 저장소 — 처음 한 번만 `git clone`, 그 뒤로는 `git pull`
>
> | 저장소 | 주소 | 받는 자리 (WSL) |
> |---|---|---|
> | 강의자료 — 주차 문서 · Simulink 모델 · MATLAB 스크립트 | **<https://github.com/wkyouncnu/Capstone-Design>** | `~/Capstone-Design` |
> | ROS 2 예제 패키지 `usv_basics` — 2주차부터 쓰는 노드 코드 | **<https://github.com/wkyouncnu/usv_basics>** | `~/capstone_ws/src/usv_basics` |
>
> | 언제 | 명령 (VS Code 의 WSL 창 터미널) | 하는 일 |
> |---|---|---|
> | 처음 한 번 | `cd ~ && git clone https://github.com/wkyouncnu/Capstone-Design.git` | 강의자료 전체를 받음 (약 400 MB) |
> | 처음 한 번 | `mkdir -p ~/capstone_ws/src && cd ~/capstone_ws/src && git clone https://github.com/wkyouncnu/usv_basics.git` | 예제 패키지를 받음. 이어서 `cd ~/capstone_ws && colcon build --symlink-install` |
> | 매주 수업 전 | `cd ~/Capstone-Design && git pull` · `cd ~/capstone_ws/src/usv_basics && git pull` | **바뀐 파일만** 받음. 다시 clone 하지 않음 |
> | 무엇이 바뀌었는지 | `git log --oneline -10` · `git show --stat HEAD` | 교수가 갱신한 내역을 확인 |
>
> - 두 저장소 모두 공개 — 로그인 없이 받아짐
> - 주차 문서는 `~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/` 에 있음. MATLAB 은 같은 폴더를 `\\wsl.localhost\Ubuntu-22.04\home\<사용자명>\Capstone-Design\...` 로 엶
> - `usv_basics` 를 받은 뒤 새 노드가 생겼으면 `colcon build --symlink-install` 을 한 번 더 돌림
> - 본인이 고친 파일 때문에 `git pull` 이 멈추면 `git stash` 로 치워 두고 다시 받음 → [[강의자료는-한-번-받고-git-pull-로-갱신한다]]

**대상**: VSCode + WSL Remote + Claude Code (10주차부터)
**학생 배포**: 10주차 자료에 이 문서의 §1\~§3을 요약해 싣는다

---

## 1. 원칙

> **평가하는 것은 "AI를 썼는가"가 아니라 "AI 출력을 검증했는가"이다.**

- 사용은 전면 허용한다. 금지하면 몰래 쓰고, 몰래 쓰면 가르칠 수 없다.
- 근거와 배경은 [[AI가-쓴-코드는-검증기록이-산출물이다]] 에 정리했다.

---

## 2. 학생이 지켜야 할 네 가지

| 요구 | 내용 | 시점 |
|---|---|---|
| **프롬프트 로그** | 주요 코드 생성에 쓴 프롬프트를 팀 레포 `docs/agent_log.md` 에 기록 | 상시 |
| **검증 기록** | 에이전트 초안 → 최종본 **diff + 수정 사유 3가지 이상** | 10주차부터 매 과제 |
| **설명 책임** | 발표 시 자기 코드의 **임의 라인을 지목받아 설명**. 못 하면 해당 항목 감점 | 6·15주차 |
| **책임 소재** | 검증 없이 병합한 코드로 인한 데모 실패는 감점 사유. 변명 불가 | 상시 |

**"수정 사유 3가지 이상"이 이 정책의 핵심 장치다.** 이게 학생을 코드를 읽게 만든다.
- 읽지 않으면 고칠 데를 못 찾고, 대개 진짜로 고칠 데가 있다.

---

## 3. 주차별 활용 지점

| 주차 | 활용 | 검증 방법 |
|---|---|---|
| 10주 | ROS 2 노드 스캐폴딩, `CLAUDE.md` 작성 | 정답지(`wamv_pid_control_v2.py`)와 비교 |
| 11주 | 포인트클라우드 전처리 파이프라인 | 부표 위치 RMSE, 오탐·미탐 측정 |
| 12주 | VFH 충돌회피 구현 | baseline과 10회 반복 비교 |
| 13주 | 영상 기반 표식 검출기 | 조명 3단계 혼동행렬 |
| 14주 | 배치 실행·로그 집계 스크립트 | 스크립트가 만든 수치를 손으로 1건 검산 |

---

## 4. 에이전트가 자주 틀리는 지점 (10주차 강의에서 다룰 것)

- 경험적으로 그럴듯하게 틀리는 곳들이다. 학생에게 미리 알려준다.

- **좌표계 부호** — ENU/NED, 쿼터니언 순서 → [[ENU와-NED를-섞으면-조용히-틀린다]]
- **QoS 설정** — 기본값 RELIABLE로 만들어 BEST_EFFORT 토픽을 못 받음
  → [[QoS가-어긋나면-에러없이-끊긴다]]
- **단위** — deg/rad, m/s vs RPM, 시간 스탬프의 기준 시계
- **ROS 버전** — Humble에 없는 Jazzy API를 자신 있게 쓴다
- **파일 경로** — 존재하지 않는 패키지 경로를 그럴듯하게 만들어낸다

---

## 5. 교수·조교용 — 채점 시 확인 절차

1. `docs/agent_log.md` 존재 여부
2. 제출된 diff에서 **수정이 실질적인가** — 변수명만 바꾼 것은 인정하지 않는다
3. 발표 중 무작위로 한 줄 지목 → 설명 요구
4. diff 없이 완성도만 높은 제출물은 **설명 책임으로 검증**한다

## 6. 부수 효과 — 다음 학기 자료가 된다

- 초안과 최종본의 diff가 한 학기 쌓이면 **어디서 AI가 반복적으로 틀리는지가 데이터로 남는다.**
- 학기 말에 이를 모아 §4를 갱신한다. 이 문서는 그렇게 매년 두꺼워지는 것을 전제로 한다.

## 연결

- [[AI가-쓴-코드는-검증기록이-산출물이다]]
- [[평가와-팀운영]]
- [[강의계획서]]
