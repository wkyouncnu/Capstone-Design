% P - controller
clear, %close all

Kp=1;
K=[0.2 1 2];

sim_model='pi_control';

j=2;
if j==1, den=[1 1];     end    % 1st order plant model
if j==2, den=[1 1 1];   end    % 2nd order plant model
if j==3, den=[1 2 1 1]; end    % 3rd order plant model

% Time Response
figure(1)
for i=1:length(K)
    Ki = K(i);
    num=1;
    simout=sim(sim_model,30);
    plot(simout.y, 'Linewidth',2)
    if i==1, hold on, end
end
hold off
grid
xlabel('time(sec)'), ylabel('y')
title('Step Response')
legend('Ki=0.2', 'Ki=1', 'Ki=2')

% Bode plot
figure(2)
num=1;
G=tf(num,den);
bode(G)
set(findall(gcf,'type','line'),'linewidth',1.5);
hold on
for i=1:length(K)
    Ki = K(i);
    num=[Kp Ki];         % integrator gina 
    den2 = [den 0];  % due to integrator
    G=tf(num, den2);
    bode(G)
    set(findall(gcf,'type','line'),'linewidth',1.5);
    [Gm(i),Pm(i)] = margin(G);
end
hold off
grid
legend('plant model','Ki=0.2', 'Ki=1', 'Ki=2')
[K; Gm; Pm]

return

% Root Locus
figure(3)
rlocus(G)

