%% =====================================================================
%  otter_params.m — Otter 2-tilt USV 파라미터 (SCRIPT)
% ---------------------------------------------------------------------
%  두 진입점이 run() 으로 호출합니다. 함수가 아니라 스크립트이므로
%  베이스 워크스페이스에 변수를 직접 만듭니다.
%
%    MILS  MILS/Otter_colision_avoidance_scripts.m
%          -> Otter_2tilt_model_JWH_260904.slx (단일 모델)
%    HILS  HILS/Init_Otter_2tilt_integration.m
%          -> Otter_2tilt_Controller.slx        (PX4 Pixhawk 6x 탑재)
%             Otter_2tilt_Dynamics*.slx         (PC 측 플랜트 3개)
%
%  ★ 두 시험이 같은 파일을 씁니다. 값을 바꾸면 MILS·HILS 를 둘 다 다시
%    돌려 보십시오. 한쪽만 확인하고 넘어가면 나중에 두 결과가 왜 다른지
%    추적할 수 없게 됩니다.
%
%  이 파일이 정의하는 것
%    · 추진기 실측 데이터와 2차 추력 계수        k_pos, k_neg
%    · PWM 창이 실제로 허용하는 회전수·추력      n_min/n_max, Thrust_min/max
%    · PWM -> 회전수 룩업                        pwm_uniq, n_uniq
%    · 추진기 배치와 3x8 배분 행렬               B
%    · 서보(틸트) 각도·각속도 한계               alpha_max, alpha_rlim
%    · 도달 가능한 힘·모멘트 포락선              Fx_min/max, Fy_min/max,
%                                                N_min/max
%    · 실기 인터페이스 상수                      ref_lla, RC_min/max, 단위환산
%
%  이 파일이 정의하지 않는 것
%    · Ts, SampleTime, T_final  -> 진입점 §1
%    · 제어 게인, LOS_L         -> otter_gains.m
%    · u_setpoint, 초기상태 x0  -> 진입점 §4
%      (웨이포인트는 MILS 만 진입점에서 만듭니다. HILS 는 PX4 미션에서
%       position_setpoint_triplet 으로 들어옵니다.)
% =====================================================================


%% 0. 환경 / 실기 인터페이스 -------------------------------------------
% MILS 모델은 이 절의 값을 하나도 참조하지 않습니다. HILS 가 씁니다.
% 어느 블록으로 들어가는지 적어 둡니다 — 단위가 틀리면 시뮬레이션이
% 멈추지 않고 조용히 틀린 센서값을 만들어 내기 때문입니다.
%
%   ref_lla       Otter_2tilt_Controller/.../globals2locals 의 NED 원점 이자
%                 플랜트 HIL_GPS 가 lat/lon 을 만들 때 쓰는 기준점.
%                 컨트롤러와 플랜트가 같은 값을 써야 폐루프가 닫힙니다.
%   m_to_mm       HIL_GPS 고도 [m] -> [mm]
%   ms_to_cms     HIL_GPS 속도 [m/s] -> [cm/s]
%   uT_to_gauss   HIL_SENSOR 자력계 [uT] -> [gauss]
%   MAVLink_Input_Read_Size
%                 MAVLink Bridge Source 의 dataLength [byte]
%
%   RC_min/RC_max, ms2_to_mg 는 현재 어느 모델도 참조하지 않습니다.
%   (findVars 로 확인) 실기 배선용으로 남겨 둡니다.

RC_min  = 1000;                                 % RC 입력 하한 [us]
RC_max  = 2000;                                 % RC 입력 상한 [us]
ref_lla = [36.395991, 127.401794, 25.1110];     % NED 원점 (SHI Square 33)

m_to_mm     = 1000;
uT_to_gauss = 0.01;
ms2_to_mg   = (1/9.80665)*1000;
ms_to_cms   = 100;

MAVLink_Input_Read_Size = 1024;


%% 1. 추진기 실측 데이터 -----------------------------------------------
% Blue Robotics T200, 16 V. Pwm2Rpm_or_Newton.m 이 공개 데이터시트에서
% 만들어 둔 .mat 파일입니다.
%
%   n, newton         회귀용 원본 (PWM 1200~1800 구간)
%   pwm_uniq, n_uniq  중복을 제거해 단조증가로 정리한 벡터
%                     -> Simulink 플랜트 pwm2input_cmd 의 1-D Lookup Table
%                        breakpoint / table 로 그대로 들어갑니다.
%                        (MILS : USV Dynamics/pwm2input_cmd,
%                         HILS : Otter_2tilt_Dynamics/Otter USV Model/
%                                pwm2input_cmd 의 Lookup~Lookup Table3)
%
% ★ 1800 파일과 1900 파일을 섞지 마십시오.
%   1800 : pwm 1200~1800, n -300.0~+302.4   <- 이것을 씁니다
%   1900 : pwm 1100~1900, n -363.2~+370.0
%   아래 §2 의 n_min/n_max 를 1800 파일에서 뽑아 놓고 룩업만 1900 으로
%   바꾸면, 컨트롤러가 아는 회전수 한계와 플랜트가 실제로 낼 수 있는
%   회전수가 어긋납니다. HILS 진입점 §5 에 이 일치 여부를 확인하는
%   assert 가 있습니다.

load('T200_thruster_pwm_16 V_1800.mat');

% 추력 모델:  q = k * n*|n|      (n [rad/s] -> q [N])
% 정회전과 역회전의 효율이 다르므로 계수를 따로 구합니다.
% 좌변에 상수항을 두지 않아 원점(n=0 -> q=0)을 지나도록 강제합니다.
q     = n .* abs(n);
i_neg = n < 0;
i_pos = n > 0;

k_neg = q(i_neg) \ newton(i_neg);      % 역회전 계수
k_pos = q(i_pos) \ newton(i_pos);      % 정회전 계수


%% 2. PWM 창 -> 실제로 도달 가능한 회전수·추력 --------------------------
% ★ PWM_LIM 은 Simulink 모델의 스러스터 Saturation 4개
%      Autopilot/Subsystem/Saturation, Saturation1, Saturation2, Saturation3
%   에 들어 있는 값과 반드시 같아야 합니다. 둘이 어긋나면 컨트롤러가
%   낼 수 없는 힘을 명령하고, 배분기의 alloc_ok 가 거짓으로 true 를 냅니다.
%
%   2026-09-14 확인 : MILS 모델과 HILS 의 Otter_2tilt_Controller 둘 다
%   같은 경로에 [1200 1800] 이 하드코딩돼 있습니다. 이 값은 워크스페이스
%   변수가 아니라 블록에 박힌 상수이므로, PWM_LIM 을 바꾸면 모델 4곳을
%   손으로 같이 고쳐야 합니다.
%
% 여기서 데이터 최대치 max(n), max(newton) 을 그대로 쓰면 안 됩니다.
% 오토파일럿의 PWM 출력이 위 Saturation 에서 잘리므로 실제 발생 가능한
% 추력은 그보다 작고, 그 값이 포화 한계로 들어가야 폐루프가 자기 권한을
% 정확히 알게 됩니다.
%
% PWM_LIM = [1200 1800] 은 pwm_uniq 의 실제 상·하한이라 룩업 외삽이
% 생기지 않는 최댓값입니다. 안전을 위해 좁히려면 이 값만 바꾸고
% 모델의 Saturation 4개도 같이 바꾸십시오.

PWM_LIM = [1200 1800];                          % [us]

n_min = interp1(pwm_uniq, n_uniq, PWM_LIM(1));  % [rad/s]
n_max = interp1(pwm_uniq, n_uniq, PWM_LIM(2));

Thrust_min = k_neg * n_min*abs(n_min);          % [N]
Thrust_max = k_pos * n_max*abs(n_max);


%% 3. 추진기 배치 / 배분 행렬 B -----------------------------------------
% 후방 좌·우 2기만 사용하고 각각 틸팅합니다. 추진기 1·2(전방)는 비활성이며
% Simulink 배분기(rpi_otter_T34_opt_alpha_fast)도 3·4번만 계산합니다.
%
%   la  CO 에서 추진기 피벗까지의 x 거리 (후방이므로 부호는 -)
%   d   중심선에서 좌·우 추진기까지의 y 거리

la = 0.45;   d = 0.30;                 % [m]  후방 팔 길이 / 중심선 이격

% ★ lf 는 아직 CAD 로 확인된 값이 아닙니다.
%   원본 Otter 는 lf = 1.5, la = 1.0 이었는데 CAD 개정 때 la 만 0.45 로
%   갱신되고 lf 는 otter_2tilt 안에서 주석 처리된 채 남았습니다.
%   전후 대칭(lf = la)으로 가정해 둡니다. 도면에서 확인해 교체하십시오.
%   이 값이 바뀌면 4대 구성의 요 권한이 비대칭이 됩니다.
lf = 0.45;                             % [m]  ← 가정값, CAD 확인 필요

% 추진기 번호와 위치 (CO 기준, x 전진 / y 우현)
%   1 · 좌현 전방      2 · 우현 전방
%   3 · 좌현 후방      4 · 우현 후방
x1 = +lf;  y1 = -d;                    % 1번 = 좌현 전방   (현재 비활성)
x2 = +lf;  y2 = +d;                    % 2번 = 우현 전방   (현재 비활성)
x3 = -la;  y3 = -d;                    % 3번 = 좌현 후방
x4 = -la;  y4 = +d;                    % 4번 = 우현 후방

% B 는 3x8 입니다.
%   입력  f   = [f1x f1y f2x f2y f3x f3y f4x f4y]'   추진기별 x/y 분력
%         (fix = T*cos(alpha),  fiy = T*sin(alpha))
%   출력  tau = B*f = [Fx; Fy; N]
%   앞 4열이 0인 것은 추진기 1·2 를 쓰지 않기 때문입니다.
%
% ※ 2x4 로 줄이면 안 됩니다. 배분기가 B(1,5:8) 과 B(3,5:8) 을 직접
%    인덱싱하고, 플랜트 otter_2tilt 도 3x8 을 받습니다.

B = [ 0 0 0 0    1     0     1     0 ;      % Fx 행
      0 0 0 0    0     1     0     1 ;      % Fy 행
      0 0 0 0  -y3    x3   -y4    x4 ];     % N  행

% 전방 1·2번을 되살린다면 앞 4열이 이렇게 채워집니다.
% 다만 배분기 rpi_otter_T34_opt_alpha_fast 는 3·4번만 계산하므로
% 배분 알고리즘도 함께 확장해야 합니다 (부호 조합 4 -> 16 가지).
%
%   B = [  1     0     1     0     1     0     1     0 ;
%          0     1     0     1     0     1     0     1 ;
%        -y1    x1   -y2    x2   -y3    x3   -y4    x4 ];
%
% N 행에서 전방(x1=x2=+lf)과 후방(x3=x4=-la)의 f_y 계수 부호가 반대인 것에
% 주의하십시오. 뱃머리를 우현으로, 선미를 좌현으로 밀면 둘 다 +N 이 됩니다.


%% 4. 서보(틸트) 한계 ---------------------------------------------------
% alpha_max 는 4원소여야 합니다. 배분기가 alpha_max(3), alpha_max(4) 를
% 직접 참조하므로 2원소로 두면 인덱스 오류가 납니다.

alpha_max  = deg2rad(45)*[1 1 1 1];    % 추진기별 최대 틸트각 [rad]
                                       %   4원소여야 합니다 — 배분기가
                                       %   alpha_max(3), alpha_max(4) 를 참조
                                       %
                                       %   ★ HILS 컨트롤러의
                                       %     Autopilot/Subsystem/Saturation11,
                                       %     Saturation5, 6, 7 은 [-45 45] deg
                                       %     로 하드코딩돼 있습니다. 45 를
                                       %     바꾸면 그 4개도 같이 고쳐야
                                       %     합니다 (진입점 §5 가 경고).
alpha_rlim = deg2rad(90);              % 최대 틸트 각속도 [rad/s]
                                       %   Autopilot/Subsystem/Rate Limiter
                                       %   에서 +alpha_rlim / -alpha_rlim 으로 사용
                                       %   단위 확인 : Rate Limiter 는 배분기
                                       %   직후, Radians to Degrees 앞에 있어
                                       %   입력이 rad 입니다. rad/s 가 맞습니다.
T_servo    = 0.12;                     % 서보 응답 시상수 [s]
                                       %   MILS USV Dynamics/Servo dynamics 의
                                       %   1/(T_servo*s + 1) 4채널
                                       %   ※ 실측하면 이 값을 갱신하십시오.
                                       %     스러스터는 0.2 s (Thruster dynamics)
                                       %
                                       %   ※ HILS 플랜트(Otter_2tilt_Dynamics)
                                       %     에는 서보·스러스터 지연 블록이
                                       %     없어 이 값을 참조하지 않습니다.
                                       %     실기 서보의 지연은 PX4 하드웨어
                                       %     쪽에서 나오므로, MILS 와 HILS 의
                                       %     과도응답을 비교할 때 이 차이를
                                       %     감안하십시오.

theta_max  = deg2rad(45);              % 아래 포락선 계산용 스칼라
theta_min  = deg2rad(-45);


%% 5. 도달 가능한 Fx·Fy·N 포락선 ----------------------------------------
% 컨트롤러의 포화 한계로 들어갑니다.
%   Fx_min/Fx_max -> Autopilot/Controller/Surge Controller 의
%                    sat1  (MILS)  /  sat2  (HILS)
%   N_min/N_max   -> Autopilot/Controller/Heading Controller 의
%                    "stern constraint"  (MILS·HILS 공통)
%   Fy_min/Fy_max -> 지금은 소비처가 없습니다 (아래 참조)
%
% ★ Fy 는 현재 어느 모델에서도 제어되지 않습니다.
%   MILS·HILS 둘 다 Autopilot/Controller/Mux7 의 2번 입력이 Constant 0
%   으로 하드와이어돼 있어 tau_Y = 0 이 배분기로 갑니다.
%   (2026-09-14 확인. HILS 쪽 블록 이름은 Constant1.)
%
%   그래도 계산해 두는 이유
%     · 이 플랫폼이 낼 수 있는 횡력이 얼마인지가 곧 드러납니다. 후방
%       2기 틸트만으로 만드는 힘이라 Fx 권한의 70 % 남짓입니다.
%     · 나중에 sway 제어기를 붙이면(otter_gains_dp.m §3 의 Kp_y 계열)
%       그 포화 한계로 그대로 들어갈 값입니다. 그때 Fx·N 과 같은
%       방법으로 구한 값이어야 세 축의 권한을 같은 기준으로 비교할 수
%       있습니다.
%
%   ※ 세 포락선은 << 각각 따로 >> 최대화한 값입니다. Fx_max 와 Fy_max 와
%     N_max 를 동시에 낼 수는 없습니다. 같은 추력·같은 틸트각을 나눠
%     쓰기 때문입니다. 세 축 동시 도달영역이 필요하면 배분기를 직접
%     돌려 봐야 합니다.
%
% 추력 크기 T 와 틸트각 theta 를 자유변수로 두고 Fx(B의 1행),
% Fy(B의 2행), N(B의 3행)을 각각 최대·최소화합니다.
%
% ※ 예전에는 fmincon 을 단일 시작점 [T중간값, 0, T중간값, 0] 에서 돌렸는데,
%   N 의 전역해는 "한 대 정회전 -45deg + 다른 한 대 역회전 +45deg" 인
%   차동 추력이라 그 시작점의 골짜기에서 빠져나오지 못했습니다.
%   그 결과 N_max 가 21.20 으로 나와 실제 가용 권한(31.38)의 68% 만
%   헤딩 컨트롤러에 주고 있었습니다. 아래 해석해로 교체합니다.
%
% 해석 방법
%   목적함수는 추진기별로 분리됩니다.
%       row * f = sum_i  T_i * ( bx_i*cos(a_i) + by_i*sin(a_i) )
%   각 추진기의 각도항 g(a) = bx*cos(a) + by*sin(a) = R*cos(a - phi) 는
%   [-theta_max, theta_max] 안에서 최대·최소가 세 후보(양 끝, 정류점
%   phi 및 phi±pi 를 구간으로 클램프한 값) 중 하나입니다.
%   T*g 는 쌍선형이므로 박스 위의 최대는 (T 극값) x (g 극값) 네 조합 중
%   최대입니다. 추진기별 최대를 더하면 전체 최대가 됩니다 — 전역해입니다.

rows = [1 2 3];                        % B 의 Fx 행, Fy 행, N 행
lim  = zeros(numel(rows), 2);          % [min max]

for k_row = 1:numel(rows)
    lo = 0;  hi = 0;
    for i_th = 1:4                     % 추진기 1~4 (1·2는 B 열이 0이라 기여 0)
        bx = B(rows(k_row), 2*i_th-1);
        by = B(rows(k_row), 2*i_th);

        R   = hypot(bx, by);
        phi = atan2(by, bx);

        cand_a = [ theta_min, theta_max, ...
                   min(max(phi,      theta_min), theta_max), ...
                   min(max(phi + pi, theta_min), theta_max), ...
                   min(max(phi - pi, theta_min), theta_max) ];
        gv = R * cos(cand_a - phi);

        cand_T = [Thrust_max*max(gv), Thrust_max*min(gv), ...
                  Thrust_min*max(gv), Thrust_min*min(gv)];

        hi = hi + max(cand_T);
        lo = lo + min(cand_T);
    end
    lim(k_row,:) = [lo hi];
end

Fx_min = lim(1,1);   Fx_max = lim(1,2);
Fy_min = lim(2,1);   Fy_max = lim(2,2);
N_min  = lim(3,1);   N_max  = lim(3,2);

clear k_row i_th bx by R phi cand_a gv cand_T lo hi lim rows


%% 6. 요약 출력 ---------------------------------------------------------
fprintf('--- otter_params ---\n');
fprintf('  PWM 창 : %6d ~ %6d us   (모델 Saturation 과 일치해야 함)\n', ...
        PWM_LIM(1), PWM_LIM(2));
fprintf('  n      : %+8.1f ~ %+8.1f rad/s\n',  n_min,      n_max);
fprintf('  Thrust : %+8.2f ~ %+8.2f N\n',      Thrust_min, Thrust_max);
fprintf('  k_pos  : %.6f    k_neg : %.6f\n',   k_pos,      k_neg);
fprintf('  Fx     : %+8.2f ~ %+8.2f N\n',      Fx_min,     Fx_max);
fprintf('  Fy     : %+8.2f ~ %+8.2f N   (제어 안 함 — tau_Y = 0)\n', ...
                                              Fy_min,     Fy_max);
fprintf('  N      : %+8.2f ~ %+8.2f N*m\n',    N_min,      N_max);
