function build_w02_models()
% BUILD_W02_MODELS  turtlesim 목표 자세 제어 Simulink 모델 3개를 생성한다.
%
%     W02_1_pose_sub.slx         1단계 — 중계된 자세를 구독해 화면에 띄우기만 한다
%     W02_2_goto_offline.slx     2단계 — 오프라인 거북이(운동학 모델). turtlesim 불필요
%     W02_3_goto_turtlesim.slx   3단계 — 실제 turtlesim 을 목표 자세로 보낸다
%
%   왜 중계 노드가 필요한가
%     /turtle1/pose 의 형식 turtlesim/msg/Pose 는 MATLAB 에 내장돼 있지 않다.
%     usv_basics 패키지의 turtle_pose_relay 노드가 표준 형식으로 옮겨 다시 발행한다.
%
%       turtlesim_node   --/turtle1/pose    (turtlesim/Pose)-->        turtle_pose_relay
%       turtle_pose_relay --/turtle1/pose2d (geometry_msgs/Pose2D)-->  Simulink
%       Simulink         --/turtle1/cmd_vel (geometry_msgs/Twist)-->   turtlesim_node
%
%   최상위 화면은 역할별 서브시스템 몇 개만 보인다 (자세한 것은 더블클릭).
%
%     2단계                                      3단계
%     Guidance -> Control -> TurtlePlant         Guidance -> Control -> CmdPublisher
%        ^                        |                 ^
%        └── [x] [y] [th] 태그 ───┘                 └── [x] [y] [th] [valid] ── PoseSubscriber
%
%     Animate · Logging 은 선이 없다. 안에서 Goto/From 태그(global)로 신호를 받는다.
%
%   모드 — 한 번에 하나씩 맞춘다
%     1 GO     목표점 방향을 psi_ref 로 두고 전진.  거리 < tol_d 이면 2 로
%     2 ALIGN  제자리에서 목표 선수각으로 회전.     오차 < tol_th 이면 3 으로
%     3 DONE   정지.  목표점이 바뀌어 거리가 벌어지면 다시 1 로
%
%   2·3단계 모델은 Guidance · Control · 게인이 전부 같다. 운동모델만 바뀐다.
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 복구된다.
%   실행 전에 반드시 >> W02_setup 을 먼저 실행할 것.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''x_goal'',''var'')')
        error('먼저 W02_setup 을 실행하십시오.');
    end

    build_pose_sub();
    build_offline();
    build_turtlesim();

    % 배치와 색을 정리한다. 한 번으로는 수렴하지 않아 두 번 부른다.
    slxList = dir('W02_*.slx');
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
% 공통 헬퍼
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

function setFcn(sys, name, code)
    S  = sfroot;
    ch = S.find('-isa','Stateflow.EMChart','Path',[sys '/' name]);
    ch.Script = code;
end

function addFcn(sys, name, pos, code)
    add_block('simulink/User-Defined Functions/MATLAB Function', [sys '/' name], 'Position', pos);
    setFcn(sys, name, code);
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
    % global — 서브시스템 안의 From 도 이 태그를 받을 수 있다
    add_block('simulink/Signal Routing/Goto', [sys '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

function note(sys, tag, txt, x, y)
    add_block('built-in/Note', [sys '/' tag], 'Position',[x y x y], 'Text', txt);
end

function L(sys, src, dst)
    add_line(sys, src, dst, 'autorouting','on');
end

% 빈 서브시스템 — 기본으로 들어 있는 In1 -> Out1 을 지운다
function ss = newSub(m, name, pos)
    ss = [m '/' name];
    add_block('simulink/Ports & Subsystems/Subsystem', ss, 'Position', pos);
    delete_line(ss, 'In1/1', 'Out1/1');
    delete_block([ss '/In1']);
    delete_block([ss '/Out1']);
end

% 이름 붙은 입출력 포트. 이름이 서브시스템 겉면에 그대로 보인다
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

% =====================================================================
% 1단계 — 자세 구독만 (블록이 적어 서브시스템 없이 펼쳐 둔다)
% =====================================================================
function build_pose_sub()
    m = 'W02_1_pose_sub'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'inf');
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    % --- 자세 x, y, theta ---------------------------------------------
    addSubscriber(m, 'PoseSub', '/turtle1/pose2d', 'geometry_msgs/Pose2D', 100, 100);
    add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], ...
              'Position',[300 90 350 230]);
    set_param([m '/Sel'], 'OutputSignals', 'x,y,theta');
    add_block('simulink/Sinks/Display', [m '/IsNew'], 'Position',[300 30 380 60]);
    L(m,'PoseSub/1','IsNew/1');
    L(m,'PoseSub/2','Sel/1');

    sig = {'x','y','theta'};
    for k = 1:3
        yy = 90 + (k-1)*50;
        add_block('simulink/Sinks/Display', [m '/Display_' sig{k}], ...
                  'Position',[450 yy 550 yy+30]);
        L(m, sprintf('Sel/%d',k), ['Display_' sig{k} '/1']);
        b = [m '/log_' sig{k}];
        add_block('simulink/Sinks/To Workspace', b, 'Position',[450 yy+300 550 yy+330]);
        set_param(b, 'VariableName',['log_' sig{k}], 'SaveFormat','Timeseries', ...
                     'SampleTime','Ts');
        L(m, sprintf('Sel/%d',k), ['log_' sig{k} '/1']);
    end

    % theta 를 도 단위로도 본다
    add_block('simulink/Math Operations/Gain', [m '/Rad2Deg'], ...
              'Position',[450 260 520 290], 'Gain','180/pi');
    add_block('simulink/Sinks/Display', [m '/Display_theta_deg'], ...
              'Position',[580 260 680 290]);
    L(m,'Sel/3','Rad2Deg/1');
    L(m,'Rad2Deg/1','Display_theta_deg/1');

    % --- 측정 속도 (중계 노드가 Twist 로 옮긴 것) ------------------------
    addSubscriber(m, 'VelSub', '/turtle1/vel', 'geometry_msgs/Twist', 100, 520);
    add_block('simulink/Signal Routing/Bus Selector', [m '/SelVel'], ...
              'Position',[300 520 350 600]);
    set_param([m '/SelVel'], 'OutputSignals', 'linear.x,angular.z');
    add_block('simulink/Sinks/Terminator', [m '/VelNewEnd'], 'Position',[300 470 320 490]);
    L(m,'VelSub/1','VelNewEnd/1');
    L(m,'VelSub/2','SelVel/1');
    add_block('simulink/Sinks/Display', [m '/Display_v'], 'Position',[450 520 550 550]);
    add_block('simulink/Sinks/Display', [m '/Display_w'], 'Position',[450 570 550 600]);
    L(m,'SelVel/1','Display_v/1');
    L(m,'SelVel/2','Display_w/1');

    note(m,'n1', ['W02 1단계  —  turtlesim 자세 구독' newline ...
        '/turtle1/pose (turtlesim/Pose) 는 MATLAB 에 없는 형식이다.' newline ...
        '중계 노드가 /turtle1/pose2d (geometry_msgs/Pose2D) 로 다시 발행한 것을 받는다.' newline ...
        '실행 전: (1) turtlesim_node  (2) ros2 run usv_basics turtle_pose_relay  (3) W02_setup'], 100, -90);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 서브시스템 1 · Guidance (파랑) — 모드 판단 + psi_ref
%   입력  x, y, th, valid      출력  psi_ref, dist, mode
%   안에서 e_th 등을 global 태그로 내보낸다 (Logging 이 받는다)
% =====================================================================
function addGuidance(m, pos)
    ss = newSub(m, 'Guidance', pos);
    ins = {'x','y','th','valid'};
    for k = 1:4, inP(ss, ins{k}, k); end
    outs = {'psi_ref','dist','mode'};
    for k = 1:3, outP(ss, outs{k}, k); end

    C(ss,'XGoal','x_goal',       100, 280);
    C(ss,'YGoal','y_goal',       100, 330);
    C(ss,'ThGoal','theta_goal',  100, 380);
    C(ss,'TolD','tol_d',         100, 430);
    C(ss,'TolTh','tol_th',       100, 480);

    addFcn(ss, 'GuidanceLaw', [350 40 560 560], [ ...
'function [psi_ref, dist, e_th, mode] = GuidanceLaw(x, y, th, valid, xg, yg, thg, tol_d, tol_th, mode_prev)' newline ...
'%#codegen'                                                                     newline ...
'% Go-to-pose guidance for turtlesim. One thing at a time:'                     newline ...
'%   mode 1 GO    : head for the goal point.   dist < tol_d   -> mode 2'        newline ...
'%   mode 2 ALIGN : turn to the goal heading.  |e_th| < tol_th -> mode 3'        newline ...
'%   mode 3 DONE  : stay still.  goal moved away (dist > 3*tol_d) -> mode 1'    newline ...
'% turtlesim frame: x right, y up, theta counter-clockwise from +x.'            newline ...
''                                                                              newline ...
'dist = sqrt((xg - x)^2 + (yg - y)^2);'                                         newline ...
'mode = mode_prev;'                                                             newline ...
''                                                                              newline ...
'if valid < 0.5              % no pose received yet -> do not move'             newline ...
'    psi_ref = th; e_th = 0; mode = 1;'                                         newline ...
'    return'                                                                    newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'if mode == 1'                                                                  newline ...
'    if dist < tol_d, mode = 2; end'                                            newline ...
'elseif mode == 2'                                                              newline ...
'    if dist > 3*tol_d'                                                         newline ...
'        mode = 1;'                                                             newline ...
'    elseif abs(ssa(thg - th)) < tol_th'                                        newline ...
'        mode = 3;'                                                             newline ...
'    end'                                                                       newline ...
'else'                                                                          newline ...
'    if dist > 3*tol_d, mode = 1; end'                                          newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'if mode == 1'                                                                  newline ...
'    psi_ref = atan2(yg - y, xg - x);   % bearing to the goal point'            newline ...
'else'                                                                          newline ...
'    psi_ref = thg;                     % final heading'                        newline ...
'end'                                                                           newline ...
'e_th = ssa(thg - th);                  % final-heading error (for logging)'    newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'function a = ssa(a)'                                                           newline ...
'% smallest signed angle, [-pi, pi)'                                            newline ...
'a = mod(a + pi, 2*pi) - pi;'                                                   newline ...
'end']);

    for k = 1:4, L(ss, [ins{k} '/1'], sprintf('GuidanceLaw/%d',k)); end
    cs = {'XGoal','YGoal','ThGoal','TolD','TolTh'};
    for k = 1:numel(cs), L(ss, [cs{k} '/1'], sprintf('GuidanceLaw/%d',4+k)); end

    % 모드는 한 스텝 늦춰 되먹인다 (대수 루프 방지)
    add_block('simulink/Discrete/Unit Delay', [ss '/ModeDly'], ...
              'Position', [420 620 480 660], 'InitialCondition','1', 'SampleTime','Ts');
    L(ss, 'GuidanceLaw/4', 'ModeDly/1');
    L(ss, 'ModeDly/1', 'GuidanceLaw/10');

    L(ss, 'GuidanceLaw/1', 'psi_ref/1');
    L(ss, 'GuidanceLaw/2', 'dist/1');
    L(ss, 'GuidanceLaw/4', 'mode/1');

    tags = {'psi_ref','dist','e_th','mode'};
    for k = 1:4
        G(ss, tags{k}, 700, 300 + (k-1)*50);
        L(ss, sprintf('GuidanceLaw/%d',k), ['Go_' tags{k} '/1']);
    end
end

% =====================================================================
% 서브시스템 2 · Control (주황) — 속도 P + 선수각 P
%   입력  psi_ref, dist, mode, th      출력  v, w
% =====================================================================
function addControl(m, pos)
    ss = newSub(m, 'Control', pos);
    ins = {'psi_ref','dist','mode','th'};
    for k = 1:4, inP(ss, ins{k}, k); end
    outP(ss, 'v', 1);
    outP(ss, 'w', 2);

    C(ss,'KvC','Kv',       100, 280);
    C(ss,'VmaxC','v_max',  100, 330);
    C(ss,'KpsiC','Kpsi',   100, 380);
    C(ss,'WmaxC','w_max',  100, 430);

    addFcn(ss, 'HeadingSpeedCtrl', [350 40 560 480], [ ...
'function [v, w] = HeadingSpeedCtrl(psi_ref, dist, mode, th, Kv, v_max, Kpsi, w_max)' newline ...
'%#codegen'                                                                     newline ...
'% Heading control (P) and speed control (P on distance).'                     newline ...
'% turtlesim is kinematic: cmd_vel sets the velocity directly,'                 newline ...
'% so no yaw-rate (D) term or thrust model is needed here.'                     newline ...
''                                                                              newline ...
'e = mod(psi_ref - th + pi, 2*pi) - pi;     % heading error, [-pi, pi)'         newline ...
'w = min(max(Kpsi*e, -w_max), w_max);'                                          newline ...
''                                                                              newline ...
'if mode == 1'                                                                  newline ...
'    % slow down near the goal; do not drive while facing away from it'         newline ...
'    v = min(Kv*dist, v_max) * max(cos(e), 0);'                                 newline ...
'elseif mode == 2'                                                              newline ...
'    v = 0;                                  % turn on the spot'                newline ...
'else'                                                                          newline ...
'    v = 0;  w = 0;                          % done'                            newline ...
'end']);

    for k = 1:4, L(ss, [ins{k} '/1'], sprintf('HeadingSpeedCtrl/%d',k)); end
    cs = {'KvC','VmaxC','KpsiC','WmaxC'};
    for k = 1:numel(cs), L(ss, [cs{k} '/1'], sprintf('HeadingSpeedCtrl/%d',4+k)); end

    L(ss, 'HeadingSpeedCtrl/1', 'v/1');
    L(ss, 'HeadingSpeedCtrl/2', 'w/1');
    G(ss, 'v', 700, 300);
    G(ss, 'w', 700, 350);
    L(ss, 'HeadingSpeedCtrl/1', 'Go_v/1');
    L(ss, 'HeadingSpeedCtrl/2', 'Go_w/1');
end

% =====================================================================
% 서브시스템 · TurtlePlant (초록) — turtlesim 과 같은 운동학
%   입력  v, w      출력  x, y, th
% =====================================================================
function addPlant(m, pos)
    ss = newSub(m, 'TurtlePlant', pos);
    inP(ss, 'v', 1);  inP(ss, 'w', 2);
    outs = {'x','y','th'};
    for k = 1:3, outP(ss, outs{k}, k); end
    C(ss,'TsC','Ts', 100, 200);

    addFcn(ss, 'PlantEq', [300 40 480 300], [ ...
'function s_next = PlantEq(v, w, s, Ts)'                                        newline ...
'%#codegen'                                                                     newline ...
'% Same kinematics as turtlesim_node (turtle.cpp):'                             newline ...
'%   theta += w*dt,  x += v*cos(theta)*dt,  y += v*sin(theta)*dt'               newline ...
'% The turtle stops at the walls (0 .. 11.0889).'                               newline ...
'x = s(1);  y = s(2);  th = s(3);'                                              newline ...
'th = th + w*Ts;'                                                               newline ...
'th = mod(th + pi, 2*pi) - pi;'                                                 newline ...
'x  = x + v*cos(th)*Ts;'                                                        newline ...
'y  = y + v*sin(th)*Ts;'                                                        newline ...
'x  = min(max(x, 0), 11.088889);'                                               newline ...
'y  = min(max(y, 0), 11.088889);'                                               newline ...
's_next = [x; y; th];']);

    % 상태는 Unit Delay 에 보관 -> 제어기와 운동모델 사이 대수 루프가 없다
    add_block('simulink/Discrete/Unit Delay', [ss '/IntegDly'], ...
              'Position', [560 150 620 190], 'InitialCondition','x0', 'SampleTime','Ts');
    add_block('simulink/Signal Routing/Demux', [ss '/PlantOut'], ...
              'Position', [700 40 710 200], 'Outputs','3');

    L(ss, 'v/1', 'PlantEq/1');
    L(ss, 'w/1', 'PlantEq/2');
    L(ss, 'TsC/1', 'PlantEq/4');
    L(ss, 'PlantEq/1', 'IntegDly/1');
    L(ss, 'IntegDly/1', 'PlantEq/3');
    L(ss, 'IntegDly/1', 'PlantOut/1');
    for k = 1:3, L(ss, sprintf('PlantOut/%d',k), [outs{k} '/1']); end
end

% =====================================================================
% 서브시스템 · CmdPublisher (연보라) — v, w -> Twist -> /turtle1/cmd_vel
% =====================================================================
function addCmdPublisher(m, pos)
    ss = newSub(m, 'CmdPublisher', pos);
    inP(ss, 'v', 1);  inP(ss, 'w', 2);
    add_block('ros2lib/Blank Message', [ss '/BlankCmd'], 'Position', [100 200 200 240]);
    set_param([ss '/BlankCmd'], 'entityType','geometry_msgs/Twist', ...
              'messageType','geometry_msgs/Twist', 'SampleTime','Ts');
    add_block('simulink/Signal Routing/Bus Assignment', [ss '/AsgCmd'], ...
              'Position', [300 30 360 170]);
    set_param([ss '/AsgCmd'], 'AssignedSignals','linear.x,angular.z');
    add_block('ros2lib/Publish', [ss '/PubCmd'], 'Position', [450 80 550 120]);
    set_param([ss '/PubCmd'], 'topicSource','Specify your own', ...
              'topic','/turtle1/cmd_vel', 'messageType','geometry_msgs/Twist');
    L(ss, 'BlankCmd/1', 'AsgCmd/1');
    L(ss, 'v/1', 'AsgCmd/2');
    L(ss, 'w/1', 'AsgCmd/3');
    L(ss, 'AsgCmd/1', 'PubCmd/1');
end

% =====================================================================
% 서브시스템 · PoseSubscriber (연보라) — /turtle1/pose2d -> x, y, th, valid
% =====================================================================
function addPoseSubscriber(m, pos)
    ss = newSub(m, 'PoseSubscriber', pos);
    outs = {'x','y','th','valid'};
    for k = 1:4, outP(ss, outs{k}, k); end

    addSubscriber(ss, 'PoseSub', '/turtle1/pose2d', 'geometry_msgs/Pose2D', 50, 60);
    add_block('simulink/Signal Routing/Bus Selector', [ss '/Sel'], ...
              'Position',[250 60 300 200]);
    set_param([ss '/Sel'], 'OutputSignals', 'x,y,theta');

    addFcn(ss, 'RxLatch', [400 40 560 240], [ ...
'function [x, y, th, valid] = RxLatch(is_new, px, py, pth)'                    newline ...
'%#codegen'                                                                     newline ...
'% Before the first message arrives, Subscribe outputs an all-zero bus.'       newline ...
'% (0,0) is a real corner of the turtlesim window, so it cannot be told'       newline ...
'% apart by value. Latch the IsNew flag instead: valid = 0 until the'          newline ...
'% first message, and Guidance keeps the turtle still until then.'             newline ...
'persistent seen'                                                               newline ...
'if isempty(seen), seen = false; end'                                           newline ...
'if is_new, seen = true; end'                                                   newline ...
'x = px;  y = py;  th = pth;'                                                   newline ...
'valid = double(seen);']);

    L(ss, 'PoseSub/1', 'RxLatch/1');
    L(ss, 'PoseSub/2', 'Sel/1');
    for k = 1:3, L(ss, sprintf('Sel/%d',k), sprintf('RxLatch/%d',k+1)); end
    for k = 1:4, L(ss, sprintf('RxLatch/%d',k), [outs{k} '/1']); end
end

% =====================================================================
% 서브시스템 · Animate (회색) — 선이 없다. 태그 [x] [y] [th] 를 받는다
% =====================================================================
function addAnimate(m, pos)
    ss = newSub(m, 'Animate', pos);
    F(ss,'x','a',  50, 40);
    F(ss,'y','a',  50, 90);
    F(ss,'th','a', 50, 140);
    add_block('simulink/Sources/Digital Clock', [ss '/Clk'], ...
              'Position', [50 190 100 220], 'SampleTime','Ts');
    C(ss,'Anim','animate', 50, 240);
    addFcn(ss, 'AnimateFcn', [250 40 400 260], [ ...
'function ok = AnimateFcn(x, y, th, t, en)'                            newline ...
'%#codegen'                                                            newline ...
'% Live plot of the hull. Plotting is plain MATLAB, so it is'          newline ...
'% declared extrinsic.'                                                newline ...
'coder.extrinsic(''W02_animate'');'                                    newline ...
'ok = 1;'                                                              newline ...
'if en > 0.5'                                                          newline ...
'    W02_animate(x, y, th, t);'                                        newline ...
'end']);
    add_block('simulink/Sinks/Terminator', [ss '/AnimEnd'], 'Position', [480 140 500 160]);
    L(ss, 'Fr_x_a/1',  'AnimateFcn/1');
    L(ss, 'Fr_y_a/1',  'AnimateFcn/2');
    L(ss, 'Fr_th_a/1', 'AnimateFcn/3');
    L(ss, 'Clk/1',     'AnimateFcn/4');
    L(ss, 'Anim/1',    'AnimateFcn/5');
    L(ss, 'AnimateFcn/1', 'AnimEnd/1');
end

% =====================================================================
% 서브시스템 · Logging (회색) — 선이 없다. W02_plot.m 이 읽는 log_* 를 만든다
% =====================================================================
function addLogging(m, pos)
    ss = newSub(m, 'Logging', pos);
    sig = {'x','y','th','v','w','psi_ref','dist','e_th','mode'};
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

% 최상위 — Guidance 앞의 되먹임 태그와 Guidance -> Control 배선
function wireFront(m, xg, yg)
    fr = {'x','y','th','valid'};
    for k = 1:4
        F(m, fr{k}, 'g', xg, yg + (k-1)*50);
        L(m, ['Fr_' fr{k} '_g/1'], sprintf('Guidance/%d',k));
    end
    L(m, 'Guidance/1', 'Control/1');
    L(m, 'Guidance/2', 'Control/2');
    L(m, 'Guidance/3', 'Control/3');
end

% =====================================================================
% 2단계 — 오프라인 거북이
% =====================================================================
function build_offline()
    m = 'W02_2_goto_offline'; fresh(m);
    setSolver(m, 'T_end');

    addGuidance(m, [250 100 400 300]);
    addControl (m, [550 100 700 300]);
    addPlant   (m, [850 100 1000 300]);
    wireFront(m, 100, 110);

    F(m, 'th', 'c', 400, 330);
    L(m, 'Fr_th_c/1', 'Control/4');
    L(m, 'Control/1', 'TurtlePlant/1');
    L(m, 'Control/2', 'TurtlePlant/2');

    t = {'x','y','th'};
    for k = 1:3
        G(m, t{k}, 1100, 110 + (k-1)*60);
        L(m, sprintf('TurtlePlant/%d',k), ['Go_' t{k} '/1']);
    end
    C(m, 'Valid', '1', 1100, 330);
    G(m, 'valid', 1250, 330);
    L(m, 'Valid/1', 'Go_valid/1');

    addAnimate(m, [550 450 700 530]);
    addLogging(m, [850 450 1000 530]);

    note(m,'n1', ['W02 2단계  —  오프라인 거북이 (turtlesim 불필요)' newline ...
        'Guidance -> Control -> TurtlePlant.  되먹임은 [x] [y] [th] 태그' newline ...
        'Guidance · Control · 게인은 3단계 turtlesim 모델과 완전히 같다.  블록을 더블클릭하면 속이 보인다' newline ...
        '실행 전 >> W02_setup'], 100, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end

% =====================================================================
% 3단계 — 실제 turtlesim
% =====================================================================
function build_turtlesim()
    m = 'W02_3_goto_turtlesim'; fresh(m);
    load_system('ros2lib');
    setSolver(m, 'T_end');
    % turtlesim 은 실시간으로 돈다 -> Simulink 도 벽시계에 맞춘다
    set_param(m, 'EnablePacing','on', 'PacingRate','1');

    addGuidance(m, [250 100 400 300]);
    addControl (m, [550 100 700 300]);
    addCmdPublisher(m, [850 150 1000 250]);
    wireFront(m, 100, 110);

    F(m, 'th', 'c', 400, 330);
    L(m, 'Fr_th_c/1', 'Control/4');
    L(m, 'Control/1', 'CmdPublisher/1');
    L(m, 'Control/2', 'CmdPublisher/2');

    addPoseSubscriber(m, [850 330 1000 530]);
    t = {'x','y','th','valid'};
    for k = 1:4
        G(m, t{k}, 1100, 340 + (k-1)*50);
        L(m, sprintf('PoseSubscriber/%d',k), ['Go_' t{k} '/1']);
    end

    addAnimate(m, [250 450 400 530]);
    addLogging(m, [550 450 700 530]);

    note(m,'n1', ['W02 3단계  —  turtlesim 목표 자세 제어' newline ...
        'Guidance -> Control -> CmdPublisher(/turtle1/cmd_vel)  ·  PoseSubscriber(/turtle1/pose2d) -> [x] [y] [th] [valid]' newline ...
        'Guidance · Control · 게인은 2단계 오프라인 모델과 완전히 같다.  블록을 더블클릭하면 속이 보인다' newline ...
        '실행 전: (1) turtlesim_node  (2) ros2 run usv_basics turtle_pose_relay  (3) W02_setup'], 100, -60);

    save_system(m); close_system(m);
    fprintf('  %s 생성\n', m);
end
