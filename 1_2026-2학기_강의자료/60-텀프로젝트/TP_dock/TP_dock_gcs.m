function TP_dock_gcs(cmd)
%TP_DOCK_GCS  도킹 관제 화면 — 가제보 왼쪽, 이 창 오른쪽
%
%   >> TP_dock_gcs            창을 띄우고 5 Hz 로 갱신한다
%   >> TP_dock_gcs('stop')    창과 타이머를 닫는다
%
%   보이는 것
%     - 선체 위치·선수각 (지면 평면도, 북 위 / 동 오른쪽)
%     - 도킹 스테이션 세 곳의 Δ북 · Δ동 · 설치방향 (WP1 기준)
%     - 고른 칸 (굵은 테두리)
%     - 횡방향 속도와 횡방향 오차 (시간 그래프)
%     - 상태 — 탐지 중 / 정렬 / 진입 / 완료
%
%   읽는 토픽 — 전부 **검출 노드와 가제보가 내는 것**이다
%     /tp_dock/stations_flat  [valid locked sel  dN dE az w depth ×3]  (az: 북기준 시계방향 deg)
%     /tp_dock/status         ACCUM n/N -> DETECTED -> STABLE -> LOCKED
%     /wamv/sensors/position/ground_truth_odometry
%
%   이 창은 **Simulink 모델 밖에 있다**
%     A3_4_vrx.slx 에 콜백을 심지 않는다 — 모델을 고치지 않기 위해서다.
%     제어는 TP_dock_run 이 돌리고, 이 창은 같은 토픽을 옆에서 읽기만 한다.
%
%   유의 사항
%     - ROS_DOMAIN_ID 가 검출 노드와 같아야 한다 (기본 7)
%     - 검출 노드가 아직 LOCKED 가 아니면 칸 칸이 비어 있는 것이 정상임

    DOMAIN = 7;
    WP1    = [10.0, 0.0];      % WP1 의 월드 NED (북, 동) — 검출 노드와 같은 값
    ODOM   = '/wamv/sensors/position/ground_truth_odometry';
    TAG    = 'TP_dock_gcs';

    if nargin >= 1 && (isstring(cmd) || ischar(cmd)) && strcmpi(cmd, 'stop')
        t = timerfind('Tag', TAG);
        if ~isempty(t), stop(t); delete(t); end
        f = findobj('Type', 'figure', 'Tag', TAG);
        if ~isempty(f), delete(f); end
        setappdata(0, 'TP_dock_gcs_G', []);
        fprintf('TP_dock_gcs 닫음\n');
        return
    end

    TP_dock_gcs('stop');
    setenv('ROS_DOMAIN_ID', num2str(DOMAIN));

    G = build(WP1);
    G.node = ros2node(sprintf('/tp_dock_gcs_%d', randi(9999)), DOMAIN);
    G.s_od = ros2subscriber(G.node, ODOM, 'nav_msgs/Odometry');
    G.s_fl = ros2subscriber(G.node, '/tp_dock/stations_flat', ...
                            'std_msgs/Float32MultiArray');
    G.s_st = ros2subscriber(G.node, '/tp_dock/status', 'std_msgs/String');
    G.t0   = tic;
    G.hist = zeros(0, 3);          % [t  e_lat  v]
    setappdata(0, 'TP_dock_gcs_G', G);

    tmr = timer('Tag', TAG, 'ExecutionMode', 'fixedSpacing', 'Period', 0.2, ...
                'TimerFcn', @(~, ~) tick(), 'ErrorFcn', @(~, e) disp(e.Data.message));
    start(tmr);
    fprintf('TP_dock_gcs 시작 — 닫으려면  TP_dock_gcs(''stop'')\n');
end

% ======================================================================
function G = build(WP1)
    G.WP1 = WP1;
    G.fig = figure('Name', '해양누리 GCS — 도킹 스테이션 탐지와 순수 횡이동 진입', ...
                   'NumberTitle', 'off', 'Tag', 'TP_dock_gcs', 'Color', 'w', ...
                   'Position', [700 90 960 900], 'MenuBar', 'none', ...
                   'ToolBar', 'none');

    %% 평면도 — 북 위 / 동 오른쪽
    G.ax = axes('Parent', G.fig, 'Position', [0.09 0.45 0.86 0.50]);
    hold(G.ax, 'on'); grid(G.ax, 'on'); axis(G.ax, 'equal');
    xlabel(G.ax, '동  [m]', 'FontName', 'Malgun Gothic');
    ylabel(G.ax, '북  [m]', 'FontName', 'Malgun Gothic');
    title(G.ax, '지면 평면도 — 도킹 스테이션 셋과 선체', ...
          'FontName', 'Malgun Gothic', 'FontSize', 11);
    xlim(G.ax, [-16 16]); ylim(G.ax, [2 32]);

    plot(G.ax, WP1(2), WP1(1), 'k+', 'MarkerSize', 12, 'LineWidth', 1.5);
    text(G.ax, WP1(2) + 0.6, WP1(1), 'WP1', 'FontName', 'Malgun Gothic', ...
         'FontSize', 9, 'Color', [0.3 0.3 0.3]);

    col = [0.11 0.31 0.85; 0.05 0.58 0.53; 0.86 0.15 0.15];   % 파랑·청록·빨강
    for k = 1:3
        G.box(k)  = plot(G.ax, nan, nan, '-', 'Color', col(k, :), 'LineWidth', 1.6);
        G.arr(k)  = plot(G.ax, nan, nan, '-', 'Color', col(k, :), 'LineWidth', 2.2);
        G.lab(k)  = text(G.ax, nan, nan, '', 'Color', col(k, :), 'FontSize', 10, ...
                         'FontWeight', 'bold', 'FontName', 'Malgun Gothic', ...
                         'HorizontalAlignment', 'center');
    end
    G.col  = col;
    G.selh = plot(G.ax, nan, nan, '-', 'Color', [0.85 0.47 0.02], 'LineWidth', 3.2);
    G.trk  = plot(G.ax, nan, nan, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.8);
    G.hull = plot(G.ax, nan, nan, '-', 'Color', [0.12 0.12 0.12], 'LineWidth', 2.0);
    G.head = plot(G.ax, nan, nan, '-', 'Color', [0.85 0.47 0.02], 'LineWidth', 2.0);

    %% 상태표 — 글상자 하나 (annotation 을 쓰지 않는다. 배치가 흔들린다)
    G.axT = axes('Parent', G.fig, 'Position', [0.09 0.215 0.86 0.205], ...
                 'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off');
    G.txt = text(G.axT, 0.0, 1.0, '', 'FontName', 'Consolas', 'FontSize', 10.5, ...
                 'VerticalAlignment', 'top', 'Interpreter', 'none');

    %% 횡방향 오차·속도
    G.axE = axes('Parent', G.fig, 'Position', [0.09 0.055 0.86 0.125]);
    hold(G.axE, 'on'); grid(G.axE, 'on');
    G.pe = plot(G.axE, nan, nan, '-', 'Color', [0.86 0.15 0.15], 'LineWidth', 1.4);
    G.pv = plot(G.axE, nan, nan, '-', 'Color', [0.11 0.31 0.85], 'LineWidth', 1.4);
    legend(G.axE, {'횡방향 오차 [m]', '횡방향 속도 [m/s]'}, ...
           'FontName', 'Malgun Gothic', 'FontSize', 8, 'Location', 'northeast');
    xlabel(G.axE, '시간 [s]', 'FontName', 'Malgun Gothic');
end

% ======================================================================
function tick()
    G = getappdata(0, 'TP_dock_gcs_G');
    if isempty(G) || ~isvalid(G.fig)
        t = timerfind('Tag', 'TP_dock_gcs');
        if ~isempty(t), stop(t); delete(t); end
        return
    end

    %% 선체
    od = G.s_od.LatestMessage;
    if isempty(od), return; end
    n  = od.pose.pose.position.y;        % ENU y -> 북
    e  = od.pose.pose.position.x;        % ENU x -> 동
    q  = od.pose.pose.orientation;
    yaw_enu = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y^2 + q.z^2));
    psi = ssa(pi/2 - yaw_enu);           % NED 선수각

    %  동체 속도 — 오도메트리의 twist 는 동체 기준이다
    u = od.twist.twist.linear.x;  v = od.twist.twist.linear.y;

    %% 검출
    st = '(상태 없음)';
    if ~isempty(G.s_st.LatestMessage), st = G.s_st.LatestMessage.data; end
    S = nan(3, 5);  sel = nan;  locked = false;
    fl = G.s_fl.LatestMessage;
    if ~isempty(fl) && numel(fl.data) >= 18
        d = double(fl.data);
        locked = d(2) > 0.5;  sel = round(d(3)) + 1;
        for k = 1:3
            S(k, :) = d(3 + (k-1)*5 + (1:5));     % dN dE az[deg] 폭 깊이
        end
    end

    %% 그린다 — 칸
    for k = 1:3
        if any(isnan(S(k, :)))
            set(G.box(k), 'XData', nan, 'YData', nan);
            set(G.arr(k), 'XData', nan, 'YData', nan);
            set(G.lab(k), 'Position', [nan nan 0], 'String', '');
            continue
        end
        cn = G.WP1(1) + S(k, 1);  ce = G.WP1(2) + S(k, 2);
        az = deg2rad(S(k, 3));  wd = S(k, 4);  dp = S(k, 5);
        %  개구부 방향 az, 벽과 나란한 방향은 az+90deg
        ah = [cos(az) sin(az)];             % (북, 동) 성분
        pw = [-sin(az) cos(az)];
        hw = wd / 2;                        % 깊이는 검출값 그대로 그린다
        c1 = [cn ce] + pw*hw;          c2 = [cn ce] - pw*hw;
        c3 = c2 - ah*dp;               c4 = c1 - ah*dp;
        P = [c1; c2; c3; c4; c1];
        set(G.box(k), 'XData', P(:, 2), 'YData', P(:, 1));
        %  개구부가 향하는 방향 화살
        a0 = [cn ce];  a1 = a0 + ah*2.5;
        set(G.arr(k), 'XData', [a0(2) a1(2)], 'YData', [a0(1) a1(1)]);
        set(G.lab(k), 'Position', [ce, cn - dp/2, 0], 'String', sprintf('%d', k));
        if k == sel
            set(G.selh, 'XData', P(:, 2), 'YData', P(:, 1));
        end
    end
    if isnan(sel), set(G.selh, 'XData', nan, 'YData', nan); end

    %% 그린다 — 선체 (4.9 x 2.46 m 직사각형)
    L = 4.9; B = 2.46;
    bx = [ L/2  L/2 -L/2 -L/2  L/2];
    by = [-B/2  B/2  B/2 -B/2 -B/2];
    hn = n + bx*cos(psi) - by*sin(psi);
    he = e + bx*sin(psi) + by*cos(psi);
    set(G.hull, 'XData', he, 'YData', hn);
    set(G.head, 'XData', [e, e + 3.5*sin(psi)], 'YData', [n, n + 3.5*cos(psi)]);
    tx = get(G.trk, 'XData'); ty = get(G.trk, 'YData');
    set(G.trk, 'XData', [tx e], 'YData', [ty n]);

    %% 오차 — 고른 칸까지. 순수 횡이동이면 동체 y 로만 줄어야 한다
    e_lat = nan; e_fwd = nan; phase = '탐지 중';
    if ~isnan(sel) && ~any(isnan(S(sel, 1:2)))
        %  목표는 입구가 아니라 입구에서 inset 만큼 안쪽 — TP_dock_run 과 같은 식
        azs = deg2rad(S(sel, 3));
        ins = 3.0;
        if isfinite(S(sel, 5)) && S(sel, 5) > 0
            ins = min(3.0, max(S(sel, 5) - 2.5, 2.46/2 + 0.5));
        end
        dn = (G.WP1(1) + S(sel, 1) - ins*cos(azs)) - n;
        de = (G.WP1(2) + S(sel, 2) - ins*sin(azs)) - e;
        e_fwd = dn*cos(psi) + de*sin(psi);      % 동체 x (전후)
        e_lat = -dn*sin(psi) + de*cos(psi);     % 동체 y (횡)
        if locked
            if abs(e_fwd) > 1.0
                phase = '정렬';
            elseif abs(e_lat) > 0.8
                phase = '진입';
            elseif hypot(u, v) < 0.12
                phase = '완료';
            else
                phase = '진입';
            end
        end
    end

    %% 글상자
    L1 = sprintf('선체    북 %+8.2f m   동 %+8.2f m   선수각 %+7.1f deg', n, e, rad2deg(psi));
    L2 = sprintf('속도    전후 %+6.2f m/s   횡 %+6.2f m/s', u, v);
    L3 = sprintf('검출    %s', st);
    rows = cell(3, 1);
    for k = 1:3
        if any(isnan(S(k, :)))
            rows{k} = sprintf('  칸 %d   (아직 없음)', k);
        else
            mk = ' ';
            if k == sel, mk = '>'; end
            rows{k} = sprintf('%s 칸 %d  dN %+7.2f  dE %+7.2f  설치방향 %6.1f deg  폭 %5.2f  깊이 %5.2f m', ...
                              mk, k, S(k, 1), S(k, 2), S(k, 3), S(k, 4), S(k, 5));
        end
    end
    if isnan(e_lat)
        L4 = '오차    (고른 칸 없음)';
    else
        L4 = sprintf('오차    전후 %+6.2f m   횡 %+6.2f m        상태  [ %s ]', ...
                     e_fwd, e_lat, phase);
    end
    set(G.txt, 'String', [{L1; L2; L3; ...
        '칸 (WP1 기준 · 설치방향은 개구부가 향하는 북기준 시계방향 방위)'}; ...
        rows; {''; L4}]);

    %% 그래프
    if ~isnan(e_lat)
        G.hist = [G.hist; toc(G.t0), e_lat, v];
        if size(G.hist, 1) > 3000, G.hist = G.hist(end-2999:end, :); end
        set(G.pe, 'XData', G.hist(:, 1), 'YData', G.hist(:, 2));
        set(G.pv, 'XData', G.hist(:, 1), 'YData', G.hist(:, 3));
        xlim(G.axE, [max(0, G.hist(end, 1) - 120), max(10, G.hist(end, 1))]);
        setappdata(0, 'TP_dock_gcs_G', G);
    end
    drawnow limitrate;
end

function a = ssa(a)
    a = mod(a + pi, 2*pi) - pi;
end
