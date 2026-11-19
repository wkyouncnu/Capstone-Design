%% =====================================================================
%  otter_gains.m — 웨이포인트 추종 제어 게인 (MILS · HILS 공유)
% ---------------------------------------------------------------------
%  MILS  Otter_2tilt_model_JWH_260904.slx        (2026-09-04 findVars)
%  HILS  Otter_2tilt_Controller.slx              (2026-09-14 findVars)
%
%  두 모델이 실제로 참조하는 값만 둡니다.
%
%    변수        MILS  HILS   비고
%    ---------------------------------------------------------------
%    Kp_u          o     o
%    Ki_u          o     o
%    Kd_u          o     o
%    Kanti_u       o     o
%    Kd_N_u        o     -    HILS 는 계수가 블록에 박혀 있음 (§1 참조)
%    Kp_psi        o     o
%    Kd_psi        o     o
%    LOS_L         o     o
%    psi_rate      o     -    HILS 유도에 레이트 제한이 없음 (§3 참조)
%    NAV_ACC_RAD   o     -    HILS 는 PX4 가 시퀀싱 (§4 참조)
%
%  ★ 두 시험이 같은 파일을 씁니다. 값을 바꾸면 MILS·HILS 를 둘 다 다시
%    돌려 보십시오.
%
%  DP / 접안 제어기 게인은 otter_gains_dp.m 으로 분리했습니다.
%  두 모델 어느 쪽에도 연결돼 있지 않아, 여기 두면 어느 값이 실제로
%  거동에 영향을 주는지 파일만 읽어서는 알 수 없기 때문입니다.
% =====================================================================


%% 1. 서지 속도 제어 ----------------------------------------------------
%  Autopilot/Controller/Surge Controller
%
%  구조 : PID + 필터 미분 + back-calculation 안티와인드업
%         e = u_ref - u  ->  Kp*e + Ki/s*e + Kd*(필터 미분)  ->  포화
%  포화 : MILS sat1 / HILS sat2, 둘 다 [Fx_min, Fx_max]
%         (otter_params.m §5 에서 계산)

Kp_u    = 90;      % 450 -> 90    Fx_max/0.4 에서 역산
                   %   (오차 0.4 m/s 까지 선형 구간을 유지하는 값)
Ki_u    = 12;      % 0 -> 12      Ti ~ 7.5 s
                   %   적분을 켜서 정상상태 오차를 없앴습니다 (실측 0.9%)
Kd_u    = 20;      % 50 -> 20
Kd_N_u  = 100;     % 미분 필터 계수.  Transfer Fcn = [Kd_N_u 0]/[1 Kd_N_u]
                   %   순수 미분 대신 Kd_N_u*s/(s+Kd_N_u) 를 써서
                   %   고주파 잡음 증폭을 막습니다. 클수록 순수 미분에 근접.
                   %
                   %   ※ MILS 전용입니다. HILS 의 같은 자리(Transfer Fcn2)
                   %     는 Discrete Transfer Fcn 으로 바뀌면서 계수가
                   %     숫자로 박혔습니다 :
                   %        num = [ 1.960784  -1.960784 ]
                   %        den = [ 1.000000   0.960784 ]
                   %
                   %   ★ 이 계수는 Kd_N_u=100 을 << Ts = 1.0 s >> 로 Tustin
                   %     이산화한 값입니다. 그런데 블록 SampleTime 은 -1
                   %     (상속) 이라 실제로는 Ts = 0.02 s 로 돕니다.
                   %     Ts = 0.02 에서 맞는 계수는 [50 -50]/[1 0] 입니다.
                   %
                   %     결과 (2026-09-14 freqresp 확인) :
                   %        w [rad/s]   의도한 필터   HILS 실제
                   %             1.0        1.000        0.020
                   %            10.0        9.950        0.201
                   %           100.0       70.711        3.113
                   %           157.0(Nyq)  84.344       99.921
                   %     쓸모 있는 대역에서 D 항이 약 1/50 로 죽고, 대신
                   %     Nyquist 근처에서만 살아납니다 — 미분기가 아니라
                   %     잡음 증폭기로 동작합니다. 지금 HILS 의 Kd_u = 20
                   %     은 실효 0.4 정도로 보면 됩니다.
                   %
                   %     고치려면 HILS 컨트롤러의 Transfer Fcn2 를
                   %       num = [2*Kd_N_u/(2+Kd_N_u*SampleTime), ...
                   %             -2*Kd_N_u/(2+Kd_N_u*SampleTime)]
                   %       den = [1, (Kd_N_u*SampleTime-2)/(2+Kd_N_u*SampleTime)]
                   %     로 바꾸면 Ts 가 바뀌어도 따라갑니다.
                   %     ※ 이 값을 고치면 HILS 서지 응답이 달라지므로
                   %       Kd_u 를 다시 튜닝해야 합니다.
Kanti_u = 0.11;    % 0 -> 1/Kp_u  back-calculation 안티와인드업 이득
                   %   포화분 (Fx_unsat - Fx_sat) 을 적분기 입력에서 뺍니다.


%% 2. 헤딩 제어 ---------------------------------------------------------
%  Autopilot/Controller/Heading Controller
%
%  구조 : Kp*wrapToPi(psi_ref - psi) - Kd*r
%         미분항이 오차 미분이 아니라 요레이트 r 직접 피드백이라
%         psi_ref 가 튀어도 setpoint kick 이 생기지 않습니다.
%  포화 : "stern constraint" [N_min, N_max]
%
%  MILS·HILS 가 같은 구조·같은 값입니다. HILS 에서는 r 이 PX4
%  vehicle_odometry 의 yawspeed 로 들어옵니다.

Kp_psi = 15;       % 이전 22.5
Kd_psi = 5;        % 이전 7.5


%% 3. LOS 유도 ----------------------------------------------------------
%  MILS  Autopilot/Guidance/LOS_guidance        — wp 배열 + 인덱스를 받음
%  HILS  Autopilot/Guidance/Subsystem1/LOS_guidance
%        (controller/LOS_guidance_wp.m)         — wp_prev, wp_curr 두 점만
%
%  받는 인자만 다르고 유도 식은 같아서 LOS_L 을 공유합니다.
%  HILS 는 Constant5 블록으로 LOS_L 이, Constant1 로 u_setpoint 가
%  함수 입력 포트에 들어갑니다.
%
%  psi_ref = psi_path - atan(y_e / LOS_L)
%    y_e      : 경로선 기준 크로스트랙 오차 [m]
%    LOS_L    : look-ahead 거리 [m]
%  작을수록 경로에 빨리 붙지만 진동하기 쉽고, 크면 완만하게 수렴합니다.
%  경험칙으로 선체 길이의 2~5배 (이 배는 L = 1.0 m).
%
%  3.5 -> 5.0 (2026-09-04). 조류 0.5 m/s @45° 에서 요 모멘트 포화 시간이
%  0.55% -> 0.04% 로 줄었고, 완만한 조건에서도 |tau_N| 첨두가 모두
%  내려갔습니다. 대가로 크로스트랙 평균이 15~20% 늘지만 최대값은
%  거의 같습니다.
%  ※ 7.0 까지 올리면 유도가 둔해져 경로를 잃습니다 (XTE 330 m, 미완주).

LOS_L = 5.0;

%  경로 방향(psi_path) 레이트 제한 — P2-3
%  웨이포인트가 넘어가는 순간 psi_path 가 계단식으로 점프합니다
%  (이 경로에서는 최대 101.3°). 그대로 두면 헤딩 제어기가 요 모멘트를
%  즉시 포화시킵니다. 크로스트랙 항은 피드백이라 제한하지 않습니다.
%
%  블록에는 한 스텝 변화량 dpsi_max = psi_rate*Ts 로 들어갑니다.
psi_rate = deg2rad(30);    % [rad/s] — 기준 경로가 회전할 수 있는 최대 각속도
                           %   101.3° 전환에 3.4 s 소요 (1 m/s 에서 3.4 m)
                           %
                           %   ※ MILS 전용. HILS 의 LOS_guidance_wp.m 에는
                           %     레이트 제한이 없습니다. 5개 조류 시나리오
                           %     실측에서 제한이 실제로 걸린 시간이 0.02 %
                           %     뿐인데 기준 경로 지연이 XTE 를 키워서
                           %     (최대 8.65 -> 7.44 m) 뺀 것입니다.
                           %     자세한 근거는 LOS_guidance_wp.m 머리주석.


%% 4. 웨이포인트 전환 ---------------------------------------------------
%  MILS 전용입니다.
%  Estimator Output/WaypointSequencer 의 threshold 입력
%  현재 목표 웨이포인트까지 거리가 이 값 이내면 다음으로 넘어갑니다.
%  마지막 웨이포인트에서 들어오면 mission_done -> Stop Simulation.
%
%  HILS 에는 시퀀서가 없습니다. PX4 가 미션을 진행시키고, 컨트롤러는
%  position_setpoint_triplet 으로 이전/현재 두 점을, mission_result 로
%  완료 여부를 받기만 합니다. 따라서 실기 수용 반경은 이 값이 아니라
%  PX4 파라미터 NAV_ACC_RAD 가 정합니다 — 둘을 맞추려면 QGroundControl
%  에서 PX4 쪽 값을 확인하십시오. (같은 이름이지만 별개입니다.)

NAV_ACC_RAD = 3;   % [m]


%% ---------------------------------------------------------------------
%  참고 — 여기서 사라진 이름들
%
%    N            서지 미분 필터 계수의 옛 이름. Transfer Fcn 이
%                 [N 0]/[1 N] 에서 [Kd_N_u 0]/[1 Kd_N_u] 로 바뀌면서
%                 Kd_N_u 로 통합됐습니다.
%
%    threshold    WaypointSequencer 의 threshold 포트에는 NAV_ACC_RAD 가
%                 꽂혀 있어 이 이름은 아무 데도 연결되지 않았습니다.
%                 (P4-2 에서 삭제)
%
%    그 외 DP / 접안 게인   -> otter_gains_dp.m
% ---------------------------------------------------------------------
