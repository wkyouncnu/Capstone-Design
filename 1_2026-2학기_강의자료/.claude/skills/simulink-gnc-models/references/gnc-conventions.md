# GNC 규약 (MSS toolbox 기준)

원본: https://github.com/cybergalactic/MSS — `demoOtterUSVHeadingControl_P_D_Waypoint.slx` 내부를
그대로 따른다. 아래는 실제로 틀렸다가 고친 것들이다.

## 1. 유도는 `ψ_ref` 를 출력한다

침로각 `χ` 가 아니다. 크랩각 보상은 유도 안에서 하고 밖으로는 선수각 지령만 낸다.

```
χ = ψ + β,     β = atan2(v, u)
```

## 2. 속도 되먹임은 `u` (surge) 만

`U = sqrt(u²+v²)` 를 쓰면 옆으로 밀릴 때 전진 속도를 과대평가한다.

## 3. 헤딩은 P–D, 오차를 미분하지 않는다

```
tau_N = Kp · ssa(psi_ref − psi) − Kd · r
```

- `r` 을 직접 되먹임한다. 오차 미분은 지령이 계단으로 바뀔 때 튄다
- `ssa()` — smallest signed angle. ±π 경계에서 반대로 도는 것을 막는다

### 규칙 — 각도 오차는 `ssa` 를 거쳐서만 이득으로 간다

블록 순서는 고정이다. **빼기 → `ssa` → 모든 이득**. 사이에 아무것도 끼우지 않는다.

```
psi_ref ─┐
         ├─► 빼기 ─► ssa ─┬─► Kp ─────────┐
psi ─────┘                └─► Ki ─► 적분 ─┤─► 합 ─► 포화 ─► tau_N
r ───────────────────────────► Kd ────────┘
```

- 빼기와 `ssa` 는 **한 블록 안**에 둔다 — `e = atan2(sin(psi_ref-psi), cos(psi_ref-psi))`.
  밖에서 빼고 안에서 접으면 누군가 중간에 이득을 끼워 넣는다
- **적분기 앞**이 가장 중요하다. P 는 오차가 줄면 따라 줄지만 적분은 쌓인 것을 반대로 빼내야
  사라진다. 340° 가 2 초만 들어가면 `Ki=50` 에서 594 N·m — 포화 500 을 혼자 넘긴다
- D 는 `r` 에서 오므로 이 경로에 없다. 그래서 이음매에서도 D 항만은 무사하다
- `|e| ≤ 180°` 에서 `ssa` 는 항등이다. 켜도 기존 게인이 하나도 바뀌지 않는다
- 유도가 내는 `psi_ref` 는 (−180°, 180°] 이므로 몇 구간만 돌아도 이음매를 밟는다. 예외가 아니다

### 가르칠 때 — 스위치 하나로 켜고 끈다

- `HeadingErr(psi_ref, psi, use_ssa)` 로 만들고 `use_ssa` 를 워크스페이스 변수로 뺀다.
  모델은 하나, 바뀌는 것은 스위치뿐이라 대조가 깨끗하다
- 두 번 돌려 겹쳐 그린다. 칸은 **선수각(unwrap)** 과 **모멘트** 둘이면 충분하다 —
  모멘트 칸이 포화에 붙어 있는 시간이 "왜 오래 걸리는가"의 답이다
- 시나리오는 계단 **두 번**이 좋다 — 이음매를 넘지 않는 계단을 앞에 두면 두 곡선이
  거기까지 겹쳐서, 버그가 이음매에서만 나온다는 것이 같은 그림 안에서 보인다
- 캡스톤 4주차 `W04_6_wrap` 실측 (Kp=800, Kd=−400, N_max=500, 60 s, ode4/0.05.
  5 s 에 170°, 20 s 에 −170°. 지표는 둘째 계단 뒤만 잰다):
  170° → −170° 에서 **20.0° 대 340.0°**, 정착 **4.1 s 대 14.8 s**, 포화 **0 s 대 12.2 s**

## 4. 유도법칙 두 가지

```matlab
% 목표를 향해 간다 (경로를 벗어나도 모른다)
psi_ref = atan2(yk1 - pe, xk1 - pn);

% 경로를 따라간다 (LOS)
y_e     = -(pn - xk)*sin(pi_p) + (pe - yk)*cos(pi_p);
psi_ref = pi_p - atan(y_e / Delta);
```

- `Delta` 작으면 공격적, 크면 완만
- 웨이포인트 전환은 **수락반경 `R`**

## 5. 벡터필드 로이터링

```matlab
N       = sqrt((r - rd)^2 + (pc*r)^2);
r_dot   = -vd * (r - rd) / N;
rth_dot =  vd * pc * r   / N;
chi_d   = atan2(vfE, vfN);        % 식 (13)
```

- **`p_c > 0` 이 시계방향** (참고 코드의 한글 주석이 반대로 적혀 있던 사례가 있음)
- 설계식: `p_c = 4ζ_c² · v · τ_r / r_d`
- 반경 정상상태 오차: `r_ss − r_d = p_c · v · τ_eff` — `p_c` 에 **정확히 비례**한다

## 6. 차동 추진 배분 (후방 2추진기)

```
X = FL + FR
N = (FL − FR) · b        % b = half beam
```

- 역변환: `FL = X/2 + N/(2b)`, `FR = X/2 − N/(2b)`
- **포화를 먼저 의심하라.** 추종 오차가 이상하면 `F_max` 부터 확인한다
  (1.5 m/s 정속에 한쪽 244 N 이 필요한데 `F_max = 250` 이면 선회 여유가 없다)

## 7. 프로펠러·모터 모델

- Gazebo 추진기 플러그인은 **뉴턴을 직접** 받는다 (PWM 아님)
- 그래도 모델에 넣는 이유는 **응답 지연**을 재현하기 위함
  - `k = ρ·Ct·D⁴`, `F = k·n·|n|`, 1차 지연 `τ_motor`

### 7.1 역 프로펠러 법칙은 WAM-V 에 **있다** — 플러그인 **안**에 있다

"토픽이 뉴턴을 받으니 WAM-V 에는 프로펠러 법칙이 없다" 고 쓰면 틀린다.
법칙은 제어기 쪽이 아니라 플러그인 쪽에 있을 뿐이다 (2026-10-15 소스 확인).

| 어디 | 무엇 |
|---|---|
| `wamv_gazebo/urdf/thruster_layouts/wamv_gazebo_thruster_config.xacro:10-24` | 계수 선언 — `thrust_coefficient 0.004422`, `fluid_density 1000`, `propeller_diameter 0.2`, `velocity_control true` |
| 펼친 URDF `bow_wamv_target.urdf:462-473` (left) · `:484-495` (right) · `:506-517` (middle = 선수추진기) | 세 추진기가 **같은 계수**를 쓴다. `max_thrust_cmd` = 2353.53383667818 N |
| `gz-sim7  src/systems/thruster/Thruster.cc:520-521` | `OnCmdThrust` — 포화는 **추력에** 걸린다 (`clamp(cmd, cmdMin, cmdMax)`) |
| 같은 파일 `:562-584` | `ThrustToAngularVec` — `ω = sign(F·Ct)·sqrt(|F|/(ρ·Ct·D⁴))`, **역 프로펠러 법칙 본체** |
| 같은 파일 `:593-599` | `AngularVelToThrust` — `F = ρ·Ct·D⁴·|ω|·ω`. **회전수 지령 모드에서만** 쓰인다 |
| 같은 파일 `:740-756` | `velocity_control` 이면 구한 `ω` 를 `JointVelocityCmd` 로 바로 준다 |
| 같은 파일 `:770-773` | `AddWorldWrench` — 링크에 실제로 주는 힘은 **포화만 거친 지령**(`desiredThrust`)이다 |

- 그래서 시뮬링크 쪽 `Thrusters` 서브시스템은 **플러그인을 베낀 것**이지 지어낸 것이
  아니다. `F → n` 은 `:562-584` 와 같은 식이고, `n → F` 는 `:593-599` 와 같은 식이다
- 가르칠 값어치가 여기 있다 — **control allocation** (`τ → F_i`) 과 **프로펠러 법칙**
  (`F_i ↔ n_i`) 은 서로 다른 두 변환이다. 한 단계에 하나씩 보인다
- 출처 식: Fossen, *Handbook of Marine Craft Hydrodynamics and Motion Control*, p. 246
- **오프라인 모델에서 지우지 않는다.** 플러그인에 있는 것을 오프라인에서 빼면 두
  모델이 다른 물리를 돌게 된다 (교수 지시 2026-10-15)
