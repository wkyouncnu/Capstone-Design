function S = W05_vrx_run(T_end, do_compare)
% W05_VRX_RUN  VRX(Gazebo) 와 연동해 W05_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W05_setup
%   >> W05_vrx_run              % 230초 주행(임무 약 207 s 완주) + 오프라인 대조
%   >> W05_vrx_run(150)         % 150초 — 완주 전에 끊긴다
%   >> W05_vrx_run(230, false)  % 대조 없이 VRX 만
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

if nargin < 1 || isempty(T_end),     T_end = 230;   end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W05_1_vrx';
TOP = '/wamv/sensors/position/ground_truth_odometry';

%% 1. 토픽 확인 -------------------------------------------------------
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
           '  - VRX 가 떠 있는가\n' ...
           '  - ground_truth_enabled 를 true 로 바꾼 urdf 로 띄웠는가\n' ...
           '  - ROS_DOMAIN_ID 가 양쪽 같은가'], TOP);
end
fprintf('   OK — 토픽 %d개\n', numel(tl));

%% 2. RTF 측정 --------------------------------------------------------
fprintf('2) RTF 측정 (20초)\n');
[RTF, x0_n, y0_n] = measureRTF(TOP, 20);
% 스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다 다르다
% (같은 2.4.0-2 인데 한 컴퓨터는 ENU y = 162, 다른 컴퓨터는 200 — 2026-09-18).
% 고정값을 쓰면 그 차이만큼 경로가 통째로 밀려 안전 수역을 벗어난다.
assignin('base', 'origin_north', x0_n);
assignin('base', 'origin_east',  y0_n);
fprintf('   스폰 위치 (x, y) = (%.1f, %.1f) m — 이 점을 원점으로 쓴다\n', x0_n, y0_n);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 ------------------------------------------------------------
fprintf('3) %s 실행 (%d초)\n', m, T_end);
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);

%% 4. 결과 그림 -------------------------------------------------------
fprintf('4) 결과 그림\n');
S     = W05_plot(out, sprintf('VRX / %s 유도', modeName()));
S.RTF = RTF;
saveFig(S.fig, 'W05_1_vrx_result.png');    % gcf 는 추진기 창이다 — 궤적 창을 저장한다

%% 5. 오프라인과 대조 --------------------------------------------------
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
animOld = evalin('base','animate');   assignin('base','animate', 0);
load_system('W05_0_offline');
o2 = sim('W05_0_offline', 'StopTime', num2str(T_end));   % 모델에 저장된 정지 시간은 건드리지 않는다
assignin('base','animate', animOld);
assignin('base','x0', x0old);   % 되돌린다 — 이 뒤에 오프라인을 다시 돌려도 W05_setup 조건 그대로
So = W05_plot(o2, '오프라인 대조 (VRX 초기 선수각)');   % 오프라인 지표를 같은 형식으로 찍는다
S.offline = rmfield(So, intersect(fieldnames(So), {'fig'}));

qn = o2.log_x_n.Data;  qe = o2.log_y_n.Data;  t2 = o2.log_x_n.Time;

% 같은 시각으로 맞춰 이격거리를 잰다.
% 두 시계가 겹치는 구간만 본다 — 밖으로 나가면 외삽이 폭주한다.
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, qn, tm, 'linear');
qe_i = interp1(t2, qe, tm, 'linear');
sep  = hypot(x_n(1:nm) - qn_i, y_n(1:nm) - qe_i);

S.sep_mean = mean(sep);
S.sep_max  = max(sep);
S.dist_vrx = sum(hypot(diff(x_n), diff(y_n)));
S.dist_off = sum(hypot(diff(qn), diff(qe)));

drawOverlay(y_n, x_n, qe, qn, tm, sep, S, T_end);
saveFig(gcf, 'W05_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  주행거리      오프라인 %7.1f m   VRX %7.1f m\n', S.dist_off, S.dist_vrx);
fprintf('  궤적 평균 이격 %6.2f m,  최대 %6.2f m\n', S.sep_mean, S.sep_max);
end

% =====================================================================
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

function s = modeName()
if evalin('base','guidance_mode') == 1, s = 'atan2'; else, s = 'LOS'; end
end

function drawOverlay(y_n, x_n, qe, qn, t, sep, S, T_end)
wpx = evalin('base','wp_north');   wpy = evalin('base','wp_east');
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(wpy, wpx, 'ks--', 'MarkerFaceColor','w', 'LineWidth',1.0); hold on;
plot(qe, qn, 'b-', 'LineWidth',1.6);
plot(y_n, x_n, 'r-', 'LineWidth',1.6);
plot(y_n(1), x_n(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
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
