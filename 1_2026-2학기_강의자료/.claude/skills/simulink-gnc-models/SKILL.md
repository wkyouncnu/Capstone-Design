---
name: simulink-gnc-models
description: 선박·USV의 GNC(유도·항법·제어) Simulink 모델을 MATLAB 코드로 생성하고, 블록 배치와 신호선을 읽기 좋게 정리한다. 사용자가 "시뮬링크 모델 만들어줘", "Simulink 모델 생성", "블록 배치 정리", "선 정리", "선이 복잡해", "겹치지 않게", "블록 색", "LOS 유도", "웨이포인트 추종", "로이터링", "Stateflow 미션", "VRX", "WAM-V", "추력 배분", "운동모델", "build_wXX_models", "대시보드", "슬라이더", "버튼", "실시간", "조종기", "RC", "조이스틱", "Joystick Input", "USB" 를 언급하거나, 강의용 Simulink 자료를 만들거나 고칠 때 사용하라. MATLAB MCP 로 실제 실행해 검증하는 절차까지 포함한다.
---

# Simulink GNC 모델 — 코드로 만들고, 코드로 정리한다

이 문서는 **목차**다. 규칙 본문은 `references/` 안에 주제별로 나뉘어 있다.
필요한 한 장만 열어 읽는다.

## 지켜야 할 것 — 다섯 줄

1. **왼쪽에서 오른쪽으로 읽힌다.** `[지령] → [유도] → [제어기] → [배분] → [운동모델] → [로깅·화면]`.
   선이 깨끗한 것보다 **앞선다** (교수 지시 2026-09-30)
2. **손으로 그리지 않는다.** `build_wXX_models.m` 하나가 모델 전체를 만든다
3. **검사 일곱 항목이 전부 0** 이어야 그 모델이 끝난 것이다 — `check_lines(m, true)`
4. **합산점은 언제나 `'|+-'`** — 지령은 왼쪽, 되먹임은 아래 (교수 지시 2026-10-14)
5. **예제는 사다리로 쌓는다** — 한 단계에 하나씩만 더하고, 단계마다 `.slx` 와
   평평한 `.m` 을 한 짝으로 낸다 (교수 지시 2026-10-14)

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
| 규칙이 왜 이런지 궁금하다 | `references/decisions.md` |

## 작업 순서

1. **생성** — `build_wXX_models.m` 작성 → MATLAB MCP 로 실행.
   최상위 x 는 `gnc_chain` 이 준다. 손으로 쓰지 않는다
2. **정리** — `tidy_model(모델, 'KeepRoot', true)` 한 번. 선이 없는 상자가 있으면
   이어서 `lay_boxes(모델, {'Animate','Logging'})`
3. **검사** — `check_lines` · `check_flow` · `check_tags` · `check_gains` ·
   `check_colour` · `check_discrete` · `check_fill` 을 **전부 0** 으로 만든다
4. **실행** — MATLAB MCP 로 실제로 돌려 수치를 얻는다. **잰 값만 문서에 싣는다**
5. **그림** — `export_diagram` (Stateflow 는 `sfprint`)
6. **짝 맞추기** — 같은 제어기를 평평한 `.m` 으로도 돌려 `max(abs(차))` 를 적는다

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
