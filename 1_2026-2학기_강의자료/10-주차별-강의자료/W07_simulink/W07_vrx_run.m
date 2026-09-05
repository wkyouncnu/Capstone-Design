function S = W07_vrx_run(T_end, do_compare)
% W07_VRX_RUN  VRX(Gazebo) 와 연동해 W07_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W07_setup
%   >> W07_vrx_run              % 150초 주행 + 오프라인 대조
%   >> W07_vrx_run(200)         % 200초
%   >> W07_vrx_run(150, false)  % 대조 없이 VRX 만
%
%   이 스크립트가 대신 해 주는 것
%     1. VRX 토픽이 보이는지 확인          (안 보이면 여기서 멈춘다)
%     2. RTF 를 20초 동안 실제로 측정       (손으로 재지 않아도 된다)
%     3. 페이싱 비율을 RTF 에 맞춰 실행     (도는 동안 실시간 그림이 뜬다)
%     4. 끝나면 오프라인과 같은 형식의 결과 그림
%     5. 같은 초기 선수각으로 오프라인을 돌려 두 궤적을 겹쳐 그림
%
%   실행 전에 VRX 가 떠 있어야 한다.
%     ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
%          urdf:=$HOME/capstone_ws/wamv/w7_wamv.urdf.xacro

if nargin < 1 || isempty(T_end),     T_end = 150;   end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W07_1_vrx';
TOP = '/wamv/sensors/position/ground_truth_odometry';

%% 1. 토픽 확인 -------------------------------------------------------
fprintf('1) VRX 토픽 확인\n');
tl = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error(['%s 가 보이지 않는다.\n' ...
           '  - VRX 가 떠 있는가\n' ...
           '  - ground_truth_enabled 를 true 로 바꾼 urdf 로 띄웠는가\n' ...
           '  - ROS_DOMAIN_ID 가 양쪽 같은가'], TOP);
end
fprintf('   OK — 토픽 %d개\n', numel(tl));

%% 2. RTF 측정 --------------------------------------------------------
fprintf('2) RTF 측정 (20초)\n');
RTF = measureRTF(TOP, 20);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 ------------------------------------------------------------
fprintf('3) %s 실행 (%d초)\n', m, T_end);
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);

%% 4. 결과 그림 -------------------------------------------------------
S     = W07_plot(out, sprintf('VRX / %s 유도', modeName()));
S.RTF = RTF;
saveFig(gcf, 'W07_1_vrx_result.png');

%% 5. 오프라인과 대조 --------------------------------------------------
if ~do_compare, return; end
fprintf('5) 같은 초기 선수각으로 오프라인 모델 실행\n');

pn = out.log_pn.Data;  pe = out.log_pe.Data;  t = out.log_pn.Time;
k0 = find(out.log_psi.Time >= 0.5, 1);   % 첫 샘플은 odom 이 아직 안 와서 못 쓴다
psi0 = out.log_psi.Data(k0);
fprintf('   VRX 초기 선수각 %.2f deg\n', rad2deg(psi0));

x0 = evalin('base','x0');   x0(6) = psi0;
assignin('base','x0', x0);
animOld = evalin('base','animate');   assignin('base','animate', 0);
load_system('W07_0_offline');
set_param('W07_0_offline','StopTime', num2str(T_end));
o2 = sim('W07_0_offline');
assignin('base','animate', animOld);

qn = o2.log_pn.Data;  qe = o2.log_pe.Data;  t2 = o2.log_pn.Time;

% 같은 시각으로 맞춰 이격거리를 잰다.
% 두 시계가 겹치는 구간만 본다 — 밖으로 나가면 외삽이 폭주한다.
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, qn, tm, 'linear');
qe_i = interp1(t2, qe, tm, 'linear');
sep  = hypot(pn(1:nm) - qn_i, pe(1:nm) - qe_i);

S.sep_mean = mean(sep);
S.sep_max  = max(sep);
S.dist_vrx = sum(hypot(diff(pn), diff(pe)));
S.dist_off = sum(hypot(diff(qn), diff(qe)));

drawOverlay(pe, pn, qe, qn, tm, sep, S, T_end);
saveFig(gcf, 'W07_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  주행거리      오프라인 %7.1f m   VRX %7.1f m\n', S.dist_off, S.dist_vrx);
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

function s = modeName()
if evalin('base','guidance_mode') == 1, s = 'atan2'; else, s = 'LOS'; end
end

function drawOverlay(pe, pn, qe, qn, t, sep, S, T_end)
wpn = evalin('base','wp_north');   wpe = evalin('base','wp_east');
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(wpe, wpn, 'ks--', 'MarkerFaceColor','w', 'LineWidth',1.0); hold on;
plot(qe, qn, 'b-', 'LineWidth',1.6);
plot(pe, pn, 'r-', 'LineWidth',1.6);
plot(pe(1), pn(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on;
xlabel('East [m]'); ylabel('North [m]');
legend({'웨이포인트','오프라인 운동모델','VRX (Gazebo)','출발'}, 'Location','best');
title(sprintf('궤적 — %d초, 평균 이격 %.2f m', T_end, S.sep_mean));

subplot(1,2,2);
plot(t, sep, 'k-', 'LineWidth',1.4); grid on;
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격거리 (평균 %.2f / 최대 %.2f m)', S.sep_mean, S.sep_max));
end

function saveFig(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, name), 'Resolution', 130);
fprintf('   그림 저장: img/%s\n', name);
end
