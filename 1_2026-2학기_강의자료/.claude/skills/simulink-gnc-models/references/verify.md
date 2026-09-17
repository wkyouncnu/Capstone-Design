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
