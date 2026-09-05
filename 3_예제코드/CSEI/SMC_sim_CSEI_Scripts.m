clc; clear all; close all
load trimout
load state_space
Ts = 0.01;
% Satuaration parameter
v_max = 0.25;
v_min = -v_max;

% Y_max = 2000;
% Y_min = -Y_max;

current = [0;0];

tau_max = 20*[3; 3; 3];
% f_VSP1_max = tau_max(1);      % Max thrust VSP1
% f_VSP2_max = tau_max(2);      % Max thrust VSP2
% f_BT_max = tau_max(3);         % Max thrust BT

%% SMC
x_ref = 7;
y_ref = 7;
psi_ref = 40;
zeta_d = 1;
w_d = 0.5;
v_max = 10;
BL = [20 10 10];% boundary layer for the saturation to avoid chattering phenomenon
lamda = [5.0 5.0 10];
% K_SMC = 5*[5.1 5.1 10.1];
K_SMC = [20 20 50];

option = 1; % option = 1 (tanh), option = 0 (signum)

%% Control_allocation == 1 (control allocation applied)
Control_allocation = 1;

%% simulink result
% u0 = [0;0;0]; % no trim input for test
T_final = 100;
t = 0:Ts:T_final;
y = sim('SMC_sim_CSEI.slx');
time = y.tout;


%% Tau (Fx, Fy, Moment)
tau = y.Tau;
Fx = tau(:,1,:);
Fy = tau(:,2,:);
Moment = tau(:,3,:);
Fx = squeeze(Fx);
Fy = squeeze(Fy);
Moment = squeeze(Moment);

%% Tau allocated (Fx, Fy, Moment)
tau_allocated = y.Tau_allocated;
Fx_allocated = tau_allocated(:,1,:);
Fy_allocated = tau_allocated(:,2,:);
Moment_allocated = tau_allocated(:,3,:);
Fx_allocated = squeeze(Fx_allocated);
Fy_allocated = squeeze(Fy_allocated);
Moment_allocated = squeeze(Moment_allocated);

% Tau allocated and Tau should be the same.
figure()
subplot(3,1,1)
plot(time, Fx, 'LineWidth', 2); hold on;
plot(time, Fx_allocated, ':', 'LineWidth', 2); hold on;
xlabel('time (s)'); ylabel('Fx (N)'); legend('Tau', 'Tau(allocated)'); grid on;
subplot(3,1,2)
plot(time, Fy, 'LineWidth', 2); hold on;
plot(time, Fy_allocated, ':', 'LineWidth', 2); hold on;
xlabel('time (s)'); ylabel('Fy (N)'); legend('Tau', 'Tau(allocated)'); grid on;
subplot(3,1,3)
plot(time, Moment, 'LineWidth', 2); hold on;
plot(time, Moment_allocated, ':', 'LineWidth', 2); hold on;
xlabel('time (s)'); ylabel('Moment (N*M)'); legend('Tau', 'Tau(allocated)'); grid on;


U = y.y_out(:,1);
V = y.y_out(:,2);
r = y.y_out(:,3);
psi = y.y_out(:,6);

figure()
n=2; m=2; k=1;
subplot(n,m,k), k=k+1; plot(time, U, 'LineWidth',1.5), ylabel('U(m/s)'), grid
subplot(n,m,k), k=k+1; plot(time, V, 'LineWidth',1.5), ylabel('V(m/s)'), grid
subplot(n,m,k), k=k+1; plot(time, 57.3*r, 'LineWidth',1.5), ylabel('r(deg/sec)'), grid
subplot(n,m,k), plot(time, 57.3*wrapToPi(psi), 'LineWidth',1.5), ylabel('psi(deg)'), grid

%% X (North), Y (East)
x_pos = y.y_out(:,4);
y_pos = y.y_out(:,5);

figure()
plot(y_pos, x_pos, 'LineWidth', 2); hold on
plot(y_pos(1), x_pos(1),'o', 'MarkerSize', 20);
plot(y_pos(end), x_pos(end), 'x', 'MarkerSize', 20);
axis equal
legend('trajectory', 'start', 'end');
xlabel('y (m)');
ylabel('x (m)'); grid on;
XL = get(gca, 'XLim');
YL = get(gca, 'YLim');

psi = y.y_out(:,6);
R2D = 180/pi;

figure()
subplot(3,1,1)
plot(time, y.psi_ref, 'r','LineWidth',1.5);  hold on;
plot(time, R2D*psi, 'b:','LineWidth',1.5);
xlabel('time(s)'), ylabel('psi(deg)'), grid
legend('\psi_{ref} (deg)','\psi_{NonLin} (deg)');
subplot(3,1,2)
plot(time, y.x_ref, 'r','LineWidth',1.5);  hold on;
plot(time, x_pos, 'b:','LineWidth',1.5);
xlabel('time(s)'), ylabel('x (m)'), grid
legend('x_{ref} (m)','x_{NonLin} m)');
subplot(3,1,3)
plot(time, y.y_ref, 'r','LineWidth',1.5);  hold on;
plot(time, y_pos, 'b:','LineWidth',1.5);
xlabel('time(s)'), ylabel('x (m)'), grid
legend('y_{ref} (m)','y_{NonLin} m)');

figure()
axis equal
xlabel('y (m)');
ylabel('x (m)'); grid on;
xlim(XL); ylim(YL);
hold on;
for i = 1: 100: length(y.y_out)
    psi = y.y_out(i,6);
    U = sqrt(y.y_out(i,1)^2 + y.y_out(i,2)^2);
    scatter(y_pos(i), x_pos(i), 10,[0 0 1],'filled');
    H = shipModel(y_pos(i), x_pos(i), -psi, U);
    pause(0.1);
    drawnow;
%     delete(H);
end

%% U_bt, U_vsp1, U_vsp2
N = y.N;
Ubt = N(1,:,:);
Uvsp1 = N(2,:,:);
Uvsp2 = N(3,:,:);
Ubt = squeeze(Ubt);
Uvsp1 = squeeze(Uvsp1);
Uvsp2 = squeeze(Uvsp2);

figure()
subplot(3,1,1)
plot(time, Ubt, 'r','LineWidth',1.5);  hold on;
xlabel('time(s)'), ylabel('U_{bt}'), grid
ylim([-1 1]);
subplot(3,1,2)
plot(time, Uvsp1, 'r','LineWidth',1.5);  hold on;
xlabel('time(s)'), ylabel('U_{vsp1}'), grid
ylim([0 1]);
subplot(3,1,3)
plot(time, Uvsp2, 'r','LineWidth',1.5);  hold on;
xlabel('time(s)'), ylabel('U_{vsp2}'), grid
ylim([0 1]);


%% alpha_vsp1, alpha_vsp2
alpha = y.alpha;
alpha_vsp1 = alpha(1,:,:);
alpha_vsp2 = alpha(2,:,:);
alpha_vsp1 = squeeze(alpha_vsp1);
alpha_vsp2 = squeeze(alpha_vsp2);

 
figure()
subplot(2,1,1)
plot(time, alpha_vsp1*R2D, 'r','LineWidth',1.5);  hold on;
xlabel('time(s)'), ylabel('\alpha_{vsp1} (deg)'), grid
subplot(2,1,2)
plot(time, alpha_vsp2*R2D, 'r','LineWidth',1.5);  hold on;
xlabel('time(s)'), ylabel('\alpha_{vsp2} (deg)'), grid