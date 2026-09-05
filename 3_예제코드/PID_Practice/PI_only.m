% KD and lead compensator

Kp = 1;
K = [ 1  5  10];

% G1 = Kp + Ki/s = (Kp*s + Ki)/s
den = [1 0];

figure(1)
for i=1:length(K)
    Ki=K(i);
    num = [Kp  Ki];
    G1 = tf(num,den);

    bode(G1),  bode_linewidth(2)
    if i==1, hold on, end
end

grid
legend('Ki=1(tau=1)','Ki=5(tau=0.2)','Ki=10(tau=0.1)')
