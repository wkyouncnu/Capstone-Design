function S = W06_plot(out, ttl)
% W06_PLOT  시뮬레이션 결과를 그림으로 그리고 성능 지표를 표로 낸다.
%
%   사용법
%     >> W06_setup
%     >> out = sim('W06_0_offline');
%     >> W06_plot(out, '접안 / 조류 없음')
%
%   반환값 S 에 성능 지표가 들어 있다 — 측정한 값만 들어간다
%     S.t_done       임무 완료 시각 [s]   (gate 가 0 으로 떨어진 시각. 미완료면 NaN)
%     S.e_final      마지막 위치 오차 [m]
%     S.epsi_final   마지막 선수각 오차 [deg]
%     S.e_ss         마지막 10 초 평균 위치 오차 [m]
%     S.epsi_ss      마지막 10 초 평균 |선수각 오차| [deg]
%     S.max_v        최대 |v| [m/s]          <- 선수추진기가 만든 횡이동 속도
%     S.max_FB       최대 |F_B| [N]
%     S.max_Ferr     프로펠러 법칙 왕복 검산 max|F_err| [N]  <- 0 이어야 한다
%     S.t_phase      단계가 올라간 시각 [s]  (접안은 3개, 그 밖은 1개)

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
apx = dx - sd*La*sin(dpsi);          % 접근점 — TaskRef 와 같은 식
apy = dy + sd*La*cos(dpsi);

t     = out.log_x_n.Time;
x_n   = out.log_x_n.Data;      y_n   = out.log_y_n.Data;
psi   = out.log_psi.Data;      pref  = out.log_psi_ref.Data;
xref  = out.log_x_ref.Data;    yref  = out.log_y_ref.Data;
u     = out.log_u.Data;        v     = out.log_v.Data;
r     = out.log_r.Data;
gate  = out.log_gate.Data;     phase = out.log_phase.Data;
FL    = out.log_FL.Data;       FR    = out.log_FR.Data;
FB    = out.log_FB.Data;

%  회전수는 3원소 벡터 신호다. 저장 모양이 [3 x 1 x N] 일 수도 [N x 3] 일 수도
%  있다 — 시간 길이를 보고 [N x 3] 으로 맞춘다 (5주차와 같은 처리)
n = squeeze(out.log_n.Data);
if size(n,1) ~= numel(t), n = n.'; end

%  프로펠러 법칙 왕복 검산 — Thrusters 가 추력을 회전수로 바꾸고 다시 추력으로
%  되돌린 차이다. 두 식이 서로의 역함수이므로 0 이 나와야 한다 (1·2단은 0 받침)
Ferr = squeeze(out.log_F_err.Data);
if size(Ferr,1) ~= numel(t), Ferr = Ferr.'; end

eN = xref - x_n;  eE = yref - y_n;
d  = hypot(eN, eE);
epsi = atan2(sin(pref - psi), cos(pref - psi)) * 180/pi;

%  접안 단계의 목표 선수각은 유도부가 정한다 — 옆걸음 접안은 선석 방위
%  그대로이지만 전진 접안(7단)은 거기서 90 deg 틀어진 값이다. 유도부가
%  마지막에 내보낸 기준값이 곧 그 단계의 목표이므로 그것으로 센다
if mode == 3, gpsi = pref(end); end

%  목표 자세에 대한 오차 — 과업 전체의 성적은 최종 목표 기준으로 매긴다
dg    = hypot(gx - x_n, gy - y_n);
epsig = atan2(sin(gpsi - psi), cos(gpsi - psi)) * 180/pi;

%  gate 가 **정확히** 0 이 된 첫 순간이 완료 시각이다. 7단의 gate 는 0/1 이
%  아니라 감속 계수라 접안 전부터 1 보다 작아진다 — 문턱을 0.5 로 두면 아직
%  달리는 중을 완료로 읽는다 (addGuidanceFront 머리글)
k = find(gate <= 0, 1);
if isempty(k), S.t_done = NaN; else, S.t_done = t(k); end
ss = find(t >= t(end) - 10, 1);      % 마지막 10 초

S.e_final    = dg(end);
S.epsi_final = epsig(end);
S.e_ss       = mean(dg(ss:end));
S.epsi_ss    = mean(abs(epsig(ss:end)));
S.max_v      = max(abs(v));
S.max_FB     = max(abs(FB));
S.max_Ferr   = max(abs(Ferr(:)));
if mode == 3, lv = [1 2 3]; else, lv = 1; end
S.t_phase = nan(size(lv));
for i = 1:numel(lv)
    j = find(phase >= lv(i), 1);
    if ~isempty(j), S.t_phase(i) = t(j); end
end

%  이름표(Tag)를 단 창을 찾아 **다시 쓴다**. 돌릴 때마다 새 창을 열면
%  단을 몇 번만 바꿔 돌려도 바탕화면에 창이 열 장씩 쌓인다
S.fig = W06_fig('W06_result', ['W06  ' ttl], [80 60 1200 780]);

% ---- 1. 궤적 --------------------------------------------------------
%  접안 단은 왼쪽 칸을 **둘로 쪼갠다**. 위 칸에 전체 항적, 아래 칸에 접안
%  확대다. 한 칸에 몰면 — 세로로 긴 칸에 axis equal 을 걸면 세로 범위가
%  데이터보다 세 배 넓어져 0~45 m 짜리 항적이 -50~100 m 축에 놓인다 —
%  11 m 짜리 베이가 점만 해져 배가 베이에 들어갔는지를 볼 수 없다
if mode == 3
    subplot(2,3,1);
else
    subplot(2,3,[1 4]);
end
th = linspace(0, 2*pi, 72);
if mode == 3
    %  계획 경로는 **베이 입구 중심선을 지나** 선석으로 들어간다. 접근점에서
    %  곧장 선석으로 선을 그으면 날개 벽을 비스듬히 가로질러 "벽을 뚫고
    %  들어가는 계획" 처럼 보인다
    [qX, qY, ~, ~, mX, mY] = W06_dock_patch(dx, dy, dpsi, sd);
    plot([0 apy mY dy], [0 apx mX dx], 'k--', 'LineWidth',1.2); hold on;
    %  ㄷ 자 도킹 스테이션 — 텀프로젝트 과제의 베이와 같은 모양이다.
    %  세 면이 막혀 있어 궤적이 벽을 뚫는지가 그림에서 바로 보인다
    patch(qY, qX, [0.82 0.76 0.66], 'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
    plot(apy, apx, 'o', 'MarkerEdgeColor',[0 0.5 0], 'MarkerFaceColor','w', ...
         'MarkerSize',9, 'LineWidth',1.6);
    plot(apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
    leg = {'계획 경로','도킹 스테이션','접근점','R_{dock}'};
else
    plot([0 gy], [0 gx], 'k--', 'LineWidth',1.2); hold on;
    leg = {'계획 경로'};
end
%  그림의 크기는 **항적이 정한다**. 목표 선수각 막대와 선체 그림을 그 크기에
%  맞춰 줄인다 — 고정 길이로 그리면 12 m 밖에 가지 않는 2단에서 배 한 척이
%  화면을 덮어 항적이 보이지 않는다 (2026-10-15 지적)
span = max([max(x_n)-min(x_n); max(y_n)-min(y_n); 2*Rs; hypot(gx-x_n(1), gy-y_n(1))]);
%  목표 선수각 막대 길이 [m] — 접안 단만 **배 반길이**로 못박는다. 장면
%  크기를 따라가면 7 m 를 넘어 깊이 5.5 m 짜리 베이의 안쪽 벽을 뚫고 나간다
if mode == 3
    Lpsi = 3.4;
else
    Lpsi = max(2, 0.12*span);
end

%  선체를 몇 배로 그릴 것인가
%    접안(3단)은 ㄷ 자 베이와 **크기를 견주어야** 하므로 실척으로 그린다 —
%    배가 베이에 들어가는 크기인지가 그림에서 바로 보여야 한다.
%    나머지 단은 축 범위가 단마다 달라 실척으로 그리면 배가 화면을 덮는다
if mode == 3
    sc = 1;
else
    sc = min(2, max(0.4, 0.10*span/4.9));
end
L = 2.45*sc;  B = 1.03*sc;
bx = L*[-1 -1 0.5 1 0.5];  by = B*[1 -1 -1 0 1];

plot(gy, gx, 'ks', 'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.6);
plot([gy gy+Lpsi*sin(gpsi)], [gx gx+Lpsi*cos(gpsi)], '-', 'Color',[0.75 0.10 0.10], ...
     'LineWidth',1.8);
plot(gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.6 0.6 0.6]);

%  목표 자세의 배를 **처음부터** 빈 외곽선으로 그려 둔다. 도착한 배(아래의
%  채운 외곽선)가 이 틀에 겹쳐야 접안에 성공한 것이다. 틀이 없으면 "오차
%  0.5 m" 가 눈에 얼마만큼인지 읽히지 않는다
cg = cos(gpsi);  sg = sin(gpsi);
plot(gy + [bx bx(1)]*sg + [by by(1)]*cg, gx + [bx bx(1)]*cg - [by by(1)]*sg, ...
     '--', 'Color',[0.75 0.10 0.10], 'LineWidth',1.3);

plot(y_n, x_n, 'b-', 'LineWidth',1.6);
plot(y_n(1), x_n(1), 'go', 'MarkerFaceColor','g', 'MarkerSize',8);
plot(y_n(end), x_n(end), 'ro', 'MarkerFaceColor','r', 'MarkerSize',8);

%  마지막 자세를 선체 모양으로 한 번 더 그린다 — 선수각이 지켜졌는지가 보인다
c = cos(psi(end));  s = sin(psi(end));
patch(y_n(end) + bx*s + by*c, x_n(end) + bx*c - by*s, [0.95 0.45 0.20], ...
      'FaceAlpha',0.5, 'EdgeColor',[0.4 0.15 0.05]);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title(sprintf('궤적   (마지막 오차 %.2f m, %.1f°)', S.e_final, S.epsi_final));

%  범례는 축 **밖 아래**에 둔다. 'best' 는 항적 위에 얹히는 일이 잦다.
%  접안 단은 아래 칸(확대 그림)에 범례를 모아 붙인다 — 위 칸에 붙이면
%  아래 칸을 덮는다
legList = [leg {'목표 위치','목표 선수각','R_{stop}','목표 자세(배)','항적','출발','도착'}];
if mode == 3
    pad = 2.0;
    zx = [min([qX gx x_n(end)])-pad, max([qX gx x_n(end)])+pad];   % 북 범위
    zy = [min([qY gy y_n(end)])-pad, max([qY gy y_n(end)])+pad];   % 동 범위

    %  위 칸에 아래 칸이 어디를 잘라 왔는지 네모로 표시한다
    plot(zy([1 2 2 1 1]), zx([1 1 2 2 1]), '-', 'Color',[0.45 0.45 0.45], ...
         'LineWidth',0.8, 'HandleVisibility','off');
    title(sprintf('궤적 전체   (마지막 오차 %.2f m, %.1f°)', S.e_final, S.epsi_final));

    %  위 칸에는 범례를 **붙이지 않는다**. 열한 줄짜리 범례는 어디에 두어도
    %  — 왼쪽 위에 두면 베이를, 오른쪽 아래에 두면 항적을 — 가린다.
    %  범례는 아래 확대 칸에 한 벌만 두고, 위 칸은 지나가는 자리 셋에
    %  글자를 직접 찍는다. 자리는 선석 기준 (a, b) 로 잡아 선석 방위
    %  psi_t 와 접안 방향 s 가 바뀌어도 따라 돌게 한다
    ab2x = @(aa,bb) dx + aa*cos(dpsi) - bb*sd*sin(dpsi);
    ab2y = @(aa,bb) dy + aa*sin(dpsi) + bb*sd*cos(dpsi);
    text(ab2y(9.0,-3.4), ab2x(9.0,-3.4), '도킹 스테이션', 'FontSize',8, ...
         'Color',[0.35 0.25 0.15], 'HorizontalAlignment','center');
    text(apy+2.0, apx+2.5, '접근점', 'FontSize',8, 'Color',[0 0.45 0]);
    text(y_n(1)+2.0, x_n(1)-2.0, '출발', 'FontSize',8, 'Color',[0 0.45 0]);

    % ---- 아래 칸 : 접안 확대 ----
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
    plot(y_n(end), x_n(end), 'ro', 'MarkerFaceColor','r', 'MarkerSize',7);
    axis equal;  xlim(zy);  ylim(zx);  grid on;
    xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
    title('접안 확대 — 배와 베이가 실척');
    legend({'도킹 스테이션','계획 경로','R_{stop}','목표 자세(배)','항적', ...
            '도착 자세','목표 위치','도착'}, ...
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

% ---- 3. 선수각 ------------------------------------------------------
subplot(2,3,3);
plot(t, atan2(sin(pref),cos(pref))*180/pi, '--', 'LineWidth',1.4); hold on;
plot(t, atan2(sin(psi), cos(psi))*180/pi, '-', 'LineWidth',1.2);
plot(t, epsi, ':', 'Color',[0.2 0.6 0.2], 'LineWidth',1.2);
grid on; xlabel('시간 [s]'); ylabel('각도 [deg]');
%  선수각이 내내 0 인 단계(순수 횡이동)에서는 축이 10^-15 자리까지 늘어나
%  제목 옆에 지수 표기가 붙는다. 최소 폭을 1 deg 로 두어 막는다
yl = ylim;  if diff(yl) < 2, ylim(mean(yl) + [-1 1]); end
legend({'\psi_{ref} 지령','\psi 선수각','오차'}, 'Location','best','FontSize',8);
title(sprintf('선수각 추종   (마지막 10초 평균 |오차| %.2f°)', S.epsi_ss));

% ---- 4. 속도 --------------------------------------------------------
subplot(2,3,5);
yyaxis left
plot(t, u, '-', 'LineWidth',1.4); hold on;
plot(t, v, '--', 'LineWidth',1.4);
ylabel('속도 [m/s]');
yyaxis right
plot(t, r*180/pi, ':', 'LineWidth',1.2);
ylabel('r [deg/s]');
%  요 각속도도 마찬가지다 — 횡이동만 하는 단계에서는 r 이 0 이다
if max(abs(r))*180/pi < 0.5, ylim([-0.5 0.5]); end
grid on; xlabel('시간 [s]');
legend({'u 서지','v 횡이동','r 요'}, 'Location','best','FontSize',8);
title(sprintf('속도   (최대 |v| = %.3f m/s)', S.max_v));

% ---- 5. 추력 --------------------------------------------------------
subplot(2,3,6);
plot(t, FL, 'LineWidth',1.2); hold on;
plot(t, FR, 'LineWidth',1.2);
plot(t, FB, 'LineWidth',1.6, 'Color',[0.93 0.69 0.13]);
Fm = evalin('base','F_max');  Fbm = evalin('base','F_bow_max');
yline( Fm,'r:');  yline(-Fm,'r:');
yline( Fbm,':','Color',[0.85 0.65 0.13]);  yline(-Fbm,':','Color',[0.85 0.65 0.13]);
grid on; xlabel('시간 [s]'); ylabel('추력 [N]');
legend({'F_L','F_R','F_B','\pmF_{max}','','\pmF_{bow,max}'}, ...
       'Location','best','FontSize',8);
title(sprintf('추력   (최대 |F_B| = %.1f N)', S.max_FB));

% ---- 6. 회전수와 단계 ------------------------------------------------
W06_fig('W06_thruster', ['W06 추진기와 단계  ' ttl], [140 120 950 380]);
subplot(1,2,1);
plot(t, n(:,1), 'LineWidth',1.2); hold on;
plot(t, n(:,2), 'LineWidth',1.2);
plot(t, n(:,3), 'LineWidth',1.6, 'Color',[0.93 0.69 0.13]);
nm = evalin('base','n_max');
yline( nm,'r:');  yline(-nm,'r:');
grid on; xlabel('시간 [s]'); ylabel('회전수 [rad/s]');
legend({'n_L','n_R','n_B','\pmn_{max} 참고선'}, 'Location','best','FontSize',8);
title('프로펠러 회전수');

subplot(1,2,2);
stairs(t, phase, 'LineWidth',1.6); hold on;
stairs(t, gate, '--', 'LineWidth',1.4);
grid on; xlabel('시간 [s]'); ylabel('단계 / gate');
ylim([-0.3 max(3.3, max(phase)+0.3)]);
legend({'phase (래치)','gate'}, 'Location','best','FontSize',8);
title('과업 진행');

% ---- 성능 지표 --------------------------------------------------------
fprintf('\n===== %s =====\n', ttl);
if isnan(S.t_done)
    fprintf('  임무 완료                미완료 (gate 가 끝까지 1)\n');
else
    fprintf('  임무 완료 시각       %8.1f s\n', S.t_done);
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
fprintf('  마지막 10초 평균 오차%8.3f m  / %6.2f deg\n', S.e_ss, S.epsi_ss);
fprintf('  최대 |v| (횡이동)    %8.3f m/s\n', S.max_v);
fprintf('  최대 |F_B| (선수추진기)%6.1f N   (한계 %.0f N)\n', S.max_FB, Fbm);
fprintf('  왕복 검산 max|F_err| %8.2e N    (F -> n -> F, 0 이어야 한다)\n', S.max_Ferr);

end
