function C = A3_check(out, ttl)
% A3_CHECK  시뮬레이션이 끝난 뒤의 점검 그림 — 두 가지 질문에 숫자로 답한다
%
%   (1) 방향각이 **늘 ±45 deg 안에** 있었는가
%   (2) 제어기가 **요구한** 힘·모멘트를 추진기가 **실제로** 냈는가
%       냈다면 배분식이 등식으로 풀렸다는 뜻이고,
%       못 냈다면 그 순간 **각도 한계인지 추력 한계인지**까지 가른다
%
%   사용법
%     >> C = A3_check(out, '1단 · 순수 횡이동')
%     A3_plot 이 끝에서 자동으로 부른다 — 따로 칠 일은 없다
%
%   반환값 C — **측정한 값만**
%     C.fig        그림 창 손잡이
%     C.d_pk       최대 |delta| [deg]
%     C.d_over     한계를 넘은 폭 [deg]  (0 이면 한 번도 안 넘었다)
%     C.f_dsat     각도가 한계에 붙어 있던 시간 비율 [%]
%     C.f_ksat     추력 축소가 걸린 시간 비율 [%]
%     C.f_rsat     각도가 변화율 한계에 걸려 있던 시간 비율 [%]
%     C.w_err      요구 대비 실제의 최대 차이 [N, N, N m] — 전 구간
%     C.w_free     한계가 **물리지 않은** 구간의 최대 차이 [N, N, N m]
%     C.w_sat      한계가 **물린** 구간의 최대 차이 [N, N, N m]
%     C.f_cls      원인별 시간 비율 [%] — [없음, 각도만, 추력만, 둘 다]
%
%   왜 차이를 두 구간으로 나누는가
%     배분식은 등식이다. 한계가 하나도 물리지 않으면 차이는 기계 정밀도 (1e-13) 다.
%     그러므로 w_free 가 0 이 아니면 **식이 틀린 것**이고,
%     w_sat 가 0 이 아닌 것은 **한계 때문**이다 — 성격이 전혀 다르다.
%     한계는 셋이다 — 각도 한계(as) · 추력 축소(ks) · 각도 변화율(rs).
%     변화율을 빼고 세면 공통 각도 방식에서 w_free 가 121 N 으로 나온다 (실측).
%     식이 틀린 것이 아니라 **지령 각도가 ±45 deg 사이를 튀어** 실제 각도가
%     따라가지 못한 것이다

if nargin < 2, ttl = ''; end

Fm  = evalin('base','F_max');
dmx = evalin('base','d_max')*180/pi;
dsw = evalin('base','d_sway')*180/pi;
Ymx = evalin('base','Y_max');
drt = evalin('base','d_rate')*180/pi;

t    = out.log_x_n.Time;
TL   = out.log_TL.Data;          TR = out.log_TR.Data;
dL   = out.log_dL.Data*180/pi;   dR = out.log_dR.Data*180/pi;
kscl = out.log_kscl.Data;
phase = out.log_phase.Data;
Xc = out.log_X_c.Data;  Yc = out.log_Y_c.Data;  Nc = out.log_N_c.Data;
Xa = out.log_X_a.Data;  Ya = out.log_Y_a.Data;  Na = out.log_N_a.Data;

dAbs = max(abs(dL), abs(dR));
E    = [Xa-Xc, Ya-Yc, Na-Nc];           % 요구 대비 실제의 차이

%  한계가 물렸는가 — 세 가지를 따로 센다
as = dAbs > dmx - 0.05;                 % 각도가 한계에 붙어 있다
ks = kscl < 0.999;                      % 추력이 넘쳐 전체를 줄였다

%  각도가 **변화율 한계에 걸려 지령을 못 따라가는** 구간도 센다
%    로그의 dL·dR 은 변화율 제한을 지난 **실제 각도**다. 지령이 ±45 deg 사이를
%    튀면 실제 각도는 내내 슬루 중이고, 한계에 붙지 않았어도 요구와 어긋난다
%    (공통 각도 방식에서 시간의 36.9 % 가 이 상태였다 — 실측)
dt = diff(t);
sl = max(abs(diff(dL))./dt, abs(diff(dR))./dt) > 0.99*drt;
rs = [sl; false] | [false; sl];         % 변화율 한계에 걸려 있다 (앞뒤 한 스텝 포함)

sat = as | ks | rs;

C.d_pk   = max(dAbs);
C.d_over = max(0, C.d_pk - dmx);
C.f_dsat = 100*mean(as);
C.f_ksat = 100*mean(ks);
C.f_rsat = 100*mean(rs);
C.w_err  = max(abs(E), [], 1);
C.w_free = pick_max(E, ~sat);
C.w_sat  = pick_max(E,  sat);
C.f_cls  = 100*[mean(~as & ~ks), mean(as & ~ks), mean(~as & ks), mean(as & ks)];

C.fig = A3_fig('A3_check', ['A3 점검  ' ttl], [120 70 1480 820]);

% ---- 1. 방향각 이력 — ±45 deg 밴드 -----------------------------------
ax = subplot(2,4,1);
yl = 1.25*dmx;
patch([t(1) t(end) t(end) t(1)], [-dmx -dmx dmx dmx], [0.88 0.97 0.88], ...
      'EdgeColor','none'); hold on;
shade_mask(ax, t, as, [0.99 0.88 0.80]);          % 한계에 붙은 구간
plot(t, dL, '-',  'Color',[0 0.35 0.85], 'LineWidth',1.4);
plot(t, dR, '--', 'Color',[0.55 0.15 0.65], 'LineWidth',1.4);
yline( dmx, 'r-', 'LineWidth',1.2);  yline(-dmx, 'r-', 'LineWidth',1.2);
yline( dsw, ':', 'Color',[0.45 0.45 0.45]);
yline(-dsw, ':', 'Color',[0.45 0.45 0.45]);
yline(0, 'k:');
ylim([-yl yl]);  grid on;  xlabel('시간 [s]');  ylabel('\delta [deg]');
legend({'\pm45° 허용 구역','한계 접촉','\delta_L','\delta_R'}, ...
       'Location','southoutside', 'NumColumns',2, 'FontSize',7.5, 'Box','off');
if C.d_over > 0
    title(sprintf('방향각 — **한계 밖 %.2f°**', C.d_over), 'Color',[0.80 0 0]);
elseif C.f_dsat > 1
    title(sprintf('방향각 — 한계 안이나 %.0f %% 는 붙어 있다', C.f_dsat), ...
          'Color',[0.85 0.45 0]);
else
    title(sprintf('방향각 — ±%.0f° 안 (최대 %.2f°)', dmx, C.d_pk), ...
          'Color',[0 0.50 0.10]);
end

% ---- 2. |delta| 분포 -------------------------------------------------
subplot(2,4,2);
histogram(abs([dL; dR]), 'BinWidth',1, 'FaceColor',[0.35 0.55 0.85], ...
          'EdgeColor','none'); hold on;
xline(dmx, 'r-', 'LineWidth',1.4);
xline(dsw, ':', 'Color',[0.45 0.45 0.45], 'LineWidth',1.2);
grid on;  xlabel('|\delta| [deg]');  ylabel('샘플 수');
xlim([0 max(dmx*1.1, C.d_pk*1.1)]);
legend({'|\delta| 분포', sprintf('한계 %.0f°', dmx), ...
        sprintf('순수 횡이동 %.2f°', dsw)}, ...
       'Location','northwest', 'FontSize',7.5, 'Box','off');
title('방향각 분포 — 한계선을 넘는 막대가 없어야 한다');

% ---- 3. 선체 고정 (Fx, Fy) 자취와 ±45 deg 쐐기 ------------------------
subplot(2,4,3);
FxL = TL.*cosd(dL);  FyL = TL.*sind(dL);
FxR = TR.*cosd(dR);  FyR = TR.*sind(dR);
%   눈금은 **데이터에 맞춘다**. F_max 로 고정하면 점이 원점에 뭉쳐 보이지 않는다
R  = max(1.35*max(abs([FxL; FyL; FxR; FyR])), 0.30*Fm);
tb = tand(dmx);
th = linspace(0, 2*pi, 180);
patch([0 R  R], [0 -R*tb R*tb], [0.90 0.95 1.00], 'EdgeColor','none'); hold on;
patch([0 -R -R], [0 R*tb -R*tb], [0.99 0.90 0.90], 'EdgeColor','none');
plot([-R R], [-R*tb R*tb], 'r-', 'LineWidth',1.0, 'HandleVisibility','off');
plot([-R R], [ R*tb -R*tb], 'r-', 'LineWidth',1.0, 'HandleVisibility','off');
plot([-R R], [0 0], 'k:', 'HandleVisibility','off');
plot([0 0], [-R R], 'k:', 'HandleVisibility','off');
lg = {'앞으로 미는 ±45° 쐐기','뒤로 미는 쐐기 (추력 반전)'};
if R >= Fm                                   % 화면 밖이면 그리지 않는다
    plot(Fm*cos(th), Fm*sin(th), ':', 'Color',[0.75 0.10 0.10], 'LineWidth',1.1);
    lg = [lg {sprintf('|T| = %.0f N 한계', Fm)}];
end
plot(FxL, FyL, '.', 'Color',[0 0.35 0.85], 'MarkerSize',6);
plot(FxR, FyR, '.', 'Color',[0.55 0.15 0.65], 'MarkerSize',6);
axis equal;  xlim([-R R]);  ylim([-R R]);  grid on;
xlabel('F_x 앞 방향 [N]');  ylabel('F_y 오른쪽 [N]');
legend([lg {'왼쪽 추진기','오른쪽 추진기'}], ...
       'Location','southoutside', 'NumColumns',2, 'FontSize',7, 'Box','off');
title('추력 벡터는 쐐기 안에만 있어야 한다');

% ---- 4. 판정 ---------------------------------------------------------
subplot(2,4,4);  axis off;
if C.d_over > 0
    v1 = sprintf('각도 한계를 %.2f° 넘었다 — 모델을 의심할 것', C.d_over);
    c1 = [0.80 0 0];
elseif C.f_dsat > 1
    v1 = sprintf('±%.0f° 안이지만 %.0f %% 구간에서 한계에 붙었다', dmx, C.f_dsat);
    c1 = [0.85 0.45 0];
else
    v1 = sprintf('±%.0f° 안 — 최대 %.2f° (여유 %.2f°)', dmx, C.d_pk, dmx-C.d_pk);
    c1 = [0 0.50 0.10];
end
fr = max(C.w_free(1:2));
if fr > 1e-6
    v2 = sprintf('한계가 안 물렸는데도 %.3g N 어긋난다 — 배분식 오류', fr);
    c2 = [0.80 0 0];
else
    v2 = sprintf('한계가 안 물린 구간: 요구 = 실제 (차이 %.1e N)', fr);
    c2 = [0 0.50 0.10];
end
sr = max(C.w_sat(1:2));
if sr > 1e-6
    v3 = sprintf('한계가 물린 구간: 최대 %.1f N 을 못 냈다', sr);
    c3 = [0.85 0.45 0];
else
    v3 = '한계가 물린 구간 없음';
    c3 = [0 0.50 0.10];
end
text(0, 1.00, '점검 결과', 'FontWeight','bold', 'FontSize',11);
text(0, 0.88, ['1.  ' v1], 'Color',c1, 'FontSize',9);
text(0, 0.78, ['2.  ' v2], 'Color',c2, 'FontSize',9);
text(0, 0.68, ['3.  ' v3], 'Color',c3, 'FontSize',9);
%   한글 글꼴이 없는 고정폭 글꼴을 지정하면 글자가 네모로 나온다 — 기본 글꼴
text(0, 0.52, sprintf(['원인별 시간 비율\n' ...
    '    한계 없음 :  %.1f %%\n' ...
    '    각도만 물림 :  %.1f %%\n' ...
    '    추력만 물림 :  %.1f %%\n' ...
    '    둘 다 물림 :  %.1f %%'], C.f_cls), 'FontSize',9, ...
    'VerticalAlignment','top');
text(0, 0.17, sprintf(['요구 대비 실제의 최대 차이\n' ...
    '    X :  %.2f N\n    Y :  %.2f N\n    N :  %.2f N m'], C.w_err), ...
    'FontSize',9, 'VerticalAlignment','top');
xlim([0 1]); ylim([0 1.05]);

% ---- 5~7. 축마다 요구와 실제 -----------------------------------------
nm = {'X 전후 [N]','Y 횡 [N]','N 요 모멘트 [N m]'};
cm = {Xc, Yc, Nc};  am = {Xa, Ya, Na};
for i = 1:3
    axi = subplot(2,4,4+i);
    shade_mask(axi, t, sat, [0.99 0.90 0.84]);  hold on;
    plot(t, cm{i}, '--', 'Color',[0.10 0.10 0.10], 'LineWidth',1.5);
    plot(t, am{i}, '-',  'Color',[0.20 0.55 0.90], 'LineWidth',1.1);
    if i == 2, yline( Ymx,'r:');  yline(-Ymx,'r:'); end
    yline(0,'k:');
    mark_phase(t, phase);
    pad_fit(axi, [cm{i}; am{i}]);
    grid on;  xlabel('시간 [s]');  ylabel(nm{i});
    legend({'한계 물림','요구','실제'}, 'Location','best', 'FontSize',7.5);
    if C.w_err(i) > 1e-6
        title(sprintf('%s — 최대 차이 %.2f', nm{i}, C.w_err(i)), 'Color',[0.80 0 0]);
    else
        title(sprintf('%s — 완전히 겹침', nm{i}), 'Color',[0 0.50 0.10]);
    end
end

% ---- 8. 차이와 그 원인 ------------------------------------------------
axd = subplot(2,4,8);
shade_mask(axd, t, as & ~ks, [0.98 0.86 0.76]);  hold on;
shade_mask(axd, t, ks, [0.86 0.90 0.99]);
shade_mask(axd, t, rs & ~as & ~ks, [0.90 0.95 0.86]);
yyaxis left
plot(t, E(:,1), '-',  'Color',[0.20 0.45 0.90], 'LineWidth',1.3);
plot(t, E(:,2), '-',  'Color',[0.60 0.20 0.75], 'LineWidth',1.3);
ylabel('힘 차이 [N]');   pad_y_min(axd, E(:,1:2), 1.0);
yyaxis right
plot(t, E(:,3), '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.3);
ylabel('모멘트 차이 [N m]');  pad_y_min(axd, E(:,3), 1.0);
grid on;  xlabel('시간 [s]');
legend({'각도 한계','추력 축소','변화율 한계','X_a-X_c','Y_a-Y_c','N_a-N_c'}, ...
       'Location','southoutside', 'NumColumns',3, 'FontSize',7, 'Box','off');
title(sprintf('못 낸 몫과 원인 [%%] 각%.0f·추%.0f·율%.0f', ...
              C.f_dsat, C.f_ksat, C.f_rsat));

% ---- 표로 한 번 더 ----------------------------------------------------
fprintf('  --- 점검 ---\n');
fprintf('  최대 |delta|         %8.2f deg  (한계 %.0f · 밖으로 %.2f)\n', ...
        C.d_pk, dmx, C.d_over);
fprintf('  한계 안 물린 구간    X %.2e · Y %.2e · N %.2e   <- 0 이어야 한다\n', C.w_free);
fprintf('  한계 물린 구간       X %8.2f · Y %8.2f · N %8.2f\n', C.w_sat);
fprintf('  원인별 시간 [%%]      없음 %.1f · 각도 %.1f · 추력 %.1f · 둘 다 %.1f\n', ...
        C.f_cls);
fprintf('  변화율 한계 걸림     %.1f %%  — 지령 각도가 튀면 실제 각도가 못 따라간다\n', C.f_rsat);
if ~isempty(phase) && max(phase) > 1
    fprintf('  (단계가 바뀌는 순간의 차이는 지령이 튄 한 스텝이다)\n');
end
end

% ======================================================================
function w = pick_max(E, m)
%  마스크가 가리키는 구간의 축별 최대 |차이|. 빈 구간이면 0
if ~any(m)
    w = [0 0 0];
else
    w = max(abs(E(m,:)), [], 1);
end
end

function shade_mask(ax, t, m, col)
%  논리 마스크가 참인 구간을 세로 띠로 칠한다 — 연속 구간마다 패치 하나
%
%  범례용 빈 패치를 **늘 먼저** 하나 만든다. 구간이 없다고 해서 패치를
%  하나도 안 만들면 범례 글이 한 칸씩 밀려 엉뚱한 선에 붙는다
hold(ax, 'on');
patch(ax, nan(1,4), nan(1,4), col, 'EdgeColor','none');
if ~any(m), return, end
d  = diff([false; m(:); false]);
i1 = find(d ==  1);
i2 = find(d == -1) - 1;
yl = [-1e6 1e6];
for k = 1:numel(i1)
    a = t(i1(k));  b = t(min(i2(k)+1, numel(t)));
    if b <= a, b = a + 1e-3; end
    patch(ax, [a b b a], [yl(1) yl(1) yl(2) yl(2)], col, ...
          'EdgeColor','none', 'HandleVisibility','off');
end
end

function mark_phase(t, phase)
%  단계가 올라간 시각에 세로 점선 — 차이가 튀는 자리가 전이인지 보려고
if isempty(phase) || max(phase) <= 1, return, end
j = find(diff(phase(:)) > 0) + 1;
for k = 1:numel(j)
    xline(t(j(k)), ':', 'Color',[0.45 0.45 0.45], 'HandleVisibility','off');
end
end

function pad_fit(ax, D)
%  데이터에 맞춰 y 범위를 잡는다 — shade_mask 의 큰 패치에 끌려가지 않게
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if ~isfinite(lo) || ~isfinite(hi), return, end
if hi - lo < 1e-9, lo = lo - 1;  hi = hi + 1; end
m = 0.10*(hi - lo);
ylim(ax, [lo-m, hi+m]);
end

function pad_y_min(ax, D, fl)
%  y 범위에 바닥을 둔다 — 차이가 1e-14 일 때 축이 노이즈를 확대하지 않게
hi = max(abs(D(:)), [], 'omitnan');
if isempty(hi) || ~isfinite(hi), return, end
lim = max(hi*1.15, fl);
ylim(ax, [-lim, lim]);
end
