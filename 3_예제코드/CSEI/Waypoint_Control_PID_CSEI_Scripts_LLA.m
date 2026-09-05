clc; clear all; close all

x0 = zeros(6,1);
current = [0;0];
%% Saturation for Fx, Fy, N (moment)
f_VSP1_max = 0.45*10;      % Max thrust VSP1
f_VSP2_max = 0.45*10;      % Max thrust VSP2
f_BT_max = 0.3*10;         % Max thrust BT
ly_VSP = 0.055;         % Moment arm along y for VSP
lx_VSP = 0.4574;        % Moment arm along x for VSP
lx_BT = 0.3875;         % Moment arm along x for BT

Fx_max = f_VSP1_max + f_VSP2_max;
Fx_min = 0;

Fy_max = f_VSP1_max + f_VSP2_max + f_BT_max;
Fy_min = -Fy_max;

N_max = Fx_max*ly_VSP*(1) - Fx_max*ly_VSP*(-1) + f_BT_max*lx_BT; 
N_min = -N_max;
%% Specify the model name
control_allocation = 2; % 1 = Direct force/moment, 2 = Control allocation
%% U control
Kp_u = 21; 
Kd_u = 1; 
Ki_u = 2; 
Kanti_u = 0.02;
N = 100;
%% Heading control
Kp_psi = 100;
Kd_psi = 10;

guidance_type = 2; % 1 = atan2,  2 = LOS
Delta = 10;
R = 2;  
%% === 지도 설정 ===
figure(1)
LatLimits = [36.371961 36.374161];
LonLimits = [127.384273 127.393020];
geobasemap satellite;
geolimits(LatLimits, LonLimits);
hold on;

%% === 초기 위치 설정 (기준점 origin 설정) ===
disp('USV 초기 위치를 클릭하세요 (기준점)');
[lat_init, lon_init] = ginput(1);  % 순서: x=lon, y=lat
origin = [lat_init, lon_init, 0];

%% === 설정값 ===
num_wp = 5;     % waypoint 개수
r = 5;          % 원 반지름 (meter)
theta = linspace(0, 2*pi, 100);  % 원 계산용

%% === 저장용 변수 초기화 ===
wp_east = zeros(1, num_wp);
wp_north = zeros(1, num_wp);

%% === Waypoint 클릭 반복 ===
for i = 1:num_wp
    disp(['Waypoint #' num2str(i) ' 위치를 클릭하세요']);
    [lat_wp, lon_wp] = ginput(1);

    % 클릭한 위도 경도를 NED로 변환
    lla_wp = [lat_wp, lon_wp, 0];
    ned_wp = lla2ned(lla_wp, origin, 'flat');
    wp_north(i) = ned_wp(1);  % North
    wp_east(i) = ned_wp(2);   % East

    % 원을 NED 상에서 계산 (중심: 클릭한 wp)
    cx = wp_east(i);
    cy = wp_north(i);
    circle_x = cx + r * cos(theta);
    circle_y = cy + r * sin(theta);
    xyzNED_circle = [circle_y', circle_x', zeros(100, 1)];  % [North, East, Down]

    % 다시 위도/경도로 변환하여 지도에 표시
    lla_circle = ned2lla(xyzNED_circle, origin, 'flat');
    geoplot(lla_circle(:,1), lla_circle(:,2), 'g--', 'LineWidth', 1.2);

    % waypoint도 점으로 표시 (중심점)
    geoplot(lat_wp, lon_wp, 'go', 'MarkerSize', 2, 'MarkerFaceColor', 'g');

    drawnow;
end

%% 결과 출력
disp('wp_east = ');
disp(wp_east);
disp('wp_north = ');
disp(wp_north);

%% Simulation
Fx = 0; Fy = 0; N = 1; % case 3
% wp_east = [0 20 30 50 0]; 
% wp_north = [10 10 20 40 30];

T_final = 800;
sim_model = 'Waypoint_Control_PID_CSEI.slx';
simout=sim(sim_model, T_final);
tau=simout.tau;

plot_ship_waypoint_control_LLA

