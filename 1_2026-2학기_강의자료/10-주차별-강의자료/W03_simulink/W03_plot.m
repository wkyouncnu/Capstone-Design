function S = W03_plot(out, ttl)
% W03_PLOT  VRX 주행 결과를 NED 평면과 시간 응답으로 그린다.
%
%   >> W03_setup
%   >> out = sim('W03_3_vrx_drive');
%   >> S = W03_plot(out, '직진 200/200 N')
%
%   왼쪽 그림 읽는 법
%     가로축 East · 세로축 North — 해도와 같다. 위쪽이 북쪽
%     회색 선체 = 출발 자세, 주황 윤곽 = 중간 자세, 초록 선체 = 마지막 자세
%     선체의 뾰족한 쪽이 선수
%
%   반환값 S
%     dist      이동 거리 [m]
%     speed     평균 대지속도 [m/s]   (유효 구간의 위치 차분)
%     dpsi_deg  선수각 변화량 [deg]   (부호가 선회 방향이다)
%     r_mean    평균 요각속도 [rad/s] (NED. 좌선회면 음수)
%     t_valid   첫 유효 샘플 시각 [s]

if nargin < 2, ttl = ''; end

t   = out.log_N.Time;
N   = squeeze(out.log_N.Data);
E   = squeeze(out.log_E.Data);
psi = squeeze(out.log_psi.Data);
r   = squeeze(out.log_r.Data);
vld = squeeze(out.log_valid.Data);

k0 = find(vld > 0.5, 1);
if isempty(k0), error('유효한 센서 샘플이 없다. VRX 와 Domain ID 를 확인할 것.'); end
idx = k0:numel(t);

dN = diff(N(idx));  dE = diff(E(idx));  dt = diff(t(idx));
S.t_valid  = t(k0);
S.dist     = sum(hypot(dN, dE));
S.speed    = S.dist / (t(idx(end)) - t(k0));
psiu       = unwrap(psi(idx));                 % ±180도 경계에서 튀는 것을 푼다
S.dpsi_deg = rad2deg(psiu(end) - psiu(1));
S.r_mean   = mean(r(idx));

figure('Name',['W03 결과 ' ttl], 'NumberTitle','off', 'Color','w', ...
       'Position',[100 100 1180 660]);

%% ---- 왼쪽 : NED 항적 ----------------------------------------------------
ax = subplot(3,2,[1 3 5]); hold(ax,'on'); grid(ax,'on');
xlabel(ax,'East [m]'); ylabel(ax,'North [m]');

C_TRAIL = [0.00 0.45 0.74];
C_MID   = [0.85 0.47 0.02];
C_END   = [0.13 0.55 0.13];

hTrail = plot(ax, E(idx), N(idx), '-', 'Color',C_TRAIL, 'LineWidth',1.6);
plot(ax, 0, 0, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',12, 'LineWidth',1.8);

% 중간 자세 — 이동 8 m 또는 회전 30도 마다 한 척
kLast = idx(1);  hMid = gobjects(0);
for k = idx(2:end-1)
    moved  = hypot(N(k)-N(kLast), E(k)-E(kLast));
    turned = abs(mod(psi(k)-psi(kLast)+pi, 2*pi) - pi);
    if moved >= 8 || turned >= deg2rad(30)
        [hX, hY] = W03_hull(E(k), N(k), pi/2 - psi(k));
        hMid = patch(ax, hX, hY, 'w', 'EdgeColor',C_MID, 'LineWidth',1.2);
        if moved >= 8
            text(ax, E(k)+1.5, N(k)+1.5, sprintf('%.0fs', t(k)), ...
                 'Color',C_MID, 'FontSize',9);
        end
        kLast = k;
    end
end

[sX, sY, shx, shy] = W03_hull(E(k0), N(k0), pi/2 - psi(k0));
hStart = patch(ax, sX, sY, [0.75 0.75 0.75], 'EdgeColor',[0.3 0.3 0.3], 'LineWidth',1.3);
plot(ax, shx, shy, '-', 'Color',[0.3 0.3 0.3], 'LineWidth',1.3);

[eX, eY, ehx, ehy] = W03_hull(E(end), N(end), pi/2 - psi(end));
hEnd = patch(ax, eX, eY, C_END, 'FaceAlpha',0.85, 'EdgeColor',[0.05 0.3 0.05], 'LineWidth',1.4);
plot(ax, ehx, ehy, '-', 'Color',[0.05 0.3 0.05], 'LineWidth',2);
text(ax, E(end)+2, N(end)-2, sprintf('끝 (N %.1f, E %.1f)\n\\psi = %.1f°', ...
     N(end), E(end), rad2deg(psi(end))), 'FontSize',10, 'Color',[0.05 0.3 0.05]);

axis(ax,'equal');
legH = [hTrail hStart hEnd];  legS = {'항적','출발 자세','마지막 자세'};
if ~isempty(hMid), legH(end+1) = hMid; legS{end+1} = '중간 자세'; end
legend(ax, legH, legS, 'Location','southoutside', 'NumColumns',4, 'FontSize',9);
title(ax, {sprintf('%s — NED 항적 (위쪽이 북쪽)', ttl), ...
           sprintf('이동 %.1f m,  평균 %.2f m/s,  \\Delta\\psi %+.1f°', ...
                   S.dist, S.speed, S.dpsi_deg)}, 'FontWeight','normal');

%% ---- 오른쪽 : 시간 응답 --------------------------------------------------
subplot(3,2,2); plot(t(idx), N(idx), t(idx), E(idx), 'LineWidth',1.4); grid on;
ylabel('[m]'); legend({'N','E'}, 'Location','best'); title('북쪽 · 동쪽 위치');

subplot(3,2,4);
plot(t(idx), rad2deg(unwrap(psi(idx))), 'LineWidth',1.4); grid on;
ylabel('\psi_{NED} [deg]'); title('선수각 (북 기준 시계 +)');

subplot(3,2,6); plot(t(idx), r(idx), 'LineWidth',1.4); grid on;
yline(0, ':'); xlabel('t [s]'); ylabel('r [rad/s]');
title('요각속도 (좌선회면 음수)');

fprintf(['[%s] 첫 유효 %.2f s | 이동 %.2f m | 평균 %.3f m/s | ' ...
         'd(psi) %+.2f deg | r 평균 %+.4f rad/s\n'], ...
        ttl, S.t_valid, S.dist, S.speed, S.dpsi_deg, S.r_mean);
end
