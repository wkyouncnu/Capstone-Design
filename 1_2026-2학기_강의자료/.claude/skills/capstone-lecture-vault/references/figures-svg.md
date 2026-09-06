# 그림과 수식

> [!important] 만들었으면 **반드시 렌더해서 눈으로 본다**
> 코드만 보고 넘어가면 라벨 겹침·잘린 글자·빈 그림을 못 잡는다.
> LaTeX 은 실패해도 조용히 이전 파일을 남기므로 **출력 파일을 직접 확인**해야 한다.
> 이 절차를 건너뛴 그림은 문서에 넣지 않는다.

---

## 1. 어느 방법으로 그리는가

| 대상 | 방법 |
|---|---|
| 개념도 · 블록선도 · 기하 그림 | **TikZ** (`assets/src/*.tex`) — 기본값 |
| 실제 화면 | PNG 캡처 → `week-quality-bar.md` |
| MATLAB 결과 그래프 | `print('-dpng','-r150', ...)` |
| 급한 임시 그림 | 수작업 SVG. 나중에 TikZ 로 옮긴다 |

- 저장 위치 — `assets/`, 소스는 `assets/src/`
- 파일명 — `w06-control-loop.svg` (주차·내용, 소문자, 하이픈)

TikZ 를 기본으로 두는 이유 — 손으로 SVG 좌표를 쓰면 화살촉·선 굵기·글자 크기가
그림마다 미묘하게 달라진다. 그것이 "자료가 어설퍼 보인다"의 정체다.

---

## 2. TikZ 파이프라인

```bash
bash _tools/tikz2svg.sh assets/src/w06-control-loop.tex assets/w06-control-loop.svg
```

- 경로 — `latex` → **DVI** → `dvisvgm --no-fonts` → SVG (PNG 도 같이 나온다)
- 스타일은 `assets/src/capstone-style.tex` 하나에서만 정한다. 그림마다 다시 정하지 않는다
- 블록 테두리 색은 **Simulink 모델 색 규칙과 같다** — `gblk` 유도 · `cblk` 제어 ·
  `tblk` 추진기 · `pblk` 운동모델 · `nblk` 항법

> [!caution] 한글은 `latex`(DVI) 경로로만 나온다
> | 경로 | 결과 |
> |---|---|
> | XeLaTeX → PDF → dvisvgm | ✕ dvisvgm 이 Ghostscript 10.07 을 거부 |
> | XeLaTeX → XDV → dvisvgm | ✕ TikZ 그래픽이 PDF special 로 빠져 **글자만** 남는다 |
> | **`latex`(ko.TeX) → DVI → dvisvgm** | **○** 그래픽·한글·수식 전부 |
>
> 필요한 TeX 패키지 — `kotex-utf` · `cjk-ko` · `nanumtype1` · **`kotex-plain`**.
> 마지막 하나가 없으면 `I can't find file kotexutf-core` 로 실패한다.
> TinyTeX 은 `%APPDATA%\TinyTeX` 에 있고 PATH 에 없으므로 스크립트가 직접 붙인다.

---

## 3. 검증 — 세 단계를 모두 한다

### ① 빌드가 실제로 성공했는가

- `wrote assets/그림.svg` 가 나와야 한다
- `No pages of output` · `latex failed` 면 실패다. **이전 SVG 가 남아 있어도 실패다**
- 자주 나오는 원인 — 정의하지 않은 TikZ 스타일 이름을 쓴 경우

### ② 그림을 눈으로 본다

`tikz2svg.sh` 가 PNG 를 같이 만든다. 그 PNG 를 **직접 열어 본다.**
수작업 SVG 는 Chrome 으로 렌더한다.

```bash
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless --disable-gpu \
  --screenshot="$(cygpath -w out.png)" --window-size=940,620 \
  --default-background-color=FFFFFF "file:///<절대경로>/그림.svg"
```

확인할 것

| 항목 | 흔한 증상 |
|---|---|
| 라벨 겹침 | 화살표 위에 글자가 얹힌다 |
| 잘린 글자 | 상자 밖으로 나가 캔버스에 잘린다 |
| 빈 그림 | 글자만 있고 선이 없다 → 엔진 선택이 틀린 것 |
| 선 교차 | 연결선이 다른 블록을 관통한다 |
| 한글 깨짐 | 네모로 나온다 → 폰트 패키지 누락 |

### ③ 자동 점검

```bash
bash .claude/skills/capstone-lecture-vault/scripts/vault_check.sh --fig
```

| 항목 | 잡는 것 |
|---|---|
| 9. 빌드 누락 | `.tex` 는 고쳤는데 `.svg` 를 다시 안 뽑은 경우 |
| 10. 그림 안의 금지 표현 | **본문 검사로는 안 걸린다.** 실제로 5건이 숨어 있었다 |
| 11. 수식 구분자 | `$$` 개수가 홀수 → 수식이 본문으로 샌다 |

---

## 4. 수식

- MD 본문은 LaTeX — `$y_e$`, `$$ ... $$` → `pdf-and-math.md`
- TikZ 안에서도 같은 문법을 쓴다. 본문과 **같은 글꼴**로 나오는 것이 TikZ 의 장점이다
- 기호는 볼드 벡터로 — `$\boldsymbol{\tau}$`, `$\tilde{\boldsymbol{\eta}}$`

### 수식 검증

1. `$$` 개수가 짝수인가 (`--fig` 가 검사)
2. PDF 를 뽑아 **수식이 조판되었는지** 본다. `$...$` 가 글자 그대로 보이면 실패다
3. 그림의 기호와 본문 표의 기호가 같은가 — 그림은 `\psi`, 본문은 `psi` 처럼 어긋나지 않게

---

## 5. 수작업 SVG (임시)

- 흰 배경 사각형 필수 — `<rect width="..." height="..." fill="#ffffff"/>`
  - 없으면 Obsidian 다크 모드에서 검은 글씨가 보이지 않는다
- 한글 폰트 `font-family="Malgun Gothic, sans-serif"`, 글자 크기 15 이상
- 팔레트 — 본문 `#1e293b` · 보조 `#64748b` · 파랑 `#1d4ed8` · 청록 `#0d9488` ·
  빨강 `#dc2626` · 주황 `#d97706` · 선 `#cbd5e1`
- **한 번의 Bash 호출에 SVG 하나씩.** 여러 개를 한 명령에 넣으면 셸 파싱이 깨진다
- 한글이 많으면 Bash 히어독 대신 **Write 도구**를 쓴다

---

## 6. 문서에 넣을 때

- 참조는 표준 마크다운 — `![설명](../assets/w06-control-loop.svg)`
- 그림만 던지지 않는다. **읽는 법**을 표로 덧붙인다
- 그림 1장당 이론 절 하나. 한 절에 3장을 넘기지 않는다
- 그림에 넣은 설명을 본문과 중복시키지 않는다. **그림은 구조, 본문은 수치**
