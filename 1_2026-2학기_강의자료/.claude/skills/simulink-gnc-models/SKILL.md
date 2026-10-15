---
name: simulink-gnc-models
description: 선박·USV의 GNC(유도·항법·제어) Simulink 모델을 MATLAB 코드로 생성하고, 블록 배치와 신호선을 읽기 좋게 정리한다. 사용자가 "시뮬링크 모델 만들어줘", "Simulink 모델 생성", "블록 배치 정리", "선 정리", "선이 복잡해", "겹치지 않게", "블록 색", "LOS 유도", "웨이포인트 추종", "로이터링", "Stateflow 미션", "VRX", "WAM-V", "추력 배분", "운동모델", "build_wXX_models", "대시보드", "슬라이더", "버튼", "실시간", "조종기", "RC", "조이스틱", "Joystick Input", "USB" 를 언급하거나, 강의용 Simulink 자료를 만들거나 고칠 때 사용하라. MATLAB MCP 로 실제 실행해 검증하는 절차까지 포함한다.
---

# Simulink GNC 모델 — 코드로 만들고, 코드로 정리한다

이 문서는 **목차**다. 규칙 본문은 `references/` 안에 주제별로 나뉘어 있다.
필요한 한 장만 열어 읽는다.

## 지켜야 할 것 — 일곱 줄

> [!important] 교수 지시 2026-10-15 — *"시뮬링크 만들 때는 자동으로 시뮬링크 스킬
> 규칙들에 맞춰서 개발해 줄 것."* 모델을 새로 만들거나 고칠 때 이 일곱 줄은
> **묻지 않고 적용한다.**

1. **왼쪽에서 오른쪽으로 읽힌다.** `[지령] → [유도] → [제어기] → [배분] → [운동모델] → [로깅·화면]`.
   선이 깨끗한 것보다 **앞선다** (교수 지시 2026-09-30)
2. **손으로 그리지 않는다.** `build_wXX_models.m` 하나가 모델 전체를 만든다
3. **검사 일곱 항목이 전부 0** 이어야 그 모델이 끝난 것이다 — `check_lines(m, true)`
4. **합산점은 언제나 `'|+-'`** — 지령은 왼쪽, 되먹임은 아래 (교수 지시 2026-10-14).
   다섯 항목을 **전수로** 본다 — `check_sums(m, true)` 가 전부 0
5. **선은 가능하면 직선** — `check_straight` 의 직선율을 올리고 꺾임 2회를 줄인다.
   **태그가 걸린 선은 100% 직선**이 목표다. 포트 높이가 다른 자리는 2회가 하한이고,
   줄이는 길은 선을 다르게 꺾는 것이 아니라 **포트 높이를 맞추는 것**이다 (2026-10-15)
6. **태그는 포트 옆, 그리고 열로 맞춘다** — 같은 블록에 붙는 Goto·From 은 x 가
   한 줄로 맞는다. `snug_tags(m)` 이 그 자리를 만든다 (교수 지시 2026-10-15)
7. **예제는 사다리로 쌓는다** — 한 단계에 하나씩만 더하고, 단계마다 `.slx` 와
   그것을 **돌려 그림을 내는** 실행 `.m` 을 한 짝으로 낸다 (교수 지시 2026-10-15).
   `.m` 은 물리를 다시 짜지 않는다 — 설정 → `sim` → 플롯 세 걸음뿐이다

## 어디를 읽는가

| 하려는 일 | 읽을 문서 |
|---|---|
| **새 모델을 시작한다** | `references/model-layout.md` → `references/build-models.md` |
| **예제를 여러 개로 쌓는다 · 빌더를 나눈다** | `references/decisions.md` §4-3 |
| 선을 긋는다 · 태그를 놓는다 | `references/line-routing.md` |
| 서브시스템으로 묶는다 · 색을 고른다 | `references/subsystems.md` · `references/tidy.md` |
| 제어기·유도법칙을 쓴다 | `references/gnc-conventions.md` · `references/authoring.md` |
| 사람이 조작하는 모델을 만든다 | `references/interactive-models.md` |
| 다 만들고 검사한다 | `references/checks.md` → `references/verify.md` |
| **VRX 로 돌려 결과 그림을 남긴다 · 애니메이션을 찍는다** | `references/verify.md` §8.1 · §8.2 |
| 규칙이 왜 이런지 궁금하다 | `references/decisions.md` |

## 작업 순서

1. **생성** — `build_wXX_models.m` 작성 → MATLAB MCP 로 실행.
   최상위 x 는 `gnc_chain` 이 준다. 손으로 쓰지 않는다
2. **정리** — `tidy_model(모델, 'KeepRoot', true)` 한 번. 선이 없는 상자가 있으면
   이어서 `lay_boxes(모델, {'Animate','Logging'})`
3. **검사** — `check_lines` · `check_sums` · `check_flow` · `check_tags` · `check_gains` ·
   `check_colour` · `check_discrete` · `check_fill` 을 **전부 0** 으로 만들고,
   `check_straight` 의 직선율을 적어 둔다 (지적이 아니라 **재는 값**이다)
4. **실행** — MATLAB MCP 로 실제로 돌려 수치를 얻는다. **잰 값만 문서에 싣는다**
5. **그림** — `export_diagram` (Stateflow 는 `sfprint`)
6. **실행 파일** — 단계마다 `WXX_N_이름_run.m` 한 장. `setappdata` 로 단계를 정하고
   `WXX_setup` → `sim(mdl)` → `WXX_plot` 을 부른 뒤 그 단계에서 **봐야 할 숫자**를
   `fprintf` 로 찍는다. 모델만 Run 해도 같은 그림이 뜨게 둔다

> [!caution] 자동 배치는 **단계 순서를 모른다**
> `Simulink.BlockDiagram.arrangeSystem` 은 선 길이만 줄인다. 최상위를 `gnc_chain`
> 으로 잡아 둔 모델은 **반드시** `tidy_model(m, 'KeepRoot', true)` 로 부른다.
> 2026-09-30 에 이것 때문에 여덟 모델에서 어긋남 189 건이 났다.

## 출처

- 여섯 단계 배치 · 이름 붙은 포트 · 로깅 계약 · 대화형 모델 관용구 —
  대학원 GradCourse 볼트 (2026-09-24)
- 좌 → 우 흐름 규칙 · `check_flow` · `tidy_model('KeepRoot')` — 교수 지적 (2026-09-30)
- 연속 제어기 · 0 인 게인 · 신호 이름 태그 · `check_tags` · `check_gains` — 교수 지시 (2026-10-01)
- 자동 정지 · Scope 한 개 · 루프마다 서브시스템 하나 — 교수 지시 (2026-10-02)
- ssa 는 합산점 + `Fcn` · Scope 범례 · 합산점 `'|+-'` · 사다리 예제 · 빌더 모듈화 —
  교수 지시 (2026-10-14)
- 되먹임이 있는 서브시스템의 안쪽 배선 순서 · 단계를 더할 때 함께 고칠 곳 셋 ·
  MATLAB MCP 운용 — 6주차 8단(NED 좌표계 접안) 작업에서 (2026-10-15)
- 선은 가능하면 직선 (`check_straight`) · 합산점 전수 검사 (`check_sums`) ·
  태그 **열 정렬** · 스킬 규칙 자동 적용 — 교수 지시 (2026-10-15).
  교수가 손수 정렬한 W06_1_point 도면에서 기준을 읽었다 (`line-routing.md` §3.4)
- 역 프로펠러 법칙이 **플러그인 안**에 있는 자리 (`gnc-conventions.md` §7.1) ·
  긴 벡터 Constant 를 이름으로 묶기 (`authoring.md`) · 공용 도면은 **그 그림을 설명하는
  단계**에서 뽑기 (`build-models.md`) · 윗단에도 앞 단계의 스위치를 남기기
  (`decisions.md` §4-3) · 좁은 상자 안에서 통과선에 가지를 치지 않기
  (`line-routing.md` §5.1) — 5·6주차 도면 점검에서 (2026-10-15)
- VRX 결과 그림 **두 장을 이름 규칙으로** 남기기 · 대조 칸은 그 주차의 질문 순서로 ·
  `WXX_anim_capture.m` 으로 실시간 화면을 조건과 함께 찍기 · `gcf` 대신 그리는 함수가
  준 핸들 · 범례가 정착선을 덮지 않게 (`verify.md` §8.1·§8.2·§16·§17) —
  교수 지시 2026-10-15 *"실제 VRX 결과에 대한 그래프도 자세히, 다른 주차에 맞게."*
- 정지 게이트를 **끊지 않고 줄이기** · 도착 판정에 속도 조건 · 게이트를 읽는 문턱은
  `<= 0` (`gnc-conventions.md` §8) · 단계 하나만 다시 빌드할 때 공용 도면이
  덮어써지는 것 · Simulink 주석에 마크다운 금지 (`build-models.md`) —
  교수 지시 2026-10-15 *"7단 끝 오차가 R_stop 보다 큰 것 고쳐줘."*
