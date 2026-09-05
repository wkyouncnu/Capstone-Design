clc; clear all; close all;

%% Initializing values
ly_VSP = 0.055;         % Moment arm along y for VSP
lx_VSP = 0.4574;        % Moment arm along x for VSP
lx_BT = 0.3875;         % Moment arm along x for BT

% default
f_VSP1_max = 0.45;      % Max thrust VSP1 
f_VSP2_max = 0.45;      % Max thrust VSP2
f_BT_max = 0.3;         % Max thrust BT

% Max 
Fx_max = f_VSP1_max + f_VSP2_max;  % 0.9
Fx_min = -Fx_max;
Fy_max = f_VSP1_max + f_VSP2_max + f_BT_max; % 1.2;
Fy_min = -Fy_max;
N_max = f_VSP1_max*ly_VSP + f_VSP2_max*ly_VSP + f_BT_max*lx_BT; %  0.1658
N_min = -N_max;

% test
% f_VSP1_max = 5;      % Max thrust VSP1 
% f_VSP2_max = 5;      % Max thrust VSP2
% f_BT_max = 3;         % Max thrust B

alpha = zeros(2,1);     % VSP angles
u = zeros(3,1);         % Input vector to the VSPs and BT

B = [  1      0       1      0      0;
       0      1       0      1      1;
     ly_VSP -lx_VSP -ly_VSP -lx_VSP lx_BT]; % Configuration matrix
B_dagger = pinv(B);                         % Calculating dagger


%% case 1) 
% tau = [0; 1; 0;0];
%% case 2) 
tau = [0.5; 1; 1.2];

%f_vps1,x f_vps1,y, 
f_cmd = B_dagger*tau                       % Forces and moment

B*f_cmd


u_cmd = [norm(f_cmd(1:2))/f_VSP1_max;
         norm(f_cmd(3:4))/f_VSP2_max;
         f_cmd(5)/f_BT_max]               % Calculating input to each
                                            % thruster

% Saturation: Limit input signal to VSPs to be within [0,1]
if u_cmd(1) < 0
    u_cmd(1) = 0;
elseif u_cmd(1) > 1
    u_cmd(1) = 1;
else
    u_cmd(1) = u_cmd(1);
end

if u_cmd(2) < 0
    u_cmd(2) = 0;
elseif u_cmd(2) > 1
    u_cmd(2) = 1;
else
    u_cmd(2) = u_cmd(2);
end

% Saturation: Limit input signal to BT to be within [-1,1]
if u_cmd(3) < -1
    u_cmd(3) = -1;
elseif u_cmd(3) > 1
    u_cmd(3) = 1;
else
    u_cmd(3) = u_cmd(3);
end

u_cmd
alpha(1) = atan2(f_cmd(2),f_cmd(1));         % Calculate angle of VSP1
alpha(2) = atan2(f_cmd(4),f_cmd(3));         % Calculate angle of VSP2

BT_gain = 1;                                 % Gain used in LAB

%% CAUTION!!:  u_cmd(3) -> u(1), u_cmd(1) ->u(2), u_cmd(2) ->u(3)
u(1) = u_cmd(3)*BT_gain;                     % Output input to BT
u(2) = u_cmd(1);                             % Output input to VSP1
u(3) = u_cmd(2);                             % Output input to VSP2
%% CAUTION!!:  u(1)->u_bt, u(2)->u_1, u(3)->u_2
u_1 = u(2);
u_2 = u(3);
u_bt = u(1);

R2D = 180/pi;
alpha*R2D

a_1 = alpha(1);
a_2 = alpha(2);

%% VSP 1
ly_VSP = 0.055;                         % Moment arm along y
lx_VSP = 0.4574;                        % Moment arm along x
% f_VSP1_max = 0.45;                      % Max thrust available

x1 = u_1*f_VSP1_max*cos(a_1);               % Resulting forces in x
y1 = u_1*f_VSP1_max*sin(a_1);               % Resulting forces in y
moment1 = x1*ly_VSP*(1) + y1*lx_VSP*(-1);   % Resulting moment

%% VSP 2
ly_VSP = 0.055;                         % Moment arm along y
lx_VSP = 0.4574;                        % Moment arm along x
% f_VSP2_max = 0.45;                      % Max thrust available

x2 = u_2*f_VSP2_max*cos(a_2);               % Resulting forces in x
y2 = u_2*f_VSP2_max*sin(a_2);               % Resulting forces in y
moment2 = x2*ly_VSP*(-1) + y2*lx_VSP*(-1);  % Resulting moment
%% BT
lx_BT = 0.3875;         % Moment arm along x
% f_BT_max = 0.3;         % Max thrust available

y3 = u_bt*f_BT_max;     % Resulting force in y
moment3 = y3*lx_BT;     % Resulting moment


Fx = x1 + x2;
Fy = y1 + y2 + y3;
moment = moment1 + moment2 + moment3;


tau 
Tau_predict = [Fx; Fy; moment]