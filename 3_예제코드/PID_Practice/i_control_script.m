% P - controller
clear, %close all

K=[0.1 0.5 1 5];

sim_model='i_control';

j=1;
if j==1, den=[1 1]; end      % 1st order plant model
if j==2, den=[1 1 1]; end    % 2nd order plant model
if j==3, den=[1 2 1 1]; end  % 3rd order plant model

% Time Response
figure(1)
for i=1:length(K)
    Ki = K(i);
    num=Ki;
    simout=sim(sim_model,20);
    plot(simout.y, 'Linewidth',2)
    if i==1, hold on, end
end
hold off
grid
xlabel('time(sec)'), ylabel('y')
title('Step Response')
legend('Ki=0.1', 'Ki=0.5', 'Ki=1', 'Ki=10')

% Bode plot
figure(2)
for i=1:length(K)
    Ki = K(i);
    num=Ki;         % integrator gina 
    den2 = [den 0];  % due to integrator
    G=tf(num, den2);
    if i==1, hold on, end
    bode(G), bode_linewidth(2)
    [Gm(i),Pm(i)] = margin(G);
end
hold off
grid
legend('Ki=0.1', 'Ki=0.5', 'Ki=1', 'Ki=10')
[K; Gm; Pm]

return

% Root Locus
figure(3)
rlocus(G)

