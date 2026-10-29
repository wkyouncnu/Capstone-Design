function f = A2_animate_map(x_n, y_n, psi, psi_ref, y_e, u, gate, FL, FR, wp_idx, t)
%A2_ANIMATE_MAP  4단 실시간 화면 — 위성지도 위의 항적과, 헤딩 명령 대 실제 헤딩
%
%   `A2_live.slx` 의 Animate 블록이 제어 주기마다 이 함수를 부른다.
%   인자 순서는 Animate 서브시스템의 From 태그 순서와 같다 (5주차와 같은 계약)
%
%       x_n  y_n  psi  psi_ref  y_e  u  gate  FL  FR  wp_idx  +  t
%
%   f = A2_ANIMATE_MAP()   인자 없이 부르면 그림 핸들만 돌려준다 (캡처용)
%
%   화면
%     왼쪽   위성지도 — 계획 경로, 웨이포인트, 지나온 항적, 선체와 헤딩선
%     오른쪽 위  헤딩 명령 psi_ref 와 실제 헤딩 psi [deg]
%     오른쪽 중  횡방향 오차 y_e [m]
%     오른쪽 아래 속도 u 와 추력 FL·FR
%
%   베이스 워크스페이스에서 읽는 값 — `A2_live_setup` 이 만든다
%     lla0  wp_north  wp_east  R_LOS  u_ref
%   선택
%     basemap_name   'satellite' 또는 'darkwater' (기본 'satellite')
%     animate_every  몇 초마다 다시 그릴 것인가 (기본 0.25)
%     boat_scale     선체 확대 배율 (기본 6)
%
%   왜 MATLAB Function 블록이 직접 그리지 않는가
%     그 블록은 코드 생성 대상이라 그림을 못 그린다. `coder.extrinsic` 으로
%     선언하면 컴파일하지 않고 이 함수를 그대로 부른다

persistent fig gx axP axE axU ...
           hTrail hHull hHead hDot hP hPref hE hU hUcmd hFL hFR ...
           trLat trLon tv Dp De Dm wpx wpy wplat wplon R nwp uRef lla0c ...
           bscale tLast tPrev

if nargin == 0
    if ~isempty(fig) && isvalid(fig)
        f = fig;
    else
        f = getappdata(0, 'A2_anim_fig');
    end
    return
end

NMAX = 40000;        % 버퍼 상한 — 길게 돌려도 메모리가 늘지 않게 한다

%  새 실행인지 판정 — 시간이 거꾸로 가면 새 실행이다
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;

if newRun
    % --- 설정값을 베이스에서 읽는다 ----------------------------------
    lla0c = evalin('base', 'lla0');
    wpx   = evalin('base', 'wp_north');
    wpy   = evalin('base', 'wp_east');
    R     = evalin('base', 'R_LOS');
    uRef  = evalin('base', 'u_ref');
    nwp   = numel(wpx);

    bm = 'satellite';
    try, bm = evalin('base', 'basemap_name'); catch, end
    bscale = 6;
    try, bscale = evalin('base', 'boat_scale'); catch, end

    % --- 웨이포인트를 위경도로 올린다 --------------------------------
    wpl   = ned2lla([wpx(:) wpy(:) zeros(nwp,1)], lla0c, 'flat');
    wplat = wpl(:,1).';
    wplon = wpl(:,2).';

    %  지도 범위 — 웨이포인트를 다 담고 여유 40 m
    span = max(40, max(abs([wpx(:); wpy(:)])) + 40);

    % --- 그림 틀 ------------------------------------------------------
    if ~isempty(fig) && isvalid(fig), delete(fig); end
    fig = figure('Name', 'A2 4단 — 위성지도 위 실시간 항적과 헤딩', ...
                 'NumberTitle', 'off', 'Color', 'w', ...
                 'Position', [40 40 1360 820]);
    setappdata(0, 'A2_anim_fig', fig);

    gx = A2_openmap(lla0c, span, bm, '위성지도 — 계획 경로와 항적', fig);
    %  왼쪽 여백을 넉넉히 둔다 — 좁히면 위도 눈금(36°22'25"N) 의 앞자리가 잘린다
    gx.Position = [0.075 0.07 0.425 0.855];

    %  계획 경로와 웨이포인트 — 위성 영상 위에서는 흰색이 가장 잘 보인다
    geoplot(gx, wplat, wplon, '-', 'Color', [1 1 1], 'LineWidth', 1.3);
    geoscatter(gx, wplat, wplon, 70, 'r', 'filled', ...
               'MarkerEdgeColor', 'w', 'LineWidth', 1.0);
    for k = 1:nwp
        text(gx, wplat(k), wplon(k), sprintf('  %d', k-1), ...
             'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12);
    end

    hTrail = geoplot(gx, NaN, NaN, '-', 'Color', [1.00 0.85 0.10], 'LineWidth', 2.0);
    hHull  = geoplot(gx, NaN, NaN, '-', 'Color', [0.10 0.90 1.00], 'LineWidth', 1.8);
    hHead  = geoplot(gx, NaN, NaN, '-', 'Color', [1.00 0.20 0.20], 'LineWidth', 1.6);
    hDot   = geoscatter(gx, NaN, NaN, 36, 'w', 'filled');

    % --- 오른쪽 세 칸 -------------------------------------------------
    %  subplot 을 쓰지 않는다. 왼쪽 지리축과 겹침 판정이 걸릴 수 있다
    axP = axes('Parent', fig, 'Position', [0.595 0.715 0.365 0.235]);
    axE = axes('Parent', fig, 'Position', [0.595 0.405 0.365 0.235]);
    axU = axes('Parent', fig, 'Position', [0.595 0.080 0.365 0.235]);

    %  헤딩 명령과 실제 헤딩
    hPref = plot(axP, NaN, NaN, '-',  'Color', [0.00 0.45 0.74], 'LineWidth', 1.6);
    hold(axP, 'on');
    hP    = plot(axP, NaN, NaN, '-',  'Color', [0.86 0.08 0.08], 'LineWidth', 1.2);
    grid(axP, 'on');
    ylabel(axP, '헤딩 [deg]');
    legend(axP, {'명령 \psi_{ref}', '실제 \psi'}, 'Location', 'best', 'FontSize', 8);
    title(axP, '헤딩 명령 대 실제 헤딩');

    %  횡방향 오차
    hE = plot(axE, NaN, NaN, '-', 'Color', [0.00 0.50 0.45], 'LineWidth', 1.4);
    hold(axE, 'on');
    yline(axE, 0, 'k-');
    grid(axE, 'on');
    ylabel(axE, 'y_e [m]');
    title(axE, sprintf('횡방향 오차   (수락반경 R = %g m)', R));

    %  속도와 추력
    yyaxis(axU, 'left');
    hUcmd = plot(axU, NaN, NaN, '-',  'Color', [0.00 0.45 0.74], 'LineWidth', 1.6);
    hold(axU, 'on');
    hU    = plot(axU, NaN, NaN, '-',  'Color', [0.86 0.08 0.08], 'LineWidth', 1.2);
    ylabel(axU, 'u [m/s]');
    yyaxis(axU, 'right');
    hFL = plot(axU, NaN, NaN, '-', 'Color', [0.85 0.55 0.10], 'LineWidth', 1.0);
    hold(axU, 'on');
    hFR = plot(axU, NaN, NaN, '-', 'Color', [0.55 0.35 0.65], 'LineWidth', 1.0);
    ylabel(axU, '추력 [N]');
    grid(axU, 'on');
    xlabel(axU, '시간 [s]');
    title(axU, '속도 지령 대 실제 속도, 좌우 추력');
    legend(axU, [hUcmd hU hFL hFR], ...
           {'지령 u_{ref}\timesgate', '실제 u', 'F_L', 'F_R'}, ...
           'Location', 'best', 'FontSize', 8);

    % --- 버퍼 ---------------------------------------------------------
    trLat = [];  trLon = [];  tv = [];
    Dp    = [];  De    = [];  Dm = [];
    tLast = -inf;
end

tPrev = t;

%% 기록 — 매 스텝 쌓는다 (그리는 것은 간격을 두고 한다)
p = ned2lla([x_n, y_n, 0], lla0c, 'flat');

tv(end+1,1)    = t;
trLat(end+1,1) = p(1);
trLon(end+1,1) = p(2);
Dp(end+1,:)    = [ssa_deg(psi_ref), ssa_deg(psi)];
De(end+1,1)    = y_e;
%  속도 지령 = u_ref x gate — 내부루프의 Gate 블록이 하는 곱이다.
%  그 곱을 모델에서 태그로 빼면 본선이 사선으로 다시 그려지므로 여기서 곱한다
Dm(end+1,:)    = [uRef*gate, u, FL, FR];

if numel(tv) > NMAX
    keep  = (numel(tv)-NMAX+1):numel(tv);
    tv    = tv(keep);     trLat = trLat(keep);  trLon = trLon(keep);
    Dp    = Dp(keep,:);   De    = De(keep);     Dm    = Dm(keep,:);
end

%% 다시 그리는 간격
every = 0.25;
try, every = evalin('base', 'animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% 지도 — 항적, 선체, 헤딩선
set(hTrail, 'LatitudeData', trLat, 'LongitudeData', trLon);

[hla, hlo] = hull_ll(x_n, y_n, psi, bscale, lla0c);
set(hHull, 'LatitudeData', hla, 'LongitudeData', hlo);

L  = 2.45*bscale;
hd = ned2lla([x_n + 2.2*L*cos(psi), y_n + 2.2*L*sin(psi), 0], lla0c, 'flat');
set(hHead, 'LatitudeData', [p(1) hd(1)], 'LongitudeData', [p(2) hd(2)]);
set(hDot,  'LatitudeData', p(1),         'LongitudeData', p(2));

leg = max(1, min(double(wp_idx), nwp-1));
title(gx, sprintf('t = %6.1f s    구간 %d/%d    y_e = %+6.2f m    u = %4.2f m/s', ...
      t, leg, nwp-1, y_e, u));

%% 오른쪽 세 칸
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hE,    'XData', tv, 'YData', De);
set(hUcmd, 'XData', tv, 'YData', Dm(:,1));
set(hU,    'XData', tv, 'YData', Dm(:,2));
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));

xl = [0 max(tv(end), 1)];
set(axP, 'XLim', xl);   set(axE, 'XLim', xl);   set(axU, 'XLim', xl);
pad_y(axP, Dp);
pad_y(axE, De);

drawnow limitrate;
end

% =====================================================================
function [la, lo] = hull_ll(x, y, psi, sc, lla0c)
%HULL_LL  선체 다각형을 위경도로 — 선수는 세모, 선미는 네모 (shipModel.m 과 같은 모양)
    L = 2.45*sc;   B = 1.03*sc;
    bx = L*[-1 -1  0.5  1  0.5 -1];      % 마지막 점으로 닫는다
    by = B*[ 1 -1 -1    0  1    1];
    c = cos(psi);  s = sin(psi);
    X = x + bx*c - by*s;                 % 북
    Y = y + bx*s + by*c;                 % 동
    p = ned2lla([X(:) Y(:) zeros(numel(X),1)], lla0c, 'flat');
    la = p(:,1).';
    lo = p(:,2).';
end

% =====================================================================
function a = ssa_deg(a)
%SSA_DEG  각을 (-180, 180] 로 접어 deg 로 — 360 도 경계에서 선이 튀지 않게 한다
    a = atan2(sin(a), cos(a)) * 180/pi;
end

% =====================================================================
function pad_y(ax, D)
%PAD_Y  y 범위에 여유를 준다. t = 0 에서는 위아래가 같아 ylim 이 거부되므로 받친다
    lo = min(D(:));   hi = max(D(:));
    if ~isfinite(lo) || ~isfinite(hi), return; end
    d = max((hi-lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
    set(ax, 'YLim', [lo-d, hi+d]);
end
