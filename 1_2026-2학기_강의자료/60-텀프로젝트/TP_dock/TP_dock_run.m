function S = TP_dock_run(station, phase, T)
%TP_DOCK_RUN  대회 코드가 찾은 도킹 스테이션으로 **순수 횡이동** 진입
%
%   >> TP_dock_run(1)        1번 칸 — 정렬 후 진입까지 (기본)
%   >> TP_dock_run(2, 1)     2번 칸 — 정렬만
%   >> TP_dock_run(2, 2)     2번 칸 — 진입만 (이미 정렬된 자리에서)
%
%   제어기는 **부록 A3 의 A3_4_vrx.slx 를 그대로 쓴다**
%     이 수업에서 튜닝한 WAM-V 이득(Kp_x 0.4 · Kp_u 300 · Kp_psi 400 · Kd_psi 200)
%     과 아지무스 추력 배분이 이미 들어 있다. 모델도 이득도 고치지 않는다.
%     A3_setup 의 **목표점만** A3_override 로 갈아 끼운다 — 목표를 바꾸는 것은
%     제어 로직을 바꾸는 것이 아니다.
%
%     대회 폴더(70-대회코드2026) 의 Simulink 는 **Otter** 용이다. 그쪽 이득
%     (SURGE_VEL_P 100 · HEADING_P 40 · HEADING_D 25) 은 선체가 달라 쓰지
%     않는다. 대회에서 가져오는 것은 **주고받는 데이터의 꼴 하나뿐이다.**
%
%   ROS 쪽과 주고받는 데이터 — 대회 규약과 같은 꼴
%     받는다  /tp_dock/docking_param   (px4_msgs/DockingTestParam 필드 순서)
%               [1] timestamp [us]
%               [2] psi_ned      칸 개구부가 향하는 NED 방위 [rad]
%               [3] idx_ned_x    입구점 북 [m]      [4] idx_ned_y  입구점 동 [m]
%               [5] wp_ned_x     접근점 북 [m]      [6] wp_ned_y   접근점 동 [m]
%     받는다  /tp_dock/stations_flat  칸마다 [d북 d동 설치방위 폭 깊이]
%               깊이만 쓴다 — 진입 깊이를 칸 안쪽에서 자르는 데 필요하다
%
%   입구점의 뜻 — 2026-11-19 실측에서 한 번 틀렸던 자리
%     대회 find_bays_pillars 가 내는 idx 는 간격 안쪽 깊은 점의 중앙값, 즉
%     **안쪽 벽면**이다. 대회 스테이션은 깊이 0.35 m 라 그 점이 곧 입구였다.
%     해양누리는 깊이 7.0 m 라 북 29.41 m (후벽 진실값 29.8 m) 가 나왔다 —
%     그대로 진입 목표로 주면 **후벽을 향해** 들어간다. 검출 노드가 격벽 앞면
%     기준거리로 입구를 다시 잡도록 고쳤고, 이 스크립트는 입구에서 INSET 만큼
%     안으로만 들어간다.
%     고른다  /tp_dock/select     (0-기준 칸 번호)
%     낸다    /tp_dock/for_docking_mission  (px4_msgs/ForDockingMission 꼴)
%               [1] timestamp [us]  [2] detect_on  [3..18] 예비 16 칸
%     낸다    /tp_dock/states_and_actuators  (StatesAndActuators 꼴, 20 칸)
%               [1] timestamp [us]
%               [2..7]   u v r x y psi
%               [8..10]  tau_x tau_y tau_n   (지령값)
%               [11,12]  u_ref psi_ref
%               [13..16] motor1..4   [17..20] alpha1..4 [rad]
%               A3 는 **위치 제어**라 u_ref 가 없다 — 0 으로 채운다
%               A3 는 선미 아지무스 둘이라 motor3·4 / alpha3·4 는 0
%               한 구간이 끝난 뒤 로그를 10 Hz 로 솎아 한꺼번에 흘린다
%               (대회는 제어 주기마다 실시간으로 냈다 — 필드 순서만 같다)
%
%   먼저 할 것 — 가제보와 검출 노드가 돌고 있어야 한다
%     WSL 터미널 1   export ROS_DOMAIN_ID=7 GZ_PARTITION=dockA
%                    cd ~/Capstone-Design/1_2026-2학기_강의자료/60-텀프로젝트/TP_haeyang
%                    bash run_haeyang.sh lite gui
%     WSL 터미널 2   같은 두 환경변수를 주고
%                    cd ../TP_dock && python3 tp_dock_detect.py
%     검출이 LOCKED 가 된 뒤에 이 스크립트를 돌린다.
%
%   끝낼 때 — 띄운 터미널에서 Ctrl+C. 남은 gz sim 이 메모리를 수십 GB 먹는다.
%     다른 세션의 가제보가 함께 돌면 stop_vrx.sh 를 쓰지 않는다 (남의 것까지 끈다).

    if nargin < 1 || isempty(station), station = 1; end
    if nargin < 2 || isempty(phase),   phase   = 0; end   % 0 = 정렬+진입
    if nargin < 3, T = []; end
    assert(ismember(station, [1 2 3]), 'TP_dock_run:station', ...
           '칸은 1 · 2 · 3 가운데 하나다 (서 -> 동 순서)');

    DOMAIN   = 7;
    PART     = 'dockA';
    WORLD    = 'haeyangnuri';
    ODOM     = '/wamv/sensors/position/ground_truth_odometry';
    STANDOFF = 6.0;        % 입구에서 이만큼 물러나 정렬한다 [m]
    INSET    = 3.0;        % 입구에서 이만큼만 안으로 들어간다 [m]
    BEAM     = 2.46;       % WAM-V 폭 — 횡이동이므로 이 방향이 진행 방향이다 [m]

    here = fileparts(mfilename('fullpath'));
    A3   = fullfile(here, '..', '..', '10-주차별-강의자료', 'A3_azimuth');
    assert(isfolder(A3), 'TP_dock_run:a3', 'A3_azimuth 를 찾지 못했다: %s', A3);
    addpath(fullfile(here, '..', '..', '_tools'));
    addpath(A3);  cd(A3);          % A3_4_vrx.slx 가 있는 자리에서 돈다

    %% [0] 도메인 — Simulink 블록은 ROS 네트워크 프로필, ros2* 함수는 환경변수
    setenv('ROS_DOMAIN_ID', num2str(DOMAIN));
    fprintf('\n[0] ROS_DOMAIN_ID = %s · 칸 %d\n', getenv('ROS_DOMAIN_ID'), station);

    %% [1] 검출 결과를 받는다 — 대회 규약 토픽
    node = ros2node(sprintf('/tp_dock_run_%d', randi(9999)), DOMAIN);
    selp = ros2publisher(node, '/tp_dock/select', 'std_msgs/Int32');
    send(selp, struct('data', int32(station - 1)));   % 0-기준
    %  대회 ForDockingMission 자리 — 검출을 켜 둔다는 신호
    fdm = ros2publisher(node, '/tp_dock/for_docking_mission', ...
                        'std_msgs/Float64MultiArray');
    send(fdm, fda(fdm, [now_us(node) 1 zeros(1,16)]));
    sap = ros2publisher(node, '/tp_dock/states_and_actuators', ...
                        'std_msgs/Float64MultiArray');
    pause(1.5);

    dps = ros2subscriber(node, '/tp_dock/docking_param', ...
                         'std_msgs/Float64MultiArray');
    fprintf('[1] /tp_dock/docking_param 을 기다린다 (검출이 LOCKED 여야 한다)\n');
    dp = receive(dps, 30);
    d  = double(dp.data);
    assert(numel(d) >= 6, 'TP_dock_run:dp', ...
           'docking_param 길이가 %d 다 — 세 칸이 아직 안 잡혔다', numel(d));
    psi_ned = d(2);  idx_n = d(3);  idx_e = d(4);  wp_n = d(5);  wp_e = d(6);
    fprintf('    칸 %d — 입구 (북 %.2f, 동 %.2f) · 접근점 (북 %.2f, 동 %.2f)\n', ...
            station, idx_n, idx_e, wp_n, wp_e);
    fprintf('    개구부 방위 %.1f deg (NED)\n', rad2deg(psi_ned));

    %  칸 깊이 — 평면배열에서 고른 칸 것만 꺼낸다 (칸마다 5 칸, 다섯째가 깊이)
    depth = NaN;
    try
        fls = ros2subscriber(node, '/tp_dock/stations_flat', ...
                             'std_msgs/Float32MultiArray');
        f = double(receive(fls, 10).data);
        if numel(f) >= 5 * station + 3
            depth = f(5 * station + 3);
        end
    catch ME
        fprintf('    (깊이를 못 받았다: %s)\n', ME.message);
    end
    if isfinite(depth) && depth > 0
        inset = min(INSET, max(depth - 2.5, BEAM / 2 + 0.5));
        fprintf('    칸 깊이 %.2f m → 진입 깊이 %.2f m\n', depth, inset);
    else
        inset = INSET;
        fprintf('    칸 깊이를 모른다 → 진입 깊이 %.2f m (기본값)\n', inset);
    end

    %% [2] 선체 선수각 — **부두 벽과 나란히** 세운다
    %    부두 벽은 동서로 뻗고 칸은 남쪽으로 열린다. 순수 횡이동이 되려면 선체가
    %    벽과 나란히 서야 한다 — 그래야 입구로 들어가는 방향이 선체 y 축과
    %    같아진다. 벽 방향은 개구부 방위에 ±90 deg 다. 둘 가운데 지금 선수각에
    %    가까운 쪽을 고른다 (쓸데없이 180 deg 돌지 않게)
    sb      = ros2subscriber(node, ODOM, 'nav_msgs/Odometry');
    mi      = receive(sb, 15);
    psi_now = odom_psi_ned(mi);
    cand    = [ssa_local(psi_ned + pi/2), ssa_local(psi_ned - pi/2)];
    [~, ic] = min(abs(ssa_local(cand - psi_now)));
    psi_wall = cand(ic);
    fprintf('[2] 지금 선수각 %.1f deg → 벽과 나란한 %.1f deg 로 세운다\n', ...
            rad2deg(psi_now), rad2deg(psi_wall));

    %% [3] 스폰 원점 — A3 모델의 x·y 는 **스폰 원점 기준**이다
    %    검출 노드는 월드 절대 NED 로 낸다. 그대로 목표로 주면 스폰 원점만큼
    %    (해양누리에서 북 10 m) 어긋난 채 출발한다 — 오류 없이 틀린다
    vrx_play(PART, WORLD);
    m0  = receive(sb, 15);  w = tic;
    t0  = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
    pause(10);
    m1  = receive(sb, 15);  tw = toc(w);
    t1  = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
    RTF = (t1 - t0) / tw;
    on  = m0.pose.pose.position.y;      % ENU y -> 북
    oe  = m0.pose.pose.position.x;      % ENU x -> 동
    fprintf('[3] 스폰 원점 (북 %.2f, 동 %.2f) · RTF %.3f\n', on, oe, RTF);

    %% [4] 세 목표점 — 정렬 자리 · 입구 · 진입 자리
    %    정렬 자리는 입구에서 **개구부가 향하는 쪽**(칸 밖, 남쪽)으로
    %    STANDOFF 만큼 물러난 점
    al_n = idx_n + STANDOFF * cos(psi_ned);
    al_e = idx_e + STANDOFF * sin(psi_ned);
    %    진입 자리는 입구에서 **칸 안쪽**으로 inset 만큼 들어간 점.
    %    개구부 방위는 칸 밖(남쪽)을 가리키므로 부호가 반대다
    en_n = idx_n - inset * cos(psi_ned);
    en_e = idx_e - inset * sin(psi_ned);
    fprintf(['[4] 정렬 (북 %.2f, 동 %.2f) → 입구 (북 %.2f, 동 %.2f)' ...
             ' → 진입 (북 %.2f, 동 %.2f)\n'], ...
            al_n, al_e, idx_n, idx_e, en_n, en_e);

    S = struct('station', station, 'psi_ned', psi_ned, 'psi_wall', psi_wall, ...
               'idx', [idx_n idx_e], 'wp', [wp_n wp_e], ...
               'align', [al_n al_e], 'enter', [en_n en_e], ...
               'inset', inset, 'depth', depth, 'origin', [on oe], 'RTF', RTF);

    %% [5] 단계별로 A3_4_vrx 를 돌린다 — 목표만 갈아 끼운다
    if phase == 0 || phase == 1
        S.align_out = run_a3(al_n - on, al_e - oe, psi_wall, RTF, ...
                             pick(T, 120), sprintf('정렬(칸%d)', station));
        pub_sa(node, sap, S.align_out);
    end
    if phase == 0 || phase == 2
        %  진입 — 선수각을 **정렬 때와 같은 값으로 묶어 둔다**. 목표 위치만
        %  측방으로 옮기므로 제어기가 내는 운동이 곧 순수 횡이동이다
        S.enter_out = run_a3(en_n - on, en_e - oe, psi_wall, RTF, ...
                             pick(T, 100), sprintf('진입(칸%d)', station));
        pub_sa(node, sap, S.enter_out);

        %  진입 결과 — 숫자로 남긴다 (추정하지 않는다)
        o = S.enter_out;
        S.err_n   = (en_n - on) - o.log_x_n.Data(end);
        S.err_e   = (en_e - oe) - o.log_y_n.Data(end);
        S.err_deg = rad2deg(ssa_local(psi_wall - o.log_psi.Data(end)));
        S.v_max   = max(abs(o.log_v.Data));
        S.u_max   = max(abs(o.log_u.Data));
        fprintf(['\n[결과 칸%d] 잔차 북 %+.2f m · 동 %+.2f m · 선수각 %+.1f deg\n' ...
                 '           최대 횡속 %.2f m/s · 최대 전후속 %.2f m/s' ...
                 '  (순수 횡이동이면 전후속이 작아야 한다)\n'], ...
                station, S.err_n, S.err_e, S.err_deg, S.v_max, S.u_max);
    end

    send(fdm, fda(fdm, [now_us(node) 0 zeros(1,16)]));   % detect_on 내림
    setappdata(0, 'A3_override', []);
    setappdata(0, 'A3_skip_run', []);
    setappdata(0, 'A3_stage', []);
    fprintf('\n끝 — 목표를 되돌렸다 (A3_override 비움)\n');
end

% ======================================================================
function out = run_a3(x_d, y_d, psi_d, RTF, T, tag)
%RUN_A3  A3_4_vrx.slx 를 목표점만 바꿔서 한 번 돌린다. 모델은 고치지 않는다
    fprintf('\n--- %s : 목표 (x %.2f, y %.2f, psi %.1f deg) · %d 초 ---\n', ...
            tag, x_d, y_d, rad2deg(psi_d), T);
    ov = struct('vrx_target', 3, ...            % 3 = 접안 목표점 자리를 쓴다
                'dock_north', x_d, 'dock_east', y_d, ...
                'dock_deg', rad2deg(psi_d), ...
                'vrx_partition', 'dockA', 'vrx_world', 'haeyangnuri', ...
                'T_run', T, 'animate', 1, 'animate_every', 0.5, 'rec_on', 0);
    setappdata(0, 'A3_stage', 4);
    setappdata(0, 'A3_skip_run', true);
    setappdata(0, 'A3_override', ov);
    evalin('base', 'A3_setup');

    mdl = evalin('base', 'mdl');
    setappdata(0, 'A3_cfg_for', mdl);     % InitFcn 이 A3_setup 을 다시 부르지 않게
    load_system(mdl);
    set_param(mdl, 'SimulationMode', 'normal', ...
              'EnablePacing', 'on', 'PacingRate', num2str(max(RTF, 0.1)));
    out = sim(mdl);
    fprintf('--- %s 끝 ---\n', tag);
end

function us = now_us(node)
%NOW_US  마이크로초 타임스탬프 (대회 uORB 메시지 첫 칸과 같은 단위)
    try
        us = double(ros2time(node, 'now').sec) * 1e6;
    catch
        us = posixtime(datetime('now', 'TimeZone', 'UTC')) * 1e6;
    end
end

function pub_sa(node, sap, out)
%PUB_SA  한 구간의 로그를 StatesAndActuators 필드 순서로 흘린다
%   대회는 제어 주기마다 실시간으로 냈다. 여기서는 구간이 끝난 뒤 10 Hz 로
%   솎아 한꺼번에 보낸다 — **필드 순서와 단위만** 같게 맞춘 것이다
    t = out.log_x_n.Time;
    if numel(t) < 2, return; end
    dec = max(1, round(0.1 / median(diff(t))));     % 10 Hz 로 솎는다
    k   = 1:dec:numel(t);
    g   = @(s) s.Data(k);
    z   = zeros(numel(k), 1);
    M = [g(out.log_u), g(out.log_v), g(out.log_r), ...
         g(out.log_x_n), g(out.log_y_n), g(out.log_psi), ...
         g(out.log_X_c), g(out.log_Y_c), g(out.log_N_c), ...
         z, g(out.log_psi_ref), ...
         g(out.log_TL), g(out.log_TR), z, z, ...
         g(out.log_dL), g(out.log_dR), z, z];
    t0 = now_us(node);
    for i = 1:size(M, 1)
        send(sap, fda(sap, [t0 + t(k(i))*1e6, M(i, :)]));
    end
    fprintf('    /tp_dock/states_and_actuators %d 묶음 발행 (10 Hz 로 솎음)\n', ...
            size(M, 1));
end

function v = pick(T, dflt)
    if isempty(T), v = dflt; else, v = T; end
end

function psi = odom_psi_ned(m)
%ODOM_PSI_NED  ENU 쿼터니언 -> NED 선수각 [rad]
    q = m.pose.pose.orientation;
    yaw_enu = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y^2 + q.z^2));
    psi = ssa_local(pi/2 - yaw_enu);
end

function a = ssa_local(a)
    a = mod(a + pi, 2*pi) - pi;
end

function m = fda(pub, v)
%FDA  Float64MultiArray 한 개 — layout 까지 채운 완전한 메시지를 만든다
%   struct('data', ...) 만 넘기면 ros2publisher/send 가 'layout' 없다고 막는다
    m = ros2message(pub);
    m.layout.dim        = m.layout.dim([]);     % 빈 MultiArrayDimension 배열
    m.layout.data_offset = uint32(0);
    m.data = double(v(:)');
end
