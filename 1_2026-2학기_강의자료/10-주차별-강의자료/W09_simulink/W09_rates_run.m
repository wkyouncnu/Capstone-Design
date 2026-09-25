function S = W09_rates_run(T_end)
% W09_RATES_RUN  센서 수신 주기를 Simulink 로 재고 설계값과 나란히 보여 준다.
%
%   >> W09_setup
%   >> W09_rates_run          % W09_setup 의 T_end 만큼 측정
%   >> W09_rates_run(30)      % 30초 측정
%
%   같은 시간에 터미널에서 아래를 돌려 두 값을 비교한다
%     ros2 topic hz /wamv/sensors/imu/imu/data
%
%   두 값이 비슷해야 정상이다. 둘 다 **벽시계** 기준이라
%   시뮬레이터가 느리면(RTF 가 낮으면) 설계값보다 함께 낮게 나온다 (9주차 §2-3-7).

if nargin < 1 || isempty(T_end), T_end = evalin('base','T_end'); end

m = 'W09_1_sensor_rates';

%% 1. 토픽 확인 -------------------------------------------------------
tl = ros2('topic','list');
want = {evalin('base','topic_gps'), evalin('base','topic_imu'), evalin('base','topic_wind')};
for k = 1:numel(want)
    if ~any(strcmp(tl, want{k}))
        error('%s 가 보이지 않는다. VRX 와 ROS_DOMAIN_ID 를 확인할 것.', want{k});
    end
end

%% 2. 실행 ------------------------------------------------------------
%  실시간 화면을 끄고 잰다. 이 모델은 **벽시계**로 세므로 그림 그리는 일이
%  그대로 실측 Hz 를 깎는다 (interactive-models.md §5). 끝나면 되돌린다.
%  화면을 보고 싶으면 이 함수 대신 모델을 직접 Run 한다 (2-8-3 절).
anim0 = 1;
try, anim0 = evalin('base','animate'); catch, end
assignin('base','animate', 0);
c = onCleanup(@() assignin('base','animate', anim0));

fprintf('%s 실행 (%g초, 벽시계, 실시간 화면 끔)\n', m, T_end);
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
         '  주기를 결정하고 있다는 뜻이다 (9주차 §2-3-7).\n']);
end
