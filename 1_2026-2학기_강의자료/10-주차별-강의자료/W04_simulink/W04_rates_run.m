function S = W04_rates_run(T_end)
% W04_RATES_RUN  센서 수신 주기를 Simulink 로 재고 설계값과 나란히 보여 준다.
%
%   >> W04_setup
%   >> W04_rates_run          % W04_setup 의 T_end 만큼 측정
%   >> W04_rates_run(30)      % 30초 측정
%
%   같은 시간에 터미널에서 아래를 돌려 두 값을 비교한다
%     ros2 topic hz /wamv/sensors/imu/imu/data
%
%   두 값이 비슷해야 정상이다. 둘 다 **벽시계** 기준이라
%   시뮬레이터가 느리면(RTF 가 낮으면) 설계값보다 함께 낮게 나온다 (4주차 §2-3-7).

if nargin < 1 || isempty(T_end), T_end = evalin('base','T_end'); end

m = 'W04_1_sensor_rates';

%% 1. 토픽 확인 -------------------------------------------------------
tl = ros2('topic','list');
want = {evalin('base','topic_gps'), evalin('base','topic_imu'), evalin('base','topic_wind')};
for k = 1:numel(want)
    if ~any(strcmp(tl, want{k}))
        error('%s 가 보이지 않는다. VRX 와 ROS_DOMAIN_ID 를 확인할 것.', want{k});
    end
end

%% 2. 실행 ------------------------------------------------------------
fprintf('%s 실행 (%g초, 벽시계)\n', m, T_end);
load_system(m);
set_param(m, 'StopTime', num2str(T_end));
out = sim(m);

%% 3. 표 --------------------------------------------------------------
S.hz_gps  = out.log_hz_gps.Data(end);
S.hz_imu  = out.log_hz_imu.Data(end);
S.hz_wind = out.log_hz_wind.Data(end);
S.T       = out.log_hz_gps.Time(end);

d = [evalin('base','hz_design_gps'), evalin('base','hz_design_imu'), ...
     evalin('base','hz_design_wind')];
meas = [S.hz_gps, S.hz_imu, S.hz_wind];
name = {'GPS','IMU','wind'};

fprintf('\n  토픽    설계값[Hz]   Simulink 실측[Hz]   비율\n');
fprintf(  '  ----    ----------   -----------------   ----\n');
for k = 1:3
    fprintf('  %-6s %8.0f %17.2f %8.2f\n', name{k}, d(k), meas(k), meas(k)/d(k));
end
S.ratio = meas ./ d;
fprintf(['\n  세 비율이 서로 비슷하면 센서가 아니라 **시뮬레이터 속도(RTF)** 가\n' ...
         '  주기를 결정하고 있다는 뜻이다 (4주차 §2-3-7).\n']);
end
