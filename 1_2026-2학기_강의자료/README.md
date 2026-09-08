---
type: reference
title: 캡스톤디자인 2026-2 볼트 홈
date: 2026-09-03
tags: [index, moc]
status: done
summary: VRX 기반 USV 제어·자율임무 수업의 강의자료와 지식 저장소 진입점
---

# 🛥️ 캡스톤디자인 2026-2

**VRX 기반 자율운항보트(USV) 제어 시스템 설계 및 자율임무 구현**
학부 4학년 · 주 3시간 연강 · 충남대학교 자율운항시스템공학과

> [!info] 환경
> Windows 11 + WSL2 · Ubuntu 22.04 · ROS 2 Humble · Gazebo Garden · VRX 2.4.x (`humble` 브랜치)
> MATLAB R2024b + Simulink + ROS Toolbox · VSCode + Claude Code

> [!tip] 처음이라면
> **[[강의계획서]]** — 15주 전체 계획, 평가, 개강 전 준비
> **[[WSL-VRX-환경구축]]** — 설치 전 과정 (1~3주차 실습의 원본)
> **[[Term-Project-명세]]** — 기말 과제가 정확히 무엇인가
> **[[MD를-PDF로-내보내기]]** — 배포용 PDF 만드는 법

> [!important] 자료 형식
> - 강의자료는 **Markdown** 으로만 만든다. HTML 슬라이드는 만들지 않는다
> - 배포는 **MD + PDF 쌍**. PDF는 `bash _tools/md2pdf.sh <파일.md>` 로 생성
> - **명령어는 항상 MD에서 복사**할 것. PDF에서 복사하면 줄바꿈·하이픈이 깨진다
> - 그림은 `assets/` 의 SVG. 작성 규칙은 [[CLAUDE]] §5

---

## 🎯 이 수업이 만드는 것

15주 뒤 학생이 만든 소프트웨어가 배를 혼자 몬다.

```
이안 → 부표 36개 장애물 필드 통과 → 반경 5m 안에서 5초 정지 → 표식 찾아 도킹
```

전반부는 **Gazebo 운동모델 위에서 Simulink 제어기로 배를 움직이는 것**,
후반부는 **VSCode + Claude 에이전트로 LiDAR·영상 인지 노드를 직접 만드는 것**이다.

---

## 📅 주차별 강의자료 — `10-주차별-강의자료/`

| 주차 | 문서 | 그림 | 주제 |
|---|---|---|---|
| 1 | [[W01_개발환경_구축과_USV_자율운항_개관]] | 3장 · PDF 19쪽 | 인지·판단·제어 · KABOAT/VRX 임무 · WSL2 · 리눅스 기본기 |
| 2 | [[W02_ROS2_기초_노드와_토픽]] | 19장 · PDF 50쪽 | VS Code+WSL · 노드·토픽·패키지 · rqt와 RViz2 · QoS · 에일리어싱 |
| 3 | [[W03_Gazebo_VRX_구축과_좌표계]] | 2장 · PDF 17쪽 | Gazebo·VRX 설치 · 6자유도 · ENU/NED · TF2 |
| 4 | [[W04_VRX_심화_모델구조와_토픽조사]] | 2장 · PDF 16쪽 | WAM-V URDF·Xacro · 센서 배치 수정 · 토픽 전수조사 · Mapviz |
| 5 | [[W05_VSCode와_Claude_에이전트_첫_제어노드]] | 3장 · PDF 21쪽 | VS Code 설치 · Claude Code 연동 · 첫 제어 노드 · **MATLAB MCP** 연동 |
| 6 전 | [[W06_0_Simulink_기초]] | 12장 · PDF 42쪽 | **Simulink 속성 입문 (3시간 x 2회)** · 1일차 블록·솔버·MATLAB Function·Subsystem·버스·PID·로깅 · 2일차 Mux·Unit Delay·Integrator·Switch·Enabled·Mask · **모델 24개 배포** |
| 6 | [[W06_Simulink_ROS2_연동과_첫_제어기]] | 7장 · PDF 21쪽 | Simulink↔ROS 2 연동 · 직진·선회·헤딩·속도 제어 · **오프라인 WAM-V** · **모델 5개 배포** |
| 7 | [[W07_웨이포인트_유도_atan2와_LOS]] | 3장 · PDF 24쪽 | 웨이포인트 유도 atan2 vs LOS · 조류 실험 · **오프라인+VRX 모델 2개** |
| 8 | [[W08_한점을_중심으로_도는_로이터링]] | PDF 20쪽 | 벡터필드 로이터링 · 방향·속도·반경 변경 · **오프라인+VRX 모델 2개** |
| 9 | [[W09_Stateflow_미션_웨이포인트와_로이터링]] | PDF 18쪽 | **Stateflow 미션 FSM** · WP → 로이터 → WP · **오프라인+VRX 모델 2개** |
| 10 | [[W10_틸팅추진기_추력배분과_동적위치유지]] | 8장 · PDF 23쪽 | **방위추진기 ±45°** · 추력 배분 · **동적위치유지(DP)** · 바람·파랑 · **모델 2개** |
| 11 | *(예정)* | | LiDAR 신호처리 · 부표 탐지 |
| 12 | *(예정)* | | LiDAR 기반 충돌회피 · **역할 로테이션** |
| 13 | *(예정)* | | 영상처리 · LiDAR-카메라 융합 · 도킹 표식 |
| 14 | *(예정)* | | 도킹 접근(10주차 DP 재사용) · 통합 검증 · 성능 정량화 |
| 15 | *(예정)* | | 최종 발표 |

> [!note] `W01_슬라이드.html`
> 이전에 만든 HTML 슬라이드 덱. 필요하면 쓰되 **더 만들지 않는다.**
> 앞으로 모든 주차는 MD + PDF 로만 제작.

---

## 📋 운영 — `00-운영/`

| 문서 | 내용 |
|---|---|
| [[강의계획서]] | 15주 계획 · 기술 스택 · 재사용 자산 · 개강 전 체크리스트 |
| [[평가와-팀운영]] | 성적 배분 · 팀 구성 · 역할 로테이션 · 미팅 규칙 |
| [[AI에이전트-활용-정책]] | 무엇을 허용하고 무엇을 평가하는가 |

## 🧠 다음 학기에도 쓸 원리 — `20-지식/`

| 카드 | 내용 |
|---|---|
| [[ENU와-NED를-섞으면-조용히-틀린다]] | 좌표계 실수는 에러를 내지 않는다. 그냥 이상하게 움직인다 |
| [[QoS가-어긋나면-에러없이-끊긴다]] | 토픽은 보이는데 내 노드만 못 받는 상황의 정체 |
| [[배는-급정지하지-않는다]] | 육상 로봇 회피 알고리즘을 그대로 가져오면 실패하는 이유 |
| [[측정하지-않은-성공은-성공이-아니다]] | 이 수업 평가 기준의 근거 |
| [[AI가-쓴-코드는-검증기록이-산출물이다]] | 에이전트를 쓰는 수업에서 무엇을 채점할 것인가 |
| [[환경구축-실패가-가장-비싼-비용이다]] | 1주차에 잃은 3시간은 15주 내내 회복되지 않는다 |
| [[조류가-있으면-뱃머리와-진행방향이-다르다]] | 크랩각. 선수각을 맞춰도 배는 옆으로 흘러간다 |
| [[목표를-향해-가는-것과-경로를-따라가는-것은-다르다]] | atan2 와 LOS. 도착과 경로 준수는 다른 문제다 |
| [[오프라인-모델이-시뮬레이터와-같아야-게인이-옮겨간다]] | 계수를 시뮬레이터에서 그대로 가져오는 이유 |
| [[USV-운동모델은-왜-이렇게-생겼나]] | 수업에서 뺀 이론의 보관소 — Fossen · Nomoto · 추력배분 |
| [[읽히지-않는-블록도는-읽히지-않는-코드다]] | 블록 배치와 색은 장식이 아니다. 겹침 0 을 세어서 확인한다 |
| [[궤적이-겹치면-이격은-오차가-아니라-지연이다]] | 두 시뮬레이션을 거리 하나로 비교하면 안 되는 이유 |

## 🔧 환경 — `30-환경/`

| 문서 | 내용 |
|---|---|
| [[WSL-VRX-환경구축]] | 설치 전 과정 + 원본 PPT 오류 4건 수정 + MATLAB 연동 + 이미지 배포 |
| [[MD를-PDF로-내보내기]] | `md2pdf.sh` 일괄 변환 · 배포 규칙 · 그림 넣는 법 |
| [[Claude-작업방식-스킬]] | 볼트 스킬 2종 · 지시 → 동작 대응표 · 볼트 점검 스크립트 |

## 🤖 스킬 — `.claude/skills/`

| 스킬 | 담고 있는 것 |
|---|---|
| `capstone-lecture-vault` | 강의자료 작성·문체·수식·PDF·그림·VRX 검증·볼트 유지 절차 |
| `simulink-gnc-models` | 모델 생성·배치 정리·MSS 규약·모델 검증 절차 |

- 이 폴더에서 Claude Code 를 열면 **자동으로 인식**됨. 설명은 [[Claude-작업방식-스킬]]
- 점검 — `bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh` (전 항목 0 건이 합격선)

## 🛠 도구 — `_tools/`

| 파일 | 역할 |
|---|---|
| `md2pdf.sh` | MD → A4 PDF 일괄 변환. `bash _tools/md2pdf.sh 10-주차별-강의자료/*.md` |
| `pdf-template.html` | 인쇄용 CSS + 콜아웃 변환 로직. 서식을 바꾸려면 여기만 수정 |
| `marked.min.js` | 마크다운 파서 로컬 사본 — 인터넷 불필요 |
| `mathjax-tex-svg.js` | LaTeX 수식 조판 로컬 사본 (SVG 출력, 폰트 파일 불필요) |
| `tidy_layout.m` | Simulink 모델 배치·색 정리. `tidy_layout('W07_0_offline')` |
| `tidy_all.m` | 22개 모델 일괄 점검 — 겹침 쌍과 꺾인 선 수를 표로 보고 |
| `tikz2svg.sh` | TikZ `.tex` → SVG(+PNG). TinyTeX 을 계정 무관하게 찾는다 |
| `winshot.ps1` | Windows 창 캡처 + 클릭·키 입력. `-Match` 로 창 지정 |
| `xshot.sh` · `xclick.sh` | **WSLg 창** 캡처·클릭. Windows 쪽에서 찍으면 안 되는 창용 |

## 🖼 그림 — `assets/`

| 파일 | 쓰이는 곳 |
|---|---|
| `w01-pipeline.svg` | 인지·판단·제어 3단계 |
| `w01-stack.svg` | Windows / WSL / MATLAB 구성 |
| `w01-mission.svg` | Term Project 4구간 |
| `w02-pubsub.svg` | 노드와 토픽 발행·구독 |
| `w02-aliasing.svg` | 에일리어싱 (9 Hz → 1 Hz) |
| `w02-where-installed.svg` | Windows / WSL 경계 — 무엇이 어디에 |
| `w02-build-flow.svg` | 작성 → 등록 → 빌드 → source → 실행 |
| `w02-vscode-*.png` | VS Code 확장 검색 · WSL 연결 · 편집기 · 통합 터미널 (4장) |
| `w02-code-pub-sub.png` · `w02-code-setup.png` | 발행자↔구독자 · `setup.py`↔`package.xml` 대비 |
| `w02-git-clone.png` · `w02-colcon-build.png` | 실습 패키지 clone 과 빌드 화면 |
| `w02-rqt-*.png` · `w02-rviz2.png` | rqt_graph · Topic Monitor · rqt_console · RViz2 |
| `w03-frames.svg` | ENU vs NED |
| `w03-6dof.svg` | 선박 6자유도 |
| `w04-sensor-layout.svg` | WAM-V 센서 배치와 사각지대 |
| `w04-topic-map.svg` | 토픽 흐름 한 바퀴 |
| `w05-agent-loop.svg` | AI 에이전트 동작 루프와 사람의 몫 |
| `w05-vscode-claude.svg` | VS Code · Claude · MATLAB 설치 위치 |
| `w05-verify.svg` | 검증 세 겹 |
| `w06-control-loop.svg` | 속도 루프 · 헤딩 루프 · 차동 배분 |
| `w07-course-crab.svg` | 선수각 · 침로각 · 크랩각과 조류 |
| `w07-los-geometry.svg` | LOS 기하 — π_p, y_e, Δ, R |
| `w07-atan2-vs-los.svg` | 두 유도법칙 궤적 대비 + 실측 표 |

## 📦 자산 인벤토리 — `40-자산/`

작년 연구실 워크스페이스에 이미 있는 것들. **백지에서 시작하지 않는다.**

| 문서 | 내용 |
|---|---|
| [[Simulink-모델-인벤토리]] | 8개 `.slx` 모델과 실행 스크립트 · 어느 주차에 투입하나 |
| [[VRX-월드와-패키지]] | 장애물·도킹 월드 · Python 인지 노드 · 추진기 구성 |
| [[참고문헌]] | 주교재 논문 · Fossen · 폴더 내 보유 자료 |

## 📚 원본자료 — `50-원본자료/`

- 교재·학술논문·외부 기관 원본 PPT 30개. **남이 만든 자료이므로 고치지 않는다**
- 2026-09-05 정리에서 볼트 루트에 흩어져 있던 것을 이 폴더로 모았다
- 문서에서 인용할 때는 `50-원본자료/파일명` 으로 적는다
## 📝 과제 — `80-과제/`

| 문서 | 내용 |
|---|---|
| [[Term-Project-명세]] | 미션 4구간 · 평가 지표 · 채점 루브릭 |

---

## ⚡ 자주 쓰는 명령

```bash
# VRX 실행
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta

# 장애물 필드 / 도킹 월드 — 연구실 배포 파일을 vrx_ws 에 덮어써야 동작한다
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta_ca
ros2 launch vrx_gz competition4docking.launch.py world:=scan_dock_deliver_full

# 토픽 진단 — QoS 확인이 핵심
ros2 topic hz   /wamv/sensors/imu/imu/data
ros2 topic info /wamv/sensors/imu/imu/data --verbose

# 배 움직이기
ros2 topic pub --rate 10 /wamv/thrusters/left/thrust  std_msgs/msg/Float64 "{data: 200.0}"
ros2 topic pub --rate 10 /wamv/thrusters/right/thrust std_msgs/msg/Float64 "{data: 200.0}"

# 빌드
cd ~/vrx_ws && colcon build --merge-install && source install/setup.bash
```

---

## 🔍 Dataview 자동 인덱스 (플러그인 설치 시)

Obsidian 커뮤니티 플러그인 **Dataview** 를 설치하면 표로 렌더링된다. 미설치 시 코드블록으로 보인다.

```dataview
TABLE week AS 주차, summary AS 요약, status AS 상태
FROM "10-주차별-강의자료"
WHERE type = "week"
SORT week ASC
```

```dataview
LIST summary
FROM "20-지식"
SORT file.name ASC
```

---

## 📌 지금 해야 할 일

- [ ] MATLAB ROS Toolbox ↔ ROS 2 Humble 실통신 검증 (개강 2주 전)
- [ ] WSL 프리빌드 이미지 `wsl --export` 로 제작·배포 → [[환경구축-실패가-가장-비싼-비용이다]]
- [ ] **커스텀 월드 배포 패키지 제작** (10주차 전) — `sydney_regatta_ca` · `scan_dock_deliver_full` ·
      `competition4docking.launch.py` · `custom_docking_station` 은 upstream VRX 에 없음 → [[VRX-월드와-패키지]]
- [ ] 학생 노트북 사양 사전조사, 미달자용 워크스테이션 준비
- [ ] MATLAB 라이선스 동시접속 수 확인 (팀당 1석)
- [ ] **Claude 계정 확보** (5주차 전) — 무료 플랜은 Claude Code 불가. 개인 구독 / 공용 계정 / API 키 결정
- [ ] GitHub Organization 개설 및 팀 레포 템플릿
- [ ] 10~15주차 자료 작성 (1~9주차 완료)
