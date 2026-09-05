% compare_PID.m
clc; close all; clear

Ts=0.01;
T_final = 10;

load trim_u_2kts.mat
load linmodel_u_2kts.mat

Kp_theta=0.6;
Ki_theta=0.38;
Kd_theta=0.115;
stern_max = 45;

%% Run simulink
% y=sim('Remus_pitch_control_240821.slx',10);
% y=sim('Remus_pitch_control_PI_D_2022a.slx',10);
y=sim('Remus_pitch_control_PI_D_2022.slx',10);

%% plot
figure()
time=y.tout;
% plot(time, y.theta_ref.Data,'r','LineWidth',1.5);hold on; title('Remus Pitch Response')
plot(time, y.out1.Data,'b','LineWidth',1.5);hold on;
plot(time, y.out2.Data,'r','LineWidth',1.5);hold off;
grid on, legend('pid','rate feedback')
