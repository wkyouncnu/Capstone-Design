function S = W06_offline_plot(out, V)
% W06_OFFLINE_PLOT  5단계 오프라인 모델의 결과를 그림 네 장으로 그린다.
%
%   >> out = sim('W06_5_offline');
%   >> W06_offline_plot(out)
%
%   반환값 S
%     S.u_ss      직진 구간(0~20 s)의 정상상태 속도 [m/s]
%     S.r_stbd    우선회 구간(20~40 s)의 정상상태 요각속도 [deg/s]
%     S.r_port    좌선회 구간(40~60 s)의 정상상태 요각속도 [deg/s]
%     S.R_stbd    우선회 반경 [m]
%     S.R_port    좌선회 반경 [m]
%
%   두 번째 인수로 W06_vrx_record 의 결과를 넘기면 VRX 항적을 겹쳐 그린다.
%     >> V = W06_vrx_record;
%     >> out = sim('W06_5_offline');
%     >> W06_offline_plot(out, V)

if nargin < 1, out = evalin('base','out'); end
if nargin < 2, V = []; end

t   = out.log_pn.Time;
pn  = out.log_pn.Data;   pe  = out.log_pe.Data;
psi = out.log_psi.Data;  u   = out.log_u.Data;   r = out.log_r.Data;

% 각 구간의 마지막 5초를 정상상태로 본다
seg = @(a,b) t >= b-5 & t <= b;
S.u_ss   = mean(u(seg(0,20)));
S.r_stbd = mean(r(seg(20,40)));
S.r_port = mean(r(seg(40,60)));

% 선회반경 R = U / r   (r 은 rad/s 로 환산)
S.R_stbd = mean(u(seg(20,40))) / abs(deg2rad(S.r_stbd));
S.R_port = mean(u(seg(40,60))) / abs(deg2rad(S.r_port));

figure('Name','W06 오프라인 WAM-V','Color','w','Position',[80 60 1080 720]);

hasV = ~isempty(V);

subplot(2,2,1);
plot(pe, pn, 'b-', 'LineWidth',1.6); hold on; grid on; axis equal;
if hasV, plot(V.pe, V.pn, 'r-', 'LineWidth',1.4); end
plot(pe(1), pn(1), 'ko','MarkerFaceColor','g','MarkerSize',8);
i20 = find(t>=20,1); i40 = find(t>=40,1); i60 = find(t>=60,1);
plot(pe(i20), pn(i20), 'k^','MarkerFaceColor','w','MarkerSize',7);
plot(pe(i40), pn(i40), 'ks','MarkerFaceColor','w','MarkerSize',7);
plot(pe(i60), pn(i60), 'kd','MarkerFaceColor','w','MarkerSize',7);
xlabel('East [m]'); ylabel('North [m]');
if hasV
    legend({'오프라인','VRX','출발','20 s','40 s','60 s'}, 'Location','best');
else
    legend({'오프라인','출발','20 s (우선회)','40 s (좌선회)','60 s (정지)'}, 'Location','best');
end
title('항적');

subplot(2,2,2);
plot(t, u, 'b-', 'LineWidth',1.4); grid on; hold on;
if hasV, plot(V.t, V.u, 'r-', 'LineWidth',1.2); end
for v = [20 40 60], xline(v,'k--'); end
xlabel('시간 [s]'); ylabel('u [m/s]');
title(sprintf('전진 속도 (직진 정상상태 %.3f m/s)', S.u_ss));

subplot(2,2,3);
plot(t, psi, 'b-', 'LineWidth',1.4); grid on; hold on;
if hasV, plot(V.t, V.psi, 'r-', 'LineWidth',1.2); end
for v = [20 40 60], xline(v,'k--'); end
xlabel('시간 [s]'); ylabel('\psi [deg]');
title('선수각');

subplot(2,2,4);
plot(t, r, 'b-', 'LineWidth',1.4); grid on; hold on;
if hasV, plot(V.t, V.r, 'r-', 'LineWidth',1.2); end
for v = [20 40 60], xline(v,'k--'); end
yline(0,'k:');
xlabel('시간 [s]'); ylabel('r [deg/s]');
title(sprintf('요각속도 (우 %+.2f / 좌 %+.2f deg/s)', S.r_stbd, S.r_port));

if hasV
    sgtitle('W06 5단계 — 오프라인 WAM-V(파랑) vs VRX(빨강)');
else
    sgtitle('W06 5단계 — 오프라인 WAM-V (직진 / 우선회 / 좌선회)');
end

fprintf('\n===== 오프라인 WAM-V =====\n');
fprintf('  직진 정상상태 속도      %6.3f m/s      (0~20 s)\n', S.u_ss);
fprintf('  우선회 요각속도         %+6.2f deg/s    (20~40 s)\n', S.r_stbd);
fprintf('  좌선회 요각속도         %+6.2f deg/s    (40~60 s)\n', S.r_port);
fprintf('  우선회 반경             %6.2f m\n', S.R_stbd);
fprintf('  좌선회 반경             %6.2f m\n', S.R_port);
if hasV
    fprintf('\n  --- VRX 대조 ---\n');
    fprintf('  %-22s %10s %10s %10s\n','항목','오프라인','VRX','차이');
    fprintf('  %-22s %10.3f %10.3f %10.3f\n','직진 u [m/s]',      S.u_ss,   V.u_ss,   V.u_ss-S.u_ss);
    fprintf('  %-22s %10.2f %10.2f %10.2f\n','우선회 r [deg/s]',  S.r_stbd, V.r_stbd, V.r_stbd-S.r_stbd);
    fprintf('  %-22s %10.2f %10.2f %10.2f\n','좌선회 r [deg/s]',  S.r_port, V.r_port, V.r_port-S.r_port);
    fprintf('  %-22s %10.2f %10.2f %10.2f\n','우선회 반경 [m]',   S.R_stbd, V.R_stbd, V.R_stbd-S.R_stbd);
    S.vrx = V;
else
    fprintf('\n  같은 시나리오를 VRX 로 돌린 것이 W06_2_turn 이다.\n');
    fprintf('  >> V = W06_vrx_record;  로 기록하면 겹쳐 그릴 수 있다.\n');
end
end
