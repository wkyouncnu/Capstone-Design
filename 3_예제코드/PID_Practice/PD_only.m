% KD and lead compensator

Kp = 1;
Kd = 5;

% G1 = Kp + Kd s
num = [Kd  Kp];
den = 1;
G1 = tf(num,den);

figure(1)
bode(G1),  bode_linewidth(2)
hold on

% PID with Filter for D
Ni=[10 50 100];
for i=1:length(Ni)
    N=Ni(i);
    num = [Kp+Kd*N N];
    den = [1  N];
    G2 = tf(num, den);
    bode(G2),  bode_linewidth(2)
    if i==length(Ni), hold off
    end
end
grid
legend('No filter','N=10','N=50','N=100')
axis([1e-3 1e3 0 100])
