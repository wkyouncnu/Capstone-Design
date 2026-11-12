function E = A3_envelope(b, L, Fmax, dmax_deg)
% A3_ENVELOPE  각도 한계 ±delta_max 를 걸었을 때 **낼 수 있는 (X, Y, N)** 을 잰다
%
%   >> A3_envelope                 %  A3_setup 의 값으로 (없으면 기본값으로)
%   >> A3_envelope(1.027135, 2.373776, 500, 45)
%
%   무엇을 답하는 그림인가
%     "전후·횡·요를 **동시에** 요구하면 어디서 ±45° 를 넘는가"
%
%   재는 것이 둘이다 — 둘을 가르는 것이 이 부록의 요점이다
%     (1) pseudo-inverse 그대로   pinv(B)*tau 를 그대로 (추력, 각도) 로 바꾼 것.
%                             **가장 간단한** 배분이다
%     (2) null space 한 줄 보정   B 의 null space [0 1 0 -1]' (두 추진기에 크기 같고
%                             방향 반대인 횡력) 을 lambda 만큼 더해, 각도를
%                             한계 안으로 넣는다. 코드 네 줄이다
%
%     추진기가 힘을 못 내는 것이 아니라 **배분이 못 쓰는** 영역이 있다.
%     (1) 과 (2) 의 차이가 그 영역이다.
%
%   반환값 E — 전부 계산한 값이다
%     E.wedge        pinv 가 각도 한계를 넘는 X/Y 구간 (N = 0)
%     E.Y_max        순수 횡력 한계 [N]
%     E.N_max        순수 요 모멘트 한계 [N m]
%     E.d_sway       순수 횡이동 때의 각도 [deg]
%     E.area         N=0 격자에서 낼 수 있는 칸의 비율 [%] — (1) 과 (2)
%     E.fig          그림 손잡이

%% ---- 입력 — 주면 그 값, 안 주면 A3_setup 값, 그것도 없으면 기본값 ----
if nargin < 1, b        = base_or(  'half_beam', 1.027135); end
if nargin < 2, L        = base_or(  'l_thr',     2.373776); end
if nargin < 3, Fmax     = base_or(  'F_max',     500);      end
if nargin < 4, dmax_deg = base_or(  'd_max_deg', 45);       end

dmax = deg2rad(dmax_deg);
td   = tan(dmax);
B    = [1 0 1 0; 0 1 0 1; b -L -b -L];

%% ---- 닫힌식으로 먼저 — 그림이 맞는지 대조할 기준 ----
E.k_T    = hypot(b, L)/(2*b);         % 순수 횡력 1 N 당 추진기 추력 [N/N]
E.Y_max  = Fmax / E.k_T;
E.N_max  = 2*b*Fmax;
E.d_sway = rad2deg(atan2(b, L));
E.X_max  = 2*Fmax;

%   pinv 가 각도 한계를 넘는 X/Y 구간 (N = 0)
%     FxR = X/2 - (L/2b)Y 이고 FyR = Y/2 이므로
%     |Y/2| > td|X/2 - (L/2b)Y|  <=>  X/Y 가 아래 두 값 사이
E.wedge = 2*(L/(2*b) + [-1 1]*td/2);

%% ---- 격자로 — 요구를 그대로 낼 수 있는 칸을 센다 (N = 0 슬라이스) ----
xs = linspace(-1.25*E.X_max, 1.25*E.X_max, 501);
ys = linspace(-1.60*E.Y_max, 1.60*E.Y_max, 501);
[XX, YY] = meshgrid(xs, ys);
ok0 = false(size(XX));   ok1 = false(size(XX));
for i = 1:numel(XX)
    ok0(i) = az_ok(XX(i), YY(i), 0, b, L, td, Fmax, dmax, false);
    ok1(i) = az_ok(XX(i), YY(i), 0, b, L, td, Fmax, dmax, true);
end
E.area = [100*mean(ok0(:)), 100*mean(ok1(:))];

%   (Y, N) 슬라이스 — X = 0 (제자리에서 옆으로 밀며 돌리기)
ns = linspace(-1.4*E.N_max, 1.4*E.N_max, 501);
[YY2, NN2] = meshgrid(ys, ns);
ok0b = false(size(YY2));  ok1b = false(size(YY2));
for i = 1:numel(YY2)
    ok0b(i) = az_ok(0, YY2(i), NN2(i), b, L, td, Fmax, dmax, false);
    ok1b(i) = az_ok(0, YY2(i), NN2(i), b, L, td, Fmax, dmax, true);
end

%   요구한 X 마다 낼 수 있는 |Y| 의 최대 (N = 0) — 쐐기가 어디서 벌어지는가
xl = linspace(0, 1.2*E.X_max, 241);
Ycap0 = zeros(size(xl));  Ycap1 = zeros(size(xl));
yt = linspace(0, 1.6*E.Y_max, 1601);
for i = 1:numel(xl)
    g0 = false(size(yt));  g1 = false(size(yt));
    for j = 1:numel(yt)
        g0(j) = az_ok(xl(i), yt(j), 0, b, L, td, Fmax, dmax, false);
        g1(j) = az_ok(xl(i), yt(j), 0, b, L, td, Fmax, dmax, true);
    end
    k0 = find(~g0, 1);   % 끊기기 **전까지** 가 쓸 수 있는 범위다 (쐐기 때문)
    k1 = find(~g1, 1);
    if isempty(k0), Ycap0(i) = yt(end); else, Ycap0(i) = yt(max(k0-1,1)); end
    if isempty(k1), Ycap1(i) = yt(end); else, Ycap1(i) = yt(max(k1-1,1)); end
end

%% ---- 그림 ----
E.fig = A3_fig('A3_env', sprintf('A3 도달 가능 집합 (±%g deg)', dmax_deg), ...
               [100 80 1280 420]);

subplot(1,3,1);
cm = [1 1 1; 0.78 0.87 0.97; 0.16 0.33 0.65];
imagesc(xs, ys, ok0 + 2*ok1 - ok0.*ok1*0);      % 1 = 보정만, 3 = 둘 다
set(gca, 'YDir','normal');  colormap(gca, [1 1 1; 0.16 0.33 0.65; 0.78 0.87 0.97; 0.16 0.33 0.65]);
hold on;
%  쐐기 두 줄 — pinv 가 각도 한계를 넘는 방향
for s = [-1 1]
    for w = E.wedge
        plot(s*w*ys, s*ys, '-', 'Color',[0.86 0.15 0.15], 'LineWidth',1.1);
    end
end
plot([0 0], ys([1 end]), 'k:');  plot(xs([1 end]), [0 0], 'k:');
plot(0,  E.Y_max, 'ko', 'MarkerFaceColor','y', 'MarkerSize',6);
plot(0, -E.Y_max, 'ko', 'MarkerFaceColor','y', 'MarkerSize',6);
axis tight;  xlabel('요구 X 전후 [N]');  ylabel('요구 Y 횡 [N]');
title(sprintf('N = 0 단면   (낼 수 있는 칸 %.1f%% -> %.1f%%)', E.area));

subplot(1,3,2);
imagesc(ys, ns, ok0b + 2*ok1b);
set(gca, 'YDir','normal');  colormap(gca, [1 1 1; 0.16 0.33 0.65; 0.78 0.87 0.97; 0.16 0.33 0.65]);
hold on;
plot(ys([1 end]), [0 0], 'k:');  plot([0 0], ns([1 end]), 'k:');
plot( E.Y_max, 0, 'ko', 'MarkerFaceColor','y', 'MarkerSize',6);
plot(0,  E.N_max, 'ko', 'MarkerFaceColor','y', 'MarkerSize',6);
axis tight;  xlabel('요구 Y 횡 [N]');  ylabel('요구 N 요 모멘트 [N m]');
title('X = 0 단면');

subplot(1,3,3);
plot(xl, Ycap0, '-',  'LineWidth',1.8, 'Color',[0.16 0.33 0.65]); hold on;
plot(xl, Ycap1, '--', 'LineWidth',1.8, 'Color',[0.85 0.33 0.10]);
yline(E.Y_max, ':', 'Color',[0.5 0.5 0.5]);
xline(2*Fmax,  ':', 'Color',[0.5 0.5 0.5]);
grid on;  xlabel('요구 X 전후 [N]');  ylabel('함께 낼 수 있는 |Y| [N]');
legend({'pseudo-inverse 그대로','null space 한 줄 보정','Y_{max}','X_{max}'}, ...
       'Location','northeast', 'FontSize',8);
title('전후와 횡을 동시에 요구할 때');

%% ---- 숫자 ----
fprintf('\n===== A3 도달 가능 집합  (각도 한계 ±%g deg) =====\n', dmax_deg);
fprintf('  기하                 b = %.6f m · L = %.6f m · F_max = %.0f N\n', b, L, Fmax);
fprintf('  순수 횡력 1 N 당 추력%8.6f N     (= hypot(b,L)/2b)\n', E.k_T);
fprintf('  순수 횡이동 각도     %8.4f deg   (= atan2(b,L))\n', E.d_sway);
fprintf('  낼 수 있는 한계      X %.0f N · Y %.1f N · N %.1f N m\n', E.X_max, E.Y_max, E.N_max);
fprintf('  pinv 가 45 deg 를 넘는 X/Y 구간   %.4f ~ %.4f\n', E.wedge);
fprintf('  N=0 단면에서 낼 수 있는 칸        pinv %.1f %%  ->  보정 후 %.1f %%\n', E.area);
fprintf('  null space                차원 %d · 벡터 [0 1 0 -1]'' (두 추진기 횡력 반대)\n', ...
        size(null(B),2));
end

% =====================================================================
function v = base_or(name, dflt)
%  베이스 워크스페이스에 A3_setup 값이 있으면 그것을 쓴다
if evalin('base', sprintf('exist(''%s'',''var'')', name)) == 1
    v = evalin('base', name);
else
    v = dflt;
end
end

% =====================================================================
function ok = az_ok(X, Y, N, b, L, td, Fmax, dmax, use_null)
%  요구 (X, Y, N) 을 **그대로** 낼 수 있는가 — 각도·추력 한계 둘 다 본다
C   = (L*Y + N)/(2*b);
FxL = X/2 + C;
FxR = X/2 - C;
lam = 0;
if use_null
    %  null space [0 1 0 -1]' 을 lambda 만큼 — 두 각도가 한계 안에 들어가게
    lo = max(-td*abs(FxL) - Y/2,  Y/2 - td*abs(FxR));
    hi = min( td*abs(FxL) - Y/2,  Y/2 + td*abs(FxR));
    if lo <= hi
        lam = min(max(0, lo), hi);      % 0 에 가장 가까운 값 (최소 노력)
    else
        lam = (lo + hi)/2;              % 어차피 안 되는 요구 — 가운데
    end
end
FyL = Y/2 + lam;
FyR = Y/2 - lam;
[TL, dL] = az_pol(FxL, FyL);
[TR, dR] = az_pol(FxR, FyR);
ok = abs(dL) <= dmax + 1e-9 && abs(dR) <= dmax + 1e-9 && ...
     abs(TL) <= Fmax  + 1e-9 && abs(TR) <= Fmax  + 1e-9;
end

% =====================================================================
function [T, d] = az_pol(Fx, Fy)
%  직각 성분 -> (추력, 각도). |d| > 90 deg 는 **뒤로 미는 추력**으로 접는다
T = hypot(Fx, Fy);
d = atan2(Fy, Fx);
if abs(d) > pi/2
    d = d - sign(d)*pi;
    T = -T;
end
end
