function out = A2_gui_panel(varargin)
%A2_GUI_PANEL  5단 GCS 창 — 위성지도 + 그래프 세 칸 + 버튼 한 줄
%
%   fig = A2_GUI_PANEL(cb)           창을 만든다
%   A2_GUI_PANEL(fig, 'mission')     계획 경로를 다시 그리고 버튼 상태를 맞춘다
%   A2_GUI_PANEL(fig, 'say', msg)    상태줄에 한 줄 쓴다
%
%   `cb` 는 버튼과 클릭을 받을 함수의 핸들이다. 이 파일은 **창만** 만들고,
%   누르면 무슨 일이 일어나는가는 전부 `cb` 에게 넘긴다
%
%       cb(fig, 'click', lat, lon)   지도를 눌렀다
%       cb(fig, 'undo')              마지막 점 지우기
%       cb(fig, 'clear')             전부 지우기
%       cb(fig, 'start')             출발
%       cb(fig, 'pause')             일시정지 / 계속
%       cb(fig, 'stop')              정지
%
%   왜 둘을 나누는가
%     창을 만드는 코드(이 파일)와 모델을 움직이는 코드(`A2_5_gui_done`)를
%     섞으면 어느 줄이 수업의 요점인지 보이지 않는다. 학생이 고쳐 볼 곳은
%     `A2_5_gui_done` 쪽이고, 이 파일은 읽기만 해도 된다
%
%   창이 쥐고 있는 것 — `S = getappdata(fig, 'S')` 로 꺼낸다
%     gx axP axE axU        축 네 개
%     hPlan hWpM hWpT       계획 경로 · 웨이포인트 표시 · 번호 글자
%     hTrail hHull hHead hDot        항적 · 선체 · 헤딩선 · 현재 위치
%     hPref hP hE hU hUcmd hFL hFR   오른쪽 세 칸의 선
%     pick                  지금 '찍기' 모드인가
%     model                 모델 이름 ('A2_gui')
%     lla0 WP_MAX           기준점과 자리 개수

    if isa(varargin{1}, 'function_handle')
        out = build_window(varargin{1});
        return
    end

    fig  = varargin{1};
    what = varargin{2};
    switch what
        case 'mission'
            refresh_mission(fig);
        case 'say'
            say(fig, varargin{3});
        otherwise
            error('A2:panel', '모르는 명령 : %s', what);
    end
    out = fig;
end

% =====================================================================
function fig = build_window(cb)

    lla0   = evalin('base', 'lla0');
    span   = evalin('base', 'map_span_m');
    WP_MAX = evalin('base', 'WP_MAX');
    R      = evalin('base', 'R_LOS');

    bm = 'satellite';
    try, bm = evalin('base', 'basemap_name'); catch, end

    %  앞서 띄운 창이 남아 있으면 지운다. 두 창이 같은 모델을 쥐면 혼란스럽다
    old = getappdata(0, 'A2_gui_fig');
    if ~isempty(old) && isvalid(old), delete(old); end

    fig = figure('Name', 'A2 5단 — 위성지도 GCS (버튼으로 조종한다)', ...
                 'NumberTitle', 'off', 'Color', 'w', ...
                 'Position', [30 30 1380 880], ...
                 'MenuBar', 'none', 'ToolBar', 'figure');
    setappdata(0, 'A2_gui_fig', fig);

    S = struct();
    S.model  = 'A2_gui';
    S.lla0   = lla0;
    S.WP_MAX = WP_MAX;
    S.pick   = false;
    S.cb     = cb;

    % --- 왼쪽 : 위성지도 ---------------------------------------------
    S.gx = A2_openmap(lla0, span, bm, '위성지도 — 눌러서 웨이포인트를 찍는다', fig);
    %  왼쪽 여백을 넉넉히 둔다 — 좁히면 위도 눈금의 앞자리가 잘린다
    S.gx.Position = [0.075 0.065 0.425 0.800];

    S.hPlan = geoplot(S.gx, NaN, NaN, '-', 'Color', [1 1 1], 'LineWidth', 1.3);
    S.hWpM  = geoscatter(S.gx, NaN, NaN, 70, 'r', 'filled', ...
                         'MarkerEdgeColor', 'w', 'LineWidth', 1.0);
    S.hWpT  = gobjects(0);

    S.hTrail = geoplot(S.gx, NaN, NaN, '-', 'Color', [1.00 0.85 0.10], 'LineWidth', 2.0);
    S.hHull  = geoplot(S.gx, NaN, NaN, '-', 'Color', [0.10 0.90 1.00], 'LineWidth', 1.8);
    S.hHead  = geoplot(S.gx, NaN, NaN, '-', 'Color', [1.00 0.20 0.20], 'LineWidth', 1.6);
    S.hDot   = geoscatter(S.gx, NaN, NaN, 36, 'w', 'filled');

    % --- 오른쪽 : 그래프 세 칸 ---------------------------------------
    S.axP = axes('Parent', fig, 'Position', [0.595 0.670 0.365 0.195]);
    S.axE = axes('Parent', fig, 'Position', [0.595 0.390 0.365 0.195]);
    S.axU = axes('Parent', fig, 'Position', [0.595 0.090 0.365 0.195]);

    S.hPref = plot(S.axP, NaN, NaN, '-', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.6);
    hold(S.axP, 'on');
    S.hP    = plot(S.axP, NaN, NaN, '-', 'Color', [0.86 0.08 0.08], 'LineWidth', 1.2);
    grid(S.axP, 'on');
    ylabel(S.axP, '헤딩 [deg]');
    legend(S.axP, {'명령 \psi_{ref}', '실제 \psi'}, 'Location', 'best', 'FontSize', 8);
    title(S.axP, '헤딩 명령 대 실제 헤딩');

    S.hE = plot(S.axE, NaN, NaN, '-', 'Color', [0.00 0.50 0.45], 'LineWidth', 1.4);
    hold(S.axE, 'on');
    yline(S.axE, 0, 'k-');
    grid(S.axE, 'on');
    ylabel(S.axE, 'y_e [m]');
    title(S.axE, sprintf('횡방향 오차   (수락반경 R = %g m)', R));

    yyaxis(S.axU, 'left');
    S.hUcmd = plot(S.axU, NaN, NaN, '-', 'Color', [0.00 0.45 0.74], 'LineWidth', 1.6);
    hold(S.axU, 'on');
    S.hU    = plot(S.axU, NaN, NaN, '-', 'Color', [0.86 0.08 0.08], 'LineWidth', 1.2);
    ylabel(S.axU, 'u [m/s]');
    yyaxis(S.axU, 'right');
    S.hFL = plot(S.axU, NaN, NaN, '-', 'Color', [0.85 0.55 0.10], 'LineWidth', 1.0);
    hold(S.axU, 'on');
    S.hFR = plot(S.axU, NaN, NaN, '-', 'Color', [0.55 0.35 0.65], 'LineWidth', 1.0);
    ylabel(S.axU, '추력 [N]');
    grid(S.axU, 'on');
    xlabel(S.axU, '시간 [s]');
    title(S.axU, '속도 지령 대 실제 속도, 좌우 추력');
    legend(S.axU, [S.hUcmd S.hU S.hFL S.hFR], ...
           {'지령 u_{ref}\timesgate', '실제 u', 'F_L', 'F_R'}, ...
           'Location', 'best', 'FontSize', 8);

    % --- 버튼 한 줄 ---------------------------------------------------
    Y = 838;  H = 30;
    S.bPick  = uicontrol(fig, 'Style', 'togglebutton', 'String', '웨이포인트 찍기', ...
                   'Position', [ 20 Y 130 H], 'FontSize', 10, ...
                   'Callback', @(h,~) set_pick(fig, h.Value == 1));
    S.bUndo  = uicontrol(fig, 'Style', 'pushbutton', 'String', '마지막 점 지우기', ...
                   'Position', [158 Y 130 H], 'FontSize', 10, ...
                   'Callback', @(~,~) hand_over(fig, 'undo'));
    S.bClear = uicontrol(fig, 'Style', 'pushbutton', 'String', '전부 지우기', ...
                   'Position', [296 Y 130 H], 'FontSize', 10, ...
                   'Callback', @(~,~) hand_over(fig, 'clear'));
    S.bStart = uicontrol(fig, 'Style', 'pushbutton', 'String', '출발', ...
                   'Position', [444 Y 100 H], 'FontSize', 10, 'FontWeight', 'bold', ...
                   'Callback', @(~,~) hand_over(fig, 'start'));
    S.bPause = uicontrol(fig, 'Style', 'pushbutton', 'String', '일시정지', ...
                   'Position', [552 Y 100 H], 'FontSize', 10, ...
                   'Callback', @(~,~) hand_over(fig, 'pause'));
    S.bStop  = uicontrol(fig, 'Style', 'pushbutton', 'String', '정지', ...
                   'Position', [660 Y 100 H], 'FontSize', 10, ...
                   'Callback', @(~,~) hand_over(fig, 'stop'));
    S.txt    = uicontrol(fig, 'Style', 'text', 'String', '', ...
                   'Position', [775 Y-2 580 H-4], 'FontSize', 10, ...
                   'HorizontalAlignment', 'left', 'BackgroundColor', 'w');

    % --- 클릭 받기 ----------------------------------------------------
    %  ginput 을 쓰지 않는다. ginput 은 **막는 함수**라서 시뮬레이션이
    %  돌아가는 동안에는 쓸 수 없다. 창에 걸어 두는 이 방식은 막지 않는다
    set(fig, 'WindowButtonDownFcn', @(~,~) on_click(fig));
    set(fig, 'CloseRequestFcn',     @(~,~) on_close(fig));

    setappdata(fig, 'S', S);

    refresh_mission(fig);
    say(fig, '"웨이포인트 찍기" 를 누르고 지도를 눌러 점을 찍을 것');
end

% =====================================================================
function set_pick(fig, on)
%SET_PICK  찍기 모드를 켜고 끈다
    S = getappdata(fig, 'S');
    S.pick = on;
    setappdata(fig, 'S', S);
    if on
        %  이것을 하지 않으면 지리축이 클릭을 **확대·이동용으로 먼저 집어삼켜**
        %  WindowButtonDownFcn 이 불리지 않는다
        disableDefaultInteractivity(S.gx);
        say(fig, '찍기 모드 — 지도를 누를 것 (끄면 지도를 끌어 옮길 수 있다)');
    else
        enableDefaultInteractivity(S.gx);
        say(fig, '찍기 모드 해제 — 지도를 끌어 옮기거나 확대할 수 있다');
    end
end

% =====================================================================
function on_click(fig)
%ON_CLICK  창을 누를 때마다 불린다 — 지도 안의 클릭만 골라 넘긴다
    S = getappdata(fig, 'S');
    if ~S.pick, return; end

    %  버튼이나 오른쪽 그래프를 누른 것은 웨이포인트가 아니다.
    %  픽셀 자리로 먼저 걸러낸다
    c = fig.CurrentPoint;
    r = getpixelposition(S.gx);
    if c(1) < r(1) || c(1) > r(1)+r(3) || c(2) < r(2) || c(2) > r(2)+r(4)
        return
    end

    %  지리축의 CurrentPoint 는 2x3 이고 **1열이 위도, 2열이 경도**다
    %  (geoaxes 의 규약. 실측으로 확인했다 — 뒤집으면 지구 반대편이 나온다)
    cp  = S.gx.CurrentPoint;
    lat = cp(1,1);
    lon = cp(1,2);

    %  두 번째 그물 — 지도 범위를 벗어난 값이면 위경도가 뒤집힌 것이다
    if lat < S.gx.LatitudeLimits(1)  || lat > S.gx.LatitudeLimits(2) || ...
       lon < S.gx.LongitudeLimits(1) || lon > S.gx.LongitudeLimits(2)
        say(fig, sprintf('지도 밖의 값이라 버렸다 : %.6f, %.6f', lat, lon));
        return
    end

    S.cb(fig, 'click', lat, lon);
end

% =====================================================================
function hand_over(fig, what)
%HAND_OVER  버튼을 눌렀다 — 판단은 cb 가 한다
    S = getappdata(fig, 'S');
    S.cb(fig, what);
end

% =====================================================================
function on_close(fig)
%ON_CLOSE  창을 닫는다 — 돌아가는 모델을 남기지 않는다
    S = getappdata(fig, 'S');
    try
        if bdIsLoaded(S.model) && ~strcmp(get_param(S.model, 'SimulationStatus'), 'stopped')
            set_param(S.model, 'SimulationCommand', 'stop');
        end
    catch err
        warning('A2:closestop', '모델을 멈추지 못했다 : %s', err.message);
    end
    setappdata(0, 'A2_gui_fig', []);
    delete(fig);
end

% =====================================================================
function refresh_mission(fig)
%REFRESH_MISSION  계획 경로를 다시 그리고 버튼 상태를 맞춘다
%
%   베이스 워크스페이스의 `wp_north` · `wp_east` · `n_wp` 가 유일한 원본이다.
%   창은 그것을 **비추기만** 한다 — 두 군데에 같은 값을 두지 않는다

    S = getappdata(fig, 'S');

    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    n   = double(evalin('base', 'n_wp'));

    xs = wpx(1:n);   ys = wpy(1:n);
    ll = ned2lla([xs(:) ys(:) zeros(n,1)], S.lla0, 'flat');

    set(S.hPlan, 'LatitudeData', ll(:,1).', 'LongitudeData', ll(:,2).');
    set(S.hWpM,  'LatitudeData', ll(:,1).', 'LongitudeData', ll(:,2).');

    delete(S.hWpT(isgraphics(S.hWpT)));
    S.hWpT = gobjects(1, n);
    for k = 1:n
        S.hWpT(k) = text(S.gx, ll(k,1), ll(k,2), sprintf('  %d', k-1), ...
                         'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12);
    end
    setappdata(fig, 'S', S);

    %  버튼 상태 — 점이 하나뿐이면 갈 곳이 없으므로 '출발' 을 막는다
    running = false;
    try
        running = bdIsLoaded(S.model) && ...
                  ~strcmp(get_param(S.model, 'SimulationStatus'), 'stopped');
    catch
    end
    onoff = {'off', 'on'};
    set(S.bStart, 'Enable', onoff{1 + (n >= 2 && ~running)});
    set(S.bPause, 'Enable', onoff{1 + running});
    set(S.bStop,  'Enable', onoff{1 + running});
    set(S.bUndo,  'Enable', onoff{1 + (n >= 2)});
    set(S.bClear, 'Enable', onoff{1 + (n >= 2 && ~running)});
end

% =====================================================================
function say(fig, msg)
%SAY  상태줄에 한 줄 쓰고 명령창에도 남긴다
    S = getappdata(fig, 'S');
    set(S.txt, 'String', msg);
    fprintf('  [GCS] %s\n', msg);
    drawnow limitrate;
end
