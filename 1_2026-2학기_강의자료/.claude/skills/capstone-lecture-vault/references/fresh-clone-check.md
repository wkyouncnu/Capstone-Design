# 새 clone 검증 — 학생 노트북에서 GitHub 판 그대로 돌아가는가

> [!important] 한 문장으로
> **Dropbox 볼트에서 도는 것은 증거가 아니다.** GitHub 에서 새로 `git clone` 한 판을, 학생과 같은
> 자리(WSL `~/Capstone-Design`)에서, 학생과 같은 경로(MATLAB 은 `\\wsl.localhost\...`)로 돌려야 한다.

2026-10-16 노트북에서 5·6주차를 이 절차로 돌려 **오류 메시지 없는 실패 넷**을 찾았다 (4장).
사용자가 "이 컴퓨터에서 처음부터 돌아가는지 확인해 줘", "GitHub 에서 받아서 되는지",
"N주차 VRX 까지 다 돌려 봐" 라고 하면 이 문서대로 한다.

---

## 0. 순서

| # | 할 일 | 합격선 |
|---|---|---|
| 1 | 볼트가 원격과 같은지 — `git fetch && git status -sb` | `## main...origin/main` (앞뒤 0) |
| 2 | WSL 옛 clone 을 **지우지 말고** 옮김 → 새로 clone | `mv ~/Capstone-Design ~/Capstone-Design.bak-MMDD` |
| 3 | 환경 셋 — WSL `~/.bashrc` 도메인 · Simulink 프로필 도메인 · 남은 VRX | 셋 다 7 · `stop_vrx.sh check` 0 개 |
| 4 | **오프라인** 실행 파일 전부 (MATLAB, UNC 경로) | 전부 PASS + 문서 수치와 **소수점까지** 같음 |
| 5 | WSL 쪽 VRX 절 — `_tools/verify_w0506_vrx.sh` 처럼 문서 순서대로 | FAIL 0 |
| 6 | **VRX 연동** 실행 파일 — 실험마다 VRX 새로 | 완주 · 끝 오차 합격 · **동기 $k \le 1.08$** |
| 7 | 고친 것은 **Dropbox 볼트에서** 고치고 clone 으로 복사해 다시 돌림 | 같은 합격선 |
| 8 | 문서 · 그림 · 캡처 · PDF · 커밋 · 푸시 → clone 에서 `git checkout -- . && git pull` | clone `git status` 깨끗 |

- 옛 clone 은 학생 사본일 수 있다 — 지우지 않고 이름만 바꾼다
- 7번: clone 에서 직접 고치면 Dropbox 와 어긋난다. 복사 스크립트는 아래 3장

---

## 1. 명령

```bash
# WSL — 새 clone (약 770 MB, 노트북 1분 40초)
wsl -d Ubuntu-22.04 bash -c 'cd ~ && mv Capstone-Design Capstone-Design.bak-$(date +%m%d) && git clone -q https://github.com/wkyouncnu/Capstone-Design.git'
```

```matlab
% MATLAB — 학생과 같은 경로. Windows 쪽으로 복사하지 않는다
cd('\\wsl.localhost\Ubuntu-22.04\home\<사용자명>\Capstone-Design\1_2026-2학기_강의자료\10-주차별-강의자료\W06_simulink')
W06_ladder        % 측정표 셋 → 문서 F 절 표와 한 칸씩 대조
```

- 여러 실행 파일을 잇달아 돌릴 때는 함수에서 `evalin('base', 이름)` 으로 부른다.
  `W0X_setup` 의 `clear` 가 스크립트 작업 공간을 비우므로 루프 변수가 사라진다
- `W0X_setup` 의 `clc` 가 MCP 출력 캡처를 지운다 → 결과는 `S` 구조체 · `appdata` 에서 다시 읽는다
- **`matlab -batch` 는 한글 경로를 깨뜨린다** (`cd` 가 `C:\wsl.localhost\...\1_2026-2_\10--\` 로 바뀜). MCP 공유 세션으로 돌린다
  - MCP 가 `failed to attach` 면 사용자에게 MATLAB 에서 `shareMATLABSession()` 을 부탁한다

---

## 2. VRX 연동 — 한 실험의 순서

```bash
bash ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite/stop_vrx.sh
cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W06_vrx_lite && bash run_vrx_bow.sh   # 5주차는 W03_vrx_lite/run_vrx.sh
```

1. 토픽이 뜰 때까지 기다림 (`ros2 topic list | grep -c thrust` — 5주차 4, 6주차 6)
2. MATLAB 에서 `W0X_vrx_run`
3. 결과에서 **동기 점검 $k$** 부터 본다. 1.08 을 넘으면 그 실행은 버린다
4. 같은 설정으로 VRX 를 **새로 띄워** 한 번 더 — 범위로 적는다

- 자동화할 때 `bash -lc` 는 `~/.bashrc` 의 도메인 줄까지 가지 않는다 (비대화형이면 첫머리에서 `return`).
  `bash -ic` 로 띄우거나 도메인을 직접 export 한다
- `setsid nohup bash -ic "bash run_vrx_bow.sh" > log 2>&1 < /dev/null &` 로 떼어 놓아야 `wsl.exe` 가 끝나도 남는다

---

## 3. 볼트 → clone 복사

```bash
# Dropbox 의 바뀐 파일(git status 기준)을 clone 으로
D=/mnt/c/Users/<윈도우사용자>/Dropbox/캡스톤디자인; C=~/Capstone-Design
cd "$D" && git -c core.quotepath=off status --porcelain | sed 's/^...//' | while read -r f; do
  [ -f "$D/$f" ] && mkdir -p "$(dirname "$C/$f")" && cp "$D/$f" "$C/$f"; done
```

- `/mnt/c` 위 `git status` 는 느리다 — 타임아웃을 200 초 이상으로
- 끝나면 clone 에서 `git checkout -- . && git clean -n` 으로 되돌리고 `git pull` 로 받은 판을 다시 확인한다

---

## 4. 2026-10-16 에 찾은 것 — 전부 오류 메시지 없이 실패했다

| 증상 | 원인 | 고친 자리 |
|---|---|---|
| 5주차 VRX 에서 4번 웨이포인트 부근 해안에 얹힘 (속도 0, 미완주, 크랩각 67°) | VRX 원본 스폰은 ENU y = **162**. 스폰을 경로 원점으로 삼아 경로가 38 m 남쪽으로 밀림. 문서 수치는 스폰 200 인 데스크톱에서 잰 것 | `W05_setup` 의 `path_north0/east0` (월드 고정), `W05_vrx_run` 출발점 오프셋 · 오프라인도 같은 출발점 |
| VRX 완주 시각이 오프라인보다 수십 초 짧음, 궤적은 겹침 | 실시간 화면(`animate`)을 그리느라 Simulink 가 VRX 를 못 따라감. RTF 는 정상이라 안 보임 | VRX 실행은 `animate = 0`, 끝에 **동기 점검 $k$** = 지나간 거리 ÷ $\int\lvert u\rvert dt$ |
| `measure_sway.sh` 가 한쪽만 `요 유지 틀림` (+33° / −4.9°) | 스폰이 해안 옆이라 우현으로 밀면 해안에 닿음 | `to_open_water.sh` (`set_pose`) 를 먼저 부름 |
| 배가 두 척 · 토픽이 튐 | 고아 `gz sim server` 가 **SIGTERM 을 무시** | `W03_vrx_lite/stop_vrx.sh` — TERM 3 초 뒤 KILL |
| (환경) Simulink 만 아무것도 못 받음 | 노트북 WSL·프로필 도메인 8, 자료 표준 7 | 노트북을 7 로. `W06_6_vrx_run` 이 프로필 불일치에서 멈추게 함 |

- 판정 문장: **같은 컴퓨터라도 스폰·속도·CPU 가 데스크톱과 다르면 같은 스크립트가 다른 실험이 된다.**
  자료의 VRX 수치에는 반드시 스폰 좌표 · RTF · $k$ 를 함께 적는다
- 5·6주차 밖(7\~9주차 `W0X_vrx_run`)도 스폰을 원점으로 쓴다 — 7주차 이후를 검증할 때 같은 해안 문제를 먼저 의심한다

---

## 5. 캡처 — 학생이 따라 할 화면

`references/screenshots.md` 의 도구에 더해 이번에 쓴 방법 (2026-10-16)

| 대상 | 방법 |
|---|---|
| 터미널 (학생이 치는 명령 + 출력) | Windows Terminal 에 데모 스크립트를 띄움 — `wt.exe -w new --title T1 --suppressApplicationTitle wsl.exe -d Ubuntu-22.04 bash -i ~/demo.sh`. 스크립트는 프롬프트 모양 + 명령을 찍고 `eval` 로 그대로 실행 |
| 앞으로 못 가져올 때 | `_tools/wincap.ps1` (PrintWindow) — 사용자가 다른 창을 쓰는 중에도 찍힘 |
| Gazebo | `_tools/xshot.sh "Gazebo Sim"` (WSL 안) |
| MATLAB 명령 창 | `winshot.ps1 -Do "click:..|type:W06_6_vrx_run|key:enter"` 로 **직접 입력**해서 돌림 — MCP 실행은 명령 창에 안 보인다 |

- `wt.exe` 는 인자의 `;` 를 **새 탭 구분자**로 읽는다 → 명령은 스크립트 파일로 넘긴다. `--size` 는 이 PC 의 WT 판에 없다
- Git Bash 에서 `wt.exe ... /home/...` 를 부르면 MSYS 가 경로를 `C:/Program Files/Git/home/...` 로 바꾼다 → **PowerShell 의 `Start-Process`** 로 띄운다
- 글꼴은 크기·글꼴을 먼저 맞춘 뒤 명령이 돌게 한다 — 스크립트 첫 줄 `sleep 7` 동안 `winshot -Do "key:ctrl+minus"` ×3. 나중에 바꾸면 줄이 다시 흘러 앞부분이 사라진다
- `ros2 launch` 로그는 1 초 만에 화면을 넘긴다 → "명령 확인" 화면은 `stop_vrx.sh check` + `DRY=1 bash run_vrx_bow.sh` 로 따로 찍는다
- MATLAB 창에는 사용자의 다른 파일 탭이 보인다 → 주소창(UNC 경로) + 명령 창만 잘라 붙인다
