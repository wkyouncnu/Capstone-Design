function S = W02_plot(out, ttl)
% W02_PLOT  목표 자세 제어 결과를 그리고 도착 성능을 수치로 돌려준다.
%
%   >> W02_setup
%   >> out = sim('W02_2_goto_offline');
%   >> S = W02_plot(out, '오프라인')
%
%   왼쪽 그림 읽는 법
%     파란 선          항적
%     회색 선체        출발 자세
%     주황 선체(윤곽)  중간 자세 — 이동 0.8 또는 회전 30 deg 마다 한 척
%     초록 선체(채움)  마지막 자세 + 좌표·선수각 표시
%     빨간 점선 선체   목표 자세
%     선체의 뾰족한 쪽 = 선수 = heading
%
%   반환값 S
%     e_pos     최종 위치 오차          (마지막 샘플)
%     e_th_deg  최종 선수각 오차 [deg]  (마지막 샘플)
%     t_go      위치 도착 시각 [s]      (모드 1 -> 2 로 바뀐 첫 시각)
%     t_done    완료 시각 [s]           (모드 3 이 된 첫 시각. 없으면 NaN)

if nargin < 2, ttl = ''; end

t    = out.log_x.Time;
x    = squeeze(out.log_x.Data);
y    = squeeze(out.log_y.Data);
th   = squeeze(out.log_th.Data);
v    = squeeze(out.log_v.Data);
w    = squeeze(out.log_w.Data);
dist = squeeze(out.log_dist.Data);
eth  = squeeze(out.log_e_th.Data);
mode = squeeze(out.log_mode.Data);

% 첫 자세가 오기 전(0,0 으로 채운 샘플)은 그림에서 뺀다
valid = ~(x == 0 & y == 0);
k0 = find(valid, 1);  if isempty(k0), k0 = 1; end

xg  = evalin('base','x_goal');
yg  = evalin('base','y_goal');
thg = evalin('base','theta_goal');

S.e_pos    = dist(end);
S.e_th_deg = rad2deg(abs(eth(end)));
k2 = find(mode >= 2, 1);   S.t_go   = NaN; if ~isempty(k2), S.t_go   = t(k2); end
k3 = find(mode >= 3, 1);   S.t_done = NaN; if ~isempty(k3), S.t_done = t(k3); end

figure('Name',['W02 결과 ' ttl], 'NumberTitle','off', 'Color','w', ...
       'Position',[100 100 1180 680]);

%% ---- 왼쪽 : 항적과 선체 --------------------------------------------------
ax = subplot(3,2,[1 3 5]); hold(ax,'on'); grid(ax,'on');
xlabel(ax,'x'); ylabel(ax,'y');

C_TRAIL = [0.00 0.45 0.74];
C_MID   = [0.85 0.47 0.02];
C_END   = [0.13 0.55 0.13];
C_GOAL  = [0.80 0.15 0.15];

% 항적
hTrail = plot(ax, x(k0:end), y(k0:end), '-', 'Color',C_TRAIL, 'LineWidth',1.6);

% 중간 자세 — 이동 0.8 또는 회전 30 deg 마다 한 척. 시각을 옆에 적는다
kLast = k0;  hMid = gobjects(0);
for k = k0+1:numel(t)-1
    moved  = hypot(x(k)-x(kLast), y(k)-y(kLast));
    turned = abs(mod(th(k)-th(kLast)+pi, 2*pi) - pi);
    if moved >= 0.8 || turned >= deg2rad(30)
        [hX, hY] = W02_hull(x(k), y(k), th(k));
        hMid = patch(ax, hX, hY, 'w', 'EdgeColor',C_MID, 'LineWidth',1.3);
        plot(ax, x(k), y(k), '.', 'Color',C_MID, 'MarkerSize',10);
        if moved >= 0.8          % 제자리 회전 구간은 글자가 겹치므로 시각을 생략
            text(ax, x(k)+0.25, y(k)+0.35, sprintf('%.1fs', t(k)), ...
                 'Color',C_MID, 'FontSize',9);
        end
        kLast = k;
    end
end

% 출발 자세 — 회색 채움
[sX, sY, shx, shy] = W02_hull(x(k0), y(k0), th(k0));
hStart = patch(ax, sX, sY, [0.75 0.75 0.75], 'EdgeColor',[0.3 0.3 0.3], 'LineWidth',1.3);
plot(ax, shx, shy, '-', 'Color',[0.3 0.3 0.3], 'LineWidth',1.3);
text(ax, x(k0)-0.2, y(k0)+0.7, sprintf('출발 (%.2f, %.2f)', x(k0), y(k0)), ...
     'FontSize',10, 'Color',[0.3 0.3 0.3], 'HorizontalAlignment','center');

% 마지막 자세 — 초록 채움 + 좌표·선수각
[eX, eY, ehx, ehy] = W02_hull(x(end), y(end), th(end));
hEnd = patch(ax, eX, eY, C_END, 'FaceAlpha',0.85, 'EdgeColor',[0.05 0.3 0.05], 'LineWidth',1.4);
plot(ax, ehx, ehy, '-', 'Color',[0.05 0.3 0.05], 'LineWidth',2);
plot(ax, x(end), y(end), 'k.', 'MarkerSize',14);
text(ax, x(end)+0.5, y(end)-0.55, ...
     sprintf('끝 (%.2f, %.2f)\n\\theta = %.1f°', x(end), y(end), rad2deg(th(end))), ...
     'FontSize',10, 'Color',[0.05 0.3 0.05], 'FontWeight','bold');

% 목표 자세 — 빨간 점선 선체. 마지막 자세 위에 그려야 겹쳐도 보인다
[gX, gY, ghx, ghy] = W02_hull(xg, yg, thg);
hGoal = plot(ax, gX, gY, '--', 'Color',C_GOAL, 'LineWidth',1.8);
plot(ax, ghx, ghy, '--', 'Color',C_GOAL, 'LineWidth',1.4);
plot(ax, xg, yg, '+', 'Color',C_GOAL, 'MarkerSize',10, 'LineWidth',1.8);

% 축 — 항적과 목표가 들어오는 영역만 확대한다 (turtlesim 벽 0 ~ 11.09 안에서)
bx = [x(k0:end); xg];  by = [y(k0:end); yg];
cx = (min(bx)+max(bx))/2;  cy = (min(by)+max(by))/2;
half = max([max(bx)-min(bx), max(by)-min(by)])/2 + 1.2;
axis(ax,'equal');
axis(ax, [cx-half cx+half cy-half cy+half]);

legH = [hTrail hStart hEnd hGoal];  legS = {'항적','출발 자세','마지막 자세','목표 자세'};
if ~isempty(hMid), legH(end+1) = hMid; legS{end+1} = '중간 자세'; end
legend(ax, legH, legS, 'Location','southoutside', 'NumColumns',3, 'FontSize',9);
title(ax, {sprintf('%s — 항적과 선수 방향 (뾰족한 쪽 = 선수)', ttl), ...
           sprintf('위치오차 %.3f,  선수각오차 %.2f°', S.e_pos, S.e_th_deg)}, ...
      'FontWeight','normal');

%% ---- 오른쪽 : 시간 응답 --------------------------------------------------
subplot(3,2,2); plot(t, dist, 'LineWidth',1.4); grid on;
ylabel('거리'); title('목표점까지 거리');

subplot(3,2,4); plot(t, rad2deg(th), t, rad2deg(thg)*ones(size(t)), '--', 'LineWidth',1.4);
grid on; ylabel('\theta [deg]'); legend({'\theta','\theta_{goal}'}, 'Location','best');

subplot(3,2,6); yyaxis left;  plot(t, v, 'LineWidth',1.4); ylabel('v, w');
hold on; plot(t, w, ':', 'LineWidth',1.4);
yyaxis right; stairs(t, mode, 'LineWidth',1.2); ylabel('mode'); ylim([0.5 3.5]);
grid on; xlabel('t [s]'); legend({'v','w','mode'}, 'Location','best');

fprintf('[%s] 위치오차 %.4f | 선수각오차 %.3f deg | 위치도착 %.2f s | 완료 %.2f s\n', ...
        ttl, S.e_pos, S.e_th_deg, S.t_go, S.t_done);
end
