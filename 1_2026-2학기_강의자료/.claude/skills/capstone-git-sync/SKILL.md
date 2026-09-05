---
name: capstone-git-sync
description: 캡스톤디자인 폴더를 GitHub(wkyouncnu/Capstone-Design) 저장소와 동기화한다. 사용자가 "깃허브에 올려줘", "푸시해줘", "커밋해줘", "git", "백업해줘", "자동 푸시", "원격 저장소", "SSH 키", "푸시가 안 돼" 를 언급하거나, 자료를 고친 뒤 원격에 반영해야 할 때 사용하라. 무엇을 올리고 무엇을 절대 올리지 않는지의 판단 기준도 여기에 있다.
---

# GitHub 동기화

- 저장소 루트 — `C:\Users\admin\Dropbox\캡스톤디자인` (볼트보다 **한 단계 위**)
- 원격 — `git@github.com:wkyouncnu/Capstone-Design.git`, 기본 브랜치 `main`
- 실행 — `bash _tools/git_autopush.sh` (볼트 안에서 실행. 스크립트가 저장소 루트를 스스로 찾는다)

---

## 0. 무엇을 올리고 무엇을 올리지 않는가

> [!caution] 한 번 올라가면 되돌릴 수 없다
> GitHub 은 강제 푸시로 커밋을 지워도 **캐시·포크·검색 색인에 남는다.**
> 아래 세 가지는 어떤 경우에도 올리지 않는다.

| 절대 올리지 않는 것 | 이유 |
|---|---|
| `5_학생제출물/`, `출석부*.xlsx` | 학번·이름·성적. **개인정보** |
| 교재·학술논문·외부 기관 발표자료 | 배포권이 없다. `2_지난학기_강의자료/`, `4_참고자료/`, `50-원본자료/` |
| 100 MB 초과 파일 | GitHub 이 거부한다. 동영상·대용량 PPTX |

올리는 것 — **직접 만든 것만**

- `1_2026-2학기_강의자료/` 의 주차 자료(MD·PDF), 그림(SVG), Simulink 모델(`.slx`), 스크립트(`.m`), 스킬
- `3_예제코드/` 의 MATLAB 실습 원본
- `README.md`, `.gitignore`

판단이 애매하면 **올리지 않는 쪽**을 고른다.

---

## 1. 처음 한 번 — SSH 키를 GitHub 에 등록

현재 키는 만들어져 있으나 **GitHub 에 등록되어 있지 않다.** 그래서 푸시가 막힌다.

```bash
cat ~/.ssh/id_ed25519.pub
```

1. 출력된 한 줄을 전부 복사
2. https://github.com/settings/keys → **New SSH key**
3. Title 아무거나 / Key 에 붙여넣기 → **Add SSH key**
4. 확인

```bash
ssh -T git@github.com
```

- `Hi wkyouncnu! You've successfully authenticated` 가 나오면 성공
- 원격 저장소가 아직 없으면 https://github.com/new 에서 `Capstone-Design` 을 먼저 만든다.
  **README·.gitignore 를 추가하지 않는다** — 이미 로컬에 있어 충돌한다

> [!important] 저장소를 Private 로 만들 것을 권한다
> 강의자료는 공개해도 되지만, 실수로 개인정보가 섞였을 때의 피해가 다르다.

---

## 2. 평소 — 자동으로 올라간다

`.claude/settings.json` 의 **Stop 훅**이 세션이 끝날 때마다 `git_autopush.sh` 를 부른다.

- 바뀐 것이 없으면 아무 일도 하지 않는다
- 커밋 메시지는 자동 생성 — `자료 갱신 2026-09-05 14:30 — 12개 파일 (1_2026-2학기_강의자료)`
- **푸시가 실패해도 세션을 막지 않는다.** 커밋은 로컬에 남고, 다음에 함께 올라간다

직접 부를 때

```bash
bash _tools/git_autopush.sh "10주차 DP 게인 재측정"
```

### 스크립트가 스스로 멈추는 두 경우

| 상황 | 동작 |
|---|---|
| 개인정보·자격증명 파일이 스테이징됨 | **커밋하지 않고 중단.** 파일 목록을 출력 |
| 95 MB 초과 파일이 스테이징됨 | 〃 |

둘 다 `.gitignore` 를 고친 뒤 다시 실행한다. 스크립트를 고쳐서 통과시키지 않는다.

---

## 3. 자동 푸시를 끄려면

`.claude/settings.json` 에서 `Stop` 블록을 지운다. 수동 실행은 그대로 쓸 수 있다.

---

## 4. Dropbox 안의 git 저장소

- 이 저장소는 Dropbox 폴더 안에 있다. `.git` 도 함께 동기화된다
- **두 대의 PC 에서 동시에 커밋하지 않는다.** 동기화 충돌이 나면 `.git` 이 깨질 수 있다
- 다른 PC 에서 작업할 때는 Dropbox 동기화가 끝난 것을 확인하고 시작한다
- 안전한 대안 — 다른 PC 에서는 Dropbox 밖에 `git clone` 해서 쓴다

---

## 5. 자주 나오는 오류

| 메시지 | 원인 | 조치 |
|---|---|---|
| `Permission denied (publickey)` | SSH 키 미등록 | §1 |
| `Repository not found` | 원격 저장소가 없음 / 권한 없음 | GitHub 에서 저장소 생성 |
| `remote contains work that you do not have` | 원격이 앞서 있음 | `git pull --rebase origin main` 후 재시도 |
| `file is 123.00 MB; exceeds 100.00 MB` | 큰 파일이 이미 커밋됨 | `.gitignore` 추가 + `git rm --cached <파일>` 후 새로 커밋 |
| `LF will be replaced by CRLF` | 경고일 뿐 | 무시 |
