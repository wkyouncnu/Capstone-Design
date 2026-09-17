function build_w03_models()
% BUILD_W03_MODELS  3주차 좌표계 Simulink 모델 3개를 생성한다.
%
%     W03_1_frame_check.slx   1단계 — 변환식만 확인. VRX 도 ROS 도 필요 없다
%     W03_2_vrx_nav.slx       2단계 — VRX 의 GPS·IMU 를 받아 NED 로 바꿔 본다
%     W03_3_vrx_drive.slx     3단계 — 추력을 주고 위치·선수각 부호를 확인한다
%
%   무엇을 확인하는 모델인가
%     ROS·Gazebo 는 ENU 로 준다. 본 과목 제어는 NED 로 쓴다.
%     변환을 빠뜨려도 오류가 나지 않는다 (3주차 §1-5). 그래서 눈으로 확인한다.
%
%       위치  N = (lat - lat0)*Rm,   E = (lon - lon0)*Rn*cos(lat0)
%       자세  psi_NED = pi/2 - yaw_ENU
%       각속도 r_NED  = -r_ENU
%
%   최상위 구성 (역할별 서브시스템)
%     2단계   SensorSubscriber -> Nav -> [N] [E] [psi] [r] 태그  (+ Animate · Logging)
%     3단계   위와 같고 Thrusters 서브시스템이 /wamv/thrusters/*/thrust 로 발행
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 복구된다.
%   실행 전에 반드시 >> W03_setup 을 먼저 실행할 것.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''lat0'',''var'')')
        error('먼저 W03_setup 을 실행하십시오.');
    end

    build_frame_check();
    build_vrx_nav();
    build_vrx_drive();
    build_teleop();

    slxList = dir('W03_*.slx');
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
% 공통 헬퍼 (W02 와 같다)
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

function C(sys, name, value, x, y)
    add_block('simulink/Sources/Constant', [sys '/' name], ...
              'Position', [x y x+95 y+30], 'Value', value);
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
    y = 40 + (k-1)*55;
    add_block('simulink/Sources/In1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [20 y 50 y+14]);
end

function outP(ss, name, k)
    y = 40 + (k-1)*55;
    add_block('simulink/Sinks/Out1', [ss '/' name], 'Port', num2str(k), ...
              'Position', [900 y 930 y+14]);
end

function addSubscriber(sys, name, topic, msgType, x, y)
    add_block('ros2lib/Subscribe', [sys '/' name], 'Position',[x y x+130 y+60]);
    set_param([sys '/' name], 'topicSource','Specify your own', ...
        'topic', topic, 'messageType', msgType, 'sampleTime','Ts');
end

% =====================================================================
% 좌표 변환 코드 — 세 모델이 같은 코드를 쓴다
% =====================================================================
function code = navCode(fname)
code = [ ...
'function [N, E, D, yaw_enu, psi] = ' fname '(lat, lon, alt, qx, qy, qz, qw, lat0, lon0, alt0)' newline ...
'%#codegen'                                                                     newline ...
'% ENU(ROS/Gazebo) -> NED(ship control). W03 section 1-5, 1-6.'                 newline ...
'%   position : flat-earth approximation around (lat0, lon0)'                   newline ...
'%   heading  : quaternion (ROS order x,y,z,w) -> yaw_ENU -> psi_NED'           newline ...
''                                                                              newline ...
'a  = 6378137.0;              % WGS84 semi-major axis [m]'                      newline ...
'e2 = 6.69437999014e-3;       % WGS84 first eccentricity squared'               newline ...
''                                                                              newline ...
'lat0r = lat0*pi/180;'                                                          newline ...
's2    = sin(lat0r)^2;'                                                         newline ...
'Rm    = a*(1 - e2) / (1 - e2*s2)^1.5;      % meridian radius'                  newline ...
'Rn    = a / sqrt(1 - e2*s2);               % prime vertical radius'            newline ...
''                                                                              newline ...
'N =  (lat - lat0)*pi/180 * Rm;             % north [m]'                        newline ...
'E =  (lon - lon0)*pi/180 * Rn*cos(lat0r);  % east  [m]'                        newline ...
'D = -(alt - alt0);                         % down  [m]'                        newline ...
''                                                                              newline ...
'% yaw about ENU z (up). ROS quaternion order is (x, y, z, w).'                 newline ...
'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'                    newline ...
'p   = pi/2 - yaw_enu;                      % NED heading'                      newline ...
'psi = atan2(sin(p), cos(p));               % wrap to [-pi, pi)'];
end

% =====================================================================
% 1단계 — 변환식 확인 (ROS 불필요)
% =====================================================================
function build_frame_check()
    m = 'W03_1_frame_check'; fresh(m);
    setSolver(m, '0');

    C(m,'Lat','lat_s',  60,  40);   C(m,'Lon','lon_s',  60, 100);
    C(m,'Alt','alt_s',  60, 160);   C(m,'Qx','qx_s',    60, 220);
    C(m,'Qy','qy_s',    60, 280);   C(m,'Qz','qz_s',    60, 340);
    C(m,'Qw','qw_s',    60, 400);   C(m,'Lat0','lat0',  60, 460);
    C(m,'Lon0','lon0',  60, 520);   C(m,'Alt0','alt0',  60, 580);

    addFcn(m, 'FrameConv', [300 40 500 620], navCode('FrameConv'));
    cs = {'Lat','Lon','Alt','Qx','Qy','Qz','Qw','Lat0','Lon0','Alt0'};
    for k = 1:numel(cs), L(m, [cs{k} '/1'], sprintf('FrameConv/%d',k)); end

    % 라디안은 사람이 못 읽는다. 도로 바꿔 함께 표시한다
    add_block('simulink/Math Operations/Gain', [m '/Rad2DegYaw'], ...
              'Position',[600 260 670 290], 'Gain','180/pi');
    add_block('simulink/Math Operations/Gain', [m '/Rad2DegPsi'], ...
              'Position',[600 320 670 350], 'Gain','180/pi');
    L(m,'FrameConv/4','Rad2DegYaw/1');
    L(m,'FrameConv/5','Rad2DegPsi/1');

    outs = {'N_m','E_m','D_m'};
    for k = 1:3
        b = [m '/Disp_' outs{k}];
        add_block('simulink/Sinks/Display', b, 'Position',[760 40+(k-1)*60 900 70+(k-1)*60]);
        L(m, sprintf('FrameConv/%d',k), ['Disp_' outs{k} '/1']);
    end
    add_block('simulink/Sinks/Display', [m '/Disp_yaw_ENU_deg'], 'Position',[760 260 900 290]);
    add_block('simulink/Sinks/Display', [m '/Disp_psi_NED_deg'], 'Position',[760 320 900 350]);
    L(m,'Rad2DegYaw/1','Disp_yaw_ENU_deg/1');
    L(m,'Rad2DegPsi/1','Disp_psi_NED_deg/1');

    % 화면 숫자와 같은 값을 워크스페이스에도 남긴다 (문서·검증용)
    tags = {'N','E','D','yaw_enu','psi'};
    for k = 1:numel(tags)
        G(m, tags{k}, 600, 420 + (k-1)*50);
        L(m, sprintf('FrameConv/%d',k), ['Go_' tags{k} '/1']);
    end
    addLogging(m, [760 420 930 520], tags);

    note(m,'n1', ['W03 1단계  —  좌표 변환식 확인 (VRX 불필요)' newline ...
        '4주차 §2-3 에서 실제로 받은 GPS·IMU 값 한 벌을 넣고 NED 로 바꾼다.' newline ...
        'yaw_ENU 와 psi_NED 가 90도 차이인지, N·E 가 기준점에서 몇 m 인지 눈으로 확인한다.' newline ...
        '실행 전 >> W03_setup'], 60, -80);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 서브시스템 · SensorSubscriber (연보라) — GPS · IMU 를 받는다
%   출력 lat, lon, alt, qx, qy, qz, qw, r_enu, valid
% =====================================================================
function addSensorSubscriber(m, pos)
    ss = newSub(m, 'SensorSubscriber', pos);
    outs = {'lat','lon','alt','qx','qy','qz','qw','r_enu','valid'};
    for k = 1:numel(outs), outP(ss, outs{k}, k); end

    addSubscriber(ss, 'GpsSub', '/wamv/sensors/gps/gps/fix', 'sensor_msgs/NavSatFix', 50, 60);
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelGps'], ...
              'Position',[250 60 300 180]);
    set_param([ss '/SelGps'], 'OutputSignals', 'latitude,longitude,altitude');

    addSubscriber(ss, 'ImuSub', '/wamv/sensors/imu/imu/data', 'sensor_msgs/Imu', 50, 320);
    add_block('simulink/Signal Routing/Bus Selector', [ss '/SelImu'], ...
              'Position',[250 320 300 520]);
    set_param([ss '/SelImu'], 'OutputSignals', ...
        ['orientation.x,orientation.y,orientation.z,orientation.w,' ...
         'angular_velocity.z']);

    addFcn(ss, 'RxLatch', [420 40 620 560], [ ...
'function [lat, lon, alt, qx, qy, qz, qw, r_enu, valid] = RxLatch(gps_new, imu_new, la, lo, al, x, y, z, w, wz)' newline ...
'%#codegen'                                                                     newline ...
'% Subscribe blocks output an all-zero message before the first one arrives.'   newline ...
'% Latitude 0 / longitude 0 is a real place (Gulf of Guinea), so the value'     newline ...
'% cannot be used to tell "no data yet" apart. Latch the IsNew flags instead.'  newline ...
'persistent seen_gps seen_imu'                                                  newline ...
'if isempty(seen_gps), seen_gps = false; seen_imu = false; end'                 newline ...
'if gps_new, seen_gps = true; end'                                              newline ...
'if imu_new, seen_imu = true; end'                                              newline ...
''                                                                              newline ...
'lat = la;  lon = lo;  alt = al;'                                               newline ...
'qx  = x;   qy  = y;   qz  = z;  qw = w;'                                       newline ...
'r_enu = wz;'                                                                   newline ...
'valid = double(seen_gps && seen_imu);']);

    L(ss,'GpsSub/1','RxLatch/1');
    L(ss,'ImuSub/1','RxLatch/2');
    L(ss,'GpsSub/2','SelGps/1');
    L(ss,'ImuSub/2','SelImu/1');
    for k = 1:3, L(ss, sprintf('SelGps/%d',k), sprintf('RxLatch/%d',k+2)); end
    for k = 1:5, L(ss, sprintf('SelImu/%d',k), sprintf('RxLatch/%d',k+5)); end
    for k = 1:numel(outs), L(ss, sprintf('RxLatch/%d',k), [outs{k} '/1']); end
end

% =====================================================================
% 서브시스템 · Nav (초록) — ENU -> NED
%   입력 lat, lon, alt, qx, qy, qz, qw, r_enu   출력 N, E, psi, r
% =====================================================================
function addNav(m, pos)
    ss = newSub(m, 'Nav', pos);
    ins = {'lat','lon','alt','qx','qy','qz','qw','r_enu'};
    for k = 1:numel(ins), inP(ss, ins{k}, k); end
    outs = {'N','E','psi','r'};
    for k = 1:numel(outs), outP(ss, outs{k}, k); end

    C(ss,'Lat0','lat0', 100, 480);
    C(ss,'Lon0','lon0', 100, 530);
    C(ss,'Alt0','alt0', 100, 580);

    addFcn(ss, 'Ned', [350 40 560 620], navCode('Ned'));
    % Ned 의 입력은 lat..qw 7개 + 기준점 3개다.
    % r_enu(8번째 입력)는 Ned 로 가지 않는다. 아래에서 부호만 뒤집는다
    for k = 1:7, L(ss, [ins{k} '/1'], sprintf('Ned/%d',k)); end
    L(ss,'Lat0/1','Ned/8');
    L(ss,'Lon0/1','Ned/9');
    L(ss,'Alt0/1','Ned/10');

    % r_NED = -r_ENU. 한 줄짜리 부호 반전이지만 빠뜨리면 선회 방향이 뒤집힌다
    add_block('simulink/Math Operations/Gain', [ss '/FlipR'], ...
              'Position',[350 700 420 730], 'Gain','-1');
    L(ss,'r_enu/1','FlipR/1');

    L(ss,'Ned/1','N/1');
    L(ss,'Ned/2','E/1');
    L(ss,'Ned/5','psi/1');
    L(ss,'FlipR/1','r/1');

    % D(수직)는 수상선 제어에 쓰지 않는다. 열어 두면 미연결 포트로 잡히므로 종단한다
    add_block('simulink/Sinks/Terminator', [ss '/D_unused'], 'Position',[700 640 720 660]);
    L(ss,'Ned/3','D_unused/1');

    % N · E · psi · r 태그는 최상위에서 만든다 (여기서 또 만들면 태그가 중복된다)
    G(ss, 'yaw_enu', 700, 520);
    L(ss, 'Ned/4', 'Go_yaw_enu/1');
end

% =====================================================================
% 서브시스템 · Thrusters (노랑) — 좌·우 추력을 발행한다
% =====================================================================
function addThrusters(m, pos)
    ss = newSub(m, 'Thrusters', pos);
    addOneThruster(ss, 'left',  'L',  60,  40);
    addOneThruster(ss, 'right', 'R',  60, 280);
end

function addOneThruster(ss, side, tag, x, y)
    C(ss, ['Cmd' tag], ['thrust_' side], x, y+60);
    add_block('ros2lib/Blank Message', [ss '/Blank' tag], ...
              'Position', [x y+120 x+100 y+160]);
    set_param([ss '/Blank' tag], 'entityType','std_msgs/Float64', ...
              'messageType','std_msgs/Float64', 'SampleTime','Ts');
    add_block('simulink/Signal Routing/Bus Assignment', [ss '/Asg' tag], ...
              'Position', [x+200 y+40 x+260 y+150]);
    set_param([ss '/Asg' tag], 'AssignedSignals','data');
    add_block('ros2lib/Publish', [ss '/Pub' tag], ...
              'Position', [x+360 y+70 x+460 y+110]);
    set_param([ss '/Pub' tag], 'topicSource','Specify your own', ...
              'topic', ['/wamv/thrusters/' side '/thrust'], ...
              'messageType','std_msgs/Float64');
    L(ss, ['Blank' tag '/1'], ['Asg' tag '/1']);
    L(ss, ['Cmd'   tag '/1'], ['Asg' tag '/2']);
    L(ss, ['Asg'   tag '/1'], ['Pub' tag '/1']);

    G(ss, ['thr_' side], x+540, y+75);
    L(ss, ['Cmd' tag '/1'], ['Go_thr_' side '/1']);
end

% =====================================================================
% 서브시스템 · Animate (회색) · Logging (회색)
% =====================================================================
function addAnimate(m, pos)
    ss = newSub(m, 'Animate', pos);
    F(ss,'N','a',   50, 40);
    F(ss,'E','a',   50, 90);
    F(ss,'psi','a', 50, 140);
    add_block('simulink/Sources/Digital Clock', [ss '/Clk'], ...
              'Position', [50 190 100 220], 'SampleTime','Ts');
    C(ss,'Anim','animate', 50, 240);
    addFcn(ss, 'AnimateFcn', [250 40 400 260], [ ...
'function ok = AnimateFcn(N, E, psi, t, en)'                           newline ...
'%#codegen'                                                            newline ...
'coder.extrinsic(''W03_animate'');'                                    newline ...
'ok = 1;'                                                              newline ...
'if en > 0.5'                                                          newline ...
'    W03_animate(N, E, psi, t);'                                       newline ...
'end']);
    add_block('simulink/Sinks/Terminator', [ss '/AnimEnd'], 'Position', [480 140 500 160]);
    L(ss,'Fr_N_a/1','AnimateFcn/1');
    L(ss,'Fr_E_a/1','AnimateFcn/2');
    L(ss,'Fr_psi_a/1','AnimateFcn/3');
    L(ss,'Clk/1','AnimateFcn/4');
    L(ss,'Anim/1','AnimateFcn/5');
    L(ss,'AnimateFcn/1','AnimEnd/1');
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

% 최상위 — SensorSubscriber -> Nav 배선과 되먹임 태그
function wireNav(m)
    for k = 1:8
        L(m, sprintf('SensorSubscriber/%d',k), sprintf('Nav/%d',k));
    end
    G(m, 'valid', 1150, 560);
    L(m, 'SensorSubscriber/9', 'Go_valid/1');
    t = {'N','E','psi','r'};
    for k = 1:4
        G(m, t{k}, 1150, 120 + (k-1)*60);
        L(m, sprintf('Nav/%d',k), ['Go_' t{k} '/1']);
    end
end

% =====================================================================
% 2단계 — VRX 의 GPS·IMU 를 NED 로
% =====================================================================
function build_vrx_nav()
    m = 'W03_2_vrx_nav'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    addSensorSubscriber(m, [250 100 420 420]);
    addNav(m, [650 100 820 420]);
    wireNav(m);
    addAnimate(m, [250 560 420 650]);
    addLogging(m, [650 560 820 650], {'N','E','psi','r','yaw_enu','valid'});

    note(m,'n1', ['W03 2단계  —  VRX 의 GPS·IMU 를 NED 로 (VRX 필요)' newline ...
        'SensorSubscriber -> Nav -> [N] [E] [psi] [r] 태그' newline ...
        '배를 손으로 몰면서(wamv_teleop_key) 숫자가 어떻게 바뀌는지 본다.' newline ...
        '실행 전: (1) VRX 기동  (2) W03_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 3단계 — 추력을 주고 부호를 확인
% =====================================================================
function build_vrx_drive()
    m = 'W03_3_vrx_drive'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    addSensorSubscriber(m, [250 100 420 420]);
    addNav(m, [650 100 820 420]);
    wireNav(m);
    addThrusters(m, [250 700 420 800]);
    addAnimate(m, [650 700 820 790]);
    addLogging(m, [1000 700 1170 790], ...
               {'N','E','psi','r','yaw_enu','valid','thr_left','thr_right'});

    note(m,'n1', ['W03 3단계  —  추력을 주고 좌표 부호를 확인한다 (VRX 필요)' newline ...
        'Thrusters 가 /wamv/thrusters/{left,right}/thrust 로 발행한다.' newline ...
        'W03_setup 의 scenario 를 1(직진) / 2(좌선회) 로 바꿔 두 번 돌린다.' newline ...
        '좌선회에서 psi_NED 가 줄고 r 이 음수여야 한다.' newline ...
        '실행 전: (1) VRX 기동  (2) W03_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 4단계 — 버튼으로 모는 teleop  (wamv_teleop_key 의 Simulink 판)
% =====================================================================
function build_teleop()
    m = 'W03_4_teleop'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end_teleop');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    addTeleopPad(m, [250 100 420 200]);
    addThrustersIn(m, [650 100 820 200]);
    addOdomNav(m, [250 380 420 560]);
    addTeleopAnimate(m, [650 380 820 470]);
    addLogging(m, [1000 380 1170 470], {'N','E','psi','u','v','r','FL','FR'});

    L(m,'TeleopPad/1','Thrusters/1');
    L(m,'TeleopPad/2','Thrusters/2');

    note(m,'n1', ['W03 4단계  —  버튼으로 배를 몬다 (VRX 필요)' newline ...
        newline ...
        'TeleopPad 를 더블클릭하면 화살표 버튼 네 개가 나온다.' newline ...
        '누르고 있는 동안만 추력이 나간다 (Momentary).' newline ...
        '  전진 / 후진 / 좌선회 / 우선회' newline ...
        newline ...
        'ROS 2 노드 wamv_teleop_key 와 같은 일을 한다.' newline ...
        '다른 점은 눌린 값이 Simulink 안에 있어, 명령과 응답을' newline ...
        '한 화면에서 함께 볼 수 있다는 것이다.' newline ...
        newline ...
        '실행 전: (1) VRX 기동  (2) W03_setup'], 250, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% ---- 버튼 네 개와 차동 배분 ----------------------------------------
function addTeleopPad(m, pos)
    ss = newSub(m, 'TeleopPad', pos);
    outP(ss, 'FL', 1);
    outP(ss, 'FR', 2);

    %  버튼은 **신호가 아니라 파라미터**를 누른다. Constant 의 Value 에 묶어 두고,
    %  누르는 동안 1, 떼면 0 이 되게 한다 (Momentary).
    key = {'fwd',   char(9650), 120,  40
           'back',  char(9660), 120, 360
           'left',  char(9664),  20, 200
           'right', char(9654), 220, 200};
    lab = {'전진','후진','좌선회','우선회'};
    for k = 1:size(key,1)
        nm = key{k,1};
        C(ss, ['c_' nm], '0', 420, 40 + (k-1)*70);
        b = [ss '/btn_' nm];
        add_block('simulink_hmi_blocks/Push Button', b, ...
                  'Position', [key{k,3} key{k,4} key{k,3}+90 key{k,4}+70]);
        info = Simulink.HMI.ParamSourceInfo;
        info.BlockPath = [ss '/c_' nm];
        info.ParamName = 'Value';
        info.Label     = nm;
        set_param(b, 'Binding', info, ...
                     'ButtonText', [key{k,2} ' ' lab{k}], ...
                     'OnValue','1', 'OffValue','0', 'ButtonType','Momentary');
    end

    addFcn(ss, 'Mix', [600 60 780 300], [ ...
'function [FL, FR] = Mix(fwd, back, left, right, Fmax)'                      newline ...
'%#codegen'                                                                  newline ...
'% wamv_teleop_key 와 같은 차동 배분.'                                        newline ...
'%   전진   FL = +F, FR = +F      후진   FL = -F, FR = -F'                    newline ...
'%   좌선회 FL = -F, FR = +F      우선회 FL = +F, FR = -F'                    newline ...
'%'                                                                          newline ...
'% 좌선회에서 요 모멘트 N = (FL - FR)*b 가 음수라 psi_NED 가 줄어든다.'        newline ...
'surge = fwd   - back;'                                                      newline ...
'turn  = right - left;'                                                      newline ...
'FL = Fmax*(surge + turn);'                                                  newline ...
'FR = Fmax*(surge - turn);'                                                  newline ...
'FL = min(max(FL, -Fmax), Fmax);'                                            newline ...
'FR = min(max(FR, -Fmax), Fmax);']);

    C(ss, 'Fmax', 'teleop_thrust', 420, 320);
    L(ss,'c_fwd/1',  'Mix/1');
    L(ss,'c_back/1', 'Mix/2');
    L(ss,'c_left/1', 'Mix/3');
    L(ss,'c_right/1','Mix/4');
    L(ss,'Fmax/1',   'Mix/5');
    L(ss,'Mix/1','FL/1');
    L(ss,'Mix/2','FR/1');
    G(ss,'FL', 840,  60);
    G(ss,'FR', 840, 130);
    L(ss,'Mix/1','Go_FL/1');
    L(ss,'Mix/2','Go_FR/1');

    note(ss,'n', ['버튼은 신호가 아니라 파라미터를 누른다.' newline ...
        '각 버튼이 옆 Constant 의 Value 에 묶여 있고,' newline ...
        '누르는 동안만 1 이 된다 (Momentary).' newline ...
        '모델을 돌린 상태에서 눌러야 반응한다.'], 120, 460);
end

% ---- FL, FR 을 입력으로 받아 발행 -----------------------------------
function addThrustersIn(m, pos)
    ss = newSub(m, 'Thrusters', pos);
    inP(ss, 'FL', 1);
    inP(ss, 'FR', 2);
    addOnePub(ss, 'left',  'L', 'FL', 120,  40);
    addOnePub(ss, 'right', 'R', 'FR', 120, 300);
end

function addOnePub(ss, side, tag, inName, x, y)
    add_block('ros2lib/Blank Message', [ss '/Blank' tag], ...
              'Position', [x y x+110 y+40]);
    set_param([ss '/Blank' tag], 'entityType','std_msgs/Float64', ...
              'messageType','std_msgs/Float64', 'SampleTime','Ts');
    add_block('simulink/Signal Routing/Bus Assignment', [ss '/Asg' tag], ...
              'Position', [x+240 y-10 x+300 y+100]);
    set_param([ss '/Asg' tag], 'AssignedSignals','data');
    add_block('ros2lib/Publish', [ss '/Pub' tag], ...
              'Position', [x+420 y+15 x+530 y+55]);
    set_param([ss '/Pub' tag], 'topicSource','Specify your own', ...
              'topic', ['/wamv/thrusters/' side '/thrust'], ...
              'messageType','std_msgs/Float64');
    L(ss, ['Blank' tag '/1'], ['Asg' tag '/1']);
    L(ss, [inName '/1'],      ['Asg' tag '/2']);
    L(ss, ['Asg' tag '/1'],   ['Pub' tag '/1']);
end

% ---- odometry 하나로 위치·자세·속도를 모두 받는다 --------------------
function addOdomNav(m, pos)
    ss = newSub(m, 'OdomNav', pos);
    outs = {'N','E','psi','u','v','r'};
    for k = 1:numel(outs), outP(ss, outs{k}, k); end

    addSubscriber(ss, 'OdomSub', ...
        '/wamv/sensors/position/ground_truth_odometry', 'nav_msgs/Odometry', 60, 60);
    add_block('simulink/Signal Routing/Bus Selector', [ss '/Sel'], ...
              'Position',[250 60 300 420]);
    set_param([ss '/Sel'], 'OutputSignals', ...
        ['pose.pose.position.x,pose.pose.position.y,' ...
         'pose.pose.orientation.x,pose.pose.orientation.y,' ...
         'pose.pose.orientation.z,pose.pose.orientation.w,' ...
         'twist.twist.linear.x,twist.twist.linear.y,twist.twist.angular.z']);

    addFcn(ss, 'Nav', [420 40 640 440], [ ...
'function [N, E, psi, u, v, r] = Nav(ex, ey, qx, qy, qz, qw, bx, by, wz)'      newline ...
'%#codegen'                                                                    newline ...
'% odometry 하나로 위치·자세·속도를 모두 얻는다 (ENU -> NED).'                  newline ...
'%   위치   N = ey,  E = ex          ENU 의 y 가 북, x 가 동'                   newline ...
'%   자세   psi = pi/2 - yaw_ENU'                                              newline ...
'%   속도   u = bx,  v = -by,  r = -wz   y·z 축이 뒤집히므로 부호가 바뀐다'      newline ...
'%'                                                                           newline ...
'% 기준점은 첫 메시지의 위치로 잡는다. 그래야 항적이 (0,0) 에서 시작한다.'      newline ...
'persistent n0 e0 seen'                                                       newline ...
'if isempty(seen), seen = false; n0 = 0; e0 = 0; end'                         newline ...
''                                                                            newline ...
'Nr = ey;   Er = ex;'                                                         newline ...
'if ~seen && (abs(ex) + abs(ey)) > 0'                                         newline ...
'    seen = true;  n0 = Nr;  e0 = Er;'                                        newline ...
'end'                                                                         newline ...
'N = Nr - n0;'                                                                newline ...
'E = Er - e0;'                                                                newline ...
''                                                                            newline ...
'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'                   newline ...
'p   = pi/2 - yaw_enu;'                                                       newline ...
'psi = atan2(sin(p), cos(p));'                                                newline ...
''                                                                            newline ...
'u =  bx;'                                                                    newline ...
'v = -by;'                                                                    newline ...
'r = -wz;']);

    %  Subscribe 의 1번은 "새 메시지가 왔는가", 2번이 메시지 버스다. 버스를
    %  Bus Selector 에 물려야 한다 — 1번을 물리면 "버스 신호가 아니다" 로 멈춘다.
    L(ss, 'OdomSub/2', 'Sel/1');
    add_block('simulink/Sinks/Display', [ss '/IsNew'], 'Position',[250 470 330 500]);
    L(ss, 'OdomSub/1', 'IsNew/1');

    for k = 1:9
        L(ss, sprintf('Sel/%d',k), sprintf('Nav/%d',k));
    end
    for k = 1:numel(outs)
        L(ss, sprintf('Nav/%d',k), [outs{k} '/1']);
        G(ss, outs{k}, 760, 40 + (k-1)*55);
        L(ss, sprintf('Nav/%d',k), ['Go_' outs{k} '/1']);
    end
end

% ---- 실시간 그림 — 왼쪽 항적, 오른쪽 psi·u·v·r -----------------------
function addTeleopAnimate(m, pos)
    ss = newSub(m, 'Animate', pos);
    tags = {'N','E','psi','u','v','r'};
    for k = 1:numel(tags), F(ss, tags{k}, 'a', 60, 40 + (k-1)*55); end
    add_block('simulink/Sources/Digital Clock', [ss '/Clk'], ...
              'Position',[60 380 130 410], 'SampleTime','Ts');
    C(ss, 'En', 'animate', 60, 440);

    addFcn(ss, 'AnimateFcn', [280 40 460 480], [ ...
'function ok = AnimateFcn(N, E, psi, u, v, r, t, en)'                        newline ...
'%#codegen'                                                                  newline ...
'% 그림은 코드 생성 대상이 아니므로 extrinsic 으로 부른다.'                    newline ...
'coder.extrinsic(''W03_teleop_plot'');'                                      newline ...
'ok = 1;'                                                                    newline ...
'if en > 0.5'                                                                newline ...
'    W03_teleop_plot(N, E, psi, u, v, r, t);'                                newline ...
'end']);

    for k = 1:numel(tags)
        L(ss, ['Fr_' tags{k} '_a/1'], sprintf('AnimateFcn/%d',k));
    end
    L(ss,'Clk/1','AnimateFcn/7');
    L(ss,'En/1', 'AnimateFcn/8');
    add_block('simulink/Sinks/Terminator', [ss '/AnimEnd'], 'Position',[560 250 580 270]);
    L(ss,'AnimateFcn/1','AnimEnd/1');
end
