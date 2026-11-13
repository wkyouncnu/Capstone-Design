%% A3_5_tilt_run — 서보 틸팅 확인. 가제보 연동을 **반으로 잘라** 짚는다
%
%   왜 4단보다 먼저 돌리는가
%     VRX 연동이 움직이지 않을 때 원인은 셋이다 — 토픽 이름 · 도메인 ID ·
%     제어기. 이 스크립트는 제어기를 아예 쓰지 않으므로, 서보가 돌면 앞의 둘이
%     맞은 것이고 돌지 않으면 뒤의 하나는 볼 필요가 없다.
%
%   두 부로 나뉜다
%     1부  순수 MATLAB — ros2publisher 로 각도를 직접 보내고, /wamv/joint_states
%          에서 **실제로 돌아간 각도**를 읽어 지령과 나란히 찍는다
%     2부  Simulink — A3_5_tilt 모델로 같은 표를 돌린다. Simulink 의 ROS 블록이
%          MATLAB 과 **다른 곳에서 도메인을 읽기** 때문에 따로 확인해야 한다
%
%   먼저 할 것 — 가제보를 띄운다 (경량 모델, 선수추진기 없음)
%     WSL 터미널에서
%       export ROS_DOMAIN_ID=7
%       export GZ_PARTITION=a3
%       cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite
%       bash run_vrx.sh lite
%
%   끝낼 때 — 같은 터미널에서 Ctrl+C. 남은 gz sim 이 메모리를 수십 GB 까지
%   먹는다. 다른 세션의 가제보가 함께 돌고 있으면 stop_vrx.sh 를 쓰지 않는다
%   (프로세스 이름으로 끄므로 남의 것까지 끈다)

clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', '_tools'));  addpath(here);  cd(here);

%% [0] 도메인 맞추기 — 틀리면 토픽이 **아예 보이지 않는다**
%    Simulink 의 ROS 블록은 ROS 네트워크 프로필을, MATLAB 의 ros2* 함수는
%    환경변수를 본다. 이 PC 에는 프로필이 없으므로 환경변수 하나로 맞춘다
DOMAIN = 7;                               % 가제보를 띄운 터미널의 ROS_DOMAIN_ID
setenv('ROS_DOMAIN_ID', num2str(DOMAIN));
fprintf('[0] ROS_DOMAIN_ID = %s\n', getenv('ROS_DOMAIN_ID'));

%% [1] 설정과 토픽 확인
setappdata(0, 'A3_stage', 5);
setappdata(0, 'A3_skip_run', true);
setappdata(0, 'A3_override', []);
stage = 5;
A3_setup

want = [vrx_thr_topic, vrx_pos_topic, {vrx_odom_topic}];
tl   = ros2('topic', 'list');
miss = want(~ismember(want, tl));
if ~isempty(miss)
    fprintf(2, '\n보이지 않는 토픽\n');
    fprintf(2, '  %s\n', miss{:});
    error(['가제보가 떠 있지 않거나 도메인이 다릅니다.\n' ...
           '  - WSL 터미널에서 run_vrx.sh lite 가 돌고 있는지\n' ...
           '  - 그 터미널의 ROS_DOMAIN_ID 가 %d 인지\n' ...
           '  - 경량 모델(W03_vrx_lite)인지 — 선수추진기 토픽은 쓰지 않습니다'], DOMAIN);
end
fprintf('[1] 토픽 %d 개 확인\n', numel(want));

%  일시정지를 푼다 — **멈춘 세계는 오류를 내지 않는다**
%    토픽도 명령도 다 받으면서 물리만 멈춰 있다. 실측 각도가 전부 0 으로
%    나오면 부호나 토픽을 의심하기 전에 이것부터 본다 (2026-11-13 실제 사례)
vrx_play(vrx_partition, vrx_world);

%% [2] 1부 — 순수 MATLAB 으로 각도를 보내고 실제 각도를 읽는다
%    조인트 이름은 가제보가 정한 것이다. 좌·우 두 개만 쓴다
JL = 'wamv/left_chassis_engine_joint';
JR = 'wamv/right_chassis_engine_joint';

node = ros2node('/a3_tilt_check', DOMAIN);
pL = ros2publisher(node, vrx_pos_topic{1}, 'std_msgs/Float64');
pR = ros2publisher(node, vrx_pos_topic{2}, 'std_msgs/Float64');
tL = ros2publisher(node, vrx_thr_topic{1}, 'std_msgs/Float64');
tR = ros2publisher(node, vrx_thr_topic{2}, 'std_msgs/Float64');
sJ = ros2subscriber(node, '/wamv/joint_states', 'sensor_msgs/JointState');

pause(1);                 % 발행자와 구독자가 서로를 찾을 시간. 이것이 없으면
                          %   **첫 메시지가 버려진다** (기본 QoS 는 깊이 1 · 휘발성)

%  시간이 흐르는지 확인 — 조인트 상태의 시각이 올라가야 한다
j1 = receive(sJ, 5);   pause(0.7);   j2 = receive(sJ, 5);
dt = double(j2.header.stamp.sec - j1.header.stamp.sec) + ...
     double(j2.header.stamp.nanosec - j1.header.stamp.nanosec) * 1e-9;
fprintf('    시뮬레이션 시간 %.2f 초 경과 (0.7 초 사이)\n', dt);
if dt < 0.05
    error(['가제보 시간이 흐르지 않습니다 — 세계가 멈춰 있습니다.\n' ...
           '  가제보 창의 재생(▶) 단추를 누르거나, GZ_PARTITION 이 %s 인지 보십시오.\n' ...
           '  멈춘 세계는 명령을 받으면서 조인트만 0 으로 머물러, 오류 없이 틀립니다'], ...
          vrx_partition);
end

msg = ros2message('std_msgs/Float64');
msg.data = 0;   send(tL, msg);   send(tR, msg);   % 추력 0 — 배를 세워 둔다

fprintf('\n[2] 1부 — 지령과 실측 (MATLAB 직접 발행)\n');
fprintf('    %-9s %-9s | %-9s %-9s | %s\n', ...
        '지령 dL', '지령 dR', '실측 dL', '실측 dR', '한계');
got = nan(size(tilt_deg));
for i = 1:size(tilt_deg, 1)
    %  설계 한계 ±d_max_deg 를 **보내기 전에** 건다 — 모델의 TiltFcn 과 같은 줄
    cmd = max(min(tilt_deg(i,:), d_max_deg), -d_max_deg);

    %  pos = vrx_pos_sign * delta  (부호 뒤집기 — parts/addPosSign.m 과 같은 식)
    msg.data = vrx_pos_sign * deg2rad(cmd(1));   send(pL, msg);
    msg.data = vrx_pos_sign * deg2rad(cmd(2));   send(pR, msg);
    pause(tilt_hold);

    j = receive(sJ, 5);
    got(i,1) = rad2deg(j.position(strcmp(j.name, JL))) / vrx_pos_sign;
    got(i,2) = rad2deg(j.position(strcmp(j.name, JR))) / vrx_pos_sign;

    if any(abs(tilt_deg(i,:)) > d_max_deg + 1e-6)
        lim = sprintf('요구 %+.0f/%+.0f -> 깎임', tilt_deg(i,1), tilt_deg(i,2));
    else
        lim = '';
    end
    fprintf('    %+9.1f %+9.1f | %+9.1f %+9.1f | %s\n', ...
            cmd(1), cmd(2), got(i,1), got(i,2), lim);
end

e_tilt = max(abs(got - max(min(tilt_deg, d_max_deg), -d_max_deg)), [], 'all');
fprintf('    지령 대비 최대 오차 %.3f deg\n', e_tilt);
if e_tilt > 1.0
    fprintf(2, '    오차가 큽니다 — 유지 시간(tilt_hold)이 짧거나 부호가 반대입니다\n');
end

%  중립으로 되돌리고 추력도 0 으로 — 플러그인은 **마지막 명령을 계속 쓴다**
msg.data = 0;
send(pL, msg);   send(pR, msg);   send(tL, msg);   send(tR, msg);
pause(1);
clear sJ pL pR tL tR node

%% [3] 2부 — Simulink 로 같은 표를 돌린다
%    1부가 맞았는데 여기서 서보가 안 돌면, 원인은 토픽이 아니라 **도메인**이다
fprintf('\n[3] 2부 — Simulink (%s) %.0f 초\n', mdl, T_run);
load_system(mdl);
set_param(mdl, 'EnablePacing', 'on', 'PacingRate', '1', ...
               'StopTime', num2str(T_run));

%  Simulink 가 도는 동안 MATLAB 은 묶인다 — 실측 각도는 **바깥에서** 받아 둔다
cap = vrx_js_capture(T_run + 2);
out = sim(mdl);
[tg, gL, gR] = vrx_js_read(cap);

dL_log = squeeze(out.log_dL.Data);   dR_log = squeeze(out.log_dR.Data);
fprintf('    보낸 각도 범위 — dL [%+.1f, %+.1f] · dR [%+.1f, %+.1f] deg\n', ...
        rad2deg(min(dL_log)), rad2deg(max(dL_log)), ...
        rad2deg(min(dR_log)), rad2deg(max(dR_log)));
fprintf('    설계 한계 ±%.0f deg — 표의 ±60 deg 줄이 여기서 깎였다\n', d_max_deg);

%  가제보가 실제로 돈 각도 — 조인트값을 delta 로 되돌려 본다 (pos = sign * delta)
gLd = [];  gRd = [];
if ~isempty(tg)
    gLd = gL / vrx_pos_sign;   gRd = gR / vrx_pos_sign;
    fprintf('    가제보 실측 범위 — dL [%+.1f, %+.1f] · dR [%+.1f, %+.1f] deg (%d 표본)\n', ...
            min(gLd), max(gLd), min(gRd), max(gRd), numel(tg));
    nover = nnz(abs([gLd; gRd]) > d_max_deg + 0.5);
    fprintf('    한계 ±%.0f deg 를 넘은 표본 %d 개 — 0 이어야 한다\n', d_max_deg, nover);
    if nover > 0
        fprintf(2, ['    변화율을 깎지 않으면 서보가 울렁거려 한계를 넘는다 — ' ...
                    'svo_rate_deg(%.0f deg/s) 를 확인하십시오\n'], svo_rate_deg);
    end
end

%% [4] 그림 — 지령·실측·Simulink 세 줄을 한 장에
f = figure('Name', '5단 — 서보 틸팅 확인', 'Position', [100 100 980 420]);
tiledlayout(f, 1, 2, 'TileSpacing', 'compact');
nm = {'좌현 dL', '우현 dR'};
for k = 1:2
    nexttile; hold on; grid on
    stairs((0:size(tilt_deg,1)-1)*tilt_hold, tilt_deg(:,k), ...
           'Color', [.6 .6 .6], 'LineWidth', 1.2);
    stairs((0:size(tilt_deg,1)-1)*tilt_hold, ...
           max(min(tilt_deg(:,k), d_max_deg), -d_max_deg), 'k', 'LineWidth', 1.6);
    stairs((0:size(tilt_deg,1)-1)*tilt_hold, got(:,k), 'o-', ...
           'Color', [0.86 0.15 0.15], 'LineWidth', 1.2);
    if k == 1, dd = rad2deg(dL_log); else, dd = rad2deg(dR_log); end
    plot(out.log_dL.Time, dd, '--', 'Color', [0.11 0.31 0.85], 'LineWidth', 1.1);
    if ~isempty(tg)
        if k == 1, gg = gLd; else, gg = gRd; end
        plot(tg, gg, '-', 'Color', [0.05 0.58 0.53], 'LineWidth', 1.1);
    end
    yline([-1 1]*d_max_deg, ':', 'Color', [0.86 0.15 0.15]);
    xlabel('시간 [s]'); ylabel('각도 [deg]'); title(nm{k});
    ylim([-70 70]);
    if k == 1
        lg = {'요구 (한계 전)','지령 (한계 후)','1부 실측 (MATLAB 발행)','2부 Simulink 발행'};
        if ~isempty(tg), lg{end+1} = '2부 실측 (가제보 조인트)'; end
        legend(lg, 'Location', 'southwest');
    end
end
exportgraphics(f, fullfile(here, 'img', 'A3_5_tilt.png'), 'Resolution', 130);
fprintf('\n[4] 그림 저장 — img/A3_5_tilt.png\n');

setappdata(0, 'A3_override', []);
