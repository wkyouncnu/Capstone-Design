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

% Fx_max = 5;
% Fx_min = -Fx_max;
% 
% Fy_max = 5;
% Fy_min = -Fy_max;
% 
% N_max = 15;
% N_min = -N_max;
%% Specify the model name
model     = 'CSEI_trim';
sim_model = 'sim_CSEI_trim';
opspec = operspec(model);
% X = u, v, r, x, y, psi
%   u:       surge velocity          (m/s)
%   v:       sway velocity           (m/s)
%   r:       yaw rate                (rad/s)
%   x:       North position          (m)
%   y:       East position           (m)
%   psi:     yaw angle               (rad)

%% Crabbing (+v = 0.25m/s)
% opspec.States.SteadyState   = [1 1 1 1 0 1]';  % successful
% % u
% opspec.States.x(1) = 0; % successful 
% opspec.States.Known(1) = true; % successful 
% 
% % v
% opspec.States.x(2) = 0.25; % successful 
% opspec.States.Known(2) = true; 
% 
% % r
% opspec.States.x(3) = 0; 
% opspec.States.Known(3) = true; 
% 
% % psi
% opspec.States.x(6) = 0;  
% opspec.States.Known(6) = true; 

%% +u 1m/s
opspec.States.SteadyState   = [1 1 1 0 0 1]';  % successful
% u
opspec.States.x(1) = 1; % successful 
opspec.States.Known(1) = true; % successful 
% v
opspec.States.x(2) = 0; % successful 
opspec.States.Known(2) = true; 
% r
opspec.States.x(3) = 0; 
opspec.States.Known(3) = true; 
% psi
opspec.States.x(6) = 0;  
opspec.States.Known(6) = true; 

%% Set the constraints on the inputs in the model.
opspec.Inputs(1).u = 0;
opspec.Inputs(2).u = 0;
opspec.Inputs(3).u = 0; % default

%% Perform the operating point search.
opt = findopOptions('DisplayReport','iter');

[op,opreport] = findop(model,opspec,opt);

opreport.states
for i=1:3
    u0(i)=opreport.inputs(i).u; 
end
x0 = opreport.states.x;
fprintf('u0 = '), fprintf('%8.4f ',u0), fprintf(' \n')

save trimout x0 u0
% return;
%% Simulation
simout=sim(sim_model,200);
plot_simout 

%% Linearlize
% x = u,v,r,x,y,psi
% u = [X, Y, N]
[A, B, C, D] = linmod(model, x0, u0);

save state_space A B C D

eig(A)
%% G(s)_X_u
[num, den] = ss2tf(A,B(:,1),C(1,:),D(1,1));
G_X_u = minreal(tf(num, den))
Den_X_u = cell2mat(G_X_u.Denominator);
Num_X_u = cell2mat(G_X_u.Numerator);

%% G(s)_Y_v
[num, den] = ss2tf(A,B(:,2),C(2,:),D(1,1));
G_Y_v = minreal(tf(num, den))
Den_Y_v = cell2mat(G_Y_v.Denominator);
Num_Y_v = cell2mat(G_Y_v.Numerator);

%% G(s)_N_r
[num, den] = ss2tf(A,B(:,3),C(3,:),D(1,1));
G_N_r = minreal(tf(num, den))
Den_N_r = cell2mat(G_N_r.Denominator);
Num_N_r = cell2mat(G_N_r.Numerator);

%% G(s)_N_psi
[num, den] = ss2tf(A,B(:,3),C(6,:),D(1,1));
G_N_psi = minreal(tf(num, den))
Den_N_psi = cell2mat(G_N_psi.Denominator);
Num_N_psi = cell2mat(G_N_psi.Numerator);

s = tf('s');
t = 0:0.01:20;

figure()
y1 = step(G_N_r*(1/s), t);
y2 = step(G_N_psi, t);
plot(t, y1, 'r', 'LineWidth', 2); hold on;
plot(t, y2, 'b:', 'LineWidth', 2);
xlabel('Time (s)'); 
title('Step response Between Heading and Moment');
ylabel('Step response');
grid on;
