function S = W08_plot(out, ttl)
% W08_PLOT  로이터링 결과를 그림 6장으로 그리고 성능 지표를 낸다.
%
%   >> W08_setup            % 실행하면 자동으로 이 함수가 불린다
%   >> W08_plot(out, '설명')
%
%   반환값 S
%     S.mean_re    정착 후 평균 반경 오차 |r - r_d| [m]
%     S.max_re     최대 반경 오차 [m]
%     S.std_re     반경 오차 표준편차 [m]
%     S.t_enter    원에 도달한 시각 [s]
%     S.turns      총 회전수
%     S.t_done     정지 시각 [s] (미완료면 NaN)
%     S.mean_u     정상상태 속도 [m/s]

if nargin < 2, ttl = ''; end

cn = evalin('base','center_north');
ce = evalin('base','center_east');
rd = evalin('base','r_d');
req = evalin('base','required_turns');

t     = out.log_pn.Time;
pn    = out.log_pn.Data;      pe   = out.log_pe.Data;
psi   = out.log_psi.Data;     pref = out.log_psi_ref.Data;
rdist = out.log_r_dist.Data;  turns= out.log_turns.Data;
gate  = out.log_gate.Data;    u    = out.log_u.Data;
ucmd  = out.log_u_cmd.Data;   beta = out.log_beta.Data;
FL    = out.log_FL.Data;      FR   = out.log_FR.Data;

% 원에 도달한 시각 = 반경 오차가 처음으로 5% 안에 든 때
tol = 0.05*rd + 1;
k_in = find(abs(rdist - rd) <= tol, 1);
if isempty(k_in), S.t_enter = NaN; k_in = 1; else, S.t_enter = t(k_in); end

% 정지 시각
k_done = find(gate < 0.5, 1);
if isempty(k_done), S.t_done = NaN; k_end = numel(t); else, S.t_done = t(k_done); k_end = k_done; end

% 정착 구간 = 도달 후 10초 뒤부터 정지 전까지
k0 = min(k_in + round(10/(t(2)-t(1))), k_end);
seg = k0:k_end;
if numel(seg) < 10, seg = k_in:k_end; end

re = rdist(seg) - rd;
S.mean_re = mean(abs(re));
S.max_re  = max(abs(re));
S.std_re  = std(re);
S.turns   = turns(k_end);
S.mean_u  = mean(u(seg));

figure('Name',['W08  ' ttl], 'Position',[70 50 1220 800], 'Color','w');

% ---- 1. 궤적 --------------------------------------------------------
subplot(2,3,[1 4]);
th = linspace(0,2*pi,200);
plot(ce + rd*cos(th), cn + rd*sin(th), '--', 'Color',[0.75 0.1 0.1], 'LineWidth',1.6);
hold on; grid on; axis equal;
plot(ce, cn, 'p', 'MarkerEdgeColor',[0.75 0.1 0.1], ...
     'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',16);
plot(pe(1:k_end), pn(1:k_end), '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
plot(pe(1), pn(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',9);
plot(pe(k_end), pn(k_end), 'ro', 'MarkerFaceColor','r', 'MarkerSize',9);
xlabel('East [m]'); ylabel('North [m]');
title(sprintf('궤적   (평균 반경오차 %.2f m)', S.mean_re));
legend({'목표 원','중심','항적','출발','종료'}, 'Location','best','FontSize',8);

% ---- 2. 반경 오차 ----------------------------------------------------
subplot(2,3,2);
plot(t(1:k_end), rdist(1:k_end), 'LineWidth',1.4); hold on; grid on;
yline(rd, 'r--', 'LineWidth',1.3);
if ~isnan(S.t_enter), xline(S.t_enter, ':', '원 도달', 'LineWidth',1.2); end
xlabel('시간 [s]'); ylabel('중심까지 거리 [m]');
title('반경 수렴');

% ---- 3. 누적 회전수 --------------------------------------------------
subplot(2,3,3);
plot(t(1:k_end), turns(1:k_end), 'k', 'LineWidth',1.5); hold on; grid on;
if req > 0, yline(req, 'm--', sprintf('%g 바퀴', req), 'LineWidth',1.2); end
xlabel('시간 [s]'); ylabel('누적 회전수');
title(sprintf('회전수  (총 %.2f 바퀴)', S.turns));

% ---- 4. 헤딩 추종 ----------------------------------------------------
subplot(2,3,5);
w = @(a) mod(a*180/pi + 180, 360) - 180;
plot(t(1:k_end), w(pref(1:k_end)), '--', 'LineWidth',1.3); hold on;
plot(t(1:k_end), w(psi(1:k_end)),  '-',  'LineWidth',1.1);
grid on; xlabel('시간 [s]'); ylabel('각도 [deg]');
legend({'\psi_{ref}','\psi'}, 'Location','best','FontSize',8);
title('헤딩 추종');

% ---- 5. 속도 ---------------------------------------------------------
subplot(2,3,6);
plot(t(1:k_end), u(1:k_end), 'LineWidth',1.4); hold on;
plot(t(1:k_end), ucmd(1:k_end).*gate(1:k_end), '--', 'LineWidth',1.2);
grid on; xlabel('시간 [s]'); ylabel('u [m/s]');
legend({'u 실제','u 지령'}, 'Location','best','FontSize',8);
title(sprintf('속도  (정상상태 %.3f m/s)', S.mean_u));

% ---- 6. 추력과 크랩각 -------------------------------------------------
figure('Name',['W08 추진기  ' ttl], 'Position',[130 110 950 380], 'Color','w');
subplot(1,2,1);
plot(t(1:k_end), FL(1:k_end), 'LineWidth',1.2); hold on;
plot(t(1:k_end), FR(1:k_end), 'LineWidth',1.2);
Fm = evalin('base','F_max');
yline(Fm,'r:'); yline(-Fm,'r:');
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R','포화'}, 'Location','best','FontSize',8);
title('추력');

subplot(1,2,2);
plot(t(1:k_end), beta(1:k_end)*180/pi, 'LineWidth',1.3); grid on; hold on;
yline(0,'k:');
xlabel('시간 [s]'); ylabel('\beta [deg]');
title('크랩각');

% ---- 지표 -----------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
if isnan(S.t_enter)
    fprintf('  원 도달                    실패\n');
else
    fprintf('  원 도달 시각          %8.1f s\n', S.t_enter);
end
fprintf('  정착 후 평균 반경오차  %8.3f m   <- 과제에 쓸 값\n', S.mean_re);
fprintf('  정착 후 최대 반경오차  %8.3f m\n', S.max_re);
fprintf('  반경오차 표준편차      %8.3f m\n', S.std_re);
fprintf('  총 회전수              %8.2f 바퀴\n', S.turns);
if isnan(S.t_done)
    fprintf('  정지                       미정지\n');
else
    fprintf('  정지 시각             %8.1f s\n', S.t_done);
end
fprintf('  정상상태 속도          %8.3f m/s\n', S.mean_u);

end
