function S = W06_plot(out, ttl)
% W06_PLOT  시뮬레이션 결과를 그림으로 그리고 성능 지표를 표로 낸다.
%
%   사용법
%     >> W06_setup
%     >> out = sim('W06_0_offline');
%     >> W06_plot(out, '접안 / 조류 없음')
%
%   반환값 S 에 성능 지표가 들어 있다 — 측정한 값만 들어간다
%     S.t_done       임무 완료 시각 [s]   (gate 가 0 으로 떨어진 시각. 미완료면 NaN)
%     S.e_final      마지막 위치 오차 [m]
%     S.epsi_final   마지막 선수각 오차 [deg]
%     S.e_ss         마지막 10 초 평균 위치 오차 [m]
%     S.epsi_ss      마지막 10 초 평균 |선수각 오차| [deg]
%     S.max_v        최대 |v| [m/s]          <- 선수추진기가 만든 횡이동 속도
%     S.max_FB       최대 |F_B| [N]
%     S.t_phase      단계가 올라간 시각 [s]  (접안은 3개, 그 밖은 1개)

if nargin < 2, ttl = ''; end

q    = evalin('base','task_q');
mode = evalin('base','task_mode');
Rs   = q(13);  Rd = q(10);  La = q(11);  sd = q(12);
dx   = q(7);   dy = q(8);   dpsi = q(9);
switch mode
    case 1,    gx = q(1);  gy = q(2);  gpsi = q(3);
    case 2,    gx = q(4);  gy = q(5);  gpsi = q(6);
    otherwise, gx = dx;    gy = dy;    gpsi = dpsi;
end
apx = dx - sd*La*sin(dpsi);          % 접근점 — TaskRef 와 같은 식
apy = dy + sd*La*cos(dpsi);

t     = out.log_x_n.Time;
x_n   = out.log_x_n.Data;      y_n   = out.log_y_n.Data;
psi   = out.log_psi.Data;      pref  = out.log_psi_ref.Data;
xref  = out.log_x_ref.Data;    yref  = out.log_y_ref.Data;
u     = out.log_u.Data;        v     = out.log_v.Data;
r     = out.log_r.Data;
gate  = out.log_gate.Data;     phase = out.log_phase.Data;
FL    = out.log_FL.Data;       FR    = out.log_FR.Data;
FB    = out.log_FB.Data;

%  회전수는 3원소 벡터 신호다. 저장 모양이 [3 x 1 x N] 일 수도 [N x 3] 일 수도
%  있다 — 시간 길이를 보고 [N x 3] 으로 맞춘다 (5주차와 같은 처리)
n = squeeze(out.log_n.Data);
if size(n,1) ~= numel(t), n = n.'; end

eN = xref - x_n;  eE = yref - y_n;
d  = hypot(eN, eE);
epsi = atan2(sin(pref - psi), cos(pref - psi)) * 180/pi;

%  목표 자세에 대한 오차 — 과업 전체의 성적은 최종 목표 기준으로 매긴다
dg    = hypot(gx - x_n, gy - y_n);
epsig = atan2(sin(gpsi - psi), cos(gpsi - psi)) * 180/pi;

k = find(gate < 0.5, 1);             % gate 가 0 으로 떨어진 첫 순간이 완료 시각
if isempty(k), S.t_done = NaN; else, S.t_done = t(k); end
ss = find(t >= t(end) - 10, 1);      % 마지막 10 초

S.e_final    = dg(end);
S.epsi_final = epsig(end);
S.e_ss       = mean(dg(ss:end));
S.epsi_ss    = mean(abs(epsig(ss:end)));
S.max_v      = max(abs(v));
S.max_FB     = max(abs(FB));
if mode == 3, lv = [1 2 3]; else, lv = 1; end
S.t_phase = nan(size(lv));
for i = 1:numel(lv)
    j = find(phase >= lv(i), 1);
    if ~isempty(j), S.t_phase(i) = t(j); end
end

S.fig = figure('Name',['W06  ' ttl], 'Position',[80 60 1200 780], 'Color','w');

% ---- 1. 궤적 --------------------------------------------------------
subplot(2,3,[1 4]);
th = linspace(0, 2*pi, 72);
if mode == 3
    plot([0 apy dy], [0 apx dx], 'k--', 'LineWidth',1.2); hold on;
    dq = 1.6;  Lq = 12;
    qcx = dx + dq*sd*sin(dpsi);   qcy = dy - dq*sd*cos(dpsi);
    plot(qcy + Lq*[-1 1]*sin(dpsi), qcx + Lq*[-1 1]*cos(dpsi), '-', ...
         'Color',[0.45 0.33 0.20], 'LineWidth',7);
    plot(apy, apx, 'o', 'MarkerEdgeColor',[0 0.5 0], 'MarkerFaceColor','w', ...
         'MarkerSize',9, 'LineWidth',1.6);
    plot(apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
    leg = {'계획 경로','부두','접근점','R_{dock}'};
else
    plot([0 gy], [0 gx], 'k--', 'LineWidth',1.2); hold on;
    leg = {'계획 경로'};
end
plot(gy, gx, 'ks', 'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.6);
plot([gy gy+6*sin(gpsi)], [gx gx+6*cos(gpsi)], '-', 'Color',[0.75 0.10 0.10], ...
     'LineWidth',1.8);
plot(gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.6 0.6 0.6]);
plot(y_n, x_n, 'b-', 'LineWidth',1.6);
plot(y_n(1), x_n(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',8);
plot(y_n(end), x_n(end), 'ro', 'MarkerFaceColor','r', 'MarkerSize',8);
%  마지막 자세를 선체 모양으로 한 번 더 그린다 — 선수각이 지켜졌는지가 보인다
sc = 2;
try, sc = evalin('base','boat_scale'); catch, end
L = 2.45*sc;  B = 1.03*sc;
bx = L*[-1 -1 0.5 1 0.5];  by = B*[1 -1 -1 0 1];
c = cos(psi(end));  s = sin(psi(end));
patch(y_n(end) + bx*s + by*c, x_n(end) + bx*c - by*s, [0.95 0.45 0.20], ...
      'FaceAlpha',0.5, 'EdgeColor',[0.4 0.15 0.05]);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title(sprintf('궤적   (마지막 오차 %.2f m, %.1f°)', S.e_final, S.epsi_final));
legend([leg {'목표 위치','목표 선수각','R_{stop}','항적','출발','도착'}], ...
       'Location','best', 'FontSize',8);

% ---- 2. 위치 오차 ----------------------------------------------------
subplot(2,3,2);
plot(t, eN, 'LineWidth',1.4); hold on;
plot(t, eE, 'LineWidth',1.4);
plot(t, d, '-.', 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
yline(0,'k:');  yline(Rs,':','Color',[.6 .6 .6]);  yline(-Rs,':','Color',[.6 .6 .6]);
grid on; xlabel('시간 [s]'); ylabel('오차 [m]');
legend({'북 오차','동 오차','거리'}, 'Location','best','FontSize',8);
title(sprintf('위치 오차   (R_{stop} = %g m)', Rs));

% ---- 3. 선수각 ------------------------------------------------------
subplot(2,3,3);
plot(t, atan2(sin(pref),cos(pref))*180/pi, '--', 'LineWidth',1.4); hold on;
plot(t, atan2(sin(psi), cos(psi))*180/pi, '-', 'LineWidth',1.2);
plot(t, epsi, ':', 'Color',[0.2 0.6 0.2], 'LineWidth',1.2);
grid on; xlabel('시간 [s]'); ylabel('각도 [deg]');
legend({'\psi_{ref} 지령','\psi 선수각','오차'}, 'Location','best','FontSize',8);
title(sprintf('선수각 추종   (마지막 10초 평균 |오차| %.2f°)', S.epsi_ss));

% ---- 4. 속도 --------------------------------------------------------
subplot(2,3,5);
yyaxis left
plot(t, u, '-', 'LineWidth',1.4); hold on;
plot(t, v, '--', 'LineWidth',1.4);
ylabel('속도 [m/s]');
yyaxis right
plot(t, r*180/pi, ':', 'LineWidth',1.2);
ylabel('r [deg/s]');
grid on; xlabel('시간 [s]');
legend({'u 서지','v 횡이동','r 요'}, 'Location','best','FontSize',8);
title(sprintf('속도   (최대 |v| = %.3f m/s)', S.max_v));

% ---- 5. 추력 --------------------------------------------------------
subplot(2,3,6);
plot(t, FL, 'LineWidth',1.2); hold on;
plot(t, FR, 'LineWidth',1.2);
plot(t, FB, 'LineWidth',1.6, 'Color',[0.93 0.69 0.13]);
Fm = evalin('base','F_max');  Fbm = evalin('base','F_bow_max');
yline( Fm,'r:');  yline(-Fm,'r:');
yline( Fbm,':','Color',[0.85 0.65 0.13]);  yline(-Fbm,':','Color',[0.85 0.65 0.13]);
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R','F_B','\pmF_{max}','','\pmF_{bow,max}'}, ...
       'Location','best','FontSize',8);
title(sprintf('추력   (최대 |F_B| = %.1f N)', S.max_FB));

% ---- 6. 회전수와 단계 ------------------------------------------------
figure('Name',['W06 추진기와 단계  ' ttl], 'Position',[140 120 950 380], 'Color','w');
subplot(1,2,1);
plot(t, n(:,1), 'LineWidth',1.2); hold on;
plot(t, n(:,2), 'LineWidth',1.2);
plot(t, n(:,3), 'LineWidth',1.6, 'Color',[0.93 0.69 0.13]);
nm = evalin('base','n_max');
yline( nm,'r:');  yline(-nm,'r:');
grid on; xlabel('시간 [s]'); ylabel('회전수 [rad/s]');
legend({'n_L','n_R','n_B','\pmn_{max}'}, 'Location','best','FontSize',8);
title('프로펠러 회전수');

subplot(1,2,2);
stairs(t, phase, 'LineWidth',1.6); hold on;
stairs(t, gate, '--', 'LineWidth',1.4);
grid on; xlabel('시간 [s]'); ylabel('단계 / gate');
ylim([-0.3 max(3.3, max(phase)+0.3)]);
legend({'phase (래치)','gate'}, 'Location','best','FontSize',8);
title('과업 진행');

% ---- 성능 지표 --------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
if isnan(S.t_done)
    fprintf('  임무 완료                미완료 (gate 가 끝까지 1)\n');
else
    fprintf('  임무 완료 시각       %8.1f s\n', S.t_done);
end
for i = 1:numel(S.t_phase)
    if isnan(S.t_phase(i))
        fprintf('  단계 %d 도달             미도달\n', i);
    else
        fprintf('  단계 %d 도달         %8.1f s\n', i, S.t_phase(i));
    end
end
fprintf('  마지막 위치 오차     %8.3f m     (R_stop = %g m)\n', S.e_final, Rs);
fprintf('  마지막 선수각 오차   %8.2f deg\n', S.epsi_final);
fprintf('  마지막 10초 평균 오차%8.3f m  / %6.2f deg\n', S.e_ss, S.epsi_ss);
fprintf('  최대 |v| (횡이동)    %8.3f m/s\n', S.max_v);
fprintf('  최대 |F_B| (선수추진기)%6.1f N   (한계 %.0f N)\n', S.max_FB, Fbm);

end
