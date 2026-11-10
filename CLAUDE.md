# 캡스톤디자인 저장소 — 어디에 무엇이 있는가

이 파일은 **저장소 루트**에 있으므로 하위 어느 폴더에서 세션을 열어도 자동으로 읽힌다.
내용을 여기 옮겨 적지 않고 **원본을 가리킨다** — 길어지면 그 자체가 토큰이다.

## 폴더 지도

| 경로 | 무엇 |
|---|---|
| `1_2026-2학기_강의자료/` | **볼트** — 이번 학기 강의자료 원본 (MD + PDF 짝) |
| `1_2026-2학기_강의자료/10-주차별-강의자료/` | `W01_…`~`W15_…` 주차 폴더, `W0n_simulink/` 모델·실행 스크립트 |
| `1_2026-2학기_강의자료/_tools/` | `pdf_sync.sh`, `git_autopull.sh`, `git_autopush.sh`, `hook_stop.sh` |
| `3_예제코드/` | 예제 코드 |
| `4_참고자료/`, `5_학생제출물/`, `2_지난학기_강의자료/` | 이름 그대로 |

**강의자료를 만들거나 고칠 때는 `1_2026-2학기_강의자료` 에서 세션을 여는 것이 가장 빠르다** — 볼트 `CLAUDE.md` 와 스킬 세 개가 그때만 자동으로 붙는다.

## 먼저 읽을 것

- **서식·문체·수식·PDF 규칙**: `1_2026-2학기_강의자료/CLAUDE.md` (절대 규칙 5개 포함). 강의자료를 건드리기 전에 읽는다.
- 스킬 (목록에 안 뜨면 경로로 직접 읽는다)
  - `1_2026-2학기_강의자료/.claude/skills/capstone-lecture-vault/SKILL.md` — 주차 자료 작성·검사
  - `.../skills/simulink-gnc-models/SKILL.md` — Simulink GNC 모델 작성
  - `.../skills/capstone-git-sync/SKILL.md` — 커밋·푸시 관례
- **VRX 실행 절차**: `.../capstone-lecture-vault/references/vrx-runbook.md` — 다시 알아내지 말고 이것을 읽는다.

## 손이 자주 미끄러지는 네 가지

1. **WSL 은 비대화형이라 `.bashrc` 를 건너뛴다.** `ROS_DOMAIN_ID` 를 명령 안에 직접 쓴다.
   `wsl.exe -d Ubuntu-22.04 -e bash -lc 'export ROS_DOMAIN_ID=7; source /opt/ros/humble/setup.bash; …'`
2. **VRX 를 끝낼 때 반드시 정리한다.** 남은 `gz sim` 이 62 GB 까지 자라 OOM 을 부른다.
   - 간단한 쪽: `cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite && bash stop_vrx.sh` (주차 자료가 쓰는 꼴)
   - `cleanup` 을 쓸 때는 **오버레이를 먼저 소스한다** — 안 하면 패키지를 못 찾는다:
     `source ~/vrx_ws/install/setup.bash; ros2 run vrx_llm_dock cleanup`
3. **대괄호 폴더 (`강의자료/[2026-2] 강의자료`)** 는 PowerShell 에서 와일드카드로 해석된다 — `-LiteralPath` 를 쓴다. 볼트 `CLAUDE.md` 절대 규칙 참고.
4. **가제보를 둘 띄울 때 `ROS_DOMAIN_ID` 로는 안 갈린다** (2026-11-10 실측). 가제보 내부 통신은 `GZ_PARTITION` 으로 갈리고, 설정하지 않으면 `hostname:username` 한 칸을 같이 쓴다 — 같은 PC·같은 계정의 두 VRX 가 서로 붙잡는다 (배가 두 척, 토픽 값이 튐, RTF 반토막).
   - 세션마다 다른 값을 주고, `gz topic`/`gz service` 를 치는 터미널에도 **같은 값**을 준다: `export GZ_PARTITION=a2; bash run_vrx.sh`
   - 실측: 값이 다르면 받은 메시지 0 줄, 같으면 둘 다 받음. `GZ_PARTITION=$(hostname):$(whoami)` 로 보낸 것이 **아무것도 설정하지 않은** 구독자에게 닿음
   - **`stop_vrx.sh` 와 `cleanup` 은 칸을 보지 않는다** — 프로세스 이름으로 끄므로 **남의 가제보까지 끈다.** 둘이 돌 때는 띄운 터미널에서 `Ctrl+C`

## 세션이 끝날 때

`Stop` 훅이 MD→PDF 동기화 후 커밋·푸시까지 한다 (`_tools/hook_stop.sh`). 손으로 돌리려면 `bash _tools/pdf_sync.sh` → `bash _tools/git_autopush.sh`.

**세션이 여럿이면 자동 커밋은 보류된다** (2026-11-10). 같은 체크아웃에 다른 세션이 살아 있으면 `git add -A` 를 건너뛰고 **이미 스테이징된 것만** 담는다 — 자기가 만든 것은 `git add -- <경로>` 로 직접 담아 커밋한다. 화면에 "자동 커밋 보류" 가 뜨면 그 뜻이다.
