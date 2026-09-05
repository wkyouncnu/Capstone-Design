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
% Fx_min = 0;
Fx_min = -Fx_max;

Fy_max = f_VSP1_max + f_VSP2_max + f_BT_max;
Fy_min = -Fy_max;

N_max = Fx_max*ly_VSP*(1) - Fx_max*ly_VSP*(-1) + f_BT_max*lx_BT; 
N_min = -N_max;

%% X-position control

%% U control
u_max = 2; 
u_min = -2;
%% Y-position control
v_max = 2; % 3m/x   
v_min = -2;
%% Heading control
Kp_psi = 
Kd_psi = 
T_final =

%% Docking position and initial position
y_dock = 30;       % docking NED position (y)
x_dock = 30;       % docking NED position (x)
psi_ref_deg = 30;  % degree

% y_dock = 0;       % docking NED position (y)
% x_dock = -10;       % docking NED position (x)

u_vsp_min = 0; % backward motion impossible
% u_vsp_min = -1;  % backward motion possible

sim_model = 'Position_Control_PID_CSEI.slx';

simout=sim(sim_model, T_final);
% plot_simout 

plot_ship_position_control

