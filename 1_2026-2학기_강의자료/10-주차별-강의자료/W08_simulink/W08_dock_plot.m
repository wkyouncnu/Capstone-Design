function S = W08_dock_plot(out, ttl)
% W08_DOCK_PLOT  실습 E 의 결과를 그리고 상태별 · 접안 성능 지표를 낸다.
%
%   실습 A 의 W08_plot 과 **칸 배치가 같다** (2x3 + 추력 그림 하나).
%   달라진 곳만 적는다
%
%     궤적 칸     + ㄷ 자 도킹 스테이션 · 접근점 · 멈춘 자리의 선체 · ㄷ 자 확대 그림
%     상태 계단   눈금이 **넷**이 된다 (3 Dock 이 더해진다)
%     경로 오차   + 접안 구간의 선석까지 거리 (청록). 세 구간이 한 칸에서 읽힌다
%     추력 그림   + 선수추진기 F_B. 접안 구간에서 이것만 서는 것이 순수 옆걸음이다
%
%   왜 W08_plot 을 고쳐 쓰지 않는가
%     W08_plot 은 미션 상태를 셋으로 못박아 두었다 (ylim · yticks · yticklabels ·
%     i_fi 의 문턱 2.5). 넓히면 실습 A 의 그림이 같이 바뀌므로 사본을 둔다
%
%   반환값 S
%     S.t_loiter_in   로이터 진입 시각 [s]
%     S.t_loiter_out  로이터 종료 시각 [s]
%     S.t_dock_in     접안 시작 시각 [s]          (Dock 진입)
%     S.t_finish      임무 종료 시각 [s]          (접안 완료)
%     S.turns         로이터 회전수
%     S.mean_ye_wp    웨이포인트 구간 평균 |y_e| [m]
%     S.mean_re_lo    로이터 구간 평균 반경오차 [m]
%     S.berth_err     완료 문턱을 넘은 순간의 선석 위치 오차 [m]
%     S.berth_rest    멈춘 뒤(완료 +10 s)의 선석 위치 오차 [m]
%     S.coast         완료 뒤 미끄러진 거리 [m]
%     S.psi_hold      순수 옆걸음 구간의 최대 선수각 오차 [deg]
%     S.u_sway        순수 옆걸음 구간의 최대 |u| [m/s]   — 0 에 가까워야 한다
%     S.v_sway        순수 옆걸음 구간의 최대 |v| [m/s]
%     S.inside        **멈춘 뒤** 선체 네 점이 모두 베이 안에 있는가 (논리값)

if nargin < 2, ttl = ''; end

wpx = evalin('base','wp_north');
wpy = evalin('base','wp_east');
lxc = evalin('base','loiter_xc');
lyc = evalin('base','loiter_yc');
lrd = evalin('base','loiter_radius');

%  접안 묶음 — BerthRef 가 받는 dock_q 를 그대로 읽는다. 따로 적어 두면
%  설정을 고쳤을 때 그림과 제어가 조용히 어긋난다
q = evalin('base','dock_q');
dkx = q(1);  dky = q(2);  dpsi = q(3);
La  = q(4);  sd  = q(5);  Rd   = q(6);  Rs = q(7);
apx = dkx - sd*La*sin(dpsi);          % 접근점 — BerthRef 의 식과 같아야 한다
apy = dky + sd*La*cos(dpsi);

t     = out.log_x_n.Time;
x_n   = out.log_x_n.Data;    y_n   = out.log_y_n.Data;
psi   = out.log_psi.Data;    pref  = out.log_psi_ref.Data;   %#ok<NASGU>
ye    = out.log_y_e.Data;    idx   = out.log_idx.Data;
mode  = out.log_mode.Data;   turns = out.log_turns.Data;
u     = out.log_u.Data;      v     = out.log_v.Data;
rlo   = out.log_r_lo.Data;   phase = out.log_phase.Data;
FL    = out.log_FL.Data;     FR    = out.log_FR.Data;
FB    = out.log_FB.Data;

i_wp = find(mode < 1.5);
i_lo = find(mode > 1.5 & mode < 2.5);
i_dk = find(mode > 2.5 & mode < 3.5);
i_fi = find(mode > 3.5, 1);                 % Finish 진입 = 접안 완료

if isempty(i_lo), S.t_loiter_in = NaN; S.t_loiter_out = NaN;
else,             S.t_loiter_in = t(i_lo(1)); S.t_loiter_out = t(i_lo(end)); end
if isempty(i_dk), S.t_dock_in = NaN;
else,             S.t_dock_in = t(i_dk(1)); end
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

% ---- 접안 지표 --------------------------------------------------------
%  구간을 반드시 밝힌다 — 순수 옆걸음은 phase 2 **한 구간**이다. 접안 전체로
%  평균을 내면 접근점에서 돌던 값이 섞여 들어가 선수각 유지가 실제보다 나빠 보인다
d_berth = hypot(x_n - dkx, y_n - dky);
i_sw = find(phase > 1.5 & phase < 2.5);
i_sw = i_sw(i_sw <= k_end);
S.berth_err = d_berth(k_end);

%  멈춘 자리는 **두 번** 적는다 — 완료 문턱을 넘은 그 순간과, 옆걸음이 멎은 뒤.
%  완료 문턱(Rs)을 넘는 순간에도 배는 아직 옆으로 움직이고 있다. 위치제어가
%  오차를 지우며 세우는 데 시간이 걸리므로, 문턱 순간의 값만 적으면 실제로
%  멈춘 자리보다 좋게 보인다. 완료 +10 s 의 값도 함께 적는다
k_rest       = min(k_end + round(10/(t(2) - t(1))), numel(t));
S.t_rest     = t(k_rest);
S.berth_rest = d_berth(k_rest);
S.coast      = hypot(x_n(k_rest) - x_n(k_end), y_n(k_rest) - y_n(k_end));
if isempty(i_sw)
    S.psi_hold = NaN;  S.u_sway = NaN;  S.v_sway = NaN;
else
    S.psi_hold = max(abs(ssa(psi(i_sw) - dpsi))) * 180/pi;
    S.u_sway   = max(abs(u(i_sw)));
    S.v_sway   = max(abs(v(i_sw)));
end

%  멈춘 자리가 ㄷ 안인가 — 중심 한 점이 아니라 **선체 네 점**으로 본다.
%  중심만 보면 선체가 벽에 박힌 채로도 합격이 된다
[qX, qY, inX, inY, pmX, pmY] = W08_dock_patch(dkx, dky, dpsi, sd);
[hXe, hYe] = hull_ned(x_n(k_rest), y_n(k_rest), psi(k_rest));
S.inside = all(inpolygon(hXe, hYe, inX, inY));

S.fig = figure('Name',['W08 실습 E  ' ttl], 'Position',[60 40 1240 820], 'Color','w');

% ---- 1. 궤적 (모드별 색) ----------------------------------------------
subplot(2,3,[1 4]); hold on; grid on; axis equal;
hPlan = plot(wpy, wpx, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',1.2);
th = linspace(0,2*pi,200);
plot(lyc + lrd*cos(th), lxc + lrd*sin(th), '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.5);
plot(lyc, lxc, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
     'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',14);

% ㄷ 자 도킹 스테이션 — 벽 세 면. 항적이 벽을 뚫었는지 눈으로 바로 걸린다
patch('XData',qY, 'YData',qX, 'FaceColor',[0.82 0.76 0.66], ...
      'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
plot([apy pmY dky], [apx pmX dkx], '--', 'Color',[0.00 0.50 0.45], 'LineWidth',1.3);
plot(dky+Rs*cos(th), dkx+Rs*sin(th), ':', 'Color',[0.00 0.50 0.45]);
plot(dky, dkx, 's', 'MarkerEdgeColor',[0.00 0.50 0.45], ...
     'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.6);
plot(apy, apx, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
     'MarkerFaceColor','w', 'MarkerSize',9, 'LineWidth',1.6);
plot(apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);

% 항적 — 상태별 색
k1 = i_wp(i_wp <= k_end);
plot(y_n(k1), x_n(k1), '.', 'Color',[0 0.45 0.74], 'MarkerSize',4);
if ~isempty(i_lo), plot(y_n(i_lo), x_n(i_lo), '.', 'Color',[0.95 0.45 0.20], 'MarkerSize',4); end
if ~isempty(i_dk), plot(y_n(i_dk), x_n(i_dk), '.', 'Color',[0.05 0.58 0.53], 'MarkerSize',5); end

plot(wpy, wpx, 's', 'MarkerEdgeColor',[0.75 0.1 0.1], ...
     'MarkerFaceColor','w', 'MarkerSize',10, 'LineWidth',1.6);
for i = 1:numel(wpx), text(wpy(i)+4, wpx(i)+5, sprintf('%d',i), ...
    'Color',[0.75 0.1 0.1], 'FontWeight','bold'); end
plot(y_n(1), x_n(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',9);

% 완료 뒤 미끄러진 토막 — 회색. 문턱을 넘은 자리와 멈춘 자리가 다르다
plot(y_n(k_end:k_rest), x_n(k_end:k_rest), '.', 'Color',[0.55 0.55 0.55], 'MarkerSize',4);

% 멈춘 자리의 선체 — 베이 안에 들어갔는지 그림으로 보인다
patch('XData',hYe, 'YData',hXe, 'FaceColor',[0.05 0.58 0.53], 'FaceAlpha',0.85, ...
      'EdgeColor',[0.15 0.15 0.15], 'LineWidth',1.1);
plot(y_n(k_end), x_n(k_end), 'ko', 'MarkerFaceColor','k', 'MarkerSize',7);

uistack(hPlan, 'top');                       % 계획선이 벽에 덮이지 않게
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title('궤적  (파랑 = 웨이포인트, 주황 = 로이터, 청록 = 접안)');

% ---- 1b. ㄷ 자 확대 — 멈춘 자리가 베이 안인지 그림만으로 읽힌다 --------
%  전체 궤적 칸에서 ㄷ 은 10 m 짜리라 점 하나로 보인다. 같은 칸의 빈 자리에
%  확대 그림을 겹쳐 둔다 (새 칸을 만들지 않는다 — 실습 A 와 칸 배치가 같아야 한다)
pT  = get(gca, 'Position');
axZ = axes('Position', [pT(1)+0.010  pT(2)+0.012  pT(3)*0.46  pT(4)*0.30]);
hold(axZ,'on'); grid(axZ,'on'); axis(axZ,'equal'); box(axZ,'on');
patch('Parent',axZ, 'XData',qY, 'YData',qX, 'FaceColor',[0.82 0.76 0.66], ...
      'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
plot(axZ, dky+Rs*cos(th), dkx+Rs*sin(th), ':', 'Color',[0.00 0.50 0.45]);
if ~isempty(i_dk)
    plot(axZ, y_n(i_dk), x_n(i_dk), '.', 'Color',[0.05 0.58 0.53], 'MarkerSize',5);
end
plot(axZ, y_n(k_end:k_rest), x_n(k_end:k_rest), '.', ...
     'Color',[0.55 0.55 0.55], 'MarkerSize',4);
patch('Parent',axZ, 'XData',hYe, 'YData',hXe, 'FaceColor',[0.05 0.58 0.53], ...
      'FaceAlpha',0.85, 'EdgeColor',[0.15 0.15 0.15], 'LineWidth',1.1);
plot(axZ, dky, dkx, 's', 'MarkerEdgeColor',[0.00 0.50 0.45], ...
     'MarkerFaceColor','w', 'MarkerSize',8, 'LineWidth',1.4);
xlim(axZ, [min(qY)-2.5 max(qY)+4.5]);  ylim(axZ, [min(qX)-2.5 max(qX)+2.5]);
set(axZ, 'FontSize',8, 'Color','w');
title(axZ, sprintf('ㄷ 자 확대 — 멈춘 뒤 %.2f m', S.berth_rest), 'FontSize',8);

% ---- 2. 미션 상태 — 눈금이 넷이다 --------------------------------------
subplot(2,3,2);
stairs(t(1:k_end), mode(1:k_end), 'k', 'LineWidth',1.6); grid on;
ylim([0.5 4.5]); yticks([1 2 3 4]);
yticklabels({'1 WP','2 Loiter','3 Dock','4 Finish'});
xlabel('시간 [s]'); title('미션 상태');

% ---- 3. 웨이포인트 인덱스와 접안 단계 ----------------------------------
subplot(2,3,3); hold on; grid on;
stairs(t(1:k_end), idx(1:k_end), 'LineWidth',1.6);
stairs(t(1:k_end), phase(1:k_end), 'LineWidth',1.6, 'Color',[0.05 0.58 0.53]);
xlabel('시간 [s]'); ylabel('번호 / 단계');
legend({'leg 시작 인덱스','접안 단계 (0~3)'}, 'Location','northwest','FontSize',8);
title('웨이포인트 진행과 접안 단계');

% ---- 4. 오차 — 세 구간이 한 칸에 ---------------------------------------
subplot(2,3,5); hold on; grid on;
plot(t(k1), ye(k1), '.', 'Color',[0 0.45 0.74], 'MarkerSize',4);
if ~isempty(i_lo)
    plot(t(i_lo), rlo(i_lo)-lrd, '.', 'Color',[0.95 0.45 0.20], 'MarkerSize',4);
end
if ~isempty(i_dk)
    plot(t(i_dk), d_berth(i_dk), '.', 'Color',[0.05 0.58 0.53], 'MarkerSize',5);
end
yline(0,'k:');
yline(Rs, ':', 'Color',[0.05 0.58 0.53]);     % 접안 완료 문턱
xlabel('시간 [s]'); ylabel('오차 [m]');
legend({'y_e (WP)','r - r_d (로이터)','선석까지 거리 (접안)'}, ...
       'Location','best','FontSize',8);
%  한 줄로 쓰면 옆 칸 제목과 글자가 맞붙는다 — 두 줄로 끊는다
title({sprintf('경로 오차   WP %.2f m / 로이터 %.2f m', S.mean_ye_wp, S.mean_re_lo), ...
       sprintf('접안 %.2f m  (멈춘 뒤 %.2f m)', S.berth_err, S.berth_rest)});

% ---- 5. 속도 — 전후와 횡 ----------------------------------------------
%  실습 A 는 회전수와 u 를 겹쳐 놓았다. 실습 E 는 **횡 속도 v** 를 같이 본다 —
%  접안 구간에서 u 가 0 으로 내려앉고 v 만 서는 것이 순수 옆걸음의 증거다
subplot(2,3,6); hold on; grid on;
plot(t(1:k_end), u(1:k_end), 'LineWidth',1.4, 'Color',[0 0.45 0.74]);
plot(t(1:k_end), v(1:k_end), 'LineWidth',1.4, 'Color',[0.05 0.58 0.53]);
if ~isnan(S.t_dock_in), xline(S.t_dock_in, 'k--', '접안 시작'); end
xlabel('시간 [s]'); ylabel('속도 [m/s]');
legend({'u (전후)','v (횡)'}, 'Location','best','FontSize',8);
title(sprintf('속도   접안 구간 |u| %.3f / |v| %.3f m/s', S.u_sway, S.v_sway));

% ---- 추력 — 추진기 셋 --------------------------------------------------
figure('Name',['W08 실습 E 추진기  ' ttl], 'Position',[120 100 900 360], 'Color','w');
plot(t(1:k_end), FL(1:k_end), 'LineWidth',1.1); hold on;
plot(t(1:k_end), FR(1:k_end), 'LineWidth',1.1);
plot(t(1:k_end), FB(1:k_end), 'LineWidth',1.4, 'Color',[0.05 0.58 0.53]);
Fm = evalin('base','F_max');      yline(Fm,'r:');  yline(-Fm,'r:');
Fb = evalin('base','F_bow_max');  yline(Fb,':', 'Color',[0.05 0.58 0.53]);
yline(-Fb,':', 'Color',[0.05 0.58 0.53]);
if ~isnan(S.t_loiter_in),  xline(S.t_loiter_in, 'k--', '로이터 시작'); end
if ~isnan(S.t_loiter_out), xline(S.t_loiter_out,'k--', '로이터 종료'); end
if ~isnan(S.t_dock_in),    xline(S.t_dock_in,   'k--', '접안 시작'); end
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R','F_B (선수)'}, 'Location','best','FontSize',8);
title('추력 — 접안 구간에서 F_B 가 선다');

% ---- 지표 -------------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
fprintf('  로이터 진입          %8.1f s\n', S.t_loiter_in);
fprintf('  로이터 종료          %8.1f s   (%.2f 바퀴)\n', S.t_loiter_out, S.turns);
if isnan(S.t_dock_in)
    fprintf('  접안 시작                미진입\n');
else
    fprintf('  접안 시작            %8.1f s\n', S.t_dock_in);
end
if isnan(S.t_finish)
    fprintf('  접안 완료                미완료\n');
else
    fprintf('  접안 완료            %8.1f s   (접안에 %.1f s)\n', ...
            S.t_finish, S.t_finish - S.t_dock_in);
end
fprintf('  WP 구간 평균 |y_e|   %8.3f m\n', S.mean_ye_wp);
fprintf('  로이터 평균 반경오차 %8.3f m\n', S.mean_re_lo);
fprintf('  선석 위치 오차       %8.3f m   (완료 문턱 %.2f m 을 넘은 순간)\n', ...
        S.berth_err, Rs);
fprintf('  멈춘 뒤 위치 오차    %8.3f m   (완료 +10 s, 그 사이 %.2f m 미끄러짐)\n', ...
        S.berth_rest, S.coast);
fprintf('  옆걸음 선수각 오차   %8.3f deg  (최대, phase 2 전 구간)\n', S.psi_hold);
fprintf('  옆걸음 |u| / |v|     %8.3f / %.3f m/s  (최대, phase 2 전 구간)\n', ...
        S.u_sway, S.v_sway);
if S.inside
    fprintf('  선체 네 점           멈춘 뒤 모두 ㄷ 안\n');
else
    fprintf('  선체 네 점           ** ㄷ 밖으로 나감 **\n');
end

end

% ---- 선체 다각형 (실시간 화면과 같은 모양, 실척) -------------------------
function [X, Y] = hull_ned(x, y, psi)
L = 2.45;  B = 1.03;                           % 반길이 · 반폭 [m]
bx = L * [ -1   -1    0.5   1    0.5 ];
by = B * [  1   -1   -1     0    1   ];
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
end

% ---- ssa : 최단 부호각 ---------------------------------------------------
function a = ssa(a)
a = atan2(sin(a), cos(a));
end
