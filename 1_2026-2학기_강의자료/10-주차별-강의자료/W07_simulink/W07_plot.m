function S = W07_plot(out, ttl)
% W07_PLOT  시뮬레이션 결과를 그림 6장으로 그리고 성능 지표를 표로 낸다.
%
%   사용법
%     >> W07_setup
%     >> out = sim('W07_0_offline');
%     >> W07_plot(out, 'LOS / 조류 없음')
%
%   반환값 S 에 성능 지표가 들어 있다.
%     S.mean_ye      전 구간 평균 |cross-track error| [m]
%     S.mean_ye_ss   초기 수렴 60 초를 뺀 평균 [m]   <- 과제에 쓸 값
%     S.max_ye       최대 |cross-track error| [m]
%     S.t_finish     완주 시각 [s]  (미완주면 NaN)
%     S.mean_beta    평균 |크랩각| [deg]
%     S.mean_u       정상상태 속도 [m/s]

if nargin < 2, ttl = ''; end

wpn = evalin('base','wp_north');
wpe = evalin('base','wp_east');
R   = evalin('base','R_LOS');
ur  = evalin('base','u_ref');
Ts  = evalin('base','Ts_ctrl');

t    = out.log_pn.Time;
pn   = out.log_pn.Data;     pe  = out.log_pe.Data;
ye   = out.log_y_e.Data;    gate= out.log_gate.Data;
psi  = out.log_psi.Data;    pref= out.log_psi_ref.Data;
chi  = out.log_chi.Data;    beta= out.log_beta.Data;
u    = out.log_u.Data;
FL   = out.log_FL.Data;     FR  = out.log_FR.Data;

% 회전수는 2원소 벡터 신호라 [2 x 1 x N] 로 저장된다. [N x 2] 로 편다
n = squeeze(out.log_n.Data)';

% 미션 완료 시점까지만 본다
k = find(gate < 0.5, 1);
if isempty(k), k = numel(t); S.t_finish = NaN; else, S.t_finish = t(k); end
s = min(round(60/Ts), k);        % 초기 수렴 구간 제외 시작점

S.mean_ye    = mean(abs(ye(1:k)));
S.mean_ye_ss = mean(abs(ye(s:k)));
S.max_ye     = max(abs(ye(1:k)));
S.mean_beta  = mean(abs(beta(s:k))) * 180/pi;
S.mean_u     = mean(u(s:k));

figure('Name', ['W07  ' ttl], 'Position', [80 60 1200 780], 'Color','w');

% ---- 1. 궤적 --------------------------------------------------------
subplot(2,3,[1 4]);
plot(wpe, wpn, 'k--', 'LineWidth', 1.2); hold on;
plot(wpe, wpn, 'ks', 'MarkerFaceColor','w', 'MarkerSize', 8);
th = linspace(0, 2*pi, 60);
for i = 1:numel(wpn)
    plot(wpe(i)+R*cos(th), wpn(i)+R*sin(th), ':', 'Color',[.6 .6 .6]);
    text(wpe(i)+4, wpn(i)+4, sprintf('%d', i), 'FontSize', 9);
end
plot(pe(1:k), pn(1:k), 'b-', 'LineWidth', 1.6);
plot(pe(1), pn(1), 'go', 'MarkerFaceColor','g', 'MarkerSize', 8);
plot(pe(k), pn(k), 'ro', 'MarkerFaceColor','r', 'MarkerSize', 8);
axis equal; grid on;
xlabel('East [m]'); ylabel('North [m]');
title(sprintf('궤적   (mean|y_e| = %.2f m)', S.mean_ye_ss));
legend({'계획 경로','웨이포인트','수락반경','실제 항적','출발','도착'}, ...
       'Location','best', 'FontSize', 8);

% ---- 2. cross-track error -------------------------------------------
subplot(2,3,2);
plot(t(1:k), ye(1:k), 'LineWidth', 1.4); grid on; hold on;
yline(0, 'k:');
xlabel('시간 [s]'); ylabel('y_e [m]');
title('Cross-track error');

% ---- 3. 선수각 지령 vs 실제 -------------------------------------------
subplot(2,3,3);
plot(t(1:k), pref(1:k)*180/pi, '--', 'LineWidth', 1.4); hold on;
plot(t(1:k), psi(1:k)*180/pi, '-', 'LineWidth', 1.2);
plot(t(1:k), chi(1:k)*180/pi, ':', 'LineWidth', 1.2);
grid on; xlabel('시간 [s]'); ylabel('각도 [deg]');
legend({'\psi_{ref} 지령','\psi 선수각','\chi 침로각'}, 'Location','best','FontSize',8);
title('헤딩 추종');

% ---- 4. 크랩각 --------------------------------------------------------
subplot(2,3,5);
plot(t(1:k), beta(1:k)*180/pi, 'LineWidth', 1.4); grid on; hold on;
yline(0,'k:');
xlabel('시간 [s]'); ylabel('\beta [deg]');
title(sprintf('크랩각   (평균 |\\beta| = %.1f\\circ)', S.mean_beta));

% ---- 5. 속도 ----------------------------------------------------------
subplot(2,3,6);
plot(t(1:k), u(1:k), 'LineWidth', 1.4); hold on;
plot(t(1:k), ur*gate(1:k), '--', 'LineWidth', 1.2);
grid on; xlabel('시간 [s]'); ylabel('u [m/s]');
legend({'u 실제','u_{ref} 지령'}, 'Location','best','FontSize',8);
title(sprintf('속도 제어   (정상상태 %.3f m/s)', S.mean_u));

% ---- 6. 추력과 회전수 --------------------------------------------------
figure('Name', ['W07 추진기  ' ttl], 'Position',[140 120 900 380], 'Color','w');
subplot(1,2,1);
plot(t(1:k), FL(1:k), 'LineWidth',1.2); hold on;
plot(t(1:k), FR(1:k), 'LineWidth',1.2);
yline( evalin('base','F_max'), 'r:'); yline(-evalin('base','F_max'), 'r:');
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R','포화한계'}, 'Location','best','FontSize',8);
title('추력');

subplot(1,2,2);
plot(t(1:k), n(1:k,1), 'LineWidth',1.2); hold on;
plot(t(1:k), n(1:k,2), 'LineWidth',1.2);
yline( evalin('base','n_max'), 'r:'); yline(-evalin('base','n_max'), 'r:');
grid on; xlabel('시간 [s]'); ylabel('회전수 [rad/s]');
legend({'n_L','n_R','n_{max}'}, 'Location','best','FontSize',8);
title('프로펠러 회전수');

% ---- 성능 지표 --------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
fprintf('  평균 |y_e|           %8.3f m   (전 구간)\n', S.mean_ye);
fprintf('  평균 |y_e|           %8.3f m   (초기 60초 제외)  <- 과제에 쓸 값\n', S.mean_ye_ss);
fprintf('  최대 |y_e|           %8.3f m\n', S.max_ye);
if isnan(S.t_finish)
    fprintf('  완주                     미완주\n');
else
    fprintf('  완주 시각            %8.1f s\n', S.t_finish);
end
fprintf('  평균 |크랩각|        %8.2f deg\n', S.mean_beta);
fprintf('  정상상태 속도        %8.3f m/s  (목표 %.2f)\n', S.mean_u, ur);

end
