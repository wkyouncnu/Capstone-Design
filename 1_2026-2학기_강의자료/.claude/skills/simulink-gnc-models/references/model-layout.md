# 최상위 배치 — 여섯 단계 체인

> [!caution] 규칙 0 — 최상위는 **왼쪽에서 오른쪽으로 흐름이 한눈에 보여야 한다**
> 이 문서의 다른 모든 규칙보다 앞선다. **선이 깨끗한 것보다도 앞선다.**
>
> ```
> [지령] -> [제어기] -> [배분] -> [운동모델] -> [로깅·화면]
> ```
>
> 교수 지시 2026-09-30 — *"이 시뮬링크 파일은 너무 가독성이 낮다. 선들도 정신없다.
> 가장 왼쪽에 명령이 나오고, 그다음 제어기, 마지막 오른쪽에 운동 모델이 나오는
> 형태로 해서 왼쪽에서 오른쪽으로 흐름을 볼 수 있게 할 것."*
>
> 지키는 법은 세 줄이다.
> 1. 빌더에서 **`gnc_chain`** 으로 단계 열을 받아 그 x 를 블록 생성 함수에 넘긴다
> 2. **`tidy_model(m, 'KeepRoot', true)`** 로 정리한다 — 최상위 블록은 건드리지 않는다
> 3. **`check_flow(m, true)`** 로 센다. **0 이 합격선**이다
>
> 어긴 실제 사례는 §8 에 있다. 규칙만 적어 두는 것으로는 모자랐다 — §8 의 경고가
> 2026-09-24 부터 이 문서에 있었는데도 엿새 뒤 교수에게 지적을 받았다.
> **세는 도구가 없는 규칙은 지켜지지 않는다.**

> [!important] 새 모델을 만들 때 **가장 먼저** 읽는다
> 최상위는 MSS 데모와 같은 순서 —
> **command → reference(유도) → controller → allocation → plant → measurement** — 이고,
> 각 단계는 **서브시스템 하나**다. 좌표를 손으로 쓰지 않고 `_tools/gnc_chain` 을 쓴다.

이 문서는 **어떤 상자를 어느 순서로 놓는가**를 정한다.
선을 어떻게 긋는가는 `line-routing.md`, 상자 안을 어떻게 묶는가는 `subsystems.md` 다.
배선 검사 일곱 항목과 색 규칙은 그대로 유지한다 — 이 문서가 그것을 바꾸지 않는다.

---

## 1. 여섯 단계

```
command  -->  reference  -->  controller  -->  allocation  -->  plant  -->  measurement
웨이포인트     Guidance       InnerLoop       Thrusters       MotionModel   Logging
설정값 상수    (LOS·경로)     (헤딩·속도)     (추력 배분)     운동모델      Animate
```

| 단계 | 하는 일 | 이 볼트의 블록 이름 | 색 (`gnc_colour`) |
|---|---|---|---|
| command | 무엇을 요구하는가 | `Waypoints`, `SpeedCmd`, 설정값 Constant | 흰색 `command` |
| reference | 그것이 실현 가능한가, 어디를 향할 것인가 | `Guidance`, `TeleopPad` | 파랑 `guidance` |
| controller | 그러려면 어떤 힘이 필요한가 | `InnerLoop`, `HeadingCtrl`, `SurgeCtrl` | 주황 `control` |
| allocation | 어느 추진기가 그 힘을 내는가 | `Thrusters`, `Allocation` | 노랑 `thruster` · `allocation` |
| plant | 배가 어떻게 반응하는가 | `MotionModel` (오프라인) · `CmdPublisher`+`PoseSubscriber` (VRX) | 초록 `plant` · 연보라 `ros` |
| measurement | 무엇을 기록하고 보여주는가 | `Logging`, `Animate` | 회색 `measurement` |

- **로깅·`Animate` 는 포트 없는 서브시스템으로 맨 오른쪽 끝, 또는 사슬 바로 아래에
  나란히 둔다.** `lay_sinks` 가 To Workspace·Scope·Goto 를 아래 한 줄로 내리므로
  `check_flow` 는 **사슬보다 아래로 내려간 종착 블록의 x 는 따지지 않는다**.
  다만 **사슬 바로 아래**여야 한다 — 멀리 내리면 그 아래로 종착 구역이 또 내려가
  도면 한가운데가 텅 비고 세로선만 길어진다 (2026-09-30 W04 에서 측정)
- **없는 단계는 그냥 빼고 나머지가 당겨진다.** 순서가 계약이지 좌표가 계약이 아니다
  - 구독만 하는 입문 모델은 plant·measurement 둘뿐이다
  - 모드 판단(Stateflow)이 있으면 `Mission` (보라 `mission`) 을 reference **앞**에 둔다
- **오프라인 ↔ VRX 쌍둥이는 `plant` 상자만 다르다.** 나머지 다섯을 같은 함수로 만들면
  "바뀌는 상자는 하나뿐" 이라는 것이 그림으로 보인다 → `capstone-lecture-vault` 규칙 20

> [!note] 기존 표기와의 관계
> SKILL.md 의 "유도 → 제어 → 추진기 → 운동모델 → 로깅" 과 같은 사슬이다.
> 여섯 단계는 그 앞에 **command**(설정값·웨이포인트)를 따로 세운 것뿐이다.
> 설정값 Constant 를 왼쪽 한 열에 모으면 어디를 고쳐야 하는지가 도면에서 바로 보인다.

---

## 2. 좌표를 손으로 쓰지 않는다

| 함수 | 하는 일 |
|---|---|
| `gnc_chain(stages, ...)` | 단계 목록 → 표준 좌표 struct. 없는 단계는 알아서 당긴다 |
| `check_flow(m, true)` | 최상위가 좌 → 우 순서인가. **0 이 합격선** |
| `add_subsys(m, name, pos, ins, outs, colour)` | **이름 붙은 포트**를 가진 빈 서브시스템 |
| `gnc_colour(stage)` | 단계별 색. 색은 의미이지 장식이 아니다 |
| `add_sum(sys, name, signs, centre)` | MSS 규격 **20×20 둥근 Sum** |
| `mss_style(m)` | 모든 블록을 MSS 치수로. `save_system` 직전 한 줄 |
| `port_xy(sys, blk, kind, k)` | 포트 위치를 **읽는다**. 계산하지 않는다 |
| `row_feed`, `lane_line`, `lay_chain` | 소스를 포트 높이로, 꺾이는 선에 이름 붙은 통로 |

```matlab
P = gnc_chain({'command','guidance','control','thruster','plant','measurement'}, ...
              'Height', struct('controller',130), 'Y', 120);

g = add_subsys(m, 'Guidance', P.reference, {'x_n','y_n','psi'}, {'psi_ref','y_e'}, ...
               gnc_colour('guidance'));
```

- `guidance`·`mission` 은 `reference`, `control` 은 `controller`, `thruster` 는
  `allocation` 으로 받아 준다. `gnc_roles` 의 낱말을 그대로 써도 되지만,
  **돌아오는 struct 의 필드 이름은 언제나 여섯 정식 이름**이다
- 단계마다 상자 수가 다르면 **`'Width'` 에 그 단계가 쓸 폭**을 적는다. `'Pitch'` 를
  주지 않으면 열 간격이 `폭 + Gap`(기본 60)으로 잡힌다 — 제어기 하나뿐인 주차와
  그 옆에 개루프 스위치까지 선 주차를 같은 간격으로 놓으면 한쪽은 비고 한쪽은 겹친다

  ```matlab
  P = gnc_chain({'command','controller','allocation','plant','measurement'}, ...
                'Width', struct('command',300,'controller',350,'allocation',250, ...
                                'plant',160,'measurement',260), 'Y', 140, 'Gap', 50);
  xC = P.command(1);  xK = P.controller(1);  ...      % 열의 왼쪽 모서리만 쓴다
  ```

- 체인이 x ≈ 1600 안에서 끝나야 PNG 가 **2000 px** 안에 들어온다. 넘치면
  `export_diagram` 이 dpi 를 낮추는데, 낮출수록 글씨를 읽을 수 없다
- `lay_chain` 으로 배치를 잡아 둔 모델에는 `tidy_model` 을 쓰지 않는다 → SKILL.md §4 `settle_links`

---

## 3. 포트 이름이 곧 인터페이스다

> [!important] `In1` · `Out1` 을 그대로 두지 않는다
> 포트 이름은 최상위 다이어그램에서 **선 옆에 그대로 보인다.**
> `psi_ref` 와 `tau_N` 이 주석 한 줄 없이 모델을 설명한다.

- 포트 이름 = **신호 이름**. 위치는 `x_n` · `y_n`, 선수각 `psi`, 요 모멘트 `N`
  (→ `capstone-lecture-vault/references/lecture-md.md` §기호 겹침)
- 포트 **순서 = 함수 인자 순서**. 그래야 안쪽 선이 교차하지 않는다
- 겉면 포트 순서를 **윗단 출력 순서와 맞춘다.** 어긋나면 입력선이 대각선이 된다
- 만드는 관용구(`newSub` · `inP` · `outP`)는 `subsystems.md` §3 에 있다 — 여기서 다시 쓰지 않는다

---

## 4. 뒤로 가는 신호는 둘 이하, 각각 이유를 댄다

- 앞으로 가는 선은 체인이 정해 준다. **되먹임은 하나하나 정당화한다**
- 그리는 방법은 **Goto/From 태그**다 (화면을 가로지르는 선을 만들지 않는다).
  태그로 그린다고 해서 개수 제한이 없어지는 것이 아니다 — 보이지 않는 되먹임이 더 나쁘다

| 신호 | 어디서 어디로 | 왜 |
|---|---|---|
| 상태 (`x_n`,`y_n`,`psi`,`u`,`r`) | plant → guidance · controller | 측정값. **한 묶음으로 보내고 받는 상자 안에서 고른다** |
| `tau_sat` | allocation → controller | 구동기가 **실제로 낸** 힘. 안티와인드업이 이것 없이는 불가능 |

- 상태를 낱개로 쪼개 최상위에 Demux·Selector 를 늘어놓지 않는다. 체인이 다시 난잡해진다
- 셋째 되먹임이 생기면 그것은 대개 **모드 신호**다. `Mission` 상자를 세우고 거기로 모은다

---

## 5. 로깅 계약 — 앞 여섯 열은 모든 주차가 같다

```
1 u    2 v    3 r [rad/s]    4 x_n    5 y_n    6 psi [deg]    7.. 그 주차의 추가 신호
```

- 열 순서를 주차마다 바꾸지 않는다. 바꾸면 결과 스크립트가 **어느 모델의 로그인지** 알아야 한다
- 같은 주차의 오프라인·VRX 두 모델은 **7열 이후도 같은 순서**로 맞춘다
- 다른 순서로 일하고 싶으면 **읽는 곳 한 군데에서** 재배열한다. 열 번호를 여기저기 고치지 않는다
- 로깅 상자는 **포트 없는 서브시스템**이고 안에서 From 태그로 받는다 → `subsystems.md` §2

> [!warning] 벡터 신호 하나가 로그 전체를 3차원으로 만든다
> MATLAB Function 이 내는 `n = [nL; nR]` 은 2×1 **행렬** 신호다.
> Mux 입력 하나가 행렬이면 **출력 전체가 행렬**이 되어 로그가 `[8 1 nT]` 로 나온다.
> 그 신호에 **Reshape(`1-D array`)** 를 하나 물린다. 로깅 계약이 2차원인 이유가 이것이다.

---

## 6. 블록 치수 — MSS 를 그대로 따른다

치수를 지어내지 않는다. MSS 툴박스 데모 전체를 훑어 블록 종류별 중앙값을 낸 것이고,
그 표가 `_tools/mss_style.m` 안에 있다.

| 블록 | MSS | Simulink 기본 |
|---|---|---|
| **Sum** | **20×20, `IconShape='round'`** | 25×40 사각형 |
| Gain | 50×36 | 40×40 |
| Constant | 55×30 | 60×40 |
| Integrator | 30×30 | 40×40 |
| Transfer Fcn | 60×36 | 마음대로 커진다 |
| Saturate · Scope · Step · Switch | 30×30 | |
| Inport · Outport | 30×14 | 30×30 |
| Clock · Terminator | 20×20 | |

```matlab
add_sum(c, 'error', '+-', [280 90]);   % 중심 좌표로 놓는다. 신호선과 중심을 맞춘다
mss_style(m);                          % save_system 직전 한 번
```

- `add_sum` 은 부호에 `|` 스페이서를 자동으로 넣는다 (`'+-'` → `'|+-'`).
  없으면 두 부호가 왼쪽 모서리에 몰려 작은 원에서 읽히지 않는다. MSS 가 그렇게 쓴다
- `mss_style` 은 **중심을 유지한 채** 크기만 바꾼다. 신호선에 맞춰 둔 블록이 어긋나지 않는다
- `mss_style` 은 SubSystem 을 건드리지 않는다. 여섯 단계의 크기는 `gnc_chain` 이 정한다
- Dashboard 블록은 `mss_style` **뒤에** 넣는다 → `interactive-models.md`

---

## 7. 파일 이름 — 강의 절과 짝이 지어지게

> [!caution] `.m` 과 `.slx` 에 **같은 이름**을 주지 않는다 — 조용히 아무것도 안 한다
> `W04_3_heading.m` 과 `W04_3_heading.slx` 를 나란히 두면, 명령창에
> `W04_3_heading` 을 쳤을 때 MATLAB 이 **모델을 여는 쪽**을 고른다.
> 스크립트는 실행되지 않는데 **에러도 안 난다.** 그림만 갱신되지 않는다.
>
> **규칙: 모델은 `WNN_<번호>_<이름>.slx`, 그것을 돌리는 스크립트는 `..._run.m`.**

- 절 하나에 스크립트 하나. 한 러너가 그림을 여섯 장 쏟아내면 수업 중에 짚어 갈 수 없다
- 파일명에 **절 번호와 내용**이 함께 들어가면 강의 순서대로 정렬된다
- `function` 이 아니라 **스크립트**로 쓴다. 변수가 워크스페이스에 남아 학생이 이어서 만져 본다
- 학생이 `.slx` 를 열고 Run 만 눌러도 그 절의 그림이 떠야 한다 —
  `set_param(m,'StopFcn','<그 절의 plot>;')` + Scope `'Open','on'`

---

## 8. 점검

- [ ] 최상위 블록이 **여섯 개 이하**인가 (로깅·Animate 제외)
- [ ] 왼쪽에서 오른쪽으로 command → … → measurement 순인가
      — **눈으로 보지 말고 `check_flow(m, true)` 로 센다. 0 이 합격선**
- [ ] `tidy_model` 을 **`'KeepRoot', true`** 로 부르고 있는가
- [ ] **모든 포트에 이름**이 있는가
- [ ] 되먹임 신호가 둘 이하이고, 각각 이유가 있는가
- [ ] 로그 앞 여섯 열이 `[u v r x_n y_n psi]` 인가
- [ ] 색이 `gnc_roles` → `paint_roles` 를 거쳤고 `check_colour` 가 0 인가
- [ ] `check_lines(m, true)` 일곱 항목이 전부 0 인가
- [ ] 블록도 PNG 폭이 2000 px 이하인가
- [ ] 서브시스템까지 PNG 로 뽑아 **눈으로** 봤는가

> [!caution] `Simulink.BlockDiagram.arrangeSystem` 을 여섯 단계 최상위에 걸지 않는다
> 더 조밀하게 싸 주기는 하는데 **블록 순서를 바꾼다.** 출력 포트를 입력 포트보다
> 왼쪽에 놓은 사례가 있다. 조밀함이 목적이 아니라 **왼쪽에서 오른쪽으로 읽히는 것**이
> 목적이다. `lay_chain` 으로 손수 열을 잡은 모델은 `settle_links` 로만 손본다.
>
> **실제로 이렇게 되었다 — 2026-09-30, `W04_3_heading_offline`.**
> 빌더는 지령을 x = 40, 제어기를 300, 배분을 700, 운동모델을 780 에 놓았는데,
> `tidy_model` 안의 `arrangeSystem` 이 최상위를 다시 놓아 이렇게 만들었다.
>
> | 블록 | 단계 | 그때 x | 지금 x |
> |---|---|---|---|
> | `psi_ref_deg` | 지령 | 685 | **60** |
> | `deg2rad` | 지령 | 850 | **165** |
> | `HeadingCtrl` | 제어기 | 1030 | **390** |
> | `OpenLoop` | 제어기(개루프 스위치) | 410 | **600** |
> | `Alloc` | 배분 | 600 | **790** |
> | `PortEff` | 추진기 | 640 | **990** |
> | `MotionModel` | 운동모델 | 800 | **1090** |
> | `Animate` | 화면 | 126 | **1300** |
>
> `check_lines` 일곱 항목은 **전부 0** 이었다. 선은 깨끗한데 도면은 오른쪽에서
> 왼쪽으로 읽혔고, 되먹임 선이 화면을 여러 줄 가로질렀다. 교수가 캡처를 들고
> "가독성이 낮다" 고 한 것이 이 그림이다.
>
> 고친 방법 — 빌더에서 `gnc_chain` 으로 열을 받고, `tidy_model(m, 'KeepRoot', true)`
> 로 최상위 블록을 그대로 둔 채 선만 손질했다. **연결·게인·계수·신호 이름은 하나도
> 바꾸지 않았고**, `sim()` 결과 지문 20행이 한 자리도 달라지지 않았다.

---

## 9. 대학원 볼트에서 가져오면 좋을 `_tools` — 다음 작업 후보

> [!note] 여기 적힌 것은 **아직 이 볼트에 없다.** 코드를 복사해 오지 않았다
> 대학원 볼트 `00_GradCourse_2026/_tools/` 에 있고, 이식할 때는
> WAM-V·VRX·한국어 기준으로 다시 쓴다. Otter 선체·MSS 경로에 묶인 것은 가져오지 않는다.

| 도구 | 하는 일 | 왜 이 볼트에 필요한가 | 우선 |
|---|---|---|---|
| `add_measurement.m` | measurement 단계를 통째로 생성 — 셀렉터 · 로깅 · 스코프 · 실시간 화면 | 지금은 `add_logging_box` + `add_animate_box` 를 모델마다 따로 부른다. §5 로깅 계약을 **한 함수가 강제**하게 됨 | 높음 |
| `draw_ship.m` · `track_ships.m` · `ship_marks.m` | 궤적 위에 선체 실루엣 + 선수 방향선을 호길이 등간격으로 | 궤적선만으로는 크랩각이 안 보인다. 결과 그림 규칙이 요구하는 것 → `capstone-lecture-vault/references/figures-svg.md` | 높음 |
| `ensure_base_vars.m` · `base_var.m` | setup 이 돌았는지 확인하고 기본 작업공간 변수를 안전하게 읽음 | `WNN_setup` 을 안 돌린 채 실행해 엉뚱한 값이 나오는 사고를 막음 | 높음 |
| `crosstrack_err.m` · `wp_switch.m` · `path_plot.m` | 횡방향 오차 · 웨이포인트 전환 · 경로 그림 | 7\~10주차가 같은 식을 모델마다 다시 쓴다. 한 곳으로 모으면 문서의 정의와 어긋날 수 없음 | 높음 |
| `run_sim.m` | 변수 하나만 바꿔 가며 반복 실행 | 조건을 바꿀 때 **모델이 실제로 읽는 변수**를 바꾸게 강제함 (`verify.md` §13) | 중간 |
| `mlfcn_params.m` | MATLAB Function 의 상수를 입력 포트가 아니라 **Parameter** 로 | 상수 넷이 포트로 붙어 선이 넷 늘어나는 것을 막음 | 중간 |
| `live_dash.m` · `live_track.m` | 한 창에 궤적 + 상태 여섯을 실시간으로 | `Animate` 가 궤적만 그린다. 속도·각속도가 안 보임 | 중간 |
| `hmi_bind.m` · `image_button.m` | Dashboard 블록 바인딩 · 그림 버튼 | → `interactive-models.md` | 중간 |
| `recovery_time.m` · `prop_thrust.m` | 외란 후 복귀 시간 · 추진기 추력 | 과제 채점선에 쓸 수 있는 지표 | 낮음 |

가져오지 않는 것 — `mss_path.m` · `otter_config.m` · `otter_B.m` · `add_otter_plant.m`
(Otter 선체와 MSS 설치 경로에 묶여 있다. 이 볼트의 선체는 WAM-V 다).

---

> 대학원 GradCourse 볼트 `simulink-gnc-models/references/model-layout.md` 에서 가져와
> 캡스톤(WAM-V · VRX · 한국어 · `x_n`/`y_n` 표기)에 맞게 고침 — 2026-09-24
