% W06_HEADING_SIGN  헤딩 D 항의 세 가지 선택을 같은 배에 걸어 본다.
%
%   왜 필요한가
%     "D 항은 요각속도 r 에 **마이너스**를 붙여 되먹인다" 는 말을 글로만 두지
%     않는다. 부호를 바꾸면 무슨 일이 생기는지 숫자로 남긴다.
%
%   비교하는 세 가지
%     (A) -Kd * r        요각속도 되먹임        <- W06_3/W06_4 가 쓰는 것
%     (B) +Kd * de/dt    오차 미분              <- 값은 같지만 지령이 튈 때 함께 튄다
%     (C) +Kd * r        부호를 뒤집은 것       <- 감쇠를 **깎아 먹는다**
%
%   D 항은 감쇠다
%     닫힌 루프의 요 감쇠는 (선체 항력 Nr) + (D 게인 Kd) 이다. 부호를 뒤집으면
%     Nr - Kd 가 되어 배가 스스로 가진 감쇠를 깎는다. Kd < Nr 이면 느려지고
%     오버슈트가 커진다. Kd > Nr 이면 선형 감쇠는 음수지만 2차 항력(Nrr |r| r)이
%     버텨 발산하지는 않는다 — 대신 응답은 쓸 수 없을 만큼 흔들린다.
%     이 스크립트는 그 문턱도 함께 찾는다.
%
%   배 모델 — 7주차 운동모델의 요 자유도만 떼어 낸 것 (계수도 같다)
%     Izz * dr/dt = N - (Nr + Nrr*|r|) * r,     dpsi/dt = r
%
%   실행:  >> W06_heading_sign

clear; clc;

Izz = 653;      % 요 관성 [kg m^2]        — W07_setup 과 같은 값
Nr  = 800;      % 선형 요 항력
Nrr = 800;      % 2차 요 항력
Kp  = 800;      % HeadingCtrl 의 P 게인
Kd  = 400;      % HeadingCtrl 의 D 게인
Nmax = 500;     % 요 모멘트 포화 [N m]

Ts   = 0.05;    % 제어 주기 [s]
Tend = 60;
t    = (0:Ts:Tend)';
psi_ref = 45*pi/180 * (t >= 1);        % 1 초에 45 도로 계단 변화

name = {'(A) -Kd*r  요각속도', '(B) +Kd*de/dt  오차 미분', '(C) +Kd*r  부호 반대'};
PSI  = zeros(numel(t), 3);
NCMD = zeros(numel(t), 3);
NRAW = zeros(numel(t), 3);

for c = 1:3
    [PSI(:,c), NCMD(:,c), NRAW(:,c)] = run_case(c, t, psi_ref, Kp, Kd, Nmax, Izz, Nr, Nrr, Ts);
end

fprintf('\n===== 헤딩 D 항 세 가지 (계단 45 deg, Kp=%g, Kd=%g) =====\n', Kp, Kd);
fprintf('  %-26s %9s %10s %14s\n', '', '오버슈트', '정착시간', '포화 전 |N| 최대');
for c = 1:3
    [ov, ts] = metrics(PSI(:,c), t, 45);
    fprintf('  %-26s %8.1f%% %9.1f s %14.0f\n', name{c}, ov, ts, max(abs(NRAW(:,c))));
end

fprintf('\n  (A) 와 (B) 는 추종이 같다 — 목표가 멈춰 있으면 de/dt = -r 이기 때문이다.\n');
fprintf('  차이는 계단이 들어오는 순간이다. (B) 의 지령은 포화 한계 %g 의 몇 배까지 치솟는다.\n', Nmax);

% ── 부호를 뒤집으면 어디서 무너지는가 ────────────────────────────────────
%  닫힌 루프 감쇠는 Nr - Kd 다. Kd 를 키우며 문턱을 찾는다.
fprintf('\n===== 부호를 뒤집은 채 Kd 를 키우면 (선체 항력 Nr = %g) =====\n', Nr);
fprintf('  %8s %10s %12s\n', 'Kd', '오버슈트', '남는 감쇠 Nr-Kd');
for kd = [200 400 600 800 1000 1400 2000]
    [y, ~, ~] = run_case(3, t, psi_ref, Kp, kd, Nmax, Izz, Nr, Nrr, Ts);
    [ov, ~]   = metrics(y, t, 45);
    if ~isfinite(ov) || ov > 1e3
        fprintf('  %8g %10s %12g\n', kd, '발산', Nr-kd);
    else
        fprintf('  %8g %9.1f%% %12g\n', kd, ov, Nr-kd);
    end
end
fprintf('\n  D 항이 하는 일은 **감쇠를 더하는 것**이다. 부호를 뒤집으면 반대로 깎는다.\n');
fprintf('  Kd 에 비례해 오버슈트가 커지는 것이 그 증거다. 남는 감쇠가 음수가 되어도\n');
fprintf('  2차 항력(Nrr)이 버텨 발산까지 가지는 않지만, 응답은 쓸 수 없게 된다.\n\n');

% 경우마다 색을 고정한다 — 위아래 두 패널에서 같은 경우가 같은 색이어야 읽힌다
col = [0.00 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
h = figure('Name','헤딩 D 항 비교','Color','w','Position',[80 80 900 620]);
subplot(2,1,1); hold on; grid on;
plot(t, psi_ref*180/pi, 'k--', 'LineWidth',1.2, 'DisplayName','목표');
sty = {'-','--','-'};  lw = [3.0 1.6 1.4];     % (A) 와 (B) 는 겹친다 — (A) 를 굵게, (B) 를 점선으로
for c = 1:3, plot(t, PSI(:,c)*180/pi, sty{c}, 'Color',col(c,:), 'LineWidth',lw(c), 'DisplayName',name{c}); end
ylabel('\psi [deg]'); ylim([-10 90]); xlim([0 15]);
legend('Location','southeast');
title('계단 45° — (A) 와 (B) 는 겹치고, (C) 는 감쇠가 깎여 크게 넘친다', 'FontWeight','normal');
subplot(2,1,2); hold on; grid on;
for c = 1:3
    plot(t, NRAW(:,c), ':', 'Color',col(c,:), 'LineWidth',1.1, 'HandleVisibility','off');
    plot(t, NCMD(:,c), sty{c}, 'Color',col(c,:), 'LineWidth',lw(c), 'DisplayName',name{c});
end
yline( Nmax, 'k--', 'HandleVisibility','off');  yline(-Nmax, 'k--', 'HandleVisibility','off');
xlim([0 15]); ylim([-1000 7500]);
xlabel('시간 [s]'); ylabel('N [N m]');
legend('Location','northeast');
title('실선 = 포화 뒤 지령, 점선 = 포화 전 (B 의 계단 순간 킥이 보인다)', 'FontWeight','normal');
exportgraphics(h, fullfile(fileparts(mfilename('fullpath')), 'img', 'W06_heading_dterm.png'), 'Resolution', 110);
fprintf('그림: img/W06_heading_dterm.png\n');

% =========================================================================
function [psi_hist, N_hist, Nraw_hist] = run_case(c, t, psi_ref, Kp, Kd, ...
                                                  Nmax, Izz, Nr, Nrr, Ts)
%RUN_CASE  D 항을 c 번 방식으로 만들어 요 자유도만 적분한다.
psi_hist  = zeros(numel(t),1);
N_hist    = zeros(numel(t),1);
Nraw_hist = zeros(numel(t),1);
psi = 0;  r = 0;  e_prev = 0;
for k = 1:numel(t)
    d = psi_ref(k) - psi;
    e = atan2(sin(d), cos(d));               % ssa
    switch c
        case 1, D = -Kd * r;
        case 2, D =  Kd * (e - e_prev)/Ts;
        case 3, D =  Kd * r;
    end
    Nraw = Kp*e + D;
    N    = max(min(Nraw, Nmax), -Nmax);
    psi_hist(k)  = psi;
    N_hist(k)    = N;
    Nraw_hist(k) = Nraw;

    dr  = (N - (Nr + Nrr*abs(r))*r) / Izz;   % 전진 오일러, 제어 주기와 같은 간격
    r   = r + Ts*dr;
    psi = psi + Ts*r;
    e_prev = e;
    if ~isfinite(psi) || abs(psi) > 1e4, psi_hist(k:end) = NaN; break, end
end
end

% =========================================================================
function [ov, ts] = metrics(psi_hist, t, ref_deg)
%METRICS  오버슈트 [%] 와 ±2 % 정착시간 [s] (계단은 t = 1 s 에 들어온다).
y = psi_hist*180/pi;
if any(~isfinite(y)), ov = inf; ts = NaN; return, end
ov  = (max(y) - ref_deg)/ref_deg*100;
out = find(abs(y - ref_deg) > 0.02*ref_deg, 1, 'last');
if isempty(out)
    ts = 0;
elseif out >= numel(t)
    ts = NaN;
else
    ts = t(out+1) - 1;
end
end
