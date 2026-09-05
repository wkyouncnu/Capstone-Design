function S = W09_plot(out, ttl)
% W09_PLOT  미션 결과를 그리고 상태별 성능 지표를 낸다.
%
%   반환값 S
%     S.t_loiter_in   로이터 진입 시각 [s]
%     S.t_loiter_out  로이터 종료 시각 [s]
%     S.t_finish      임무 종료 시각 [s]
%     S.turns         로이터 회전수
%     S.mean_ye_wp    웨이포인트 구간 평균 |y_e| [m]
%     S.mean_re_lo    로이터 구간 평균 반경오차 [m]

if nargin < 2, ttl = ''; end

wpn = evalin('base','wp_north');
wpe = evalin('base','wp_east');
lcn = evalin('base','loiter_cn');
lce = evalin('base','loiter_ce');
lrd = evalin('base','loiter_radius');

t    = out.log_pn.Time;
pn   = out.log_pn.Data;    pe   = out.log_pe.Data;
psi  = out.log_psi.Data;   pref = out.log_psi_ref.Data;
ye   = out.log_y_e.Data;   idx  = out.log_idx.Data;
mode = out.log_mode.Data;  turns= out.log_turns.Data;
u    = out.log_u.Data;     rlo  = out.log_r_lo.Data;
FL   = out.log_FL.Data;    FR   = out.log_FR.Data;

i_lo = find(mode > 1.5 & mode < 2.5);
i_wp = find(mode < 1.5);
i_fi = find(mode > 2.5, 1);

if isempty(i_lo), S.t_loiter_in = NaN; S.t_loiter_out = NaN;
else,             S.t_loiter_in = t(i_lo(1)); S.t_loiter_out = t(i_lo(end)); end
if isempty(i_fi), S.t_finish = NaN; k_end = numel(t);
else,             S.t_finish = t(i_fi); k_end = i_fi; end

S.turns = max(turns);
S.mean_ye_wp = mean(abs(ye(i_wp(i_wp <= k_end))));
if isempty(i_lo)
    S.mean_re_lo = NaN;
else
    j = i_lo(round(0.3*numel(i_lo)):end);      % 진입 과도구간 제외
    S.mean_re_lo = mean(abs(rlo(j) - lrd));
end

figure('Name',['W09  ' ttl], 'Position',[60 40 1240 820], 'Color','w');

% ---- 1. 궤적 (모드별 색) ----------------------------------------------
subplot(2,3,[1 4]); hold on; grid on; axis equal;
plot(wpe, wpn, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',1.2);
th = linspace(0,2*pi,200);
plot(lce + lrd*cos(th), lcn + lrd*sin(th), '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.5);
plot(lce, lcn, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
     'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',14);
k1 = i_wp(i_wp <= k_end);
plot(pe(k1), pn(k1), '.', 'Color',[0 0.45 0.74], 'MarkerSize',4);
if ~isempty(i_lo), plot(pe(i_lo), pn(i_lo), '.', 'Color',[0.95 0.45 0.20], 'MarkerSize',4); end
plot(wpe, wpn, 's', 'MarkerEdgeColor',[0.75 0.1 0.1], ...
     'MarkerFaceColor','w', 'MarkerSize',10, 'LineWidth',1.6);
for i = 1:numel(wpn), text(wpe(i)+4, wpn(i)+5, sprintf('%d',i), ...
    'Color',[0.75 0.1 0.1], 'FontWeight','bold'); end
plot(pe(1), pn(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',9);
plot(pe(k_end), pn(k_end), 'ko', 'MarkerFaceColor','k', 'MarkerSize',9);
xlabel('East [m]'); ylabel('North [m]');
title('궤적  (파랑 = 웨이포인트, 주황 = 로이터)');

% ---- 2. 미션 상태 -----------------------------------------------------
subplot(2,3,2);
stairs(t(1:k_end), mode(1:k_end), 'k', 'LineWidth',1.6); grid on;
ylim([0.5 3.5]); yticks([1 2 3]);
yticklabels({'1 WP','2 Loiter','3 Finish'});
xlabel('시간 [s]'); title('미션 상태');

% ---- 3. 웨이포인트 인덱스 ---------------------------------------------
subplot(2,3,3);
stairs(t(1:k_end), idx(1:k_end), 'LineWidth',1.6); grid on;
xlabel('시간 [s]'); ylabel('leg 시작 인덱스');
title('웨이포인트 진행');

% ---- 4. 오차 ----------------------------------------------------------
subplot(2,3,5); hold on; grid on;
plot(t(k1), ye(k1), '.', 'Color',[0 0.45 0.74], 'MarkerSize',4);
if ~isempty(i_lo)
    plot(t(i_lo), rlo(i_lo)-lrd, '.', 'Color',[0.95 0.45 0.20], 'MarkerSize',4);
end
yline(0,'k:');
xlabel('시간 [s]'); ylabel('오차 [m]');
legend({'y_e (WP)','r - r_d (로이터)'}, 'Location','best','FontSize',8);
title(sprintf('경로 오차   WP %.2f m / 로이터 %.2f m', S.mean_ye_wp, S.mean_re_lo));

% ---- 5. 회전수와 속도 --------------------------------------------------
subplot(2,3,6);
yyaxis left;  plot(t(1:k_end), turns(1:k_end), 'LineWidth',1.5); ylabel('회전수');
yyaxis right; plot(t(1:k_end), u(1:k_end), 'LineWidth',1.2);     ylabel('u [m/s]');
grid on; xlabel('시간 [s]'); title('회전수와 속도');

% ---- 추력 -------------------------------------------------------------
figure('Name',['W09 추진기  ' ttl], 'Position',[120 100 900 360], 'Color','w');
plot(t(1:k_end), FL(1:k_end), 'LineWidth',1.1); hold on;
plot(t(1:k_end), FR(1:k_end), 'LineWidth',1.1);
Fm = evalin('base','F_max'); yline(Fm,'r:'); yline(-Fm,'r:');
if ~isnan(S.t_loiter_in),  xline(S.t_loiter_in, 'k--', '로이터 시작'); end
if ~isnan(S.t_loiter_out), xline(S.t_loiter_out,'k--', '로이터 종료'); end
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R'}, 'Location','best','FontSize',8);
title('추력');

% ---- 지표 -------------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
fprintf('  로이터 진입          %8.1f s\n', S.t_loiter_in);
fprintf('  로이터 종료          %8.1f s   (%.2f 바퀴)\n', S.t_loiter_out, S.turns);
if isnan(S.t_finish)
    fprintf('  임무 종료                미완료\n');
else
    fprintf('  임무 종료            %8.1f s\n', S.t_finish);
end
fprintf('  WP 구간 평균 |y_e|   %8.3f m\n', S.mean_ye_wp);
fprintf('  로이터 평균 반경오차 %8.3f m\n', S.mean_re_lo);

end
