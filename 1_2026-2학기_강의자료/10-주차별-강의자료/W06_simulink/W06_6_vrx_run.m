% W06_6_VRX_RUN  6단 — Gazebo(VRX) 와 연동해 접안을 돌리고 오프라인과 대조한다
%
%   >> W06_6_vrx_run
%
%   바뀌는 것은 운동모델 하나다. 1~5단은 오프라인 플랜트가 배를 움직였고,
%   6단은 그 자리에 Gazebo 가 들어간다 — 제어기·유도부·추력배분은 5단 그대로다.
%     추력 F_L · F_R · F_B  ->  /wamv/thrusters/*/thrust  (뉴턴)
%     자세 x_n · y_n · psi   <-  ground truth odometry     (ENU -> NED 로 바꿔 받음)
%
%   이 파일이 대신 해 주는 것
%     1. VRX 토픽이 보이는지 확인        (안 보이면 여기서 멈춘다)
%     2. RTF 를 20 초 동안 실제로 측정    (손으로 재지 않아도 된다)
%     3. 스폰 위치를 첫 샘플로 읽어 원점으로 씀 (설치마다 다르다)
%     4. 페이싱 비율을 RTF 에 맞춰 실행   (도는 동안 실시간 그림이 뜬다)
%     5. 결과 그림 + 5단 오프라인과 궤적 대조
%
%   실행 전에 WSL 에서 VRX 가 떠 있어야 한다.
%     ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
%          urdf:=$HOME/capstone_ws/wamv/w7_wamv.urdf.xacro
setappdata(0, 'W06_stage', 6);
setappdata(0, 'W06_skip_run', true);
W06_setup

TOPIC = '/wamv/sensors/position/ground_truth_odometry';

%% 1. 토픽 확인 -------------------------------------------------------
%  Simulink ROS 블록은 'ROS 네트워크 프로필' 의 Domain ID 를, MATLAB 의 ros2*
%  함수는 환경변수 ROS_DOMAIN_ID 를 쓴다. 둘이 다르면 토픽이 보이지 않는다.
fprintf('\n1) ROS_DOMAIN_ID = %s — 토픽 확인\n', getenv('ROS_DOMAIN_ID'));
topic_list = ros2('topic', 'list');
if ~any(strcmp(topic_list, TOPIC))
    error(['%s 가 보이지 않는다.\n' ...
           '  - VRX 가 떠 있는가\n' ...
           '  - ground_truth_enabled 를 true 로 바꾼 urdf 로 띄웠는가\n' ...
           '  - WSL 의 echo $ROS_DOMAIN_ID 가 %s 인가'], TOPIC, getenv('ROS_DOMAIN_ID'));
end
fprintf('   OK — 토픽 %d 개\n', numel(topic_list));

%% 2. RTF 측정과 스폰 위치 읽기 ----------------------------------------
fprintf('2) RTF 측정 (20 초)\n');
probe_node = ros2node(sprintf('/w06_rtf_probe_%d', randi(9999)));
probe_sub  = ros2subscriber(probe_node, TOPIC, 'nav_msgs/Odometry');
msg0 = receive(probe_sub, 15);   wall = tic;
t_sim0 = double(msg0.header.stamp.sec) + double(msg0.header.stamp.nanosec)*1e-9;
pause(20);
msg1 = receive(probe_sub, 15);   t_wall = toc(wall);
t_sim1 = double(msg1.header.stamp.sec) + double(msg1.header.stamp.nanosec)*1e-9;
RTF = (t_sim1 - t_sim0) / t_wall;
clear probe_sub probe_node

%  스폰 좌표는 설치마다 다르다 (같은 2.4.0-2 인데 한 컴퓨터는 ENU y = 162,
%  다른 컴퓨터는 200 — 2026-09-18). 고정값을 쓰면 접안 목표가 통째로 밀린다.
origin_north = msg0.pose.pose.position.y;     % ENU y -> NED x (북)
origin_east  = msg0.pose.pose.position.x;     % ENU x -> NED y (동)
fprintf('   스폰 위치 (N, E) = (%.2f, %.2f) m — 이 점을 원점으로 쓴다\n', ...
        origin_north, origin_east);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 ------------------------------------------------------------
fprintf('3) %s 실행 (최대 %g 초)\n', mdl, T_run);
load_system(mdl);
set_param(mdl, 'EnablePacing', 'on', 'PacingRate', num2str(RTF));
out = sim(mdl);

%% 4. 결과 그림 -------------------------------------------------------
S     = W06_plot(out, sprintf('%d단 — %s (RTF %.2f)', stage, stage_name{stage}, RTF));
S.RTF = RTF;

t_vrx = out.log_x_n.Time;
x_vrx = out.log_x_n.Data;   y_vrx = out.log_y_n.Data;
setappdata(0, 'W06_vrx_log', [t_vrx(:), x_vrx(:), y_vrx(:)]);
setappdata(0, 'W06_vrx_S',   S);

%% 5. 5단 오프라인과 대조 ---------------------------------------------
%  W06_setup 이 base 를 비우므로 VRX 결과는 위에서 appdata 로 옮겨 두었다
fprintf('5) 5단 오프라인 모델 실행 (같은 접안 임무, 운동모델만 오프라인)\n');
setappdata(0, 'W06_stage', 5);
setappdata(0, 'W06_skip_run', true);
W06_setup
animate = 0;                       % 대조용이라 실시간 그림은 끈다
load_system(mdl);
out_off = sim(mdl);
S_off = W06_plot(out_off, '5단 오프라인 대조');

L = getappdata(0, 'W06_vrx_log');   S = getappdata(0, 'W06_vrx_S');
t_vrx = L(:,1);   x_vrx = L(:,2);   y_vrx = L(:,3);
t_off = out_off.log_x_n.Time;
x_off = out_off.log_x_n.Data;   y_off = out_off.log_y_n.Data;

%  두 시계가 겹치는 구간만 본다 — 밖으로 나가면 외삽이 폭주한다
tm = t_vrx(t_vrx <= t_off(end));
sep = hypot(x_vrx(1:numel(tm)) - interp1(t_off, x_off, tm), ...
            y_vrx(1:numel(tm)) - interp1(t_off, y_off, tm));

figure('Name', 'W06  6단 오프라인 vs VRX', 'Color', 'w', 'Position', [80 80 1000 440]);
subplot(1,2,1);
plot(y_off, x_off, 'b-', 'LineWidth', 1.6); hold on;
plot(y_vrx, x_vrx, 'r-', 'LineWidth', 1.6);
plot(dock_east, dock_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
plot(app_east,  app_north,  'go', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({'5단 오프라인', '6단 VRX', '선석', '접근점'}, 'Location', 'best');
title(sprintf('접안 궤적 — 평균 이격 %.2f m', mean(sep)));

subplot(1,2,2);
plot(tm, sep, 'k-', 'LineWidth', 1.4); grid on;
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격거리 (평균 %.2f / 최대 %.2f m)', mean(sep), max(sep)));

fprintf('\n[6단 점검] RTF %.3f,  스폰 원점 (N, E) = (%.2f, %.2f) m\n', ...
        S.RTF, origin_north, origin_east);
fprintf('           VRX      끝 오차 %.3f m / %.2f deg,  완료 %s\n', ...
        S.e_final, S.epsi_final, mat2str(round(S.t_done, 2)));
fprintf('           오프라인 끝 오차 %.3f m / %.2f deg,  완료 %s\n', ...
        S_off.e_final, S_off.epsi_final, mat2str(round(S_off.t_done, 2)));
fprintf('           궤적 평균 이격 %.2f m,  최대 %.2f m\n', mean(sep), max(sep));
fprintf('           이격이 크면 먼저 볼 것 — 스폰 원점, 추력 토픽 부호, RTF\n');
