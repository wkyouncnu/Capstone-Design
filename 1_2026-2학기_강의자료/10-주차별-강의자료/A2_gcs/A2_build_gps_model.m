function dst = A2_build_gps_model(force)
%A2_BUILD_GPS_MODEL  6단 모델 `A2_gps.slx` 를 5주차 VRX 모델에서 파생시킨다
%
%   dst = A2_BUILD_GPS_MODEL        % 없으면 만든다
%   dst = A2_BUILD_GPS_MODEL(true)  % 있어도 다시 만든다
%
%   무엇을 하는가
%     1. `W05_simulink/W05_1_vrx.slx` 를 올려 이름만 바꿔 `A2_gps.slx` 로 저장
%     2. 지상참값(odometry) 이 내던 위치 태그 x_n·y_n 을 x_true·y_true 로 바꾼다
%        — 참값은 **비교용**으로만 남긴다
%     3. GPS 구독 상자를 새로 넣고, 그 출력이 x_n·y_n 태그를 맡는다
%        -> 유도·제어가 보는 위치가 odometry 에서 **GPS** 로 바뀐다
%     4. 로깅에 x_true·y_true·z_n 세 줄을 더한다 (오차를 숫자로 보려면 둘 다 필요)
%     5. Animate 의 그림 함수를 `W05_animate` -> `A2_animate_map` 으로 바꾼다
%     6. InitFcn 을 걸어 실시간 창을 **첫 스텝 전에** 만들어 둔다
%
%   왜 모델을 새로 그리지 않는가
%     유도·제어·추진기·추력배분은 5주차에서 검증한 것이다. 6단에서 바뀌는 자리는
%     "위치를 어디서 받는가" 한 군데뿐이다. 그래서 결과가 이상하면 의심할 곳이
%     한 군데로 좁혀진다
%
%   왜 창을 InitFcn 에서 만드는가
%     첫 스텝 안에서 창을 만들면 그림이 뜨는 몇 초 동안 모델이 멎는다. 그 사이
%     가제보는 직전 추력 명령을 그대로 쥐고 있으므로 배는 계속 간다. 6주차 4단에서
%     이것 때문에 모델 시간 0.4 s 사이에 배가 9.4 m 를 갔다 ([[W06_model_init]])
%
%   되돌리는 법
%     >> A2_build_gps_model(true)

    if nargin < 1, force = false; end

    here = fileparts(mfilename('fullpath'));
    w05  = fullfile(fileparts(here), 'W05_simulink');
    src  = fullfile(w05, 'W05_1_vrx.slx');
    dst  = fullfile(here, 'A2_gps.slx');

    tools = fullfile(fileparts(fileparts(here)), '_tools');
    if isfolder(tools), addpath(tools); end

    if ~isfile(src)
        error('A2:nosrc', '5주차 VRX 모델을 찾지 못했다 : %s', src);
    end
    if isfile(dst) && ~force
        fprintf('A2_gps.slx 이미 있음 — 다시 만들려면 A2_build_gps_model(true)\n');
        return
    end

    SRC = 'W05_1_vrx';
    DST = 'A2_gps';

    % --- 열려 있는 모델 정리 — 저장 안 한 변경을 말없이 버리지 않는다 ----
    for nm = {DST, SRC}
        if bdIsLoaded(nm{1})
            if strcmp(get_param(nm{1}, 'Dirty'), 'on')
                error('A2:dirty', ...
                      '%s 에 저장하지 않은 변경이 있다. 먼저 저장하거나 닫을 것', nm{1});
            end
            close_system(nm{1}, 0);
        end
    end

    % --- 1. 올리고 이름만 바꿔 저장 ----------------------------------
    fprintf('5주차 VRX 모델을 올린다 : %s\n', src);
    load_system(src);
    save_system(SRC, dst);
    if bdIsLoaded(DST), m = DST; else, m = SRC; end

    % --- 2. 참값 태그 이름 바꾸기 ------------------------------------
    %  순서가 중요하다. 먼저 바꾸지 않고 GPS 쪽 Goto 를 먼저 넣으면
    %  같은 태그 x_n 이 두 개가 되어 Simulink 가 거부한다
    geo = get_param([m '/Go_x_n'], 'Position');     % 크기를 그대로 베낀다
    gw  = geo(3) - geo(1);
    gh  = geo(4) - geo(2);
    rename_goto(m, 'Go_x_n', 'Go_x_true', 'x_true');
    rename_goto(m, 'Go_y_n', 'Go_y_true', 'y_true');

    % --- 3. GPS 구독 상자 --------------------------------------------
    s = add_gps_subscriber(m, [760 568], ...
                           '/wamv/sensors/gps/gps/fix', 'Ts_ctrl');

    %  GPS 가 내는 위치가 이제 x_n · y_n 이다
    tag = {'x_n', 'y_n', 'z_n'};
    for k = 1:3
        q  = port_xy(m, 'GpsSubscriber', 'Outport', k);
        nb = [m '/Go_' tag{k}];
        add_block('simulink/Signal Routing/Goto', nb, ...
                  'Position', [1000 q(2)-gh/2 1000+gw q(2)+gh/2], ...
                  'GotoTag', tag{k}, 'TagVisibility', 'global');
        add_line(m, sprintf('GpsSubscriber/%d', k), ['Go_' tag{k} '/1'], ...
                 'autorouting', 'off');
    end
    fprintf('GPS 구독 상자를 넣었다 : %s\n', s);

    % --- 4. 로깅 세 줄 추가 ------------------------------------------
    add_log_rows(m, {'x_true', 'y_true', 'z_n'});

    % --- 5. 그림 함수 교체 -------------------------------------------
    charts = sfroot().find('-isa', 'Stateflow.EMChart');
    hit    = 0;
    for k = 1:numel(charts)
        p = charts(k).Path;
        if contains(p, [m '/Animate'])
            sc = charts(k).Script;
            if contains(sc, 'W05_animate')
                charts(k).Script = strrep(sc, 'W05_animate', 'A2_animate_map');
                hit = hit + 1;
                fprintf('그림 함수 교체 : %s\n', p);
            end
        end
    end
    if hit ~= 1
        error('A2:animate', ...
              'Animate 블록의 그림 함수를 %d 군데 바꿨다 (1 이어야 한다)', hit);
    end

    nt = find_system(m, 'SearchDepth', 2, 'FindAll', 'on', 'type', 'annotation');
    for k = 1:numel(nt)
        txt = get_param(nt(k), 'Text');
        if contains(txt, 'W05_animate')
            set_param(nt(k), 'Text', strrep(txt, 'W05_animate', 'A2_animate_map'));
        end
    end

    % --- 6. InitFcn — 창을 첫 스텝 전에 만든다 -----------------------
    init = sprintf(['if ~exist(''A2_6_prep'',''file''), ' ...
                    'addpath(fileparts(get_param(''%s'',''FileName''))); end, ' ...
                    'A2_6_prep(''%s'')'], DST, DST);
    set_param(m, 'InitFcn', init);

    % --- 설명 메모 ----------------------------------------------------
    add_block('built-in/Note', [m '/note_gps'], 'Position', [760 760], 'Text', sprintf([ ...
        '6단 — 위치를 GPS 에서 받는다.\n' ...
        '  x_n · y_n  : GpsSubscriber (위경도 -> 평면좌표).  유도·제어가 쓰는 값\n' ...
        '  x_true · y_true : PoseSubscriber (가제보 지상참값).  **비교용으로만** 쓴다\n' ...
        '  psi · u · r · beta · chi · U 는 그대로 지상참값에서 온다 —\n' ...
        '  한 번에 한 가지만 바꾼다 (헤딩까지 센서로 바꾸는 것은 과제 A2-6)']));

    % --- 저장 ---------------------------------------------------------
    save_system(m, dst);
    close_system(m, 0);
    fprintf('만들었다 : %s\n', dst);
end

% =====================================================================
function rename_goto(m, old, new, tag)
%RENAME_GOTO  Goto 블록의 태그와 이름을 함께 바꾼다. 들어오는 선은 그대로 남는다
    b = [m '/' old];
    if ~getSimulinkBlockHandle(b)
        error('A2:nogoto', '%s 를 찾지 못했다', b);
    end
    set_param(b, 'GotoTag', tag);
    set_param(b, 'Name', new);
    fprintf('태그 교체 : %s -> %s (tag %s)\n', old, new, tag);
end

% =====================================================================
function add_log_rows(m, tags)
%ADD_LOG_ROWS  기존 Logging 상자 아래에 From -> To Workspace 한 쌍씩 더한다
%   원래 상자의 격자(60 px 간격, From x=100, To x=260)를 그대로 따른다
    s  = [m '/Logging'];
    fr = find_system(s, 'SearchDepth', 1, 'BlockType', 'From');
    y  = 0;
    for k = 1:numel(fr)
        p = get_param(fr{k}, 'Position');
        y = max(y, p(2));
    end
    %  설명 메모는 맨 아래 줄 밑에 있다. 줄을 더하면 그 자리를 뺏으므로
    %  더할 줄 수만큼 메모를 먼저 내려 보낸다 (check_lines 의 블록겹침)
    an = find_system(s, 'FindAll', 'on', 'SearchDepth', 1, 'type', 'annotation');
    for k = 1:numel(an)
        p = get_param(an(k), 'Position');
        d = 60*numel(tags);
        if numel(p) == 4 && p(2) > y - 60
            set_param(an(k), 'Position', p + [0 d 0 d]);
        elseif numel(p) == 2 && p(2) > y - 60
            set_param(an(k), 'Position', p + [0 d]);
        end
    end
    for k = 1:numel(tags)
        yk = y + 60*k;
        fb = [s '/Fr_' tags{k}];
        add_block('simulink/Signal Routing/From', fb, ...
                  'Position', [100 yk-11 170 yk+11], 'GotoTag', tags{k});
        wb = [s '/log_' tags{k}];
        add_block('simulink/Sinks/To Workspace', wb, ...
                  'Position', [260 yk-15 320 yk+15]);
        set_param(wb, 'VariableName', ['log_' tags{k}], ...
                      'SaveFormat', 'Timeseries', 'SampleTime', 'Ts_ctrl');
        add_line(s, ['Fr_' tags{k} '/1'], ['log_' tags{k} '/1']);
        fprintf('로깅 추가 : log_%s\n', tags{k});
    end
end

% =====================================================================
function s = add_gps_subscriber(m, pos, topic, ts)
%ADD_GPS_SUBSCRIBER  NavSatFix 를 받아 기준점 기준 평면좌표로 바꾸는 상자
%
%   안에 들어가는 것 (5주차 PoseSubscriber 와 같은 짜임새)
%     Subscribe      토픽에서 sensor_msgs/NavSatFix 를 받는다
%     IsNew(Display) 새 메시지가 왔는지 눈으로 본다. 0 에서 안 바뀌면 토픽이 안 온다
%     Bus Selector   세 필드만 꺼낸다 — latitude, longitude, altitude
%     NavGps         A2_ex5 의 flat-earth 식. 기준점은 상수 두 개로 받는다

    outs = {'x_n', 'y_n', 'z_n'};
    s = add_subsys(m, 'GpsSubscriber', ...
                   [pos(1) pos(2) pos(1)+170 pos(2)+140], {}, outs, ...
                   gnc_colour('ros'));

    add_block('ros2lib/Subscribe', [s '/GpsSub'], 'Position', [80 220 210 280]);
    set_param([s '/GpsSub'], 'topicSource', 'Specify your own', ...
        'topic', topic, 'messageType', 'sensor_msgs/NavSatFix', 'sampleTime', ts);

    add_block('simulink/Sinks/Display', [s '/IsNew'], 'Position', [300 120 380 150]);

    add_block('simulink/Signal Routing/Bus Selector', [s '/Sel'], ...
              'Position', [300 200 350 360]);
    set_param([s '/Sel'], 'OutputSignals', 'latitude,longitude,altitude');

    %  입력 5 개 — 52 px 간격을 쓰려면 키가 52*(5-1)+40 = 248 px 이상이어야
    %  lat0 · lon0 두 Constant 사이에 이름표 자리가 남는다 (row_feed 의 권고)
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [s '/NavGps'], 'Position', [520 180 700 440]);
    ch = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', [s '/NavGps']);
    ch.Script = nav_gps_code();
    set_param([s '/NavGps'], 'Position', [520 180 700 440]);

    %  Bus Selector 의 세 출력을 NavGps 의 1~3 번 입력 높이에 정확히 맞춘다
    a = port_xy(s, 'NavGps', 'Inport', 1);
    b = port_xy(s, 'NavGps', 'Inport', 3);
    fit_span(s, 'Sel', 'Outport', a(2), b(2));

    align_to(s, 'GpsSub', 'Outport', port_xy(s, 'Sel', 'Inport', 1), 2);
    q  = get_param([s '/Sel'], 'Position');
    yN = q(2) - 50;
    set_param([s '/IsNew'], 'Position', [300 yN-15 380 yN+15]);
    align_to(s, 'IsNew', 'Inport', yN);
    p1  = port_xy(s, 'GpsSub', 'Outport', 1);
    pn  = port_xy(s, 'IsNew', 'Inport', 1);
    po  = get_param([s '/GpsSub'], 'PortHandles');
    pd  = get_param([s '/IsNew'],  'PortHandles');
    pd2 = get_param([s '/Sel'],    'PortHandles');
    draw_line(s, po.Outport(1), pd.Inport(1), ...
              [p1; p1(1)+30 p1(2); p1(1)+30 pn(2); pn]);
    draw_line(s, po.Outport(2), pd2.Inport(1));

    %  기준점은 신호가 아니라 설정이다. 상자 안에 둔다
    add_block('simulink/Sources/Constant', [s '/lat0'], ...
              'Position', [390 300 465 330], 'Value', 'lla0(1)');
    add_block('simulink/Sources/Constant', [s '/lon0'], ...
              'Position', [390 350 465 380], 'Value', 'lla0(2)');

    for k = 1:3
        add_line(s, sprintf('Sel/%d', k), sprintf('NavGps/%d', k));
    end
    row_feed(s, 'NavGps', {'', '', '', 'lat0', 'lon0'});

    for k = 1:numel(outs)
        q = port_xy(s, 'NavGps', 'Outport', k);
        set_param([s '/' outs{k}], 'Position', [820 q(2)-7 850 q(2)+7]);
        add_line(s, sprintf('NavGps/%d', k), [outs{k} '/1']);
    end

    add_block('built-in/Note', [s '/note'], 'Position', [80 520], 'Text', sprintf([ ...
        'GPS 항법 — 위경도를 기준점 기준 평면좌표로 바꾼다.\n' ...
        '  토픽 %s   (sensor_msgs/NavSatFix, 약 20 Hz)\n' ...
        '\n' ...
        '변환식은 A2 1부 예제 5 (A2_ex5_flat_formula.m) 와 글자 그대로 같다.\n' ...
        'lla2ned 를 부르지 않고 식을 펼쳐 쓴 것은 이 블록이 코드 생성 대상이기\n' ...
        '때문이다 — 툴박스 함수는 그 안에서 못 부른다.\n' ...
        '\n' ...
        'NavGps 첫머리의 가드가 없으면, 첫 메시지 전에 Subscribe 가 내는 0 버스를\n' ...
        '그대로 변환해 "위도 0도 적도" 에서 온 것으로 읽고 위치가 수천 km 튄다.'], topic));
end

% =====================================================================
function c = nav_gps_code()
%NAV_GPS_CODE  MATLAB Function 블록에 들어가는 글. A2_ex5 의 식 그대로다
    L = { ...
    'function [x_n, y_n, z_n] = NavGps(lat, lon, alt, lat0, lon0)'
    '%#codegen'
    '%  GPS 위경도 -> 기준점 기준 평면좌표 (A2 1부 예제 5 의 flat-earth 식)'
    '%'
    '%  가드 — 첫 메시지가 오기 전에 Subscribe 는 0 으로 채운 버스를 낸다.'
    '%  그것을 그대로 변환하면 "위도 0도, 경도 0도" (기니만) 에서 온 것으로'
    '%  읽혀 위치가 수천 km 튄다. 5주차 PoseSubscriber 의 가드와 같은 이유다'
    'if lat == 0 && lon == 0'
    '    x_n = 0;  y_n = 0;  z_n = 0;'
    '    return'
    'end'
    ''
    'a  = 6378137.0;              % WGS84 장반경 [m]'
    'f  = 1.0/298.257223563;      % 편평률'
    'e2 = 2.0*f - f*f;            % 제1 이심률의 제곱'
    ''
    '%  곡률반경은 기준점 위도에서 **한 번** 구한다 — flat-earth 근사의 뜻이다'
    's2  = sind(lat0)^2;'
    'R_N = a / sqrt(1 - e2*s2);                 % 묘유선 (동-서)'
    'R_M = R_N * (1 - e2) / (1 - e2*s2);        % 자오선 (남-북)'
    ''
    'x_n = (lat - lat0) / atan2d(1, R_M);                % 북'
    'y_n = (lon - lon0) / atan2d(1, R_N*cosd(lat0));     % 동'
    'z_n = -alt;                                         % 아래가 +'
    };
    c = strjoin(L, newline);
end
