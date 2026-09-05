% P - controller
clear, %close all

Kp=1;
K=[0.1  1  5];

sim_model='pd_control';

N=100;
j=2;
if j==1, den=[1 1];     end    % 1st order plant model
if j==2, den=[1 1 1];   end    % 2nd order plant model
if j==3, den=[1 2 1 1]; end    % 3rd order plant model

% Time Response
figure(1)
for i=1:length(K)
    Kd = K(i);
    num=1;
    simout=sim(sim_model,30);
    plot(simout.y, 'Linewidth',2)
    if i==1, hold on, end
end
hold off
grid
xlabel('time(sec)'), ylabel('y')
title('Step Response')
legend('Kd=0.1', 'Kd=1', 'Kd=5')

% Bode plot
figure(2)
num=1;
G=tf(num,den);
bode(G)
hold on
for i=1:length(K)
    Kd = K(i);
    num=[Kp+Kd*N  Kp*N];
    den2 = [den 0] + [0 N*den];
    G=tf(num, den2);
    bode(G), bode_linewidth(2)
    if i==1, hold on, end
    [Gm(i),Pm(i)] = margin(G);
end
hold off
grid
legend('plant model','Kd=0.1', 'Kd=1', 'Kd=5')
set(findall(gcf,'type','line'),'linewidth',1.5);
[K; Gm; Pm]

return

% Root Locus
figure(3)
rlocus(G)

