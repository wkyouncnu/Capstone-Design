function R = W06_step_compare(stage, T_end)
% W06_STEP_COMPARE  3·4단계 제어기를 오프라인 쌍둥이로 먼저 돌리고, VRX 가 떠 있으면 같은 것을 VRX 로 돌려 겹친다.
%
%   >> R = W06_step_compare(3)        % 헤딩 제어       W06_3_heading_offline  -> W06_3_heading
%   >> R = W06_step_compare(4)        % 속도 + 헤딩     W06_4_inner_loop_offline -> W06_4_inner_loop
%   >> R = W06_step_compare(3, 40)    % 40 초 (기본)
%
%   순서 — 6주차 H·I 절
%     1) 오프라인 쌍둥이 (운동방정식, 초기 선수각 32.7 deg = VRX 스폰)  -> 1 초 안쪽
%     2) VRX 토픽이 보이면 같은 제어기의 VRX 모델을 실측 RTF 로 페이싱해 T_end 초
%        VRX 는 실험마다 새로 띄울 것 (스폰 자세에서 시작해야 같은 계단이 된다)
%     3) 두 결과의 지표와 그림
%
%   지표 (헤딩)  계단 크기, 오버슈트 [%], 2 % 정착시간 [s], 마지막 5 초 평균 선수각
%   지표 (속도)  0 -> u_ref 의 63 % 도달 시각, 마지막 5 초 평균 u

if nargin < 1 || isempty(stage), stage = 3; end
if nargin < 2 || isempty(T_end), T_end = 40; end
here = fileparts(mfilename('fullpath'));  cd(here);
if stage == 3
    mOff = 'W06_3_heading_offline';     mVrx = 'W06_3_heading';
else
    mOff = 'W06_4_inner_loop_offline';  mVrx = 'W06_4_inner_loop';
end

fprintf('1) 오프라인 쌍둥이 %s (%g 초)\n', mOff, T_end);
load_system(mOff);
oOff = sim(mOff, 'StopTime', num2str(T_end));
R.off = metrics(oOff, stage);
report('오프라인', R.off, stage);

R.vrx = [];
TOP = '/wamv/sensors/position/ground_truth_odometry';
try
    tl = ros2('topic','list');
catch
    tl = {};
end
if ~any(strcmp(tl, TOP))
    fprintf('\n2) VRX 토픽(%s)이 보이지 않아 오프라인만 돌렸다.\n', TOP);
    plotBoth(oOff, [], stage, R);
    return
end

fprintf('\n2) VRX %s — RTF 측정 (10초)\n', mVrx);
RTF = measureRTF(TOP, 10);
fprintf('   RTF = %.3f  ->  페이싱 비율\n', RTF);
load_system(mVrx);
set_param(mVrx, 'EnablePacing','on', 'PacingRate', num2str(RTF), 'StopTime', num2str(T_end));
oVrx = sim(mVrx);
set_param(mVrx, 'StopTime','inf');
stopThrusters();
R.vrx = metrics(oVrx, stage);
R.RTF = RTF;
report('VRX', R.vrx, stage);
plotBoth(oOff, oVrx, stage, R);
end

% ---------------------------------------------------------------------
function M = metrics(o, stage)
t   = o.log_psi.Time;
psi = unwrap(squeeze(o.log_psi.Data));
% VRX 는 첫 odom 이 오기 전 쿼터니언이 0 이다. Quat2Yaw 가 그것을 정확히 90 deg 로 바꾼다
k0  = find(abs(psi - pi/2) > 1e-9 & abs(psi) > 1e-9, 1);
if isempty(k0), k0 = 1; end
M.psi0 = rad2deg(psi(k0));
ref = 45;
M.step = ref - M.psi0;
pd  = rad2deg(psi(k0:end));   tt = t(k0:end) - t(k0);
over = max((pd - M.psi0)/M.step) - 1;
M.overshoot = 100*max(over, 0);
band = 0.02*abs(M.step);
out = find(abs(pd - ref) > band, 1, 'last');
if isempty(out), M.t_settle = 0; else, M.t_settle = tt(min(out+1, numel(tt))); end
M.psi_end = mean(pd(tt > tt(end) - 5));
M.t = tt;  M.psi = pd;
if stage == 4
    u = squeeze(o.log_u.Data);  u = u(k0:end);
    M.u_end = mean(u(tt > tt(end) - 5));
    i63 = find(u >= 0.632*1.5, 1);
    if isempty(i63), M.t_u63 = NaN; else, M.t_u63 = tt(i63); end
    M.u = u;
end
end

function report(name, M, stage)
fprintf('   [%s] 초기 %.1f deg -> 45 deg (계단 %.1f deg), 오버슈트 %.1f %%, 2%% 정착 %.1f s, 마지막 5 s 평균 %.2f deg\n', ...
        name, M.psi0, M.step, M.overshoot, M.t_settle, M.psi_end);
if stage == 4
    fprintf('   [%s] u 63 %% 도달 %.1f s, 마지막 5 s 평균 u %.3f m/s\n', name, M.t_u63, M.u_end);
end
end

function plotBoth(oOff, oVrx, stage, R)
f = figure('Name', sprintf('W06 %d단계 — 오프라인 vs VRX', stage), 'Color','w', 'Position',[80 80 900 400+200*(stage==4)]);
n = 1 + (stage == 4);
subplot(n,1,1); hold on; grid on;
plot(R.off.t, R.off.psi, 'b-', 'LineWidth',1.5);
if ~isempty(R.vrx), plot(R.vrx.t, R.vrx.psi, 'r--', 'LineWidth',1.5); end
yline(45, 'k:');
ylabel('\psi [deg]'); legend([{'오프라인 쌍둥이'}, repmat({'VRX'},1,~isempty(R.vrx)), {'목표 45°'}], 'Location','southeast');
title(sprintf('%d단계 헤딩 — 초기 선수각 %.1f° 에서 45° 로', stage, R.off.psi0), 'FontWeight','normal');
if stage == 4
    subplot(2,1,2); hold on; grid on;
    plot(R.off.t, R.off.u, 'b-', 'LineWidth',1.5);
    if ~isempty(R.vrx), plot(R.vrx.t, R.vrx.u, 'r--', 'LineWidth',1.5); end
    yline(1.5, 'k:');
    ylabel('u [m/s]'); legend([{'오프라인 쌍둥이'}, repmat({'VRX'},1,~isempty(R.vrx)), {'목표 1.5'}], 'Location','southeast');
end
xlabel('시간 [s]');
d = fullfile(fileparts(mfilename('fullpath')), 'img');
exportgraphics(f, fullfile(d, sprintf('W06_%d_offline_vs_vrx.png', stage)), 'Resolution', 110);
fprintf('   그림 저장: img/W06_%d_offline_vs_vrx.png\n', stage);
end

function RTF = measureRTF(topic, secs)
n  = ros2node('/w06_rtf_probe', str2double(getenv('ROS_DOMAIN_ID')));
s  = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(secs);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = min(max((t1 - t0)/dw, 0.05), 1.0);
clear s n
end

function stopThrusters()
% 추진기 플러그인은 마지막 값을 유지한다 — 끝나면 0 을 몇 번 보낸다
n  = ros2node('/w06_stop', str2double(getenv('ROS_DOMAIN_ID')));
pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
msg = ros2message(pl);  msg.data = 0;
for k = 1:5, send(pl, msg); send(pr, msg); pause(0.1); end
clear pl pr n
end
