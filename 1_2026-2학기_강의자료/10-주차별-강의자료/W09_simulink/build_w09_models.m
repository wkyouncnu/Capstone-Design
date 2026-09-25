function build_w09_models()
% BUILD_W09_MODELS  9주차 토픽 조사 Simulink 모델 3개를 생성한다.
%
%     W09_0_offline.slx        0단계 — 운동모델에 GPS · IMU 센서 모델을 붙여 같은 주기를 잰다 (VRX 불필요)
%     W09_1_sensor_rates.slx   1단계 — 센서 세 개를 동시에 받아 수신 주기를 잰다 (VRX 필요)
%     W09_2_qos_test.slx       2단계 — 같은 토픽을 QoS 만 달리해 두 번 받는다 (VRX 불필요)
%
%   무엇을 확인하는 모델인가
%     1단계 — `ros2 topic hz` 로 잰 값과 Simulink 가 센 값이 같은지.
%             둘 다 벽시계 기준이므로 RTF 가 낮으면 함께 낮아진다 (§2-3-7)
%     2단계 — 발행자가 BEST_EFFORT 일 때, RELIABLE 로 구독하면 **한 건도 오지 않는다**.
%             토픽 목록에는 그대로 보인다 (2주차 §2-9 와 같은 실패)
%
%   최상위 구성
%     0단계  Command -> MotionModel -> SensorModel      -> RateMeter -> Display · Logging
%     1단계                            SensorSubscriber -> RateMeter -> Display · Logging
%     0단계와 1단계는 RateMeter 뒤가 같다. SensorModel 이 VRX 의 센서 자리를 대신한다
%     2단계  QosSubscribers   -> RxCount   -> Display · Logging
%
%   실행 전에 반드시 >> W09_setup 을 먼저 실행할 것.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''hz_design_imu'',''var'')')
        error('먼저 W09_setup 을 실행하십시오.');
    end

    build_offline();
    build_sensor_rates();
    build_qos_test();

    slxList = dir('W09_*.slx');
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try

            tidy_model(mName);

            %  입출력이 많은 서브시스템은 미리보기의 안쪽 포트 이름이 겉 포트 이름과
            %  겹쳐 읽히지 않는다 (W09_2 의 rel_new/be_new). 그런 상자만 미리보기를 끈다
            load_system(mName);
            for nm = {'QosSubscribers','RxCount','SensorSubscriber','SensorModel','RateMeter'}
                b = [mName '/' nm{1}];
                if getSimulinkBlockHandle(b) > 0, set_param(b, 'ContentPreviewEnabled','off'); end
            end
            save_system(mName);  close_system(mName, 0);

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
    fpos = get_param([sys '/' name], 'Position');   % 포트가 생기며 블록이 멋대로 자란다
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[sys '/' name]);
    ch.Script = code;
    set_param([sys '/' name], 'Position', fpos);    % 다시 놓아야 포트 위치가 저장 뒤와 같아진다 (사선 방지)
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

% =====================================================================
% 실시간 화면 — 0단계와 1단계가 같은 함수(W09_animate.m)를 쓴다
%
%   스킬 규칙 26. 9주차는 제어 주차가 아니므로 "지령 대비 응답" 대신
%   **센서가 제대로 오고 있는가**를 네 칸에 그린다 (W09_animate 머리말).
%
%   >>> 태그 순서가 곧 W09_animate 의 인자 순서다 <<<
%
%       lat  lon  qz  qw  wz  hz_gps  hz_imu  [x_n_true  y_n_true  r_true]  + t + en
%
%   From 을 더하거나 빼면 AnimateFcn 의 인자 순서도 같이 바뀐다. 아래 tags
%   한 줄이 그 계약이고, add_animate_box 가 그 순서대로 포트를 만든다.
%
%   **새 신호를 만들지 않았다.** 전부 빌더가 이미 걸어 둔 Goto 태그다 —
%   `lat`·`wz` 는 최상위, `lon`·`qz`·`qw` 는 센서 상자 안(전역 태그),
%   `*_true` 는 `MotionModel` 안. VRX 모델에는 참값 태그가 아예 없으므로
%   AnimateFcn 이 NaN 을 넣어 부르고, W09_animate 가 그 칸을 바꿔 그린다.
%
%   왜 Ts 인가 (add_animate_box 의 기본 0.05 를 쓰지 않는 이유)
%     Animate 상자를 0.05 s 로 두면 모델에 이산 주기가 둘 생긴다. 1단계는
%     고정스텝 이산 솔버라 그 순간 multitasking 이 되고 Rate Transition
%     블록을 요구하며 컴파일이 멈춘다. 0단계는 반대로 상속이 연속이 되어
%     마이너 스텝마다 불린다. 두 모델 모두 Ts 하나로 못박는다 —
%     그리는 횟수는 animate_every 가 줄인다.
% =====================================================================
function addW09Animate(m, x, y, hasTruth)
    tags = {'lat','lon','qz','qw','wz','hz_gps','hz_imu'};
    if hasTruth
        tags = [tags, {'x_n_true','y_n_true','r_true'}];
        aT = 'x_n_true, y_n_true, r_true';
    else
        aT = 'NaN, NaN, NaN';
    end

    code = [ ...
    sprintf('function ok = AnimateFcn(%s, t, en)', strjoin(tags, ', '))           newline ...
    '%#codegen'                                                                   newline ...
    '% 실시간 그림. MATLAB Function 블록은 그림을 그리지 못하므로 그리는 함수를'    newline ...
    '% extrinsic 으로 선언한다 — 코드를 만들지 않고 평범한 MATLAB 을 부른다.'       newline ...
    '% en = base workspace 의 animate (0 이면 그리지 않는다).'                      newline ...
    'coder.extrinsic(''W09_animate'');'                                           newline ...
    'ok = 1;'                                                                     newline ...
    'if en > 0.5'                                                                 newline ...
    sprintf('    W09_animate(lat, lon, qz, qw, wz, hz_gps, hz_imu, %s, t);', aT)  newline ...
    'end'];

    s = add_animate_box(m, tags, 'W09_animate', code, [x y], 'Ts');

    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[s '/AnimateFcn']);
    ch.ChartUpdate = 'DISCRETE';
    ch.SampleTime  = 'Ts';
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
% 0단계 — 운동모델 + 센서 모델 (VRX 불필요)
%   Command     : 좌·우 추력 상수 (W09_setup 의 thrust_left, thrust_right)
%   MotionModel : 3주차 1-8 절의 운동방정식 — W03_0_offline 과 같은 EOM 코드
%   SensorModel : GPS (20 Hz, 안테나 위치 반영) · IMU (100 Hz, 자이로 잡음)
%                 출력 여섯 개가 1단계 SensorSubscriber 와 순서·이름이 같다
%   RateMeter 뒤는 1단계와 같은 함수로 만든다
% =====================================================================
function build_offline()
    m = 'W09_0_offline'; fresh(m);
    % 연속 적분기가 있으므로 ode4. 스텝은 1단계와 같은 Ts (200 Hz)
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts', 'StopTime','T_end', 'SimulationMode','normal');

    % --- 추력 명령 -------------------------------------------------------
    cs = newSub(m, 'Command', [0 100 170 220]);
    outP(cs, 'FL', 1);  outP(cs, 'FR', 2);
    add_block('simulink/Sources/Constant', [cs '/CmdL'], 'Position',[300 35 400 65], 'Value','thrust_left');
    add_block('simulink/Sources/Constant', [cs '/CmdR'], 'Position',[300 95 400 125], 'Value','thrust_right');
    L(cs,'CmdL/1','FL/1');  L(cs,'CmdR/1','FR/1');

    % --- 운동모델 (W03_0_offline 과 같은 EOM) ---------------------------
    ms = newSub(m, 'MotionModel', [250 100 420 320]);
    inP(ms, 'FL', 1);  inP(ms, 'FR', 2);
    outs = {'x_n','y_n','psi','r'};
    for k = 1:numel(outs), outP(ms, outs{k}, k); end
    add_block('simulink/Sources/Constant', [ms '/p'], 'Position', [60 200 200 230], ...
              'Value', '[m_usv; Izz; Xu; Xuu; Yv; Yvv; Nr; Nrr; half_beam]');
    addFcn(ms, 'EOM', [300 30 480 250], [ ...
'function xdot = EOM(s, FL, FR, p)'                                      newline ...
'%#codegen'                                                              newline ...
'% 3-DOF WAM-V equations of motion, NED.'                                newline ...
'% Coefficients come straight from the Gazebo VRX plugins.'              newline ...
'%   s = [u v r x_n y_n psi]'''                                              newline ...
'%   p = [m Izz Xu Xuu Yv Yvv Nr Nrr half_beam]'''                       newline ...
'u = s(1); v = s(2); r = s(3); psi = s(6);'                              newline ...
'm=p(1); Izz=p(2); Xu=p(3); Xuu=p(4); Yv=p(5); Yvv=p(6);'                newline ...
'Nr=p(7); Nrr=p(8); b_half=p(9);'                                        newline ...
''                                                                       newline ...
'X = FL + FR;'                                                           newline ...
'N = (FL - FR)*b_half;'                                                  newline ...
''                                                                       newline ...
'Dx = (Xu + Xuu*abs(u))*u;'                                              newline ...
'Dy = (Yv + Yvv*abs(v))*v;'                                              newline ...
'Dn = (Nr + Nrr*abs(r))*r;'                                              newline ...
''                                                                       newline ...
'du = (X - Dx)/m + v*r;'                                                 newline ...
'dv = (  - Dy)/m - u*r;'                                                 newline ...
'dr = (N - Dn)/Izz;'                                                     newline ...
''                                                                       newline ...
'xdot = [du; dv; dr;'                                                    newline ...
'        u*cos(psi) - v*sin(psi);'                                       newline ...
'        u*sin(psi) + v*cos(psi);'                                       newline ...
'        r];']);
    add_block('simulink/Continuous/Integrator', [ms '/Integ'], ...
              'Position', [560 115 610 165], 'InitialCondition', 'x0_w04');
    addFcn(ms, 'States', [700 30 820 330], [ ...
'function [x_n, y_n, psi, r] = States(s)'                                newline ...
'%#codegen'                                                              newline ...
'% 상태 벡터 s = [u v r x_n y_n psi] 에서 센서 모델이 쓰는 네 개를 꺼낸다.'    newline ...
'r = s(3);'                                                              newline ...
'x_n = s(4);  y_n = s(5);'                                                   newline ...
'psi = atan2(sin(s(6)), cos(s(6)));']);
    L(ms,'EOM/1','Integ/1');  L(ms,'Integ/1','EOM/1');
    L(ms,'FL/1','EOM/2');     L(ms,'FR/1','EOM/3');   L(ms,'p/1','EOM/4');
    L(ms,'Integ/1','States/1');
    for k = 1:numel(outs), L(ms, sprintf('States/%d',k), [outs{k} '/1']); end
    % 참값은 센서 모델 결과와 비교하려고 태그로 남긴다 (W09_offline_run)
    for k = 1:numel(outs)
        G(ms, [outs{k} '_true'], 900, 300 + (k-1)*50);
        L(ms, sprintf('States/%d',k), ['Go_' outs{k} '_true/1']);
    end

    % --- 센서 모델 --------------------------------------------------------
    ss = newSub(m, 'SensorModel', [650 100 820 420]);
    ins = {'x_n','y_n','psi','r'};
    for k = 1:numel(ins), inP(ss, ins{k}, k); end
    so = {'gps_new','imu_new','wind_new','lat','wz','wind'};
    for k = 1:numel(so), outP(ss, so{k}, k); end
    add_block('simulink/Sources/Random Number', [ss '/GyroNoise'], 'Position',[60 280 130 310], ...
              'Mean','0', 'Variance','imu_gyro_std^2', 'Seed','imu_seed', 'SampleTime','Ts');
    add_block('simulink/Sources/Constant', [ss '/q'], 'Position', [40 340 200 370], ...
              'Value', '[lat0; lon0; gps_x; gps_y; imu_gyro_bias; round(1/(hz_design_gps*Ts)); round(1/(hz_design_imu*Ts))]');
    addFcn(ss, 'Sensors', [300 30 520 420], [ ...
'function [gps_new, imu_new, lat, lon, qz, qw, wz] = Sensors(x_n, y_n, psi, r, noise, q)' newline ...
'%#codegen'                                                                         newline ...
'% GPS 와 IMU 를 VRX 처럼 흉내 낸다 (9주차 1-5 절).'                                 newline ...
'%   GPS : 안테나 위치(선체 x = gps_x)의 위경도. nG 스텝마다 한 번 새 값'            newline ...
'%   IMU : ENU 쿼터니언과 z 각속도(ENU, 잡음 + 바이어스). nI 스텝마다 한 번'        newline ...
'%   q = [lat0 lon0 gps_x gps_y bias nG nI]'''                                       newline ...
'persistent k lat_h lon_h qz_h qw_h wz_h'                                           newline ...
'if isempty(k)'                                                                     newline ...
'    k = 0;  lat_h = q(1);  lon_h = q(2);  qz_h = 0;  qw_h = 1;  wz_h = 0;'           newline ...
'end'                                                                               newline ...
'% 안테나 위치 — 선체 원점에서 (gps_x, gps_y) 만큼 떨어진 점 (3주차 1-5 회전)'       newline ...
'xa = x_n + q(3)*cos(psi) - q(4)*sin(psi);'                                         newline ...
'ya = y_n + q(3)*sin(psi) + q(4)*cos(psi);'                                         newline ...
'% NED -> 위경도 (3주차 1-5 식의 역변환, WGS84)'                                    newline ...
'a = 6378137.0;  e2 = 6.69437999014e-3;'                                            newline ...
'lat0r = q(1)*pi/180;  s2 = sin(lat0r)^2;'                                          newline ...
'Rm = a*(1 - e2)/(1 - e2*s2)^1.5;  Rn = a/sqrt(1 - e2*s2);'                         newline ...
'gps_new = double(mod(k, q(6)) == 0);'                                              newline ...
'if gps_new > 0'                                                                    newline ...
'    lat_h = q(1) + xa/Rm*180/pi;'                                                  newline ...
'    lon_h = q(2) + ya/(Rn*cos(lat0r))*180/pi;'                                     newline ...
'end'                                                                               newline ...
'imu_new = double(mod(k, q(7)) == 0);'                                              newline ...
'if imu_new > 0'                                                                    newline ...
'    yaw = pi/2 - psi;                 % NED 선수각 -> ENU yaw'                      newline ...
'    qz_h = sin(yaw/2);  qw_h = cos(yaw/2);'                                        newline ...
'    wz_h = -r + q(5) + noise;         % r_ENU = -r_NED, 잡음 + 바이어스'           newline ...
'end'                                                                               newline ...
'k = k + 1;'                                                                        newline ...
'lat = lat_h;  lon = lon_h;  qz = qz_h;  qw = qw_h;  wz = wz_h;']);
    % 센서는 이산이다 — 운동모델(연속)에서 Ts 마다 한 번 값을 읽는다.
    % 영속 변수(persistent)를 쓰는 함수는 연속 샘플 시간을 물려받을 수 없다
    %  SampleTime 만 넣으면 저장되지 않는다. 갱신 방식을 DISCRETE 로 먼저 바꿔야 한다
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[ss '/Sensors']);
    ch.ChartUpdate = 'DISCRETE';
    ch.SampleTime  = 'Ts';
    for k = 1:4, L(ss, [ins{k} '/1'], sprintf('Sensors/%d',k)); end
    L(ss,'GyroNoise/1','Sensors/5');  L(ss,'q/1','Sensors/6');
    L(ss,'Sensors/1','gps_new/1');    L(ss,'Sensors/2','imu_new/1');
    L(ss,'Sensors/3','lat/1');        L(ss,'Sensors/7','wz/1');
    % 바람 센서는 이 모델에 없다 — 1단계와 같은 자리에 0 을 둔다
    add_block('simulink/Sources/Constant', [ss '/NoWind'], 'Position',[600 470 650 500], 'Value','0');
    L(ss,'NoWind/1','wind_new/1');    L(ss,'NoWind/1','wind/1');
    tg = {'lon','qz','qw'};
    for k = 1:3
        G(ss, tg{k}, 700, 520 + (k-1)*50);
        L(ss, sprintf('Sensors/%d',k+3), ['Go_' tg{k} '/1']);
    end

    % --- 최상위 배선 ------------------------------------------------------
    L(m,'Command/1','MotionModel/1');  L(m,'Command/2','MotionModel/2');
    L(m,'MotionModel/1','SensorModel/1');  L(m,'MotionModel/2','SensorModel/2');
    L(m,'MotionModel/3','SensorModel/3');  L(m,'MotionModel/4','SensorModel/4');
    addRateMeter(m, 'SensorModel');
    addLogging(m, [650 500 820 600], {'hz_gps','hz_imu','hz_wind','lat','wz','wind', ...
                                      'lon','qz','qw','x_n_true','y_n_true','psi_true','r_true'});
    addW09Animate(m, 40, 700, true);          % 참값이 있는 모델 — 네 칸 전부 그린다

    note(m,'n1', ['W09 0단계  —  운동모델에 GPS · IMU 를 붙여 수신 주기를 먼저 잰다 (VRX 불필요)' newline ...
        'Command -> MotionModel -> SensorModel -> RateMeter.  RateMeter 뒤는 1단계와 같다' newline ...
        'SensorModel 은 VRX 파일의 update_rate (GPS 20 Hz, IMU 100 Hz) 와 안테나 위치를 쓴다' newline ...
        'Animate 상자가 도는 동안 GPS 점 · 참값 항적 · 수신 주기 · 자이로를 그린다 (W09_animate.m)' newline ...
        '실행: W09_setup -> W09_offline_run'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 수신 주기 계산 · 표시 · 태그 — 0단계와 1단계가 똑같이 쓴다
%   src 의 1~3번 출력 = 새 메시지 플래그 (GPS, IMU, 바람)
%   src 의 4~6번 출력 = 값 (위도, 요각속도 z, 풍속)
% =====================================================================
function addRateMeter(m, src)
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
    for k = 1:3, L(m, sprintf('%s/%d',src,k), sprintf('RateMeter/%d',k)); end
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
        L(m, sprintf('%s/%d',src,k+3), ['Go_' val{k} '/1']);
    end
end

% =====================================================================
% 1단계 — 센서 세 개의 수신 주기
% =====================================================================
function build_sensor_rates()
    m = 'W09_1_sensor_rates'; fresh(m);
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

    %  실시간 화면이 쓸 값도 같은 버스에서 함께 뽑는다 — 0단계 SensorModel 이
    %  lon · qz · qw 를 전역 Goto 로 내려 둔 것과 **같은 자리, 같은 이름**이다.
    %  출력 포트는 늘리지 않는다 (늘리면 RateMeter 쪽 포트 번호가 전부 밀린다)
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelGps'], 'Position',[250 60 300 120]);
    set_param([ss '/SelGps'], 'OutputSignals', 'latitude,longitude');
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelImu'], 'Position',[250 240 300 300]);
    set_param([ss '/SelImu'], 'OutputSignals', 'angular_velocity.z,orientation.z,orientation.w');
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelWind'], 'Position',[250 420 300 480]);
    set_param([ss '/SelWind'], 'OutputSignals', 'data');

    L(ss,'GpsSub/1','gps_new/1');
    L(ss,'ImuSub/1','imu_new/1');
    L(ss,'WindSub/1','wind_new/1');
    L(ss,'GpsSub/2','SelGps/1');   L(ss,'SelGps/1','lat/1');
    L(ss,'ImuSub/2','SelImu/1');   L(ss,'SelImu/1','wz/1');
    L(ss,'WindSub/2','SelWind/1'); L(ss,'SelWind/1','wind/1');
    G(ss, 'lon', 700, 60);   L(ss, 'SelGps/2', 'Go_lon/1');
    G(ss, 'qz',  700, 240);  L(ss, 'SelImu/2', 'Go_qz/1');
    G(ss, 'qw',  700, 300);  L(ss, 'SelImu/3', 'Go_qw/1');

    addRateMeter(m, 'SensorSubscriber');
    addLogging(m, [650 500 820 600], {'hz_gps','hz_imu','hz_wind','lat','wz','wind'});
    addW09Animate(m, 40, 700, false);        % VRX — 참값이 없다. NaN 으로 부른다

    note(m,'n1', ['W09 1단계  —  센서 세 개의 수신 주기를 Simulink 로 잰다 (VRX 필요)' newline ...
        'SensorSubscriber -> RateMeter -> 화면 표시.  IsNew 를 세어 경과시간으로 나눈 값이다' newline ...
        '같은 시간에 터미널에서 ros2 topic hz 를 돌려 두 값을 비교한다' newline ...
        'Animate 상자는 GPS 점과 자이로를 그린다. **주기를 잴 때는 animate = 0 으로 둔다**' newline ...
        '실행 전: (1) VRX 기동  (2) W09_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 2단계 — QoS 를 어긋나게 해 본다 (VRX 불필요)
% =====================================================================
function build_qos_test()
    m = 'W09_2_qos_test'; fresh(m);
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

    note(m,'n1', ['W09 2단계  —  QoS 불일치를 Simulink 에서 재현한다 (VRX 불필요)' newline ...
        '같은 토픽 /qos_topic 을 Reliable 과 Best effort 로 각각 구독한다.' newline ...
        '발행자(usv_basics qos_test_pub)가 BEST_EFFORT 이므로 Reliable 쪽은 0 건이다.' newline ...
        '실행 전: (1) ros2 run usv_basics qos_test_pub  (2) W09_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end
