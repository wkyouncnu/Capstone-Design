# PDF 와 수식

## 1. PDF — 이 한 줄이 전부다

```bash
bash _tools/pdf_sync.sh
```

- **PDF 가 원본보다 오래된 문서만** 골라 다시 뽑는다. 대상 폴더는 `10-주차별-강의자료` · `80-과제` · `00-운영` · `30-환경`
- 검사만 하려면 `bash _tools/pdf_sync.sh --check` (갱신 대상 수가 종료코드)
- **세션이 끝날 때 Stop 훅(`_tools/hook_stop.sh`)이 이 스크립트를 자동으로 부른다.** 그 뒤 `git_autopush.sh` 가 돈다
  - 훅 경로는 `.claude/settings.json` 에 박아 두지 않는다. `CLAUDE_PROJECT_DIR` 에서 위로 올라가며 `_tools/` 를 찾는다 (계정·PC 가 달라도 동작)
- 파일을 지정해 뽑고 싶으면 아래를 쓴다

```bash
bash _tools/md2pdf.sh 10-주차별-강의자료/W0*.md
```

- 인터넷 불필요. `_tools/marked.min.js` + `_tools/mathjax-tex-svg.js` 로컬 사본 사용
- 서식 기준은 `_tools/pdf-template.html` 의 `<style>` **하나**
- 성공 시 `[OK] 파일명 NNN KB`, 실패 시 원인까지 출력한다

### 무엇이 바뀌면 다시 뽑는가 — 네 가지

| 바뀐 것 | 잡히는가 | 보고되는 이유 |
|---|---|---|
| MD 본문 | O | `MD` |
| MD 가 싣고 있는 그림 (PNG · SVG) | O | `그림 <파일명>` |
| 조판 도구 — `pdf-template.html` · `md2pdf.sh` · `marked.min.js` · `mathjax-tex-svg.js` | O | `조판도구 <파일명>` |
| 짝 PDF 가 아예 없음 (주차자료 · 과제) | O | `PDF 없음` |

> [!warning] 그림과 템플릿을 보지 않으면 조용히 어긋난다
> MD 의 시각만 비교하던 때에는 Simulink 도면을 다시 뽑거나 CSS 를 고쳐도
> 검사가 "갱신할 것 없음" 이라 했다. PDF 는 옛 그림을 품은 채 남고, 학생이
> 받는 것은 그 PDF 다. 2026-09-17 에 두 번 겪었다 — 그림 높이 제한을 넣었을
> 때와 블록에 색을 칠했을 때. 그때는 전부 강제로 다시 뽑아야 했다.
>
> 이제 `why_stale()` 이 MD 에서 `![](경로)` 와 `<img src="경로">` 를 훑어
> 그림의 시각까지 비교한다. **강제 재생성은 더 필요 없다.**

> [!important] 그림을 바꿨으면 `pdf_sync` 를 한 번 더 돌린다
> Simulink 모델을 고쳐 PNG 를 다시 뽑았으면, 그 그림을 싣는 주차 PDF 가
> 자동으로 목록에 오른다. 어느 주차인지 외울 필요가 없다.
> 목록에 뜨지 않는다면 **그 그림이 어느 강의자료에도 실려 있지 않다는 뜻이다** —
> 자료의 구멍이지 스크립트의 문제가 아니다 (스킬 `capstone-lecture-vault` 규칙 8).

- 쪽수 확인이 필요하면 아래를 쓴다

```bash
grep -ao "/Count [0-9]*" 파일.pdf | sort -t' ' -k2 -n | tail -1
```

> [!warning] Chrome 은 Windows 실행 파일이라 POSIX 경로를 못 읽는다
> 스크립트가 `cygpath -w` (출력) / `cygpath -m` (입력 URL) 로 변환해 넘긴다.
> Chrome 을 새로 호출하는 코드를 추가할 때도 같이 처리할 것.

### 실패할 때

| 증상 | 원인 | 조치 |
|---|---|---|
| `갱신되지 않음` + `0x20` | PDF 뷰어가 파일을 열고 있음 / Dropbox 동기화 중 | 뷰어를 닫고 재실행. 스크립트가 3회 재시도한다 |
| 수식이 `$…$` 그대로 | MathJax 가 늦게 끝남 | 템플릿의 `data-ready` 와 `--virtual-time-budget` 을 건드리지 말 것 |
| 그림이 빠짐 | 상대경로가 MD 위치 기준이 아님 | 임시 HTML 은 **MD 와 같은 폴더**에 만들어진다. 경로를 그에 맞춘다 |

---

## 2. 수식 — MathType 이 아니라 LaTeX

> [!important] 별도 도구가 필요 없다
> LaTeX 으로 쓰면 **Obsidian · GitHub · PDF 세 곳에서 모두** 렌더된다.
> PDF 는 로컬 MathJax 3 (`tex-svg-full`) 이 SVG 로 조판한다. 이미지 파일을 만들지 않는다.

- 인라인 `$y_e$`
- 블록

```markdown
$$
\psi_{\text{ref}} = \pi_p - \arctan\!\left(\frac{y_e}{\Delta}\right)
$$
```

- 여러 줄은 `aligned`

```markdown
$$
\begin{aligned}
m\,\dot{u} &= X - (X_u + X_{uu}|u|)\,u + m\,v\,r \\
I_z\,\dot{r} &= N - (N_r + N_{rr}|r|)\,r
\end{aligned}
$$
```

### 쓸 때의 판단

| 상황 | 형식 |
|---|---|
| 긴 유도, 기호 정의 | 블록 수식 |
| 코드에 **그대로** 쓰이는 식 | 코드블록 (```matlab) |
| 둘을 섞기 | 하지 않는다. 학생이 어느 쪽을 옮겨 적어야 할지 모른다 |

- 기호를 쓴 뒤에는 **기호 표**를 붙인다 (기호 / 값 / 출처)
- 값의 출처는 파일명까지 적는다 — `wamv_gazebo_dynamics_plugin.xacro`

---

## 3. 템플릿이 하는 일 (고치기 전에 읽을 것)

`pdf-template.html` 의 변환 순서. **순서가 전부다.**

```
1) 코드블록 ``` … ```  →  @C0@ 로 빼둔다
2) 인라인 코드 ` … `   →  @C1@ 로 빼둔다
3) 블록 수식 $$ … $$   →  @M0@ 로 빼둔다
4) 인라인 수식 $ … $   →  @M1@ 로 빼둔다
5) @C…@ 를 코드로 되돌린다
6) marked() 로 마크다운 → HTML
7) @M…@ 를 수식 원문으로 되돌린다 (HTML 이스케이프)
8) MathJax.typesetPromise() → 끝나면 data-ready="1"
```

이 순서 때문에 생기는 좋은 결과 두 가지:

- `$HOME`, `$(pwd)` 가 **수식으로 잡히지 않는다** (1·2단계에서 이미 빠졌으므로)
- `y_e` 의 밑줄이 **강조로 해석되지 않는다** (marked 가 수식을 보지 못하므로)

---

## 4. 그림이 두 쪽에 걸치지 않게

`break-inside: avoid` **하나로는 안 된다.** 그 규칙은 "한 쪽에 들어가는 요소"만
다음 쪽으로 밀어 준다. 쪽보다 큰 그림에는 아무 효과가 없고, 브라우저는 자른다.

- A4 297mm − 위 13 − 아래 16 = **본문 높이 268mm**, 본문 폭 186mm
- 따라서 **세로/가로 비가 1.44 를 넘는 그림**은 폭에 맞추는 순간 쪽을 넘는다

템플릿이 하는 일 두 가지.

```css
img { max-width: 100%; max-height: 248mm; height: auto; ... }
.figblock { break-inside: avoid; page-break-inside: avoid; }
```

- `max-height` 로 **높이를 본문 안에 가둔다.** `max-width` 와 함께 주면 비율은 유지된다
- marked 는 그림을 `<p>` 로 감싸므로, 렌더 뒤 JS 가 **그림만 든 문단**에 `.figblock` 을 붙인다

> [!important] 측정으로 확인한다
> 그림 하나만 든 MD 를 만들어 쪽 수를 세면 바로 보인다.
> ```bash
> grep -ao "/Count [0-9]*" 파일.pdf | head -1
> ```
> 2026-09-17 측정 — `W02_1_pose_sub.png` (1205×1999, 비 1.66) 하나만 담은 문서가
> **제한 없이 3쪽, `max-height: 248mm` 에서 1쪽**이었다.
>
> PDF 를 그림으로 볼 수 없는 환경(`pdftoppm` 미설치)에서도 이 방법은 동작한다.

- 그림을 새로 만들 때 **비 1.44 를 넘기지 않는 것이 가장 좋다.**
  넘으면 제한에 걸려 폭이 줄어들고, 쪽 옆이 비어 보인다
- 사슬이 긴 Simulink 도면은 `lay_chain` 의 `Wrap` 으로 접는다 →
  스킬 `simulink-gnc-models` 의 `references/line-routing.md` §8.5

---

### 템플릿 지뢰

| 증상 | 원인 | 조치 |
|---|---|---|
| **그림이 두 쪽에 걸침** | 그림이 본문 높이(268mm)보다 큼 | `img` 의 `max-height` 를 확인. §4 |
| `Can't load "/input/tex/extensions/boldsymbol.js"` | MathJax 축약 빌드는 확장을 원격에서 받는다 | **`tex-svg-full.js`** 를 쓴다 |
| 파일이 갑자기 "binary" 로 잡힘 | Edit 도구가 NUL 문자를 삽입 | `tr -d '\000'` 로 제거 후 재확인 |
| 수식 번호가 붙음 | `tags` 기본값 | 설정이 `tags:"none"` 이다. 바꾸지 말 것 |
| 마커를 찾을 수 없음 | `<!--MDCONTENT-->` `<!--MATHJAXJS-->` `<!--MARKEDJS-->` 중 하나가 사라짐 | 세 마커는 `md2pdf.sh` 가 템플릿을 4등분하는 기준이다. 지우지 말 것 |

---

## 5. Obsidian 쪽 확인

- 수식은 Obsidian 에서도 그대로 보인다. 별도 플러그인 불필요
- 다만 **Obsidian 전용 문법(`![[파일]]`)은 쓰지 않는다** — VSCode·GitHub 에서 깨진다
- 그림은 항상 표준 마크다운 `![설명](../assets/x.svg)`

---

## 쪽 번호 — `@page` 마진 박스

모든 PDF 오른쪽 아래에 `현재쪽 / 전체쪽` 이 찍힌다. `_tools/pdf-template.html` 의
`@page` 안에 있다.

```css
@page {
  size: A4;
  margin: 13mm 12mm 16mm 12mm;
  @bottom-right {
    content: counter(page) " / " counter(pages);
    font-size: 8.6pt;
    color: #94a3b8;
  }
}
```

- **Chrome 이 `@page` 마진 박스를 지원한다.** 2026-09-16 에 실측으로 확인했다
  — 같은 3쪽 문서가 카운터 없이 10255 bytes, 카운터를 넣으면 15258 bytes
- `position: fixed` 로 흉내 내지 않는다. 모든 쪽에 **같은 숫자**가 찍힌다
- 아래 여백을 14mm 에서 **16mm** 로 늘렸다. 그러지 않으면 본문 마지막 줄과 겹친다

> [!important] 템플릿을 고치면 `pdf_sync` 만 돌리면 된다
> `pdf_sync.sh` 가 `pdf-template.html` 의 시각도 본다. 템플릿이 PDF 보다 새로우면
> 그 PDF 는 `조판도구 pdf-template.html` 이유로 목록에 오른다 — **강제 재생성은
> 더 필요 없다.** §1 의 표를 볼 것.
