%% =====================================================================
%  otter_params_fixed.m — Otter 2-FIXED USV 파라미터 (SCRIPT)
% ---------------------------------------------------------------------
%  틸트 없는 고정 추진기 2기 구성입니다. otter_params_tilt.m 의 자매
%  파일이며, 두 파일의 §0~§2 는 같고 §3 이후가 다릅니다.
%
%    진입점  MILS/Otter_colision_avoidance_scripts.m  §2
%            -> run('otter_params_fixed.m')
%            -> Otter_2fixed_model_JWH_260916.slx
%
%  ★ HILS 진입점(Init_Otter_2tilt_integration.m)은 이 파일을 쓰지
%    않습니다. 그쪽은 B 가 3x8, alpha_max 가 4원소라고 assert 하므로
%    이 파일을 물리면 그 자리에서 멈춥니다. 틸트 파일을 쓰십시오.
%
%  틸트판과 무엇이 다른가
%    같다   k_pos, k_neg          추진기(T200)가 같으므로 그대로입니다
%           n_min, n_max          PWM 창이 같으므로 그대로입니다
%           Thrust_min, Thrust_max
%    다르다 B                     3x8 -> 2x2. 틸트각이 없으므로 추진기
%                                 입력이 분력 8개가 아니라 추력 2개입니다
%           Fy                    항등 0. 고정 추진기는 횡력을 못 냅니다
%           N_min, N_max          ±31.38 -> ±17.75 N*m. 틸트로 벌던
%                                 la=0.45 레버를 잃어 요 권한이 43% 줄어듭니다
%    없앴다 alpha_max, alpha_rlim, T_servo, theta_min, theta_max, la, lf
%                                 서보가 없으므로 정의하지 않습니다
%
%  이 파일이 정의하지 않는 것
%    · Ts, SampleTime, T_final  -> 진입점 §1
%    · 제어 게인, LOS_L         -> otter_gains.m
%    · u_setpoint, 초기상태 x0  -> 진입점 §4
% =====================================================================


%% 0. 환경 / 실기 인터페이스 -------------------------------------------
% MILS 모델은 이 절의 값을 하나도 참조하지 않습니다. 실기 배선용입니다.
%
%   ref_lla       NED 원점. 실기에서는 globals2locals 와 HIL_GPS 가
%                 같은 값을 써야 폐루프가 닫힙니다.
%   m_to_mm       HIL_GPS 고도 [m] -> [mm]
%   ms_to_cms     HIL_GPS 속도 [m/s] -> [cm/s]
%   uT_to_gauss   HIL_SENSOR 자력계 [uT] -> [gauss]

RC_min  = 1000;                                 % RC 입력 하한 [us]
RC_max  = 2000;                                 % RC 입력 상한 [us]
ref_lla = [36.395991, 127.401794, 25.1110];     % NED 원점 (SHI Square 33)

m_to_mm     = 1000;
uT_to_gauss = 0.01;
ms2_to_mg   = (1/9.80665)*1000;
ms_to_cms   = 100;

MAVLink_Input_Read_Size = 1024;


%% 1. 추진기 실측 데이터 -> k_pos, k_neg --------------------------------
% Blue Robotics T200, 16 V. Pwm2Rpm_or_Newton.m 이 공개 데이터시트에서
% 만들어 둔 .mat 파일입니다.
%
% ★ k_pos·k_neg 는 추진기의 성질이지 배치의 성질이 아닙니다.
%   틸트를 떼도 T200 은 그대로이므로 이 절은 틸트판과 한 글자도
%   다르지 않습니다. "고정판이니 다시 구해야 한다"는 대상이 아닙니다.
%   실제로 바뀌는 것은 §3 의 B 와 §5 의 포락선뿐입니다.
%
%   n, newton         회귀용 원본 (PWM 1200~1800 구간)
%   pwm_uniq, n_uniq  중복을 제거해 단조증가로 정리한 벡터
%                     -> 두 방향으로 모두 쓰입니다
%                        정방향 (n -> pwm)  Autopilot/Subsystem/
%                                           1-D Lookup Table, ~Table1
%                        역방향 (pwm -> n)  USV Dynamics/pwm2input_cmd/
%                                           1-D Lookup Table, ~Table1
%
% ★ 1800 파일과 1900 파일을 섞지 마십시오.
%   1800 : pwm 1200~1800, n -300.0~+302.4   <- 이것을 씁니다
%   1900 : pwm 1100~1900, n -363.2~+370.0

load('T200_thruster_pwm_16 V_1900.mat');

% 추력 모델:  q = k * n*|n|      (n [rad/s] -> q [N])
% 정회전과 역회전의 효율이 다르므로 계수를 따로 구합니다.
% 좌변에 상수항을 두지 않아 원점(n=0 -> q=0)을 지나도록 강제합니다.
q     = n .* abs(n);
i_neg = n < 0;
i_pos = n > 0;

k_neg = q(i_neg) \ newton(i_neg);      % 역회전 계수
k_pos = q(i_pos) \ newton(i_pos);      % 정회전 계수

%
%                (T200 실측)    
%     k_pos       0.000364             
%     k_neg       0.000287             
%     n_max       +302.4              
%     n_min       -300.0              
%     y_pont       0.30 (= d)          


%% 2. PWM 창 -> 실제로 도달 가능한 회전수·추력 --------------------------
% ★ PWM_LIM 은 모델의 스러스터 Saturation 과 반드시 같아야 합니다.

PWM_LIM = [1100 1900];                          % [us]

n_min = interp1(pwm_uniq, n_uniq, PWM_LIM(1));  % [rad/s]
n_max = interp1(pwm_uniq, n_uniq, PWM_LIM(2));

Thrust_min = k_neg * n_min*abs(n_min);          % [N]  추진기 1기당
Thrust_max = k_pos * n_max*abs(n_max);


%% 3. 추진기 배치 / 배분 행렬 B -----------------------------------------
% 후방 좌·우 2기, 틸트 없음. 두 추진기 모두 선체 +x 방향으로만 밉니다.
%
%   d   중심선에서 좌·우 추진기까지의 y 거리
d = 0.30;                              % [m]  중심선 이격 (조립 계획)

y1 = -d;                               % 1번 = 좌현
y2 = +d;                               % 2번 = 우현

% B 는 2x2 입니다.
%   입력  T   = [T1 T2]'        추진기별 추력 [N]
%   출력  tau = B*T = [Fx; N]
%
%   Fx 행 : 두 추진기가 그대로 더해집니다
%   N  행 : N_i = -y_i * T_i   (좌현이 세면 우현으로 돕니다, +N)
%
% ※ Fy 행이 없습니다. 고정 추진기는 횡력을 못 내므로 tau 가 3원소가
%    아니라 2원소입니다. 모델의 Autopilot/Subsystem/Selector 가
%    tau_Auto(3원소)에서 [1 3] = [Fx; N] 만 뽑아 쓰는 것과 맞습니다.

B = [   1     1  ;                     % Fx 행
      -y1   -y2 ];                     % N  행   = [d  -d]


%% 5. 도달 가능한 Fx·N 포락선 -------------------------------------------
% 컨트롤러의 포화 한계로 들어갑니다.
%
%   Fx_max = 2*Thrust_max                    둘 다 전진 최대
%   Fx_min = 2*Thrust_min                    둘 다 후진 최대
%   N_max  = d*(Thrust_max - Thrust_min)     좌현 전진 최대 + 우현 후진 최대
%   N_min  = -N_max
%
% ※ Fx 와 N 을 동시에 최대로 낼 수는 없습니다. 같은 두 추력을 나눠
%   쓰기 때문입니다. N_max 를 내는 차동 조합의 Fx 는
%   Thrust_max + Thrust_min = +7.45 N 밖에 안 됩니다.

Fx_max = 2*Thrust_max;                 % 둘 다 전진 최대
Fx_min = 2*Thrust_min;                 % 둘 다 후진 최대
Fy_max = 0;
Fy_min = 0;
N_max  = d*(Thrust_max - Thrust_min);  % 좌현 전진 최대 + 우현 후진 최대
N_min  = -N_max;


%% 6. 요약 출력 ---------------------------------------------------------
fprintf('--- otter_params_fixed (고정 추진기 2기) ---\n');
fprintf('  PWM 창 : %6d ~ %6d us   (모델 Saturation 2개와 일치해야 함)\n', ...
        PWM_LIM(1), PWM_LIM(2));
fprintf('  n      : %+8.1f ~ %+8.1f rad/s\n',  n_min,      n_max);
fprintf('  Thrust : %+8.2f ~ %+8.2f N   (1기당)\n', Thrust_min, Thrust_max);
fprintf('  k_pos  : %.6f    k_neg : %.6f\n',   k_pos,      k_neg);
fprintf('  d      : %.3f m   (요 레버)\n',      d);
fprintf('  Fx     : %+8.2f ~ %+8.2f N\n',      Fx_min,     Fx_max);
fprintf('  N      : %+8.2f ~ %+8.2f N*m   (틸트판 ±31.38 대비 %.0f%%)\n', ...
        N_min, N_max, 100*N_max/31.38);
fprintf('  Fy     :  고정 추진기 — 항등 0, 변수 없음\n');
