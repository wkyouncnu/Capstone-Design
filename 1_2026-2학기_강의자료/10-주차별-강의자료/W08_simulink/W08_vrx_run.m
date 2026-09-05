function S = W08_vrx_run(T_end, do_compare)
% W08_VRX_RUN  VRX(Gazebo) 와 연동해 W08_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W08_setup
%   >> W08_vrx_run              % 300초 주행 + 오프라인 대조
%   >> W08_vrx_run(400)
%   >> W08_vrx_run(300, false)  % 대조 없이 VRX 만
%
%   해 주는 일은 7주차 W07_vrx_run 과 같다.
%     1. 토픽 확인  2. RTF 측정  3. 페이싱 맞춰 실행(실시간 그림)
%     4. 결과 그림  5. 오프라인과 궤적 겹쳐 그리기
%
%   실행 전에 VRX 가 떠 있어야 한다.

if nargin < 1 || isempty(T_end),      T_end = 300;  end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W08_1_vrx';
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

S     = W08_plot(out, 'VRX 로이터링');
S.RTF = RTF;
saveFig(gcf, 'W08_1_vrx_result.png');

if ~do_compare, return; end
fprintf('5) 같은 초기 선수각으로 오프라인 모델 실행\n');

pn = out.log_pn.Data;  pe = out.log_pe.Data;  t = out.log_pn.Time;
k0 = find(out.log_psi.Time >= 0.5, 1);   % 첫 샘플은 odom 이 아직 안 와서 못 쓴다
psi0 = out.log_psi.Data(k0);
fprintf('   VRX 초기 선수각 %.2f deg\n', rad2deg(psi0));

x0 = evalin('base','x0');   x0(6) = psi0;   assignin('base','x0', x0);
animOld = evalin('base','animate');         assignin('base','animate', 0);
load_system('W08_0_offline');
set_param('W08_0_offline','StopTime', num2str(T_end));
o2 = sim('W08_0_offline');
assignin('base','animate', animOld);

qn = o2.log_pn.Data;  qe = o2.log_pe.Data;  t2 = o2.log_pn.Time;

% 두 시계가 겹치는 구간만 비교한다 — 밖으로 나가면 외삽이 폭주한다
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, qn, tm, 'linear');
qe_i = interp1(t2, qe, tm, 'linear');
sep  = hypot(pn(1:nm) - qn_i, pe(1:nm) - qe_i);

cn = evalin('base','center_north');  ce = evalin('base','center_east');
rd = evalin('base','r_d');
S.sep_mean = mean(sep);   S.sep_max = max(sep);
S.r_vrx    = mean(hypot(pn - cn, pe - ce));
S.r_off    = mean(hypot(qn - cn, qe - ce));

drawOverlay(pe, pn, qe, qn, tm, sep, S, T_end, cn, ce, rd);
saveFig(gcf, 'W08_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  평균 반경     오프라인 %6.2f m   VRX %6.2f m   (목표 %g)\n', ...
        S.r_off, S.r_vrx, rd);
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

function drawOverlay(pe, pn, qe, qn, t, sep, S, T_end, cn, ce, rd)
th = linspace(0, 2*pi, 361);
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(ce + rd*sin(th), cn + rd*cos(th), 'k--', 'LineWidth',1.0); hold on;
plot(ce, cn, 'k+', 'MarkerSize',10, 'LineWidth',1.2);
plot(qe, qn, 'b-', 'LineWidth',1.4);
plot(pe, pn, 'r-', 'LineWidth',1.4);
plot(pe(1), pn(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on; xlabel('East [m]'); ylabel('North [m]');
legend({'목표 원','중심','오프라인','VRX','출발'}, 'Location','best');
title(sprintf('궤적 — 평균 반경 오프 %.2f / VRX %.2f m', S.r_off, S.r_vrx));

subplot(1,2,2);
plot(t, sep, 'k-', 'LineWidth',1.3); grid on;
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격거리 (평균 %.2f / 최대 %.2f m)', S.sep_mean, S.sep_max));
end

function saveFig(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, name), 'Resolution', 130);
fprintf('   그림 저장: img/%s\n', name);
end
