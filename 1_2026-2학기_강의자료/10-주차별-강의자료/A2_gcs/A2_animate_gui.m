function f = A2_animate_gui(x_n, y_n, psi, psi_ref, y_e, u, gate, FL, FR, wp_idx, t)
%A2_ANIMATE_GUI  5단 실시간 화면 — GUI 창에 **이미 있는** 축에 그린다
%
%   `A2_gui.slx` 의 Animate 블록이 제어 주기마다 이 함수를 부른다.
%   인자 순서는 Animate 서브시스템의 From 태그 순서와 같다 (5주차와 같은 계약)
%
%       x_n  y_n  psi  psi_ref  y_e  u  gate  FL  FR  wp_idx  +  t
%
%   4단(`A2_animate_map`) 과 무엇이 다른가
%     4단은 **스스로 창을 만들었다.** 5단은 만들지 않는다
%     창·축·선 핸들은 `A2_gui_panel` 이 미리 만들어 `S` 구조체에 담아 두었고,
%     이 함수는 그 핸들의 데이터만 갈아 끼운다
%
%   | 무엇을 그리는가 | 누가 소유하는가 |
%   |-----------------|-----------------|
%   | 창·축·버튼      | `A2_gui_panel`  |
%   | 계획 경로·웨이포인트 표시 | `A2_gui_addwp` (클릭할 때마다 다시 그림) |
%   | 항적·선체·헤딩선·오른쪽 세 칸 | **이 함수** (실행 중 매 주기) |
%
%   f = A2_ANIMATE_GUI()         그림 핸들만 돌려준다 (캡처용)
%   A2_ANIMATE_GUI('reset')      버퍼를 비운다 (다시 출발할 때)
%
%   베이스 워크스페이스에서 읽는 값 — `A2_gui_setup` 이 만든다
%     lla0  u_ref  n_wp
%   선택
%     animate_every  몇 초마다 다시 그릴 것인가 (기본 0.25)
%     boat_scale     선체 확대 배율 (기본 6)

persistent trLat trLon tv Dp De Dm tLast tPrev lla0c uRef bscale

NMAX = 40000;        % 버퍼 상한 — 길게 돌려도 메모리가 늘지 않게 한다

%% 인자 없이 / 글자 하나로 부른 경우 — 사람이 부르는 길
if nargin == 0
    f = getappdata(0, 'A2_gui_fig');
    return
end
if nargin == 1 && (ischar(x_n) || isstring(x_n))
    trLat = [];  trLon = [];  tv = [];
    Dp = [];  De = [];  Dm = [];
    tLast = [];  tPrev = [];
    f = getappdata(0, 'A2_gui_fig');
    return
end

%% 창이 없으면 아무것도 하지 않는다 — 모델은 계속 돌아간다
fig = getappdata(0, 'A2_gui_fig');
if isempty(fig) || ~isvalid(fig)
    f = [];
    return
end
S = getappdata(fig, 'S');
f = fig;

%% 새 실행인지 판정 — 시간이 거꾸로 가면 새 실행이다
newRun = isempty(tLast) || isempty(tPrev) || t < tPrev;

if newRun
    lla0c = evalin('base', 'lla0');
    uRef  = evalin('base', 'u_ref');
    bscale = 6;
    try, bscale = evalin('base', 'boat_scale'); catch, end

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
%  속도 지령 = u_ref x gate — 내부루프의 Gate 블록이 하는 곱이다
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
set(S.hTrail, 'LatitudeData', trLat, 'LongitudeData', trLon);

[hla, hlo] = hull_ll(x_n, y_n, psi, bscale, lla0c);
set(S.hHull, 'LatitudeData', hla, 'LongitudeData', hlo);

L  = 2.45*bscale;
hd = ned2lla([x_n + 2.2*L*cos(psi), y_n + 2.2*L*sin(psi), 0], lla0c, 'flat');
set(S.hHead, 'LatitudeData', [p(1) hd(1)], 'LongitudeData', [p(2) hd(2)]);
set(S.hDot,  'LatitudeData', p(1),         'LongitudeData', p(2));

%  유효 점 개수는 실행 중에 바뀐다 — 매번 다시 읽는다.
%  그래서 점을 더 찍으면 제목의 구간 수가 바로 늘어난다
nwp = 1;
try, nwp = evalin('base', 'n_wp'); catch, end
nleg = max(1, double(nwp) - 1);
leg  = max(1, min(double(wp_idx), nleg));
if gate < 0.5
    tag = '임무 완료 — 점을 더 찍으면 다시 간다';
else
    tag = sprintf('구간 %d/%d', leg, nleg);
end
title(S.gx, sprintf('t = %6.1f s    %s    y_e = %+6.2f m    u = %4.2f m/s', ...
      t, tag, y_e, u));

%% 오른쪽 세 칸
set(S.hPref, 'XData', tv, 'YData', Dp(:,1));
set(S.hP,    'XData', tv, 'YData', Dp(:,2));
set(S.hE,    'XData', tv, 'YData', De);
set(S.hUcmd, 'XData', tv, 'YData', Dm(:,1));
set(S.hU,    'XData', tv, 'YData', Dm(:,2));
set(S.hFL,   'XData', tv, 'YData', Dm(:,3));
set(S.hFR,   'XData', tv, 'YData', Dm(:,4));

xl = [0 max(tv(end), 1)];
set(S.axP, 'XLim', xl);   set(S.axE, 'XLim', xl);   set(S.axU, 'XLim', xl);
pad_y(S.axP, Dp);
pad_y(S.axE, De);

drawnow limitrate;
end

% =====================================================================
function [la, lo] = hull_ll(x, y, psi, sc, lla0c)
%HULL_LL  선체 다각형을 위경도로 — 선수는 세모, 선미는 네모
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
