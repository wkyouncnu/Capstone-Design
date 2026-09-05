function S = W10_plot(out, ttl)
% W10_PLOT  DP 결과를 그림 6장으로 그리고 성능 지표를 표로 낸다.
%
%   >> W10_setup            % 실행하면 자동으로 이 함수가 불린다
%   >> W10_plot(out, '설명')
%
%   반환값 S
%     S.rms_pos    구간별 위치 오차 RMS [m]
%     S.rms_psi    구간별 선수각 오차 RMS [deg]
%     S.max_pos    최대 위치 오차 [m]
%     S.mean_T     평균 추력 크기 [N]
%     S.sat_pct    포화·불감대에 걸린 시간 비율 [%]
%     S.settle     각 구간의 정착 시간 [s] (오차 0.5 m 이내 진입)

if nargin < 2, ttl = ''; end

tbl  = evalin('base','dp_step');
dmax = evalin('base','del_max');
Fmax = evalin('base','F_max');
Ts   = evalin('base','Ts_ctrl');

t   = out.log_eta.Time;
N   = numel(t);
eta = pick(out.log_eta,     N);          % [N x 3]
etd = pick(out.log_eta_d,   N);
nu  = pick(out.log_nu,      N);
ee  = eta - etd;
ee(:,3) = atan2(sin(ee(:,3)), cos(ee(:,3)));   % 실제 오차 (필터 전)
tc  = pick(out.log_tau_cmd, N);
te  = pick(out.log_tau_env, N);
Ta  = pick(out.log_Tact,    N);          % [N x 2]
Da  = pick(out.log_Dact,    N);
sat = pick(out.log_sat,     N);

epos = hypot(ee(:,1), ee(:,2));
epsi = rad2deg(ee(:,3));

% 각 목표 구간의 마지막 20 초를 정상상태로 본다
seg = tbl(:,1);
S.rms_pos = zeros(size(seg));  S.rms_psi = zeros(size(seg));
S.settle  = nan(size(seg));
for i = 1:numel(seg)
    if i < numel(seg), t2 = seg(i+1); else, t2 = t(end); end
    m1 = t >= t2-20 & t <= t2;
    if any(m1)
        S.rms_pos(i) = sqrt(mean(epos(m1).^2));
        S.rms_psi(i) = sqrt(mean(epsi(m1).^2));
    end
    m2 = t >= seg(i) & t <= t2;
    k  = find(m2 & epos <= 0.5, 1);
    if ~isempty(k), S.settle(i) = t(k) - seg(i); end
end
S.max_pos = max(epos);
S.mean_T  = mean(mean(abs(Ta)));
S.sat_pct = 100*mean(sat > 0.5);
% 추진기가 얼마나 바쁘게 움직이는가 — 파랑 필터의 효과를 보는 지표
S.dT_rms  = sqrt(mean(mean((diff(Ta)/Ts).^2)));
S.dD_rms  = rad2deg(sqrt(mean(mean((diff(Da)/Ts).^2))));

figure('Name',['W10 ' ttl],'Color','w','Position',[60 40 1180 780]);

subplot(2,3,1);
plot(etd(:,2), etd(:,1), 'k--', 'LineWidth',1.2); hold on;
plot(eta(:,2), eta(:,1), 'b-',  'LineWidth',1.5);
plot(eta(1,2), eta(1,1), 'ko','MarkerFaceColor','g','MarkerSize',8);
axis equal; grid on; xlabel('East [m]'); ylabel('North [m]');
legend({'목표','실제','출발'},'Location','best');
title('평면 궤적');

subplot(2,3,2);
plot(t, epos, 'b-', 'LineWidth',1.3); grid on; hold on;
yline(0.5,'r:','0.5 m');
xlabel('시간 [s]'); ylabel('위치 오차 [m]');
title(sprintf('위치 오차 (최대 %.2f m)', S.max_pos));

subplot(2,3,3);
plot(t, epsi, 'b-', 'LineWidth',1.3); grid on;
xlabel('시간 [s]'); ylabel('선수각 오차 [deg]');
title('선수각 오차');

subplot(2,3,4);
plot(t, Ta(:,1), 'b-', t, Ta(:,2), 'r-', 'LineWidth',1.2); grid on; hold on;
yline( Fmax,'k:'); yline(-Fmax,'k:');
xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'좌','우'},'Location','best');
title(sprintf('추력 (한계 ±%g N)', Fmax));

subplot(2,3,5);
plot(t, rad2deg(Da(:,1)), 'b-', t, rad2deg(Da(:,2)), 'r-', 'LineWidth',1.2);
grid on; hold on;
yline( rad2deg(dmax),'k:'); yline(-rad2deg(dmax),'k:');
xlabel('시간 [s]'); ylabel('방위각 [deg]');
legend({'좌','우'},'Location','best');
title(sprintf('추진기 방위각 (한계 ±%.0f°)', rad2deg(dmax)));

subplot(2,3,6);
plot(t, te(:,1), 'b-', t, te(:,2), 'r-', t, te(:,3)/10, 'g-', 'LineWidth',1.1);
grid on;
xlabel('시간 [s]'); ylabel('외란');
legend({'X [N]','Y [N]','N/10 [N·m]'},'Location','best');
title('환경 외란');

sgtitle(['W10 — ' ttl]);

fprintf('\n===== %s =====\n', ttl);
fprintf('  구간별 정상상태 오차 (각 구간 마지막 20 s)\n');
for i = 1:numel(seg)
    fprintf('   t=%4.0f s  목표 (%5.1f, %5.1f, %5.0f°)   위치 RMS %6.3f m   선수각 RMS %5.2f°   정착 %s\n', ...
        seg(i), tbl(i,2), tbl(i,3), tbl(i,4), S.rms_pos(i), S.rms_psi(i), ...
        ternary(isnan(S.settle(i)), '  —  ', sprintf('%5.1f s', S.settle(i))));
end
fprintf('  최대 위치 오차          %6.3f m\n', S.max_pos);
fprintf('  평균 추력 크기          %6.1f N\n', S.mean_T);
fprintf('  포화·불감대 시간 비율   %6.1f %%\n', S.sat_pct);
fprintf('  추력 변화율 RMS         %6.1f N/s\n', S.dT_rms);
fprintf('  방위각 변화율 RMS       %6.2f deg/s\n', S.dD_rms);
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

function y = pick(ts, N)
% To Workspace 신호를 [N x k] 로 맞춘다.
% 상수 신호는 표본이 하나뿐일 수 있어 그대로 늘려 준다.
y = squeeze(ts.Data);
if size(y,2) == N && size(y,1) ~= N, y = y'; end
if isvector(y), y = y(:); end
if size(y,1) == 1 && N > 1, y = repmat(y, N, 1); end
if size(y,1) ~= N
    if size(y,1) > N, y = y(1:N,:);
    else, y = [y; repmat(y(end,:), N-size(y,1), 1)]; end
end
end
