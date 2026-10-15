# 모델을 코드로 만들기

## 한 파일의 골격

```matlab
function build_w05_models()
    here = fileparts(mfilename('fullpath'));  cd(here);
    if evalin('base','~exist(''wp_north'',''var'')')
        error('먼저 W05_setup 을 실행하십시오.');
    end
    build_offline();
    build_vrx();

    slxList = dir('*.slx');
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try, tidy_model(mName); export_model_pngs(mName); catch e, warning(e.message); end
    end
    fprintf('\n완료.\n');
end
```

## 공통 헬퍼 — 그대로 복사해 쓴다

```matlab
function fresh(m)
    if bdIsLoaded(m), close_system(m, 0); end
    if isfile([m '.slx']), delete([m '.slx']); end
    new_system(m); load_system(m);
end

function setFcn(sys, path, code)          % MATLAB Function 블록 본문 채우기
    add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/' path]);
    S = sfroot; B = S.find('Path', [sys '/' path], '-isa','Stateflow.EMChart');
    B.Script = code;
end

function C(m, name, value, x, y)          % Constant
    add_block('simulink/Sources/Constant', [m '/' name], ...
              'Value', value, 'Position', [x y x+95 y+30]);
end

function F(m, tag, sfx, x, y)             % From
function G(m, tag, x, y)                  % Goto
function note(m, tag, txt, x, y)          % 주석
```

- **From/Goto 이름은 `Fr_<tag>_<접미사>` / `Go_<tag>`** 로 통일한다. 이름이 겹치면 `add_line` 이 조용히 엉뚱한 데 붙는다

## Stateflow 를 코드로

```matlab
ch = Stateflow.Chart(machine);
ch.ActionLanguage = 'MATLAB';
ch.ChartUpdate    = 'DISCRETE';
ch.SampleTime     = 'Ts_ctrl';

s = Stateflow.State(ch);  s.LabelString = sprintf('WpFollow\nen: mode = 1;');
t = Stateflow.Transition(ch);  t.Source = s1;  t.Destination = s2;
t.LabelString = '[at_loiter > 0.5]';

d = Stateflow.Data(ch);  d.Name = 'mode';  d.Scope = 'Output';
```

- **기본 전이**는 `Source` 를 비우고 `Destination` 만 준다
- 상태·전이의 좌표(`Position`, `MidPoint`)를 반드시 지정한다. 안 하면 전부 원점에 겹친다

## 자주 걸리는 것

| 증상 | 원인 | 해법 |
|---|---|---|
| `Algebraic loop` 오류 | 모드 신호가 자기 자신으로 되먹임 | 경로에 **Unit Delay 1개** |
| 로이터 중 웨이포인트 인덱스가 전진 | 인덱스 갱신에 모드 조건이 없음 | `if (mode < 1.5) && reached && (k < n-1)` |
| 로이터 중심이 따라 움직임 | 중심을 매 스텝 계산 | 진입 시점 값을 상수로 고정 |
| `To Workspace` 데이터가 `[2×1×N]` | 벡터 신호 | `squeeze(out.log_x.Data)'` |
| MATLAB Function 안에서 그림이 안 그려짐 | 코드 생성 대상 | `coder.extrinsic('plot', ...)` |
| 제목의 한글이 네모로 나옴 | `'FontName','Consolas'` | FontName 을 지정하지 않는다 |
| 실제보다 배가 느리게 감 | 페이싱 ≠ RTF | `PacingRate` 를 **실측 RTF** 와 같게 |
| `이름이 '…/input n [rad/s]'인 새 블록은 추가할 수 없음` | **Simulink 블록 이름에 `/` 를 못 쓴다.** 경로 구분자다 | 단위를 풀어 쓴다 — `(rad per s)` |
| `To Workspace` 로그가 `[8 1 nT]` 3차원으로 나옴 | MATLAB Function 의 `n = [nL; nR]` 는 2×1 **행렬** 신호다. Mux 입력 **하나**가 행렬이면 출력 전체가 행렬이 된다 | 그 신호에 **Reshape(`1-D array`)** 를 물린다 → `model-layout.md` §5 |
| `유효하지 않은 표현식입니다` | `...` 줄바꿈 **다음 줄에 주석**을 넣었다 | 주석은 호출문 **위**로 뺀다 |

## 단계를 하나 더 쌓을 때 — 모델 밖에서 함께 고치는 것 셋

사다리 예제(`decisions.md` §4-3)에 단계를 더하면 `.slx` 만으로 끝나지 않는다.
2026-10-15 6주차 7·8단에서 셋을 한꺼번에 밟았다.

| 함께 고칠 곳 | 안 고치면 | 고침 |
|---|---|---|
| `_tools/gnc_roles.m` 의 `case` 목록 | `check_flow` 가 "단계를 모르는 블록" 을 물고 그 상자가 흰색으로 남는다 | 새 모델 이름을 같은 `case` 줄에 더한다 |
| 받침 상자(`NotYet`)가 흘리는 0 의 **모양** | 아랫단에서 `WNN_plot` 이 `n(:,2)` 를 찾다 멈춘다 | 신호 폭까지 맞춘다 — 추진기가 셋이면 `'[0; 0; 0]'` |
| 강의노트가 쓰는 공용 서브시스템 도면 | 가장 높은 단계에서 뽑으면 **좌표계가 다른 단계**의 그림이 `img/InnerLoop.png` 를 덮어쓴다 | 같은 사슬의 최고 단계에서 뽑고, 갈라진 단계는 꼬리를 붙여 따로 뽑는다 (`InnerLoopNED.png`) |

- 받침은 **아랫단에서도 같은 그림이 그려지게** 두는 장치다. 값이 0 인 것은 보이지만
  폭이 틀리면 그림이 멈춘다 — 폭도 계약이다
- 공용 도면을 어디서 뽑는지는 `build_wXX_models.m` 끝의 `shots` 표 한 곳에 모아 둔다

> [!caution] 서브시스템 도면은 "가장 높은 단계" 가 아니라 **그 그림을 설명하는 단계**에서 뽑는다
> 윗단의 서브시스템이 아랫단의 것보다 **더 큰** 경우에만 최고 단계가 답이다. 블록이
> 아예 **다른** 경우에는 최고 단계가 강의노트와 어긋난다.
> 2026-10-15 에 `img/Guidance.png` 가 7단(`addGuidanceFront`, 전진 접안)에서 뽑히고
> 있었다. 강의노트의 캡션과 `dock_on` 설명은 5단(`addGuidance`, 세 단계 접안)의
> 것이므로 그림만 다른 블록이었다. `shots` 를 쪼개 Guidance 만 5단에서 뽑게 고쳤다.
> 판별법 하나 — **단계를 더할 때 `addXxx` 함수 이름이 바뀌었으면 그림도 갈라진 것이다.**

## 파일을 쓰는 방법 — 긴 한글 `.m` 은 히어독으로 쓰지 않는다

- Bash 히어독으로 긴 한국어 MATLAB 본문을 쓰면 `unexpected EOF while looking for
  matching` 로 깨진다. Write 도구로 쓰거나, 작은 파이썬 스크립트를 UTF-8 로 돌린다
- 이 PC 에는 `python3` 가 없다. **`py`** 로 부른다

## 실시간 애니메이션을 모델 안에 넣기

- MATLAB Function 블록 + `coder.extrinsic`, 지속 변수(`persistent`)에 figure 핸들 보관
- 선수는 **삼각형**, 선미는 **사각형** — 방향이 한눈에 보인다
- 제어 루프와 분리해 `en` 입력으로 켜고 끈다. 끄면 시뮬레이션이 빨라진다
- 궤적만 그리지 말고 **선체와 선수 방향선**을 함께 그린다 — 크랩각이 그 차이다
- 사람이 버튼·슬라이더로 조작하는 모델은 → `interactive-models.md`

> 표의 마지막 세 줄(블록 이름의 `/`, Mux 행렬 입력, `...` 뒤 주석)과 실시간 애니메이션의
> 선체 표시는 대학원 GradCourse 볼트에서 가져옴 — 2026-09-24
