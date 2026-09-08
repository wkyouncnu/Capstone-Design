# 화면 캡처 — 학생이 그대로 따라 할 수 있는 그림 만들기

> [!important] 한 문장으로
> **터미널 글자는 코드블록으로, 도구 창은 캡처로.** 캡처는 저장 전에 반드시 창 제목을 확인한다.

2026-09-08 W02 개편에서 이 절차로 캡처 9장을 만들었다. 그때 밟은 지뢰까지 적어 둔다.

---

## 0. 무엇을 캡처하는가

| 문서에 나오는 것 | 캡처 | 이유 |
|---|---|---|
| 내려받기 페이지 | **한다** | 어느 버튼인지 말로는 안 된다 |
| 설치 옵션 화면 | 한다 | 체크박스를 놓친다 |
| VS Code · rqt · RViz2 · Gazebo · Simulink | **한다** | 처음 여는 학생이 자기 화면과 대조한다 |
| 메뉴가 펼쳐진 순간 | **한다** | "왼쪽 아래 버튼" 은 못 찾는다 |
| 터미널 텍스트 출력 | **하지 않는다** | 코드블록이 복사·검색된다 |

- 캡처 뒤에는 **반드시 판정표**를 단다 — "이 화면에서 무엇이 보이면 성공인가"

---

## 1. 도구 세 가지

| 대상 | 도구 | 왜 |
|---|---|---|
| Windows 앱 (VS Code, 탐색기) | `_tools/winshot.ps1` | 창을 앞으로 끌어와 DWM 경계로 자름 |
| **WSLg 창** (rqt, RViz2, Gazebo) | `_tools/xshot.sh` · `_tools/xclick.sh` | **X 서버에서 직접** 뜬다 |
| 웹 페이지 | 헤드리스 Chrome | 로그인·쿠키 배너가 없다 |

### Windows 앱

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File _tools/winshot.ps1 \
  -Match "WSL: Ubuntu-22.04" -W 1900 -H 1150 \
  -Do "click:1642,667|sleep:3000|type:ros2 run x y|key:enter|sleep:5000|move:900,400" \
  -Out out.png
```

| 인자 | 뜻 |
|---|---|
| `-Match` | 창 제목의 일부. **부분 일치, 첫 번째 창** |
| `-W -H` | 창 크기를 물리 픽셀로 고정 — 캡처 재현성의 핵심 |
| `-Do` | `click:x,y` · `move:x,y` · `type:문자열` · `key:ctrl+grave` · `sleep:ms` 를 `\|` 로 이어 붙인다 |
| `-Out` | 없으면 캡처하지 않고 조작만 한다 |

- 좌표는 **직전 캡처 이미지의 픽셀 그대로**다. 창을 (0,0) 에 붙이므로 화면 좌표와 같다

### WSLg 창

```bash
wsl -d Ubuntu-22.04 -u <사용자> -- bash -lc \
  "bash ~/xclick.sh TopicPlugin 39,87 && bash ~/xshot.sh TopicPlugin ~/shots/a.png 1150 340"
```

- `xdotool search --name` 으로 창을 찾고 `import -window <id>` 로 **X 에서 직접** 뜬다
- 필요한 패키지 — `sudo apt install -y imagemagick xdotool x11-apps`

### 웹 페이지

```bash
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless --disable-gpu \
  --hide-scrollbars --window-size=1400,950 --virtual-time-budget=12000 \
  --screenshot="$(cygpath -w out.png)" "https://code.visualstudio.com/download"
```

---

## 2. 이미 밟은 지뢰

| 증상 | 원인 | 조치 |
|---|---|---|
| **엉뚱한 창이 찍힘** (WSLg 대상) | `SetForegroundWindow` 는 성공을 보고하지만 WSLg 창은 실제로 앞에 오지 않는다 | Windows 쪽에서 찍지 말고 **`xshot.sh` 로 WSL 안에서** 찍는다 |
| 캡처에 남의 작업 화면이 들어감 | 위와 같음 | **즉시 파일을 지운다.** 저장 전 최상위 창 제목 검사를 켠 채로 쓴다 |
| 클릭이 아무 데도 안 먹음 | PowerShell 이 DPI 비인식이라 좌표가 배율만큼 어긋난다 | 스크립트 앞에서 **`SetProcessDPIAware()`** 를 부른다 (`winshot.ps1` 에 이미 있음) |
| `SendKeys` 가 무시됨 | Electron(VS Code) 은 저널 훅 기반 `SendKeys` 를 받지 않는다 | **`SendInput`** 으로 보낸다 (`winshot.ps1` 의 `key:`) |
| `Unable to find type [ushort]` | PowerShell 형식 접근자에 `ushort` 가 없다 | **`[uint16]`** 을 쓴다 |
| 변수에 객체를 넣는데 형 변환 오류 | `param([int]$W)` 와 `$w` 가 **같은 변수**다 (대소문자 무시) | 창 변수는 `$win` 처럼 다른 이름으로 |
| 키 입력이 편집기에 들어가 파일이 더러워짐 | 단축키가 실패하면 그 뒤 `type:` 이 편집기로 간다 | 저장 전이면 `key:ctrl+z` 를 여러 번 보내 되돌린다. **디스크 파일은 그대로다** |
| WSLg 창 제목에 `[WARN:COPY MODE]` 가 붙음 | WSLg 표시 | 제목 **부분 일치**로 찾으면 문제없다 |
| 도구 창의 목록 좌표가 밀림 | 다른 노드·도구가 떠서 항목이 늘었다 | **캡처 대상만 남기고 나머지를 끈 뒤** 다시 찍는다 |
| `ros2 run` 프로세스가 곧 죽음 | `wsl.exe` 가 끝나면 자식도 정리된다 | `setsid nohup ... &` 로 세션에서 떼거나, 백그라운드 태스크로 계속 붙잡는다 |
| WSL 명령의 `$VAR` 가 비어서 옴 | 바깥 셸이 먼저 확장한다 | **스크립트 파일로 만들어** `bash ~/x.sh` 로 부른다 |

---

## 3. 캡처 뒤에 문서에 쓰는 형식

```markdown
![원격 표시기 — Connect to WSL](../assets/w02-vscode-connect-wsl.png)

| 화면의 위치 | 무엇인가 |
|---|---|
| 맨 위 **Connect to WSL** | 이것을 누른다 |
| `Tunnel` · `SSH` | 본 과목에서 쓰지 않는다 |
```

- **그림만 던지지 않는다.** 어디를 눌러야 하는지, 무엇이 보이면 성공인지 표로 붙인다
- 파일명 — `assets/wNN-<내용>.png`. 소문자·하이픈

---

## 4. 실행 검증과 짝을 이룬다

캡처는 "화면이 이렇게 나온다" 를 보이고, 코드블록은 "무엇이 찍힌다" 를 보인다. 둘 다 필요하다.

```bash
# 실행 결과를 파일로 모아 둔 뒤 문서에 옮긴다
timeout 12 ros2 topic hz /chatter > ~/w02_out/topic_hz.txt 2>&1
```

- 오류 메시지도 **재현해서 받는다**. 기억으로 적지 않는다

| 오류 | 재현 |
|---|---|
| `ros2: command not found` | `env -i bash -c 'ros2 topic list'` |
| `Package 'x' not found` | 워크스페이스를 `source` 하지 않고 `ros2 run` |
| `No executable found` | 실행파일 이름을 한 글자 틀리게 |
| `/bin/bash^M: bad interpreter` | `printf '#!/bin/bash\r\n' > x.sh` 후 실행 |
| `Permission denied` (apt) | `sudo` 없이 `apt install` |
| 노드 이름 중복 경고 | 같은 노드를 두 번 실행 |
