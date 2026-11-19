function out = TP_gcs(v, t)
%TP_GCS  해양누리공원 GCS — 위성지도 위의 배와 항적, 실시간 그래프, 조종 버튼
%
%   모델의 GCS 블록이 제어 주기마다 부른다.          TP_gcs(v, t)
%   모델의 InitFcn 이 실행 전에 창을 세운다.          TP_gcs('init', 모델이름)
%   그림 핸들만 받는다 (캡처용).                       f = TP_gcs()
%   지금까지의 기록을 받는다 (요약·검증용).            S = TP_gcs('result')
%
%   v 의 순서 — 빌더(build_tp_manual.m)의 GCS 상자와 **같은 표**다. 순서가 곧 계약이다
%
%       1 x_n   북 위치 [m]  (VRX: GPS 로 구한 선체 중심)     9  FB  선수 추력 [N]
%       2 y_n   동 위치 [m]                                  10 X   요구 전후력 [N]
%       3 psi   선수각 [rad] (북에서 시계방향 +)              11 Y   요구 횡력 [N]
%       4 u     선수 방향 속도 [m/s]                         12 N   요구 요 모멘트 [N m]
%       5 v     우현 방향 속도 [m/s]                         13 x_true  참값 북 [m]
%       6 r     선수동요 각속도 [rad/s]                      14 y_true  참값 동 [m]
%       7 FL    좌현 추력 [N]                                15 valid   1 = 센서 값이 들어옴
%       8 FR    우현 추력 [N]
%
%   화면
%     왼쪽 위    위성지도 — 미션 지점 넷, 위치유지 링, 항적, **선체 모양과 선수 방향선**
%     왼쪽 아래  조종 버튼(화살표 여섯 + 정지)과 현재값 · 위치유지 판정
%     오른쪽     선수각 [deg] / 선수 속도 u [m/s] / 위치 x·y [m] / 추력 셋 [N]
%
%   조종 — 이 창이 앞에 있을 때
%     마우스   화살표를 **누르고 있는 동안** 힘이 나간다. 떼면 0
%     키보드   W 전진 · S 후진 · A 좌선회 · D 우선회 · Q 좌현 횡이동 · E 우현 횡이동 · 스페이스 정지
%     정지     가운데 '정지' 원을 클릭하면 Simulink 의 정지 버튼이 켜진다 (모든 출력 0, 다시 누르면 풀림)
%              (방향키 ↑ ↓ ← → 도 W S A D 와 같다)
%     눌린 값은 appdata 'TP_keys' 에 두고, 모델의 ManualPad/GcsKeys 블록이 매 스텝 읽는다
%
%   왜 MATLAB Function 블록이 직접 그리지 않는가
%     그 블록은 코드 생성 대상이라 그림을 못 그린다. coder.extrinsic 으로 이 함수를 부른다

persistent G

if nargin == 0                                   % 그림 핸들
    out = [];
    if ~isempty(G) && isvalid(G.fig), out = G.fig; end
    return
end

if ischar(v) || isstring(v)
    switch char(v)
        case 'init'
            G = build(char(t));
            if nargout, out = G.fig; end
        case 'result'
            out = result(G);
    end
    return
end

v = double(v(:)).';
setappdata(0, 'TP_state', [t, v]);               % 가상 조종사(TP_manual_check)가 읽는다
if nargout, out = 1; end
if isequal(getappdata(0, 'TP_gcs_on'), false), return; end   % animate = 0 — 창을 띄우지 않는 실행

if isempty(G) || ~isvalid(G.fig)                 % 실행 중에 창을 닫았으면 다시 세운다
    G = build(getappdata(0, 'TP_gcs_model'));
end
if v(15) < 0.5, return; end                      % 첫 메시지 전 — 0 으로 채운 값은 그리지 않는다

%% 기록 — 매 스텝 쌓는다
G.n = G.n + 1;
if G.n > size(G.D, 1), G.D(end + 5000, 1) = 0; end
G.D(G.n, :) = [t, v];
if G.n == 1, G.w0 = tic; end                     % 벽시계 — 모델이 실시간을 따라갔는지 본다
G.wall = toc(G.w0);

%% 위치유지 판정 — 반경 안 + 정지를 hold_time 동안 이어 가면 성공 (요구조건 3-2 절)
dt = t - G.tPrev;   G.tPrev = t;
U  = hypot(v(4), v(5));
for k = 1:2
    d = hypot(v(1) - G.wp(k, 1), v(2) - G.wp(k, 2));
    G.dist(k) = d;
    if d <= G.holdR && U <= G.holdU
        G.hold(k) = G.hold(k) + max(dt, 0);
    else
        G.hold(k) = 0;
    end
    G.inside(k) = G.inside(k) || d <= G.holdR;
    if G.hold(k) >= G.holdT && isnan(G.done(k)), G.done(k) = t; end
end

%% 다시 그리는 간격
if t - G.tDraw < G.every, return; end
G.tDraw = t;
draw(G, v, t);
drawnow limitrate

%% 녹화 — appdata 'TP_rec' 에 폴더와 간격을 주면 그 간격(모델 시간)마다 창을 한 장씩 남긴다
%   파일 이름에 벽시계(ms)와 모델 시각을 넣는다. 가제보 화면과 나란히 붙일 때 벽시계로 맞춘다
rec = getappdata(0, 'TP_rec');
if isstruct(rec) && t - G.tRec >= rec.every
    if ~isfinite(G.tRec) && ~isfolder(rec.dir), mkdir(rec.dir); end
    G.tRec = t;
    fr = getframe(G.fig);
    im = fr.cdata;
    %  고해상도 화면에서는 창이 두 배 크기로 잡힌다. 절반으로 줄여 쓴다 — 쓰는 시간이 1/3 로 준다
    %  (2026-11-19 실측 : getframe 0.09 s + 2760x1560 쓰기 0.07 s. 1 초마다 남겼더니 k = 1.225)
    if size(im, 2) > 2000, im = im(1:2:end, 1:2:end, :); end
    imwrite(im, fullfile(rec.dir, sprintf('gcs_%013.0f_%07.1f.jpg', ...
            double(java.lang.System.currentTimeMillis()), t)), 'Quality', 90);
end
end

% =====================================================================
function G = build(mdl)
%BUILD  창을 세우고 설정을 읽는다. 버퍼를 비운다 (= 새 실행)
B = @(nm, def) base_or(nm, def);
G.mdl   = mdl;
G.lat0  = B('lat0_tp', 35.1862095);
G.lon0  = B('lon0_tp', 128.5665903);
G.every = B('animate_every', 0.25);
G.win   = B('gcs_window', 120);
G.scale = B('boat_scale', 3.0);
view    = B('gcs_view', [-105 50 -130 45]);
G.holdR = B('hold_radius', 5.0);
G.holdU = B('hold_speed', 0.1);
G.holdT = B('hold_time', 5.0);
bm      = B('basemap_name', 'satellite');
[G.dLat, G.dLon] = deg_per_m(G.lat0);

G.D = zeros(20000, 16);   G.n = 0;
G.tPrev = 0;   G.tDraw = -inf;   G.tRec = -inf;
G.hold = [0 0];   G.done = [NaN NaN];   G.dist = [NaN NaN];   G.inside = [false false];

%  미션 지점 — TP_haeyang/haeyang_points.m 이 숫자의 원본이다
try
    P = haeyang_points();
    G.pt = [P.n_m, P.e_m];   G.ptName = P.name;
catch
    G.pt = [-32 0; 10 0; -14 -20; -39 -70];   G.ptName = {'start'; 'wp1'; 'wp2'; 'goal'};
end
G.wp = G.pt(2:3, :);                             % 위치유지 지점 둘 (북, 동)

old = findall(0, 'Type', 'figure', 'Tag', 'TP_gcs');
delete(old);
scr = get(0, 'ScreenSize');
w = min(1500, scr(3) - 60);   h = min(880, scr(4) - 120);
G.fig = figure('Name', '해양누리공원 GCS — 수동 조종', 'NumberTitle', 'off', 'Tag', 'TP_gcs', ...
               'Color', 'w', 'Position', [scr(3) - w - 20, 60, w, h], ...
               'WindowKeyPressFcn',   @key_down, ...
               'WindowKeyReleaseFcn', @key_up, ...
               'WindowButtonUpFcn',   @(~, ~) release_all());
setappdata(0, 'TP_keys', zeros(1, 6));

% --- 위성지도 ---------------------------------------------------------
%  왼쪽 여백을 넉넉히 둔다 — 좁히면 위도 눈금(35°11'10"N)의 앞자리가 잘린다
G.gx = geoaxes(G.fig, 'Position', [0.075 0.285 0.440 0.655]);
for b = {bm, 'satellite', 'topographic', 'streets-light', 'none'}
    try
        geobasemap(G.gx, b{1});   drawnow
        G.basemap = b{1};
        break
    catch
    end
end
hold(G.gx, 'on');
[la, lo] = G_ll(G, view(1:2), view(3:4));
geolimits(G.gx, la, lo);
G.gx.LatitudeLabel.String = '';   G.gx.LongitudeLabel.String = '';

[pla, plo] = G_ll(G, G.pt(:, 1), G.pt(:, 2));
geoplot(G.gx, pla, plo, '--', 'Color', [1 1 1], 'LineWidth', 1.2);
col = [0.10 0.80 0.25; 0.20 0.55 1.00; 1.00 0.55 0.10; 1.00 0.25 0.25];
lab = {'① 출발', '② WP1', '③ WP2', '④ 종료'};
for k = 1:size(G.pt, 1)
    geoplot(G.gx, pla(k), plo(k), 'o', 'MarkerSize', 9, 'LineWidth', 2, ...
            'Color', col(k, :), 'MarkerFaceColor', 'w');
    text(G.gx, pla(k), plo(k) + 4*G.dLon, lab{k}, 'Color', 'w', 'FontWeight', 'bold', ...
         'FontSize', 11);
end
th = linspace(0, 2*pi, 73);
for k = 1:2                                       % 위치유지 링 (반경 hold_radius)
    [rla, rlo] = G_ll(G, G.wp(k, 1) + G.holdR*cos(th), G.wp(k, 2) + G.holdR*sin(th));
    G.hRing(k) = geoplot(G.gx, rla, rlo, '-', 'Color', [1.00 0.60 0.15], 'LineWidth', 1.6);
end
G.hTrail = geoplot(G.gx, NaN, NaN, '-', 'Color', [1.00 0.90 0.10], 'LineWidth', 2.2);
G.hHull  = geoplot(G.gx, NaN, NaN, '-', 'Color', [0.10 0.95 1.00], 'LineWidth', 2.2);
G.hHead  = geoplot(G.gx, NaN, NaN, '-', 'Color', [1.00 0.20 0.20], 'LineWidth', 2.0);
title(G.gx, '3·15 해양누리공원 앞 수역 — 노랑 항적 · 하늘색 선체 · 빨강 선수 방향');

% --- 오른쪽 그래프 넷 --------------------------------------------------
x0 = 0.585;  wd = 0.385;  ht = 0.170;
yb = [0.775 0.545 0.315 0.075];
ttl = {'선수각 \psi [deg]   (-180 ~ +180 으로 접음.  북 0 · 동 +90 · 서 -90 · 남 \pm180.  점선이 \pm180 경계)', '선수 방향 속도 u [m/s]', ...
       '위치 [m]   (북 x, 동 y — 월드 원점 기준)', '추력 [N]'};
for k = 1:4
    G.ax(k) = axes('Parent', G.fig, 'Position', [x0 yb(k) wd ht]); %#ok<LAXES>
    hold(G.ax(k), 'on');   grid(G.ax(k), 'on');   box(G.ax(k), 'on');
    title(G.ax(k), ttl{k}, 'FontSize', 10);
end
xlabel(G.ax(4), '시간 [s]');
G.hPsi = plot(G.ax(1), NaN, NaN, '-', 'Color', [0.86 0.08 0.08], 'LineWidth', 1.5);
G.hU   = plot(G.ax(2), NaN, NaN, '-', 'Color', [0.86 0.08 0.08], 'LineWidth', 1.5);
G.hV   = plot(G.ax(2), NaN, NaN, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
legend(G.ax(2), {'u (앞)', 'v (우현)'}, 'Location', 'northwest', 'FontSize', 8);
G.hX   = plot(G.ax(3), NaN, NaN, '-', 'Color', [0.11 0.31 0.85], 'LineWidth', 1.5);
G.hY   = plot(G.ax(3), NaN, NaN, '-', 'Color', [0.05 0.58 0.53], 'LineWidth', 1.5);
legend(G.ax(3), {'x 북', 'y 동'}, 'Location', 'northwest', 'FontSize', 8);
G.hFL  = plot(G.ax(4), NaN, NaN, '-', 'Color', [0.85 0.47 0.02], 'LineWidth', 1.3);
G.hFR  = plot(G.ax(4), NaN, NaN, '-', 'Color', [0.49 0.23 0.75], 'LineWidth', 1.3);
G.hFB  = plot(G.ax(4), NaN, NaN, '-', 'Color', [0.09 0.64 0.29], 'LineWidth', 1.3);
legend(G.ax(4), {'F_L 좌현', 'F_R 우현', 'F_B 선수'}, 'Location', 'northwest', 'FontSize', 8);
%  축을 ±200 으로 조금 넓게 잡고 ±180 에 점선을 긋는다. 축 끝이 정확히 ±180 이면 경계에서
%  반대편으로 건너뛰는 자리가 축 밖으로 나가는 것처럼 보인다 (값은 언제나 ±180 안이다)
set(G.ax(1), 'YLim', [-200 200], 'YTick', -180:90:180);
yline(G.ax(1),  180, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0, 'HandleVisibility', 'off');
yline(G.ax(1), -180, ':', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0, 'HandleVisibility', 'off');

% --- 조종 버튼 ---------------------------------------------------------
G.pad = axes('Parent', G.fig, 'Position', [0.015 0.010 0.260 0.235], ...
             'XLim', [-0.6 9.6], 'YLim', [-0.5 6.9], 'Visible', 'off', 'DataAspectRatio', [1 1 1]);
hold(G.pad, 'on');
%  [가운데 x, 가운데 y, 방향(deg), 키 번호]   키 번호 = 1 전진 2 후진 3 좌선회 4 우선회 5 좌현 6 우현
spec = [4.5 4.9  90 1;  4.5 1.1 270 2;  2.3 3.0 180 3;  6.7 3.0   0 4;  0.9 5.4 180 5;  8.1 5.4   0 6];
name = {'W 전진', 'S 후진', 'A 좌선회', 'D 우선회', 'Q 좌현 횡', 'E 우현 횡'};
ar = [-0.8 0.1 0.1 0.9 0.1 0.1 -0.8; 0.32 0.32 0.75 0 -0.75 -0.32 -0.32];   % 오른쪽을 보는 화살표
for k = 1:6
    a = spec(k, 3)*pi/180;
    R = [cos(a) -sin(a); sin(a) cos(a)] * ar;
    G.hBtn(k) = patch(G.pad, spec(k, 1) + R(1, :), spec(k, 2) + R(2, :), [0.80 0.86 0.94], ...
                      'EdgeColor', [0.20 0.25 0.33], 'LineWidth', 1.4, ...
                      'ButtonDownFcn', @(~, ~) press(spec(k, 4)));
    off = [0 1.35; 0 -1.35; -0.3 -1.1; 0.3 -1.1; 0 -1.1; 0 -1.1];     % 이름표 자리 — 화살표를 덮지 않게
    text(G.pad, spec(k, 1) + off(k, 1), spec(k, 2) + off(k, 2), name{k}, 'HorizontalAlignment', 'center', ...
         'FontSize', 9, 'Color', [0.12 0.16 0.23], 'PickableParts', 'none');
end
th = linspace(0, 2*pi, 40);
G.hStop = patch(G.pad, 4.5 + 0.62*cos(th), 3.0 + 0.62*sin(th), [0.99 0.89 0.89], ...
                'EdgeColor', [0.86 0.15 0.15], 'LineWidth', 1.4, ...
                'ButtonDownFcn', @(~, ~) toggle_stop(mdl));
text(G.pad, 4.5, 3.0, '정지', 'HorizontalAlignment', 'center', 'FontSize', 9, ...
     'Color', [0.86 0.15 0.15], 'PickableParts', 'none');

% --- 현재값 ------------------------------------------------------------
%  annotation 글상자를 쓰지 않는다 — 글자를 바꿀 때마다 그림 전체의 배치를 다시 잡아
%  한 번에 0.13 s 가 든다 (2026-11-19 실측). 축 안의 text 는 그렇지 않다
axT = axes('Parent', G.fig, 'Position', [0.285 0.012 0.235 0.222], 'XLim', [0 1], 'YLim', [0 1], ...
           'XTick', [], 'YTick', [], 'Box', 'on', 'Color', [0.97 0.98 1.00], ...
           'XColor', [0.80 0.84 0.88], 'YColor', [0.80 0.84 0.88]);
G.txt = text(axT, 0.03, 0.96, '', 'FontName', 'Malgun Gothic', 'FontSize', 10, ...
             'Interpreter', 'none', 'VerticalAlignment', 'top');
set(G.txt, 'String', {'Simulink 에서 Run 을 누르면 값이 들어온다.', '', ...
    '조종 — 이 창을 한 번 클릭한 뒤', '  W S A D  전진·후진·좌선회·우선회', ...
    '  Q E      좌현·우현 횡이동 (선수추진기)', '  스페이스  정지', ...
    '  화살표를 마우스로 누르고 있어도 된다'});
drawnow
end

% =====================================================================
function draw(G, v, t)
D  = G.D(1:G.n, :);
tv = D(:, 1);

%  지도 — 항적 · 선체 · 선수 방향선
[la, lo] = G_ll(G, D(:, 2), D(:, 3));
set(G.hTrail, 'LatitudeData', la, 'LongitudeData', lo);
L = 2.45*G.scale;   Bh = 1.23*G.scale;            % 반길이 · 반폭 (WAM-V 4.9 x 2.46 m)
bx = L *[-1 -1  0.45  1  0.45 -1];                % 선미는 네모, 선수는 뾰족
by = Bh*[ 1 -1 -1     0  1     1];
c = cos(v(3));  s = sin(v(3));
[hla, hlo] = G_ll(G, v(1) + bx*c - by*s, v(2) + bx*s + by*c);
set(G.hHull, 'LatitudeData', hla, 'LongitudeData', hlo);
[dla, dlo] = G_ll(G, v(1) + [0 2.4*L]*c, v(2) + [0 2.4*L]*s);
set(G.hHead, 'LatitudeData', dla, 'LongitudeData', dlo);
for k = 1:2
    if ~isnan(G.done(k)),  set(G.hRing(k), 'Color', [0.20 0.90 0.30], 'LineWidth', 2.6);
    elseif G.dist(k) <= G.holdR, set(G.hRing(k), 'Color', [1.00 1.00 0.20], 'LineWidth', 2.6);
    else,                  set(G.hRing(k), 'Color', [1.00 0.60 0.15], 'LineWidth', 1.6);
    end
end
psd = atan2(sin(v(3)), cos(v(3)))*180/pi;          % -180 ~ +180

%  오른쪽 그래프 — 최근 gcs_window 초
i0 = find(tv >= t - G.win, 1);
if isempty(i0), i0 = 1; end
T  = tv(i0:end);   E = D(i0:end, :);
ps = atan2(sin(E(:, 4)), cos(E(:, 4)))*180/pi;    % -180 ~ +180 으로 접는다 (wrapToPi 와 같다)
jump = [false; abs(diff(ps)) > 180];              % +180 ↔ -180 을 건너뛰는 자리에서 선을 끊는다
ps(jump) = NaN;                                   % (잇지 않는다 — 이으면 세로줄이 화면을 가로지른다)
set(G.hPsi, 'XData', T, 'YData', ps);
set(G.hU,   'XData', T, 'YData', E(:, 5));
set(G.hV,   'XData', T, 'YData', E(:, 6));
set(G.hX,   'XData', T, 'YData', E(:, 2));
set(G.hY,   'XData', T, 'YData', E(:, 3));
set(G.hFL,  'XData', T, 'YData', E(:, 8));
set(G.hFR,  'XData', T, 'YData', E(:, 9));
set(G.hFB,  'XData', T, 'YData', E(:, 10));
%  축 범위는 **넘칠 때만** 바꾼다. 매번 바꾸면 눈금을 다시 잡느라 한 번에 0.19 s 가 든다
te = 20*ceil(max(t, 1)/20);                       % 가로축은 20 초씩 늘린다
xl = [max(0, te - G.win), te];
if ~isequal(get(G.ax(1), 'XLim'), xl), set(G.ax, 'XLim', xl); end
pad_y(G.ax(2), E(:, 5:6), 1.0);
pad_y(G.ax(3), E(:, 2:3), 20);
pad_y(G.ax(4), E(:, 8:10), 400);

%  조종 버튼 — 지금 나가고 있는 요구 힘의 부호로 칠한다 (누가 눌렀든 같다)
on = [v(10) > 1, v(10) < -1, v(12) < -1, v(12) > 1, v(11) < -1, v(11) > 1];
for k = 1:6
    if on(k), set(G.hBtn(k), 'FaceColor', [1.00 0.80 0.20]);
    else,     set(G.hBtn(k), 'FaceColor', [0.80 0.86 0.94]);
    end
end

%  Simulink 의 정지 버튼(ManualPad/c_stop)이 눌려 있는가 — 눌려 있으면 가운데 원을 빨갛게 채운다
stopped = false;
try, stopped = str2double(get_param([G.mdl '/ManualPad/c_stop'], 'Value')) > 0.5; catch, end
if stopped, set(G.hStop, 'FaceColor', [0.90 0.15 0.15]);
else,       set(G.hStop, 'FaceColor', [0.99 0.89 0.89]);
end

%  현재값
[lat, lon] = G_ll(G, v(1), v(2));
s = cell(1, 2);
for k = 1:2
    if ~isnan(G.done(k))
        s{k} = sprintf('WP%d  거리 %5.2f m   **성공** (t = %.1f s)', k, G.dist(k), G.done(k));
    elseif G.dist(k) <= G.holdR
        s{k} = sprintf('WP%d  거리 %5.2f m   링 안 — 정지 %.1f / %.0f s', k, G.dist(k), G.hold(k), G.holdT);
    else
        s{k} = sprintf('WP%d  거리 %5.2f m', k, G.dist(k));
    end
end
set(G.txt, 'String', { ...
    sprintf('t = %.1f s', t), ...
    sprintf('위도 %.7f°   경도 %.7f°', lat, lon), ...
    sprintf('북 x %+8.2f m    동 y %+8.2f m', v(1), v(2)), ...
    sprintf('선수각 %+7.1f°    각속도 %+6.1f °/s', psd, v(6)*180/pi), ...
    sprintf('u %+5.2f m/s    v %+5.2f m/s    속력 %4.2f m/s', v(4), v(5), hypot(v(4), v(5))), ...
    sprintf('추력  좌 %+5.0f   우 %+5.0f   선수 %+5.0f N', v(7), v(8), v(9)), ...
    s{1}, s{2}, ...
    sprintf('(판정 : %.0f m 이내 · %.1f m/s 이하 · %.0f 초)', G.holdR, G.holdU, G.holdT)});
if stopped
    str = get(G.txt, 'String');
    str{1} = sprintf('t = %.1f s    ** 정지 버튼 눌림 — 모든 출력 0 **', t);
    set(G.txt, 'String', str);
end
end

% =====================================================================
function S = result(G)
%RESULT  지금까지의 기록 — 요약과 검증 스크립트가 쓴다
S = struct('n', 0);
if isempty(G) || G.n == 0, return; end
D = G.D(1:G.n, :);
S.n = G.n;            S.t = D(:, 1);
S.x_n = D(:, 2);      S.y_n = D(:, 3);      S.psi = D(:, 4);
S.u = D(:, 5);        S.v = D(:, 6);        S.r = D(:, 7);
S.FL = D(:, 8);       S.FR = D(:, 9);       S.FB = D(:, 10);
S.X = D(:, 11);       S.Y = D(:, 12);       S.N = D(:, 13);
S.x_true = D(:, 14);  S.y_true = D(:, 15);
S.path = sum(hypot(diff(S.x_true), diff(S.y_true)));
S.wall = G.wall;                                 % 첫 기록부터 마지막 기록까지의 벽시계 [s]
S.pace = (S.t(end) - S.t(1))/max(S.wall, eps);   % 모델 시간 / 벽시계 — 1 이면 실시간
S.gps_err = hypot(S.x_n - S.x_true, S.y_n - S.y_true);
S.hold_done = G.done;   S.inside = G.inside;   S.dist_end = G.dist;
if isfield(G, 'basemap'), S.basemap = G.basemap; end
[S.lat, S.lon] = G_ll(G, S.x_n, S.y_n);
end

% =====================================================================
%  조종 입력 — 눌린 값을 appdata 'TP_keys' 에 둔다. 모델의 GcsKeys 블록이 읽는다
%    순서 [전진 후진 좌선회 우선회 좌현횡 우현횡]
function press(k)
a = getappdata(0, 'TP_keys');
if numel(a) ~= 6, a = zeros(1, 6); end
a(k) = 1;
setappdata(0, 'TP_keys', a);
end

function release_all()
setappdata(0, 'TP_keys', zeros(1, 6));
end

function toggle_stop(mdl)
%TOGGLE_STOP  GCS 가운데의 '정지' 원 — Simulink 의 정지 버튼(ManualPad/c_stop)을 켜고 끈다
%   켜면 모든 출력이 0 이 되고, 다시 누르면 풀린다. Simulink 캔버스의 정지 버튼과 같은 값을 쓴다
release_all();
try
    b = [mdl '/ManualPad/c_stop'];
    on = str2double(get_param(b, 'Value')) > 0.5;
    set_param(b, 'Value', num2str(double(~on)));
catch
end
end

function key_down(~, e)
k = key_index(e.Key);
if k > 0, press(k); elseif k < 0, release_all(); end
end

function key_up(~, e)
k = key_index(e.Key);
if k > 0
    a = getappdata(0, 'TP_keys');
    if numel(a) ~= 6, a = zeros(1, 6); end
    a(k) = 0;
    setappdata(0, 'TP_keys', a);
end
end

function k = key_index(key)
switch lower(key)
    case {'w', 'uparrow'},    k = 1;
    case {'s', 'downarrow'},  k = 2;
    case {'a', 'leftarrow'},  k = 3;
    case {'d', 'rightarrow'}, k = 4;
    case 'q',                 k = 5;
    case 'e',                 k = 6;
    case 'space',             k = -1;
    otherwise,                k = 0;
end
end

% =====================================================================
function [lat, lon] = G_ll(G, x_n, y_n)
%G_LL  월드 원점 기준 북·동 [m] -> 위도·경도 [deg]  (haeyang_points.m 과 같은 식)
lat = G.lat0 + x_n*G.dLat;
lon = G.lon0 + y_n*G.dLon;
end

function [dLat, dLon] = deg_per_m(lat0)
a  = 6378137.0;   f = 1/298.257223563;   e2 = f*(2 - f);
W  = 1 - e2*sind(lat0)^2;
M  = a*(1 - e2)/W^1.5;                           % 자오선 곡률반경
N  = a/sqrt(W);                                  % 묘유선 곡률반경
dLat = rad2deg(1/M);
dLon = rad2deg(1/(N*cosd(lat0)));
end

function val = base_or(nm, def)
val = def;
try
    if evalin('base', sprintf('exist(''%s'',''var'')', nm)) == 1
        val = evalin('base', nm);
    end
catch
end
end

function pad_y(ax, D, step)
%PAD_Y  세로축을 step 의 배수로 잡는다. 자료가 지금 범위를 넘을 때만 바꾼다
lo = min(D(:));   hi = max(D(:));
if ~isfinite(lo) || ~isfinite(hi), return; end
yl = [step*floor((lo - 0.05*step)/step), step*ceil((hi + 0.05*step)/step)];
if yl(2) <= yl(1), yl(2) = yl(1) + step; end
if ~isequal(get(ax, 'YLim'), yl), set(ax, 'YLim', yl); end
end
