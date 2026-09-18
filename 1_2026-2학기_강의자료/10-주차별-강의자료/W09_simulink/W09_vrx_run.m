function S = W09_vrx_run(T_end, do_compare)
% W09_VRX_RUN  VRX(Gazebo) 와 연동해 W09_1_vrx 를 돌리고 결과를 그린다.
%
%   >> W09_setup
%   >> W09_vrx_run              % 300초 주행 + 오프라인 대조
%   >> W09_vrx_run(400)
%   >> W09_vrx_run(300, false)  % 대조 없이 VRX 만
%
%   해 주는 일은 7주차 W07_vrx_run 과 같다.
%     1. 토픽 확인  2. RTF 측정  3. 페이싱 맞춰 실행(실시간 그림)
%     4. 결과 그림  5. 오프라인과 궤적 겹쳐 그리기
%
%   실행 전에 VRX 가 떠 있어야 한다.

if nargin < 1 || isempty(T_end),      T_end = 300;  end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W09_1_vrx';
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
[RTF, N0, E0] = measureRTF(TOP, 20);
% 스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다 다르다
% (같은 2.4.0-2 인데 한 컴퓨터는 ENU y = 162, 다른 컴퓨터는 200 — 2026-09-18).
% 고정값을 쓰면 그 차이만큼 경로가 통째로 밀려 안전 수역을 벗어난다.
assignin('base', 'origin_north', N0);
assignin('base', 'origin_east',  E0);
fprintf('   스폰 위치 (N, E) = (%.1f, %.1f) m — 이 점을 원점으로 쓴다\n', N0, E0);
fprintf('   RTF = %.3f\n', RTF);

fprintf('3) %s 실행 (%d초)\n', m, T_end);
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);

fprintf('4) 결과 그림\n');
S     = W09_plot(out, 'VRX 미션 — WP -> 로이터 -> WP');
S.RTF = RTF;
saveFig(S.fig, 'W09_1_vrx_result.png');    % gcf 는 추진기 창이다 — 궤적 창을 저장한다

if ~do_compare, return; end
fprintf('5) 같은 초기 선수각으로 오프라인 모델 실행\n');

pn = out.log_pn.Data;  pe = out.log_pe.Data;  t = out.log_pn.Time;
k0 = find(out.log_psi.Time >= 0.5, 1);   % 첫 샘플은 odom 이 아직 안 와서 못 쓴다
psi0 = out.log_psi.Data(k0);
fprintf('   VRX 초기 선수각 %.2f deg\n', rad2deg(psi0));

x0old = evalin('base','x0');   x0 = x0old;   x0(6) = psi0;   assignin('base','x0', x0);
animOld = evalin('base','animate');         assignin('base','animate', 0);
load_system('W09_0_offline');
o2 = sim('W09_0_offline', 'StopTime', num2str(T_end));   % 모델에 저장된 정지 시간은 건드리지 않는다
assignin('base','animate', animOld);
assignin('base','x0', x0old);   % 되돌린다 — 이 뒤에 오프라인을 다시 돌려도 W09_setup 조건 그대로
So = W09_plot(o2, '오프라인 대조 (VRX 초기 선수각)');   % 오프라인 지표를 같은 형식으로 찍는다
S.offline = rmfield(So, intersect(fieldnames(So), {'fig'}));

qn = o2.log_pn.Data;  qe = o2.log_pe.Data;  t2 = o2.log_pn.Time;

% 두 시계가 겹치는 구간만 비교한다 — 밖으로 나가면 외삽이 폭주한다
tm   = t(t <= t2(end));   nm = numel(tm);
qn_i = interp1(t2, qn, tm, 'linear');
qe_i = interp1(t2, qe, tm, 'linear');
sep  = hypot(pn(1:nm) - qn_i, pe(1:nm) - qe_i);

cn = evalin('base','loiter_cn');  ce = evalin('base','loiter_ce');
rd = evalin('base','loiter_radius');
S.sep_mean = mean(sep);   S.sep_max = max(sep);

% 상태 전이 시각을 오프라인과 나란히 비교한다
mo = out.log_mode.Data;   mf = o2.log_mode.Data;
S.t_in_vrx  = firstAt(t,  mo, 2);   S.t_in_off  = firstAt(t2, mf, 2);
S.t_out_vrx = lastAt(t,   mo, 2);   S.t_out_off = lastAt(t2, mf, 2);

drawOverlay(pe, pn, qe, qn, tm, sep, S, T_end, cn, ce, rd);
saveFig(gcf, 'W09_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%d초) ===\n', T_end);
fprintf('  로이터 진입   오프라인 %6.1f s    VRX %6.1f s\n', S.t_in_off,  S.t_in_vrx);
fprintf('  로이터 종료   오프라인 %6.1f s    VRX %6.1f s\n', S.t_out_off, S.t_out_vrx);
fprintf('  임무 종료     오프라인 %6.1f s    VRX %6.1f s\n', So.t_finish, S.t_finish);
fprintf('  궤적 평균 이격 %6.2f m,  최대 %6.2f m\n', S.sep_mean, S.sep_max);
end

function v = firstAt(t, m, val)
k = find(round(m) == val, 1, 'first');
if isempty(k), v = NaN; else, v = t(k); end
end

function v = lastAt(t, m, val)
k = find(round(m) == val, 1, 'last');
if isempty(k), v = NaN; else, v = t(k); end
end

% =====================================================================
function [RTF, N0, E0] = measureRTF(topic, sec)
n = ros2node(sprintf('/rtf_probe_%d', randi(9999)));
c = onCleanup(@() clear('n'));
s = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
E0 = m0.pose.pose.position.x;   N0 = m0.pose.pose.position.y;   % ENU -> NED
pause(sec);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end

function drawOverlay(pe, pn, qe, qn, t, sep, S, T_end, cn, ce, rd)
th  = linspace(0, 2*pi, 361);
wpn = evalin('base','wp_north');   wpe = evalin('base','wp_east');
figure('Name','오프라인 vs VRX','Color','w','Position',[80 80 1000 440]);

subplot(1,2,1);
plot(wpe, wpn, 'ks--', 'MarkerFaceColor','w', 'LineWidth',1.0); hold on;
plot(ce + rd*sin(th), cn + rd*cos(th), 'k:', 'LineWidth',1.0);
plot(qe, qn, 'b-', 'LineWidth',1.4);
plot(pe, pn, 'r-', 'LineWidth',1.4);
plot(pe(1), pn(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on; xlabel('East [m]'); ylabel('North [m]');
legend({'웨이포인트','로이터 원','오프라인','VRX','출발'}, 'Location','best');
title(sprintf('미션 궤적 — %d초, 평균 이격 %.2f m', T_end, S.sep_mean));

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
