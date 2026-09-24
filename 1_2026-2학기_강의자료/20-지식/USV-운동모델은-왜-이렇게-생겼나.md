---
type: knowledge
title: USV 운동모델은 왜 이렇게 생겼나
date: 2026-09-03
tags: [modeling, fossen, reference]
status: done
summary: 수업에서 빼낸 이론의 보관소 — 필요할 때 여기서 꺼내 쓴다
---

## 한 줄 요약

> 수업에서는 계수를 **주고 시작**한다. 그 계수가 어디서 왔는지 알고 싶을 때 이 문서를 본다.

> [!note] 이 카드의 성격
> 학부 캡스톤 진도에서 **의도적으로 뺀 이론**을 모아 둔 곳이다.
> 수업 시간에 다루지 않는다. Term Project 에서 필요해지면 꺼내 쓴다.
> 대학원 「센서신호처리 및 융합」에서 정식으로 다룬다.

## 무슨 일이 일어나는가

### 1. Fossen 3자유도 조종운동방정식

```
η̇ = J(ψ) ν
M ν̇ + C(ν) ν + D(ν) ν = τ
```

| 기호 | 뜻 |
|---|---|
| `η = [x, y, ψ]ᵀ` | NED 위치 (x 북, y 동) 와 선수각 |
| `ν = [u, v, r]ᵀ` | 선체 기준 속도 |
| `J(ψ)` | 회전행렬. 선체 → NED |
| `M` | 질량 + **부가질량** |
| `C(ν)` | 코리올리·구심 항 |
| `D(ν)` | 감쇠(항력). 선형 + 2차 |
| `τ = [X, Y, N]ᵀ` | 추진기가 만드는 힘·모멘트 |

- 이 수업의 오프라인 모델은 위 식의 축약형임
  - VRX 는 부가질량이 0 이라 `M` 이 대각 상수행렬
  - `C(ν)` 는 강체 항만 남음 (`+v·r`, `−u·r`)
  - `D(ν)` 는 `(Xu + Xuu│u│)` 꼴

### 2. Nomoto 1차 모델

- 조종성을 두 숫자로 줄인 것

$$
T\,\dot{r} + r = K\,\delta_{\text{rud}}
$$

- $K$ = 선회 이득, $T$ = 시상수 (3주차 $T_r$), $\delta_{\text{rud}}$ = 방향타 각 (4주차 기호. 8주차 추진기 방위각 $\delta_L$, $\delta_R$ 과 다름)
- 지그재그 시험(zig-zag test)으로 식별함
- **극배치 게인 설계**의 출발점 (헤딩 PD 이득)

$$
K_{p,\psi} = \frac{T\,\omega_n^2}{K},
\qquad
K_{d,\psi} = \frac{2\zeta\omega_n T - 1}{K}
$$

### 3. 추력배분과 도달가능 제어집합

- 추진기가 여러 개면 $\boldsymbol{\tau} = \mathbf{T}_e\,\mathbf{f}$ 를 뒤집어야 함 ($\mathbf{f}$ = 추진기별 힘 성분을 모은 확장 추력 벡터, 8주차 1-3절)
- 미지수가 더 많으면 **가중 의사역행렬** (8주차는 $\mathbf{W} = \mathbf{I}$)

$$
\mathbf{f} = \mathbf{W}^{-1}\mathbf{T}_e^{\top}\left(\mathbf{T}_e\mathbf{W}^{-1}\mathbf{T}_e^{\top}\right)^{-1}\boldsymbol{\tau}
$$

- 각도 포화가 있으면 반복 재계산 (연구실 `rpi_otter` 함수)
- **도달가능 제어집합(ACS)** — 배가 낼 수 있는 $\boldsymbol{\tau}$ 의 전부. 볼록껍질로 그림
- 5\~7주차는 **후방 고정 2추진기**라 $X$, $N$ 두 식뿐이고 2×2 역행렬이 손으로 풀림 ($F_L$, $F_R$ = 좌·우 추력)

$$
X = F_L + F_R,
\qquad
N = (F_L - F_R) \times 1.027
$$

- 8주차는 같은 2기를 **틸팅**(방위각 $\delta_L$, $\delta_R$ 포함)으로 씀 — $\mathbf{f} = [F_{xL}, F_{yL}, F_{xR}, F_{yR}]^{\top}$, $\mathbf{T}_e$ 는 3×4, 계급 3 이라 의사역행렬로 배분

### 4. 과소구동

- 고정 추진기면 독립 입력 2개(좌·우 추력)로 3자유도(전후·좌우·회전)를 다뤄야 함
- **좌우(sway)는 직접 제어할 수 없음**
- 그래서 옆으로 붙이는 접안이 어려움. 13주차의 핵심 난제
- 8주차 틸팅 방위각을 쓰면 옆 힘이 생겨 3자유도를 모두 제어함 (동적위치유지)

## 왜 중요한가 / 어디에 쓰나

| 언제 | 무엇을 |
|---|---|
| 게인이 안 잡힐 때 | Nomoto 로 `K`, `T` 를 식별해 극배치 |
| 추진기를 늘렸을 때 | 의사역행렬 배분 + ACS 로 성능 한계 확인 |
| 접안이 안 될 때 | 과소구동 때문인지, 게인 문제인지 구분 |

### 원본 문헌 (`50-원본자료/`)

| 파일 | 내용 |
|---|---|
| `Handbook Of Marine Craft Hydrodynamics And Motion Control(2nd) @.pdf` | Fossen 교과서. 3\~7장 |
| `Fossen 2024 Lecture on 2D and 3D path-following control.pdf` | LOS·ILOS 유도 |
| `1. 동역학 모델.pdf` | 교수 강의자료. 운동방정식 유도 |
| `2. USV 제어기 설계.pdf` | 선형화, 극배치, 추력배분, 접안 |
| `Construction of Simulation System for USV ... VRX and Simulink.pdf` | Jin et al. 2025. Table 1 에 파라미터 |

### 연구실 코드

| 파일 | 내용 |
|---|---|
| `WAMV_USV_Control_Allocation.m` | 배분 + ACS 그림 자동 생성 |
| `VRX_tilt4_controller_full.slx` 의 `Control allocations (RPI)` | 4추진기 반복 재계산 배분 |
| `선형제어시스템/.../MSS/` | Fossen MSS 툴박스 전체 |

## 연결

- [[오프라인-모델이-시뮬레이터와-같아야-게인이-옮겨간다]]
- [[배는-급정지하지-않는다]]
- [[W05_웨이포인트_유도_atan2와_LOS]]
- [[Simulink-모델-인벤토리]]
