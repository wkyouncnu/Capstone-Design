function S = W10_vrx_run(T_end, do_compare)
% W10_VRX_RUN  VRX(Gazebo) 와 연동해 W10_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W10_setup
%   >> W10_vrx_run              % 300초 주행 + 오프라인 대조
%   >> W10_vrx_run(400)
%   >> W10_vrx_run(300, false)  % 대조 없이 VRX 만
%
%   해 주는 일은 7주차 W07_vrx_run 과 같다.
%     1. 토픽 확인  2. RTF 측정  3. 페이싱 맞춰 실행(실시간 그림)
%     4. 결과 그림  5. 오프라인과 궤적 겹쳐 그리기
%
%   실행 전에 VRX 가 떠 있어야 한다.

if nargin < 1 || isempty(T_end),      T_end = 300;  end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W10_1_vrx';
TOP = '/wamv/sensors/position/ground_truth_odometry';

fprintf('1) VRX 토픽 확인\n');
tl = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error(['%s 가 보이지 않는다.\n' ...
           '  VRX 가 떠 있는가 / ground_truth_enabled 가 true 인가 / ' ...
           'ROS_DOMAIN_ID 가 같은가'], TOP);
end
fprintf('   OK — 토픽 %d개\n', numel(tl));

fprintf('2) RTF 측정 (20초)\n');
RTF = measureRTF(TOP, 20);
fprintf('   RTF = %.3f\n', RTF);

fprintf('3) %s 실행 (%d초)\n', m, T_end);
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);

S     = W10_plot(out, 'VRX DP');
S.RTF = RTF;
saveFig(gcf, 'W10_1_vrx_result.png');

if ~do_compare, return; end
fprintf('5) 같은 초기 선수각으로 오프라인 모델 실행\n');

t   = out.log_eta.Time;
eta = squeeze(out.log_eta.Data)';
k0   = find(t >= 0.5, 1);        % 첫 샘플은 odom 이 아직 안 와서 못 쓴다
psi0 = eta(k0,3);
fprintf('   VRX 초기 선수각 %.2f deg\n', rad2deg(psi0));

x0 = evalin('base','x0');   x0(6) = psi0;   assignin('base','x0', x0);
animOld = evalin('base','animate');         assignin('base','animate', 0);
load_system('W10_0_offline');
set_param('W10_0_offline','StopTime', num2str(T_end));
o2 = sim('W10_0_offline');
assignin('base','animate', animOld);

t2  = o2.log_eta.Time;
eo  = squeeze(o2.log_eta.Data)';
ee_v = squeeze(out.log_eta_e.Data)';
ee_o = squeeze(o2.log_eta_e.Data)';

% 두 시계가 겹치는 구간만 비교한다
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, eo(:,1), tm, 'linear');
qe_i = interp1(t2, eo(:,2), tm, 'linear');
sep  = hypot(eta(1:nm,1) - qn_i, eta(1:nm,2) - qe_i);

S.sep_mean = mean(sep);   S.sep_max = max(sep);
S.epos_vrx = mean(hypot(ee_v(:,1), ee_v(:,2)));
S.epos_off = mean(hypot(ee_o(:,1), ee_o(:,2)));

drawOverlay(eta(:,2), eta(:,1), eo(:,2), eo(:,1), tm, sep, S, T_end, ...
            squeeze(out.log_eta_d.Data)');
saveFig(gcf, 'W10_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  평균 위치 오차  오프라인 %6.3f m   VRX %6.3f m\n', S.epos_off, S.epos_vrx);
fprintf('  궤적 평균 이격 %6.2f m,  최대 %6.2f m\n', S.sep_mean, S.sep_max);
end

% =====================================================================
function RTF = measureRTF(topic, sec)
n = ros2node(sprintf('/rtf_probe_%d', randi(9999)), 0);
c = onCleanup(@() clear('n'));
s = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(sec);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end


function saveFig(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, name), 'Resolution', 130);
fprintf('   그림 저장: img/%s\n', name);
end

function drawOverlay(pe, pn, qe, qn, t, sep, S, T_end, etd)
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(etd(:,2), etd(:,1), 'k--', 'LineWidth',1.1); hold on;
plot(qe, qn, 'b-', 'LineWidth',1.4);
plot(pe, pn, 'r-', 'LineWidth',1.4);
plot(pe(1), pn(1), 'ko','MarkerFaceColor','g','MarkerSize',8);
axis equal; grid on; xlabel('East [m]'); ylabel('North [m]');
legend({'DP 목표','오프라인','VRX','출발'}, 'Location','best');
title(sprintf('DP 궤적 — %d초, 평균 이격 %.2f m', T_end, S.sep_mean));

subplot(1,2,2);
plot(t, sep, 'k-', 'LineWidth',1.3); grid on;
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격거리 (평균 %.2f / 최대 %.2f m)', S.sep_mean, S.sep_max));
end
