---
name: capstone-lecture-vault
description: 캡스톤디자인 2026-2 강의 볼트에서 강의자료를 만들고 고치고 검증하는 전 과정. 사용자가 "주차 자료 만들어줘", "강의자료 고쳐줘", "MD 수정", "PDF 다시 뽑아줘", "수식 넣어줘", "LaTeX", "그림 그려줘", "SVG", "문체 고쳐줘", "개조식", "지식카드", "README 갱신", "강의계획서", "과제 만들어줘", "VRX 로 확인해줘", "실측", "오프라인이랑 VRX 대조", "볼트 점검" 을 언급하거나, 10-주차별-강의자료·20-지식·80-과제·00-운영 폴더의 문서를 건드릴 때 반드시 사용하라. Simulink 모델 자체를 만들거나 배치를 정리할 때는 simulink-gnc-models 스킬을 함께 쓴다.
---

# 캡스톤디자인 볼트 — 일하는 방식

이 볼트는 **배포하는 것과 기록하는 것이 같은 파일**이다. `10-주차별-강의자료/` 의 MD 를
학생이 그대로 받는다. 그래서 "일단 써 놓고 나중에 다듬는다" 가 성립하지 않는다.

> [!important] 한 문장으로
> **모든 수치는 실행해서 얻고, MD 를 고쳤으면 PDF 를 다시 뽑고, 문서를 옮겼으면 README 를 고친다.**

형식 규칙(폴더 구조·문체·프론트매터·콜아웃)의 **원본은 `CLAUDE.md`** 다. 이 스킬은
그것을 **어떤 순서로 실행하는가**를 담는다. 둘이 어긋나면 `CLAUDE.md` 가 이긴다.

---

## 0. 지시 → 무엇부터 하는가

| 사용자가 이렇게 말하면 | 첫 동작 | 읽을 것 |
|---|---|---|
| "N주차 자료 만들어줘" | `_templates/주차자료.md` 복사. **골격을 바꾸지 않는다** | `references/lecture-md.md` |
| "주차 자료 보강해줘" · "다른 주차도 비슷하게" | 합격선 5항목으로 진단부터 한다 | `references/week-quality-bar.md` |
| "이 부분 설명 보강해줘" | 대상 독자를 먼저 정한다 — 기본은 **리눅스·ROS 무경험 4학년** | `references/lecture-md.md` |
| "문체 고쳐줘 / AI 같아" | `scripts/vault_check.sh --style` 로 금지 표현부터 센다 | `references/lecture-md.md` §문체 |
| "수식 넣어줘 / 보기 좋게" | LaTeX 으로 쓴다. MathType 이미지 불필요 | `references/pdf-and-math.md` |
| "PDF 다시 뽑아줘" | `bash _tools/md2pdf.sh <파일>` — 쪽수까지 확인 | `references/pdf-and-math.md` |
| "그림 그려줘" | `assets/` 에 SVG. **한 번의 Bash 호출에 하나씩** | `references/figures-svg.md` |
| "모델 만들어줘 / 선 정리해줘" | `build_wXX_models.m` 작성 → `tidy_layout` 2회 | 스킬 `simulink-gnc-models` |
| "VRX 로 돌려서 확인해줘" | WSL 배포판 `Ubuntu-22.04` 확인부터 | `references/vrx-runbook.md` |
| "오프라인이랑 대조해줘" | 겹치는 시간 구간만. 이격은 **위상 오차인 경우가 많다** | `references/vrx-runbook.md` |
| "주차를 옮기자 / 순서 바꾸자" | 파급 범위를 먼저 나열한다 (문서 4곳 이상) | `references/vault-upkeep.md` |
| "다 끝났나 확인해줘" | `bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh` | 아래 §4 |

---

## 1. 어길 수 없는 것 여섯

1. **수치는 실행 결과다.** 오차·시간·반경·RMS 를 추정으로 쓰지 않는다.
   반드시 **구간을 명시**한다 ("전 구간" 과 "초기 5초 제외" 는 다른 숫자다).
2. **MD 를 고쳤으면 PDF 를 다시 뽑는다.** 두 파일이 어긋나면 학생이 혼란스러워한다.
3. **`10-주차별-강의자료/` 와 `80-과제/` 에 내부용 메모를 쓰지 않는다.** 그건 `00-운영/`.
4. **HTML 슬라이드 덱을 만들지 않는다.** 요청받지 않는 한 `html-slide-deck` 스킬 금지.
5. **개조식·정식 교재 어조.** 1·2인칭 금지, 시점 표현("오늘") 금지, 장식 기호 금지.
6. **폴더명의 `[2026-2]` 대괄호** — PowerShell `-LiteralPath`, bash 는 `find -path "./[2025]*"` 대신
   `*ROS2_VRX_Gazebo_Simulink*` 로 우회한다.

---

## 2. 작업 루프

새 자료든 수정이든 순서는 같다. **문서가 마지막이다.**

```
1) 자산 확인   볼트 안의 PPT·PDF·연구실 코드에 이미 있는지 먼저 찾는다
2) 만들기      스크립트·모델·SVG
3) 실행        MATLAB MCP / VRX — 수치를 뽑는다
4) 문서        MD 에 그림 + 실측 수치 + 진도 체크 + 과제 배점
5) 변환        md2pdf.sh → 쪽수 확인
6) 색인        README 표 · 강의계획서 · 지식카드 갱신
7) 점검        vault_check.sh → 0 건이 합격선
```

> [!warning] 3번을 건너뛰고 4번을 쓰지 않는다
> 이 볼트에서 문서의 숫자는 전부 근거가 있다. 근거가 없으면 그 절을 쓰지 않는다.

---

## 3. 참고 문서

| 파일 | 읽을 때 |
|---|---|
| `references/lecture-md.md` | 주차 자료를 쓰거나 고칠 때마다. 골격·문체·과제 배점 |
| `references/week-quality-bar.md` | **주차 자료의 합격선.** 다이어그램·정상출력·캡처·외부코드 인용 |
| `references/pdf-and-math.md` | 수식을 넣을 때, PDF 가 안 나올 때 |
| `references/figures-svg.md` | 그림을 그릴 때 |
| `references/vrx-runbook.md` | VRX 를 띄우고 수치를 뽑을 때 |
| `references/vault-upkeep.md` | 문서를 추가·이동·개편할 때, 지식카드를 만들 때 |

모델 작업은 **다른 스킬**이다 — `.claude/skills/simulink-gnc-models/`
(배치 정리 `layout.md`, 생성 관용구 `build-models.md`, MSS 규약 `gnc-conventions.md`,
검증 `verify.md`).

---

## 4. 끝내기 전 점검

```bash
bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh
```

| 항목 | 합격선 |
|---|---|
| MD ↔ PDF 쌍 누락 | 0 |
| PDF 가 MD 보다 오래됨 | 0 |
| 깨진 wikilink | 0 |
| 없는 그림 참조 | 0 |
| 금지 표현(여러분·우리·오늘·★ 등) | 0 |
| `![[...]]` 임베드 | 0 |
| 미지원 콜아웃(`[!danger]` 등) | 0 |
| 흰 배경 없는 SVG | 0 |

`--style` 만 주면 문체 검사만, `--links` 면 링크·그림만 돈다.

> [!note] VRX 를 띄웠으면 반드시 정리한다
> ```bash
> wsl -d Ubuntu-22.04 bash -lc 'pkill -f "[v]rx_gz|[v]rx_ros|[r]os_gz_bridge|[g]z sim|[r]uby|[p]arameter_bridge"'
> ```
> 대괄호를 씌우지 않으면 **자기 명령줄이 패턴에 걸려** 셸이 먼저 죽는다.
