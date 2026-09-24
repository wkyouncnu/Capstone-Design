---
name: simulink-gnc-models
description: 선박·USV의 GNC(유도·항법·제어) Simulink 모델을 MATLAB 코드로 생성하고, 블록 배치와 신호선을 읽기 좋게 정리한다. 사용자가 "시뮬링크 모델 만들어줘", "Simulink 모델 생성", "블록 배치 정리", "선 정리", "선이 복잡해", "겹치지 않게", "블록 색", "LOS 유도", "웨이포인트 추종", "로이터링", "Stateflow 미션", "VRX", "WAM-V", "추력 배분", "운동모델", "build_wXX_models", "대시보드", "슬라이더", "버튼", "실시간", "조종기", "RC", "조이스틱", "Joystick Input", "USB" 를 언급하거나, 강의용 Simulink 자료를 만들거나 고칠 때 사용하라. MATLAB MCP 로 실제 실행해 검증하는 절차까지 포함한다.
---

# Simulink GNC 모델 — 코드로 만들고, 코드로 정리한다

> [!important] 배치가 먼저다
> 모델을 쓰기 전에 **`references/model-layout.md`** 를 읽는다. 최상위는
> **command → reference(유도) → controller → allocation → plant → measurement** 순이고,
> 각 단계는 **서브시스템 하나**다. 좌표를 손으로 쓰지 않고 `_tools/gnc_chain` 을 쓴다.
> 포트 이름 · 되먹임 개수 · **로깅 앞 여섯 열 `[u v r x_n y_n psi]`** 도 거기서 정한다.

Simulink 모델을 **손으로 그리지 않는다.** `build_wXX_models.m` 하나가 모델 전체를 만든다.
이유는 세 가지다.

- 모델이 깨져도 한 줄로 복구된다 — 학생이 마음껏 만져볼 수 있다
- 배치·색·배선 규칙을 전 모델에 **똑같이** 적용할 수 있다
- 무엇이 바뀌었는지 `.slx` 가 아니라 `.m` 의 diff 로 보인다

---

## 0. 작업 순서

1. **생성** — `build_wXX_models.m` 작성 → MATLAB MCP 로 실행
2. **정리** — 스크립트 끝에서 `tidy_model(모델)` 호출. 한 번이면 된다
3. **색** — 이어서 `paint_roles(모델)` · `check_colour(모델)`. 흰색 0 이 합격선
4. **그림** — 같은 자리에서 `export_model_pngs(모델)` 호출
5. **검증** — 컴파일 · 미연결 포트 0 · 실제 시뮬레이션 실행
6. **문서** — MD 에 그림과 **실측 수치**를 싣고 PDF 재생성

```matlab
    slxList = dir('W04_*.slx');
    slxList = slxList(~cellfun(@isempty, regexp({slxList.name}, '^W04_[1-5]_', 'once')));
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try
            tidy_model(mName);
            paint_roles(mName);        % 역할표는 _tools/gnc_roles.m 하나뿐이다
            check_colour(mName);       % 흰색으로 남은 블록 0 이 합격선
            export_model_pngs(mName);
        catch e, warning(e.message); end
    end
```

> [!warning] `dir` 의 문자 클래스는 Windows 에서 먹지 않는다
> `dir('W04_[1-5]_*.slx')` 는 **빈 목록**을 돌려준다. `*` 와 `?` 만 쓰고 이름은
> `regexp` 로 거른다. 2026-09-17 에 이것 때문에 빌더가 정리를 통째로 건너뛰면서도
> 아무 말이 없었다. `catch, end` 로 오류를 삼키지 말 것 — 최소한 `warning` 은 남긴다.

> [!important] 수치는 반드시 실행해서 얻는다
> 문서에 싣는 오차·시간·반경은 전부 `sim()` 결과다. 추정치를 쓰지 않는다.

---

## 1. 배치 정리 — `tidy_model`

`_tools/tidy_model.m` 하나만 부르면 된다. 안에서 여섯 가지를 순서대로 한다.

| 순서 | 도구 | 하는 일 |
|---|---|---|
| 1 | `mss_style` | 블록 크기를 **먼저** 정한다. 나중에 키우면 배치가 어긋난다 |
| 2 | `arrangeSystem` | Simulink 의 층 배치. 앞뒤 순서를 잡는 데는 이만한 것이 없다 |
| 3 | `lay_feedback` | 되돌아가는 선을 블록 **아래 통로**로 돌린다 |
| 4 | `tag_feedback` | 그래도 세 번 꺾이면 Goto/From 한 쌍으로 바꾼다 |
| 5 | `lay_sinks` | 갈라져 나온 종착 블록(Display·Goto·Scope)을 아래 한 열로 내린다 |
| 6 | `lay_links` | 남은 지저분한 선만 통로 하나로 다시 긋는다 |

`tidy_model` 은 **절대 나빠지지 않는다.** 손대기 전 성적과 파일 사본을 챙겨 두고,
정리 결과가 더 나쁘면 되돌린다. 그래서 몇 번을 다시 돌려도 손해가 없다.

측정 — 옛 모델 18개의 지적 **80건 → 0건**. `arrangeSystem` 만으로는 50건이 남았다.

> [!important] 선을 지우면 신호의 "기록 표시"도 지워진다
> `DataLogging` 은 **출력 포트**에 붙어 있고, 그 포트의 선을 지우면 함께 사라진다.
> 배치 도구는 선을 지웠다 다시 긋는 것이 일이므로, `tidy_model` 은 `keep_signals`
> 로 표시를 챙겼다가 되돌린다. **직접 배치 도구를 부를 때도 반드시 같이 쓸 것.**
> 2026-09-17 에 SB5 의 `yout` 하나가 이렇게 없어졌다 — 도면은 깨끗해졌는데
> 결과 파일에서 신호가 빠졌다. 그림만 보고는 알 수 없는 종류의 사고다.

무엇을 하는지, 무엇이 깨지는지는 **`references/layout.md`** 와
**`references/line-routing.md`** 에 있다. 고치기 전에 반드시 읽을 것 —
이미 밟은 지뢰가 열 개 넘는다.

### 색 규칙 (바꾸지 말 것)

| 색 | 역할 | `gnc_colour` 이름 |
|---|---|---|
| 파랑 `[0.80 0.89 0.98]` | 유도 Guidance | `guidance` |
| 보라 `[0.90 0.83 0.96]` | 미션 판단 (FSM, 모드 전환) | `mission` |
| 주황 `[1.00 0.88 0.72]` | 제어 Control | `control` |
| 노랑 `[1.00 0.95 0.70]` | 추진기 · 추력 배분 | `thruster` · `allocation` |
| 초록 `[0.81 0.93 0.81]` | 운동모델 Plant | `plant` |
| 분홍 `[0.98 0.85 0.85]` | 외란 (바람 · 파랑 · 센서 잡음) | `env` |
| 연보라 `[0.87 0.87 0.96]` | ROS 통신 · 신호처리 | `ros` |
| 회색 `[0.93 0.93 0.93]` | 로깅 · 표시 | `measurement` |
| 흰색 | 설정값 Constant | `command` |

#### 칠하는 것은 두 줄이다

```matlab
paint_roles(m);        % 역할표는 _tools/gnc_roles.m 하나뿐이다
check_colour(m);       % 흰색으로 남은 것을 잡는다. 합격선은 0
```

- **역할표는 `_tools/gnc_roles.m` 한 파일에만 있다.** 모델 이름으로 찾는다.
  새 모델을 만들면 거기에 `case` 한 줄을 추가한다
- 빌더는 `tidy_model` 뒤에서 위 두 줄을 부르기만 한다.
  `set_param(..., 'BackgroundColor', ...)` 를 빌더에 직접 쓰지 않는다

#### 세 가지 규칙

1. **색은 블록 종류가 아니라 단계를 따른다** — `W04_P1` 의 `SumE` 는 Sum 블록이지만
   제어기의 일부여서 주황이다. 덧셈이라서 무슨 색인 것이 아니다
2. **안쪽 서브시스템은 부모 색을 물려받는다** — 역할표에는 최상위만 적는다.
   예외는 `'InnerLoop/Kp'` 처럼 경로로 적는다
3. **Scope · Display · To Workspace · Goto · From · Terminator 는 언제나 회색** —
   역할표에 적지 않는다. 계산하지 않고 내보내거나 이어 줄 뿐이어서 어느 모델
   어느 층에서든 뜻이 같다

#### SB 드릴은 예외다

`SB*` 는 GNC 사슬이 아니라 Simulink 블록 자체를 가르친다. 단계 색을 억지로 입히면
학생이 없는 뜻을 배운다. 뜻이 분명한 것만 칠하고 — 전달함수는 초록, 제어기는 주황,
계산용 서브시스템은 연보라(신호처리) — 나머지는 흰색으로 둔다.

> [!warning] 색이 빠지는 것은 조용한 사고다
> 배선 검사는 통과하고, 모델도 돌아가고, 수치도 맞다. 도면만 흑백이 된다.
> 2026-09-17 감사 — 강의 모델 **49개 전부가 걸렸고 흰색 블록이 1359개**였다.
> 빌더 11개 중 4개(W05\~W08)만 색칠 루프를 들고 있었고, W02·W03·W04·W09 에는
> 아예 없었다. **같은 루프를 복사해 두면 복사하지 않은 곳이 반드시 생긴다.**
> 그래서 `check_colour` 를 `check_lines` 와 같은 자리에 두었다 — 빌더는 둘 다 부른다.

---

## 2. 모델을 만들 때

**`references/build-models.md`** 에 관용구가 전부 있다 — `fresh`/`setFcn`/`C`/`F`/`G`/`note`
헬퍼, Stateflow 프로그래밍 API, 대수 루프 끊는 법, 실시간 페이싱.

절대 규칙 다섯 가지만 여기 적는다.

1. **GNC 순서를 왼쪽에서 오른쪽으로** — 유도 → 제어 → 추진기 → 운동모델 → 로깅.
   설정값 Constant 를 `command` 한 열로 묶은 **여섯 단계 체인**이 원본이다 → `references/model-layout.md`
2. **되먹임은 Goto/From 태그** — 화면을 가로지르는 선을 만들지 않는다
3. **오프라인 모델의 계수는 시뮬레이터와 같아야 한다** — 안 그러면 게인이 옮겨가지 않는다
4. **최상위는 역할별 서브시스템만** — 블록 20개가 넘으면 묶는다. 로깅·그림은 포트 없는 서브시스템으로.
   관용구·색 이름표·지뢰는 **`references/subsystems.md`**
5. **제어기는 독립 모듈 하나** — 아래

### 사람이 조작하는 모델 — 버튼 · 슬라이더 · 조종기

키보드 노드(`wamv_teleop_key` 등)에 대응하는 Simulink 판을 만들 때는
**`references/interactive-models.md`** 를 읽는다. 여기에는 세 줄만 적는다.

- 라이브러리 이름은 **`simulink_hmi_blocks`** 다. `simulink/Dashboard` 로는 찾지 못한다
- 버튼은 **신호가 아니라 파라미터**를 누른다. `Constant` 의 `Value` 에 `Binding` 으로 묶는다
- Dashboard 블록은 **`mss_style` 뒤에** 넣고, 사람이 조작한 실행의 수치는
  **확인 스크립트가 따로 재서** 문서에 싣는다 (조작은 재현되지 않는다)

### 제어기는 서브시스템 하나로 (예외 없음)

제어기 하나 = **서브시스템 하나**다. 밖에서는 그 상자와 포트 이름만 보인다.

```
HeadingCtrl(psi_ref, psi, r) -> N          헤딩 제어기는 상자 하나
```

상자 **안에** 들어가는 것

- 오차 계산 (`ssa` 같은 각도 wrap 포함)
- 게인 블록, 적분기, 미분기
- 포화·안티와인드업
- 그 제어기만 쓰는 상수 (게인 값, 한계값)

상자 **밖에** 남는 것 — 측정값과 지령, 그리고 출력. 그것뿐이다.

| 왜 | |
|---|---|
| 옮길 수 있다 | 다른 주차 모델로 상자만 복사하면 된다 |
| 읽힌다 | 최상위에서 "무엇이 무엇을 만드는가"만 보인다 |
| 바꿀 곳이 하나다 | 게인을 고치려면 그 상자만 연다 |

> [!caution] 오차 계산 블록을 상자 밖에 두지 않는다
> `HeadingErr` 를 최상위에 두면 제어기가 두 조각이 되고, 최상위에 제어기 내부
> 신호가 떠돌아다닌다. 6주차가 그 상태였다가 2026-09-17 에 고쳤다.

---

## 3. 제어기를 쓸 때 — MSS 규약

`references/gnc-conventions.md` 참조. 자주 틀리는 세 가지:

| 흔한 실수 | 옳은 것 |
|---|---|
| 속도 되먹임에 `U = sqrt(u²+v²)` 사용 | **`u` (surge) 만** 되먹임 |
| 헤딩 D항에서 오차를 미분 | **요각속도 `r` 을 직접** 되먹임 (P–D) |
| 유도가 침로각 `χ` 를 출력 | 유도는 **`ψ_ref`** 를 출력 |

---

## 4. 검증

**`references/verify.md`** — 컴파일 확인, 미연결 포트 검사, VRX 기동·정리 명령,
RTF 와 `PacingRate` 를 맞추는 이유.

### 배선 검사 — 모델을 끝내기 전에 반드시

```matlab
check_lines(모델, true)   % 겹침·블록관통·꺾임3회+·매달림·사선·블록겹침·이름표위선
```

- **일곱 다 0 이 합격선.** 최상위와 모든 서브시스템에 대해
- **블록겹침 0** — 블록 사각형끼리, 이름표(블록 아래 글자 줄, 약 14 px)가 다른 블록에,
  주석이 블록·이름표에 겹치면 센다. 포트 간격이 좁아 이름표가 가려지면 받는 블록 키를
  `52 x (포트수-1) + 40` px 로 키운다 (2026-09-19 PoseSubscriber 의 orgN). 태그는
  `drop_tag`·`feed_from` 이 `spot_free` 로 빈자리를 재서 놓는다
- **이름표 위 선 0** — 남의 선이 블록 이름 글자 위를 지나면 인쇄물에서 이름이 지워진다.
  블록은 멀쩡한데 그것이 무엇인지 알 수 없는 도면이 된다. 2026-09-21 에 참고값에서
  합격선으로 올렸다 (그때 전 모델에 11건 남아 있었다). **통로를 옮겨** 푼다 —
  꺾임을 늘려 돌아가지 않는다
  - 이름표 자리는 `_tools/name_box.m` 이 잰다. `lay_sinks`·`lay_links`·`lay_chain` 은
    통로 x 를 고를 때 블록 사각형과 **함께** 그것을 피하고, `spot_free` 는 태그를 놓기
    전에 새 이름표 위로 지나는 선이 있는지도 본다
  - From 태그로 들어가는 세로 통로는 그 태그의 **오른쪽 테두리**에 묶여 있다. 위아래로
    내려도 안 풀리면 `feed_from` 이 포트에서 더 멀리 물러나 통로를 옆으로 옮긴다
  - 로깅 상자처럼 줄을 쌓는 곳은 **줄 간격**이 원인이다. 블록 30 + 이름표 14 + 여백이
    들어가야 하므로 65 px 아래로 좁히지 않는다 (W04_P2·P3 의 Scope 는 80 px 간격)
- **사선 0** — 모든 선 토막은 가로 아니면 세로. 몇 px 기운 선도 도면에서는 비뚤게 보임
  (2026-09-19 W04_P2 Dcompare 에서 교수 지적). 원인은 거의 둘
  - 포트 높이를 **계산**으로 맞춤 → `port_xy` 로 **읽어서** 줄 높이·블록 위치를 정할 것
    (예: 다입력 Scope 를 먼저 놓고 입력 포트 높이를 읽어 각 줄의 y 로 씀)
  - 점 목록의 끝점을 블록 **테두리** 좌표로 줌 → 포트는 테두리 몇 px 바깥.
    `draw_line` 이 끝점을 실제 포트로 당기고 이웃 점을 따라 옮김 (snap_ends).
    `add_line(sys, 점목록)` 을 직접 쓸 때는 분기 시작점을 **본선 위 한 점**으로 줄 것
  - MATLAB Function 은 코드를 넣으면 포트가 생기며 블록이 자람 → 코드를 넣은 **뒤**
    `Position` 을 다시 줄 것 (저장 전후로 포트 간격이 달라짐)
  - 보조 도구: `fit_span` (여러 출력 포트를 받는 블록 입력 높이에 맞춤), `align_to`
    (블록 하나를 옮겨 두 포트 높이를 맞춤), `square_lines` (블록 크기가 바뀐 뒤 기운 끝
    토막을 직각으로 — `mss_style`·`tidy_model`·`settle_links` 끝에서 자동 호출)
- 하나라도 남으면 `references/line-routing.md` 를 읽고 **배치로** 푼다. 배선으로 풀지 않는다


### 색 검사 — 배선 검사와 같은 자리에서

```matlab
check_colour(모델, true)     % 흰색으로 남은 블록을 나열한다
```

- **0 이 합격선.** 서브시스템 · Scope · Display · To Workspace · Goto · From ·
  Terminator 는 흰색으로 두지 않는다
- Constant · Step · Sine 같은 설정값 소스는 **흰색이 맞다** (`command`)
- 걸리면 `_tools/gnc_roles.m` 에 그 모델의 `case` 를 고친다. 빌더를 고치지 않는다
### 도면만 보지 말고 컴파일까지 볼 것

```matlab
set_param(모델, 'SimulationCommand', 'update')     % 차원·자료형이 풀리는가
```

배선 검사는 **신호가 이어져 있는지**를 완전히 보증하지 못한다. 한쪽 끝이 포트에
붙지 않은 선은 겹치지도 블록을 뚫지도 않으므로 검사를 통과한다. 도면은 흠잡을 데
없는데 모델이 컴파일되지 않는다 (2026-09-17 W02_2 의 TurtlePlant).

`check_lines` 에 **매달림** 검사를 넣었고, `tidy_model` 은 정리 뒤 컴파일이
깨지면 **손대기 전 파일로 되돌린다.** 도면을 예쁘게 만들자고 모델을 망가뜨릴 수는
없다.


### 포트를 하나 더 달았다면 — `settle_links`

```matlab
settle_links(m)      % 배치는 그대로, 선만 지적 0 이 될 때까지 다시 긋는다
```

- `lay_chain` 으로 배치를 잡아 둔 모델에는 **`tidy_model` 을 쓰지 않는다.** `arrangeSystem`
  이 배치부터 다시 잡아서 접어 둔 모양이 무너진다. `settle_links` 는 `lay_links` 만 반복한다
- 신호 기록 표시는 안에서 `keep_signals` 로 챙겼다가 되돌린다

> [!warning] 출력 포트를 늘리면 아래 포트가 전부 밀린다
> 2026-09-17 에 W05 의 `Guidance` 에 `x_e` 출력을 더했더니 `gate` 가 한 칸 내려가고,
> 그 선이 전에는 비어 있던 자리를 지나가며 From 두 개를 가로질렀다 — 블록관통 2건.
> 배치를 다시 잡을 일이 아니라 **선 하나를 다른 통로로 보내면 되는 일**이다.
> 빌더의 `mss_style` 뒤에 `settle_links(m)` 를 한 줄 넣으면 다시 만들 때마다 알아서 풀린다.


### Stateflow 차트 그림 — `export_diagram` 이 아니라 `sfprint`

```matlab
sfprint('SB13_stateflow_done/Mission', 'png', fullfile(pwd,'img','SB13_chart.png'));
```

- `print('-s모델/차트')` (= `export_diagram`) 는 차트 **블록의 겉모양**만 찍는다 — 상태 셋이 빈 상자로 나온다
- 상태 이름 · `en:` 동작 · 전이 조건까지 보이려면 `sfprint` 를 쓴다. 2026-09-18 SB13 에서 확인

### 선을 그을 때는 `draw_line`

```matlab
draw_line(sys, 출발포트핸들, 도착포트핸들, 점들)   % 잇고 나서 모양을 준다
cut_line(sys, 도착포트핸들)                        % 가지 하나만 끊는다
```

- `add_line(sys, 점들)` 은 **끝점의 좌표로** 포트를 찾는다. 몇 픽셀만 어긋나면 매달린다
- `delete_line(선핸들)` 은 **뿌리를 지우면 가지가 전부** 사라진다. 옮기려던 가지만
  다시 그으면 나머지는 조용히 없어진다

### VRX 정리

정리 명령은 반드시 `vrx_ros` 를 포함한다.

```bash
pkill -f "vrx_gz|vrx_ros|ros_gz_bridge|gz sim|ruby|parameter_bridge"
```

---

## 5. 참고 문서

| 파일 | 읽을 때 |
|---|---|
| **`references/model-layout.md`** | **새 모델을 만들 때 가장 먼저.** 여섯 단계 체인 · 이름 붙은 포트 · 로깅 계약 · MSS 블록 치수 |
| **`references/line-routing.md`** | **선을 그을 때마다. `check_lines` 의 일곱 항목이 전부 0 이 합격선** |
| `references/layout.md` | 배치가 마음에 안 들 때. `tidy_model` 의 도구를 고치기 전에 |
| `references/build-models.md` | 새 모델을 만들 때마다 |
| `references/subsystems.md` | **선이 겹치거나 최상위가 복잡할 때.** 서브시스템 관용구·색 이름표 |
| `references/interactive-models.md` | **사람이 조작하는 모델** — 버튼·슬라이더·조종기 스틱, 실시간 화면, 실물 USB 조종기(Joystick Input), 장치 없이 검증하는 법 |
| `references/gnc-conventions.md` | 제어기·유도법칙을 쓸 때 |
| `references/verify.md` | 수치를 문서에 싣기 전에 |

> 여섯 단계 배치 · 이름 붙은 포트 · 로깅 계약 · 대화형 모델 관용구는
> 대학원 GradCourse 볼트에서 가져옴 — 2026-09-24
