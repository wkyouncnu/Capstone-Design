function S = W07_vrx_run(T_end, do_compare, show)
% W07_VRX_RUN  VRX(Gazebo) 와 연동해 W07_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W07_setup
%   >> W07_vrx_run                 % 300초 주행 + 오프라인 대조
%   >> W07_vrx_run(400)
%   >> W07_vrx_run(300, false)     % 대조 없이 VRX 만
%   >> W07_vrx_run(300, true, 1)   % 실시간 화면을 켜고 (빠른 PC 에서만)
%
%   해 주는 일은 5주차 W05_vrx_run 과 같다.
%     1. 토픽 확인  2. RTF 측정  3. 페이싱 맞춰 실행(실시간 화면은 기본으로 끔)
%     4. 결과 그림 + 동기 점검 k · 걸림 검사 · 물체 이격  5. 오프라인과 궤적 겹쳐 그리기
%
%   실시간 화면을 기본으로 끄는 까닭 (2026-11-01 노트북 실측)
%     화면을 켠 채 돌리면 300 s 모델에 벽시계 538 s 가 걸려 Simulink 가 VRX 를
%     못 따라갔다. 같은 원을 돌았는데 두 바퀴를 193.1 s 에 끝내(오프라인 241.8 s)
%     궤적 평균 이격이 26 m 로 나왔다. 도는 모습은 오프라인 모델(W07_setup)의
%     실시간 화면으로 본다.
%
%   실행 전에 WSL 에서 VRX 가 떠 있어야 한다 (3주차 경량 모델, 실험마다 새로).
%     cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite
%     bash stop_vrx.sh && bash run_vrx.sh

if nargin < 1 || isempty(T_end),      T_end = 300;  end
if nargin < 2 || isempty(do_compare), do_compare = true; end
if nargin < 3 || isempty(show),       show = 0;      end
animUser = evalin('base','animate');               % 끝나면 W07_setup 값으로 되돌린다
assignin('base', 'animate', show);
cRestore = onCleanup(@() assignin('base','animate', animUser));

m   = 'W07_1_vrx';
TOP = '/wamv/sensors/position/ground_truth_odometry';

% ---------------------------------------------------------------------
%  ROS 2 도메인 맞추기 — Simulink 블록은 'ROS 네트워크 프로필'의 Domain ID 를
%  쓰고, MATLAB 의 ros2* 함수는 환경변수 ROS_DOMAIN_ID(기본 0)를 쓴다.
%  둘이 다르면 토픽이 보이지 않는다. 프로필 값으로 환경변수를 맞춘다.
% ---------------------------------------------------------------------
try
    prof = getpref('ROS_Toolbox','ROS_NetworkAddress_Profiles');
    if ~isempty(prof) && isfield(prof{1},'DomainID')
        setenv('ROS_DOMAIN_ID', num2str(double(prof{1}.DomainID)));
    end
catch
end
if isempty(getenv('ROS_DOMAIN_ID')), setenv('ROS_DOMAIN_ID','0'); end
fprintf('0) ROS_DOMAIN_ID = %s\n', getenv('ROS_DOMAIN_ID'));

fprintf('1) VRX 토픽 확인\n');
tl = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error(['%s 가 보이지 않는다.\n' ...
           '  VRX 가 떠 있는가 / ground_truth_enabled 가 true 인가 / ' ...
           'ROS_DOMAIN_ID 가 같은가'], TOP);
end
fprintf('   OK — 토픽 %d개\n', numel(tl));

fprintf('2) RTF 측정 (20초)\n');
[RTF, x0_n, y0_n] = measureRTF(TOP, 20);
% 스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다 다르다
% (같은 2.4.0-2 인데 한 컴퓨터는 ENU y = 162, 다른 컴퓨터는 200 — 2026-09-18).
% 고정값을 쓰면 그 차이만큼 경로가 통째로 밀려 안전 수역을 벗어난다.
assignin('base', 'origin_north', x0_n);
assignin('base', 'origin_east',  y0_n);
fprintf('   스폰 위치 (x, y) = (%.1f, %.1f) m — 이 점을 원점으로 쓴다\n', x0_n, y0_n);
fprintf('   RTF = %.3f\n', RTF);

fprintf('3) %s 실행 (%d초)\n', m, T_end);
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);

fprintf('4) 결과 그림\n');
S     = W07_plot(out, 'VRX 로이터링');
S.RTF = RTF;
saveFig(S.fig, 'W07_1_vrx_result.png');    % gcf 는 추진기 창이다 — 궤적 창을 저장한다
S.k_sync = syncCheck(out);
[S.stuck_s, S.clear_m, S.clear_obj, S.world] = landCheck(out, x0_n, y0_n, S.t_done);

if ~do_compare, return; end
fprintf('5) 같은 초기 선수각으로 오프라인 모델 실행\n');

x_n = out.log_x_n.Data;  y_n = out.log_y_n.Data;  t = out.log_x_n.Time;
% odom 이 오기 전의 샘플은 0 이다. 도착 시각은 실행마다 다르므로 (0.5 s 를 넘길 때도 있다)
% 시각으로 자르지 않고 처음으로 0 이 아닌 선수각을 쓴다
k0 = find(abs(out.log_psi.Data(:)) > 1e-9, 1);
if isempty(k0), k0 = 1; end
psi0 = out.log_psi.Data(k0);
fprintf('   VRX 초기 선수각 %.2f deg\n', rad2deg(psi0));

x0old = evalin('base','x0');   x0 = x0old;   x0(6) = psi0;   assignin('base','x0', x0);
animOld = evalin('base','animate');         assignin('base','animate', 0);
load_system('W07_0_offline');
o2 = sim('W07_0_offline', 'StopTime', num2str(T_end));   % 모델에 저장된 정지 시간은 건드리지 않는다
assignin('base','animate', animOld);
assignin('base','x0', x0old);   % 되돌린다 — 이 뒤에 오프라인을 다시 돌려도 W07_setup 조건 그대로
So = W07_plot(o2, '오프라인 대조 (VRX 초기 선수각)');   % 오프라인 지표를 같은 형식으로 찍는다
S.offline = rmfield(So, intersect(fieldnames(So), {'fig'}));

qn = o2.log_x_n.Data;  qe = o2.log_y_n.Data;  t2 = o2.log_x_n.Time;

% 두 시계가 겹치는 구간만 비교한다 — 밖으로 나가면 외삽이 폭주한다
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, qn, tm, 'linear');
qe_i = interp1(t2, qe, tm, 'linear');
sep  = hypot(x_n(1:nm) - qn_i, y_n(1:nm) - qe_i);

cn = evalin('base','center_north');  ce = evalin('base','center_east');
rd = evalin('base','r_d');
S.sep_mean = mean(sep);   S.sep_max = max(sep);
S.r_vrx    = mean(hypot(x_n - cn, y_n - ce));
S.r_off    = mean(hypot(qn - cn, qe - ce));

drawOverlay(y_n, x_n, qe, qn, tm, sep, S, T_end, cn, ce, rd);
saveFig(gcf, 'W07_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  평균 반경     오프라인 %6.2f m   VRX %6.2f m   (목표 %g)\n', ...
        S.r_off, S.r_vrx, rd);
fprintf('  궤적 평균 이격 %6.2f m,  최대 %6.2f m\n', S.sep_mean, S.sep_max);
end

% =====================================================================
function k = syncCheck(out)
% Simulink 가 VRX 를 따라갔는가 — 로그만으로 판정한다 (5주차 W05_vrx_run 과 같음)
%   VRX 가 준 속도 u 는 "시뮬레이터 1 초에 몇 m" 다. Simulink 가 제때 돌았다면
%   모델 시각으로 적분한 거리와 실제로 지나간 거리가 같다 (k = 1).
%   Simulink 가 그림 그리기 등으로 늦어지면 같은 모델 1 초 동안 배가 더 가므로 k > 1.
t = out.log_x_n.Time;
s_path = sum(hypot(diff(out.log_x_n.Data), diff(out.log_y_n.Data)));
s_int  = trapz(t, abs(out.log_u.Data));
k = s_path / max(s_int, eps);
fprintf('   동기 점검 k = 지나간 거리 %.1f m / 속도 적분 %.1f m = %.3f', s_path, s_int, k);
if k > 1.08
    fprintf('  <- Simulink 가 VRX 를 못 따라갔다\n');
    fprintf('      이 결과는 쓰지 말 것. 실시간 화면을 끈 채(기본) VRX 를 다시 띄워 재실행\n');
elseif k < 0.9
    %  명령은 나가는데 배가 그만큼 가지 않음 = Gazebo 가 멈춰 있었던 것 (ros2 데몬 손상)
    fprintf('  <- 명령만큼 배가 가지 않았다 (Gazebo 가 멈춤)\n');
    fprintf('      이 결과는 쓰지 말 것. WSL 에서 ros2 daemon stop && ros2 daemon start 뒤 VRX 를 다시 띄워 재실행\n');
else
    fprintf('  (0.9 ~ 1.08 — 동기 정상)\n');
end
end

function [L, d, name, W] = landCheck(out, on, oe, t_done)
% 육지·부표에 닿았는가 (6주차 W06_vrx_report 와 같은 검사)
%   걸림 — 추진기가 힘을 내는데 배가 5 초 넘게 서 있으면 무언가에 닿은 것
%   이격 — 스폰 둘레 고정 물체(부표·남쪽 해안의 말뚝·안테나)까지 가장 가까이 지난 거리
t = out.log_x_n.Time;   x = out.log_x_n.Data(:);   y = out.log_y_n.Data(:);
U = abs(out.log_u.Data(:));
F = abs(out.log_FL.Data(:)) + abs(out.log_FR.Data(:));
b = F > 150 & U < 0.05;
if ~isnan(t_done), b(t >= t_done) = false; end      % 두 바퀴 돌고 선 뒤는 뺀다
b(1:find(abs(x) + abs(y) > 0, 1)) = false;          % 첫 메시지 전의 0 버스는 뺀다
L = 0;  s = [];
for i = 1:numel(b)
    if b(i) && isempty(s), s = t(i); end
    if (~b(i) || i == numel(b)) && ~isempty(s), L = max(L, t(i) - s); s = []; end
end
ok = abs(x) + abs(y) > 0;
xE = y(ok) + oe;   yN = x(ok) + on;                 % 지나간 자리를 월드 ENU (x 동, y 북) 로
W  = [min(xE) max(xE) min(yN) max(yN)];
% 2026-10-23 gz model -m <이름> -p 로 잰 월드 ENU 좌표 [m] (6주차와 같은 표)
O = { 'mb_marker_buoy_red',   -528.0, 191.0;   'mb_marker_buoy_black', -528.0, 190.0;
      'mb_marker_buoy_green', -528.0, 189.0;   'mb_marker_buoy_white', -528.0, 188.0;
      'mb_round_buoy_orange', -528.0, 187.0;   'mb_round_buoy_black',  -528.0, 186.0;
      'post_0', -535.917, 154.363;  'post_1', -527.490, 153.855;  'post_2', -544.833, 156.672;
      'antenna', -531.064, 147.669 };
d = inf;  name = '';
for i = 1:size(O,1)
    di = min(hypot(xE - O{i,2}, yN - O{i,3}));
    if di < d, d = di; name = O{i,1}; end
end
fprintf('   걸림 검사 : 힘을 내는데 서 있던 가장 긴 구간 %.1f s', L);
if L > 5, fprintf('  <- 육지·부표에 닿았을 수 있음. Gazebo 화면과 궤적 그림을 볼 것\n');
else,     fprintf('  (5 s 이하 — 걸리지 않음)\n'); end
fprintf('   지나간 자리 (월드 ENU) : x %.1f ~ %.1f m,  y %.1f ~ %.1f m\n', W);
fprintf('   가장 가까이 지난 물체 : %s 까지 %.1f m', name, d);
if d < 5, fprintf('  <- 5 m 안. 로이터 중심을 옮길 것\n');
else,     fprintf('  (5 m 넘게 떨어져 지남)\n'); end
end

function [RTF, x0_n, y0_n] = measureRTF(topic, sec)
n = ros2node(sprintf('/rtf_probe_%d', randi(9999)));
c = onCleanup(@() clear('n'));
s = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
y0_n = m0.pose.pose.position.x;   x0_n = m0.pose.pose.position.y;   % ENU -> NED
pause(sec);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end

function drawOverlay(y_n, x_n, qe, qn, t, sep, S, T_end, cn, ce, rd)
th = linspace(0, 2*pi, 361);
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(ce + rd*sin(th), cn + rd*cos(th), 'k--', 'LineWidth',1.0); hold on;
plot(ce, cn, 'k+', 'MarkerSize',10, 'LineWidth',1.2);
plot(qe, qn, 'b-', 'LineWidth',1.4);
plot(y_n, x_n, 'r-', 'LineWidth',1.4);
plot(y_n(1), x_n(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on; xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
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
