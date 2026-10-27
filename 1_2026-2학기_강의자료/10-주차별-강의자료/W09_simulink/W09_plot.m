function S = W09_plot(out, ttl)
%W09_PLOT  9주차 회피 주행 결과를 그린다. 5주차 그림에 회피 한 줄을 더한 것이다.
%
%   S = W09_plot(out, '제목')
%
%   5주차와 **다르게 재는 것** 둘 — 여기가 이 함수의 요점이다
%
%     1. 횡방향 오차 y_e 를 전 구간 평균으로 재지 않는다.
%        회피하는 동안 배는 경로를 **일부러** 벗어난다. 그 구간을 섞어 평균을
%        내면 "추종이 나빠졌다" 는 숫자가 나오는데 실제로는 피한 것이다.
%        그래서 추종 성능은 oa = 0 인 구간(= 시뮬링크 LOS 가 조타한 구간)에서만
%        재고, 회피 구간은 따로 적는다.
%
%     2. 이 주차의 합격 숫자는 y_e 가 아니라 **최소 여유**다.
%        장애물 중심까지 가장 가까이 지나간 거리다. 충돌을 면했는가를 그 한
%        숫자가 말한다. 월드 SDF 에 적힌 참값(obs_x_n · obs_y_n)과 재므로
%        라이다가 잘 보았는지와 무관하게 재어진다.
%
%   돌려주는 것 S
%     .clear_min .clear_at_x   최소 여유 [m] 와 그때의 x_n [m]
%     .oa_n .oa_time .oa_frac  회피가 켜진 횟수 · 회피한 시간 [s] · 비율
%     .mean_ye_los .max_ye_los LOS 구간만의 평균·최대 |y_e| [m]
%     .mean_ye_all             전 구간 평균 |y_e| (참고 — 회피가 섞여 있다)
%     .t_finish .mean_u .max_Ferr .fig
%
%   쓰는 base 변수  wp_north wp_east R_LOS u_ref Ts_ctrl F_max n_max
%                   obs_x_n obs_y_n   (모두 W09_setup 이 만든다)

if nargin < 2 || isempty(ttl), ttl = '회피 주행'; end

Ts    = evalin('base','Ts_ctrl');
u_ref = evalin('base','u_ref');
R_LOS = evalin('base','R_LOS');
F_max = evalin('base','F_max');
n_max = evalin('base','n_max');
ox    = evalin('base','obs_x_n');   oy = evalin('base','obs_y_n');

t    = out.log_x_n.Time;
x_n  = out.log_x_n.Data;     y_n  = out.log_y_n.Data;
ye   = out.log_y_e.Data;     gate = out.log_gate.Data;
psi  = out.log_psi.Data;     pref = out.log_psi_ref.Data;
plos = out.log_psi_los.Data; poa  = out.log_psi_oa.Data;
oa   = out.log_oa.Data;
u    = out.log_u.Data;
FL   = out.log_FL.Data;      FR   = out.log_FR.Data;

%  회전수는 2원소 벡터 신호다. 저장 모양이 [2 x 1 x N] 일 수도 [N x 2] 일 수도 있다
n = squeeze(out.log_n.Data);        if size(n,1)    ~= numel(t), n    = n.';    end
Ferr = squeeze(out.log_F_err.Data); if size(Ferr,1) ~= numel(t), Ferr = Ferr.'; end

%% 보는 구간 — 임무 완료까지 --------------------------------------------
k = find(gate < 0.5, 1);
if isempty(k), k = numel(t); S.t_finish = NaN; else, S.t_finish = t(k); end
kk = (1:k).';
s  = min(round(60/Ts), k);          % 초기 수렴 구간 제외 시작점 (5주차와 같은 자리)
on = oa(kk) > 0.5;                  % 회피 중인 샘플

%% 1. 최소 여유 — 이 주차의 합격 숫자 -----------------------------------
%  암시적 확장으로 [샘플 x 장애물] 거리표를 한 번에 만든다
D = hypot(x_n(kk) - ox(:).', y_n(kk) - oy(:).');
[S.clear_min, ii] = min(D(:));
i_t          = mod(ii-1, size(D,1)) + 1;
S.clear_at_x = x_n(i_t);
S.clear_at_t = t(i_t);

%% 2. 회피가 몇 번 · 얼마나 ---------------------------------------------
%  켜짐의 **상승 변이**만 센다. 강의노트가 "정확히 두 번 막힌다" 라고 말하므로
%  학생이 기대하는 숫자는 2 다. 켜짐·꺼짐을 함께 세면 4 가 나와 표와 어긋난다
S.oa_n    = sum(diff([0; double(on(:))]) > 0);
S.oa_time = sum(on) * Ts;
S.oa_frac = mean(on);

%% 3. 추종 성능 — LOS 구간만 --------------------------------------------
los = ~on;
los(1:max(s-1,0)) = false;                  % 초기 수렴 구간도 뺀다
if ~any(los), los = ~on; end                % 전부 회피였다면 그대로
S.mean_ye_los = mean(abs(ye(los)));
S.max_ye_los  = max(abs(ye(los)));
S.mean_ye_all = mean(abs(ye(kk)));
S.mean_u      = mean(u(s:k));
S.max_Ferr    = max(abs(Ferr(:)));

%% 4. 그림 --------------------------------------------------------------
S.fig = figure('Name',['W09  ' ttl], 'Position',[60 50 1240 800], 'Color','w');

% --- 궤적 -------------------------------------------------------------
subplot(2,3,[1 4]);
drawObstacles(oy, ox);  hold on;
wpx = evalin('base','wp_north');   wpy = evalin('base','wp_east');
plot(wpy, wpx, 'k--', 'LineWidth',1.0);
plot(wpy, wpx, 'ks', 'MarkerFaceColor','w', 'MarkerSize',7, 'HandleVisibility','off');
th = linspace(0, 2*pi, 60);
for i = 1:numel(wpx)
    plot(wpy(i)+R_LOS*cos(th), wpx(i)+R_LOS*sin(th), ':', 'Color',[.6 .6 .6], ...
         'HandleVisibility','off');
    text(wpy(i)+2, wpx(i), sprintf('%d',i), 'FontSize',8, 'Color',[.3 .3 .3]);
end
%  궤적을 두 색으로 나눠 그린다 — 파랑은 시뮬링크 LOS 가 조타한 구간, 빨강은
%  파이썬 회피가 조타한 구간이다. 색이 바뀌는 자리가 곧 이음새가 일한 자리다
%  (쓰지 않는 구간을 NaN 으로 비워 한 번의 plot 으로 끊어 그린다)
plot(nanMask(y_n(kk), los), nanMask(x_n(kk), los), 'b-', 'LineWidth',1.6);
plot(nanMask(y_n(kk), on),  nanMask(x_n(kk), on),  'r-', 'LineWidth',2.0);
plot(y_n(1), x_n(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
plot(y_n(k), x_n(k), 'ko', 'MarkerFaceColor','r', 'MarkerSize',8);
plot(y_n(i_t), x_n(i_t), 'kp', 'MarkerFaceColor','y', 'MarkerSize',13);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title(sprintf('궤적 — 최소 여유 %.1f m (x_n = %.0f)', S.clear_min, S.clear_at_x));
legend({'장애물(월드 참값)','웨이포인트','LOS 조타','회피 조타','출발','끝','최소 여유'}, ...
       'Location','southeast', 'FontSize',7);

% --- 헤딩 명령 셋 -----------------------------------------------------
subplot(2,3,[2 3]);
shadeOA(t(kk), on);  hold on;
plot(t(kk), unwrapDeg(plos(kk)), '--', 'Color',[0 .45 .74],  'LineWidth',1.1);
plot(t(kk), unwrapDeg(poa(kk)),  ':',  'Color',[.85 .33 .10],'LineWidth',1.3);
plot(t(kk), unwrapDeg(pref(kk)), '-',  'Color',[.2 .2 .2],   'LineWidth',1.5);
plot(t(kk), unwrapDeg(psi(kk)),  '-',  'Color',[.47 .67 .19],'LineWidth',1.0);
grid on; xlabel('시간 [s]'); ylabel('방위각 [deg]');
title('헤딩 명령 — 분홍 구간에서 psi_{ref} 가 LOS 에서 회피로 넘어간다');
legend({'회피 구간','psi_{los} (시뮬링크 LOS)','psi_{oa} (파이썬)', ...
        'psi_{ref} (제어기가 실제로 받은 것)','psi (현재 선수각)'}, ...
       'Location','best', 'FontSize',7);
ylim(padRange([unwrapDeg(plos(kk)); unwrapDeg(psi(kk))]));

% --- 횡방향 오차 ------------------------------------------------------
subplot(2,3,5);
shadeOA(t(kk), on);  hold on;
plot(t(kk), ye(kk), 'b-', 'LineWidth',1.2);
yline(0, 'k:');
grid on; xlabel('시간 [s]'); ylabel('y_e [m]');
ylim(padRange(ye(kk)));
title(sprintf('횡방향 오차 — LOS 구간 평균 %.2f m', S.mean_ye_los));

% --- 회피 깃발과 여유 -------------------------------------------------
subplot(2,3,6);
yyaxis left;
stairs(t(kk), double(on), '-', 'LineWidth',1.4);
ylim([-0.1 1.4]);  ylabel('oa (0 = LOS, 1 = 회피)');
yyaxis right;
plot(t(kk), min(D,[],2), '-', 'LineWidth',1.2);
ylabel('가장 가까운 장애물까지 [m]');
grid on; xlabel('시간 [s]');
title(sprintf('회피 %d회 · 총 %.0f s (%.0f%%)', S.oa_n, S.oa_time, 100*S.oa_frac));

%% 5. 추진기 — 5주차와 같은 형식 ----------------------------------------
figure('Name',['W09 추진기  ' ttl], 'Position',[120 110 1200 380], 'Color','w');
subplot(1,3,1);
plot(t(kk), FL(kk), '-', t(kk), FR(kk), '-', 'LineWidth',1.1); hold on;
yline( F_max, 'r:');  yline(-F_max, 'r:');
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R'}, 'Location','best');  title('좌·우 추력');

subplot(1,3,2);
plot(t(kk), n(kk,1), '-', t(kk), n(kk,2), '-', 'LineWidth',1.1); hold on;
yline( n_max, 'r:');  yline(-n_max, 'r:');
grid on; xlabel('시간 [s]'); ylabel('회전수 [rev/s]');
legend({'n_L','n_R'}, 'Location','best');  title('회전수');

subplot(1,3,3);
plot(t(kk), abs(Ferr(kk,:)), '-', 'LineWidth',1.1);
grid on; xlabel('시간 [s]'); ylabel('|F_{err}| [N]');
title(sprintf('왕복 검산 — 최대 %.2e N', S.max_Ferr));

%% 6. 숫자 --------------------------------------------------------------
fprintf('\n  === 9주차 회피 주행 지표 ===\n');
fprintf('  최소 여유        %6.2f m   (t = %.0f s, x_n = %.0f m)\n', ...
        S.clear_min, S.clear_at_t, S.clear_at_x);
fprintf('  회피 켜짐        %6d 회   총 %.0f s (%.0f%%)\n', ...
        S.oa_n, S.oa_time, 100*S.oa_frac);
fprintf('  평균 |y_e|       %6.2f m   <- LOS 구간만 (최대 %.2f)\n', ...
        S.mean_ye_los, S.max_ye_los);
fprintf('  (참고) 전 구간   %6.2f m   <- 회피가 섞여 있어 추종 지표가 아니다\n', ...
        S.mean_ye_all);
fprintf('  평균 속도        %6.2f m/s (지령 %.2f)\n', S.mean_u, u_ref);
fprintf('  추력 왕복 오차   %6.2e N\n', S.max_Ferr);
if isnan(S.t_finish)
    fprintf('  완주             아직 (정지 시간을 늘려 다시 돌린다)\n');
else
    fprintf('  완주 시각        %6.0f s\n', S.t_finish);
end
if S.clear_min < 3
    fprintf('  [경고] 여유 3 m 미만이다 — 라이다를 보았는지, oa 가 늦게 켜졌는지 본다\n');
end
end

% ======================================================================
function v = nanMask(v, keep)
%  keep 이 false 인 자리를 NaN 으로 만든다 — plot 이 그 자리를 끊어 그린다
v(~keep) = NaN;
end

function d = unwrapDeg(r)
%  ±180 경계에서 그림이 위아래로 튀는 것을 막는다
d = unwrap(r(:)) * 180/pi;
end

function r = padRange(v)
%  patch 를 ±1e4 로 깔았으므로 축을 그대로 두면 그림이 납작해진다.
%  띠가 아니라 **신호**가 축을 정하게 한다
v = v(isfinite(v));
if isempty(v), r = [-1 1]; return; end
lo = min(v);   hi = max(v);   d = max(hi-lo, eps);
r  = [lo - 0.08*d, hi + 0.08*d];
end

function shadeOA(t, on)
%  회피 구간을 분홍 띠로 깔아 둔다. 세 그림이 같은 띠를 쓰므로
%  "이 구간에서 명령이 넘어갔다" 를 눈으로 맞춰 읽을 수 있다
d  = diff([false; on(:); false]);
i0 = find(d ==  1);
i1 = find(d == -1) - 1;
ax = gca;   hold(ax, 'on');
for i = 1:numel(i0)
    x = [t(i0(i)) t(i1(i)) t(i1(i)) t(i0(i))];
    patch(ax, x, [-1e4 -1e4 1e4 1e4], [1 .85 .9], ...
          'EdgeColor','none', 'HandleVisibility', onceOnly(i==1));
end
end

function drawObstacles(oy, ox)
%  월드 SDF 에 적힌 자리다 (참값). 점은 중심이고 옅은 원은 읽기용 반경 2 m 다 —
%  부표마다 크기가 다르므로 원 자체를 충돌 판정으로 쓰지 않는다
th = linspace(0, 2*pi, 24);
hold on;
for i = 1:numel(ox)
    patch(oy(i)+2*cos(th), ox(i)+2*sin(th), [.9 .9 .9], ...
          'EdgeColor',[.7 .7 .7], 'HandleVisibility', onceOnly(i==1));
end
plot(oy, ox, '.', 'Color',[.45 .45 .45], 'MarkerSize',7, 'HandleVisibility','off');
end

function s = onceOnly(first)
%  같은 모양을 수십 개 그리므로 범례에는 첫 하나만 올린다
if first, s = 'on'; else, s = 'off'; end
end
