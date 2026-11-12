function S = A3_plot(out, ttl)
% A3_PLOT  부록 A3 결과를 그림으로 그리고 성능 지표를 표로 낸다.
%
%   사용법
%     >> A3_setup                       %  설정 + 실행 + 이 그림까지 한 줄
%     >> A3_1_crab_run                  %  권장 — 단별 run 스크립트
%
%   반환값 S — **측정한 값만** 들어간다 (추정값을 쓰지 않는다)
%     S.psi_rms      선수각 오차 RMS [deg]        <- 교수님 질문 (a) 의 답
%     S.psi_pk       선수각 오차 최대 |값| [deg]
%     S.v_pk         최대 |v| 횡속도 [m/s]
%     S.v_ss         정상 구간 평균 |v| [m/s]     (움직인 구간의 중간 절반)
%     S.t_done       도착 시각 [s] (gate 가 0 으로 떨어진 때. 미완료면 NaN)
%     S.e_final      마지막 위치 오차 [m]
%     S.epsi_final   마지막 선수각 오차 [deg]
%     S.e_ss         마지막 10 초 평균 위치 오차 [m]
%     S.epsi_ss      마지막 10 초 평균 |선수각 오차| [deg]
%     S.T_pk         최대 추력 |T| [N]
%     S.d_pk         최대 방향각 |delta| [deg]
%     S.d_mean       움직이는 동안의 평균 |delta| [deg]
%     S.f_dsat       방향각이 한계에 붙어 있던 시간 비율 [%]
%     S.f_ksat       추력 포화로 축소가 걸린 시간 비율 [%]
%     S.w_err        요구 힘·모멘트와 실제 값의 최대 차이 [N, N, N m]
%     S.t_phase      단계가 올라간 시각 [s]

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
apx = dx - sd*La*sin(dpsi);          % 접근점 — 유도부와 같은 식
apy = dy + sd*La*cos(dpsi);

Fm   = evalin('base','F_max');
dmx  = evalin('base','d_max')*180/pi;

dsw  = evalin('base','d_sway')*180/pi;

t     = out.log_x_n.Time;
x_n   = out.log_x_n.Data;      y_n   = out.log_y_n.Data;
psi   = out.log_psi.Data;      pref  = out.log_psi_ref.Data;
xref  = out.log_x_ref.Data;    yref  = out.log_y_ref.Data;
u     = out.log_u.Data;        v     = out.log_v.Data;
r     = out.log_r.Data;
gate  = out.log_gate.Data;     phase = out.log_phase.Data;
TL    = out.log_TL.Data;       TR    = out.log_TR.Data;
dL    = out.log_dL.Data*180/pi;  dR  = out.log_dR.Data*180/pi;
kscl  = out.log_kscl.Data;
Xc    = out.log_X_c.Data;      Yc    = out.log_Y_c.Data;   Nc = out.log_N_c.Data;
Xa    = out.log_X_a.Data;      Ya    = out.log_Y_a.Data;   Na = out.log_N_a.Data;

eN = xref - x_n;  eE = yref - y_n;
d  = hypot(eN, eE);
epsi = atan2(sin(pref - psi), cos(pref - psi)) * 180/pi;

if mode == 3, gpsi = pref(end); end
dg    = hypot(gx - x_n, gy - y_n);
epsig = atan2(sin(gpsi - psi), cos(gpsi - psi)) * 180/pi;

k = find(gate <= 0, 1);
if isempty(k), S.t_done = NaN; else, S.t_done = t(k); end
ss = find(t >= t(end) - 10, 1);              % 마지막 10 초
%  움직이는 중인 구간 — **속도로** 가른다
%    gate 하나만 보면 안 된다. 1단은 도착 판정을 쓰지 않아 gate 가 끝까지 1 이고,
%    목표에 닿아 멈춘 뒤의 긴 정지 구간이 그대로 섞인다 (평균 횡속도가 0 으로
%    읽혔다). 그래서 실제로 움직인 샘플만 고른다.
mv = gate > 0 & hypot(u, v) > 0.02;
if ~any(mv), mv = gate > 0; end
if ~any(mv), mv = true(size(t)); end
%  정상 구간 — 움직인 샘플 가운데 **중간 절반**. 가·감속을 뺀다
iv  = find(mv);
if numel(iv) >= 4
    iv = iv(round(0.25*numel(iv)) : round(0.75*numel(iv)));
end
mid = false(size(t));  mid(iv) = true;

S.psi_rms    = sqrt(mean(epsi.^2));
S.psi_pk     = max(abs(epsi));
S.v_pk       = max(abs(v));
S.v_ss       = mean(abs(v(mid)));
S.e_final    = dg(end);
S.epsi_final = epsig(end);
S.e_ss       = mean(dg(ss:end));
S.epsi_ss    = mean(abs(epsig(ss:end)));
S.T_pk       = max(max(abs(TL)), max(abs(TR)));
S.d_pk       = max(max(abs(dL)), max(abs(dR)));
S.d_mean     = mean([abs(dL(mv)); abs(dR(mv))]);
S.f_dsat     = 100*mean(max(abs(dL), abs(dR)) > dmx - 0.05);
S.f_ksat     = 100*mean(kscl < 0.999);
S.w_err      = [max(abs(Xa-Xc)), max(abs(Ya-Yc)), max(abs(Na-Nc))];
if mode == 3, lv = [1 2 3]; else, lv = 1; end
S.t_phase = nan(size(lv));
for i = 1:numel(lv)
    j = find(phase >= lv(i), 1);
    if ~isempty(j), S.t_phase(i) = t(j); end
end

%  이름표를 단 창을 찾아 다시 쓴다 — 돌릴 때마다 창이 쌓이지 않게
S.fig = A3_fig('A3_result', ['A3  ' ttl], [80 60 1240 800]);

% ---- 1. 궤적 --------------------------------------------------------
if mode == 3
    subplot(2,3,1);
else
    subplot(2,3,[1 4]);
end
th = linspace(0, 2*pi, 72);
if mode == 3
    [qX, qY, ~, ~, mX, mY] = A3_dock_patch(dx, dy, dpsi, sd);
    plot([0 apy mY dy], [0 apx mX dx], 'k--', 'LineWidth',1.2); hold on;
    patch(qY, qX, [0.82 0.76 0.66], 'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
    plot(apy, apx, 'o', 'MarkerEdgeColor',[0 0.5 0], 'MarkerFaceColor','w', ...
         'MarkerSize',9, 'LineWidth',1.6);
    plot(apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
    leg = {'계획 경로','도킹 스테이션','접근점','R_{dock}'};
else
    plot([0 gy], [0 gx], 'k--', 'LineWidth',1.2); hold on;
    leg = {'계획 경로'};
end

span = max([max(x_n)-min(x_n); max(y_n)-min(y_n); 2*Rs; hypot(gx-x_n(1), gy-y_n(1))]);
if mode == 3
    Lpsi = 3.4;   sc = 1;
else
    Lpsi = max(2, 0.12*span);
    sc   = min(2, max(0.4, 0.10*span/4.9));
end
L = 2.45*sc;  B = 1.03*sc;
bx = L*[-1 -1 0.5 1 0.5];  by = B*[1 -1 -1 0 1];

plot(gy, gx, 'ks', 'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.6);
plot([gy gy+Lpsi*sin(gpsi)], [gx gx+Lpsi*cos(gpsi)], '-', 'Color',[0.75 0.10 0.10], ...
     'LineWidth',1.8);
plot(gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.6 0.6 0.6]);
cg = cos(gpsi);  sg = sin(gpsi);
plot(gy + [bx bx(1)]*sg + [by by(1)]*cg, gx + [bx bx(1)]*cg - [by by(1)]*sg, ...
     '--', 'Color',[0.75 0.10 0.10], 'LineWidth',1.3);
plot(y_n, x_n, 'b-', 'LineWidth',1.6);
plot(y_n(1), x_n(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',8);
plot(y_n(end), x_n(end), 'ro', 'MarkerFaceColor','r', 'MarkerSize',8);
c = cos(psi(end));  s = sin(psi(end));
patch(y_n(end) + bx*s + by*c, x_n(end) + bx*c - by*s, [0.95 0.45 0.20], ...
      'FaceAlpha',0.5, 'EdgeColor',[0.4 0.15 0.05]);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title(sprintf('궤적   (마지막 오차 %.2f m, %.1f°)', S.e_final, S.epsi_final));

legList = [leg {'목표 위치','목표 선수각','R_{stop}','목표 자세(배)','항적','출발','도착'}];
if mode == 3
    pad = 2.0;
    zx = [min([qX gx x_n(end)])-pad, max([qX gx x_n(end)])+pad];
    zy = [min([qY gy y_n(end)])-pad, max([qY gy y_n(end)])+pad];
    plot(zy([1 2 2 1 1]), zx([1 1 2 2 1]), '-', 'Color',[0.45 0.45 0.45], ...
         'LineWidth',0.8, 'HandleVisibility','off');
    title(sprintf('궤적 전체   (마지막 오차 %.2f m, %.1f°)', S.e_final, S.epsi_final));
    text(apy+2.0, apx+2.5, '접근점', 'FontSize',8, 'Color',[0 0.45 0]);
    text(y_n(1)+2.0, x_n(1)-2.0, '출발', 'FontSize',8, 'Color',[0 0.45 0]);

    subplot(2,3,4);
    patch(qY, qX, [0.82 0.76 0.66], 'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
    hold on;
    plot([mY dy], [mX dx], 'k--', 'LineWidth',1.1);
    plot(gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    plot(gy + [bx bx(1)]*sg + [by by(1)]*cg, gx + [bx bx(1)]*cg - [by by(1)]*sg, ...
         '--', 'Color',[0.75 0.10 0.10], 'LineWidth',1.3);
    plot(y_n, x_n, 'b-', 'LineWidth',1.6);
    patch(y_n(end) + bx*s + by*c, x_n(end) + bx*c - by*s, [0.95 0.45 0.20], ...
          'FaceAlpha',0.5, 'EdgeColor',[0.4 0.15 0.05]);
    plot(gy, gx, 'ks', 'MarkerFaceColor','w', 'MarkerSize',9, 'LineWidth',1.4);
    axis equal;  xlim(zy);  ylim(zx);  grid on;
    xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
    title('접안 확대 — 배와 베이가 실척');
    legend({'도킹 스테이션','계획 경로','R_{stop}','목표 자세(배)','항적', ...
            '도착 자세','목표 위치'}, ...
           'Location','southoutside', 'NumColumns',3, 'FontSize',7.5, 'Box','off');
else
    legend(legList, 'Location','southoutside', 'NumColumns',3, ...
           'FontSize',7.5, 'Box','off');
end

% ---- 2. 위치 오차 ----------------------------------------------------
subplot(2,3,2);
plot(t, eN, 'LineWidth',1.4); hold on;
plot(t, eE, 'LineWidth',1.4);
plot(t, d, '-.', 'Color',[0.2 0.2 0.2], 'LineWidth',1.2);
yline(0,'k:');  yline(Rs,':','Color',[.6 .6 .6]);  yline(-Rs,':','Color',[.6 .6 .6]);
grid on; xlabel('시간 [s]'); ylabel('오차 [m]');
legend({'북 오차','동 오차','거리'}, 'Location','best','FontSize',8);
title(sprintf('위치 오차   (R_{stop} = %g m)', Rs));

% ---- 3. 선수각 — 이 부록의 머리 그림 ---------------------------------
subplot(2,3,3);
plot(t, atan2(sin(pref),cos(pref))*180/pi, '--', 'LineWidth',1.4); hold on;
plot(t, atan2(sin(psi), cos(psi))*180/pi, '-', 'LineWidth',1.2);
plot(t, epsi, ':', 'Color',[0.2 0.6 0.2], 'LineWidth',1.2);
grid on; xlabel('시간 [s]'); ylabel('각도 [deg]');
yl = ylim;  if diff(yl) < 2, ylim(mean(yl) + [-1 1]); end
legend({'\psi_{ref} 지령','\psi 선수각','오차'}, 'Location','best','FontSize',8);
title(sprintf('선수각   (오차 RMS %.3f° · 최대 %.3f°)', S.psi_rms, S.psi_pk));

% ---- 4. 속도 --------------------------------------------------------
subplot(2,3,5);
yyaxis left
plot(t, u, '-', 'LineWidth',1.4); hold on;
plot(t, v, '--', 'LineWidth',1.4);
ylabel('속도 [m/s]');
yyaxis right
plot(t, r*180/pi, ':', 'LineWidth',1.2);
ylabel('r [deg/s]');
if max(abs(r))*180/pi < 0.5, ylim([-0.5 0.5]); end
grid on; xlabel('시간 [s]');
legend({'u 서지','v 횡이동','r 요'}, 'Location','best','FontSize',8);
title(sprintf('속도   (최대 |v| %.3f · 정상 구간 %.3f m/s)', S.v_pk, S.v_ss));

% ---- 5. 추력과 방향각 ------------------------------------------------
subplot(2,3,6);
yyaxis left
plot(t, TL, '-', 'LineWidth',1.3); hold on;
plot(t, TR, '-', 'LineWidth',1.3);
yline( Fm,'r:');  yline(-Fm,'r:');  yline(0,'k:');
ylabel('추력 [N]');
yyaxis right
plot(t, dL, '--', 'LineWidth',1.3);
plot(t, dR, '--', 'LineWidth',1.3);
yline( dmx,':','Color',[0.5 0 0.5]);  yline(-dmx,':','Color',[0.5 0 0.5]);
ylabel('방향각 [deg]');  ylim([-1.15*dmx 1.15*dmx]);
grid on; xlabel('시간 [s]');
legend({'T_L','T_R','\pmF_{max}','','0','\delta_L','\delta_R','\pm\delta_{max}'}, ...
       'Location','best','FontSize',7.5);
title(sprintf('추력과 방향각   (최대 |T| %.0f N · |\\delta| %.1f°)', S.T_pk, S.d_pk));

% ---- 성능 지표 --------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
fprintf('  선수각 오차 RMS      %8.4f deg   <- 횡이동 중 흔들림\n', S.psi_rms);
fprintf('  선수각 오차 최대     %8.4f deg\n', S.psi_pk);
fprintf('  최대 |v| 횡속도      %8.3f m/s   (정상 구간 평균 %.3f)\n', S.v_pk, S.v_ss);
if isnan(S.t_done)
    fprintf('  도착 판정                미완료 (gate 가 끝까지 1)\n');
else
    fprintf('  도착 시각            %8.1f s\n', S.t_done);
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
fprintf('  마지막 10초 평균     %8.3f m  / %6.2f deg\n', S.e_ss, S.epsi_ss);
fprintf('  최대 추력 |T|        %8.1f N     (한계 %.0f N)\n', S.T_pk, Fm);
fprintf('  최대 방향각 |delta|  %8.2f deg   (한계 %.0f deg · 순수 횡이동 %.2f)\n', ...
        S.d_pk, dmx, dsw);
fprintf('  각도 한계에 붙은 시간%8.1f %%\n', S.f_dsat);
fprintf('  추력 축소가 걸린 시간%8.1f %%\n', S.f_ksat);
fprintf('  요구 대비 실제 차이  X %.2f N · Y %.2f N · N %.2f N m\n', S.w_err);

% ---- 점검 그림 — 각도 한계와 요구 대비 실제 ---------------------------
%   창을 따로 쓰는 까닭 — 결과 창은 "과업을 해냈는가", 점검 창은 "배분이
%   성립했는가" 를 본다. 보는 사람이 다르고 보는 때가 다르다
S.chk     = A3_check(out, ttl);
S.fig_chk = S.chk.fig;
S.w_free  = S.chk.w_free;          % 한계가 안 물린 구간의 차이 — 0 이어야 한다
S.w_sat   = S.chk.w_sat;           % 한계가 물린 구간의 차이 — 한계 탓이다
figure(S.fig);                     % 결과 창을 다시 앞으로

end
