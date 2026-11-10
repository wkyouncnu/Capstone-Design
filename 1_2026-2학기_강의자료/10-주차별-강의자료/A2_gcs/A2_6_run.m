function [out, V] = A2_6_run(T_end)
%A2_6_RUN  VRX 와 연동해 A2_gps 를 돌린다 — 실행 전 네 가지를 대신 확인한다
%
%   >> A2_6_gps_setup
%   >> A2_build_gps_model
%   >> [out, V] = A2_6_run(T_run)
%
%   보통은 직접 부르지 않는다. `A2_6_gps_done` 이 이 함수를 부른다.
%
%   대신 해 주는 것 (5주차 `W05_vrx_run` 과 같은 순서)
%     0. ROS 2 도메인 맞추기 — Simulink 프로필 값으로 환경변수를 맞춘다
%     1. 토픽 두 개가 보이는지 — GPS 와 지상참값. 없으면 여기서 멈춘다
%     2. GPS 를 한 번 받아 위경도를 찍고, 주기를 재고,
%        지상참값으로 RTF 와 스폰 위치를 재고, 경로 원점을 월드에 고정한다
%     3. 페이싱을 측정한 RTF 로 두고 실행
%     4. 결과를 .mat 으로 남긴다 — 긴 실행이 중간에 끊겨도 숫자가 남는다
%
%   왜 경로 원점을 스폰이 아니라 월드에 고정하는가
%     스폰 위치는 설치마다 다르다 (원본 ENU y = 162, 이 데스크톱 200). 스폰을
%     경로 원점으로 삼으면 162 설치에서 경로가 38 m 남쪽으로 밀려 해안에
%     얹힌다. 그래서 원점은 `W05_setup` 의 path_north0 · path_east0 로 고정하고
%     배는 스폰에서 출발한다 — 5주차와 같은 처방이다
%
%   끝나면 반드시
%     $ source ~/vrx_ws/install/setup.bash
%     $ ros2 run vrx_llm_dock cleanup
%   남은 gz sim 이 62 GB 까지 자라 OOM 을 부른다

    if nargin < 1 || isempty(T_end)
        T_end = evalin('base', 'T_run');
    end

    m    = 'A2_gps';
    here = fileparts(mfilename('fullpath'));
    GPS  = evalin('base', 'gps_topic');
    TRU  = evalin('base', 'truth_topic');

    %% 0. 도메인 맞추기 ------------------------------------------------
    %  Simulink 블록은 'ROS 네트워크 프로필'의 Domain ID 를 쓰고, MATLAB 의
    %  ros2* 함수는 환경변수 ROS_DOMAIN_ID (기본 0) 를 쓴다. 둘이 다르면
    %  MATLAB 쪽에서만 토픽이 보이지 않는다 — 조용히 틀리는 자리다
    try
        prof = getpref('ROS_Toolbox', 'ROS_NetworkAddress_Profiles');
        if ~isempty(prof) && isfield(prof{1}, 'DomainID')
            setenv('ROS_DOMAIN_ID', num2str(double(prof{1}.DomainID)));
        end
    catch
    end
    if isempty(getenv('ROS_DOMAIN_ID')), setenv('ROS_DOMAIN_ID', '0'); end
    fprintf('\n0) ROS_DOMAIN_ID = %s\n', getenv('ROS_DOMAIN_ID'));

    %% 1. 토픽 확인 ----------------------------------------------------
    fprintf('1) 토픽 확인\n');
    tl = ros2('topic', 'list');
    for tp = {GPS, TRU}
        if ~any(strcmp(tl, tp{1}))
            error('A2:notopic', ...
                 ['%s 가 보이지 않는다.\n' ...
                  '  - VRX 가 떠 있는가 (WSL 에서  ros2 topic list )\n' ...
                  '  - 지상참값은 urdf 인자 ground_truth_enabled:=true 가 필요하다\n' ...
                  '  - ROS_DOMAIN_ID 가 양쪽 같은가 (지금 %s)'], ...
                  tp{1}, getenv('ROS_DOMAIN_ID'));
        end
    end
    fprintf('   OK — 토픽 %d 개,  GPS 와 지상참값 모두 보인다\n', numel(tl));

    %% 2. 한 번 받아 보고, 재어 본다 -----------------------------------
    fprintf('2) GPS 를 받아 본다\n');
    nd = ros2node(sprintf('/a2_probe_%d', randi(9999)));
    cu = onCleanup(@() clear('nd'));

    sg = ros2subscriber(nd, GPS, 'sensor_msgs/NavSatFix');
    g0 = receive(sg, 15);
    V.gps_lat = g0.latitude;
    V.gps_lon = g0.longitude;
    V.gps_alt = g0.altitude;
    fprintf('   위도 %.8f,  경도 %.8f,  고도 %.4f m\n', ...
            V.gps_lat, V.gps_lon, V.gps_alt);
    fprintf('   frame_id = %s,  status = %d\n', ...
            g0.header.frame_id, g0.status.status);

    w = tic;  N = 20;
    for k = 1:N, receive(sg, 5); end
    V.gps_hz = N / toc(w);
    fprintf('   수신 주기 — %d 개를 받는 데 %.2f s  ->  %.1f Hz\n', ...
            N, toc(w), V.gps_hz);

    %  --- 지상참값으로 RTF 와 스폰 위치 ------------------------------
    fprintf('   지상참값으로 RTF 측정 (20 s)\n');
    st = ros2subscriber(nd, TRU, 'nav_msgs/Odometry');
    m0 = receive(st, 15);  wr = tic;
    t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
    y0_n = m0.pose.pose.position.x;      % ENU x (동) -> NED y
    x0_n = m0.pose.pose.position.y;      % ENU y (북) -> NED x
    pause(20);
    m1 = receive(st, 15);  dw = toc(wr);
    t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
    V.RTF = (t1 - t0) / dw;

    pn0 = evalin('base', 'path_north0');
    pe0 = evalin('base', 'path_east0');
    assignin('base', 'origin_north', pn0);
    assignin('base', 'origin_east',  pe0);
    V.start_n = x0_n - pn0;
    V.start_e = y0_n - pe0;
    assignin('base', 'start_n', V.start_n);
    assignin('base', 'start_e', V.start_e);

    fprintf('   스폰 (북 %.2f, 동 %.2f) 월드  ->  경로 좌표 (%.2f, %.2f)\n', ...
            x0_n, y0_n, V.start_n, V.start_e);
    fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', V.RTF);

    %  GPS 한 샘플을 손으로 변환해 둔다 — 지상참값과 바로 견준다
    lla0 = evalin('base', 'lla0');
    ned  = lla2ned([V.gps_lat V.gps_lon V.gps_alt], lla0, 'flat');
    V.gps_n = ned(1);   V.gps_e = ned(2);
    fprintf('   GPS 를 기준점 기준으로 환산 : (북 %.2f, 동 %.2f)\n', V.gps_n, V.gps_e);
    fprintf('   같은 순간 지상참값          : (북 %.2f, 동 %.2f)  -> 차 %.2f m\n', ...
            V.start_n, V.start_e, hypot(V.gps_n - V.start_n, V.gps_e - V.start_e));

    %% 3. 실행 ---------------------------------------------------------
    fprintf('3) %s 실행 (%d s, 페이싱 %.3f)\n', m, T_end, V.RTF);
    load_system(fullfile(here, [m '.slx']));
    set_param(m, 'EnablePacing', 'on', ...
                 'PacingRate',   num2str(V.RTF), ...
                 'StopTime',     num2str(T_end));
    tw  = tic;
    out = sim(m);
    V.wall  = toc(tw);
    V.T_end = T_end;

    %% 4. 결과 저장 ----------------------------------------------------
    %  긴 실행이 중간에 끊기거나 창을 닫아도 숫자는 남는다
    V.mat = fullfile(here, 'A2_6_last_run.mat');
    save(V.mat, 'out', 'V', '-v7.3');
    fprintf('4) 결과 저장 : %s\n', V.mat);
end
