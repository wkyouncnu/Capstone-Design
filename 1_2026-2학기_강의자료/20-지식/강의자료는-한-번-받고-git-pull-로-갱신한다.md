---
type: knowledge
title: 강의자료는 한 번 받고 git pull 로 갱신한다
date: 2026-09-19
tags: [git, setup, wsl, vscode]
status: done
summary: 강의자료 저장소를 WSL 에 한 번만 clone 하고, 매주 VS Code 터미널에서 git pull 로 바뀐 것만 받는 절차
---

## 한 줄 요약

> 강의자료 저장소는 **처음 한 번만 `git clone`**, 그 뒤로는 매주 **`git pull` 한 줄**로 바뀐 파일만 받음. 다시 clone 하지 않음

## 무엇을 받는가

| 저장소 | 주소 | 들어 있는 것 | 받는 주차 |
|---|---|---|---|
| **강의자료** | <https://github.com/wkyouncnu/Capstone-Design> | 주차 문서(MD · PDF), Simulink 모델, MATLAB 스크립트, 그림 | 2주차 2-6 |
| ROS 2 예제 패키지 | <https://github.com/wkyouncnu/usv_basics> | `usv_basics` (노드 코드) | 2주차 2-6, 3주차 2-6 |

- 두 저장소 모두 **공개** — 로그인 · 비밀번호 없이 받아짐
- 강의자료는 수업 중에도 계속 고쳐짐 (코드 · 모델 · 측정값). 매 주차 시작 전에 받아야 문서와 코드가 맞음

## 처음 한 번 — clone

- 어디서: **VS Code 의 WSL 창**(왼쪽 아래 `WSL: Ubuntu-22.04`)에서 터미널을 엶 — `` Ctrl + ` ``
  - 우분투 터미널을 따로 열어도 같음. Windows PowerShell 이 아님

```bash
git config --global core.quotepath false      # 한글 파일 이름을 \355\... 대신 글자로 보이게
cd ~
git clone https://github.com/wkyouncnu/Capstone-Design.git
code ~/Capstone-Design                         # VS Code 로 열기 (WSL 창)
```

- 받은 크기: 약 **320 MB** (2026-09-19, WSL 에서 `du -sh ~/Capstone-Design` 317 MB). 처음 한 번만 걸림
- 주차 문서는 `~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/` 에 있음

> [!warning] 다시 받고 싶어져도 `git clone` 을 또 하지 않음
> 같은 자리에 clone 하면 `already exists and is not an empty directory` 로 멈춤
> 폴더를 지우고 다시 받으면 320 MB 를 또 받고, **그 안에서 고친 것도 함께 사라짐**

## 매주 — pull

```bash
cd ~/Capstone-Design
git pull
```

- 정상 출력 — 바뀐 것이 있을 때 (2026-09-19 실측, 앞부분)

```
Updating b690ad2..ce9c217
Fast-forward
 .../references/vrx-runbook.md                      |   25 +-
 .../00-운영/강의계획서.md                   |   50 +-
 .../00-운영/강의계획서.pdf                  |  Bin 1219795 -> 1228142 bytes
 .../W02_ROS2_기초_노드와_토픽.md            |    2 +-
 .../W02_ROS2_기초_노드와_토픽.pdf           |  Bin 6693487 -> 6693473 bytes
 .../W03_Gazebo_VRX_구축과_좌표계.md          |  127 +-
```

- 정상 출력 — 바뀐 것이 없을 때

```
Already up to date.
```

| 줄 | 뜻 |
|---|---|
| `Updating b690ad2..ce9c217` | 내 사본이 `b690ad2` 에 있었고 `ce9c217` 로 올라감 |
| `Fast-forward` | 내가 고친 것과 겹치지 않아 그대로 앞으로 감 — 정상 |
| `파일 \| 50 +-` | 그 파일에서 바뀐 줄 수 |
| `Bin 1219795 -> 1228142 bytes` | PDF · 그림 · `.slx` 같은 이진 파일은 크기만 표시 |

- 무엇이 바뀌었는지 더 보고 싶으면

```bash
git log --oneline -5              # 최근 갱신 다섯 개의 요약 한 줄씩
git diff --stat HEAD@{1} HEAD     # 방금 pull 로 바뀐 파일 목록
```

- 방금 pull 로 바뀐 파일 목록의 마지막 줄 예 (2026-09-19 실측)

```
 176 files changed, 4743 insertions(+), 3441 deletions(-)
```

> [!tip] VS Code 버튼으로도 됨
> 왼쪽 **소스 제어** (`Ctrl + Shift + G`) → 위쪽 `…` 메뉴 → **Pull**(끌어오기)
> 또는 왼쪽 아래 상태 표시줄의 동기화 아이콘. 터미널의 `git pull` 과 같은 일을 함

## MATLAB · Simulink 에서 여는 법

- 받은 폴더는 WSL 안에 있지만 Windows 의 MATLAB 이 그대로 열 수 있음 — `\\wsl.localhost` 경로
- MATLAB 명령 창에서 (`<사용자명>` 은 WSL 의 사용자 이름, `whoami` 로 확인)

```matlab
cd('\\wsl.localhost\Ubuntu-22.04\home\<사용자명>\Capstone-Design\1_2026-2학기_강의자료\10-주차별-강의자료\W03_simulink')
W03_setup
W03_offline_run
```

- 기준 환경에서 이 경로로 `W03_0_offline` 을 열고 · 돌리고 · 저장하는 것까지 확인했음 (2026-09-19, 첫 실행 6.6 s)
- Windows 탐색기 주소창에 `\\wsl.localhost\Ubuntu-22.04\home\<사용자명>\Capstone-Design` 을 넣어도 같은 폴더가 열림
- MATLAB 이 만드는 `slprj/` · `*.slxc` · `*.asv` 는 저장소의 `.gitignore` 에 들어 있어 pull 을 막지 않음

## pull 이 멈출 때 — 받은 파일을 고쳐 둔 경우

- 받은 폴더 안의 파일(예: `W07_setup.m`)을 고치거나 MATLAB 에서 모델을 **저장**한 뒤 pull 하면, 같은 파일이 갱신됐을 때 멈춤

```
error: Your local changes to the following files would be overwritten by merge:
	1_2026-2학기_강의자료/10-주차별-강의자료/W07_simulink/W07_setup.m
Please commit your changes or stash them before you merge.
Aborting
```

- 아무것도 받지 않고 멈춘 것임. 내 수정도 그대로 있음. 둘 중 하나를 고름

| 원하는 것 | 명령 | 결과 |
|---|---|---|
| **내 수정은 버리고** 새 판을 받음 | `git restore <파일>` → `git pull` | 그 파일이 받은 판으로 돌아간 뒤 갱신됨 |
| **내 수정을 살린 채** 새 판도 받음 | `git stash` → `git pull` → `git stash pop` | 수정을 잠시 치워 두고 받은 다음 다시 얹음 |

- `git stash` → `git pull` → `git stash pop` 의 정상 출력 (2026-09-19 실측, 줄임)

```
Saved working directory and index state WIP on main: b690ad2 ...
...
Auto-merging 1_2026-2학기_강의자료/10-주차별-강의자료/W07_simulink/W07_setup.m
On branch main
Your branch is up to date with 'origin/main'.
```

- `stash pop` 에서 `CONFLICT` 가 나오면 두 판이 같은 줄을 고친 것임 → `git restore <파일>` 로 받은 판을 쓰고 내 수정은 다시 적음
- `git status` 로 지금 고쳐진 파일이 있는지 언제든 볼 수 있음 (` M 파일` = 고쳐짐)

> [!important] 받은 폴더에서 고친 것은 pull 앞뒤로 치워 두고 되돌린다
> - 실습은 `*_setup.m` 을 **파일에서** 고치게 되어 있음 (7주차 1-7 — 명령 창에서 바꾼 값은 `setup` 이 다시 지움). 고쳐도 됨
> - 다음 주에 받기 전에 `git stash` → `git pull` → `git stash pop` 세 줄이면 수정이 살아남음
> - 모델(`.slx`)을 크게 고칠 때는 **다른 이름으로 저장** (예: `save_system('W09_0_offline','W09_my')`) — 새 파일은 pull 과 부딪히지 않음
> - 팀 코드는 팀 저장소(5주차 D-1)에 둠. 강의자료 저장소와 섞지 않음

## 연결

- [[W02_ROS2_기초_노드와_토픽]] 2-7 — 처음 받는 곳
- [[W05_VSCode와_Claude_에이전트_첫_제어노드]] — VS Code 의 WSL 창
- [[환경구축-실패가-가장-비싼-비용이다]]
