function S = W06_vrx_report(twin, out)
% W06_VRX_REPORT  VRX 쌍둥이 실행이 끝난 뒤의 결과 그림 · 점검 · 오프라인 대조
%
%   쌍둥이 모델의 StopFcn 이 부른다. 손으로 부를 일은 없다.
%
%   하는 일
%     1. 결과 그림 네 칸 (W06_plot) 과 img/W06_<n>_vrx_result.png
%     2. 동기 점검 k    — Simulink 가 VRX 를 따라갔는가
%     3. 걸림 검사       — 힘을 내는데 서 있었는가 (육지·부두·부표에 닿음)
%     4. 이격 검사       — 고정 물체를 몇 m 로 지났는가
%     5. 오프라인 대조   — **m 파일이 남긴 기준 궤적**(ref/) 위에 겹쳐 여섯 칸
%
%   5 번이 이 함수의 핵심이다. 예전 W06_vrx_run 은 쌍둥이를 돌린 뒤 오프라인을
%   **그 자리에서 다시** 돌려 대조했다. 한 번에 두 모델이 도는 셈이어서 어느 그래프가
%   무엇인지 헷갈렸다. 이제 오프라인은 m 파일(또는 오프라인 직접 Run)이 돌리고,
%   그 결과가 ref/ 에 남아 있다가 여기서 불려 온다.

twin = char(twin);
[st, is_vrx] = W06_stage_of(twin);
assert(is_vrx, 'W06_vrx_report 은 *_vrx 모델에만 쓴다 (%s)', twin);
rst  = st;  if rst == 6, rst = 5; end       % 6단의 기준은 5단 것 (img 이름도 5)
here = fileparts(mfilename('fullpath'));
IMG  = fullfile(here, 'img');   if ~isfolder(IMG), mkdir(IMG); end
B = @(v) evalin('base', v);

RTF = 1;   try  RTF = B('W06_RTF');  catch  end
on  = B('origin_north');   oe = B('origin_east');
sn  = B('stage_name');

%% 1. 결과 그림
S = W06_plot(out, sprintf('%d단 VRX — %s (RTF %.2f)', st, sn{st}, RTF));
S.RTF = RTF;   S.origin = [on oe];
f1 = sprintf('W06_%d_vrx_result.png', rst);
exportgraphics(S.fig, fullfile(IMG, f1), 'Resolution', 130);
fprintf('\n[%d단 VRX 점검] RTF %.3f,  스폰 원점 (N, E) = (%.2f, %.2f) m\n', st, RTF, on, oe);
fprintf('   결과 그림 저장 — img/%s\n', f1);

V = W06_pack(out);
U = hypot(V.u, V.v);
dd = hypot(diff(V.x), diff(V.y));   dt = diff(V.t);

%% 2. 동기 점검 — 움직이는 구간(U > 0.2 m/s)만 본다. 목표에 서서 파도에 흔들리는
%  구간까지 넣으면 위치 잡음이 '지나간 거리' 로 쌓여 k 가 부풀려진다
mv = U(1:end-1) > 0.2;
S.k_sync = sum(dd(mv)) / max(sum(U(mv) .* dt(mv)), eps);
fprintf('   동기 점검 k = %.3f', S.k_sync);
if S.k_sync > 1.08
    fprintf(['  <- Simulink 가 VRX 를 못 따라갔다. 이 결과는 쓰지 말 것\n' ...
             '      W06_setup 에서 animate = 0 으로 두거나 animate_every 를 키운 뒤\n' ...
             '      VRX 를 다시 띄워 재실행\n']);
elseif S.k_sync < 0.9
    %  명령은 나가는데 배가 그만큼 가지 않음 = Gazebo 가 멈춰 있었던 것.
    %  ros2 데몬이 깨지면 이 꼴이 되고, 걸림 검사는 (힘은 나가므로) 통과해 버린다
    fprintf(['  <- 명령만큼 배가 가지 않았다 (Gazebo 가 멈춤). 이 결과는 쓰지 말 것\n' ...
             '      WSL 에서  ros2 daemon stop && ros2 daemon start  뒤 VRX 를 다시 띄워 재실행\n']);
else
    fprintf('  (0.9 ~ 1.08 — 동기 정상)\n');
end

%% 3. 걸림 검사 — 추진기가 힘을 내는데 배가 5 초 넘게 서 있으면 무언가에 닿은 것
%  (육지·부두·부표). 목표에 도착해 선 뒤(gate 가 닫힌 뒤)는 빼고 본다
Fsum  = abs(V.FL) + abs(V.FR) + abs(V.FB);
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

%% 5. 오프라인 기준과 대조
R = W06_ref('load', st);
if isempty(R)
    fprintf(['   오프라인 기준 궤적이 없어 대조를 건너뛴다.\n' ...
             '     먼저 >> %s   을 돌리면 ref/W06_%d_offline.mat 이 생긴다\n'], ...
            runner(rst), rst);
    return
end
O  = rmfield(R, intersect(fieldnames(R), {'S','stage','mdl','T_run','psi0','when'}));
So = R.S;
tm  = V.t(V.t <= O.t(end));
sep = hypot(V.x(1:numel(tm)) - interp1(O.t, O.x, tm), ...
            V.y(1:numel(tm)) - interp1(O.t, O.y, tm));
S.sep      = [mean(sep) max(sep)];
S.offline  = So;
S.ref_when = R.when;

f2 = sprintf('W06_%d_vrx_vs_offline.png', rst);
draw_compare(st, V, O, S, So, tm, sep, fullfile(IMG, f2));
fprintf('   대조 그림 저장 — img/%s\n', f2);

%% 6. 표
fprintf('\n   기준 궤적 : %s, %s 실행\n', R.mdl, char(R.when, 'yyyy-MM-dd HH:mm'));
fprintf('   초기 선수각 : 오프라인 %.1f deg / VRX %.1f deg\n', ...
        rad2deg(R.psi0), rad2deg(V.psi(first_valid(V.psi))));
fprintf('   %-22s %12s %12s\n', '항목', '오프라인', 'VRX');
fprintf('   %-22s %12s %12s\n', '완료 시각 [s]', ...
        mat2str(round(So.t_done,2)), mat2str(round(S.t_done,2)));
fprintf('   %-22s %12.3f %12.3f\n', '끝 오차 [m]',          So.e_final,    S.e_final);
fprintf('   %-22s %12.2f %12.2f\n', '선수각 끝 오차 [deg]', So.epsi_final, S.epsi_final);
fprintf('   %-22s %12.3f %12.3f\n', '마지막 10초 오차 [m]', So.e_ss,       S.e_ss);
fprintf('   %-22s %12.3f %12.3f\n', 'max|v| [m/s]',         So.max_v,      S.max_v);
fprintf('   %-22s %12.1f %12.1f\n', 'max|F_B| [N]',         So.max_FB,     S.max_FB);
fprintf('   %-22s %12.1f %12.1f\n', '주행거리 [m]', ...
        sum(hypot(diff(O.x),diff(O.y))), sum(dd));
fprintf('   궤적 평균 이격 %.2f m,  최대 %.2f m\n', S.sep);
fprintf('   동기 점검 k = %.3f · 걸림 %.1f s\n', S.k_sync, S.stuck_s);
end

% =====================================================================
function k0 = first_valid(psi)
%  Subscribe 가 첫 메시지 전에 0 으로 채운 버스를 내므로 앞쪽 0 은 건너뛴다
k0 = find(abs(psi) > 1e-9, 1);   if isempty(k0), k0 = 1; end
end

function s = runner(rst)
%  기준 궤적을 만드는 m 파일 이름
name = {'W06_1_point_run','W06_2_sway_run','W06_3_thrust_run','W06_4_stop_run', ...
        'W06_5_dock_run','','W06_7_front_run','W06_8_ned_run'};
s = name{rst};
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
legend({sprintf('%d단 오프라인 (기준)', k), sprintf('%d단 VRX', k), '목표'}, ...
       'Location', 'best', 'FontSize', 8);
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
