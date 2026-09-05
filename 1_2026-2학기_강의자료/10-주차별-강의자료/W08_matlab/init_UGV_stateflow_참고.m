clc; clear; close all;

T_final = 2000;
Ts = 0.02;

%% Estimator Output & Guidance Parameter 
wp_east = [0 50  80]; 
wp_north = [50 50 80];
wp_u = [0.5 0.8 1.2 0.5];
NAV_ACC_RAD = 2;
% u_setpoint = 1.0;

%% Controller Gain
% Surge Controller
Kp_u = 15;
Ki_u = 2;
Kd_u = 0;
Kanti_u = 1/Ki_u;
N_u = 100;

Fx_max = 50;  % Not mathematically calculated. Arbitrary values used.
Fx_min = -50;

% Heading Controller
Kp_psi = 1.5;
Kd_psi = 3.15;

d2r = pi/180;
r2d = 180/pi;
delta_min = -45*d2r;
delta_max = 45*d2r;

%% Run simulation
out = sim('UGV_Control_StateFlow_260529.slx', T_final);

%% States Extraction
t = out.tout;
states = squeeze(out.states);   % [6 x N]
u   = states(:,1);
v   = states(:,2);
r   = states(:,3);
x   = states(:,4);   % North
y   = states(:,5);   % East
psi = states(:,6);   % rad

%% =========================
% 1. Trajectory & UGV Heading Visualization
% =========================
figure('Name', 'Trajectory & UGV Visualization', 'Position', [100, 100, 700, 600]);
plot(y, x, 'b', 'LineWidth', 2); hold on;

% Start / End points
plot(y(1), x(1), 'go', 'MarkerSize', 8, 'LineWidth', 1.5, 'MarkerFaceColor', 'g');
plot(y(end), x(end), 'mo', 'MarkerSize', 8, 'LineWidth', 1.5, 'MarkerFaceColor', 'm');

% Waypoint path
plot(wp_east, wp_north, 'k--', 'LineWidth', 1.2);
plot(wp_east, wp_north, 'ks', 'MarkerSize', 8, 'LineWidth', 1.5, 'MarkerFaceColor', 'y');

% Waypoint text (Adjusted position to avoid overlapping)
for i = 1:length(wp_east)
    text(wp_east(i)+2, wp_north(i)+2, sprintf('WP%d', i), ...
        'FontSize', 10, 'FontWeight', 'bold');
end

% ----------------------------------------------------
% Draw UGV Position and Heading
% ----------------------------------------------------
% UGV Visualization Parameters (Adjust these to fit your scale)
ugv_L = 3.0;      % UGV triangle length [m]
ugv_W = 2.0;      % UGV triangle width [m]
draw_step = 200;  % Data step for drawing (Increase if too dense)

% UGV basic shape (Local Frame: Nose points to +x direction)
% Vertices: [Nose, Back-Left, Back-Right]
ugv_body_x = [ugv_L/2, -ugv_L/2, -ugv_L/2]; 
ugv_body_y = [0, -ugv_W/2, ugv_W/2];

for k = 1:draw_step:length(t)
    c = cos(psi(k));
    s = sin(psi(k));
    
    % 2D Rotation (Body Frame -> NED Global Frame)
    rot_x = c * ugv_body_x - s * ugv_body_y;
    rot_y = s * ugv_body_x + c * ugv_body_y;
    
    % Translate to current UGV global position
    ugv_global_north = x(k) + rot_x;
    ugv_global_east  = y(k) + rot_y;
    
    % Draw the UGV polygon
    patch(ugv_global_east, ugv_global_north, 'c', 'EdgeColor', 'k', 'LineWidth', 0.8, 'FaceAlpha', 0.7);
end
% ----------------------------------------------------

grid on;
axis equal;
xlabel('East [m]');
ylabel('North [m]');
title('UGV Trajectory with Heading Visualization');
legend('Trajectory', 'Start', 'End', 'Waypoint path', 'Waypoints', ...
       'Location', 'best');


%% =========================
% 2. System States Plot over Time (Mode, Heading, Speed)
% =========================
% Load data from 'To Workspace' blocks
op_mode = out.op_mode_out;
psi_ref = out.psi_ref_out;
u_ref = out.u_ref_out;

% Wrap Heading angles to [-180, 180] degrees for clean visualization
psi_deg_wrapped = mod(psi * r2d + 180, 360) - 180;
psi_ref_deg_wrapped = mod(psi_ref * r2d + 180, 360) - 180;

% Create Subplot Figure
figure('Name', 'System States over Time', 'Position', [850, 100, 800, 800]); 

% --- Row 1: Operation Mode ---
subplot(3, 1, 1);
plot(t, op_mode, 'k', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Mode Number');
title('Operation Mode Transitions');
legend('op\_mode', 'Location', 'best');
ylim([0 30]); % Assuming modes are 11, 12, 21, 22

% --- Row 2: Actual Heading vs Reference Heading ---
subplot(3, 1, 2);
plot(t, psi_deg_wrapped, 'b', 'LineWidth', 1.5); hold on;
plot(t, psi_ref_deg_wrapped, 'r--', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Heading Angle [deg]');
title('Actual Heading vs Reference Heading (Wrapped to \pm 180\circ)');
legend('\psi (Actual)', '\psi_{ref} (Reference)', 'Location', 'best');
ylim([-200 200]); 

% --- Row 3: Actual Speed (u) vs Reference Speed (u_setpoint) ---
subplot(3, 1, 3);
plot(t, u, 'b', 'LineWidth', 1.5); hold on;
% Plot reference speed as a constant line matching the length of 't'
plot(t, u_ref, 'r--', 'LineWidth', 1.5);
grid on;
xlabel('Time [s]');
ylabel('Surge Speed (u) [m/s]');
title('Actual Speed vs Reference Speed');
legend('u (Actual)', 'u_{ref} (Reference)', 'Location', 'best');
% Dynamic y-axis limit based on max speed to keep it visually clean
ylim([0, max(2.0, max(u)*1.2)]);

%% =========================
% 2. 누적 회전수 계산 및 플롯 (StartMission2 구간 한정)
% =========================
% 1. To Workspace 블록으로 내보낸 데이터 불러오기
op_mode = out.op_mode_out;
psi_ref = out.psi_ref_out;

% [수정됨] 시뮬링크 내부에서 직접 계산한 회전수 데이터 불러오기
sim_turns = out.number_of_turn; 

% 2. StartMission2 (operation_mode == 21) 구간의 인덱스 찾기
idx_mode21 = find(op_mode == 21);

if isempty(idx_mode21)
    disp('Warning: 시뮬레이션 결과에 operation_mode == 21 인 구간이 없습니다.');
else
    % 3. 해당 구간의 데이터 추출
    t_21 = t(idx_mode21);
    psi_21 = psi(idx_mode21);
    psi_ref_21 = psi_ref(idx_mode21);
    
    % [수정됨] 수동 계산 코드를 삭제하고, 시뮬링크에서 가져온 데이터를 해당 구간만큼만 잘라냅니다.
    cumulative_turns = sim_turns(idx_mode21);
    
    total_turns = cumulative_turns(end);
    fprintf('StartMission2 (op_mode=21) 구간 실제 누적 회전수: %.2f 바퀴\n', total_turns);
    
    % Heading 비교를 위해 -180 ~ 180도 범위로 Wrap 처리
    psi_21_deg_wrapped = mod(psi_21 * r2d + 180, 360) - 180;
    psi_ref_21_deg_wrapped = mod(psi_ref_21 * r2d + 180, 360) - 180;
    
    % Subplot 작성
    figure('Name', 'Heading Tracking & Turn Count', 'Position', [850, 100, 800, 600]); 
    
    % --- 위쪽 그래프: Heading vs Reference Heading ---
    subplot(2, 1, 1);
    plot(t_21, psi_21_deg_wrapped, 'b', 'LineWidth', 1.5); hold on;
    plot(t_21, psi_ref_21_deg_wrapped, 'r--', 'LineWidth', 1.5);
    
    grid on;
    xlabel('Time [s]');
    ylabel('Heading Angle [deg]');
    title('Heading vs Reference Heading (Wrapped to \pm 180\circ)');
    legend('\psi (Actual)', '\psi_{ref} (Reference)', 'Location', 'best');
    ylim([-200 200]); 
    
    % --- 아래쪽 그래프: 누적 회전수 (Cumulative Turns) ---
    subplot(2, 1, 2);
    % (오타 수정: 'LineWidth' 에 닫는 따옴표 추가)
    plot(t_21, cumulative_turns, 'k', 'LineWidth', 1.5); hold on;   
    
    % 1바퀴, 2바퀴 목표선 시각화
    yline(1, 'g--', '1 Turn', 'LabelHorizontalAlignment', 'left', 'LineWidth', 1.2);
    yline(2, 'm--', '2 Turns', 'LabelHorizontalAlignment', 'left', 'LineWidth', 1.2);
    
    grid on;
    xlabel('Time [s]');
    ylabel('Cumulative Turns [Revolutions]');
    title('Accumulated Orbit Turns (From Simulink)');
    
    % y축 여유 공간 확보 (데이터가 0일 때 에러 방지 처리 추가)
    max_turn = max(cumulative_turns);
    if isempty(max_turn) || max_turn == 0
        max_turn = 0.1;
    end
    ylim([0, max(2.5, ceil(max_turn))]); 
end