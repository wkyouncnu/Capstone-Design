% =====================================================================
%  A3_setup.m  —  부록 A3 설정 한 자리 (아지무스 추진기 두 대)
% =====================================================================
%   전제는 6주차와 하나만 다르다. 추진기는 **원래 WAM-V 그대로 선미 좌·우 둘**
%   이고, 선수추진기가 없다. 대신 두 추진기가 **방향을 틀 수 있다** (azimuth).
%
%     6주차   추진기 셋 · 방향 고정   -> X · Y · N 셋을 각각 한 추진기가 맡음
%     부록 A3 추진기 둘 · 방향 가변   -> X · Y · N 셋을 **각도로** 만들어 냄
%
%   고치는 곳은 전부 이 파일이다. 모델을 열어 블록을 누를 일이 없다.
%
%   돌리는 법
%     >> A3_setup            %  설정을 깔고 그 단의 모델을 바로 돌린다
%     >> A3_1_crab_run       %  1단만 (권장 — 그림까지 그린다)
%
%   같은 폴더의 .slx 를 Simulink 에서 직접 Run 해도 된다. 모델의 InitFcn 이
%   자기 단의 설정을 스스로 깐다 (A3_model_init.m).

if ~getappdata(0, 'A3_skip_run'), clc; end

%% ====================================================================
%  1. 어느 단을 돌릴 것인가
% =====================================================================
%    1  A3_1_crab   순수 횡이동 — 옆걸음만. 선수각이 흔들리는지 본다
%    2  A3_2_pose   위치·선수각 유지 — 목표점에 목표 선수각으로 서서 멈춘다
%    3  A3_3_dock   단계 전이 접안 — 6주차 5단과 같은 과업
stage = 1;

st_in = getappdata(0, 'A3_stage');       % 다른 스크립트가 지정한 단이 있으면 그것
if ~isempty(st_in), stage = st_in; end

%% ====================================================================
%  2. 추진기 — 원래 WAM-V 의 선미 좌·우 둘, 방향을 틀 수 있다고 본다
% =====================================================================
%   기하는 W03_vrx_lite/wamv_lite.urdf 의 조인트 위치에서 그대로 읽은 값이다.
%     좌현 engine  xyz = (-2.373776,  1.027135, 0.318237)
%     우현 engine  xyz = (-2.373776, -1.027135, 0.318237)
%   선박 관례(x 앞, y 우현)로 옮기면 둘 다 x = -l_thr, y = ∓half_beam 이다.
half_beam = 1.027135;   % 중심선에서 추진기까지의 반폭 b [m]
l_thr     = 2.373776;   % 무게중심에서 추진기까지, 뒤쪽으로 L [m]
F_max     = 500;        % 추진기 한 대의 추력 한계 [N] (VRX 플러그인과 같음)

%   방향타(azimuth) 한계 — **설계 전제**
%     URDF 의 조인트 한계 자체는 ±pi 다. 그러나 실제 선외기를 그렇게 돌리지는
%     않으므로 본 부록은 ±45° 를 전제로 둔다. 보수적인 쪽을 전제로 두면
%     "±45° 안에서 되는가" 라는 질문에 답할 수 있다.
d_max_deg = 45;         % 각도 한계 [deg]
d_rate_deg = 573;       % 각도 변화율 한계 [deg/s] (URDF velocity 10 rad/s)

%   추력 반전을 허용하는가
%     1  허용 — 추진기가 뒤로도 민다 (VRX 플러그인은 음수 추력을 낸다)
%     0  금지 — 앞으로만 민다. 순수 횡이동이 **깨진다** (A3-4 실습)
rev_on = 1;

%   영공간 보정을 켜는가 — 각도 한계를 넘을 때 횡력을 한쪽으로 몰아 준다
%     1  켠다 — 수도인버스 + 네 줄. 요구를 바꾸지 않고 각도만 한계 안으로 넣는다
%     0  끈다 — 수도인버스 그대로 (가장 간단한 배분). 쐐기 구간에서 90 deg 를 요구한다
%     실측: 켜면 그대로 낼 수 있는 요구가 35.3 % 늘고, 깨지는 요구는 0 건
split_on = 1;

%% ====================================================================
%  3. 과업별 목표
% =====================================================================
%   1단 순수 횡이동 — 북쪽 성분을 0 으로 두어 옆으로만 가게 한다
crab_north = 0;
crab_east  = 12;
crab_deg   = 0;

%   2단 위치·선수각 유지 — 6주차 1단과 같은 목표
hold_north = 30;
hold_east  = 20;
hold_deg   = 45;

%   3단 접안 — 6주차 5단과 같은 선석
dock_north = 40;
dock_east  = 45;
dock_deg   = 0;
berth_side = +1;        % +1 이면 부두가 선석의 좌현 쪽
L_app      = 15;        % 접근점까지의 거리 [m]
R_dock     = 4;         % 단계 전환 반지름 [m]
R_stop     = 1.5;       % 도착으로 보는 반지름 [m]
R_brake    = 8;         % 이 거리 안에서 속도 지령에 (거리/R_brake) 를 곱한다 [m]
U_berth    = 0.2;       % 도착으로 보는 속도 한계 [m/s]
dock_on    = 1;

%% ====================================================================
%  4. 제어 게인 — 6주차와 **같게 둔다** (그래야 비교가 된다)
% =====================================================================
%   바깥 고리 (위치 -> 속도 지령, 비례)
Kp_x  = 0.4;
Kp_y  = 0.4;
u_max = 1.5;            % 전후 속도 지령 한계 [m/s]
v_max = 0.6;            % 횡 속도 지령 한계 [m/s] — 6주차와 같은 값

%   안쪽 고리 (속도 -> 힘, PI) · 선수각 (P-D)
Kp_u = 300;  Ki_u = 100;
Kp_v = 300;  Ki_v = 100;
Kp_psi = 400;  Kd_psi = 200;
Kb = Ki_u/Kp_u;         % 역계산 되감기 이득 (Åström: Tt = Ti)

%% ====================================================================
%  5. 운동모델 계수 — VRX 설정파일에서 읽은 값 (6주차와 같다)
% =====================================================================
m_usv = 226.5;          % 질량 [kg]
Izz   = 653;            % 요 관성 [kg m^2]
Xu    = 100;   Xuu = 150;
Yv    = 100;   Yvv = 100;
Nr    = 800;   Nrr = 800;

current_speed     = 0;  % 조류 속력 [m/s]
current_direction = 0;  % 조류가 가는 방향 [deg, NED]

%% ====================================================================
%  6. 실행 시간
% =====================================================================
T_run     = 300;
stop_hold = 15;
Ts_ctrl   = 0.05;

%% ====================================================================
%  6-1. 비교 실습이 값 하나만 바꿔 같은 과업을 다시 돌리는 자리
% =====================================================================
%   앞에서 정한 값 가운데 **이름이 같은 것**을 덮는다. 설정을 복사해 두 벌로
%   만들지 않기 위한 장치다 — 한계를 바꿔 가며 같은 과업을 돌리는 A3-4 가 쓴다.
%
%     s.rev_on = 0;  s.d_max_deg = 15;
%     setappdata(0, 'A3_override', s);   A3_setup
%
%   쓰고 나면 **반드시 비운다** (`setappdata(0,'A3_override',[])`). 남겨 두면
%   다음 실행까지 따라온다. run 스크립트가 끝에서 비운다.
ov = getappdata(0, 'A3_override');
if ~isempty(ov)
    fn = fieldnames(ov);
    for i_ov = 1:numel(fn)
        eval([fn{i_ov} ' = ov.' fn{i_ov} ';']);
    end
    fprintf('  (설정 덮어쓰기 %s)\n', strjoin(fn', ', '));
end

%% ====================================================================
%  7. 자동 계산 — 손대지 않아도 된다
% =====================================================================
beta_c = deg2rad(current_direction);
d_max  = deg2rad(d_max_deg);
d_rate = deg2rad(d_rate_deg);

%   추진기 둘로 낼 수 있는 한계 — 배분식에서 바로 나온다
%     순수 횡력   추진기 한 대의 추력 = |Y| * sqrt(b^2 + L^2) / (2b)
%     순수 모멘트 추진기 한 대의 추력 = |N| / (2b)
T_per_Y = hypot(half_beam, l_thr)/(2*half_beam);   % 횡력 1 N 당 추력 [N/N]
Y_max   = F_max / T_per_Y;                          % 낼 수 있는 횡력 한계 [N]
N_max   = 2*half_beam*F_max;                        % 낼 수 있는 요 모멘트 한계 [N m]
d_sway  = atan2(half_beam, l_thr);                  % 순수 횡이동 때의 각도 [rad]

model_name = {'A3_1_crab','A3_2_pose','A3_3_dock'};
stage_name = {'순수 횡이동 (crabbing)','위치·선수각 유지','단계 전이 접안'};
mdl = model_name{stage};

switch stage
    case 1                                   % 순수 횡이동
        x_d = crab_north;  y_d = crab_east;  psi_d = deg2rad(crab_deg);
        psi_init = psi_d;                    % 이미 목표 선수각으로 서 있다
    otherwise
        x_d = hold_north;  y_d = hold_east;  psi_d = deg2rad(hold_deg);
        psi_init = atan2(y_d, x_d);          % 목표점을 향해 선다
end

%   과업 고르기 — 유도부(3단)와 그림이 함께 읽는다
%     1  한 점에 그 자세로 서 있기   2  순수 횡이동   3  접안
if stage == 1
    task_mode = 2;
elseif stage == 2
    task_mode = 1;
else
    task_mode = 3;
end

%   접안 유도부가 한 줄로 받는 묶음 — 순서가 곧 q(1..16). 6주차와 같은 꼴이다
task_q = [ hold_north;  hold_east;  deg2rad(hold_deg);
           crab_north;  crab_east;  deg2rad(crab_deg);
           dock_north;  dock_east;  deg2rad(dock_deg);
           R_dock;      L_app;      berth_side;      R_stop;
           dock_on;     R_brake;    U_berth ];

%   1·2단 유도부가 받는 목표 자세 묶음 — 순서가 곧 q(1..3)
stop_q = [x_d; y_d; psi_d];

%   추력 배분이 받는 기하·한계 묶음 — 순서가 곧 PRM(1..6)
az_prm = [half_beam; l_thr; F_max; d_max; rev_on; split_on];

%   오프라인 운동모델이 받는 계수 묶음 — 순서가 곧 p(1..8)
%     6주차와 달리 b·l_bow 가 없다. 힘·모멘트가 배분에서 이미 완성되어 들어온다
usv_p = [m_usv; Izz; Xu; Xuu; Yv; Yvv; Nr; Nrr];

app_north = dock_north - berth_side * L_app * sin(deg2rad(dock_deg));
app_east  = dock_east  + berth_side * L_app * cos(deg2rad(dock_deg));
if stage == 3
    psi_init = atan2(app_east, app_north);
end

%   오프라인 모델 초기 상태 [u v r x_n y_n psi]'
x0 = [0.1; 0; 0; 0; 0; psi_init];

if rev_on > 0.5
    rev_txt = '허용';
else
    rev_txt = '금지';
end

fprintf('A3 설정 완료\n');
fprintf('  %d단  %s  —  %s\n', stage, mdl, stage_name{stage});
fprintf('  추진기 둘 · 반폭 b = %.6f m · 거리 L = %.6f m\n', half_beam, l_thr);
if split_on > 0.5
    spl_txt = '켬';
else
    spl_txt = '끔';
end

fprintf('  각도 한계 ±%.0f deg · 변화율 %.0f deg/s · 추력 반전 %s · 영공간 보정 %s\n', ...
        d_max_deg, d_rate_deg, rev_txt, spl_txt);
fprintf('  낼 수 있는 한계 — 횡력 %.1f N · 요 모멘트 %.1f N m\n', Y_max, N_max);
fprintf('  목표 (%.1f, %.1f) m · %.1f deg\n', x_d, y_d, rad2deg(psi_d));

setappdata(0, 'A3_cfg_for', mdl);

%  설정만 깔고 끝낼 것인가 (InitFcn·run 스크립트가 쓴다)
if getappdata(0, 'A3_skip_run'), return; end

load_system(mdl);
out = sim(mdl);
A3_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
