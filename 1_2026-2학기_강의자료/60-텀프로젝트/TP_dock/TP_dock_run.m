function S = TP_dock_run(station, phase, T)
%TP_DOCK_RUN  대회 코드가 찾은 도킹 스테이션으로 **순수 횡이동** 진입
%
%   >> TP_dock_run(1)        1번 칸 — WP1 유지(검출) → 정렬 → 진입 (기본)
%   >> TP_dock_run(2, 1)     2번 칸 — 정렬만
%   >> TP_dock_run(2, 2)     2번 칸 — 진입만 (이미 정렬된 자리에서)
%   >> TP_dock_run([], 3)    WP1 위치유지만 — 검출 노드가 점군을 쌓는 동안
%   >> TP_dock_run([], 4)    WP1 복귀 — 다음 칸을 시도하기 전에
%   >> TP_dock_run(1, 5, 60) 진단 — crab 한 구간(3 m)만 · 선수각 흐름을 잰다
%
%   제어기는 **부록 A3 의 A3_4_vrx.slx 를 그대로 쓴다**
%     이 수업에서 튜닝한 WAM-V 이득(Kp_x 0.4 · Kp_u 300 · Kp_psi 400 · Kd_psi 200)
%     과 아지무스 추력 배분이 이미 들어 있다. 모델도 이득도 고치지 않는다.
%     A3_setup 의 **목표점과 스폰 원점만** A3_override 로 갈아 끼운다.
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
%     고른다  /tp_dock/select     (0-기준 칸 번호)
%     낸다    /tp_dock/for_docking_mission  (ForDockingMission 꼴, 18 칸)
%     낸다    /tp_dock/states_and_actuators (StatesAndActuators 꼴, 20 칸)
%
%   2026-11-19 에 잡은 두 가지 — 둘 다 **오류 메시지 없이** 틀렸다
%     [1] 스폰 원점
%         A3_setup 은 origin_north·origin_east 를 0 으로 두고 "실행 스크립트가
%         ground truth 첫 샘플로 재서 덮어쓴다" 고 적어 두었다. A3_override 에
%         그 두 값을 넣지 않으면 모델의 x_n·y_n 은 **월드 절대 좌표**가 되고,
%         이 스크립트가 주는 목표는 **원점 상대 좌표**라 약 10 m 어긋난 자리로
%         들어간다. 실측: 진입 잔차가 0.13 m 로 나왔는데 배는 북 9.4 m, 즉
%         WP1 옆에 그대로 있었다. 이제 override 에 origin 을 함께 넘긴다.
%     [2] 검출 중 위치유지
%         누적기는 월드 NED 로 쌓으므로 배가 흘러가면 점군이 번진다. 검출이
%         LOCKED 가 되기 전에 **A3 로 WP1 을 잡고 있어야** 세 칸이 다 잡힌다.
%         실측: 제어 없이 띄워 두면 프레임당 점이 300 → 49 로 줄고 1/3 만 잡힘.
%
%   입구점의 뜻 — 2026-11-19 실측에서 한 번 틀렸던 자리
%     대회 find_bays_pillars 가 내는 idx 는 간격 안쪽 깊은 점의 중앙값, 즉
%     **안쪽 벽면**이다. 대회 스테이션은 깊이 0.35 m 라 그 점이 곧 입구였다.
%     해양누리는 깊이 7.0 m 라 후벽이 나온다 — 검출 노드가 격벽 앞면 기준거리로
%     입구를 다시 잡도록 고쳤고, 이 스크립트는 입구에서 INSET 만큼만 들어간다.
%
%   2026-11-20 에 잡은 것 — **같은 추력 토픽을 쓰던 두 번째 제어기**
%     tp_dock_ctrl.py (대회 Otter 이득으로 짰다가 쓰지 않기로 한 파이썬 제어기)
%     가 ROS 노드로 남아 돌고 있었다. 그것이 /wamv/thrusters/{left,right}/thrust
%     에 WP1·선수각 0 유지를 계속 지령했다 — A3_4_vrx 와 **같은 토픽**이다
%       실측: 추력을 0 으로 내려도 배가 (북 16.6, 동 -7.8) 에서 9.4 m 를 움직여
%             (북 11.3, 동 0.0) · 선수각 -9 deg 에서 멈췄다. 조류가 아니라
%             WP1 유지였다 (해류·파랑은 coast_waves 로 **시각 전용**임)
%       확인: ros2 topic info -v /wamv/thrusters/left/thrust -> tp_dock_ctrl
%       끈 뒤: 추력 0 으로 20 초에 0.3 m · 0.25 m/s 이하
%     그 전까지의 진입 측정은 **제어기 둘이 서로 당긴 결과**였다. 선수각이
%     흐른다·포화가 요 모멘트를 먹는다 던 진단은 전부 이 간섭의 그림자였다
%
%   간섭을 없앤 뒤의 진입 성적 — 칸마다 WP1 에서 새로 출발 (tp_dock_reset)
%     | 칸 | 끝난 자리 (북, 동) | 칸 안쪽 | 폭 치우침 | 선수각 오차 | 최대 횡속 | 최대 전후속 |
%     |  1 | (25.74, -8.37) | +3.01 m | -0.08 m | +0.9 deg | 0.29 | 0.07 |
%     |  2 | (25.49, -0.29) | +3.00 m | +0.48 m | +0.9 deg | 0.32 | 0.13 |
%     |  3 | (25.22,  8.94) | +3.00 m | -0.05 m | +0.9 deg | 0.29 | 0.08 |
%     - 전 구간이 A3 자동정지(0.30 m · 2.0 deg 를 15 초)에 들었다
%     - 칸 2 의 0.48 m 치우침은 [8] 이 **벽 따라 성분을 일부러 버리기** 때문임
%       순수 횡이동을 지키려고 전후 성분을 안 주므로 그만큼은 끝까지 안 준다
%       칸 폭 8.0 m · 선폭 2.46 m 로 한쪽 여유가 2.77 m 라 문제가 되지 않는다
%
%   재현 — 칸 2 를 하루 뒤 같은 절차로 다시 (2026-11-20)
%     (북 25.49, 동 0.02) · 칸 안쪽 +3.00 m · 치우침 +0.17 m · 선수각 오차 +0.9 deg
%     앞의 표와 같은 자리로 들어왔다
%
%   **재는 동안 TP_dock_gcs 를 띄우지 않는다** — 2026-11-20 실측
%     관제 화면은 5 Hz 로 그림 셋을 다시 그린다. 그 부하가 페이싱된 실행과
%     CPU 를 다투어 제어 대역폭을 떨어뜨린다
%       띄운 채 칸 2: 정렬이 목표까지 4.8 m 모자란 자리에서 멈췄고, 남은 거리를
%         진입 네 구간이 떠안아 선수각이 159.6 deg 까지 무너졌다 (칸 안쪽 +1.98 m)
%       창만 닫고 다시: 위의 재현값 그대로 (칸 안쪽 +3.00 m · 오차 +0.9 deg)
%     관제 화면은 **진입이 끝난 뒤** 결과를 보이는 데 쓴다
%
%   먼저 할 것 — 가제보와 검출 노드가 돌고 있어야 한다
%     WSL 터미널 1   export ROS_DOMAIN_ID=7 GZ_PARTITION=dockA
%                    cd .../60-텀프로젝트/TP_haeyang
%                    START_X=0 START_Y=10 START_YAW=1.5708 bash run_haeyang.sh lite gui
%     WSL 터미널 2   같은 두 환경변수를 주고
%                    cd ../TP_dock && python3 tp_dock_detect.py
%
%   끝낼 때 — 띄운 터미널에서 Ctrl+C. 남은 gz sim 이 메모리를 수십 GB 먹는다.
%     다른 세션의 가제보가 함께 돌면 stop_vrx.sh 를 쓰지 않는다 (남의 것까지 끈다).

    if nargin < 1, station = 1; end
    if isempty(station), station = 1; end
    if nargin < 2 || isempty(phase), phase = 0; end
    if nargin < 3, T = []; end
    assert(ismember(station, [1 2 3]), 'TP_dock_run:station', ...
           '칸은 1 · 2 · 3 가운데 하나다 (서 -> 동 순서)');

    DOMAIN   = 7;
    PART     = 'dockA';
    WORLD    = 'haeyangnuri';
    ODOM     = '/wamv/sensors/position/ground_truth_odometry';
    WP1      = [10 0];     % 위치유지 지점 — 월드 절대 NED (북, 동) [m]
    STANDOFF = 6.0;        % 입구에서 이만큼 물러나 정렬한다 [m]
    INSET    = 3.0;        % 입구에서 이만큼만 안으로 들어간다 [m]
    BEAM     = 2.46;       % WAM-V 폭 — 횡이동이므로 이 방향이 진행 방향이다 [m]
    T_HOLD   = 90;         % 검출이 점군을 쌓는 동안 WP1 을 잡고 있는 시간 [s]

    here = fileparts(mfilename('fullpath'));
    A3   = fullfile(here, '..', '..', '10-주차별-강의자료', 'A3_azimuth');
    assert(isfolder(A3), 'TP_dock_run:a3', 'A3_azimuth 를 찾지 못했다: %s', A3);
    addpath(fullfile(here, '..', '..', '_tools'));
    addpath(A3);  cd(A3);          % A3_4_vrx.slx 가 있는 자리에서 돈다

    %% [0] 도메인 — Simulink 블록은 ROS 네트워크 프로필, ros2* 함수는 환경변수
    setenv('ROS_DOMAIN_ID', num2str(DOMAIN));
    fprintf('\n[0] ROS_DOMAIN_ID = %s · 칸 %d · phase %d\n', ...
            getenv('ROS_DOMAIN_ID'), station, phase);

    %% [1] 토픽 — 대회 규약과 같은 꼴
    node = ros2node(sprintf('/tp_dock_run_%d', randi(9999)), DOMAIN);
    selp = ros2publisher(node, '/tp_dock/select', 'std_msgs/Int32');
    fdm  = ros2publisher(node, '/tp_dock/for_docking_mission', ...
                         'std_msgs/Float64MultiArray');
    sap  = ros2publisher(node, '/tp_dock/states_and_actuators', ...
                         'std_msgs/Float64MultiArray');
    thp  = {ros2publisher(node, '/wamv/thrusters/left/thrust',  'std_msgs/Float64'), ...
            ros2publisher(node, '/wamv/thrusters/right/thrust', 'std_msgs/Float64')};
    azp  = {ros2publisher(node, '/wamv/thrusters/left/pos',  'std_msgs/Float64'), ...
            ros2publisher(node, '/wamv/thrusters/right/pos', 'std_msgs/Float64')};
    sb   = ros2subscriber(node, ODOM, 'nav_msgs/Odometry');
    pause(1.5);
    send(selp, struct('data', int32(station - 1)));          % 0-기준
    send(fdm,  fda(fdm, [now_us(node) 1 zeros(1,16)]));      % detect_on 올림

    %% [2] 스폰 원점과 RTF — 모델의 x·y 는 이 점 기준이다
    %    override 에 함께 넘기지 않으면 A3_setup 이 0 으로 두고, 목표가 어긋난다
    vrx_play(PART, WORLD);
    %  RTF 는 **한 번만 재고 아껴 쓴다** — 재는 10 초 동안 배가 제어 없이 흐른다
    %    2026-11-19 실측: phase 2 를 따로 돌렸을 때 이 10 초와 A3_setup 시간을
    %    합쳐 배가 10 m 흐르고 46 deg 돌았다 (정렬에서 맞춘 -80 deg 가 -34 deg
    %    로 무너졌다). 같은 세션에서 같은 세계를 쓰는 동안 RTF 는 바뀌지 않으니
    %    appdata 에 담아 두고 다음 실행에서는 한 표본만 읽는다
    RTF = getappdata(0, 'tp_dock_rtf');
    if isempty(RTF)
        m0  = receive(sb, 15);  w = tic;
        t0  = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
        pause(10);
        m1  = receive(sb, 15);  tw = toc(w);
        t1  = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
        RTF = (t1 - t0) / tw;
        setappdata(0, 'tp_dock_rtf', RTF);
    else
        m0  = receive(sb, 15);
        fprintf('    RTF %.3f — 앞서 실측한 값을 쓴다 (10 초 표류를 피한다)\n', RTF);
    end
    on  = m0.pose.pose.position.y;      % ENU y -> 북
    oe  = m0.pose.pose.position.x;      % ENU x -> 동
    fprintf('[2] 모델 원점 (북 %.2f, 동 %.2f) · RTF %.3f\n', on, oe, RTF);
    fprintf('    지금 월드 위치 (북 %.2f, 동 %.2f) · 선수각 %.1f deg\n', ...
            on, oe, rad2deg(odom_psi_ned(m0)));

    S = struct('station', station, 'phase', phase, 'origin', [on oe], 'RTF', RTF);
    R = struct();     % 구간마다의 실측 결과

    %% [3] WP1 위치유지 — 검출 노드가 그 동안 점군을 쌓아 LOCKED 가 된다
    if phase == 0 || phase == 3 || phase == 4
        tg = sprintf('WP1 유지 (북 %.1f, 동 %.1f)', WP1(1), WP1(2));
        R.hold = leg(WP1(1) - on, WP1(2) - oe, 0, on, oe, RTF, ...
                     pick(T, T_HOLD), tg, node, sb, thp, azp);
        pub_sa(node, sap, R.hold.out);
        if phase ~= 0
            S.legs = R;  tidy(fdm, node);  return
        end
    end

    %% [4] 검출 결과 — 대회 규약 토픽에서 받는다
    dps = ros2subscriber(node, '/tp_dock/docking_param', ...
                         'std_msgs/Float64MultiArray');
    fprintf('[4] /tp_dock/docking_param 을 기다린다 (검출이 LOCKED 여야 한다)\n');
    dp = receive(dps, 60);
    d  = double(dp.data);
    assert(numel(d) >= 6, 'TP_dock_run:dp', ...
           'docking_param 길이가 %d 다 — 세 칸이 아직 안 잡혔다', numel(d));
    psi_ned = d(2);  idx_n = d(3);  idx_e = d(4);  wp_n = d(5);  wp_e = d(6);
    fprintf('    칸 %d — 입구 (북 %.2f, 동 %.2f) · 접근점 (북 %.2f, 동 %.2f)\n', ...
            station, idx_n, idx_e, wp_n, wp_e);
    fprintf('    개구부 방위 %.1f deg (NED) · WP1 기준 상대 (북 %+.2f, 동 %+.2f)\n', ...
            rad2deg(psi_ned), idx_n - WP1(1), idx_e - WP1(2));

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

    %% [5] 선체 선수각 — **부두 벽과 나란히** 세운다
    %    부두 벽은 동서로 뻗고 칸은 남쪽으로 열린다. 순수 횡이동이 되려면 선체가
    %    벽과 나란히 서야 한다 — 그래야 입구로 들어가는 방향이 선체 y 축과
    %    같아진다. 벽 방향은 개구부 방위에 ±90 deg 다. 둘 가운데 지금 선수각에
    %    가까운 쪽을 고른다 (쓸데없이 180 deg 돌지 않게)
    mi      = receive(sb, 15);
    psi_now = odom_psi_ned(mi);
    cand    = [ssa_local(psi_ned + pi/2), ssa_local(psi_ned - pi/2)];
    [~, ic] = min(abs(ssa_local(cand - psi_now)));
    psi_wall = cand(ic);
    fprintf('[5] 지금 선수각 %.1f deg → 벽과 나란한 %.1f deg 로 세운다\n', ...
            rad2deg(psi_now), rad2deg(psi_wall));

    %% [6] 두 목표점 — 정렬 자리 · 진입 자리
    %    정렬 자리는 입구에서 **개구부가 향하는 쪽**(칸 밖, 남쪽)으로 STANDOFF
    al_n = idx_n + STANDOFF * cos(psi_ned);
    al_e = idx_e + STANDOFF * sin(psi_ned);
    %    진입 자리는 입구에서 **칸 안쪽**으로 inset 만큼. 개구부 방위가 칸 밖을
    %    가리키므로 부호가 반대다
    en_n = idx_n - inset * cos(psi_ned);
    en_e = idx_e - inset * sin(psi_ned);
    fprintf(['[6] 정렬 (북 %.2f, 동 %.2f) → 입구 (북 %.2f, 동 %.2f)' ...
             ' → 진입 (북 %.2f, 동 %.2f)\n'], ...
            al_n, al_e, idx_n, idx_e, en_n, en_e);
    %    진입 구간이 **선체 횡방향인지** 먼저 따진다 — 숫자로 확인하고 들어간다
    dn = en_n - al_n;  de = en_e - al_e;
    e_fwd = dn*cos(psi_wall) + de*sin(psi_wall);
    e_lat = -dn*sin(psi_wall) + de*cos(psi_wall);
    fprintf('    진입 구간 %.2f m = 전후 %+.2f m · 횡 %+.2f m (전후가 0 이어야 순수 횡이동)\n', ...
            hypot(dn, de), e_fwd, e_lat);

    S.psi_ned = psi_ned;  S.psi_wall = psi_wall;
    S.idx = [idx_n idx_e];  S.wp = [wp_n wp_e];
    S.align = [al_n al_e];  S.enter = [en_n en_e];
    S.inset = inset;  S.depth = depth;
    S.leg_fwd = e_fwd;  S.leg_lat = e_lat;

    %  여기서 세계를 멈춘다 — [3] 유지가 끝난 뒤 [4]~[6] 을 읽고 A3_setup 이
    %  도는 사이 (실측 15~20 초) 배가 제어 없이 흐르는 것을 막는다. 아래 구간은
    %  저마다 leg 첫머리에서 world_run(true) 로 다시 돌린다
    world_run(false);

    %% [7] 정렬 — 선수각을 벽과 나란히 세우고 칸 밖에 선다
    if phase == 0 || phase == 1
        R.align = leg(al_n - on, al_e - oe, psi_wall, on, oe, RTF, ...
                      pick(T, 150), sprintf('정렬(칸%d)', station), ...
                      node, sb, thp, azp, true);
        pub_sa(node, sap, R.align.out);

        %  [7a] 제자리 회전 — **위치 오차를 0 으로 둔 채** 선수각만 세운다
        %
        %   현재 상태 — 2026-11-20 실측에서 칸 1·2·3 **세 번 모두 건너뛰었다**
        %     정렬 구간이 끝난 선수각 오차가 1 deg 안쪽이라 아래 5 deg 문턱에
        %     걸리지 않는다. 세 칸의 진입 성공은 전부 이 구간 **없이** 난 것임
        %
        %   처음 넣은 이유와, 그 이유가 틀렸던 점
        %     '정렬에서 선수각이 거의 안 돈다 (-45.4 -> -38.2 deg)' 를 보고
        %     추력 배분의 힘 포화 탓으로 적었다. **원인이 아니었다**
        %     같은 추력 토픽에 두 번째 제어기(tp_dock_ctrl.py) 가 WP1 유지를
        %     지령하고 있었다. 그것을 끈 뒤로는 정렬만으로 선수각이 선다
        %
        %   남겨 두는 까닭
        %     선수각이 5 deg 넘게 남은 경우의 대비임 — 문턱 안에서는 안 돈다
        %     모델도 이득도 고치지 않는다. 구간을 하나 더 주는 것뿐이다
        psi_now = R.align.psi;
        p0      = R.align.world;
        R.spin  = {};
        for ks = 1:3
            e_deg = rad2deg(ssa_local(psi_wall - psi_now));
            fprintf(['\n[7a-%d] 지금 선수각 %.1f deg · 벽과 나란한 값 %.1f deg' ...
                     ' (오차 %+.1f deg)\n'], ...
                    ks, rad2deg(psi_now), rad2deg(psi_wall), e_deg);
            if abs(e_deg) < 5
                fprintf('      5 deg 안 — 회전을 더 하지 않는다\n');
                break
            end
            rr = leg(p0(1) - on, p0(2) - oe, psi_wall, on, oe, RTF, ...
                     80, sprintf('회전%d(칸%d)', ks, station), ...
                     node, sb, thp, azp, true);
            pub_sa(node, sap, rr.out);
            fprintf(['      회전 끝 — 선수각 %.1f deg (오차 %+.1f deg) ·' ...
                     ' 자리 (북 %.2f, 동 %.2f) · 흐른 거리 %.2f m\n'], ...
                    rad2deg(rr.psi), rad2deg(ssa_local(psi_wall - rr.psi)), ...
                    rr.world(1), rr.world(2), hypot(rr.world(1) - p0(1), ...
                                                    rr.world(2) - p0(2)));
            psi_now = rr.psi;  p0 = rr.world;
            R.spin{ks} = rr;
            R.align    = rr;          % [7b] 가 '정렬이 끝난 자리' 로 쓰는 값
        end
        S.psi_spin = psi_now;
    end

    %% [7b] 진입 직전 자세를 실측한다 — **구간을 더 돌리지 않는다**
    %
    %   '접근' 구간을 두지 않는 이유
    %     정렬이 끝난 자리는 이미 입구 정남쪽 STANDOFF 거리다. 더 갈 곳이 없다
    %     한 구간을 더 주면 같은 자리를 다시 요구하는 빈 구간이 된다
    %   이 구간을 없애며 적어 두었던 '선수각이 다시 무너졌다 (-91.2 -> -73.8 deg)'
    %   는 설계 탓이 아니라 **tp_dock_ctrl.py 간섭** 때문이었다 (2026-11-20)
    %   그래서 여기서는 재기만 하고, 바로 [8] 저속 진입으로 넘어간다
    if phase == 0 || phase == 2 || phase == 5
        if isfield(R, 'align')
            %  [7]/[7a] 가 멈추기 **전에** 재 둔 값 (멈춘 세계는 odom 을 안 낸다)
            psi_b = R.align.psi;
            pb    = R.align.world;
        else
            world_run(true);
            ma    = receive(sb, 15);
            psi_b = odom_psi_ned(ma);
            pb    = [ma.pose.pose.position.y, ma.pose.pose.position.x];
        end
        d     = [en_n en_e] - pb;
        lat_w = [-sin(psi_wall), cos(psi_wall)];     % 벽 기준 횡축 (= 벽 법선)
        fwd_w = [ cos(psi_wall), sin(psi_wall)];     % 벽 기준 전후축 (= 벽 방향)
        d_lat = d(1)*lat_w(1) + d(2)*lat_w(2);
        d_fwd = d(1)*fwd_w(1) + d(2)*fwd_w(2);
        fprintf(['[7b] 진입 직전 — 자리 (북 %.2f, 동 %.2f) · 선수각 %.1f deg' ...
                 ' (벽과 %+.1f deg)\n' ...
                 '     진입 목표 (북 %.2f, 동 %.2f) 까지 %.2f m' ...
                 ' = 횡 %+.2f m · 전후 %+.2f m\n'], ...
                pb(1), pb(2), rad2deg(psi_b), rad2deg(ssa_local(psi_b - psi_wall)), ...
                en_n, en_e, hypot(d(1), d(2)), d_lat, d_fwd);
        S.psi_b = psi_b;  S.pb = pb;
        S.d_lat = d_lat;  S.d_fwd = d_fwd;
    end

    %% [8] 진입 — 저속 순수 횡이동. **벽과 나란한 선수각을 계속 지시한다**
    %
    %   한 구간이 하는 일
    %     1. 지금 자리를 실측한다
    %     2. 진입 목표까지 남은 벡터를 **벽 기준** 횡·전후로 쪼갠다
    %        (선체의 지금 횡축이 아니다 — 지시하는 선수각이 벽 기준이므로)
    %     3. 전후 성분은 버리고, 횡 성분을 남은 구간 수로 나눠 한 토막만 준다
    %     4. 선수각 목표는 **매번 psi_wall** — 흘러도 다시 끌어온다
    %     5. 구간이 끝나면 세계를 멈춘다
    %   속도 한계는 leg 의 'crab' 이 u_max 0.15 · v_max 0.30 으로 묶는다
    if phase == 0 || phase == 2 || phase == 5
        if phase == 5
            %  진단 — 한 구간만 돌려 선수각이 얼마나 흐르는지 잰다
            NSEG = 1;  T_seg = pick(T, 60);
        else
            NSEG  = 4;
            T_seg = max(45, round(pick(T, 200) / NSEG));
        end
        pc    = pb;   psi_c = psi_b;
        um = 0;  vm = 0;  R.seg = {};
        for k = 1:NSEG
            d     = [en_n en_e] - pc;
            d_lat = d(1)*lat_w(1) + d(2)*lat_w(2);
            d_fwd = d(1)*fwd_w(1) + d(2)*fwd_w(2);
            f     = 1 / (NSEG - k + 1);        % 남은 거리를 남은 구간 수로 나눈다
            if phase == 5, f = min(f, 3.0/max(abs(d_lat), 1e-6)); end   % 진단 3 m
            sn    = pc(1) + f*d_lat*lat_w(1);
            se    = pc(2) + f*d_lat*lat_w(2);
            fprintf(['\n[8-%d] 지금 (북 %.2f, 동 %.2f) · 선수각 %.1f deg' ...
                     ' (벽과 %+.1f deg)\n' ...
                     '      목표까지 횡 %+.2f m · 전후 %+.2f m' ...
                     ' — 전후는 버리고 횡의 %.0f %%%% 만 준다\n' ...
                     '      이번 목표 (북 %.2f, 동 %.2f) · 선수각 %.1f deg\n'], ...
                    k, pc(1), pc(2), rad2deg(psi_c), ...
                    rad2deg(ssa_local(psi_c - psi_wall)), ...
                    d_lat, d_fwd, f*100, sn, se, rad2deg(psi_wall));
            rr = leg(sn - on, se - oe, psi_wall, on, oe, RTF, ...
                     T_seg, sprintf('진입%d(칸%d)', k, station), ...
                     node, sb, thp, azp, true, 'crab');
            pub_sa(node, sap, rr.out);
            u_k = max(abs(rr.out.log_u.Data));
            v_k = max(abs(rr.out.log_v.Data));
            um  = max(um, u_k);  vm = max(vm, v_k);
            fprintf(['      구간 끝 (북 %.2f, 동 %.2f) · 선수각 %.1f deg' ...
                     ' · 최대 횡속 %.2f · 최대 전후속 %.2f m/s\n'], ...
                    rr.world(1), rr.world(2), rad2deg(rr.psi), v_k, u_k);
            pc = rr.world;  psi_c = rr.psi;
            R.seg{k} = rr;  R.enter = rr;
        end

        %  성적 — 월드 절대 좌표로만 적는다
        S.end_world = pc;
        S.psi_end   = psi_c;
        S.v_max     = vm;
        S.u_max     = um;
        %  입구 평면에서 칸 안쪽으로 얼마나 들어갔는가 (개구부 방위 psi_ned 의 반대)
        S.dist_in = (pc(1) - idx_n)*(-cos(psi_ned)) + ...
                    (pc(2) - idx_e)*(-sin(psi_ned));
        %  칸 폭 방향(벽 따라)으로 중앙선에서 얼마나 치우쳤는가
        S.off_lat = (pc(1) - idx_n)*(-sin(psi_ned)) + ...
                    (pc(2) - idx_e)*( cos(psi_ned));
        S.err_n = idx_n - pc(1);
        S.err_e = idx_e - pc(2);
        fprintf(['\n[결과 칸%d]\n' ...
                 '   입구점 (북 %.2f, 동 %.2f) · 끝난 자리 (북 %.2f, 동 %.2f)\n' ...
                 '   선수각 %.1f deg (벽과 나란한 값 %.1f deg · 오차 %+.1f deg)\n' ...
                 '   칸 안쪽으로 %+.2f m (깊이 %.2f m 칸) ·' ...
                 ' 칸 폭 방향 치우침 %+.2f m (한쪽 여유 %.2f m)\n' ...
                 '   최대 횡속 %.2f m/s · 최대 전후속 %.2f m/s' ...
                 ' — 순수 횡이동이면 전후속이 작아야 한다\n'], ...
                station, idx_n, idx_e, pc(1), pc(2), ...
                rad2deg(psi_c), rad2deg(psi_wall), ...
                rad2deg(ssa_local(psi_c - psi_wall)), ...
                S.dist_in, depth, S.off_lat, 8.0/2 - BEAM/2, ...
                S.v_max, S.u_max);
    end

    S.legs = R;
    tidy(fdm, node);
end

% ======================================================================
function r = leg(x_d, y_d, psi_d, on, oe, RTF, T, tag, ~, sb, thp, azp, freeze, mode)
%LEG  A3_4_vrx.slx 를 목표점만 바꿔 한 구간 돌리고, 끝나면 추력을 내린다
%   모델도 이득도 고치지 않는다. 바꾸는 것은 목표점·스폰 원점·**과업 선택**뿐이다
%
%   mode — A3_4_vrx 가 가진 과업 가운데 무엇을 쓰는가 (기본 'hold')
%     'hold'  vrx_target 3 (접안 목표점 자리) -> A3_setup 이 task_mode 1 을 고른다
%     'crab'  vrx_target 1 (순수 횡이동 자리) -> A3_setup 이 task_mode 2 를 고른다
%
%   유의 — **task_mode 1 과 2 는 유도부에서 같은 코드다**
%     parts/addGuidance.m 의 TaskRef 를 읽어 확인한 사실임
%       "한 점·한 선수각으로 가서 서 있는다. 1 과 2 는 목표만 다르다"
%     1 단이 순수 횡이동이 되는 까닭은 유도부가 달라서가 아니다
%       - 배가 **이미 목표 선수각으로 서 있고** (psi_init = psi_d)
%       - 목표점이 선체 횡축 위에 있어서
%     그래서 'crab' 을 고르는 것만으로는 전후속이 줄지 않는다
%
%   전후속을 실제로 묶는 것 — u_max
%     바깥 고리는 선체고정 오차에 비례 제어를 걸고 **속도로 포화**시킨다
%       u_cmd = sat(Kp_x * e_x, u_max),  v_cmd = sat(Kp_y * e_y, v_max)
%     본 과목 기본값은 u_max 1.5 · v_max 0.6 m/s 다. 전후 여유가 횡의 2.5 배이므로
%     선수각이 조금 돌아 전후 오차가 생기면 그쪽이 먼저 커진다
%     2026-11-19 실측: 'hold' 진입에서 최대 전후속 0.92 m/s > 최대 횡속 0.66 m/s
%   그래서 'crab' 구간에서는 **u_max 를 U_CAP 으로 내린다** (0.15 m/s)
%     - 모델도 이득도 유도부도 고치지 않는다. 본 과목 자료가 이미 조정 가능하게
%       내놓은 속도 한계 하나를 접안 구간에 맞게 줄이는 것임
%     - 결과: 바깥 고리가 전후 속도를 그 이상 지령할 수 없다 -> 순수 횡이동
%
%   횡속도 **까지** 묶는 까닭 — 2026-11-20 재측정으로 고쳐 적음
%     이 자리에 처음 적었던 진단 — '추진기가 둘뿐이라 배분이 힘을 먼저 맞추고
%     요 모멘트 여유가 없어 선수각이 무너진다' — 은 **틀렸다**
%     선수각이 흘러간 진짜 원인은 제어 설계가 아니라 **같은 추력 토픽에
%     지령을 내던 두 번째 제어기**였다 (tp_dock_ctrl.py · 파일 머리말 참조)
%     그것을 끈 뒤로는 모든 구간이 선수각 오차 +0.9 deg 로 끝난다
%   그래도 접안 구간을 느리게 두는 까닭 (v_max 0.30 · u_max 0.15 m/s)
%     - 접안은 벽을 3 m 남기고 서는 동작임. 속도가 미덕이 아니다
%     - 느린 쪽이 A3 자동정지(0.30 m · 2.0 deg 를 15 초 유지) 에 빨리 든다
%     - 본 과목 자료가 조정 가능하게 내놓은 속도 한계 둘을 줄이는 것뿐임
%     - 기본값(u_max 1.5 · v_max 0.6) 으로도 되는지는 **재지 않았다**
    U_CAP = 0.15;                  % 'crab' 구간의 전후 속도 지령 한계 [m/s]
    V_CAP = 0.30;                  % 'crab' 구간의 횡 속도 지령 한계 [m/s]
    if nargin < 14 || isempty(mode), mode = 'hold'; end
    fprintf('\n--- %s : 목표 (x %.2f, y %.2f, psi %.1f deg) · %d 초 · 과업 %s ---\n', ...
            tag, x_d, y_d, rad2deg(psi_d), T, mode);
    if strcmp(mode, 'crab')
        ov = struct('vrx_target', 1, ...        % 1 = 순수 횡이동 자리를 쓴다
                    'crab_north', x_d, 'crab_east', y_d, ...
                    'crab_deg', rad2deg(psi_d), ...
                    'u_max', U_CAP, 'v_max', V_CAP, ...   % 속도 한계 둘 (위 설명)
                    'origin_north', on, 'origin_east', oe, ...
                    'vrx_partition', 'dockA', 'vrx_world', 'haeyangnuri', ...
                    'T_run', T, 'animate', 1, 'animate_every', 0.5, 'rec_on', 0);
    else
        ov = struct('vrx_target', 3, ...        % 3 = 접안 목표점 자리를 쓴다
                    'dock_north', x_d, 'dock_east', y_d, ...
                    'dock_deg', rad2deg(psi_d), ...
                    'origin_north', on, 'origin_east', oe, ...
                    'vrx_partition', 'dockA', 'vrx_world', 'haeyangnuri', ...
                    'T_run', T, 'animate', 1, 'animate_every', 0.5, 'rec_on', 0);
    end
    %  시험용 덮어쓰기 — 접안 이득·속도 한계를 밖에서 쓸어 넣는다
    %    setappdata(0, 'tp_dock_tune', struct('v_max', 0.15, 'Kp_psi', 800))
    %    setappdata(0, 'tp_dock_tune', [])   <- 비우면 위 기본값으로 돌아간다
    %  **진단용이다.** 어느 값이 선수각을 지키는지 재기 위한 구멍이며,
    %  A3 모델·부품·기본 이득 파일은 건드리지 않는다
    tn = getappdata(0, 'tp_dock_tune');
    if ~isempty(tn) && isstruct(tn)
        fn = fieldnames(tn);
        for q = 1:numel(fn), ov.(fn{q}) = tn.(fn{q}); end
        fprintf('    시험용 덮어쓰기 — %s\n', strjoin(fn', ', '));
    end
    setappdata(0, 'A3_stage', 4);
    setappdata(0, 'A3_skip_run', true);
    setappdata(0, 'A3_override', ov);
    evalin('base', 'A3_setup');

    mdl = evalin('base', 'mdl');
    setappdata(0, 'A3_cfg_for', mdl);     % InitFcn 이 A3_setup 을 다시 부르지 않게
    load_system(mdl);
    world_run(true);                      % 멈춰 있었다면 풀고 시작한다
    set_param(mdl, 'SimulationMode', 'normal', ...
              'EnablePacing', 'on', 'PacingRate', num2str(max(RTF, 0.1)));
    r.out = sim(mdl);

    %  끝난 자리를 **월드 절대 좌표로** 실측한다 (모델 로그는 원점 상대다)
    %    멈추기 **전에** 읽는다 — 멈춘 세계는 odom 을 더 내보내지 않는다
    m = receive(sb, 15);

    %  구간 사이에 세계를 멈춘다 — 이것이 없으면 다음 구간을 띄우는 사이
    %    (A3_setup + load_system + sim 초기화, 실측 15~20 초) 동안 배가
    %    제어 없이 표류한다. 실측: WP1 유지가 끝난 뒤 몇 초 만에 선수각
    %    0 -> -21.2 deg, 속력 0.30 m/s. 정렬에서 맞춘 선수각이 진입까지
    %    살아 있어야 순수 횡이동이 성립한다
    if nargin >= 13 && freeze
        world_run(false);
    end

    %  추력도 내린다 — 멈춘 세계에 마지막 지령이 남아 있지 않게
    zero_thr(thp, azp);
    r.world   = [m.pose.pose.position.y, m.pose.pose.position.x];   % (북, 동)
    r.psi     = odom_psi_ned(m);
    r.psi_err_deg = rad2deg(ssa_local(psi_d - r.psi));
    r.spd     = hypot(m.twist.twist.linear.x, m.twist.twist.linear.y);
    fprintf(['--- %s 끝 — 월드 (북 %.2f, 동 %.2f) · 선수각 %.1f deg' ...
             ' (목표와 %+.1f deg) · 속력 %.2f m/s ---\n'], ...
            tag, r.world(1), r.world(2), rad2deg(r.psi), r.psi_err_deg, r.spd);
end

function world_run(go)
%WORLD_RUN  가제보 세계를 돌리거나(true) 멈춘다(false)
%   _tools/vrx_play.m 과 같은 방식이다 — 가제보 내부 통신은 ROS_DOMAIN_ID 가
%   아니라 GZ_PARTITION 으로 갈리므로 띄울 때 준 값을 그대로 준다
    if go, req = 'pause: false'; else, req = 'pause: true'; end
    sh = ['export GZ_PARTITION=dockA; ' ...
          'gz service -s /world/haeyangnuri/control' ...
          ' --reqtype gz.msgs.WorldControl --reptype gz.msgs.Boolean' ...
          ' --timeout 3000 --req ''' req ''' > /dev/null 2>&1'];
    [st, ~] = system(['wsl.exe -d Ubuntu-22.04 -e bash -lc "' sh '"']);
    if st ~= 0
        fprintf(2, '    세계 %s 에 실패했습니다 (코드 %d)\n', req, st);
    elseif ~go
        fprintf('    가제보를 멈췄습니다 — 다음 구간을 띄우는 동안 표류하지 않습니다\n');
    end
    pause(0.4);
end

function zero_thr(thp, azp)
%ZERO_THR  추력과 방향각을 0 으로 내린다 — 구간 사이의 표류를 줄인다
    for k = 1:30
        for i = 1:2
            send(thp{i}, struct('data', 0));
            send(azp{i}, struct('data', 0));
        end
        pause(0.1);
    end
end

function tidy(fdm, node)
%   멈춘 채로 끝내지 않는다 — RViz 와 검출 노드가 그대로 멈춰 보인다
%TIDY  detect_on 을 내리고 override 를 비운다 — 남기면 다음 실행까지 따라온다
    send(fdm, fda(fdm, [now_us(node) 0 zeros(1,16)]));
    setappdata(0, 'A3_override', []);
    setappdata(0, 'A3_skip_run', []);
    setappdata(0, 'A3_stage', []);
    fprintf('\n끝 — 목표를 되돌렸다 (A3_override 비움)\n');
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
