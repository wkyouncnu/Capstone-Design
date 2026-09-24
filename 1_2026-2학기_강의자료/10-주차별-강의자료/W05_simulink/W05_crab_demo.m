% W05_CRAB_DEMO  조류 속에서 뱃머리(psi)와 진행 방향(chi)이 벌어지는 것을 시간축으로 본다.
%
%   >> W05_setup
%   >> W05_crab_demo
%
%   무엇을 보이는가
%     두 번째 구간(정동, 80 m)을 LOS 로 달린다. 조류만 바꾼다 — 없음 / 북쪽으로 0.4 m/s.
%     구간을 가로지르는 조류가 배를 북쪽(좌현)으로 밀면
%       - 배는 조류를 거슬러 뱃머리를 남쪽으로 튼다 (psi > 90°)
%       - 실제 진행 방향 chi 는 경로 방향(90°)에 가깝게 간다
%       - 그 차이가 크랩각 beta = chi - psi 다
%     그리고 선수각 지령만 주면 경로 옆에 **정상 이탈**이 남는다.
%
%   왜 두 번째 구간인가
%     첫 구간은 경로에서 20 m 벗어난 채 출발해 수렴하느라 정상상태가 짧다.
%     두 번째 구간은 모서리를 돈 뒤 경로 위에서 시작하므로 조류의 효과만 남는다.
%
%   이론값과 맞춰 본다 (대학원 강의 W04 §4-7 과 같은 식)
%     정상상태에서 chi = pi_p 가 되려면 psi = pi_p - beta.
%     LOS 가 내는 psi_d = pi_p - atan(y_e/Delta) 와 같아지려면
%         atan(y_e/Delta) = beta   ->   y_e = Delta * tan(beta)
%     경로 옆으로 Delta*tan(beta) 만큼 떨어진 채 나란히 간다.
%
%   주의 — 모델이 읽는 조류 방향은 beta_c 다. current_direction 만 바꾸면
%   적용되지 않는다. W05_setup 은 둘을 함께 계산하므로, 스크립트에서 바꿀 때는
%   아래처럼 beta_c 도 다시 계산한다.

setappdata(0, 'W05_skip_run', true);
W05_setup;
animate = 0;                                   %#ok<NASGU>
load_system('W05_0_offline');

CUR = [0.0 0.4];                               % 조류 [m/s]
current_direction = 0;                         % 북쪽으로 흐른다 — 2구간(정동)을 가로지른다
beta_c = deg2rad(current_direction);           %#ok<NASGU>  모델이 읽는 값
res = struct([]);

for i = 1:numel(CUR)
    current_speed = CUR(i);                    %#ok<NASGU>
    out = sim('W05_0_offline');
    t   = out.log_x_n.Time;
    psi = rad2deg(out.log_psi.Data);  chi = rad2deg(out.log_chi.Data);
    bet = rad2deg(out.log_beta.Data); ye  = out.log_y_e.Data;
    xe  = out.log_x_e.Data;
    x_n  = out.log_x_n.Data;            y_n  = out.log_y_n.Data;

    sw = find(diff(xe) < -5) + 1;              % 구간이 바뀌는 순간들
    a = sw(1);  b = sw(2) - 1;                 % 두 번째 구간
    w = a + round(0.5*(b - a)) : b;            % 구간 뒤쪽 절반 = 정상상태

    res(i).cur = CUR(i);
    res(i).t = t(a:b);  res(i).psi = psi(a:b);  res(i).chi = chi(a:b);
    res(i).bet = bet(a:b);  res(i).ye = ye(a:b);
    res(i).x_n = x_n(a:b);  res(i).y_n = y_n(a:b);
    res(i).psi_ss = mean(psi(w));  res(i).chi_ss = mean(chi(w));
    res(i).bet_ss = mean(bet(w));  res(i).ye_ss  = mean(ye(w));
    res(i).ye_th  = Delta * tand(res(i).bet_ss);
    res(i).bet_th = atan2d(-CUR(i), u_ref);    % 옆 성분이 전부 조류일 때의 크랩각
end

%% 표 ----------------------------------------------------------------
fprintf('\n===== 두 번째 구간(정동) 뒤쪽 절반의 평균 =====\n');
fprintf('%10s %9s %9s %9s %11s %10s %15s\n', ...
        '조류[m/s]', 'psi[°]', 'chi[°]', 'beta[°]', 'beta 예상[°]', 'y_e[m]', 'Delta*tan(b)[m]');
for i = 1:numel(res)
    r = res(i);
    fprintf('%10.1f %9.2f %9.2f %9.2f %11.2f %10.3f %15.3f\n', ...
            r.cur, r.psi_ss, r.chi_ss, r.bet_ss, r.bet_th, r.ye_ss, r.ye_th);
end

%% 그림 --------------------------------------------------------------
h = figure('Name','W05 크랩각','Position',[80 80 1150 540],'Color','w');
C = [0.2 0.2 0.2; 0.85 0.33 0.10];

subplot(2,2,[1 3]); hold on; grid on; box on;
plot([wp_east(2) wp_east(3)], [wp_north(2) wp_north(3)], 'k--', 'LineWidth', 1.2, ...
     'DisplayName', '계획 경로 (2구간)');
for i = 1:numel(res)
    plot(res(i).y_n, res(i).x_n, 'LineWidth', 1.8, 'Color', C(i,:), ...
         'DisplayName', sprintf('조류 %.1f m/s', res(i).cur));
end
quiver(45, 53, 0, 4, 0, 'Color',[0 0.45 0.74], 'LineWidth',1.5, 'MaxHeadSize',2, ...
       'DisplayName','조류 방향 (북)');
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]'); ylim([52 66]);
title('두 번째 구간 — 조류가 있으면 경로 옆에 붙어 간다');
legend('Location','southeast');

r = res(2);
subplot(2,2,2); hold on; grid on; box on;
plot(r.t, r.psi, 'k',  'LineWidth', 1.6, 'DisplayName', '\psi 뱃머리');
plot(r.t, r.chi, 'Color',[0 0.45 0.74], 'LineWidth', 1.6, 'DisplayName', '\chi 진행 방향');
yline(90, 'k:', 'HandleVisibility','off');
ylabel('각 [°]'); title(sprintf('조류 %.1f m/s — 뱃머리와 진행 방향이 어긋난다', r.cur));
legend('Location','northeast');

subplot(2,2,4); hold on; grid on; box on;
plot(r.t, r.bet, 'Color',[0.85 0.33 0.10], 'LineWidth', 1.6, 'DisplayName', '\beta 크랩각');
plot(res(1).t, res(1).bet, 'Color',[0.55 0.55 0.55], 'LineWidth', 1.0, 'DisplayName', '\beta (조류 없음)');
yline(r.bet_th, ':', 'Color',[0.85 0.33 0.10], 'DisplayName', sprintf('예상 %.1f°', r.bet_th));
xlabel('시간 [s]'); ylabel('\beta [°]'); legend('Location','southeast');

d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, 'W05_crab_demo.png'), 'Resolution', 110);
fprintf('\n그림: img/W05_crab_demo.png\n');
