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

% control_allocation = 1  ; % 1 = Direct force/moment, 2 = Control allocation
control_allocation = 2; % 1 = Direct force/moment, 2 = Control allocation


%% U control
% Kp_u = 
% Kd_u =
% Ki_u =  
% Kanti_u = 
% N = 
%% Heading control
% Kp_psi = 
% Kd_psi = 

guidance_type = 1; % 1 = atan2,  2 = LOS
Delta = 5;
R = 4;
wp_east = [0 20 30 50 0]; 
wp_north = [10 10 20 40 30];

T_final = 50;

%% Parameter
% Fx = 4; Fy = 0; N = 0; % case 1
Fx = 0; Fy = 3; N = 0; % case 2
% Fx = 0; Fy = 0; N = 1; % case 3

% sim_model = 'Waypoint_Control_PID_CSEI.slx';
sim_model = 'Waypoint_Control_PID_CSEI_2022a_released.slx';

simout=sim(sim_model, T_final);
plot_simout 

tau=simout.tau;
