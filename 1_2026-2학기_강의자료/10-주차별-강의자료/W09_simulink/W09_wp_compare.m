% W09_WP_COMPARE  같은 웨이포인트를 고정 추진기와 틸팅 추진기로 각각 돌아 견준다
%
%   >> W09_wp_compare
%
%   돌리는 모델 둘 — 물리를 여기서 다시 짜지 않는다
%     W05_simulink/W05_0_offline  고정 추진기 2기 + LOS 유도 (과소구동)
%     W09_simulink/W09_0_offline  틸팅 추진기 2기 + 추력 배분 + DP (완전구동)
%
%   맞춰 놓는 것 — 둘의 차이가 '추진기 배치' 하나만 남게 한다
%     웨이포인트  5주차의 사각형 네 꼭지 (-20,20) (60,20) (60,100) (-20,100) 복귀
%     출발        (0, 0) m, 선수각 0°
%     목표 속력   1.5 m/s   (W05 u_ref = W09 dp_vmax)
%     추진기      2기, 기당 500 N, 같은 모터 시상수
%     플랜트      같은 계수 (m 211 kg, Izz 653, Xu/Xuu/Yv/Yvv/Nr/Nrr 동일)
%     외란        없음 (W09 의 바람·파랑을 끈다. W05 에는 조류가 없다)
%
%   재는 것 — 두 모델에 **같은 식**을 쓴다
%     통과 시각   웨이포인트 수락반경 R = 5 m 안에 처음 든 시각 [s]
%     경로 이탈   사각형 폴리라인까지의 최단거리 [m] (평균·최대)
%     주행거리    적분 거리 [m]
%     max|v|      선체 횡속도 [m/s]  — 과소구동은 0 에 가깝고, 완전구동은 커진다
%     선수각      사용 범위 [deg]    — 과소구동은 경로를 향해 돌고, DP 는 안 돈다
%     추력        기당 최대 [N], 시간평균 [N]
%
%   그림: img/W09_wp_compare.png

clear; clc;
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(here);              % 폴더를 옮겨 다녀도 which 로 자기 자리를 되찾는다

%  웨이포인트·수락반경은 설정 스크립트의 clear 뒤에 적는다 (아래 두 군데)

%% ====================================================================
%  1. 고정 추진기 + LOS — 5주차 모델을 그대로 돌린다
% =====================================================================
cd(fullfile(root, 'W05_simulink'));
setappdata(0, 'W05_skip_run', true);
W05_setup;

%  W05_setup 의 clear 가 이 스크립트의 변수까지 지운다. 쓰는 것만 다시 적는다
here  = fileparts(which('W09_wp_compare'));
root  = fileparts(here);
cache = fullfile(here, 'W09_wp_compare_cache.mat');

fprintf('\n[1/2] 고정 추진기 + LOS 실행 중\n');
o5 = sim('W05_0_offline');

t  = o5.log_x_n.Time;  n5 = numel(t);
A.name = '고정 2기 + LOS';
A.t    = t;
A.x    = cpick(o5.log_x_n, n5);
A.y    = cpick(o5.log_y_n, n5);
A.psi  = cpick(o5.log_psi, n5);
U      = cpick(o5.log_U,    n5);
bta    = cpick(o5.log_beta, n5);
A.u    = cpick(o5.log_u, n5);
A.v    = U .* sin(bta);                 % U^2 = u^2 + v^2, beta = atan2(v,u)
A.r    = cpick(o5.log_r, n5);
A.F    = [cpick(o5.log_FL, n5), cpick(o5.log_FR, n5)];
A.del  = zeros(n5, 2);                  % 고정 추진기 — 방위각 없음
save(cache, 'A');

%% ====================================================================
%  2. 틸팅 추진기 + 배분 + DP — 9주차 모델에 같은 꼭지를 넣는다
%     DPRef 의 계단표가 곧 웨이포인트다. 모델은 손대지 않는다.
% =====================================================================
cd(fullfile(root, 'W09_simulink'));
setappdata(0, 'W09_skip_run', true);
W09_setup;

wpN = [-20   60   60  -20  -20];        % W09_setup 의 clear 뒤 다시 적는다
wpE = [ 20   20  100  100   20];
R_wp = 5;
here = fileparts(which('W09_wp_compare'));
cache = fullfile(here, 'W09_wp_compare_cache.mat');

%  구간 시간은 넉넉히 준다 — 80 m 를 1.5 m/s 로 가면 53 s 이므로 70 s 면 남는다.
%  통과 시각은 '수락반경에 든 때' 로 재므로 이 표가 성능을 가리지 않는다.
dp_step = [   0  wpN(1) wpE(1)  0 ;
             30  wpN(2) wpE(2)  0 ;
            100  wpN(3) wpE(3)  0 ;
            170  wpN(4) wpE(4)  0 ;
            240  wpN(5) wpE(5)  0 ];
dp_mode  = 1;
dp_vmax  = [1.5; 1.5; deg2rad(8)];      % W05 의 u_ref 와 같은 값
wind_on  = 0;   wave_on = 0;            % 외란을 끄고 둘을 같은 조건에 둔다
animate  = 0;
T_end    = 320;
x0       = [0; 0; 0; 0; 0; 0];

fprintf('\n[2/2] 틸팅 추진기 + DP 실행 중\n');
o9 = sim('W09_0_offline');

t  = o9.log_eta.Time;  n9 = numel(t);
eta = cpick(o9.log_eta, n9);  nu = cpick(o9.log_nu, n9);
B.name = '틸팅 2기 + 배분 + DP';
B.t   = t;
B.x   = eta(:,1);   B.y = eta(:,2);   B.psi = eta(:,3);
B.u   = nu(:,1);    B.v = nu(:,2);    B.r   = nu(:,3);
B.F   = cpick(o9.log_Tact, n9);
B.del = cpick(o9.log_Dact, n9);

load(cache, 'A');
delete(cache);

%% ====================================================================
%  3. 같은 식으로 지표를 뽑는다
% =====================================================================
%  구간 시작 시각 — DP 는 계단표가 목표를 바꾼 때, LOS 는 이전 웨이포인트를 지난 때.
%  이것을 빼 주지 않으면 계단표에서 기다린 시간이 제어 성능으로 보인다
SA = metrics(A, wpN, wpE, R_wp, zeros(1, numel(wpN)));
SB = metrics(B, wpN, wpE, R_wp, dp_step(:,1)');

fprintf('\n===== 웨이포인트 성능 — 고정 추진기 vs 틸팅 추진기 =====\n');
fprintf('  %-22s %14s %14s\n', '항목', '고정 2기+LOS', '틸팅 2기+DP');
pr('완주 시각 [s]',        SA.t_done,  SB.t_done,  '%14.1f');
for k = 2:numel(wpN)
    pr(sprintf('  wp%d 통과 [s]', k), SA.t_wp(k), SB.t_wp(k), '%14.1f');
end
for k = 2:numel(wpN)
    pr(sprintf('  구간%d 소요 [s]', k), SA.t_leg(k), SB.t_leg(k), '%14.1f');
end
pr('80 m 구간 평균 [s]',   SA.t_leg_mean, SB.t_leg_mean, '%14.1f');
pr('경로 이탈 평균 [m]',   SA.xte_mean, SB.xte_mean, '%14.3f');
pr('경로 이탈 최대 [m]',   SA.xte_max,  SB.xte_max,  '%14.3f');
pr('주행거리 [m]',         SA.dist,     SB.dist,     '%14.1f');
pr('max|u| [m/s]',         SA.umax,     SB.umax,     '%14.3f');
pr('max|v| [m/s]',         SA.vmax,     SB.vmax,     '%14.3f');
pr('max|r| [deg/s]',       SA.rmax,     SB.rmax,     '%14.2f');
pr('선수각 사용 범위 [deg]', SA.psi_rng, SB.psi_rng, '%14.1f');
pr('기당 최대 추력 [N]',   SA.Fmax,     SB.Fmax,     '%14.1f');
pr('기당 평균 추력 [N]',   SA.Fmean,    SB.Fmean,    '%14.1f');
fprintf('  %-22s %14s %14.1f\n', '방위각 최대 [deg]', '—', SB.dmax);
fprintf('  %-22s %14s %14.1f\n', '방위각 ±45° 포화 [%]', '—', SB.dsat);

%% ====================================================================
%  4. 그림 — 궤적·횡속도·선수각·방위각 네 칸
% =====================================================================
f = figure('Name','W09 웨이포인트 성능 비교','Position',[80 80 1180 780], 'Color','w');

subplot(2,2,1); hold on; grid on; axis equal;
plot(wpE, wpN, 'k--', 'LineWidth',1.0);
plot(wpE, wpN, 'ks', 'MarkerSize',8, 'MarkerFaceColor','w');
plot(A.y, A.x, 'b-', 'LineWidth',1.4);
plot(B.y, B.x, 'r-', 'LineWidth',1.4);
xlabel('동쪽 y [m]'); ylabel('북쪽 x [m]');
legend({'경로','웨이포인트', A.name, B.name}, 'Location','best');
title('궤적');

subplot(2,2,2); hold on; grid on;
plot(A.t, A.v, 'b-', B.t, B.v, 'r-', 'LineWidth',1.2);
xlabel('시간 [s]'); ylabel('횡속도 v [m/s]');
legend({A.name, B.name}, 'Location','best');
title('횡속도 — 완전구동만 옆으로 간다');

subplot(2,2,3); hold on; grid on;
plot(A.t, rad2deg(unwrap(A.psi)), 'b-', B.t, rad2deg(unwrap(B.psi)), 'r-', 'LineWidth',1.2);
xlabel('시간 [s]'); ylabel('선수각 \psi [deg]');
legend({A.name, B.name}, 'Location','best');
title('선수각 — DP 는 돌지 않는다');

subplot(2,2,4); hold on; grid on;
plot(B.t, rad2deg(B.del(:,1)), 'r-', B.t, rad2deg(B.del(:,2)), 'm-', 'LineWidth',1.2);
yline( 45, 'k--'); yline(-45, 'k--');
xlabel('시간 [s]'); ylabel('방위각 \delta [deg]');
legend({'좌현','우현'}, 'Location','best');
title('방위각 — ±45° 한계 안에서 쓴다');

sgtitle('W09 — 같은 웨이포인트, 고정 추진기와 틸팅 추진기');

if ~exist(fullfile(here,'img'), 'dir'), mkdir(fullfile(here,'img')); end
png = fullfile(here, 'img', 'W09_wp_compare.png');
exportgraphics(f, png, 'Resolution', 150);
fprintf('\n그림 저장: %s\n', png);

%% ====================================================================
%  지역 함수
% =====================================================================
function pr(nm, a, b, fmt)
fprintf(['  %-22s ' fmt ' ' fmt '\n'], nm, a, b);
end

function S = metrics(D, wpN, wpE, R, t_start)
%  두 모델에 같은 식을 쓴다
nw = numel(wpN);
S.t_wp  = nan(1, nw);
S.t_leg = nan(1, nw);
t0 = 0;
for k = 2:nw                              % wp1 은 LOS 가 지나지 않을 수 있어 재지 않는다
    d = hypot(D.x - wpN(k), D.y - wpE(k));
    i = find(d < R & D.t >= t0, 1, 'first');
    if ~isempty(i)
        S.t_wp(k)  = D.t(i);
        S.t_leg(k) = D.t(i) - max(t0, t_start(k));
        t0 = D.t(i);
    end
end
S.t_done = S.t_wp(nw);
S.t_leg_mean = mean(S.t_leg(3:nw));       % 꼭지에서 꼭지로 가는 80 m 구간 셋

%  경로 이탈 — 폴리라인까지의 최단거리. 통과를 마친 뒤 구간은 세지 않는다
iend = find(D.t <= S.t_done, 1, 'last');
if isempty(iend), iend = numel(D.t); end
xx = D.x(1:iend); yy = D.y(1:iend);
dmin = inf(size(xx));
for k = 1:nw-1
    dmin = min(dmin, seg_dist(xx, yy, [wpN(k) wpE(k)], [wpN(k+1) wpE(k+1)]));
end
%  첫 구간은 출발점 (0,0) 에서 wp1 로 들어오는 접근이므로 거기도 경로로 본다
dmin = min(dmin, seg_dist(xx, yy, [0 0], [wpN(1) wpE(1)]));
S.xte_mean = mean(dmin);
S.xte_max  = max(dmin);

S.dist  = sum(hypot(diff(xx), diff(yy)));
S.umax  = max(abs(D.u(1:iend)));
S.vmax  = max(abs(D.v(1:iend)));
S.rmax  = rad2deg(max(abs(D.r(1:iend))));
S.psi_rng = rad2deg(max(unwrap(D.psi(1:iend))) - min(unwrap(D.psi(1:iend))));
S.Fmax  = max(max(abs(D.F(1:iend,:))));
S.Fmean = mean(mean(abs(D.F(1:iend,:))));
S.dmax  = rad2deg(max(max(abs(D.del(1:iend,:)))));
S.dsat  = 100 * mean(any(abs(D.del(1:iend,:)) > deg2rad(44.9), 2));
end

function d = seg_dist(x, y, p1, p2)
%  점 (x,y) 에서 선분 p1-p2 까지의 최단거리
vx = p2(1)-p1(1);  vy = p2(2)-p1(2);
L2 = vx*vx + vy*vy;
s  = ((x-p1(1))*vx + (y-p1(2))*vy) / L2;
s(s < 0) = 0;  s(s > 1) = 1;
d = hypot(x - (p1(1) + s*vx), y - (p1(2) + s*vy));
end

function y = cpick(ts, N)
%  To Workspace 신호를 [N x k] 로 맞춘다 (W09_plot 의 pick 과 같은 식)
y = squeeze(ts.Data);
if size(y,2) == N && size(y,1) ~= N, y = y'; end
if isvector(y), y = y(:); end
if size(y,1) == 1 && N > 1, y = repmat(y, N, 1); end
if size(y,1) ~= N
    if size(y,1) > N, y = y(1:N,:);
    else, y = [y; repmat(y(end,:), N-size(y,1), 1)]; end
end
end
