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
%    4  A3_4_vrx    **가제보 연동** — 운동모델 자리에 Gazebo 를 둔다.
%                   목표(x, y, psi) 하나만 바꿔 횡이동·위치유지·접안을 다 돌린다
%                   (vrx_target 으로 고른다 — 모델은 하나뿐이다)
%    5  A3_5_tilt   **서보 틸팅 확인** — 토픽이 맞는지, 각도가 ±45 deg 안에
%                   머무는지를 배를 움직이지 않고 먼저 본다 (4단 전에 돌린다)
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

%   배분 방식 — 해의 직선 위에서 **어느 점에 앉는가**. 둘 중 하나다
%     1  pseudo-inverse                   원점에 가장 가까운 점. 가장 간단함
%     2  pseudo-inverse + null-space 보정  요구를 바꾸지 않고 각도만 한계 안으로 넣음
%     둘을 같은 과업으로 비교하는 것이 A3_4_limit_run 이다
%     실측: 2 로 두면 그대로 낼 수 있는 요구가 19.7 % 에서 25.3 % 로 늘어난다
alloc_mode = 2;

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
U_stop     = 0.05;      % 도착으로 보는 속력 한계 [m/s] — 이보다 느려야 섰다고 본다
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
T_run     = 300;        % 이 시간까지도 안 멈추면 강제로 끝난다 [s]
stop_hold = 15;         % 도착 상태를 몇 초 유지하면 끝낼 것인가 [s]
Ts_ctrl   = 0.05;

%   도착 판정 — **오차가 줄어들면 멈춘다**
%     1단은 유도부가 상수라 gate 가 끝까지 1 이다. 그대로 두면 도착한 뒤의
%     긴 정지 구간이 T_run 까지 기록에 섞인다. 그래서 위치·선수각 오차를
%     직접 보고 멈추는 상자를 1단에 둔다 (parts/addAutoStopErr.m).
%     2·3단은 유도부가 이미 도착 판정을 하므로 gate 를 보는 쪽을 쓴다.
%     2단의 도착 판정에는 **속력 조건(U_stop)** 이 함께 들어간다. 거리만 보면
%     아직 1 m/s 로 달리는 중에 판정이 서서 도착 기록이 거짓이 된다. gate 는
%     배를 세우는 장치가 아니라 다 섰음을 적는 장치다 (parts/addGuidanceStop.m).
stop_on    = 1;         % 1 = 도착하면 멈춘다,  0 = T_run 까지 끝까지 돈다
e_stop     = 0.30;      % 위치 오차 임계 [m]      — 이 안에 들어오고
epsi_stop  = 2.0;       % 선수각 오차 임계 [deg]  — 이 안에 들어온 상태가
                        %                           stop_hold 초 이어지면 끝

%% ====================================================================
%  6-1. 실시간 그림
% =====================================================================
%   모델을 돌리는 동안 창 하나가 열려 항적 · 두 추진기의 방향과 크기 ·
%   방향각이 ±45 deg 안에 있는가 · **요구한 힘과 실제로 난 힘의 차이**를
%   같이 보여준다. 그리는 쪽은 A3_animate.m 이다.
animate       = 1;      % 1 = 켬,  0 = 끔 (끄면 훨씬 빨리 돈다)
animate_every = 0.25;   % 몇 초마다 다시 그릴 것인가 [시뮬레이션 초]
boat_scale    = 3;      % 선체를 몇 배로 크게 그릴 것인가 (1 = 실제 전장 4.9 m)

%   실시간 그림 **녹화**
%     켜면 실시간 창을 그리는 그대로 동영상 한 개로 받는다. 보고서나 발표에
%     그림 여러 장을 붙이는 대신 동영상 하나를 쓸 수 있다.
%     - 녹화는 animate 가 켜져 있을 때만 된다 (그릴 창이 있어야 한다)
%     - 한 프레임은 animate_every 초마다 한 장이다. rec_fps 를
%       1/animate_every 로 두면 **실시간 속도**로 재생된다
%     - 파일은 img/ 에 단 이름으로 떨어진다 (rec_name 이 비어 있을 때)
%     - 영상은 **저장소에 올라가지 않는다** (저장소 .gitignore 가 *.mp4 를
%       제외한다). 내 PC 에만 남으므로 따로 지울 필요가 없다
%     - 기준 환경 실측 — 1단 36.7 초 실행에서 147 프레임 · 3.2 MB.
%       녹화를 켜면 벽시계 8.7 초 → 22.5 초 (화면을 떠내는 비용)
rec_on   = 1;           % 1 = 녹화,  0 = 끔 (기본). 끄면 속도 손실이 없다
rec_fps  = 2;           % 재생 프레임률 [frame/s]. 1/animate_every = 실시간
rec_name = '';          % 파일 이름. 비우면 img/<모델이름>_anim.mp4 로 정한다

%% ====================================================================
%  6-2. VRX (Gazebo) 연동 — 4·5단만 쓴다
% =====================================================================
%   4단은 운동모델 자리에 Gazebo 를 둔다. 유도부·바깥고리·안쪽고리·배분기는
%   오프라인 모델과 **글자 하나까지 같다**. 바뀌는 상자는 둘뿐이다.
%
%     오프라인   Alloc -> MotionModel (Wrench + 운동방정식 + 적분) -> 항법량
%     4단 VRX    Alloc -> CmdPublisher (토픽 넷) -> Gazebo -> PoseSubscriber
%
%   모델은 **하나**다. 과업은 목표 (x, y, psi) 하나로 갈린다 — 횡이동도 접안도
%   "그 자리에 그 자세로 서라" 의 특수한 경우일 뿐이다. 아래에서 고른다.
vrx_target = 2;         % 1 = 순수 횡이동 · 2 = 위치·선수각 유지 · 3 = 접안 목표점
                        %   목표값 자체는 3절에서 정한 것을 그대로 쓴다

%   토픽 — 2026-11-13 실측으로 확인한 것 (3주차 경량 모델 W03_vrx_lite)
%     추력   [N]   /wamv/thrusters/{left,right}/thrust
%     방향각 [rad] /wamv/thrusters/{left,right}/pos
%     넷 다 std_msgs/Float64 이고 ROS 2 쪽으로 이어져 있다
%
%   부호 — 가제보 조인트는 **반대로 돈다**
%     본 부록의 delta 는 우현 쪽이 양수다. 가제보의 pos 는 좌현 쪽이 양수다.
%     그래서 발행 직전에 -1 을 곱한다 (모델의 SignL · SignR 게인)
%     실측 — pos = -90 deg · thrust = +300 N 에서 선체 횡속도 v = -0.311 m/s
%            (우현으로 밀림) · r = +0.287 rad/s. delta = +90 deg 와 같은 꼴이다
vrx_odom_topic = '/wamv/sensors/position/ground_truth_odometry';
vrx_thr_topic  = {'/wamv/thrusters/left/thrust', '/wamv/thrusters/right/thrust'};
vrx_pos_topic  = {'/wamv/thrusters/left/pos',    '/wamv/thrusters/right/pos'};
vrx_pos_sign   = -1;    % pos = vrx_pos_sign * delta

%   가제보를 띄울 때 준 칸과 세계 이름 — 실행 스크립트가 **일시정지를 풀** 때 쓴다
%     칸(GZ_PARTITION)은 ROS_DOMAIN_ID 와 **다른 것**이다. 가제보 내부 통신은
%     칸으로 갈린다. 띄운 터미널에서 export 한 값과 같아야 그 세계가 보인다
%     멈춘 세계는 토픽도 명령도 다 받으면서 조인트만 0 으로 머문다 (_tools/vrx_play)
vrx_partition = 'a3';
vrx_world     = 'sydney_regatta';

%   가제보 서보에 보내기 전에 지령을 다듬는 두 값 — **실측으로 정한 값**
%     가제보의 조인트 위치 제어기(gz-sim-joint-position-controller-system)는
%     계단 명령에 **울렁거린다**. 2026-11-13 실측 (W03_vrx_lite)
%       계단 90 deg (-45 -> +45)        조인트가 75.7 deg 까지 넘어감
%       계단이 이어지면                 ±180 deg 조인트 한계까지 밀려남
%     변화율만 깎아도 남는 울렁거림이 있다 — 깎은 지령이 **계단참**이기 때문
%       보내는 간격 50.0 Hz (한 칸 0.90 deg)  넘어감 +0.54 deg
%       보내는 간격 12.5 Hz (한 칸 3.60 deg)  넘어감 +2.07 deg
%     한 칸을 1 차 지연으로 뭉개면 넘어감이 사라진다 (같은 조건 실측)
%       tau 0.15 s : +0.00 deg · tau 0.30 s : +0.00 deg
%     즉 **지령을 다듬는 쪽**이 제어기 게인을 건드리는 것보다 안전하다
%     (URDF 는 W03 주차 자료의 파일이므로 고치지 않는다)
%     거는 자리는 parts/addPosSign.m 한 곳이다 — 4·5단이 같이 지난다
svo_rate_deg = 45;      % 변화율 한계 [deg/s]
svo_tau_s    = 0.2;     % 계단참을 뭉개는 1 차 지연 시간상수 [s]

%   스폰 원점 — **설치마다 다르다.** 실행 스크립트(A3_4_vrx_run)가 ground truth
%   첫 샘플로 재서 덮어쓴다. 여기 값은 재지 못했을 때의 자리표시다
origin_north = 0;
origin_east  = 0;

%   5단 서보 틸팅 확인 — 각도 명령만 보내고 배는 세워 둔다
%     한 줄이 [좌현 delta, 우현 delta] 이고 각 줄을 tilt_hold 초 유지한다
%     ±60 deg 줄을 **일부러** 넣는다. 한계에 걸려 ±45 deg 로 깎이는 것을
%     눈으로 보이려는 것이다 (가제보 조인트 자체의 한계는 ±180 deg 다)
tilt_hold   = 4;        % 한 자세를 몇 초 유지하는가 [s]
tilt_thrust = 0;        % 그 동안 줄 추력 [N]. 0 이면 배가 제자리에 있다
tilt_deg    = [   0    0        % 중립
                 30   30        % 둘이 같이 우현으로 조금
                 45   45        % 한계 위
                 60   60        % 한계 밖 -> 45 로 깎여야 한다
                -60  -60        % 반대쪽 한계 밖
                  0    0        % 중립
                 45  -45        % 안쪽으로 모음
                -45   45        % 바깥으로 벌림
                  0    0 ];     % 중립으로 되돌리고 끝낸다

%% ====================================================================
%  6-3. 비교 실습이 값 하나만 바꿔 같은 과업을 다시 돌리는 자리
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
svo_rate = deg2rad(svo_rate_deg);     % 가제보 서보에 보낼 때 깎는 변화율
svo_tau  = svo_tau_s;                 % 같은 자리에서 쓰는 1 차 지연 시간상수

%   추진기 둘로 낼 수 있는 한계 — 배분식에서 바로 나온다
%     순수 횡력   추진기 한 대의 추력 = |Y| * sqrt(b^2 + L^2) / (2b)
%     순수 모멘트 추진기 한 대의 추력 = |N| / (2b)
T_per_Y = hypot(half_beam, l_thr)/(2*half_beam);   % 횡력 1 N 당 추력 [N/N]
Y_max   = F_max / T_per_Y;                          % 낼 수 있는 횡력 한계 [N]
N_max   = 2*half_beam*F_max;                        % 낼 수 있는 요 모멘트 한계 [N m]
d_sway  = atan2(half_beam, l_thr);                  % 순수 횡이동 때의 각도 [rad]

model_name = {'A3_1_crab','A3_2_pose','A3_3_dock','A3_4_vrx','A3_5_tilt'};
stage_name = {'순수 횡이동 (crabbing)','위치·선수각 유지','단계 전이 접안', ...
              'VRX 연동 — 목표 하나로 세 과업','서보 틸팅 확인'};
mdl = model_name{stage};

%   목표 고르기 — **이 세 줄이 "모델 하나로 세 과업" 의 전부다**
%     1·2·3단은 지금까지와 똑같이 움직인다 (tgt 이 stage 로 고정된다)
%     4단만 vrx_target 을 본다 — 같은 slx 로 횡이동·위치유지·접안을 돌린다
tgt = 2;                                     % 기본 — 위치·선수각 유지
if stage == 1, tgt = 1; end                  % 1단은 횡이동 고정
if stage == 4, tgt = vrx_target; end         % 4단만 고를 수 있다

switch tgt
    case 1                                   % 순수 횡이동
        x_d = crab_north;  y_d = crab_east;  psi_d = deg2rad(crab_deg);
        psi_init = psi_d;                    % 이미 목표 선수각으로 서 있다
    case 3                                   % 접안 목표점 — 4단에서만 고를 수 있다
        x_d = dock_north;  y_d = dock_east;  psi_d = deg2rad(dock_deg);
        psi_init = atan2(y_d, x_d);
    otherwise                                % 위치·선수각 유지
        x_d = hold_north;  y_d = hold_east;  psi_d = deg2rad(hold_deg);
        psi_init = atan2(y_d, x_d);          % 목표점을 향해 선다
end

%   과업 고르기 — 유도부(3단)와 그림이 함께 읽는다
%     1  한 점에 그 자세로 서 있기   2  순수 횡이동   3  접안
if tgt == 1
    task_mode = 2;
elseif stage == 3
    task_mode = 3;                           % 3단만 단계 전이 유도부를 쓴다
else
    task_mode = 1;
end

%   접안 유도부가 한 줄로 받는 묶음 — 순서가 곧 q(1..16). 6주차와 같은 꼴이다
task_q = [ hold_north;  hold_east;  deg2rad(hold_deg);
           crab_north;  crab_east;  deg2rad(crab_deg);
           dock_north;  dock_east;  deg2rad(dock_deg);
           R_dock;      L_app;      berth_side;      R_stop;
           dock_on;     R_brake;    U_berth ];

%   1·2단 유도부가 받는 목표 자세 묶음 — 순서가 곧 q(1..3)
stop_q = [x_d; y_d; psi_d];

%   1단 정지 판정이 받는 묶음 — 순서가 곧 p(1..3)
%     parts/addAutoStopErr.m 의 StopChk 가 읽는다. 각도는 rad 로 넘긴다
epsi_stop_r = deg2rad(epsi_stop);
stop_prm = [e_stop; epsi_stop_r; stop_on];

%   추진기의 기하·한계 묶음 — 순서가 곧 PRM(1..5)
%     배분기(AzAlloc)와 운동모델의 Wrench 가 **같은 묶음**을 받는다. 둘이 같은
%     기하를 써야 하므로 변수를 하나로 둔다
%     배분 방식(alloc_mode)은 이 묶음에 넣지 않는다 — 기하가 아니라 **선택**이고,
%     모델 안에서 별도 상수 블록으로 들어간다
az_prm = [half_beam; l_thr; F_max; d_max; rev_on];

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

%   5단(서보 틸팅 확인)이 받는 묶음 — 순서가 곧 q(1..3+2n)
%     q(1) 유지 시간 · q(2) 추력 · q(3) 줄 수 · 그 뒤로 [좌현;우현] 각도가 rad 로 쌓인다
%     각도는 TiltCmd 안에서 **다시 한 번** ±d_max 로 깎인다 — 표에 한계 밖 값을
%     일부러 넣어 두었으므로 그 깎임이 그림에 보인다
if stage == 5
    T_run  = tilt_hold * size(tilt_deg, 1);   % 표를 한 번 다 돌 만큼만 돈다
    animate = 0;                              % 배가 움직이지 않으므로 항적이 없다
    rec_on  = 0;
    stop_on = 0;                              % 끝까지 돈다 — 도착 판정이 없다
end
tilt_q = [tilt_hold; tilt_thrust; size(tilt_deg,1); ...
          reshape(deg2rad(tilt_deg)', [], 1)];

if rev_on > 0.5
    rev_txt = '허용';
else
    rev_txt = '금지';
end

fprintf('A3 설정 완료\n');
fprintf('  %d단  %s  —  %s\n', stage, mdl, stage_name{stage});
fprintf('  추진기 둘 · 반폭 b = %.6f m · 거리 L = %.6f m\n', half_beam, l_thr);
alloc_txt = {'pseudo-inverse', 'pseudo-inverse + null-space 보정'};
fprintf('  배분 방식 %d — %s\n', alloc_mode, alloc_txt{alloc_mode});
fprintf('  각도 한계 ±%.0f deg · 변화율 %.0f deg/s · 추력 반전 %s\n', ...
        d_max_deg, d_rate_deg, rev_txt);
fprintf('  낼 수 있는 한계 — 횡력 %.1f N · 요 모멘트 %.1f N m\n', Y_max, N_max);
if stage == 5
    fprintf('  서보 틸팅 확인 — 자세 %d 가지 × %.0f 초 = %.0f 초. 추력 %.0f N\n', ...
            size(tilt_deg,1), tilt_hold, T_run, tilt_thrust);
    fprintf('  토픽 — %s · %s\n', vrx_pos_topic{1}, vrx_pos_topic{2});
else
    fprintf('  목표 (%.1f, %.1f) m · %.1f deg\n', x_d, y_d, rad2deg(psi_d));
end
if stage >= 4
    fprintf(['  서보 지령 다듬기 — 변화율 %.0f deg/s · 1 차 지연 %.2f s\n' ...
             '    계단 명령에 가제보 서보가 울렁거려 ±%.0f deg 를 넘는다 (실측)\n'], ...
            svo_rate_deg, svo_tau_s, d_max_deg);
end
if stage == 4
    tgt_txt = {'순수 횡이동','위치·선수각 유지','접안 목표점'};
    fprintf('  VRX 목표 %d — %s (vrx_target 으로 바꾼다)\n', tgt, tgt_txt{tgt});
    fprintf('  스폰 원점 (%.1f, %.1f) m — 실행 스크립트가 재서 덮어쓴다\n', ...
            origin_north, origin_east);
end
if stop_on > 0.5
    fprintf('  정지 — 오차 %.2f m · %.1f deg 안에서 %.0f 초 유지 (최대 %.0f 초)\n', ...
            e_stop, epsi_stop, stop_hold, T_run);
else
    fprintf('  정지 끔 — T_run = %.0f 초까지 끝까지 돈다 (stop_on = 0)\n', T_run);
end
if rec_on > 0.5 && animate > 0.5
    fprintf('  녹화 켜짐 — %.0f frame/s. 끄려면 rec_on = 0\n', rec_fps);
elseif rec_on > 0.5
    fprintf('  녹화 요청됨 — 그러나 animate = 0 이라 녹화하지 않는다\n');
end

setappdata(0, 'A3_cfg_for', mdl);

%  설정만 깔고 끝낼 것인가 (InitFcn·run 스크립트가 쓴다)
if getappdata(0, 'A3_skip_run'), return; end

if animate
    fprintf('  실시간 그림 켜짐 — 새 창이 열린다. 끄려면 animate = 0\n');
end
load_system(mdl);
out = sim(mdl);
if stage <= 4                 % 5단은 A3_plot 이 읽는 24 개 신호를 내지 않는다
    A3_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
end
