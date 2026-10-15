% W06_6_VRX_RUN  6단 — Gazebo(VRX) 와 연동해 접안을 돌리고 오프라인과 대조한다
%
%   >> W06_6_vrx_run
%
%   바뀌는 것은 운동모델 하나다. 1~5단은 오프라인 플랜트가 배를 움직였고,
%   6단은 그 자리에 Gazebo 가 들어간다 — 제어기·유도부·추력배분은 5단 그대로다.
%     추력 F_L · F_R · F_B  ->  /wamv/thrusters/*/thrust  (뉴턴)
%     자세 x_n · y_n · psi   <-  ground truth odometry     (ENU -> NED 로 바꿔 받음)
%
%   이 파일이 대신 해 주는 것
%     1. VRX 토픽이 보이는지 확인        (안 보이면 여기서 멈춘다)
%     2. RTF 를 20 초 동안 실제로 측정    (손으로 재지 않아도 된다)
%     3. 스폰 위치를 첫 샘플로 읽어 원점으로 씀 (설치마다 다르다)
%     4. 페이싱 비율을 RTF 에 맞춰 실행   (도는 동안 실시간 그림이 뜬다)
%     5. 결과 그림을 img/ 에 저장         (W06_6_vrx_result.png)
%     6. 5단 오프라인을 같은 과업으로 돌려 여섯 칸으로 대조하고 저장
%                                         (W06_vrx_vs_offline.png)
%
%   남는 그림 두 장 — 5·7·8주차 VRX 실행 파일과 같은 이름 규칙이다
%     img/W06_6_vrx_result.png    VRX 단독 결과 (W06_plot 이 그리는 네 칸)
%     img/W06_vrx_vs_offline.png  오프라인 ↔ VRX 여섯 칸 대조
%   손으로 창을 잡아 찍지 않는다. 강의자료에 싣는 그림은 조건과 함께
%   재현되어야 하고, 창이 여럿 열려 있을 때 gcf 는 엉뚱한 창을 가리킨다.
%
%   여섯 칸에 무엇을 담는가 — 접안이 답해야 하는 질문 순서다
%     (1) 궤적      ㄷ 자 베이 안으로 들어갔는가            [두 궤적 겹침]
%     (2) 목표까지 거리  R_stop 안에 섰는가, 언제 섰는가
%     (3) 이격거리   두 운동모델이 같은 배인가 (interp1 로 시각 맞춤)
%     (4) 선수각     선석 방위에 맞췄는가
%     (5) u · v      바깥 고리가 낸 속도 지령을 따라갔는가
%     (6) 추력       선미 합 F_L+F_R 과 선수추진기 F_B 가 한계에 닿았는가
%
%   실행 전에 WSL 에서 VRX 가 떠 있어야 한다.
%     ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
%          urdf:=$HOME/capstone_ws/wamv/w7_wamv.urdf.xacro
setappdata(0, 'W06_stage', 6);
setappdata(0, 'W06_skip_run', true);
W06_setup

TOPIC = '/wamv/sensors/position/ground_truth_odometry';
IMG   = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(IMG), mkdir(IMG); end

%% 1. 토픽 확인 -------------------------------------------------------
%  Simulink ROS 블록은 'ROS 네트워크 프로필' 의 Domain ID 를, MATLAB 의 ros2*
%  함수는 환경변수 ROS_DOMAIN_ID 를 쓴다. 둘이 다르면 토픽이 보이지 않는다.
fprintf('\n1) ROS_DOMAIN_ID = %s — 토픽 확인\n', getenv('ROS_DOMAIN_ID'));
topic_list = ros2('topic', 'list');
if ~any(strcmp(topic_list, TOPIC))
    error(['%s 가 보이지 않는다.\n' ...
           '  - VRX 가 떠 있는가\n' ...
           '  - ground_truth_enabled 를 true 로 바꾼 urdf 로 띄웠는가\n' ...
           '  - WSL 의 echo $ROS_DOMAIN_ID 가 %s 인가'], TOPIC, getenv('ROS_DOMAIN_ID'));
end
fprintf('   OK — 토픽 %d 개\n', numel(topic_list));

%% 2. RTF 측정과 스폰 위치 읽기 ----------------------------------------
fprintf('2) RTF 측정 (20 초)\n');
probe_node = ros2node(sprintf('/w06_rtf_probe_%d', randi(9999)));
probe_sub  = ros2subscriber(probe_node, TOPIC, 'nav_msgs/Odometry');
msg0 = receive(probe_sub, 15);   wall = tic;
t_sim0 = double(msg0.header.stamp.sec) + double(msg0.header.stamp.nanosec)*1e-9;
pause(20);
msg1 = receive(probe_sub, 15);   t_wall = toc(wall);
t_sim1 = double(msg1.header.stamp.sec) + double(msg1.header.stamp.nanosec)*1e-9;
RTF = (t_sim1 - t_sim0) / t_wall;
clear probe_sub probe_node

%  스폰 좌표는 설치마다 다르다 (같은 2.4.0-2 인데 한 컴퓨터는 ENU y = 162,
%  다른 컴퓨터는 200 — 2026-09-18). 고정값을 쓰면 접안 목표가 통째로 밀린다.
origin_north = msg0.pose.pose.position.y;     % ENU y -> NED x (북)
origin_east  = msg0.pose.pose.position.x;     % ENU x -> NED y (동)
fprintf('   스폰 위치 (N, E) = (%.2f, %.2f) m — 이 점을 원점으로 쓴다\n', ...
        origin_north, origin_east);
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);

%% 3. 실행 ------------------------------------------------------------
fprintf('3) %s 실행 (최대 %g 초)\n', mdl, T_run);
load_system(mdl);
set_param(mdl, 'EnablePacing', 'on', 'PacingRate', num2str(RTF));
out = sim(mdl);

%% 4. 결과 그림 -------------------------------------------------------
S     = W06_plot(out, sprintf('%d단 — %s (RTF %.2f)', stage, stage_name{stage}, RTF));
S.RTF = RTF;
exportgraphics(S.fig, fullfile(IMG, 'W06_6_vrx_result.png'), 'Resolution', 130);
fprintf('4) 결과 그림 저장: img/W06_6_vrx_result.png\n');

%  W06_setup 이 base 를 비우므로 VRX 로그를 appdata 로 옮겨 둔다.
%  여섯 칸에 쓸 신호를 한 묶음으로 나른다
V = struct('t',   out.log_x_n.Time, ...
           'x',   out.log_x_n.Data, 'y', out.log_y_n.Data, ...
           'psi', out.log_psi.Data, ...
           'u',   out.log_u.Data,   'v', out.log_v.Data, ...
           'FL',  out.log_FL.Data,  'FR', out.log_FR.Data, 'FB', out.log_FB.Data);
setappdata(0, 'W06_vrx_log', V);
setappdata(0, 'W06_vrx_S',   S);
setappdata(0, 'W06_vrx_org', [origin_north, origin_east, RTF]);

%% 5. 5단 오프라인과 대조 ---------------------------------------------
fprintf('5) 5단 오프라인 모델 실행 (같은 접안 임무, 운동모델만 오프라인)\n');
setappdata(0, 'W06_stage', 5);
setappdata(0, 'W06_skip_run', true);
W06_setup
animate = 0;                       % 대조용이라 실시간 그림은 끈다
load_system(mdl);
out_off = sim(mdl);
S_off = W06_plot(out_off, '5단 오프라인 대조');

V = getappdata(0, 'W06_vrx_log');   S = getappdata(0, 'W06_vrx_S');
G = getappdata(0, 'W06_vrx_org');   origin_north = G(1);   origin_east = G(2);

O = struct('t',   out_off.log_x_n.Time, ...
           'x',   out_off.log_x_n.Data, 'y', out_off.log_y_n.Data, ...
           'psi', out_off.log_psi.Data, ...
           'u',   out_off.log_u.Data,   'v', out_off.log_v.Data, ...
           'FL',  out_off.log_FL.Data,  'FR', out_off.log_FR.Data, 'FB', out_off.log_FB.Data);

%  두 시계가 겹치는 구간만 본다 — 밖으로 나가면 외삽이 폭주한다
tm  = V.t(V.t <= O.t(end));
sep = hypot(V.x(1:numel(tm)) - interp1(O.t, O.x, tm), ...
            V.y(1:numel(tm)) - interp1(O.t, O.y, tm));

%% 6. 여섯 칸 대조 그림 -----------------------------------------------
ssa  = @(a) atan2(sin(a), cos(a));                  % ±pi 로 접는다
dist = @(Z) hypot(Z.x - dock_north, Z.y - dock_east);
[qX, qY] = W06_dock_patch(dock_north, dock_east, deg2rad(dock_deg), berth_side);
cV = [0.85 0.33 0.10];   cO = [0 0.45 0.74];        % VRX 주황 · 오프라인 파랑

fig = W06_fig('W06_vrx_cmp', 'W06  6단 오프라인 vs VRX', [60 50 1340 760]);

% (1) 궤적 — 베이를 먼저 깔아 궤적이 그 위에 올라오게 한다
subplot(2,3,1); hold on; grid on; axis equal;
patch(qY, qX, [0.82 0.76 0.66], 'EdgeColor', [0.45 0.33 0.20], ...
      'LineWidth', 1.0, 'HandleVisibility', 'off');
plot(O.y, O.x, '-', 'Color', cO, 'LineWidth', 1.6);
plot(V.y, V.x, '-', 'Color', cV, 'LineWidth', 1.6);
plot(app_east,  app_north,  'go', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
plot(dock_east, dock_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({'5단 오프라인', '6단 VRX', '접근점', '선석'}, 'Location', 'best', 'FontSize', 8);
title(sprintf('접안 궤적 — 평균 이격 %.2f m', mean(sep)));

% (2) 목표까지 거리 — R_stop 안에 섰는가
subplot(2,3,2); hold on; grid on;
plot(O.t, dist(O), '-', 'Color', cO, 'LineWidth', 1.4);
plot(V.t, dist(V), '-', 'Color', cV, 'LineWidth', 1.4);
yline(R_dock, 'k--', 'R_{dock}', 'LabelHorizontalAlignment', 'left');
yline(R_stop, 'k:',  'R_{stop}', 'LabelHorizontalAlignment', 'left');
xlabel('시간 [s]'); ylabel('선석까지 거리 [m]');
title(sprintf('끝 오차 — 오프라인 %.3f / VRX %.3f m', S_off.e_final, S.e_final));

% (3) 두 궤적 이격
subplot(2,3,3); hold on; grid on;
plot(tm, sep, 'k-', 'LineWidth', 1.4);
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격 (평균 %.2f / 최대 %.2f m)', mean(sep), max(sep)));

% (4) 선수각 — 선석 방위에 맞췄는가
subplot(2,3,4); hold on; grid on;
plot(O.t, rad2deg(ssa(O.psi)), '-', 'Color', cO, 'LineWidth', 1.4);
plot(V.t, rad2deg(ssa(V.psi)), '-', 'Color', cV, 'LineWidth', 1.4);
yline(dock_deg, 'k--', '\psi_t', 'LabelHorizontalAlignment', 'left');
xlabel('시간 [s]'); ylabel('\psi [deg]');
title(sprintf('선수각 끝 오차 — %.2f / %.2f deg', S_off.epsi_final, S.epsi_final));

% (5) 속도 — 바깥 고리 지령을 따라갔는가
subplot(2,3,5); hold on; grid on;
plot(O.t, O.u, '-',  'Color', cO, 'LineWidth', 1.3);
plot(O.t, O.v, '--', 'Color', cO, 'LineWidth', 1.1);
plot(V.t, V.u, '-',  'Color', cV, 'LineWidth', 1.3);
plot(V.t, V.v, '--', 'Color', cV, 'LineWidth', 1.1);
yline(u_max, 'k:');   yline(-u_max, 'k:');
xlabel('시간 [s]'); ylabel('속도 [m/s]');
legend({'오프 u', '오프 v', 'VRX u', 'VRX v'}, 'Location', 'best', 'FontSize', 8);
title('서지 u (실선) · 횡이동 v (파선)');

% (6) 추력 — 선미 합과 선수추진기가 한계에 닿았는가
subplot(2,3,6); hold on; grid on;
plot(O.t, O.FL + O.FR, '-',  'Color', cO, 'LineWidth', 1.3);
plot(O.t, O.FB,        '--', 'Color', cO, 'LineWidth', 1.1);
plot(V.t, V.FL + V.FR, '-',  'Color', cV, 'LineWidth', 1.3);
plot(V.t, V.FB,        '--', 'Color', cV, 'LineWidth', 1.1);
yline(F_bow_max, 'k:');   yline(-F_bow_max, 'k:');
xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'오프 F_L+F_R', '오프 F_B', 'VRX F_L+F_R', 'VRX F_B'}, ...
       'Location', 'best', 'FontSize', 8);
title(sprintf('max|F_B| — 오프라인 %.1f / VRX %.1f N', S_off.max_FB, S.max_FB));

exportgraphics(fig, fullfile(IMG, 'W06_vrx_vs_offline.png'), 'Resolution', 130);
fprintf('6) 대조 그림 저장: img/W06_vrx_vs_offline.png\n');

%% 7. 표 --------------------------------------------------------------
fprintf('\n[6단 점검] RTF %.3f,  스폰 원점 (N, E) = (%.2f, %.2f) m\n', ...
        S.RTF, origin_north, origin_east);
fprintf('  %-22s %12s %12s\n', '항목', '오프라인', 'VRX');
fprintf('  %-22s %12s %12s\n', '완료 시각 [s]', ...
        mat2str(round(S_off.t_done, 2)), mat2str(round(S.t_done, 2)));
fprintf('  %-22s %12.3f %12.3f\n', '끝 오차 [m]',          S_off.e_final,    S.e_final);
fprintf('  %-22s %12.2f %12.2f\n', '선수각 끝 오차 [deg]', S_off.epsi_final, S.epsi_final);
fprintf('  %-22s %12.3f %12.3f\n', 'max|v| [m/s]',         S_off.max_v,      S.max_v);
fprintf('  %-22s %12.1f %12.1f\n', 'max|F_B| [N]',         S_off.max_FB,     S.max_FB);
fprintf('  %-22s %12.1f %12.1f\n', '주행거리 [m]', ...
        sum(hypot(diff(O.x), diff(O.y))), sum(hypot(diff(V.x), diff(V.y))));
fprintf('  궤적 평균 이격 %.2f m,  최대 %.2f m\n', mean(sep), max(sep));
fprintf('  이격이 크면 먼저 볼 것 — 스폰 원점, 추력 토픽 부호, RTF\n');
