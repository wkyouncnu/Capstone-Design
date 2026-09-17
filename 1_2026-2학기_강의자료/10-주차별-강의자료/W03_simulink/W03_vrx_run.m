function S = W03_vrx_run(model, T_end)
% W03_VRX_RUN  VRX 와 연동해 3주차 모델을 돌리고 결과를 그린다.
%
%   >> W03_setup
%   >> W03_vrx_run                      % W03_3_vrx_drive 를 W03_setup 의 T_end 만큼
%   >> W03_vrx_run('W03_2_vrx_nav')     % 추력 없이 관측만
%   >> W03_vrx_run('W03_3_vrx_drive', 60)
%
%   이 스크립트가 대신 해 주는 것
%     1. VRX 토픽이 보이는지 확인        (안 보이면 여기서 멈춘다)
%     2. RTF 를 실제로 측정              (GPS 헤더 스탬프 / 벽시계)
%     3. 페이싱을 RTF 에 맞춰 실행       (시뮬레이터보다 빨리 가지 않게)
%     4. 결과 그림과 수치
%
%   실행 전에 VRX 가 떠 있어야 한다 (3주차 §2-3)
%     ros2 launch vrx_gz competition.launch.py world:=sydney_regatta

if nargin < 1 || isempty(model), model = 'W03_3_vrx_drive'; end
if nargin < 2 || isempty(T_end), T_end = evalin('base','T_end'); end

TOP_GPS = '/wamv/sensors/gps/gps/fix';
TOP_IMU = '/wamv/sensors/imu/imu/data';

%% 1. 토픽 확인 -------------------------------------------------------
fprintf('1) VRX 토픽 확인\n');
tl = ros2('topic','list');
for top = {TOP_GPS, TOP_IMU}
    if ~any(strcmp(tl, top{1}))
        error(['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가 (W03_setup 의 ros_domain_id)'], top{1});
    end
end
fprintf('   OK — 토픽 %d개\n', numel(tl));

%% 2. RTF 측정 --------------------------------------------------------
fprintf('2) RTF 측정 (10초)\n');
RTF = measureRTF(TOP_GPS, 10);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 ------------------------------------------------------------
fprintf('3) %s 실행 (%g초)\n', model, T_end);
load_system(model);
set_param(model, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
                 'StopTime', num2str(T_end));
out = sim(model);

%% 4. 추력 정지 -------------------------------------------------------
% 추진기 플러그인은 **마지막 값을 유지**한다. 시뮬레이션이 끝나도 배가 계속 간다.
% 다음 실험이 엉뚱한 자리에서 시작하지 않도록 0 을 보내고 끝낸다
if strcmp(model, 'W03_3_vrx_drive')
    stopThrusters();
end

%% 5. 결과 ------------------------------------------------------------
sc = evalin('base','scenario');
if sc == 1, name = '직진'; else, name = '좌선회'; end
S = W03_plot(out, sprintf('%s / %s', model, name));
S.RTF = RTF;
S.out = out;
end

% ---------------------------------------------------------------------
function stopThrusters()
% 좌·우 추진기에 0 N 을 몇 번 보낸다. 한 번만 보내면 놓칠 수 있다
n  = ros2node('/w03_stop', str2double(getenv('ROS_DOMAIN_ID')));
pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
msg = ros2message(pl);  msg.data = 0;
for k = 1:5
    send(pl, msg);  send(pr, msg);  pause(0.1);
end
clear pl pr n
fprintf('   추력 0 송신 완료\n');
end

% ---------------------------------------------------------------------
function RTF = measureRTF(topic, secs)
% 시뮬레이터 시각(헤더 스탬프)이 벽시계 대비 얼마나 빨리 가는지 잰다
n  = ros2node('/w03_rtf_probe', str2double(getenv('ROS_DOMAIN_ID')));
s  = ros2subscriber(n, topic, 'sensor_msgs/NavSatFix');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(secs);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
clear s n
RTF = min(max(RTF, 0.05), 1.0);      % 페이싱에 넣을 값이므로 범위를 자른다
end
