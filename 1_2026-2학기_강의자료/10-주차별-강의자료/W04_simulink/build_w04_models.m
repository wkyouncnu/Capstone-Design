function build_w04_models()
% BUILD_W04_MODELS  4주차 토픽 조사 Simulink 모델 2개를 생성한다.
%
%     W04_1_sensor_rates.slx   1단계 — 센서 세 개를 동시에 받아 수신 주기를 잰다 (VRX 필요)
%     W04_2_qos_test.slx       2단계 — 같은 토픽을 QoS 만 달리해 두 번 받는다 (VRX 불필요)
%
%   무엇을 확인하는 모델인가
%     1단계 — `ros2 topic hz` 로 잰 값과 Simulink 가 센 값이 같은지.
%             둘 다 벽시계 기준이므로 RTF 가 낮으면 함께 낮아진다 (§2-3-7)
%     2단계 — 발행자가 BEST_EFFORT 일 때, RELIABLE 로 구독하면 **한 건도 오지 않는다**.
%             토픽 목록에는 그대로 보인다 (2주차 §2-9 와 같은 실패)
%
%   최상위 구성
%     1단계  SensorSubscriber -> RateMeter -> Display · Logging
%     2단계  QosSubscribers   -> RxCount   -> Display · Logging
%
%   실행 전에 반드시 >> W04_setup 을 먼저 실행할 것.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''hz_design_imu'',''var'')')
        error('먼저 W04_setup 을 실행하십시오.');
    end

    build_sensor_rates();
    build_qos_test();

    slxList = dir('W04_*.slx');
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try

            tidy_model(mName);

            paint_roles(mName);        % 역할표는 _tools/gnc_roles.m 하나뿐이다

            check_colour(mName);

            export_model_pngs(mName);

        catch e, warning(e.message); end
    end
    fprintf('\n완료. 생성된 모델:\n');
    for k = 1:numel(slxList), fprintf('  %s\n', slxList(k).name); end
end

% =====================================================================
% 공통 헬퍼 (W02 · W03 과 같다)
% =====================================================================
function fresh(m)
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end

function setSolver(m, stopTime)
    set_param(m, 'SolverType','Fixed-step', 'SolverName','FixedStepDiscrete', ...
                 'FixedStep','Ts', 'StopTime',stopTime, 'SimulationMode','normal');
end

function addFcn(sys, name, pos, code)
    add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/' name], 'Position', pos);
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[sys '/' name]);
    ch.Script = code;
end

function F(sys, tag, sfx, x, y)
    add_block('simulink/Signal Routing/From', [sys '/Fr_' tag '_' sfx], ...
              'Position', [x y x+70 y+25], 'GotoTag', tag);
end

function G(sys, tag, x, y)
    add_block('simulink/Signal Routing/Goto', [sys '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

function note(sys, tag, txt, x, y)
    add_block('built-in/Note', [sys '/' tag], 'Position',[x y x y], 'Text', txt);
end

function L(sys, src, dst)
    add_line(sys, src, dst, 'autorouting','on');
end

function ss = newSub(m, name, pos)
    ss = [m '/' name];
    add_block('simulink/Ports & Subsystems/Subsystem', ss, 'Position', pos);
    delete_line(ss, 'In1/1', 'Out1/1');
    delete_block([ss '/In1']);
    delete_block([ss '/Out1']);
end

function inP(ss, name, k)
    y = 40 + (k-1)*60;
    add_block('simulink/Sources/In1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [20 y 50 y+14]);
end

function outP(ss, name, k)
    y = 40 + (k-1)*60;
    add_block('simulink/Sinks/Out1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [900 y 930 y+14]);
end

function addSubscriber(sys, name, topic, msgType, x, y)
    add_block('ros2lib/Subscribe', [sys '/' name], 'Position',[x y x+130 y+60]);
    set_param([sys '/' name], 'topicSource','Specify your own', ...
        'topic', topic, 'messageType', msgType, 'sampleTime','Ts');
end

function addLogging(m, pos, sig)
    ss = newSub(m, 'Logging', pos);
    for k = 1:numel(sig)
        yy = 40 + (k-1)*55;
        F(ss, sig{k}, 'log', 50, yy+3);
        b = [ss '/log_' sig{k}];
        add_block('simulink/Sinks/To Workspace', b, 'Position', [200 yy 300 yy+30]);
        set_param(b, 'VariableName', ['log_' sig{k}], ...
                     'SaveFormat','Timeseries', 'SampleTime','Ts');
        L(ss, ['Fr_' sig{k} '_log/1'], ['log_' sig{k} '/1']);
    end
end

% =====================================================================
% 1단계 — 센서 세 개의 수신 주기
% =====================================================================
function build_sensor_rates()
    m = 'W04_1_sensor_rates'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');   % 벽시계로 센다

    % --- 구독 서브시스템 -------------------------------------------------
    ss = newSub(m, 'SensorSubscriber', [250 100 420 320]);
    outs = {'gps_new','imu_new','wind_new','lat','wz','wind'};
    for k = 1:numel(outs), outP(ss, outs{k}, k); end

    addSubscriber(ss, 'GpsSub',  '/wamv/sensors/gps/gps/fix',  'sensor_msgs/NavSatFix', 50,  60);
    addSubscriber(ss, 'ImuSub',  '/wamv/sensors/imu/imu/data', 'sensor_msgs/Imu',       50, 240);
    addSubscriber(ss, 'WindSub', '/vrx/debug/wind/speed',      'std_msgs/Float32',      50, 420);

    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelGps'], 'Position',[250 60 300 120]);
    set_param([ss '/SelGps'], 'OutputSignals', 'latitude');
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelImu'], 'Position',[250 240 300 300]);
    set_param([ss '/SelImu'], 'OutputSignals', 'angular_velocity.z');
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelWind'], 'Position',[250 420 300 480]);
    set_param([ss '/SelWind'], 'OutputSignals', 'data');

    L(ss,'GpsSub/1','gps_new/1');
    L(ss,'ImuSub/1','imu_new/1');
    L(ss,'WindSub/1','wind_new/1');
    L(ss,'GpsSub/2','SelGps/1');   L(ss,'SelGps/1','lat/1');
    L(ss,'ImuSub/2','SelImu/1');   L(ss,'SelImu/1','wz/1');
    L(ss,'WindSub/2','SelWind/1'); L(ss,'SelWind/1','wind/1');

    % --- 주기 계산 서브시스템 --------------------------------------------
    rs = newSub(m, 'RateMeter', [650 100 820 320]);
    ins = {'gps_new','imu_new','wind_new','t'};
    for k = 1:numel(ins), inP(rs, ins{k}, k); end
    outs2 = {'hz_gps','hz_imu','hz_wind','n_gps','n_imu','n_wind'};
    for k = 1:numel(outs2), outP(rs, outs2{k}, k); end

    addFcn(rs, 'CountRate', [300 40 520 420], [ ...
'function [hz_gps, hz_imu, hz_wind, n_gps, n_imu, n_wind] = CountRate(gps_new, imu_new, wind_new, t)' newline ...
'%#codegen'                                                                     newline ...
'% Count how many messages arrived and divide by elapsed time.'                 newline ...
'% This is what `ros2 topic hz` does, on the same wall clock.'                  newline ...
'persistent cg ci cw'                                                           newline ...
'if isempty(cg), cg = 0; ci = 0; cw = 0; end'                                   newline ...
'if gps_new,  cg = cg + 1; end'                                                 newline ...
'if imu_new,  ci = ci + 1; end'                                                 newline ...
'if wind_new, cw = cw + 1; end'                                                 newline ...
''                                                                              newline ...
'n_gps = cg;  n_imu = ci;  n_wind = cw;'                                        newline ...
'if t > 0'                                                                      newline ...
'    hz_gps = cg/t;  hz_imu = ci/t;  hz_wind = cw/t;'                           newline ...
'else'                                                                          newline ...
'    hz_gps = 0;     hz_imu = 0;     hz_wind = 0;'                              newline ...
'end']);
    for k = 1:4, L(rs, [ins{k} '/1'], sprintf('CountRate/%d',k)); end
    for k = 1:6, L(rs, sprintf('CountRate/%d',k), [outs2{k} '/1']); end

    % --- 최상위 배선 -----------------------------------------------------
    add_block('simulink/Sources/Digital Clock', [m '/Clk'], ...
              'Position', [470 380 520 410], 'SampleTime','Ts');
    for k = 1:3, L(m, sprintf('SensorSubscriber/%d',k), sprintf('RateMeter/%d',k)); end
    L(m, 'Clk/1', 'RateMeter/4');

    % 화면 표시 — 수업 중에는 이 숫자를 본다
    disp_names = {'Hz_GPS','Hz_IMU','Hz_wind','N_GPS','N_IMU','N_wind'};
    for k = 1:6
        b = [m '/' disp_names{k}];
        add_block('simulink/Sinks/Display', b, 'Position',[1000 100+(k-1)*60 1120 130+(k-1)*60]);
        L(m, sprintf('RateMeter/%d',k), [disp_names{k} '/1']);
    end

    % 로깅 태그 — 값도 함께 남긴다
    tag = {'hz_gps','hz_imu','hz_wind'};
    for k = 1:3
        G(m, tag{k}, 1000, 500+(k-1)*50);
        L(m, sprintf('RateMeter/%d',k), ['Go_' tag{k} '/1']);
    end
    val = {'lat','wz','wind'};
    for k = 1:3
        G(m, val{k}, 470, 500+(k-1)*50);
        L(m, sprintf('SensorSubscriber/%d',k+3), ['Go_' val{k} '/1']);
    end
    addLogging(m, [650 500 820 600], [tag val]);

    note(m,'n1', ['W04 1단계  —  센서 세 개의 수신 주기를 Simulink 로 잰다 (VRX 필요)' newline ...
        'SensorSubscriber -> RateMeter -> 화면 표시.  IsNew 를 세어 경과시간으로 나눈 값이다' newline ...
        '같은 시간에 터미널에서 ros2 topic hz 를 돌려 두 값을 비교한다' newline ...
        '실행 전: (1) VRX 기동  (2) W04_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 2단계 — QoS 를 어긋나게 해 본다 (VRX 불필요)
% =====================================================================
function build_qos_test()
    m = 'W04_2_qos_test'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    ss = newSub(m, 'QosSubscribers', [250 100 420 300]);
    outP(ss, 'rel_new', 1);
    outP(ss, 'be_new',  2);

    % 같은 토픽을 두 번 구독한다. 다른 것은 Reliability 하나뿐이다
    addSubscriber(ss, 'SubReliable',   '/qos_topic', 'std_msgs/String', 50,  60);
    set_param([ss '/SubReliable'],   'QOSReliability','Reliable');
    addSubscriber(ss, 'SubBestEffort', '/qos_topic', 'std_msgs/String', 50, 240);
    set_param([ss '/SubBestEffort'], 'QOSReliability','Best effort');

    add_block('simulink/Sinks/Terminator', [ss '/RelMsgEnd'], 'Position',[250 100 270 120]);
    add_block('simulink/Sinks/Terminator', [ss '/BeMsgEnd'],  'Position',[250 280 270 300]);
    L(ss,'SubReliable/2','RelMsgEnd/1');
    L(ss,'SubBestEffort/2','BeMsgEnd/1');
    L(ss,'SubReliable/1','rel_new/1');
    L(ss,'SubBestEffort/1','be_new/1');

    cs = newSub(m, 'RxCount', [650 100 820 300]);
    inP(cs, 'rel_new', 1);
    inP(cs, 'be_new',  2);
    outP(cs, 'n_reliable', 1);
    outP(cs, 'n_besteffort', 2);
    addFcn(cs, 'Counter', [300 40 500 200], [ ...
'function [n_rel, n_be] = Counter(rel_new, be_new)'                             newline ...
'%#codegen'                                                                     newline ...
'% Count messages received by each subscriber.'                                 newline ...
'% Publisher (qos_test_pub) is BEST_EFFORT, so a RELIABLE subscriber'           newline ...
'% is incompatible and receives nothing at all.'                                newline ...
'persistent nr nb'                                                              newline ...
'if isempty(nr), nr = 0; nb = 0; end'                                           newline ...
'if rel_new, nr = nr + 1; end'                                                  newline ...
'if be_new,  nb = nb + 1; end'                                                  newline ...
'n_rel = nr;  n_be = nb;']);
    L(cs,'rel_new/1','Counter/1');
    L(cs,'be_new/1','Counter/2');
    L(cs,'Counter/1','n_reliable/1');
    L(cs,'Counter/2','n_besteffort/1');

    L(m,'QosSubscribers/1','RxCount/1');
    L(m,'QosSubscribers/2','RxCount/2');

    add_block('simulink/Sinks/Display', [m '/N_RELIABLE'],   'Position',[1000 120 1140 150]);
    add_block('simulink/Sinks/Display', [m '/N_BEST_EFFORT'],'Position',[1000 220 1140 250]);
    L(m,'RxCount/1','N_RELIABLE/1');
    L(m,'RxCount/2','N_BEST_EFFORT/1');

    G(m,'n_reliable',   1000, 340);
    G(m,'n_besteffort', 1000, 400);
    L(m,'RxCount/1','Go_n_reliable/1');
    L(m,'RxCount/2','Go_n_besteffort/1');
    addLogging(m, [650 400 820 500], {'n_reliable','n_besteffort'});

    note(m,'n1', ['W04 2단계  —  QoS 불일치를 Simulink 에서 재현한다 (VRX 불필요)' newline ...
        '같은 토픽 /qos_topic 을 Reliable 과 Best effort 로 각각 구독한다.' newline ...
        '발행자(usv_basics qos_test_pub)가 BEST_EFFORT 이므로 Reliable 쪽은 0 건이다.' newline ...
        '실행 전: (1) ros2 run usv_basics qos_test_pub  (2) W04_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end
