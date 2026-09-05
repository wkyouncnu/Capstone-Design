clc; clear all; close all

x0 = zeros(6,1);
current = [0;0];


%% Saturation for Fx, Fy, N (moment)
f_VSP1_max = 0.45;      % Max thrust VSP1
f_VSP2_max = 0.45;      % Max thrust VSP2
f_BT_max = 0.3;         % Max thrust BT
ly_VSP = 0.055;         % Moment arm along y for VSP
lx_VSP = 0.4574;        % Moment arm along x for VSP
lx_BT = 0.3875;         % Moment arm along x for BT

Fx_max = f_VSP1_max + f_VSP2_max;
Fx_min = -Fx_max;

Fy_max = f_VSP1_max + f_VSP2_max;
Fy_min = -Fy_max;

N_max = Fx_max*ly_VSP*(1) - Fx_max*ly_VSP*(-1) + f_BT_max*lx_BT; 
N_min = -N_max;

%% Specify the model name
control_allocation = 2; % 1 = Direct force/moment, 2 = Control allocation

T_final = 30;
sim_model = 'sim_trajectory_CSEI_2023b.slx';
simout=sim(sim_model, T_final);
plot_simout 

tau=simout.tau;
