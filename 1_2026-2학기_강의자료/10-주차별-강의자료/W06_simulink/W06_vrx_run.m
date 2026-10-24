function S = W06_vrx_run(k, T_end)
% W06_VRX_RUN  k 단의 VRX 쌍둥이를 Gazebo 에 붙여 돌리고, 같은 k 단 오프라인과 대조한다
%
%   >> W06_vrx_run(1)        % 1단 — 목표 자세로 가서 선다      (W06_1_point_vrx)
%   >> W06_vrx_run(2)        % 2단 — 순수 횡이동                (W06_2_sway_vrx)
%   >> W06_vrx_run(3)        % 3단 — 추진기 동역학              (W06_3_thrust_vrx)
%   >> W06_vrx_run(4)        % 4단 — 도착 판정과 정지           (W06_4_stop_vrx)
%   >> W06_vrx_run(5)        % 5단 — 옆걸음 접안                (W06_5_dock_vrx)
%                            %        6단이 돌리는 모델이 이것이다 (W06_6_vrx_run 과 같음)
%   >> W06_vrx_run(7)        % 7단 — 전진 접안                  (W06_7_front_vrx)
%   >> W06_vrx_run(8)        % 8단 — NED 위치제어 접안          (W06_8_ned_vrx)
%   >> W06_vrx_run(1, 90)    % 실행 길이를 직접 [s]
%
%   예제마다 오프라인과 VRX 가 쌍이다 (스킬 규칙 20). 두 모델은 같은 빌더가 만들고
%   다른 것은 운동모델 자리 하나뿐이다 — 결과가 다르면 원인은 제어기가 아니라
%   플랜트(Gazebo)나 페이싱이다.
%
%   실행 전에 WSL 에서 **선수추진기를 단** VRX 가 떠 있어야 한다 (실험마다 새로)
%     cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W06_vrx_lite
%     bash ../W03_vrx_lite/stop_vrx.sh && bash run_vrx_bow.sh
%
%   이 함수가 대신 해 주는 것
%     0. Simulink ROS 프로필과 W06_setup 의 Domain ID 가 같은지 (다르면 멈춤)
%     1. 토픽 확인 — ground truth 와 선수추진기 토픽
%     2. RTF 20 초 측정, 스폰 위치를 원점으로
%     3. 실시간 화면을 끄고 페이싱 = RTF 로 실행
%     4. 결과 그림 + 동기 점검 k + 걸림 검사(육지·부두·부표에 닿았는가)
%     5. 같은 k 단 오프라인을 **같은 초기 선수각**으로 돌려 여섯 칸 대조
%
%   남는 그림 (img/) — 단마다 이름 규칙이 같다
%     W06_<k>_vrx_result.png        VRX 단독 결과 (W06_plot 이 그리는 네 칸)
%     W06_<k>_vrx_vs_offline.png    오프라인 ↔ VRX 여섯 칸 대조

if nargin < 1, k = 5; end
if k == 6, k = 5; end                       % 6단 = 5단의 VRX 쌍둥이
assert(ismember(k, [1 2 3 4 5 7 8]), 'k 는 1·2·3·4·5·7·8 가운데 하나');
if nargin < 2 || isempty(T_end)
    %  1~3단에는 정지 게이트가 없어 T_run(300 s) 을 끝까지 돈다. 목표에 서는 데
    %  오프라인으로 40 s 안쪽이면 되므로 VRX 에서는 120 s 로 줄인다
    if k <= 3, T_end = 120; else, T_end = []; end
end

here = fileparts(mfilename('fullpath'));
IMG  = fullfile(here, 'img');   if ~isfolder(IMG), mkdir(IMG); end
TOPIC = '/wamv/sensors/position/ground_truth_odometry';
B = @(v) evalin('base', v);                 % W06_setup 이 만든 변수를 읽는다

%% 0. 설정 — k 단의 목표·게인 그대로
setup_stage(k, T_end);
offline = B('mdl');
twin = [offline '_vrx'];                    % 단마다 이름 규칙이 같다 (6단 예외가 없다)
tag  = sprintf('%d', k);
dom = B('ros_domain_id');

%  Simulink 블록은 ROS 네트워크 프로필의 Domain ID 를, ros2* 함수는 환경변수를
%  쓴다. 둘이 다르면 Simulink 만 아무것도 못 받고 오류 없이 배가 서 있다
%  프로필을 한 번도 만든 적이 없으면 Simulink 도 환경변수를 따른다 — 그대로 둔다
try
    prof = getpref('ROS_Toolbox', 'ROS_NetworkAddress_Profiles');
    dom_prof = double(prof{1}.DomainID);
catch
    dom_prof = [];                          % 프로필 없음 (새로 설치한 MATLAB 의 기본 상태)
end
if isempty(dom_prof)
    setenv('ROS_DOMAIN_ID', dom);
elseif dom_prof ~= str2double(dom)
    error(['Simulink ROS 프로필의 Domain ID 는 %d, W06_setup 의 ros_domain_id 는 %s 이다.\n' ...
           '  Simulink 툴스트립 시뮬레이션 -> ROS 네트워크 에서 Domain ID 를 %s 로 바꾸고 다시 실행'], ...
          dom_prof, dom, dom);
end

%% 1. 토픽 확인
fprintf('\n1) ROS_DOMAIN_ID = %s — 토픽 확인 (%d단, %s)\n', getenv('ROS_DOMAIN_ID'), k, twin);
tl = ros2('topic', 'list');
if ~any(strcmp(tl, TOPIC))
    error(['%s 가 보이지 않는다.\n  - VRX 가 떠 있는가 (bash run_vrx_bow.sh)\n' ...
           '  - WSL 의 echo $ROS_DOMAIN_ID 가 %s 인가'], TOPIC, getenv('ROS_DOMAIN_ID'));
end
if ~any(strcmp(tl, '/wamv/thrusters/bow/thrust'))
    error(['/wamv/thrusters/bow/thrust 가 없다 — 선수추진기 없는 WAM-V 로 띄웠다.\n' ...
           '  5주차의 run_vrx.sh 가 아니라 W06_vrx_lite/run_vrx_bow.sh 로 띄울 것']);
end
fprintf('   OK — 토픽 %d 개 (bow 토픽 있음)\n', numel(tl));

%% 2. RTF 와 스폰 위치
fprintf('2) RTF 측정 (20 초)\n');
nd = ros2node(sprintf('/w06_rtf_probe_%d', randi(9999)));
sb = ros2subscriber(nd, TOPIC, 'nav_msgs/Odometry');
m0 = receive(sb, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(20);
m1 = receive(sb, 15);  tw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / tw;
clear sb nd
on = m0.pose.pose.position.y;   oe = m0.pose.pose.position.x;   % ENU -> NED
assignin('base', 'origin_north', on);
assignin('base', 'origin_east',  oe);
fprintf('   스폰 위치 (N, E) = (%.2f, %.2f) m — 이 점을 원점으로 쓴다\n', on, oe);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 — 실시간 화면 끔 (켜면 Simulink 가 VRX 를 못 따라감, 2026-10-16)
assignin('base', 'animate', 0);
fprintf('3) %s 실행 (최대 %g 초)\n', twin, B('T_run'));
load_system(twin);
set_param(twin, 'EnablePacing', 'on', 'PacingRate', num2str(RTF));
out = sim(twin);

%% 4. 결과 그림 · 동기 점검 · 걸림 검사
stage_name = B('stage_name');
S = W06_plot(out, sprintf('%d단 VRX — %s (RTF %.2f)', k, stage_name{k}, RTF));
S.RTF = RTF;   S.origin = [on oe];
f1 = sprintf('W06_%s_vrx_result.png', tag);
exportgraphics(S.fig, fullfile(IMG, f1), 'Resolution', 130);
fprintf('4) 결과 그림 저장: img/%s\n', f1);

V = pack(out);
U = hypot(V.u, V.v);
%  동기 점검 — 움직이는 구간(U > 0.2 m/s)만 본다. 목표에 서서 파도에 흔들리는
%  구간까지 넣으면 위치 잡음이 '지나간 거리' 로 쌓여 k 가 부풀려진다
mv = U(1:end-1) > 0.2;
dd = hypot(diff(V.x), diff(V.y));   dt = diff(V.t);
S.k_sync = sum(dd(mv)) / max(sum(U(mv) .* dt(mv)), eps);
fprintf('   동기 점검 k = %.3f', S.k_sync);
if S.k_sync > 1.08
    fprintf('  <- Simulink 가 VRX 를 못 따라갔다. 이 결과는 쓰지 말 것 — VRX 를 다시 띄워 재실행\n');
elseif S.k_sync < 0.9
    %  명령은 나가는데 배가 그만큼 가지 않음 = Gazebo 가 멈춰 있었던 것.
    %  ros2 데몬이 깨지면 이 꼴이 되고, 걸림 검사는 (힘은 나가므로) 통과해 버린다
    fprintf(['  <- 명령만큼 배가 가지 않았다 (Gazebo 가 멈춤). 이 결과는 쓰지 말 것\n' ...
             '      WSL 에서  ros2 daemon stop && ros2 daemon start  뒤 VRX 를 다시 띄워 재실행\n']);
else
    fprintf('  (0.9 ~ 1.08 — 동기 정상)\n');
end

%  걸림 검사 — 추진기가 힘을 내는데 배가 5 초 넘게 서 있으면 무언가에 닿은 것
%  (육지·부두·부표). 목표에 도착해 선 뒤(gate 가 닫힌 뒤)는 빼고 본다
Fsum = abs(V.FL) + abs(V.FR) + abs(V.FB);
stuck = Fsum > 150 & U < 0.05;
if ~isnan(S.t_done), stuck(V.t >= S.t_done) = false; end
S.stuck_s = longest_run(stuck, V.t);
xE = V.y + oe;   yN = V.x + on;                 % 지나간 자리를 월드 ENU 로
S.world = [min(xE) max(xE) min(yN) max(yN)];
fprintf('   걸림 검사 : 힘을 내는데 서 있던 가장 긴 구간 %.1f s', S.stuck_s);
if S.stuck_s > 5
    fprintf('  <- 육지·부두·부표에 닿았을 수 있음. Gazebo 화면과 궤적 그림을 볼 것\n');
else
    fprintf('  (5 s 이하 — 걸리지 않음)\n');
end
fprintf('   지나간 자리 (월드 ENU) : x %.1f ~ %.1f m,  y %.1f ~ %.1f m\n', S.world);
[S.clear_m, S.clear_obj] = clearance(xE, yN);
fprintf('   가장 가까이 지난 물체 : %s 까지 %.1f m', S.clear_obj, S.clear_m);
if S.clear_m < 5
    fprintf('  <- 5 m 안. 목표·출발점을 옮길 것\n');
else
    fprintf('  (5 m 넘게 떨어져 지남)\n');
end

%  첫 유효 선수각 — 오프라인을 같은 자세에서 출발시키려고
k0 = find(abs(V.psi) > 1e-9, 1);   if isempty(k0), k0 = 1; end
psi0 = V.psi(k0);

%% 5. 같은 k 단 오프라인과 대조 (같은 출발 선수각)
fprintf('5) %s 오프라인 실행 — 같은 과업, 같은 초기 선수각 %.1f deg\n', offline, rad2deg(psi0));
setup_stage(k, T_end);
assignin('base', 'animate', 0);
x0 = B('x0');   x0(6) = psi0;   assignin('base', 'x0', x0);
load_system(offline);
out_off = sim(offline);
So = W06_plot(out_off, sprintf('%d단 오프라인 대조', k));
O = pack(out_off);
S.offline = rmfield(So, intersect(fieldnames(So), {'fig'}));

tm  = V.t(V.t <= O.t(end));
sep = hypot(V.x(1:numel(tm)) - interp1(O.t, O.x, tm), ...
            V.y(1:numel(tm)) - interp1(O.t, O.y, tm));
S.sep = [mean(sep) max(sep)];

f2 = sprintf('W06_%s_vrx_vs_offline.png', tag);
draw_compare(k, V, O, S, So, tm, sep, fullfile(IMG, f2));
fprintf('6) 대조 그림 저장: img/%s\n', f2);

%% 7. 표
fprintf('\n[%d단 VRX 점검] RTF %.3f,  스폰 원점 (N, E) = (%.2f, %.2f) m\n', k, RTF, on, oe);
fprintf('  %-22s %12s %12s\n', '항목', '오프라인', 'VRX');
fprintf('  %-22s %12s %12s\n', '완료 시각 [s]', mat2str(round(So.t_done,2)), mat2str(round(S.t_done,2)));
fprintf('  %-22s %12.3f %12.3f\n', '끝 오차 [m]',          So.e_final,    S.e_final);
fprintf('  %-22s %12.2f %12.2f\n', '선수각 끝 오차 [deg]', So.epsi_final, S.epsi_final);
fprintf('  %-22s %12.3f %12.3f\n', '마지막 10초 오차 [m]', So.e_ss,       S.e_ss);
fprintf('  %-22s %12.3f %12.3f\n', 'max|v| [m/s]',         So.max_v,      S.max_v);
fprintf('  %-22s %12.1f %12.1f\n', 'max|F_B| [N]',         So.max_FB,     S.max_FB);
fprintf('  %-22s %12.1f %12.1f\n', '주행거리 [m]', sum(hypot(diff(O.x),diff(O.y))), sum(dd));
fprintf('  궤적 평균 이격 %.2f m,  최대 %.2f m\n', S.sep);
fprintf('  동기 점검 k = %.3f · 걸림 %.1f s\n', S.k_sync, S.stuck_s);
end

% =====================================================================
function setup_stage(k, T_end)
%  W06_setup 을 k 단으로 부르고 (자동 실행 없이) 실행 길이를 맞춘다
setappdata(0, 'W06_stage', k);
setappdata(0, 'W06_skip_run', true);
evalin('base', 'W06_setup');
if ~isempty(T_end), assignin('base', 'T_run', T_end); end
end

function Z = pack(o)
Z = struct('t', o.log_x_n.Time, 'x', o.log_x_n.Data, 'y', o.log_y_n.Data, ...
           'psi', o.log_psi.Data, 'u', o.log_u.Data, 'v', o.log_v.Data, ...
           'FL', o.log_FL.Data, 'FR', o.log_FR.Data, 'FB', o.log_FB.Data);
end

function [d, name] = clearance(xE, yN)
%  sydney_regatta 에서 스폰 둘레의 고정 물체 — 배 중심선에서 이 점들까지 가장 짧은 거리
%  좌표는 2026-10-23 에 gz model -m <이름> -p 로 잰 월드 ENU (x 동, y 북) [m].
%  부표 여섯 개가 x = -528 에 1 m 간격으로 서 있고, 말뚝·안테나는 스폰 남쪽 해안 위다
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
end

function L = longest_run(b, t)
%  참이 이어진 가장 긴 구간의 길이 [s]
L = 0;  s = [];
for i = 1:numel(b)
    if b(i) && isempty(s), s = t(i); end
    if (~b(i) || i == numel(b)) && ~isempty(s), L = max(L, t(i) - s); s = []; end
end
end

function draw_compare(k, V, O, S, So, tm, sep, file)
%  여섯 칸 — (1) 궤적 (2) 목표까지 거리 (3) 이격 (4) 선수각 (5) u·v (6) 추력
B = @(v) evalin('base', v);
ssa = @(a) atan2(sin(a), cos(a));
cV = [0.85 0.33 0.10];   cO = [0 0.45 0.74];       % VRX 주황 · 오프라인 파랑
task = B('task_mode');
if task == 3                                         % 접안 — 선석이 목표
    tn = B('dock_north');  te = B('dock_east');
    pt = B('dock_deg');  if k == 7, pt = pt - B('berth_side')*90; end
else                                                 % 한 점 · 횡이동
    tn = B('x_d');  te = B('y_d');  pt = rad2deg(B('psi_d'));
end
dist = @(Z) hypot(Z.x - tn, Z.y - te);

fig = W06_fig('W06_vrx_cmp', sprintf('W06  %d단 오프라인 vs VRX', k), [60 50 1340 760]);

subplot(2,3,1); hold on; grid on; axis equal;
if task == 3
    [qX, qY] = W06_dock_patch(tn, te, deg2rad(B('dock_deg')), B('berth_side'));
    patch(qY, qX, [0.82 0.76 0.66], 'EdgeColor', [0.45 0.33 0.20], 'HandleVisibility', 'off');
end
plot(O.y, O.x, '-', 'Color', cO, 'LineWidth', 1.6);
plot(V.y, V.x, '-', 'Color', cV, 'LineWidth', 1.6);
plot(te, tn, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({sprintf('%d단 오프라인', k), sprintf('%d단 VRX', k), '목표'}, 'Location', 'best', 'FontSize', 8);
title(sprintf('궤적 — 평균 이격 %.2f m', mean(sep)));

subplot(2,3,2); hold on; grid on;
plot(O.t, dist(O), '-', 'Color', cO, 'LineWidth', 1.4);
plot(V.t, dist(V), '-', 'Color', cV, 'LineWidth', 1.4);
yline(B('R_stop'), 'k:', 'R_{stop}', 'LabelHorizontalAlignment', 'left');
xlabel('시간 [s]'); ylabel('목표까지 거리 [m]');
title(sprintf('끝 오차 — 오프라인 %.3f / VRX %.3f m', So.e_final, S.e_final));

subplot(2,3,3); hold on; grid on;
plot(tm, sep, 'k-', 'LineWidth', 1.4);
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격 (평균 %.2f / 최대 %.2f m)', mean(sep), max(sep)));

subplot(2,3,4); hold on; grid on;
plot(O.t, rad2deg(ssa(O.psi)), '-', 'Color', cO, 'LineWidth', 1.4);
plot(V.t, rad2deg(ssa(V.psi)), '-', 'Color', cV, 'LineWidth', 1.4);
yline(pt, 'k--', '\psi_t', 'LabelHorizontalAlignment', 'left');
xlabel('시간 [s]'); ylabel('\psi [deg]');
title(sprintf('선수각 끝 오차 — %.2f / %.2f deg', So.epsi_final, S.epsi_final));

subplot(2,3,5); hold on; grid on;
plot(O.t, O.u, '-', 'Color', cO, 'LineWidth', 1.3);  plot(O.t, O.v, '--', 'Color', cO, 'LineWidth', 1.1);
plot(V.t, V.u, '-', 'Color', cV, 'LineWidth', 1.3);  plot(V.t, V.v, '--', 'Color', cV, 'LineWidth', 1.1);
xlabel('시간 [s]'); ylabel('속도 [m/s]');
legend({'오프 u','오프 v','VRX u','VRX v'}, 'Location', 'best', 'FontSize', 8);
title('서지 u (실선) · 횡이동 v (파선)');

subplot(2,3,6); hold on; grid on;
plot(O.t, O.FL + O.FR, '-', 'Color', cO, 'LineWidth', 1.3);  plot(O.t, O.FB, '--', 'Color', cO, 'LineWidth', 1.1);
plot(V.t, V.FL + V.FR, '-', 'Color', cV, 'LineWidth', 1.3);  plot(V.t, V.FB, '--', 'Color', cV, 'LineWidth', 1.1);
xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'오프 F_L+F_R','오프 F_B','VRX F_L+F_R','VRX F_B'}, 'Location', 'best', 'FontSize', 8);
title(sprintf('max|F_B| — 오프라인 %.1f / VRX %.1f N', So.max_FB, S.max_FB));

exportgraphics(fig, file, 'Resolution', 130);
end
