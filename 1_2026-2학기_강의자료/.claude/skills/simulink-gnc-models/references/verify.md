# 검증 — 문서에 수치를 싣기 전에

## 1. 컴파일과 미연결 포트

```matlab
set_param(m, 'SimulationCommand', 'update');          % 컴파일만
```

```matlab
% 미연결 포트 세기
ph = find_system(m,'FindAll','on','Type','port');
n  = sum(arrayfun(@(h) isempty(get_param(h,'Line')) || get_param(h,'Line') < 0, ph));
```

## 2. 겹침·꺾임

```matlab
tidy_all('<폴더>')     % 겹침 0 이 합격선
```

## 2-2. 색

```matlab
check_colour('<모델>')      % 흰색으로 남은 블록 0 이 합격선
```

- 걸리면 `_tools/gnc_roles.m` 의 그 모델 `case` 를 고치고 `paint_roles` 를 다시 부른다
- 색이 빠져도 모델은 돌아가고 수치도 맞다. 그래서 **검사하지 않으면 모른다**

## 3. 실제로 돌린다

- 문서에 싣는 값은 전부 `sim()` 결과
- 구간을 명시한다 — "전 구간 평균" 과 "초기 60초 제외" 는 다른 숫자다
- 비교 실험은 **한 번에 하나만** 바꾼다

## 4. 오프라인 모델과 시뮬레이터를 맞춘다

- 오프라인 운동모델의 계수는 시뮬레이터 플러그인 설정과 **같은 값**이어야 한다
- 확인법: 같은 추력을 주고 정상상태 속도를 비교 (예: 400 N → `u` 1.333 vs 1.331)
- 안 맞으면 오프라인에서 맞춘 게인이 시뮬레이터에서 그대로 쓰이지 않는다

## 5. 실시간 페이싱

```matlab
set_param(m,'EnablePacing','on','PacingRate', RTF);
```

- `PacingRate` 는 **실측 RTF** 와 같아야 한다. 다르면 대지속도가 절반으로 보인다
- RTF 는 시뮬레이터 로그에서 읽는다

## 6. VRX 정리

```bash
pkill -f "vrx_gz|vrx_ros|ros_gz_bridge|gz sim|ruby|parameter_bridge"
```

- `vrx_ros` 를 빼면 `optical_frame_publisher` · `pose_tf_broadcaster` 가 고아로 남는다

## 7. 시뮬레이터에 없는 물리는 실험할 수 없다

- 있는지 없는지는 **소스에서 확인한다** (grep + 플러그인 SDF 파라미터)
- 없으면 오프라인 모델에서만 다루고, 문서에 그 사실을 적는다

---

## 8. VRX 실연동 — 스크립트 하나로 끝낸다

손으로 RTF 를 재고 페이싱을 맞추는 절차는 학생이 반드시 틀린다. 스크립트로 묶는다.

```matlab
function S = WXX_vrx_run(T_end, do_compare)
% 1) 토픽 확인  2) RTF 측정  3) 페이싱 맞춰 실행  4) 결과 그림  5) 오프라인 대조
```

- **RTF 측정** — `/…/ground_truth_odometry` 의 헤더 스탬프를 20초 간격으로 두 번 읽는다

```matlab
n  = ros2node('/rtf_probe', 0);
s  = ros2subscriber(n, TOP, 'nav_msgs/Odometry');
m0 = receive(s,15); w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(20);
m1 = receive(s,15); dw = toc(w);
RTF = (double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9 - t0) / dw;
```

- **VRX 모델에도 `Animate` 블록을 넣는다** — 주행 중 항적이 보인다. Gazebo 화면 없이도 확인 가능

### 8.1 결과 그림은 **두 장**을 같은 이름으로 남긴다 (교수 지시 2026-10-15)

VRX 연동 단이 있는 주차는 실행 파일이 그림을 **띄우기만 하면 안 된다.** Gazebo 가
떠 있는 자리에서만 얻는 그림이므로, 그 자리에서 파일로 남겨야 다음 사람이 본다.
주차마다 이름이 달라지면 강의자료에서 찾지 못하므로 **이름을 규칙으로 고정한다.**

| 파일 | 무엇 | 내는 곳 |
|---|---|---|
| `img/WXX_N_vrx_result.png` | 연동 단(N단) 자체의 성능 그림 — `WXX_plot` 이 낸 그 창 | `WXX_vrx_run` 끝 |
| `img/WXX_vrx_vs_offline.png` | 같은 조건으로 돌린 **오프라인 ↔ VRX 대조** | 같은 곳, `do_compare` |

```matlab
IMG = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(IMG), mkdir(IMG); end
S = WXX_plot(out, ttl);
exportgraphics(S.fig, fullfile(IMG,'WXX_N_vrx_result.png'), 'Resolution', 130);
```

- **대조 그림의 칸은 그 주차가 답해야 하는 질문 순서로 둔다.** 칸 수를 늘리는 것이
  목적이 아니다. 5주차는 궤적과 이격 두 칸으로 족하지만, 접안(6주차)은
  *제자리에 섰는가 · 자세가 맞는가 · 힘을 얼마나 썼는가* 를 따로 물으므로
  여섯 칸이다 — 궤적+선석 · 목표까지 거리(+$R_{dock}$·$R_{stop}$) · 이격 ·
  $\psi$ 와 $\psi_t$ · $u$·$v$ · $F_L$·$F_R$·$F_B$
- 색은 **VRX 주황 `[0.85 0.33 0.10]` · 오프라인 파랑 `[0 0.45 0.74]`** 로 주차마다 같게
- 끝에 두 열 표(완료·끝오차·자세오차·최대 속도·최대 추력·주행거리)를 `fprintf` 로 찍는다
- **VRX 로그를 `setappdata` 로 남긴다** — Gazebo 를 한 번 돌리기 어려우므로, 그림을
  다시 그리려고 다시 돌리는 일을 막는다 (`setappdata(0,'WXX_vrx_log', V)`)

> [!caution] 찍지 못한 그림을 강의자료에 `![…]` 로 링크하지 않는다
> `vault_check.sh` 가 **없는 그림을 잡아낸다.** VRX 가 떠야 생기는 PNG 는 실제로
> 찍은 뒤에 링크한다. 그 전에는 "어느 파일로 남는지 · 각 칸을 어떻게 읽는지" 만 적는다

### 8.2 실시간 화면은 `WXX_anim_capture.m` 로 찍는다

애니메이션 그림도 **재현되어야 한다.** 손으로 창을 잡아 찍으면 다음 사람이 같은
그림을 얻지 못하고 조건(게인·시간·RTF)도 남지 않는다. 주차마다 한 장 둔다.

```matlab
function info = WXX_anim_capture(which, varargin)   % 'Pacing' · 'Stop'
setappdata(0,'WXX_stage', stage);  setappdata(0,'WXX_skip_run', true);
evalin('base','WXX_setup');  assignin('base','animate',1);
in = Simulink.SimulationInput(evalin('base','mdl'));   % 모델 파일은 건드리지 않는다
if ~isempty(tStop), in = in.setModelParameter('StopTime', num2str(tStop)); end
sim(in);
f = WXX_animate();                                     % 그리는 함수가 준 핸들
exportgraphics(f, fullfile(img,['WXX_anim_' which '.png']), 'Resolution', 150);
```

- **StopTime·페이싱은 `Simulink.SimulationInput` 으로만 준다.** `set_param` 으로
  모델에 쓰면 `.slx` 가 바뀌어 다음 빌드와 어긋난다
- `info` 로 조건을 함께 돌려준다 — 과업·게인·추진기 한계·벽시계. 강의자료에 그림을
  실을 때 그 숫자를 캡션에 적는다
- VRX 로 찍을 때는 끝에 **추진기마다 0 N 을 보낸다.** 플러그인은 마지막 값을
  유지하므로, 보내지 않으면 다음 실험이 달리는 배 위에서 시작한다. 선수추진기가
  있는 주차는 좌·우·**선수** 셋 전부다

## 9. VRX 연동에서 반드시 밟는 지뢰 세 개

| 증상 | 원인 | 조치 |
|---|---|---|
| 로그 첫 점이 수백 m 튄다 | **Subscribe 는 첫 메시지 전에 0 으로 채운 버스**를 낸다. 원점을 빼면 스폰 좌표만큼 튄다 | `Nav` 첫머리에 `if ex==0 && ey==0` 가드. 유효성 검사 후 쓴다 |
| 초기 선수각이 90° 로 읽힌다 | 위와 같은 첫 샘플 | `t >= 0.5 s` 샘플에서 읽는다 |
| 대조 그래프가 수백 m 로 폭주 | 두 모델의 종료 시각이 달라 `interp1` 외삽 | **겹치는 시간 구간만** 비교 |

## 10. 이격거리를 읽는 법

- 오프라인 ↔ VRX 궤적 이격은 **경로 오차가 아니라 위상 오차인 경우가 많다**
- 판별법
  - 궤적을 겹쳐 그렸을 때 **선이 겹치면** 위상 오차다
  - 임무가 끝나는 지점에서 이격이 **다시 0 으로 떨어지면** 확실하다
- 미션 단위 모델은 **이격 [m] 보다 상태 전이 시각 [s]** 을 비교하는 편이 낫다

## 11. `pkill` 을 스크립트 안에서 쓸 때

```bash
# 터미널에 직접 칠 때는 문제없다
pkill -f "vrx_gz|vrx_ros|ros_gz_bridge|gz sim|ruby|parameter_bridge"

# 스크립트/원격 셸 안에서는 자기 명령줄이 패턴에 걸려 셸이 먼저 죽는다
pkill -f "[v]rx_gz|[v]rx_ros|[r]os_gz_bridge|[g]z sim|[r]uby|[p]arameter_bridge"
```

---

## 12. WSL ROS 2 노드 + MATLAB — 2026-09-15 turtlesim 연동에서 밟은 것

| 증상 | 원인 | 조치 |
|---|---|---|
| MATLAB 에서 `ros2 topic list` 는 보이는데 `receive` 가 시간 초과 | `wsl -- bash script` 안에서 `nohup ... &` 로 띄운 노드가 **wsl.exe 가 끝난 뒤 멈춤**. 목록(발견 정보)만 남는다 | 노드는 **백그라운드 태스크로 붙잡은 wsl 세션** 안에서 띄우고 `wait` 로 유지한다 |
| 위와 같은데 `ros2 node list` 에 노드가 없고 발행자 이름이 `_NODE_NAME_UNKNOWN_` | 같은 원인 | 노드를 다시 띄운다. 먼저 WSL 안에서 `ros2 topic hz` 로 살아 있는지 본다 |
| `turtlesim/Pose은(는) 인식할 수 없는 메시지 유형` | MATLAB 에 turtlesim 메시지가 내장돼 있지 않다 (`ros2 msg list` 358종 중 없음) | 중계 노드로 `geometry_msgs/Pose2D` 로 옮겨 발행 |
| 첫 샘플 좌표가 (0,0) | Subscribe 는 첫 메시지 전 0 버스를 낸다. turtlesim 에서 (0,0) 은 실제 벽 모서리라 **값으로 거를 수 없다** | `IsNew` 를 래치해 `valid` 신호를 만든다 |
| MCP 공유 세션이 응답하지 않음 | 클라이언트가 **요청 도중 시간 초과로 끊기면** MATLAB 쪽 평가가 매듭지어지지 않는다 | 긴 작업(모델 생성 + tidy)은 MCP 로 보내지 않고 `matlab -batch` 로 돌린다. MCP 는 짧은 확인에만 |
| 결과 스크립트의 `fprintf` 가 MCP 출력에 없음 | `W02_setup` 의 `clc` 가 그 앞의 출력을 지운다 | 결과 출력은 setup **뒤에** 두거나 파일로 쓴다 |

## 13. 조건을 바꿔 가며 돌릴 때 — 모델이 읽는 변수를 바꾼다

- `WNN_setup` 이 **다른 변수에서 계산해 두는** 값이 있다. 5주차의 `beta_c = deg2rad(current_direction)` 이 그렇다
- 모델은 `beta_c` 를 읽는다. setup 을 부른 **뒤에** 스크립트에서 `current_direction` 만 바꾸면 조류 방향은 그대로다
- 2026-09-18 — 이렇게 잰 5주차 "동쪽 조류" 표 셋이 실은 북쪽 조류였다. `W05_compare` 는 `beta_c` 를 다시 계산하고 있어서 맞았다

```matlab
assignin('base','current_direction', 90);
assignin('base','beta_c', deg2rad(90));     % 모델이 실제로 읽는 쪽
```

- setup 파일에서 `= deg2rad(`, `= sqrt(`, `pinv(` 처럼 **계산으로 만들어지는 줄**을 먼저 찾는다. 그 왼쪽 변수는 스크립트에서 함께 바꿔야 한다
- 결과가 직관과 크게 다르면 (0.4 m/s 옆 조류인데 크랩각 0.5°) **모델보다 스크립트를 먼저 의심한다**

## 14. 기본값을 바꾼 뒤 — 그 모델의 숫자를 쓰는 곳을 전부 다시 잰다

- 기본값 하나(5주차 `sw_mode`)를 바꾸면 같은 모델로 잰 **모든 표**가 영향을 받는다. 조류가 없는 조건은 그대로여도 조류가 있는 조건은 바뀐다
- 옛 숫자로 검색해 본문 · 콘솔 블록 · TikZ 그림 안 표 · 지식카드 · 요약을 모두 찾는다 (스킬 `capstone-lecture-vault` 규칙 9)
- **숫자에 기대던 문장**을 다시 읽는다. 2026-09-18 에는 "조류에서 3.0 배로 벌어진다" 가 2.57 배가 되어, 결론을 "비율은 같고 벌어지는 거리가 커진다" 로 고쳐야 했다

## 15. MATLAB MCP 로 돌릴 때 — 응답에 남는 것만 쓸 수 있다

- `WNN_setup` 은 작업공간을 비우고 **모델을 자동 실행**한다. 빌드·검사만 할 때는 끈다

```matlab
setappdata(0, 'W06_skip_run', true);   % setup 이 읽고 스스로 되돌린다
o = evalc('W06_setup');
```

- setup 이 작업공간을 비우므로 **한 호출 안에서 문자열을 모으다 setup 을 다시 부르면
  그 변수가 사라진다.** `evalc` 로 받아 두고 마지막에 한 번 `disp` 한다
- `fprintf` 로 직접 찍은 것은 응답에 남지 않는다. `sprintf` 로 모아 `disp` 한다
- 출력이 길면 끝부분만 — `disp(o(strfind(o, '[대조]'):end))`
- 빌더(`parts/*.m`)를 고친 뒤에는 `bdclose('all'); clear functions` 를 먼저 부른다.
  안 부르면 옛 함수가 그대로 돈다
- **함수·리터럴 결과를 바로 색인할 수 없다** — `{'a','b'}{k}` 는 오류다. 변수에 받아 쓴다
- `evaluate_matlab_code` 안에서는 **함수를 정의할 수 없다.** MCP 도구의 `description`
  인자도 쓰지 않는다

### 15.1 조건을 바꿔 가며 여러 번 돌릴 때는 **스크래치패드 함수 파일**로

`WXX_setup` 이 base 를 비우므로 루프 변수와 모아 둔 결과가 두 번째 바퀴에서 사라진다.
한 줄짜리 MCP 호출로는 풀리지 않는다 — 스크래치패드에 `.m` **함수 파일**을 쓰고
`addpath` 한 뒤 그 함수만 부른다. 함수 작업공간은 setup 이 비우지 못한다.

```matlab
function w06_sw(stages, bows, docks)        % 스크래치패드 파일
for i = 1:numel(stages)
    setappdata(0, 'W06_stage', stages(i));  setappdata(0, 'W06_skip_run', true);
    evalin('base', 'W06_setup');
    evalin('base', sprintf('bow_on = %d;', bows(i)));   % 설정을 덮어쓴다
    o = sim(evalin('base', 'mdl'));
    fprintf('...', ...);                     % 바퀴마다 한 줄씩 찍는다
end
end
```

- 모델이 읽는 값은 **base 에서** 덮어쓴다 (`evalin('base', ...)`). 함수 안에서 만든
  변수는 모델이 보지 못한다
- 설정 묶음(`task_q` 같은 벡터)을 덮어쓸 때는 **묶음 전체를 다시 조립**한다.
  낱개만 바꾸면 모델은 옛 묶음을 읽는다

### 15.2 한 호출 안에서 밟는 문법 지뢰

6주차 접안 그림을 고치며 실제로 밟은 것만 적는다.

- **run 스크립트가 `clear` 를 부른다.** `W06_5_dock_run` 은 머리에서 작업공간을
  비우므로, **그 앞에서 정의한 내 변수도 같이 날아간다.** run 뒤에 쓸 변수는
  run **다음 줄에서 새로 정의**한다

```matlab
W06_5_dock_run                       % 여기서 base 가 비워진다
sp = 'img/W06_r5_dock.png';          % 그래서 경로는 **이 줄에서** 만든다
```

- **스크립트는 괄호 없이 부른다** — `W06_5_dock_run` 은 스크립트라
  `S = W06_5_dock_run()` 가 오류다. 값이 필요하면 base 에서 꺼낸다
- **메서드 호출 결과에 바로 색인할 수 없다** — `out.get('tout')(k)` 는 오류다.
  `T = out.get('tout'); T(k)` 로 받아 쓴다
- **`out.logsout` 이 없다.** 무엇이 실렸는지는 `out.who`, 꺼내는 것은
  `out.get('log_x_n')` 이다
- **`min([A; B])` 가 크기 오류를 낸다** — 길이가 다른 두 로그를 세로로 붙이려 들기
  때문이다. `min(min(A), min(B))` 로 쓴다

## 16. 그림을 파일로 내릴 때 — `figure(N)` 은 **옛 창**을 가리킨다

`figure('Name', ...)` 는 부를 때마다 **새 창**을 연다. 한 단계를 세 번만 고쳐 돌리면
결과 창 셋 · 추진기 창 셋 · 애니메이션 창 셋, 바탕화면에 아홉 장이 쌓인다.
그 상태에서 `exportgraphics(figure(1), ...)` 로 저장하면 **맨 처음 창**이 저장된다.
고친 내용이 그림에 안 보여 "수정이 안 먹는다" 고 오판하게 된다 (2026-10-15 에 실제로).

**창마다 이름표(Tag)를 달고, 같은 이름표를 찾아 다시 쓴다.**

```matlab
function f = W06_fig(tag, name, pos)
f = findobj(0, 'Type','figure', 'Tag',tag);
if isempty(f), f = figure('Tag',tag); else, f = f(1); clf(f); figure(f); end
set(f, 'Name',name, 'NumberTitle','off', 'Position',pos, 'Color','w');
end
```

저장할 때도 번호가 아니라 이름표로 찾는다.

```matlab
exportgraphics(findobj(0,'Type','figure','Tag','W06_anim'), path, 'Resolution',130);
```

**`gcf` 는 더 나쁘다.** 한 세션에 성능 그림 · 추진기 그림 · 실시간 화면이 함께 열려
있으므로 `gcf` 는 **마지막으로 만진 창**이다. 그리는 함수가 인자 없이 불렀을 때
자기 창 핸들을 돌려주게 만들고(`f = W06_animate();`), **그 핸들로** 저장한다.
저장 전에 `isvalid(f)` 로 창이 정말 열렸는지 보고, 안 열렸으면 `animate = 1` 이
아니라는 뜻이므로 오류를 낸다 — 빈 그림이 조용히 저장되는 것보다 낫다.

## 17. 그림 칸을 짤 때 — 두 번 실패한 길

- **세로로 긴 칸 + `axis equal` 은 쓰지 않는다.** `subplot(2,3,[1 4])` 에 `axis equal`
  을 걸면 세로 범위가 데이터의 세 배로 벌어져, 가까이 봐야 할 선석이 점만 해진다
- **인셋(`axes('Position', ...)`)은 두 번 다 축 밖으로 튀어나갔다.** 넓게 보는 칸과
  확대해 보는 칸을 **그냥 둘로 쪼개는 편**이 확실하다
- **열 줄이 넘는 범례는 어디에 두어도 무언가를 가린다.** 왼쪽 위는 도형을,
  오른쪽 아래는 항적을 가렸다. 범례는 확대 칸에 한 벌만 두고, 넓은 칸에는
  지나가는 자리 두셋에 `text` 로 글자를 직접 찍는다
- 글자 자리는 **그림의 기준 좌표**로 잡는다. 접안 그림은 선석 기준 $(a, b)$ 로 두어
  선석 방위와 접안 방향이 바뀌어도 이름표가 따라 돌게 했다
- **범례가 정착 구간을 덮지 않게 둔다.** 오차 칸은 끝에서 0 선에 붙으므로 `southeast`
  에 둔 범례가 바로 그 구간을 가린다. 제어 결과 그림에서 읽어야 하는 것이 그
  "끝에서 0 에 붙었는가" 이므로, 오차·각도 칸의 범례는 `southwest` 또는 `north`
  쪽으로 비켜 둔다. **찍은 그림을 눈으로 열어 확인한다** — 코드만 보고는 못 찾는다
  (2026-10-15 에 `W06_anim_dock.png` 에서 $\psi = 0$ 정착선이 가려져 있었다)
