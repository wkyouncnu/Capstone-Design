clc; clear all; close all

x0 = zeros(6,1);
% current = [0.5;0];
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

% control_allocation = 1  ; % 1 = Direct force/moment, 2 = Control allocation
control_allocation = 2; % 1 = Direct force/moment, 2 = Control allocation


%% U control
Kp_u = 21; 
% Kd_u = 4.6995; 
Kd_u = 1; 
% Ki_u = 9.9287; 
Ki_u = 2; 
Kanti_u = 0.02;
N = 100;
%% Heading control
% Kp_psi = 105.6745*0.08;     
% Kd_psi = 64.7083*0.08; 
Kp_psi = 100;
Kd_psi = 10;
% Kp_psi = 3;
% Kd_psi = 15;
guidance_type = 2; % 1 = atan2,  2 = LOS
Delta = 10;
R = 2;
wp_east = [0 20 30 50 0]; 
wp_north = [10 10 20 40 30];

% T_final = 50;
T_final = 500;

% sim_model = 'RC_Control_CSEI.slx';

%% Parameter
% Fx = 4; Fy = 0; N = 0; % case 1
% Fx = 0; Fy = 3; N = 0; % case 2
Fx = 0; Fy = 0; N = 1; % case 3

sim_model = 'Waypoint_Control_PID_CSEI.slx';
% sim_model = 'Waypoint_Control_PID_CSEI_2022a_released.slx';

simout=sim(sim_model, T_final);
% plot_simout 

tau=simout.tau;

% plot_ship_waypoint_control
plot_ship_waypoint_control_LLA

