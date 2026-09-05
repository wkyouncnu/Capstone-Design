% P - controller
clear, close all

K=[0.1 0.5 1 5];

sim_model='p_control';

j=2;
if j==1, den=[1 1]; end      % 1st order plant model
if j==2, den=[1 1 1]; end    % 2nd order plant model
if j==3, den=[1 2 1 1]; end  % 3rd order plant model

% Time Response
figure(1)
for i=1:length(K)
    Kp = K(i);
    num=Kp;
    simout=sim(sim_model,20);
    plot(simout.y, 'Linewidth',2)
    if i==1, hold on, end
end
hold off
grid
xlabel('time(sec)'), ylabel('y')
title('Step Response')
legend('Kp=0.1', 'Kp=0.5', 'Kp=1', 'Kp=5')

% Bode plot
figure(2)
for i=1:length(K)
    Kp = K(i);
    num=Kp;
    G=tf(num, den);
    if i==1, hold on, end
    bode(G), 
    set(findall(gcf,'type','line'),'linewidth',1.5);
    [Gm(i),Pm(i)] = margin(G);
end
hold off
grid
legend('Kp=0.1', 'Kp=0.5', 'Kp=1', 'Kp=5')

% Stability Margin
[K; Gm; Pm]
