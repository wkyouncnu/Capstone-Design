% plot_simout.m
a = simout.y_out;
tout=simout.tout;
a = squeeze(a);
%% u, v, r, psi
figure()
n=2; m=2; k=1;
subplot(n,m,k), k=k+1; plot(tout, a(:,1), 'LineWidth',1.5), ylabel('U (m/s)'), grid, xlim([0 tout(end)]);
subplot(n,m,k), k=k+1; plot(tout, a(:,2), 'LineWidth',1.5), ylabel('V (m/s)'), grid, xlim([0 tout(end)]);
subplot(n,m,k), k=k+1; plot(tout, 180/pi*a(:,3), 'LineWidth',1.5), ylabel('r (deg/sec)'), grid, xlim([0 tout(end)]);
subplot(n,m,k), plot(tout, 180/pi*wrapToPi(a(:,6)), 'LineWidth',1.5), ylabel('psi (deg)'), grid, xlim([0 tout(end)]);
%% X (North), Y (East)
figure()
plot(a(:,5), a(:,4), 'LineWidth', 2); hold on
plot(a(1,5), a(1,4),'o', 'MarkerSize', 20);
plot(a(end, 5), a(end, 4),'x', 'MarkerSize', 20);
if isempty(wp_north) == 0
    plot(wp_east, wp_north, 'rx', 'LineWidth', 2);
end
axis equal
legend('trajectory', 'start', 'end');
xlabel('y (m)');
ylabel('x (m)'); grid on;
XL = get(gca, 'XLim');
YL = get(gca, 'YLim');


%% u1, u2, u_bt, alpha1, alpha2
alpha = simout.alpha;
alpha = squeeze(alpha);
u = simout.u;
u = squeeze(u);

%% tau, tau_allocated
tau = simout.tau;
tau_allocated = simout.tau_allocated;

figure()
subplot(2,3,1), plot(tout, u(1,:), 'LineWidth',1.5), ylabel('u_{bt}'), legend('u_{BT}'), grid, xlim([0 tout(end)]);
subplot(2,3,2), 
plot(tout, u(2,:), 'LineWidth',1.5), hold on, 
plot(tout, u(3,:), ':', 'LineWidth',1.5), ylabel('u_{vsp}'), legend('u_{vsp1}', 'u_{vsp2}'), grid, xlim([0 tout(end)]);
subplot(2,3,3), 
plot(tout, 180/pi*alpha(1,:), 'LineWidth',1.5), hold on, 
plot(tout, 180/pi*alpha(2,:), ':', 'LineWidth',1.5), ylabel('alpha'), legend('alpha 1', 'alpha 2'), grid, xlim([0 tout(end)]);
subplot(2,3,4),
plot(tout, tau(:,1), 'LineWidth',1.5), hold on, 
plot(tout, tau_allocated(:,1), ':', 'LineWidth',1.5), ylabel('F_x'), legend('F_{x}', 'F_{xa}'), grid, xlim([0 tout(end)]);
subplot(2,3,5),
plot(tout, tau(:,2), 'LineWidth',1.5), hold on, 
plot(tout, tau_allocated(:,2), ':', 'LineWidth',1.5), ylabel('F_y'), legend('F_{y}', 'F_{ya}'), grid, xlim([0 tout(end)]);
subplot(2,3,6),
plot(tout, tau(:,3), 'LineWidth',1.5), hold on, 
plot(tout, tau_allocated(:,3), ':', 'LineWidth',1.5), ylabel('N'), legend('N', 'N_{a}'), grid, xlim([0 tout(end)]);


