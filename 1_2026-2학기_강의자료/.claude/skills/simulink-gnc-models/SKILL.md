---
name: simulink-gnc-models
description: 선박·USV의 GNC(유도·항법·제어) Simulink 모델을 MATLAB 코드로 생성하고, 블록 배치와 신호선을 읽기 좋게 정리한다. 사용자가 "시뮬링크 모델 만들어줘", "Simulink 모델 생성", "블록 배치 정리", "선 정리", "선이 복잡해", "겹치지 않게", "블록 색", "LOS 유도", "웨이포인트 추종", "로이터링", "Stateflow 미션", "VRX", "WAM-V", "추력 배분", "운동모델", "build_wXX_models" 를 언급하거나, 강의용 Simulink 자료를 만들거나 고칠 때 사용하라. MATLAB MCP 로 실제 실행해 검증하는 절차까지 포함한다.
---

# Simulink GNC 모델 — 코드로 만들고, 코드로 정리한다

Simulink 모델을 **손으로 그리지 않는다.** `build_wXX_models.m` 하나가 모델 전체를 만든다.
이유는 세 가지다.

- 모델이 깨져도 한 줄로 복구된다 — 학생이 마음껏 만져볼 수 있다
- 배치·색·배선 규칙을 전 모델에 **똑같이** 적용할 수 있다
- 무엇이 바뀌었는지 `.slx` 가 아니라 `.m` 의 diff 로 보인다

---

## 0. 작업 순서

1. **생성** — `build_wXX_models.m` 작성 → MATLAB MCP 로 실행
2. **정리** — 스크립트 끝에서 `tidy_model(모델)` 호출. 한 번이면 된다
3. **그림** — 같은 자리에서 `export_model_pngs(모델)` 호출
4. **검증** — 컴파일 · 미연결 포트 0 · 실제 시뮬레이션 실행
5. **문서** — MD 에 그림과 **실측 수치**를 싣고 PDF 재생성

```matlab
    slxList = dir('W06_*.slx');
    slxList = slxList(~cellfun(@isempty, regexp({slxList.name}, '^W06_[1-5]_', 'once')));
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try, tidy_model(mName); export_model_pngs(mName); catch e, warning(e.message); end
    end
```

> [!warning] `dir` 의 문자 클래스는 Windows 에서 먹지 않는다
> `dir('W06_[1-5]_*.slx')` 는 **빈 목록**을 돌려준다. `*` 와 `?` 만 쓰고 이름은
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

| 색 | 역할 |
|---|---|
| 파랑 `[0.80 0.89 0.98]` | 유도 Guidance |
| 보라 `[0.90 0.83 0.96]` | 미션 판단 (FSM, 모드 전환) |
| 주황 `[1.00 0.88 0.72]` | 제어 Control |
| 노랑 `[1.00 0.95 0.70]` | 추진기 |
| 초록 `[0.81 0.93 0.81]` | 운동모델 Plant |
| 분홍 `[0.98 0.85 0.85]` | 외란 (바람·파랑) |
| 연보라 `[0.87 0.87 0.96]` | ROS 통신 · 신호처리 |
| 회색 `[0.93 0.93 0.93]` | 로깅·표시 |
| 흰색 | 설정값 Constant |

---

## 2. 모델을 만들 때

**`references/build-models.md`** 에 관용구가 전부 있다 — `fresh`/`setFcn`/`C`/`F`/`G`/`note`
헬퍼, Stateflow 프로그래밍 API, 대수 루프 끊는 법, 실시간 페이싱.

절대 규칙 네 가지만 여기 적는다.

1. **GNC 순서를 왼쪽에서 오른쪽으로** — 유도 → 제어 → 추진기 → 운동모델 → 로깅
2. **되먹임은 Goto/From 태그** — 화면을 가로지르는 선을 만들지 않는다
3. **오프라인 모델의 계수는 시뮬레이터와 같아야 한다** — 안 그러면 게인이 옮겨가지 않는다
4. **최상위는 역할별 서브시스템만** — 블록 20개가 넘으면 묶는다. 로깅·그림은 포트 없는 서브시스템으로.
   관용구·색 이름표·지뢰는 **`references/subsystems.md`**

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
check_lines(모델, true)      % 겹침 · 블록 관통 · 꺾임 3회+ · 매달림
```

- **넷 다 0 이 합격선.** 최상위와 모든 서브시스템에 대해
- 하나라도 남으면 `references/line-routing.md` 를 읽고 **배치로** 푼다. 배선으로 풀지 않는다

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
| **`references/line-routing.md`** | **선을 그을 때마다. 블록 관통 0 · 꺾임 1회 · 겹침 0 이 합격선** |
| `references/layout.md` | 배치가 마음에 안 들 때. `tidy_model` 의 도구를 고치기 전에 |
| `references/build-models.md` | 새 모델을 만들 때마다 |
| `references/subsystems.md` | **선이 겹치거나 최상위가 복잡할 때.** 서브시스템 관용구·색 이름표 |
| `references/gnc-conventions.md` | 제어기·유도법칙을 쓸 때 |
| `references/verify.md` | 수치를 문서에 싣기 전에 |
