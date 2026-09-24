# 사람이 조작하는 모델 — 버튼 · 슬라이더 · 조종기 · USB 장치

학생이 **모델을 돌려 놓고 직접 몰아 보는** 예제를 만들 때 읽는다.
키보드 텔레옵 노드(`wamv_teleop_key` 등)에 대응하는 Simulink 판이 여기에 해당한다.

전부 R2024b 에서 **실제로 돌려서** 확인한 것이다. 확인하지 않은 것은 적지 않는다.

---

## 1. 스크립트 없이 도는 모델

학생이 `.slx` 를 더블클릭하고 Run 만 눌러도 돌아야 한다.

| 할 일 | 방법 |
|---|---|
| 변수 | **모델 작업공간**에 넣는다 — `assignin(get_param(m,'ModelWorkspace'), name, value)`. 모델과 함께 저장된다 |
| 경로 | `PostLoadFcn` 이 `get_param(bdroot,'FileName')` 에서 폴더를 얻어 `_tools` 를 `addpath` |
| 실시간 | `EnablePacing on`, `PacingRate` 는 **실측 RTF** 와 같게, `StopTime inf` |
| 실행 중 값 변경 | **`BlockReduction off`** — 켜 두면 Terminator 로만 가는 Constant 가 최적화로 사라져 `set_param` 이 "시뮬레이션 중에는 변경할 수 없다" 로 거부한다 |
| MATLAB Function 의 상수 | 입력 포트 대신 **Parameter** 로 둔다. `find(sfroot,'-isa','Stateflow.EMChart','Path',blk)` 에서 `Stateflow.Data` 를 찾아 `Scope='Parameter'`. 값은 모델 작업공간의 같은 이름에서 온다 — **선이 늘지 않는다** |

---

## 2. 캔버스 위의 조작 장치

> [!important] 라이브러리 이름은 **`simulink_hmi_blocks`** 다
> `simulink/Dashboard/…` 로는 찾지 못한다. 그쪽은 라이브러리를 여는 껍데기다.
> 조종기 스틱처럼 모양이 다른 것은 `simulink_hmi_customizable_blocks` 에 있다.

### 버튼 — 신호가 아니라 **파라미터**를 누른다

```matlab
add_block('simulink_hmi_blocks/Push Button', [ss '/btn_fwd'], 'Position',[x y x+90 y+70]);
info = Simulink.HMI.ParamSourceInfo;
info.BlockPath = [ss '/c_fwd'];      % 묶을 블록 (Constant)
info.ParamName = 'Value';            % 묶을 파라미터
set_param([ss '/btn_fwd'], 'Binding', info, ...
          'ButtonText','▲ 전진', 'OnValue','1', 'OffValue','0', ...
          'ButtonType','Momentary');
```

- `Binding` 은 반드시 `Simulink.HMI.ParamSourceInfo` **객체**여야 한다. 핸들을 주면 거부된다
- `Momentary` 는 누르는 동안만 `OnValue`. 떼면 저절로 0 이 되므로 "정지" 버튼이 필요 없다
- **모델을 돌린 상태에서** 눌러야 반응한다
- `set_param` 으로 Constant 값을 바꾸면 **묶인 슬라이더도 따라 움직인다** — 정지 중에도 실행 중에도

### 장치별 주의

| 장치 | 블록 | 주의 |
|---|---|---|
| 라디오 버튼 | `simulink_hmi_blocks/Radio Button` | `States = struct('Value',…,'Label',…)`, 캡션은 `ButtonGroupName` |
| 가로 슬라이더 | `simulink_hmi_blocks/Slider` | `Limits = [최소 눈금 최대]`. 눈금에 −1 을 주면 자동 |
| 조종기 스틱 | `simulink_hmi_customizable_blocks/Vertical Slider` · `Horizontal Slider` | **범위를 코드로 바꿀 수 없다** (`ScaleMin`·`Limits` 는 받지만 저장 뒤 비어 있다). 0\~100 그대로 두고 **모델 안에서 정규화**한다 — 수신기 펄스 1000\~2000 µs 와 같은 구조 |
| 그림 버튼 | 둥근 버튼 PNG 를 **그림 주석**에 넣고 `ClickFcn` | Dashboard Callback Button 은 코드로 준 `ClickFcn`·글자가 **저장 뒤 사라진다** |
| 장치 몸체 | 그림 주석을 **먼저** 놓고 Dashboard 블록을 그 위에 얹는다 | 주석은 블록 뒤에 그려진다. 영역(area) 주석의 배경색은 저장 뒤 흰색으로 돌아가므로 글자는 그림 안에 그린다 |

- `mss_style(m)` 은 모든 블록 크기를 바꾸므로 **Dashboard 블록은 그 뒤에** 넣는다
- 캔버스가 넓어지면 블록도 PNG 가 2000 px 를 넘는다. 안내문은 옆이 아니라 **아래**에 둔다

---

## 3. 실시간 화면

| 할 일 | 방법 |
|---|---|
| **조작한 값** | **반드시 그린다.** 화면에 없으면 학생은 "슬라이더가 안 먹는다" 고 본다 |
| 상태 외의 신호 | 최상위의 탭 블록(MATLAB Function + `coder.extrinsic('setappdata')`)이 매 스텝 맡기고, 그리는 함수가 `getappdata` 로 꺼낸다 |
| t = 0 의 옛 값 | `StartFcn` 이 `rmappdata` 로 지운다. 없으면 NaN 이 남는다 |
| 두 모델이 한 화면 | `StartFcn` 이 `setappdata(0,'<tag>_model',bdroot)`. 화면 함수가 그 모델 작업공간에서 한계값을 읽는다 |
| 창 두 개 | 모델 창을 화면 왼쪽, 그래프를 오른쪽에. 겹치면 버튼을 누를 때마다 그래프가 가려진다 |
| 처음부터 다시 | START 가 stop → 완전히 멈출 때까지 대기 → start |

- 궤적을 그릴 때는 **선체 실루엣과 선수 방향선**을 함께 그린다 (궤적선만으로는 크랩각이 안 보인다)
- 그리는 함수가 창을 둘 이상 열면 **`gcf` 로 저장하지 않는다.** 핸들을 돌려받아 그것을 저장한다

---

## 4. 실물 USB 장치 (조종기 · 게임패드)

| 할 일 | 방법 |
|---|---|
| 블록 | Simulink 3D Animation **`vrlib/Joystick Input`** (`joyid`). 출력은 축 벡터와 버튼 |
| 장치 확인 | `j = vrjoystick(id); caps(j); read(j)` — 없으면 "Joystick is not connected" |
| 모델 생성 | **장치 없이 된다.** 컴파일(실행)만 장치를 요구한다 |
| 축의 의미 | 조종기는 USB 로 **채널**(AETR 등)을 보낸다. 모드는 조종기 안에서 적용되므로 모델에 모드 스위치를 두지 않는다 |
| 축 번호·방향 | **가정하지 않는다.** "움직여 보라" 고 한 뒤 무엇이 움직였는지 본다 — 가장 크게 변한 축과 부호, 전체 폭의 1/4 미만이면 거부 |
| START | 먼저 `vrjoystick` 으로 열어 본다. 없으면 창으로 알리고 시작하지 않는다. 스로틀이 중립이 아니면 시작하지 않는다 |

> [!note] Aerospace Blockset 의 pilot 라이브러리는 **조종사 동특성 모델**이다
> 장치 블록이 아니다. 찾아도 나오지 않는다.

### 장치 없이 검증하는 법

장치에서 모델로 들어오는 것은 그 블록의 출력 하나뿐이다.
**그 블록만 같은 모양의 Constant 로 바꾼 임시 사본**을 만들어 돌린다.

```matlab
save_system(m0, fullfile(tempdir,'harness.slx'));      % 사본. 원본은 그대로 둔다
lh = get_param(jb,'LineHandles');  delete_line(lh.Outport(lh.Outport > 0));
p  = get_param(jb,'Position');     delete_block(jb);
add_block('simulink/Sources/Constant', [tx '/fake axes'], 'Value','ax_test', 'Position', p);
```

- 축 순서·방향이 다른 가짜 장치 몇 개로 돌려, 화면 조종기 모델과 **자릿수까지 같은지** 본다
- 장치를 읽는 부분만 미검증으로 남는다. **문서에 그렇게 적는다** —
  출력을 지어내지 않고 판정 기준 표만 둔다

---

## 5. 문서에 싣는 수치

사람이 조작한 실행은 **재현되지 않는다.** 그대로 표에 옮기면 학생이 같은 값을 못 본다.

- **조작마다 한 번씩 돌리는 확인 스크립트**가 표를 만든다
- Pacing 과 실시간 화면은 끈다 — `setModelParameter('EnablePacing','off')`,
  `setVariable('animate', 0, 'Workspace', m)`
- 정지 상태에서 일정 시간 유지한 값을 싣고, **측정 구간을 명시**한다

> [!warning] 확인 스크립트에서 `clear` 를 그냥 쓰지 않는다
> MCP 로 돌리면 스크립트는 **기본 작업공간**에서 돈다. 맨 앞의 `clear` 가 기본 작업공간을
> 비워, 기본 작업공간 변수를 읽는 **다른 모델**이 다음 실행에서 "SampleTime 이 유효하지
> 않다" 로 멈춘다. 제 변수만 이름으로 지운다 — `clear m cfg y …`

---

## 6. 이 문서를 위해 가져오면 좋을 `_tools` — 다음 작업 후보

> [!note] 아직 이 볼트에 없다. 코드를 복사해 오지 않았다

| 도구 | 하는 일 | 왜 |
|---|---|---|
| `hmi_bind.m` | `Simulink.HMI.ParamSourceInfo` 조립 세 줄을 한 줄로 | 버튼·슬라이더를 쓸 때마다 같은 세 줄을 다시 쓴다 |
| `image_button.m` | 둥근 버튼 PNG + `ClickFcn` 그림 주석 | Dashboard Callback Button 이 저장 뒤 글자를 잃는 문제의 우회로 |
| `mlfcn_params.m` | MATLAB Function 상수를 `Scope='Parameter'` 로 | §1 의 "선이 늘지 않게" 를 한 줄로 |
| `live_dash.m` | 한 창에 궤적 + 상태 여섯 | 조작한 값이 화면에 보여야 한다는 §3 의 요구를 한 함수가 충족 |

---

> 대학원 GradCourse 볼트 `simulink-gnc-models/references/interactive-models.md` 에서 가져오고,
> 캡스톤 `SKILL.md` 에 흩어져 있던 Dashboard 버튼 관용구를 이 문서로 합침 — 2026-09-24
