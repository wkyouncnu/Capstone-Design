% W06_POLE_PLACE  헤딩 게인을 "적당히" 가 아니라 극배치로 정한다.
%
%   >> W06_pole_place
%
%   무엇을 하는가
%     1) WAM-V 요 운동을 Nomoto 1차 모델로 적는다   I_z r' + N_r r = N
%     2) P-D 요각속도 되먹임 N = K_p e - K_d r 을 붙이면 닫힌 루프가 2차가 된다
%     3) 2차 표준형과 계수를 맞춰 omega_n, zeta 를 읽는다 — 또는 거꾸로 게인을 정한다
%     4) 과목에 나온 두 게인 세트와 설계한 한 세트를 비선형 모델로 돌려 비교한다
%
%   출처 — 대학원 강의 W03 Heading Control §3-1 ~ §3-3 을 WAM-V 수치로 옮긴 것이다.
%          Fossen (2021) §15.2 도 같은 유도다.
%
%   계수는 6·7주차 오프라인 모델과 같다 (W07_setup.m 80·84행).
%     I_z = 653 kg m^2,  N_r = 800 N m s,  N_rr = 800 N m s^2  (부가질량 0)

Iz   = 653;          % 요 관성 [kg m^2]
Nr   = 800;          % 선형 요 감쇠 [N m s/rad]
Nrr  = 800;          % 2차 요 감쇠 [N m s^2/rad^2]
Nmax = 500;          % 6주차 SatN 포화 [N m]
step_deg = 30;       % 선수각 계단 [deg] — Kp*e 가 포화에 닿지 않을 만큼

%% 세 게인 세트 ------------------------------------------------------
zeta_d = 0.9;  wn_d = 1.0;                       % 설계 목표
Kp_d   = wn_d^2 * Iz;
Kd_d   = 2*zeta_d*sqrt(Kp_d*Iz) - Nr;

G = { '6주차 (800, 400)',      800,   400;
      '7주차~ (400, 200)',     400,   200;
      sprintf('설계 zeta=%.1f wn=%.1f', zeta_d, wn_d), Kp_d, Kd_d };

%% 계산과 시뮬레이션 ---------------------------------------------------
psid = deg2rad(step_deg);
tspan = [0 20];
opts = odeset('RelTol',1e-8,'AbsTol',1e-10,'MaxStep',0.01);

res = struct([]);
for i = 1:size(G,1)
    Kp = G{i,2};  Kd = G{i,3};
    wn   = sqrt(Kp/Iz);
    zeta = (Nr + Kd) / (2*sqrt(Kp*Iz));
    p    = roots([1, (Nr+Kd)/Iz, Kp/Iz]);

    % 선형 예측 (N_rr = 0, 포화 없음)
    if zeta < 1
        os_lin = 100*exp(-zeta*pi/sqrt(1-zeta^2));
    else
        os_lin = 0;
    end

    % 비선형 모델 — 과목 모델과 같은 2차 감쇠와 포화를 넣는다
    f = @(t,x) [ x(2);
                 ( max(-Nmax, min(Nmax, Kp*(psid - x(1)) - Kd*x(2))) ...
                   - (Nr + Nrr*abs(x(2)))*x(2) ) / Iz ];
    [t, x] = ode45(f, tspan, [0;0], opts);
    psi = x(:,1);
    Ncmd = max(-Nmax, min(Nmax, Kp*(psid - psi) - Kd*x(:,2)));

    os  = max(0, (max(psi) - psid)/psid*100);
    out = find(abs(psi - psid) > 0.02*psid, 1, 'last');
    if isempty(out) || out == numel(t), ts = NaN; else, ts = t(out+1); end

    % 같은 게인의 선형 응답 (그림 비교용)
    fl = @(t,x) [ x(2); (Kp*(psid - x(1)) - Kd*x(2) - Nr*x(2)) / Iz ];
    [tl, xl] = ode45(fl, tspan, [0;0], opts);

    res(i).name = G{i,1};  res(i).Kp = Kp;  res(i).Kd = Kd;
    res(i).wn = wn;  res(i).zeta = zeta;  res(i).p = p;
    res(i).os_lin = os_lin;  res(i).os = os;  res(i).ts = ts;
    res(i).Npk = max(abs(Ncmd));
    res(i).t = t;  res(i).psi = rad2deg(psi);
    res(i).tl = tl;  res(i).psil = rad2deg(xl(:,1));
end

%% 표 ----------------------------------------------------------------
fprintf('\n===== 헤딩 P-D 의 극 — 선수각 %g deg 계단 =====\n', step_deg);
fprintf('%-24s %6s %6s %7s %6s %9s %9s %8s %8s\n', ...
        '게인', 'Kp', 'Kd', 'wn', 'zeta', 'OS선형%', 'OS실측%', 'Ts2%[s]', '|N|max');
for i = 1:numel(res)
    r = res(i);
    fprintf('%-24s %6.0f %6.0f %7.3f %6.2f %9.2f %9.2f %8.2f %8.0f\n', ...
            r.name, r.Kp, r.Kd, r.wn, r.zeta, r.os_lin, r.os, r.ts, r.Npk);
end
fprintf('\n극 (s 평면)\n');
for i = 1:numel(res)
    fprintf('  %-24s  %s\n', res(i).name, mat2str(res(i).p.', 3));
end
fprintf('\nNomoto 1차 모델  T = I_z/N_r = %.3f s,  K = 1/N_r = %.2e rad/(s N m)\n', Iz/Nr, 1/Nr);

%% 그림 --------------------------------------------------------------
C = lines(numel(res));
h = figure('Name','W06 극배치','Position',[80 80 1160 470],'Color','w');

subplot(1,2,1); hold on; grid on; box on;
for i = 1:numel(res)
    plot(real(res(i).p), imag(res(i).p), 'x', 'MarkerSize', 12, 'LineWidth', 2.2, ...
         'Color', C(i,:), 'DisplayName', res(i).name);
end
xline(0,'k-','HandleVisibility','off'); yline(0,'k-','HandleVisibility','off');
xlabel('실수부  [1/s]'); ylabel('허수부  [rad/s]');
title('닫힌 루프의 극 — 왼쪽일수록 빨리 가라앉는다');
legend('Location','northwest'); axis equal;
xl = xlim; xlim([min(xl(1),-2) 0.3]);

subplot(1,2,2); hold on; grid on; box on;
for i = 1:numel(res)
    plot(res(i).t, res(i).psi, 'LineWidth', 1.8, 'Color', C(i,:), ...
         'DisplayName', res(i).name);
    plot(res(i).tl, res(i).psil, '--', 'LineWidth', 1.0, 'Color', C(i,:), ...
         'HandleVisibility','off');
end
yline(step_deg, 'k:', 'HandleVisibility','off');
xlabel('시간 [s]'); ylabel('선수각 \psi [deg]');
title(sprintf('%g° 계단 응답 — 실선 비선형 모델, 점선 선형 예측', step_deg));
legend('Location','southeast'); xlim([0 12]);

d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, 'W06_pole_place.png'), 'Resolution', 110);
fprintf('\n그림: img/W06_pole_place.png\n');
