# VRX 로 검증하기

문서에 싣는 VRX 수치는 전부 이 절차로 뽑았다. 모델 쪽 검증(컴파일·미연결 포트·페이싱)은
`simulink-gnc-models/references/verify.md` 에 있다. 여기는 **환경과 실험 설계**를 다룬다.

---

## 1. 환경 — 틀리면 아무것도 안 보인다

| 항목 | 값 |
|---|---|
| WSL 배포판 | **`Ubuntu-22.04`** — 기본 배포판이 아니다 |
| 워크스페이스 | `/home/wkyoun/vrx_ws`, **merged install** (`install/share/vrx_gz/...`) |
| 버전 | VRX `humble` 브랜치 `2.4.0-2-gdc30ed8d` (2026-09-15 재설치 실측) |
| 스택 | ROS 2 Humble + Gazebo Garden 7.9.0 |
| **도메인** | `~/.bashrc` 의 `ROS_DOMAIN_ID=8`. **Simulink 프로필과 같아야 한다** (§1.1) |
| 스폰 위치 | **설치마다 다르다.** 데스크톱 ENU `(-532, 200)`, 9-15 노트북 `(-532, 162)` — 둘 다 2.4.0-2. `vrx_run` 이 ground truth 첫 샘플로 잰다 (§4) |

```bash
wsl -d Ubuntu-22.04 bash -lc 'source /opt/ros/humble/setup.bash && source ~/vrx_ws/install/setup.bash && ros2 topic list'
```

배포판 이름을 빼면 기본 배포판이 잡히고 토픽이 하나도 안 보인다. 매번 `-d Ubuntu-22.04`.
스크립트에서 `bash -lc` 대신 파일로 넘길 때는 `.bashrc` 가 안 읽히므로 **도메인을 직접 export** 한다.

### 기동

```bash
wsl -d Ubuntu-22.04 bash -lc 'source ~/vrx_ws/install/setup.bash && ros2 launch vrx_gz competition.launch.py world:=2023_practice/practice_2023_wayfinding0_task'
```

### ground truth 는 **런치 인자가 아니다**

> [!caution] `ground_truth_enabled:=True` 를 런치에 주면 조용히 무시된다
> `competition.launch.py` 의 인자는 `world` · `sim_mode` · `bridge_competition_topics` ·
> `config_file` · `robot` · `headless` · `urdf` · `paused` · `competition_mode` · `extra_gz_args` 뿐이다.

```bash
cp ~/vrx_ws/src/vrx/vrx_urdf/wamv_gazebo/urdf/wamv_gazebo.urdf.xacro ~/capstone_ws/wamv/w7_wamv.urdf.xacro
sed -i 's#ground_truth_enabled" default="false"#ground_truth_enabled" default="true"#' ~/capstone_ws/wamv/w7_wamv.urdf.xacro
```

그 뒤 `urdf:=$HOME/capstone_ws/wamv/w7_wamv.urdf.xacro` 로 넘긴다.
정상이면 `/wamv/sensors/position/ground_truth_odometry` 가 `map → wamv/base_link`, 약 9\~10 Hz, RELIABLE 로 나온다.

### 카메라 렌더링이 느린 그래픽에서는 엔진을 바꾼다

WSL 의 D3D12 경로(Intel 그래픽 실측)에서는 카메라 3대가 RTF 를 **0.26 %** 로 떨어뜨린다.

```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta "extra_gz_args:=--render-engine-server ogre --render-engine-gui ogre"
```

| 구성 | RTF |
|---|---|
| 월드만 | 0.99 |
| 배(카메라 제외) | 0.99 |
| 카메라 3대, `ogre2` 기본 | **0.0026** |
| 카메라 3대, `ogre` | **0.98** |

- 판정: `gz topic -e -t /stats -n 1 | grep real_time_factor`
- RTF 는 같은 월드에서도 **0.46 \~ 0.98 로 흔들린다.** 비교 실험은 연속으로 돌린다

### RTF 가 멀쩡해도 GUI 가 1 fps 일 수 있다 (2026-09-22, 같은 노트북)

- 서버만 `ogre` 로 바꾸면 RTF 0.95 인데 **GUI 는 0.9 fps** — 사용자는 "스크롤해도 반응이 없다" 로 보고함
- `--render-engine-gui ogre` 를 함께 주면 **49.6 fps**, RTF 0.92. 센서 최소(`wamv_lite.urdf`) + GUI ogre 는 RTF 0.985 · 49.5 fps
- MATLAB `W03_vrx_run` 60 초 실행 중 120 초 평균 RTF **0.986** · 49.5 fps — 알고리즘과 함께 돌려도 유지
- GUI fps 측정: `timeout 10 gz topic -e -t /gui/camera/pose | grep -c "^position"` ÷ 10 (MinimalScene 이 렌더 프레임마다 발행)
- 순간값이 아니라 **구간 평균**으로 판정한다 — `/stats` 의 sim_time·real_time 차분을 1 초 구간으로 나눠 평균·표준편차·최솟값
- `--gui-config` 로 ComponentInspector·EntityTree 를 뺀 가벼운 GUI 설정은 **효과 없음** (1.5 fps) — 병목은 패널이 아니라 3D 렌더링

---

## 2. 외란 — 있는 것과 없는 것

> [!important] 시뮬레이터에 없는 물리는 실험할 수 없다
> 있는지 없는지는 **소스에서 확인한다.** 없으면 오프라인에서만 다루고, 문서에 그 사실을 적는다.

### 해류 — VRX 에 **없다**

- 레포 전체 `grep -E 'ocean_current|water_current|currentVel|tidal|drift'` → **0건**
- `SimpleHydrodynamics.cc` 가 읽는 SDF 파라미터에 해류 항이 없다 → 항력이 **대지속도** 기준
- 조류 실험은 오프라인 `WAMV.m` 에 상대속도 3줄을 넣어서 한다

```matlab
u_r = u - V_c*cos(beta_c - psi);
v_r = v - V_c*sin(beta_c - psi);
```

동역학 항에는 `u_r, v_r`, 운동학 항에는 절대속도. 이렇게 해야 **크랩각이 눈에 보인다**.

### 바람·파랑 — **있다. world 를 고르는 방식이다**

런타임 변경 토픽·서비스가 없다 (`USVWind.cc` 는 발행만 한다). 미리 세팅된 월드를 고른다.

| world | 풍속 m/s | 파고 gain | 용도 |
|---|---|---|---|
| `2023_practice/practice_2023_wayfinding0_task` | 0.0 | 0.0 | 잔잔 (기준선) |
| `…_wayfinding1_task` | 4.0 | 0.6 | 중간 |
| `…_wayfinding2_task` | 8.0 | 0.8 | 거침 |

- 힘 모델 `F = c·v_rel·|v_rel|`, `N = −2·c_z·v_x·v_y` → **yaw 토크가 생긴다**
- 디버그 토픽 `/vrx/debug/wind/{speed,direction}` (Float32). `competition_mode:=True` 면 사라진다
- **파향은 라디안, 풍향은 도.** 강의에서 반드시 구분해 줄 것

---

## 3. 실험 설계

- 비교 실험은 **한 번에 하나만** 바꾼다 (게인 / 외란 / 필터 on-off)
- 각 조건마다 **구간을 정해 놓고** 평균을 낸다. 초기 과도구간을 포함할지 먼저 정한다
- 기록은 스크립트 하나로 묶는다 — `WXX_vrx_run.m`
  - 토픽 확인 → **RTF 자동 측정** → 페이싱 설정 → 실행 → 결과·대조 그림
  - 손으로 RTF 를 재고 페이싱을 맞추는 절차는 학생이 반드시 틀린다
- VRX 모델에도 `Animate` 블록을 넣는다 — Gazebo 창을 보지 않아도 항적이 보인다

### 시나리오는 시뮬레이션 시각으로 돌린다

벽시계로 세면 RTF 가 흔들릴 때 전환 시점이 달라진다. odometry 헤더 스탬프를 쓴다.

```matlab
t = double(m.header.stamp.sec) + double(m.header.stamp.nanosec)*1e-9;
```

---

## 4. 반드시 밟는 지뢰

| 증상 | 원인 | 조치 |
|---|---|---|
| **Simulink 만 아무것도 못 받는다** (MATLAB `ros2("topic","list")` 는 보임) | Simulink 블록은 **ROS 네트워크 프로필의 Domain ID**, `ros2*` 함수는 환경변수를 쓴다 | `getpref('ROS_Toolbox','ROS_NetworkAddress_Profiles')` 의 `DomainID` 로 `setenv('ROS_DOMAIN_ID',...)`. `W0X_vrx_run` 이 자동으로 함 |
| 주행이 경로에서 수십 m 벗어난 채 시작, 대조 궤적이 **평행하게** 떨어짐 | `origin_north`/`origin_east` 가 스폰 좌표와 다름 (설치마다 `162` 또는 `200`, 38 m 차이) | `W07~W10_vrx_run` 이 RTF 를 잴 때 첫 샘플로 원점을 덮어쓴다 (2026-09-18). 고정값을 믿지 않는다 |
| 두 번째 실험부터 결과가 엉뚱함 | 앞 실험이 끝난 **자리에서 시작** | 실험마다 VRX 재기동 |
| 첫 점이 수백 m 튄다 (약 568 m) | **Subscribe 는 첫 메시지 전에 0 으로 채운 버스**를 낸다. 원점을 빼면 스폰 좌표만큼 튄다 | `Nav` 첫머리에 `if ex==0 && ey==0` 가드 |
| 초기 선수각이 90° 또는 0° | 위와 같은 첫 샘플. `t >= 0.5 s` 로 고정해도 odom 이 늦게 오면 0° 를 읽음 (9주차 실측) | **처음으로 0 이 아닌 선수각**을 씀 (2026-09-19) |
| 대조 그래프가 수백 m 로 폭주 | 종료 시각이 달라 `interp1` 이 외삽 | **겹치는 시간 구간만** 비교 (`t <= t2(end)`) |
| 선수각 그래프가 위아래로 튄다 | 쿼터니언에서 뽑은 $\psi$ 는 항상 $[-\pi,\pi]$ | `unwrap` 으로 풀어서 저장 |
| 대지속도가 절반으로 보인다 | `PacingRate` 가 실측 RTF 와 다름 | 스크립트가 RTF 를 재서 넣는다 |
| 페이싱을 높였더니 더 느려짐 | 모델과 시뮬레이터가 같은 CPU 를 쓴다. 0.97 을 요구해도 실효 **0.787** (실측) | 잰 값을 그대로 쓴다. 올리지 않는다 |
| 부호가 반대 | ENU ↔ NED. 특히 `thrusters/*/pos` 는 **ENU 관절각** | 변환 지점에 `assert` 를 박는다 |

> [!caution] 부호는 주석으로 막지 말고 `assert` 로 막는다
> 10주차에서 배분 행렬의 요 행 부호와 방위각 부호를 각각 틀렸고, 둘 다 **오류 없이 발산**했다.
> 사람이 읽는 주석은 다음 학기에 안 읽힌다. 실행되는 검사만 남는다.
> ```matlab
> assert(abs(T_e(3,1) - thr_y) < 1e-9 && abs(T_e(3,3) + thr_y) < 1e-9, ...
>        'T_e 의 요 행 부호가 차동추진 식과 어긋납니다.');
> ```

---

## 5. 오프라인 ↔ VRX 대조

이 볼트의 표준 검증이다. 두 모델의 **계수가 같아야** 성립한다.

| 주차 | 평균 이격 09-18 | 09-19 | 판정 지표 09-19 (VRX / 오프라인) |
|---|---|---|---|
| 7 | 0.28 m | 0.95 m (같은 날 다른 실행 2.59 m) | 정착 후 \|y_e\| 0.784 / 0.702 m, u 1.501 / 1.500 m/s, 완주 205.9 / 206.7 s |
| 8 | 4.96 m | 0.77 m | 반경오차 2.265 / 2.138 m. 09-18 은 VRX 가 한 바퀴에 4 s 빨라 **위상 오차** |
| 9 | 0.83 m | 4.78 m | 반경오차 1.213 / 1.282 m. 09-19 는 VRX 가 9.5 s 빨리 끝난 **위상 오차** |
| 10 | 0.16 m | 0.16 m | 네 주차 중 최소. DP 는 위상 오차가 드러나지 않음 |

- 데스크톱, VRX 2.4.0-2, 스폰 ENU (−532, 200) 실측, 실험마다 VRX 새로 띄움. 본문 수치는 2026-09-19 실행. 이 전의 표(1.11 / 0.31 / 5.07 / 0.25)는 원점 고정값 시절
- **7\~9주차 이격은 실행마다 크게 달라짐** — 페이싱 비율(측정 RTF)과 실제 진행이 어긋난 만큼 같은 길을 다른 시각에 지남. 7주차 같은 설정 세 번: 이격 0.28 · 2.59 · 0.95 m, 정착 후 \|y_e\| 0.785 · 0.779 · 0.784 m, u 셋 다 1.501 m/s
- 판정은 이격이 아니라 **정착 후 \|y_e\| · 반경오차 · 정상상태 속도**로 함
- `W0X_vrx_run` 의 초기 선수각은 "처음으로 0 이 아닌 선수각" 을 씀 (2026-09-19 수정). 0.5 s 시점 값을 쓰면 odom 이 늦게 올 때 0° 를 읽음

> [!note] 이격은 오차가 아니라 지연인 경우가 많다
> - 궤적을 겹쳐 그렸을 때 **선이 겹치면** 위상 오차다
> - 임무 종료 지점에서 이격이 **다시 0 으로 떨어지면** 확실하다
> - 미션 단위 모델은 이격[m] 보다 **상태 전이 시각[s]** 을 비교하는 편이 낫다
> → [[궤적이-겹치면-이격은-오차가-아니라-지연이다]]

계수가 맞는지 확인하는 가장 빠른 방법 — 같은 추력을 주고 정상상태 속도를 본다.
6주차 실측: 400 N → 오프라인 `u` **1.333** / VRX **1.332** m/s. 요 방향은 7 % 벌어진다.

---

## 6. 정리 — 매번 한다

```bash
wsl -d Ubuntu-22.04 bash -lc 'pkill -f "[v]rx_gz|[v]rx_ros|[r]os_gz_bridge|[g]z sim|[r]uby|[p]arameter_bridge"'
```

- `vrx_ros` 를 빼면 `optical_frame_publisher` · `pose_tf_broadcaster` 가 고아로 남는다 (실측 12개)
- **대괄호를 씌우는 이유** — 스크립트·원격 셸 안에서는 `pkill` 자신의 명령줄이 패턴에 걸려
  셸이 먼저 죽는다. 터미널에 직접 칠 때는 문제없지만 항상 대괄호 형태를 쓴다
- 남았는지 확인

```bash
wsl -d Ubuntu-22.04 bash -lc 'pgrep -af "[g]z sim|[v]rx_gz|[v]rx_ros" | wc -l'
```
