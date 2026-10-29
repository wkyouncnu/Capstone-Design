---
type: plan
title: 부록 A2 — 위성지도 GCS 실습 설계 계획
date: 2026-10-29
tags: [plan, gcs, geoaxes, waypoint]
status: done
summary: 위성지도에 웨이포인트를 찍어 LOS 추종을 돌리고 실시간으로 지켜보는 부록 A2 의 설계안. 1\~5단 구현 완료
---

# 부록 A2 — 위성지도 GCS 실습 설계 계획

> [!important] 이 문서는 **설계 기록**이다 — 1\~5단 구현 완료 (2026-10-29)
> - 산출물: [[A2_위성지도_GCS]] · 스크립트 20개 (`10-주차별-강의자료/A2_gcs/`)
> - 남은 결정은 8절의 **2 · 3 · 4 · 5번**(시간 배정 · 재사용 모델 확인 · 학생 PC 툴박스 · 강의실 인터넷)
> - 문서 내 모든 수치는 2026-10-29 R2024b 에서 **실행해 얻은 값**. 추정값 없음

## 0. 목표와 범위

- 현 상태: 학생은 Simulink 안의 NED 숫자만 다룸. 지도 위에서 배를 본 경험이 없음
- 목표: 위성지도에 웨이포인트를 찍고, 그 지도 위에서 배가 움직이는 것을 실시간으로 보는 경험
- 가르치는 축 두 개
  - 위경도·고도 ↔ NED 변환의 원리와 한계
  - GCS 식 실시간 감시 화면이 어떻게 만들어지는가
- **이번 범위에서 제외**: Gazebo·VRX 연동. 오프라인 운동모델로만 구성하고 나중에 붙임
- 배치: 본문은 `10-주차별-강의자료/A2_*`, 보조 파일은 `A2_gcs/` (`A1_simulink/` 와 같은 규칙)

---

## 1. 참조 구현 분석

- 대상: `선형제어시스템/MATLAB_source/Examples/[2025] ROS2_VRX_Gazebo_Simulink` (읽기 전용 원본)
- 핵심 산출물은 `USV_display.m` 한 함수. 다섯 질문 중 네 개가 이 파일에서 답이 나옴

| 질문 | 답 | 코드 근거 |
|---|---|---|
| 좌표 변환 | `lla2ned` · `ned2lla`, `'flat'` 방식만 사용 | `USV_display.m:68,114,192,198,215,223` · `VRX_SHIFT_MINI_Full.m:113,155` |
| 지도 그리기 | 일반 `figure` 의 geoaxes + `geobasemap satellite` + `geolimits` + `geoplot`·`geoscatter` | `USV_display.m` 초기화 분기 |
| 클릭 입력 | `[lat, lon] = ginput(1)` 을 `for i = 1:7` 로 반복 | `VRX_SHIFT_MINI_Full.m` · `VRX_Autonomous_Navigation_Scripts.m` |
| 실시간 갱신 | `Interpreted MATLAB Fcn` 블록 1개 (`SampleTime=1`, `OutputDimensions=0`) → `persistent` 핸들 → `set(h,'LatitudeData',…)` → `drawnow limitrate` | `.slx` 내 SID 1151 블록 + `USV_display.m` 갱신 분기 |
| 필요 툴박스 | 7절 참조 | `detect_matlab_toolboxes` 실측 |

- `webmap`·타일 이미지·직접 구현 변환식·UTM 은 **쓰지 않음**
  - `deg2utm.m`·`utm2deg.m` 은 폴더에 있으나 실행 경로에서 호출되지 않는 잔존 파일
- 모델이 받는 입력은 Mux 9 입력 한 다발
  - `[lat lon alt | lla0(1:3) | psi | psi_d | time | wp_lat(:) | wp_lon(:)]`
  - `psi_d` 는 `Merge` 블록이 조건부 실행 미션 서브시스템 다섯 개에서 모은 값
- 배울 점과 고칠 점

| 항목 | 참조 구현 | A2 에서 |
|---|---|---|
| 상태 보관 | `persistent` + 핸들 갱신 | 그대로 따름 — 좋은 방식 |
| 초기화 | `USV_display_No_Waypoint.m` 은 매 스텝 `delete` 후 재생성 | 핸들 갱신판만 가르침. 재생성판은 **대조 예시**로만 보여 줌 |
| lat/lon 출처 | GPS 토픽에서 그대로 옴 → 모델에 `ned2lla` 가 없음 | Gazebo 가 없으므로 **운동모델 NED 를 `ned2lla` 로 올려야 함** |
| 기준점 | 호주 시드니 리가타 코스 하드코딩 | 갑천 기준점으로 교체 (8절 1번) |

---

## 2. `lla2ned` · `ned2lla` 설명 초안

> [!note] 2026-10-29 — 이 절은 **초안이며 배포본이 더 넓다**
> - 배포본 1부는 1-1 \~ 1-10 열 개 절로 재구성됨 (초안은 함수 설명 한 절 분량)
> - 추가된 것: WGS84 표준의 정의와 유도값 · 위도·경도·고도의 3차원 정의 · 측지위도와 지심위도 · 두 곡률반경 ($R_N$, $R_M$) · `'flat'`·`'ellipsoid'` 내부 수식 전개 · 왕복 변환
> - 그림 둘 추가: `assets/a2-lla-ecef.svg` (지구 + ECEF 축 + φ·λ·h), `assets/a2-ned-frame.svg` (NED 삼축 + 자오선 단면)
> - 학생이 하나씩 실행하는 예제 9 개 추가: `A2_gcs/A2_ex1_wgs84.m` \~ `A2_ex7_roundtrip.m`, `A2_ex_all.m`, `A2_ex_lla0.m`
>   - 전부 **함수**로 작성 — `A2_setup.m` 이 `clear` 로 시작하므로 스크립트면 베이스 워크스페이스를 지움
> - 손으로 쓴 수식이 MATLAB 함수와 같은지 실측 대조: `'flat'` 차 **0.000e+00 m**, `'ellipsoid'` 차 **1.137e-13 m**
>   - 따라서 배포본의 수식은 MATLAB 이 실제로 쓰는 식임 (추정 아님)
> - 아래 초안 표는 기록으로 남김. 배포본의 설명과 어긋나면 **배포본이 맞다**

- 원본 파일: `MATLAB/R2024b/toolbox/shared/coordinates/coordinates_ml/`
- 문서상 소속은 **Navigation Toolbox**

| 항목 | 내용 |
|---|---|
| 호출 | `xyzNED = lla2ned(lla, lla0, method)` · `lla = ned2lla(xyzNED, lla0, method)` |
| `lla` | `[위도 경도 고도]` — **도, 도, m**. 고도는 WGS84 타원체 기준 높이 |
| `xyzNED` | `[xNorth yEast zDown]` — **전부 m** |
| `lla0` | 지역 좌표계의 원점. `1×3` 또는 `N×3` |
| `method` | `'flat'` 또는 `'ellipsoid'` |
| 인자 개수 | `narginchk(3,3)` — **세 인자 모두 필수. 생략 시 기본값 없음** |
| 입력 모양 | `N×3`. 여러 점을 한 번에 변환 가능 |

- 유의: `z` 는 **Down** 이므로 수면 위는 음수
- 두 방식의 차이

| 방식 | 가정 | 근거 |
|---|---|---|
| `'flat'` | 지구를 평면으로 보고, z 축이 **원점에서만** 지표에 수직 | Stevens & Lewis, *Aircraft Control and Simulation* |
| `'ellipsoid'` | WGS84 타원체 | Hofmann-Wellenhof, *GPS: Theory and Practice* |

### 평면 가정이 얼마나 틀리는가 — 실측 (2026-10-29 재측정)

> [!warning] 앞선 측정은 수평 성분과 수직 성분을 섞어 적었음
> 초판 표의 값(5 km 에서 1.617 m)은 두 방식의 **수직 성분** 차가 대부분이었음.
> 아래 표가 성분을 분리한 재측정 결과이며, `A2_gcs/A2_1_refpoint_done.m` 의 출력 그대로임

- 측정 절차 — 같은 한 점을 두 방식으로 읽고 성분별로 뺌

```matlab
p  = ned2lla([L, 0, 0], lla0, 'ellipsoid');   % 타원체로 올린 점
nf = lla2ned(p, lla0, 'flat');                % 같은 점을 평면으로 내린 것
gap_h = hypot(nf(1) - L, nf(2));              % 수평 성분의 차
gap_v = abs(nf(3));                           % 수직 성분
```

- 기준점 $\text{lla}_0 = [36.3719625,\ 127.3927656,\ 0]$ (확정된 갑천 기준점)

| 원점에서 거리 | 수평 차 | 상대오차 | 수직 항 |
|---|---|---|---|
| 100 m | 0.0000 m | 0.1 ppm | 0.0008 m |
| 300 m | 0.0001 m | 0.2 ppm | 0.0071 m |
| 500 m | 0.0002 m | 0.4 ppm | 0.0197 m |
| 1 km | 0.0008 m | 0.8 ppm | 0.0786 m |
| 2 km | 0.0031 m | 1.5 ppm | 0.3146 m |
| 5 km | 0.0199 m | 4.0 ppm | 1.9661 m |

- 두 성분의 성격이 다름 — 이것이 가르칠 핵심
  - **수평 차**: 5 km 에서도 2 cm. 배가 수면 위에서만 움직이면 사실상 무시 가능
  - **수직 항**: $L^2/(2R)$ 로 커짐. 지구 곡률 그 자체임
    - `'ellipsoid'` 의 NED 는 원점 접평면의 직교좌표임
    - 수평으로 $L$ 만큼 간 점은 타원체면에서 $L^2/(2R)$ 만큼 **떠오른** 점이 됨
    - 5 km 에서 1.97 m — 지구 반지름 6 371 km 를 넣은 $L^2/(2R)$ 와 일치
- `'flat'` 왕복 오차(`ned2lla` → `lla2ned`, 북 300 m / 동 200 m)는 `3.335e-10 m` — 왕복 자체는 손실이 없음
- 기준점 고도 `alt0` 의 영향 (`'flat'`)
  - `alt0` 을 0 에서 50 m 로 바꿔도 수평 차는 **정확히 0** (N `0.000e+00` m, E `0.000e+00` m)
  - 바뀌는 것은 D 뿐 (50 m)
  - 따라서 `alt0 = 0` 은 추정이 아니라 **수평 좌표에 영향이 없음을 확인한 선택**임
- 해당 위도의 축척 (확정 기준점)
  - 위도 1° = 110 965.9 m, 경도 1° = 89 738.4 m
  - 즉 `1e-5°` 는 북 1.1097 m / 동 0.8974 m
- 결론
  - 수백 m 규모의 갑천 코스에서 `'flat'` 은 충분함 — 수평 오차 1 mm 미만
  - 본문에 쓸 한 줄: 평면 가정의 **수평** 오차는 5 km 에서도 2 cm 수준이며, 눈에 띄는 차이는 **수직 성분**에서 나옴

---

## 3. 클릭 입력 — 방법 비교와 권고

> [!important] `ginput(1)` 은 구식이 아니라 공식 지원 방식임
> - MathWorks `ginput` 문서에 지리축 예제가 있고, 반환값은 **첫째가 위도, 둘째가 경도**
> - 따라서 참조 구현은 틀린 것이 아님
> - 한계는 정확도가 아니라 **블로킹이어서 버튼과 공존할 수 없다는 점**

- 2026-10-29 R2024b 에서 네 방법을 실제로 돌려 비교

| 방법 | 동작 | 블로킹 | 수정·삭제 | 버튼과 공존 | uifigure |
|---|---|---|---|---|---|
| `ginput(n)` | 됨. `(lat, lon)` 순 | **블로킹** — 클릭 전까지 다른 조작 불가 | 불가 | 불가 | 문서에 언급 없음 |
| ROI `drawpoint`·`drawpolyline` | 됨. `Position` 이 `[lat lon]` | 비블로킹 | **끌어서 이동, Delete 로 삭제** | 가능 | 됨 |
| `WindowButtonDownFcn` + `CurrentPoint` | 됨 (조건 있음, 아래) | 비블로킹 | 직접 구현 필요 | 가능 | 됨 |
| `drawpolygon`·`drawcrosshair`·`drawassisted` | **쓰지 않음** | `Position` 이 안 맞으면 대화형 배치 대기로 들어가 세션이 멈춤 | — | — | — |

### 실측으로 드러난 세 가지

- `geoaxes` 의 `CurrentPoint` 는 **포인터 이동만으로는 갱신되지 않는다**
  - 생성 당시 값(축 좌하단)에 묶여 있음. 이전 조사에서 `[-1 -1 0]` 으로 보였던 것도 같은 이유
  - **클릭 시점에는 정확히 갱신됨**
- 기본 상호작용이 버튼 이벤트를 먹는다
  - `geoaxes` 의 `Interactions` 는 `DefaultGeographicAxesInteractionSet` (팬·줌)
  - 그대로 두면 `ButtonDownFcn` 이 **한 번도 호출되지 않음**
  - `disableDefaultInteractivity(gx)` 를 부르면 클릭이 잡히고, `enableDefaultInteractivity(gx)` 로 팬·줌이 되살아남 — 둘 다 확인
- 클릭 좌표 정확도
  - 축 안 5 지점을 Java Robot 으로 클릭해 콜백이 받은 값과 픽셀 비례 예상값을 비교
  - 최대 차 **3.3 m 북 / 7.7 m 동**. 이는 축 픽셀 사각형을 선형으로 근사한 몫이며 API 오차가 아님
  - `geolimits` 는 **종횡비 때문에 요청값보다 넓게 잡힘** — 요청 경도 `[127.372 127.388]` 이 실제 `[127.37016 127.38984]` 로 바뀜
  - 검증할 때는 반드시 `geolimits(gx)` 로 되읽은 값을 쓸 것

### 권고 — 단계마다 다른 방법

| 단계 | 방법 | 이유 |
|---|---|---|
| 기본 실습 | `ginput` | 한 줄이면 됨. 참조 구현과 같아 비교가 쉬움 |
| 수정이 필요한 단계 | ROI `drawpoint` | 잘못 찍은 점을 **끌어서 고침**. 처음부터 다시 찍지 않음 |
| 확장판 GUI | `WindowButtonDownFcn` + `CurrentPoint` + ROI | 버튼·표와 공존. 실제 GCS 와 같은 조작감 |

> [!warning] `draw*` 계열을 `Position` 없이 부르지 않는다
> - 대화형 배치 대기로 들어가면 MATLAB 이 응답을 멈춤
> - 이번 조사에서 실제로 세션이 막혀 MATLAB 을 다시 켰음
> - 학생 실습 코드에는 `Position` 을 반드시 주는 형태만 넣음

---

## 4. 실시간 감시 화면 설계

- 한 화면에 올리는 것 다섯 가지

| 요소 | 그리는 방법 | 참조 |
|---|---|---|
| 지나온 항적 | `geoscatter` 핸들에 `LatitudeData` 누적 (상한 5000 점) | `USV_display.m` 의 `MAX_TRACE` |
| 현재 위치 | `geoscatter` 마커 하나 | |
| 선수 방향으로 돌아간 선체 | NED 에서 선체 윤곽을 $\psi$ 로 회전 → `ned2lla` → `geoplot` | `drawOrUpdateUSV` |
| 실제 $\psi$ 와 LOS 지령 $\psi_{ref}$ | 길이 `scale_factor` 의 벡터 두 개 — **초록이 실제, 빨강이 지령** | `tipLLA` |
| 저장된 웨이포인트 | 마커 + 번호 라벨 + 수락반경 원 | `circle_draw` |

- 두 선을 겹쳐 그리는 것이 **선수 제어 성능을 눈에 보이게** 하는 핵심
  - 두 선이 벌어진 각이 곧 선수각 오차
  - 과도응답과 정상상태 오차를 그래프 없이 지도에서 읽게 됨
- 갱신 규칙
  - 핸들은 **첫 호출에서 한 번만 생성**하고 이후 `set` 으로 값만 바꿈
  - 매 스텝 `delete` 후 재생성하면 느려지고 깜빡임 — 참조 구현의 구버전이 그 예
  - 끝에 `drawnow limitrate` 하나

---

## 5. 단계 사다리

> [!important] 완성 파일을 먼저 주지 않는다
> - 각 단은 **혼자 돌아가는 파일 하나**
> - 앞 단의 결과가 다음 단의 입력
> - `A1_simulink/` 의 `SBn_*_todo` 와 같은 방식

| 단 | 파일 | 학생이 만드는 것 | 정상 출력 |
|---|---|---|---|
| 1 | `A2_1_refpoint.m` | 갑천 기준점 하나. `lla2ned` → `ned2lla` 왕복 | NED 세 숫자와 왕복 오차 `< 1e-9 m` 출력. 지도 없음 |
| 2 | `A2_2_map.m` | 위성지도 띄우고 기준점 찍기 | 지도 위 흰 점 하나. `geolimits` 되읽은 값 출력 |
| 3 | `A2_3_click.m` | `ginput` 으로 웨이포인트 3개 받아 NED 표로 바꾸고 `.mat` 저장 | 3행 표 (`lat lon → N E`) 와 `mission_points.mat` 생성 |
| 4 | `A2_4_live.m` | 클릭한 웨이포인트로 **실시간 주행** — 당초 4·5·6단을 합침 | 지도 위에서 배·항적이 움직이고 헤딩 명령/실제가 나란히 보임 |
| 5 | `A2_5_gui_todo.m` / `_done.m` | 버튼 GCS 화면 (6절) | 출발·일시정지·정지가 버튼으로 듣고, **주행 중에 찍은 점**으로 배가 다시 떠남 |

> [!note] 2026-10-29 구현에서 사다리를 7단 → 5단으로 줄임
> - 당초 4단(재생)은 **독립 가치가 없음** — 실시간 표시가 되면 재생은 같은 코드의 특수한 경우임
> - 당초 5단(표시 블록)과 6단(클릭→모델)은 **한 번에 해야 의미가 있음** — 표시할 것이 있어야 표시 블록을 시험할 수 있음
> - 결과: 구현된 4단 하나가 당초 4\~6단을 모두 담고, 5단이 당초 7단(GCS 화면)에 해당함

> [!important] 5단 구현에서 계획과 달라진 것 (2026-10-29)
> | 항목 | 계획 | 구현 | 이유 |
> |---|---|---|---|
> | 웨이포인트 표 | `uitable` 로 셀 편집 | **넣지 않음** | 지도 클릭 · 마지막 점 지우기 · 전부 지우기로 충분. 표 편집은 값의 원본이 두 곳이 됨 |
> | 끌어서 수정 | `drawpoint` 로 점 이동 | **넣지 않음** | `draw*` 계열은 `Position` 없이 부르면 MATLAB 이 멈춤 — 수업에서 못 씀 |
> | 팬·줌 전환 | 토글에 따라 `enable`/`disableDefaultInteractivity` | `disable` 고정 | 전환을 두면 "클릭이 안 먹는" 상태가 생김. 범위는 `A2_gui_setup` 에서 정함 |
> | 임무 길이 | 점을 늘리는 배열 | **고정 길이 버퍼 + `n_wp`** | 실행 중 배열 **길이** 변경은 `Simulink:Parameters:InvParamSetting` 으로 거부됨 |

- 재사용 대상은 `W05_simulink/W05_0_offline.slx` 와 `W05_setup.m`
  - `guidance_mode = 2` (LOS), `Delta = 10`, `R_LOS = 5`, `u_ref = 1.5`
  - 웨이포인트가 `wp_north`·`wp_east` 두 벡터로 들어감 — 클릭 결과를 그대로 꽂을 수 있는 모양
- 3단에서 `USE_SAVED` 스위치를 가르침
  - 한 번 찍어 저장하고 다시 쓰는 구조. 매 실행마다 다시 클릭하지 않음
  - 참조 구현의 `VRX_SHIFT_MINI_Full.m` 과 같은 관례

---

## 6. 확장판 — Simulink 연동 GUI

- **버튼이 있는 한 화면**에서 미션을 짜고 돌리고 지켜보는 판
- 실측으로 확인한 구성 요소 (전부 2026-10-29 R2024b)

| 요소 | 확인 결과 |
|---|---|
| `uifigure` + `uigridlayout` + `geoaxes` + `uibutton` + `uitable` | 한 창에 공존함 |
| `uifigure` 의 마우스 콜백 | `WindowButtonDownFcn`·`WindowButtonUpFcn`·`WindowButtonMotionFcn`·`WindowKeyPressFcn` 모두 있음 |
| uifigure 안 클릭에서 위경도 얻기 | `disableDefaultInteractivity` 후 `WindowButtonDownFcn` 에서 `CurrentPoint` 로 받음 — 동작 확인 |
| uifigure 안 ROI | `drawpoint` 됨. `Position` 이 `[lat lon]` |
| ROI 이벤트 | `DrawingStarted`·`DrawingFinished`·`MovingROI`·`ROIMoved`·`ROIClicked`·`DeletingROI` 등 9종. `MovingROI`·`ROIMoved` 리스너 등록 확인 |
| 시뮬레이션 제어 | `set_param(mdl,'SimulationCommand', …)` 의 `start`·`pause`·`continue`·`stop` 이 모두 상태를 바꿈 (`running` → `paused` → `running` → `stopped`) |
| 실행 중 값 전달 | 같은 크기(`1×8`)로 값 바꾸기 **성공** |
| 실행 중 크기 변경 | **거부됨** — `'Value'에 대한 설정이 유효하지 않습니다` |

> [!important] 크기를 바꿀 수 없다는 제약이 설계를 결정한다
> - 웨이포인트 배열을 **고정 길이(예: 8)** 로 두고, 실제 개수는 별도 스칼라 `n_wp` 로 넘김
> - `n_wp` 는 실행 중 변경 성공 확인
> - 유도 로직은 `n_wp` 까지만 보고 나머지는 무시
> - 이 구조가 없으면 "웨이포인트를 하나 더 찍었는데 실행 중 반영이 안 된다" 에서 막힘

- 추가 관례 (볼트 스킬 `simulink-gnc-models` 에 기록된 기확인 사항)
  - `BlockReduction` 을 **off** 로 둠 — 켜 두면 최적화로 사라진 Constant 에 `set_param` 이 거부됨
  - 캔버스 위 조작 장치는 `simulink_hmi_blocks` 라이브러리. `simulink/Dashboard/…` 로는 찾지 못함
  - 표시 함수와 모델 사이의 신호는 `setappdata(0, …)` 와 `getappdata` 로 주고받고, `StartFcn` 에서 `rmappdata` 로 지움
- 화면 구성안

| 영역 | 내용 |
|---|---|
| 왼쪽 (3/4) | 위성지도 — 항적·선체·두 선수벡터·웨이포인트 마커·수락반경 |
| 오른쪽 위 | 버튼 — `WP 추가` (토글) · `WP 비우기` · `시작` · `일시정지` · `정지` |
| 오른쪽 가운데 | `uitable` — 웨이포인트 목록 (lat, lon, N, E). 셀 편집으로 숫자 직접 수정 |
| 오른쪽 아래 | 수치 표시 — 경과시간 · $\psi$ · $\psi_{ref}$ · 횡방향 오차 · 현재 웨이포인트 번호 |

- `WP 추가` 토글의 동작
  - 켜면 `disableDefaultInteractivity` 로 바꿔 클릭이 웨이포인트로 들어감
  - 끄면 `enableDefaultInteractivity` 로 되돌려 팬·줌이 가능
  - 이 전환이 없으면 지도를 끌 수 없거나 클릭이 안 잡힘 — 둘 중 하나를 잃음
- 실제 GCS(QGroundControl·Mission Planner)와 같은 구조
  - 지도와 **표를 함께** 두고 양쪽에서 같은 웨이포인트를 고칠 수 있게 함
- 배치 제안: 확장판은 A2 본문의 마지막 절로 넣되, 분량이 커지면 **부록 A3** 로 분리 (8절 6번)

---

## 7. 측정한 툴박스

- `detect_matlab_toolboxes` 와 `which` 로 확인. 기준 환경은 MATLAB **R2024b Update 9**

| 기능 | 소속 | 비고 |
|---|---|---|
| `geoaxes`·`geobasemap`·`geolimits`·`geoplot`·`geoscatter` | **기본 MATLAB** (`toolbox/matlab/graphics/maps/`) | 추가 툴박스 불필요 |
| `uifigure`·`uibutton`·`uitable`·`uigridlayout` | **기본 MATLAB** | |
| `lla2ned`·`ned2lla` | `toolbox/shared/coordinates/` — 문서상 **Navigation Toolbox** | 학생 PC 확인 필요 (8절 4번) |
| `drawpoint`·`drawpolyline` | `toolbox/images/imuitools/` — **Image Processing Toolbox** | 확장판에서 사용 |
| `set_param`·`add_exec_event_listener`·Dashboard | **Simulink** | |
| `addCustomBasemap` | **Mapping Toolbox** | 오프라인 위성지도 대안 |

- 기준 환경에서는 위 전부 설치·라이선스 확인됨 (`license('test', …)` 가 1)
- 형제 함수 — 대안으로 적어 둘 것
  - `lla2enu`·`enu2lla` (같은 폴더)
  - `lla2flat`·`flat2lla` (Aerospace Toolbox)
  - `geodetic2ned`·`ned2geodetic` (Mapping Toolbox)
  - `latlon2local` (Automated Driving Toolbox)

> [!caution] 위성 베이스맵은 인터넷이 필요하다
> - 공식 문서: `'darkwater'` 외 모든 베이스맵은 인터넷 연결이 필요하며 `'darkwater'` 만 MATLAB 에 포함
> - Natural Earth 계열 6종은 Add-On Explorer 로 미리 받을 수 있으나 **고배율 5종(위성 포함)은 다운로드 제공 대상이 아님**
> - 즉 `'satellite'` 는 **미리 캐시해 둘 수 없음**
> - 대비책 두 가지
>   - 강의실 인터넷 확보
>   - `addCustomBasemap` 으로 MBTiles 사본을 등록 (Mapping Toolbox 필요)
> - 1·2단 예제는 `'darkwater'` 로도 돌아가게 짜서 인터넷이 끊겨도 실습이 멈추지 않게 함

---

## 8. 확인이 필요한 항목

| 번호 | 항목 | 현황 |
|---|---|---|
| 1 | **갑천 기준점 위도·경도·고도** | **해결 (2026-10-29)** — 지정 좌표를 받음. 아래 표 참조 |
| 2 | A2 의 제목·시간 배정·배포 범위 | A1 은 2회 6시간. A2 도 같은 분량으로 볼지 |
| 3 | 재사용 모델 | `W05_simulink/W05_0_offline.slx` 와 `W05_setup.m` (LOS) 로 보는 것이 맞는지 |
| 4 | 학생 PC 의 툴박스 | **Navigation Toolbox (`lla2ned`) 와 Simulink** 두 개만 필요함 (구현에서 `draw*` 계열을 쓰지 않게 됨). Navigation 이 없으면 1\~3단은 평면 변환식을 손으로 쓰는 판으로 대체 가능 |
| 5 | 강의실 인터넷 | `'satellite'` 베이스맵 사용 가능 여부 (7절 경고) |
| 6 | 확장판의 자리 | **해결 (2026-10-29)** — A2 본문의 마지막 절(§2-6)로 넣음. 분량이 한 절에 들어감 |

### 1번 항목 — 확정된 기준점

| 항목 | 값 | 출처 |
|---|---|---|
| 받은 링크 | `https://maps.app.goo.gl/bTuGoaHMM8wR1mhC7` | 지정 |
| Plus Code | `8Q8999CV+Q3X` | 링크가 가리키는 코드 |
| 위도·경도 | **36.3719625 N, 127.3927656 E** | Plus Code 셀 중심을 산술 복호 |
| 고도 `alt0` | 0 m | 수평 좌표에 영향 없음을 실측 (2절) |
| 지명 | 갑천 자전거길, 대전광역시 | Nominatim 역지오코딩 |
| 좌표 자체의 불확실성 | 약 3 m | Plus Code 한 칸 = 북 2.77 m × 동 2.80 m |

- 위성지도 확인 결과 기준점은 **갑천 강변, 교량 바로 옆**에 앉음 — 코스를 강 위로 잡기 좋음
- 더 정확한 좌표가 필요하면 현장 GPS 실측값으로 `A2_setup.m` 의 `lla0` 한 줄만 바꾸면 됨

---

## 9. 착수 후 순서

1. ~~기준점 확정 (8절 1번)~~ — **완료 (2026-10-29)**
2. ~~1\~3단 작성 후 실행해 정상 출력 채집, MD 에 실측값으로 기입~~ — 스크립트·실측 완료, MD 작성 중
3. 4\~6단 작성 후 W05 모델에 표시 블록 추가, 반경오차 재측정
4. 확장판 7단 작성
5. `bash _tools/pdf_sync.sh` 실행 → `README.md` 표 갱신 → 커밋

## 참고 자료

- 참조 구현: `선형제어시스템/MATLAB_source/Examples/[2025] ROS2_VRX_Gazebo_Simulink`
- 재사용 모델: `10-주차별-강의자료/W05_simulink/`
- 서식 기준: `10-주차별-강의자료/A1_Simulink_기초.md`
- 관련 지식카드: [[ENU와-NED를-섞으면-조용히-틀린다]] · [[측정하지-않은-성공은-성공이-아니다]]
