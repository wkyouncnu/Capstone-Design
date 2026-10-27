function build_w09_models()
% BUILD_W09_MODELS  9주차 Simulink 모델을 생성한다.
%
%     W09_1_vrx.slx   VRX 연동 — 유도는 둘, 제어는 하나
%
%   이 주차의 모델은 **새로 짓지 않는다.** 5주차 `W05_1_vrx.slx` 를 복사해 와서
%   한 자리만 끊고 그 사이에 상자 하나를 끼운다.
%
%       5주차   Guidance ──────────────────────────────> InnerLoop -> Thrusters
%       9주차   Guidance -> AvoidSeam -> InnerLoop -> Thrusters
%                              ↑
%                     파이썬의 /vfh/command · /vfh/oa_flag
%
%   왜 복사인가 / why copy instead of rebuild
%       교수 지시 2026-10-27 — *"이미 이 강의 자료에서 개발한 헤딩 제어기 속도
%       제어기 등은 다 유지해 줘."* 다시 지으면 "같게 지었다" 고 말할 수밖에 없다.
%       복사하면 **같은 블록**이다. 헤딩 P-D 와 속도 PI 는 5주차에서 한 줄도
%       바뀌지 않고, 바뀐 것이 어디인지는 이 파일의 길이가 그대로 말해 준다.
%
%       원본 `W05_1_vrx.slx` 는 건드리지 않는다. save_system 의 두 번째 인자는
%       "다른 이름으로 저장" 이므로 메모리의 모델 이름만 바뀌고 원본 파일은 그대로다.
%
%   끼워 넣는 상자 둘
%     AvoidSeam      /vfh/command 의 회피 방위각과 /vfh/oa_flag 를 받아,
%                    LOS 의 psi_ref 와 둘 중 **어느 것을 쓸지 고른다** (유도·파랑)
%     GoalPublisher  지금 쫓는 웨이포인트를 ENU 로 바꿔 /usv/state/goal_enu 로 낸다.
%                    파이썬 회피기는 목표점을 모르면 "앞이 막혔는가" 를 판정할 수 없다
%
%   빼는 상자 하나
%     Animate        실시간 그림은 이 주차에서 **파이썬이 그린다** (ca_viz.py).
%                    궤적·장애물·헤딩 명령 넷을 극좌표로 겹쳐 보여야 하는데,
%                    장애물은 /scan 에 있고 그것은 파이썬 쪽 자료다
%
%   실행 전에 반드시 >> W09_setup 을 먼저 실행할 것.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', '_tools'));
cd(here);

if evalin('base', '~exist(''wp_north'',''var'')')
    error('먼저 W09_setup 을 실행하십시오.');
end

m = 'W09_1_vrx';
build_vrx(here, m);

%  배치 — 5주차와 같은 차례다. 사슬에 AvoidSeam 한 칸이 늘고,
%  포트 없는 상자가 둘(GoalPublisher · VizPublisher) 늘었다
boxes = {'GoalPublisher','VizPublisher','Logging','Observe','AutoStop'};
lay_chain(m, {'Guidance','AvoidSeam','InnerLoop','Thrusters','CmdPublisher','PoseSubscriber'}, ...
          'Boxes', boxes, 'Wrap', 3);

load_system(m);
paint_roles(m); check_colour(m);
mss_style(m); save_system(m); close_system(m, 0);

%  settle_links 는 선을 다시 그을 때마다 지적 수를 찍는다. 그 숫자는 **태그를
%  당겨 붙이기(snug_tags) 전** 의 것이라 블록겹침 11건이 그대로 남아 있다 —
%  바로 아래 두 줄이 지우는 것들이다. 중간 숫자를 그대로 찍으면 다 끝난 뒤에도
%  빌드 기록이 불합격처럼 보인다. 합격·불합격은 아래의 check_lines 하나가 말한다
%  (지적이 없으면 아무것도 찍지 않는다 — 조용한 빌드가 합격이다)
evalc('settle_links(m)');
load_system(m); snug_tags(m);
pack_boxes(m, boxes);
scope_legend(m);
save_system(m);
check_lines(m, false); export_diagram(m);
close_system(m, 0);

%  속 그림 — 이 주차에 새로 생긴 상자 셋만 따로 뽑는다. 나머지는 5주차 그림이 그대로 맞다
for nm = {'AvoidSeam','GoalPublisher','VizPublisher'}
    f = export_diagram(m, '', nm{1});
    movefile(f, fullfile(here, 'img', [nm{1} '.png']), 'f');
end
fprintf('  W09_1_vrx      생성\n');
end

% =====================================================================
% 복사하고, 한 자리를 끊고, 상자 둘을 끼운다
% =====================================================================
function build_vrx(here, m)
    src = fullfile(here, '..', 'W05_simulink', 'W05_1_vrx.slx');
    dst = fullfile(here, [m '.slx']);
    assert(isfile(src), '5주차 모델이 없다: %s', src);

    try, close_system(m, 0);           catch, end
    try, close_system('W05_1_vrx', 0); catch, end
    if isfile(dst), delete(dst); end

    load_system(src);
    save_system('W05_1_vrx', dst);     % 다른 이름으로 저장 — 원본 파일은 그대로다
    load_system('ros2lib');

    % --- 1) 이 주차에서 쓰지 않는 상자를 뺀다 --------------------------
    %  실시간 그림은 파이썬이 그린다. W05_animate 는 5주차 폴더에 있어서
    %  경로까지 끌고 와야 하는데, 끌고 와서 보여 줄 것이 장애물 빼고는 없다
    delete_block([m '/Animate']);
    delete_block([m '/Observe']);      % 아래에서 회피 칸을 더해 다시 짓는다
    delete_block([m '/Logging']);      % 같은 이유 — psi_los·psi_oa·oa 를 더한다

    % --- 2) 유도와 제어 사이를 끊는다 ----------------------------------
    %  이 한 줄이 이 주차의 전부다. 5주차에서는 Guidance 의 psi_ref 가 곧장
    %  InnerLoop 로 갔다. 그 가지만 끊는다 — Goto 로 가는 가지는 **남긴다**.
    %  로그에서 "LOS 가 무슨 명령을 내고 있었나" 를 끝까지 볼 수 있어야 하기 때문이다
    ph = get_param([m '/InnerLoop'], 'PortHandles');
    assert(cut_line(m, ph.Inport(1)), 'Guidance -> InnerLoop 가지를 끊지 못했다');

    %  2번(gate) 은 끊지 않고 **태그로 바꾼다**. 5주차에서는 Guidance 에서 InnerLoop
    %  까지 곧장 갔는데, 그 사이에 AvoidSeam 이 들어서면서 선이 상자를 가로지른다.
    %  교수 지시 2026-10-01 — *"태그를 신호 옆에 모아 꺾임을 없앨 것."*
    %  Go_gate 는 5주차에서 이미 달려 있으므로 받는 쪽만 From 으로 세운다
    assert(cut_line(m, ph.Inport(2)), 'Guidance -> InnerLoop gate 가지를 끊지 못했다');
    add_block('simulink/Signal Routing/From', [m '/Fr_gate'], ...
              'GotoTag','gate', 'Position',[860 300 940 325]);
    add_line(m, 'Fr_gate/1', 'InnerLoop/2', 'autorouting','on');

    %  남긴 가지의 이름을 바꾼다. 이제 psi_ref 는 "제어기가 실제로 받은 명령" 이고,
    %  LOS 가 낸 것은 psi_los 다. 둘이 갈라지는 구간이 곧 회피 구간이다
    set_param([m '/Go_psi_ref'], 'GotoTag', 'psi_los');
    set_param([m '/Go_psi_ref'], 'Name',    'Go_psi_los');

    % --- 3) 이음새 ------------------------------------------------------
    addAvoidSeam(m, 700, 60);
    add_line(m, 'Guidance/1',  'AvoidSeam/1', 'autorouting','on');
    add_line(m, 'AvoidSeam/1', 'InnerLoop/1', 'autorouting','on');

    G(m, 'psi_ref', 940,  70);
    G(m, 'psi_oa',  940, 115);
    G(m, 'oa',      940, 160);
    add_line(m, 'AvoidSeam/1', 'Go_psi_ref/1', 'autorouting','on');
    add_line(m, 'AvoidSeam/2', 'Go_psi_oa/1',  'autorouting','on');
    add_line(m, 'AvoidSeam/3', 'Go_oa/1',      'autorouting','on');

    % --- 4) 목표점 발행 -------------------------------------------------
    addGoalPublisher(m, 1660, 1100);
    addVizPublisher(m, 1660, 1300);

    % --- 5) 로깅·화면 ---------------------------------------------------
    addLogging(m, 2400, 60);
    addObserve(m, {'psi_ref','psi'; 'psi_los','psi_oa'; '','oa'; '','y_e'; '','wp_idx'}, ...
               2750, 1800);

    % --- 6) 설명 --------------------------------------------------------
    retitle(m, ['W09 실습 D  —  LOS 와 파이썬 회피를 한 제어기에 (Gazebo 필요)' newline ...
        'Guidance -> AvoidSeam -> Inner Loop -> Thrusters -> Gazebo -> Navigation' newline ...
        '' newline ...
        '제어는 5주차 그대로다. 헤딩 P-D 와 속도 PI 는 블록 하나도 바뀌지 않았다.' newline ...
        '바뀐 것은 **제어기에 들어가는 명령을 누가 내는가** 하나뿐이다.' newline ...
        '  oa_flag 가 0 : LOS 가 낸 psi_los 가 그대로 간다 (5주차와 완전히 같다)' newline ...
        '  oa_flag 가 1 : 파이썬이 낸 psi_oa 가 대신 간다' newline ...
        '로그의 psi_los 와 psi_ref 가 갈라지는 구간이 회피 구간이다.' newline ...
        '' newline ...
        '실행 전: (1) W09_setup  (2) bash run_vrx_ca.sh  (3) bash run_ca_nodes.sh'], ...
        250, -330);
    %  -330 인 까닭 — 이 주차의 설명은 5주차의 것보다 길어서 열한 줄(약 132 px)이다.
    %  -130 에 두면 상자가 [250 -130 590 2] 를 차지해 태그 줄(Go_x_e, y = -8..18)과
    %  겹친다. 240 px 를 더 올려 태그 줄 위로 완전히 비킨다

    save_system(m); close_system(m);
end

% =====================================================================
% AVOIDSEAM — 어느 헤딩 명령을 쓸 것인가
% =====================================================================
function addAvoidSeam(m, x, y)
% 이음새 — 포트 psi_los -> psi_ref, psi_oa, oa
%
%   하는 일은 고르기 하나다. 그래서 제어가 아니라 **유도(파랑)** 다.
%
%   왜 Switch 가 도면에 보이는가 / why the choice is a visible block
%       교수 지시 2026-10-14 — *"ssa 도 이렇게 간단하게."* 뜻이 있는 계산은
%       MATLAB Function 안에 숨기지 않고 도면에 보이게 둔다. 이 주차에서 뜻이
%       있는 것은 단 하나, **둘 중 하나를 고른다** 는 것이다. 그것을 코드 한 줄로
%       숨기면 이 주차의 그림에 남는 것이 없다.
%
%   세 갈래를 세 블록으로 나눈 까닭
%       Take = oa_flag AND fresh.  파이썬이 "피하는 중" 이라 말하는 것과, 그 말이
%       **아직 유효한가** 는 다른 문제다. 노드가 죽으면 마지막 oa_flag=true 가
%       Subscribe 의 출력에 그대로 남아, 배는 죽은 명령을 영원히 따라간다.
%       그래서 /vfh/command 가 몇 초 안 왔는지(Age) 를 재서 함께 묻는다.
%       파이썬 회피기도 /scan 에 같은 가드를 두고 있다 (sensor_timeout_sec).
%
%   ENU -> NED
%       파이썬은 ENU 로 말한다 (0 = 동, 반시계 +). 이 과목의 제어는 NED 다
%       (0 = 북, 시계 +).  psi_NED = ssa(pi/2 - psi_ENU).  한 번 더 걸면 제자리로
%       돌아오는 변환이라, 어느 쪽으로 걸었는지 헷갈리면 네 방위로 재 보면 된다.
%   왜 cmd_new 만 태그로 가는가 / why one signal travels as a tag
%       IsNew(CmdSub 1번) 는 도면의 맨 위에서 나와 맨 아래의 Age 되묶기 포트로
%       들어간다. 선으로 끌면 그 사이의 상자 다섯을 가로지른다.
%       교수 지시 2026-10-01 — *"태그를 신호 옆에 모아 꺾임을 없앨 것."*
%       받는 쪽 From 을 되묶기 포트 바로 왼쪽에 세우면 선이 직선 한 줄이 된다.
%
%   한 군데는 선이 직각으로 교차한다 — psi_los 의 가로줄(y=250)과 ToD -> Pick 의
%   세로줄(x=985). Switch 세 포트가 서로 다른 줄에서 들어오니 피할 길이 없다.
%   직각 교차는 배선 검사의 일곱 항목에 들지 않는다 (겹침·관통과 다른 것이다).
    s = add_subsys(m, 'AvoidSeam', [x y x+190 y+120], {'psi_los'}, ...
                   {'psi_ref','psi_oa','oa'}, gnc_colour('guidance'));

    %  add_subsys 가 포트를 기본 자리(입력 x=60, 출력 x=700)에 떨어뜨린다.
    %  그 자리는 아래 상자들과 겹치므로 네 포트를 먼저 제자리에 놓는다
    set_param([s '/psi_los'], 'Position',[  60 240   90 260]);
    set_param([s '/psi_oa' ], 'Position',[1160  30 1190  50]);
    set_param([s '/psi_ref'], 'Position',[1160 180 1190 200]);
    set_param([s '/oa'     ], 'Position',[1160 460 1190 480]);

    % ---- 회피 방위각 : /vfh/command 의 angular.z ----------------------
    %  높이를 120 으로 둔다 — IsNew(1번, y=90) 와 Msg(2번, y=130) 가 40 px 떨어져야
    %  Go_new 의 이름표가 Msg 선 위에 올라앉지 않는다
    add_block('ros2lib/Subscribe', [s '/CmdSub'], 'Position',[80 50 210 170]);
    set_param([s '/CmdSub'], 'topicSource','Specify your own', ...
        'topic','/vfh/command', 'messageType','geometry_msgs/Twist', ...
        'sampleTime','Ts_ctrl');

    add_block('simulink/Signal Routing/Goto', [s '/Go_new'], ...
              'GotoTag','cmd_new', 'Position',[240 78 320 102]);

    add_block('simulink/Signal Routing/Bus Selector', [s '/SelCmd'], ...
              'Position',[380 110 430 150]);
    set_param([s '/SelCmd'], 'OutputSignals','angular.z');

    add_block('simulink/User-Defined Functions/Fcn', [s '/EnuToNed'], ...
              'Position',[500 112 640 148]);
    set_param([s '/EnuToNed'], 'Expr','atan2(sin(pi/2-u), cos(pi/2-u))');

    % ---- 회피 중인가 : /vfh/oa_flag ------------------------------------
    add_block('ros2lib/Subscribe', [s '/FlagSub'], 'Position',[80 300 210 360]);
    set_param([s '/FlagSub'], 'topicSource','Specify your own', ...
        'topic','/vfh/oa_flag', 'messageType','std_msgs/Bool', ...
        'sampleTime','Ts_ctrl');

    add_block('simulink/Signal Routing/Bus Selector', [s '/SelFlag'], ...
              'Position',[380 320 430 360]);
    set_param([s '/SelFlag'], 'OutputSignals','data');

    % ---- 그 말이 아직 유효한가 : 명령이 끊긴 지 몇 초인가 --------------
    %  level 로 되묶는다 — 새 메시지가 오는 동안(IsNew=1) 적분기를 0 에 묶어 두고,
    %  끊기면(IsNew=0) 그때부터 초를 센다. rising 으로 두면 매 스텝 1 인 동안
    %  상승 에지가 없어 영원히 셈이 늘어난다 (AutoStop 의 HeldFor 와 같은 꼴).
    %  되묶기 포트는 상자 **왼쪽 변**에 있다 (아래 변이 아니다 — HeldFor 에서 실측)
    add_block('simulink/Sources/Constant', [s '/One'], ...
              'Value','1', 'Position',[360 408 440 432]);
    add_block('simulink/Signal Routing/From', [s '/Fr_new'], ...
              'GotoTag','cmd_new', 'Position',[430 448 510 472]);
    add_block('simulink/Discrete/Discrete-Time Integrator', [s '/Age'], ...
              'Position',[540 380 620 500]);
    set_param([s '/Age'], 'IntegratorMethod','Integration: Forward Euler', ...
        'SampleTime','Ts_ctrl', 'ExternalReset','level', 'InitialCondition','0');
    add_block('simulink/Sources/Constant', [s '/TimeOut'], ...
              'Value','oa_timeout', 'Position',[540 548 640 572]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', ...
              [s '/Fresh'], 'Operator','<', 'Position',[660 420 700 480]);

    % ---- 둘을 함께 묻는다 ---------------------------------------------
    add_block('simulink/Logic and Bit Operations/Logical Operator', [s '/Take'], ...
              'Operator','AND', 'Inputs','2', 'Position',[810 320 850 380]);
    add_block('simulink/Signal Attributes/Data Type Conversion', [s '/ToD'], ...
              'OutDataTypeStr','double', 'Position',[900 332 950 368]);

    % ---- 고른다 --------------------------------------------------------
    %  높이 240 — 세 포트가 각각 회피(y=130) · 판단(y=190) · LOS(y=250) 줄에 맞는다
    add_block('simulink/Signal Routing/Switch', [s '/Pick'], ...
              'Position',[1020 70 1060 310]);
    set_param([s '/Pick'], 'Criteria','u2 >= Threshold', 'Threshold','0.5');

    %  배선은 전부 lane_line 으로 — 통로 x 를 신호마다 다르게 주어 겹침을 없앤다.
    %  마지막 인자가 0 이면 "통로가 필요 없다", 즉 양 끝이 같은 높이라 직선이다
    % 배선 — 회피 방위각
    lane_line(s, 'CmdSub',   2, 'SelCmd',   1, 0);      % 직선  y=130
    lane_line(s, 'SelCmd',   1, 'EnuToNed', 1, 0);      % 직선  y=130
    lane_line(s, 'CmdSub',   1, 'Go_new',   1, 0);      % 직선  y=90
    % 배선 — 깃발
    lane_line(s, 'FlagSub',  2, 'SelFlag',  1, 0);      % 직선  y=340
    lane_line(s, 'SelFlag',  1, 'Take',     1, 0);      % 직선  y=340
    % 배선 — 나이
    lane_line(s, 'One',      1, 'Age',      1, 0);      % 직선  y=420
    lane_line(s, 'Fr_new',   1, 'Age',      2, 0);      % 직선  y=460  (되묶기)
    lane_line(s, 'Age',      1, 'Fresh',    1, 0);      % 직선  y=440
    lane_line(s, 'TimeOut',  1, 'Fresh',    2, 640);    % 꺾임 1 — Age·Fresh 사이 틈
    lane_line(s, 'Fresh',    1, 'Take',     2, 755);
    lane_line(s, 'Take',     1, 'ToD',      1, 0);      % 직선  y=350
    % 배선 — 고르기.  1번 = 회피, 2번 = 판단, 3번 = LOS
    lane_line(s, 'EnuToNed', 1, 'Pick',     1, 0);      % 직선  y=130
    lane_line(s, 'ToD',      1, 'Pick',     2, 985);
    lane_line(s, 'psi_los',  1, 'Pick',     3, 0);      % 직선  y=250, 도면을 가로지른다
    % 배선 — 내보내기.  둘은 가지다 — Pick 의 위·아래로 돌아 나간다
    lane_line(s, 'Pick',     1, 'psi_ref',  1, 0);      % 직선  y=190
    lane_line(s, 'EnuToNed', 1, 'psi_oa',   1, 800);
    lane_line(s, 'ToD',      1, 'oa',       1, 1000);

    add_block('built-in/Note', [s '/note'], 'Position',[80 640], 'Text', sprintf([ ...
        '이음새 — 제어기에 들어가는 명령을 누가 내는가.\n' ...
        '\n' ...
        '  Pick 의 2번(판단)이 0.5 보다 작으면 3번(LOS) 을, 크면 1번(회피) 을 낸다.\n' ...
        '  판단 = oa_flag AND (명령이 끊긴 지 %s 초보다 적다)\n' ...
        '\n' ...
        '토픽 둘 — 둘 다 받기만 한다. 이 모델은 회피 쪽으로 아무것도 보내지 않는다.\n' ...
        '  /vfh/command   geometry_msgs/Twist  angular.z = 절대 방위각 (ENU, rad)\n' ...
        '  /vfh/oa_flag   std_msgs/Bool        피하는 중이면 true\n' ...
        '\n' ...
        'oa_flag 는 거리 문턱이 아니다. "목표까지 직진 통로가 막혔는가" 의 답이다.\n' ...
        '그래서 장애물이 8 m 옆에 있어도 통로가 열려 있으면 0 이고,\n' ...
        '30 m 앞이 막혀 있으면 1 이다.'], 'oa_timeout'));
end

% =====================================================================
% GOALPUBLISHER — 파이썬에게 "어디로 가려는가" 를 알려 준다
% =====================================================================
function addGoalPublisher(m, x, y)
% 포트 없는 상자. 웨이포인트 번호는 안에서 From 으로 받는다.
%
%   왜 필요한가 / why the avoider needs a goal
%       회피기는 "앞이 막혔는가" 를 판정한다. 그 '앞' 이 어디인지는 목표점이
%       있어야 정해진다. 연구실 원본 런치는 goal_publisher_enu 노드가 이것을
%       냈는데, 이 주차에서는 웨이포인트를 시뮬링크가 쥐고 있으므로 시뮬링크가 낸다.
%       파이썬 쪽에서 그 노드를 띄우면 목표점이 둘이 되어 서로를 덮어쓴다 —
%       run_ca_nodes.sh 가 그 노드를 일부러 띄우지 않는 까닭이다.
%
%   좌표계가 여기서 한 번 바뀐다
%       시뮬링크의 웨이포인트는 **스폰 원점 기준 NED** 다 (x 북, y 동).
%       파이썬은 **월드 ENU** 로 말한다 (x 동, y 북). 그래서
%           ENU x = (웨이포인트 동) + origin_east
%           ENU y = (웨이포인트 북) + origin_north
%
%   한 칸 어긋나면 배가 제자리에서 돈다 — 2026-10-27 에 걸렸다
%       유도부가 내는 wp_idx 는 **구간 번호** 다. 구간 k 는 k 번 점에서 k+1 번 점으로
%       간다 (W05 GuidanceLaw 의 `xk1 = wp_x(k+1)`). 그래서 목표점은 wp(idx) 가
%       아니라 **wp(idx+1)** 이다. wp(idx) 를 내보냈더니 파이썬에게 건네진 목표가
%       언제나 배 **뒤** 에 있었고, 회피기는 "뒤로 돌아라" 를 내고 LOS 는 앞으로
%       끌어 배가 북 294 m 에서 제자리걸음을 했다. 회피처럼 보이지만 회피가 아니다.
    s = add_subsys(m, 'GoalPublisher', [x y x+160 y+80], {}, {}, gnc_colour('ros'));

    add_block('simulink/Signal Routing/From', [s '/Fr_wp_idx'], ...
              'GotoTag','wp_idx', 'Position',[60 100 130 125]);

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [s '/Goal'], 'Position',[300 80 480 340]);
    setFcn(s, 'Goal', [ ...
'function [ex, ey] = Goal(idx, wn, we, orgN, orgE)'                            newline ...
'%#codegen'                                                                    newline ...
'% 지금 쫓는 웨이포인트를 월드 ENU 로 바꾼다.'                                 newline ...
'%   들어오는 것  idx  유도부가 달리고 있는 **구간 번호** (1..n-1)'             newline ...
'%   나가는 것    ex   ENU x = 동,   ey   ENU y = 북'                           newline ...
''                                                                             newline ...
'n = numel(wn);'                                                               newline ...
'k = min(max(round(idx), 1) + 1, n);  % 구간 k 의 **끝점**(k+1 번 점) 이 목표다' newline ...
''                                                                             newline ...
'ex = we(k) + orgE;'                                                           newline ...
'ey = wn(k) + orgN;']);
    set_param([s '/Goal'], 'Position', [300 80 480 340]);

    add_block('simulink/Sources/Constant', [s '/wn'], ...
              'Value','wp_north', 'Position',[150 160 250 190]);
    add_block('simulink/Sources/Constant', [s '/we'], ...
              'Value','wp_east',  'Position',[150 210 250 240]);
    add_block('simulink/Sources/Constant', [s '/orgN'], ...
              'Value','origin_north', 'Position',[150 260 250 290]);
    add_block('simulink/Sources/Constant', [s '/orgE'], ...
              'Value','origin_east',  'Position',[150 310 250 340]);

    %  From 은 1번 포트 높이로 옮기고, 상수 넷은 자기 포트 높이로 옮긴다 -> 선이 전부 직선
    align_to(s, 'Fr_wp_idx', 'Outport', port_xy(s, 'Goal', 'Inport', 1));
    add_line(s, 'Fr_wp_idx/1', 'Goal/1');
    row_feed(s, 'Goal', {'', 'wn', 'we', 'orgN', 'orgE'});

    %  Point 메시지 하나에 x·y 를 함께 넣는다 — Bus Assignment 한 블록으로 된다
    add_block('ros2lib/Blank Message', [s '/BlankGoal'], 'Position',[560 140 660 180]);
    set_param([s '/BlankGoal'], 'entityType','geometry_msgs/Point', ...
        'messageType','geometry_msgs/Point', 'SampleTime','Ts_ctrl');

    add_block('simulink/Signal Routing/Bus Assignment', [s '/AsgGoal'], ...
              'Position',[740 120 820 220]);
    set_param([s '/AsgGoal'], 'AssignedSignals','x,y');

    add_block('ros2lib/Publish', [s '/PubGoal'], 'Position',[920 150 1040 190]);
    set_param([s '/PubGoal'], 'topicSource','Specify your own', ...
        'topic','/usv/state/goal_enu', 'messageType','geometry_msgs/Point');

    align_to(s, 'BlankGoal', 'Outport', port_xy(s, 'AsgGoal', 'Inport', 1));
    align_to(s, 'PubGoal',   'Inport',  port_xy(s, 'AsgGoal', 'Outport', 1));
    add_line(s, 'BlankGoal/1', 'AsgGoal/1');
    add_line(s, 'AsgGoal/1',   'PubGoal/1');
    add_line(s, 'Goal/1', 'AsgGoal/2', 'autorouting','on');
    add_line(s, 'Goal/2', 'AsgGoal/3', 'autorouting','on');

    add_block('built-in/Note', [s '/note'], 'Position',[60 420], 'Text', sprintf([ ...
        '목표점 발행 — 파이썬 회피기가 "앞이 막혔는가" 를 판정하는 데 쓴다.\n' ...
        '  /usv/state/goal_enu   geometry_msgs/Point   x = 동, y = 북 (월드 ENU)\n' ...
        '\n' ...
        '좌표계가 여기서 한 번 바뀐다.\n' ...
        '  시뮬링크  스폰 원점 기준 NED — wp_north(k), wp_east(k)\n' ...
        '  파이썬    월드 ENU          — x = 동 + origin_east, y = 북 + origin_north\n' ...
        '\n' ...
        '같은 일을 하는 파이썬 노드(goal_publisher_enu) 는 띄우지 않는다.\n' ...
        '둘이 같은 토픽에 쓰면 서로를 덮어쓴다.']));
end

% =====================================================================
% 로깅 · 화면
% =====================================================================
function addLogging(m, x, y)
%  5주차 목록에 회피 신호 셋을 더했다 — psi_los, psi_oa, oa.
%  psi_ref 는 이제 "제어기가 실제로 받은 명령" 이다
    sig = {'x_n','y_n','psi','psi_ref','psi_los','psi_oa','oa', ...
           'y_e','x_e','beta','chi','u','r','U','gate','FL','FR','n','F_err','wp_idx'};
    tag = {'x_n','y_n','psi','psi_ref','psi_los','psi_oa','oa', ...
           'y_e','x_e','beta','chi','u','r','U','gate','FL','FR','nprop','Ferr','wp_idx'};
    add_logging_box(m, sig, tag, [x y], 'Ts_ctrl');
end

function addObserve(m, pairs, x, y)
%  포트 없는 상자. 신호는 안에서 From 으로 받는다 — 5주차 addCompareScope 와 같은 꼴.
%  칸이 하나 늘었다: psi_los 와 psi_oa 를 겹쳐 보면 **언제 갈라졌나** 가 보인다
    nAx = size(pairs,1);
    s   = add_subsys(m, 'Observe', [x y x+170 y+90], {}, {}, gnc_colour('logging'));
    sc  = [s '/Scope'];

    ROW = 120;  GAP = 60;
    add_block('simulink/Sinks/Scope', sc, 'Position',[360 60 410 60+ROW*nAx]);
    set_param(sc, 'NumInputPorts', num2str(nAx));
    for i = 1:nAx
        ref = pairs{i,1};  act = pairs{i,2};  yi = 60 + ROW*(i-1);
        if isempty(ref)
            nm = from_name(s, act);
            add_block('simulink/Signal Routing/From', [s '/' nm], ...
                      'GotoTag', act, 'Position',[60 yi 130 yi+25]);
            add_line(s, [nm '/1'], sprintf('Scope/%d', i), 'autorouting','on');
        else
            add_block('simulink/Signal Routing/Mux', sprintf('%s/MuxSc%d', s, i), ...
                      'Inputs','2', 'Position',[250 yi 255 yi+GAP+25]);
            n1 = from_name(s, ref);
            add_block('simulink/Signal Routing/From', [s '/' n1], ...
                      'GotoTag', ref, 'Position',[60 yi 130 yi+25]);
            n2 = from_name(s, act);
            add_block('simulink/Signal Routing/From', [s '/' n2], ...
                      'GotoTag', act, 'Position',[60 yi+GAP 130 yi+GAP+25]);
            add_line(s, [n1 '/1'], sprintf('MuxSc%d/1', i), 'autorouting','on');
            add_line(s, [n2 '/1'], sprintf('MuxSc%d/2', i), 'autorouting','on');
            add_line(s, sprintf('MuxSc%d/1', i), sprintf('Scope/%d', i), 'autorouting','on');
        end
    end
end

% =====================================================================
% 공통 헬퍼 — 5주차 빌더와 같은 것들
% =====================================================================
function setFcn(sys, path, code)
    S  = sfroot;
    fpos = get_param([sys '/' path], 'Position');
    ch = S.find('-isa','Stateflow.EMChart','Path',[sys '/' path]);
    ch.Script = code;
    set_param([sys '/' path], 'Position', fpos);
end

function G(m, tag, x, y)
    add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

function retitle(m, txt, x, y)
%  복사본은 5주차의 설명을 달고 온다. 그것을 지우고 이 주차의 것을 붙인다.
%  built-in/Note 는 블록이 아니라 주석(annotation) 으로 저장되므로 FindAll 로 찾는다
    A = find_system(m, 'FindAll','on', 'SearchDepth',1, 'Type','annotation');
    for i = 1:numel(A)
        try, delete(A(i)); catch, end
    end
    add_block('built-in/Note', [m '/n1'], 'Position',[x y x y], 'Text', txt);
end

% =====================================================================
% 그림용 발행 — 모델만 아는 값 둘을 파이썬 그림판에 넘긴다
% =====================================================================
%  ca_viz.py 의 극좌표 그림에는 선이 넷이다. 그중 둘(현재 헤딩·회피 명령)은
%  파이썬이 이미 갖고 있지만, **LOS 가 낸 명령과 제어기가 실제로 받은 명령**은
%  시뮬링크 안에만 있다. 이 두 개를 내보내지 않으면 그림의 초록·검정 선이
%  영영 그려지지 않는다 (2026-10-27 에 실제로 비어 있었다).
%
%  단위는 **라디안·NED 그대로** 내보낸다. ENU 로 바꾸지 않는다 —
%  ca_viz.py 가 "Simulink 쪽은 이미 NED 다" 라고 적고 그대로 쓴다.
%  바깥에서 들어오는 /vfh/command 만 ENU 라 AvoidSeam 에서 한 번 돌린다.
function addVizPublisher(m, x, y)
    s = add_subsys(m, 'VizPublisher', [x y x+160 y+80], {}, {}, gnc_colour('ros'));

    %  {태그, 토픽, 설명} — 둘 다 똑같은 네 블록짜리 줄이다
    rows = { 'psi_los', '/sim/psi_los', 'LOS 가 낸 명령'
             'psi_ref', '/sim/psi_cmd', '제어기가 실제로 받은 명령' };

    for k = 1:size(rows,1)
        tag = rows{k,1};  topic = rows{k,2};  dy = (k-1)*200;
        fr  = ['Fr_'    tag];  bl = ['Blank_' tag];
        asg = ['Asg_'   tag];  pb = ['Pub_'   tag];

        add_block('simulink/Signal Routing/From', [s '/' fr], ...
                  'GotoTag', tag, 'Position',[60 100+dy 150 125+dy]);

        add_block('ros2lib/Blank Message', [s '/' bl], ...
                  'Position',[300 90+dy 400 130+dy]);
        set_param([s '/' bl], 'entityType','std_msgs/Float64', ...
                  'messageType','std_msgs/Float64', 'SampleTime','Ts_ctrl');

        add_block('simulink/Signal Routing/Bus Assignment', [s '/' asg], ...
                  'Position',[480 80+dy 560 170+dy]);
        set_param([s '/' asg], 'AssignedSignals','data');

        add_block('ros2lib/Publish', [s '/' pb], ...
                  'Position',[660 100+dy 780 140+dy]);
        set_param([s '/' pb], 'topicSource','Specify your own', ...
                  'topic', topic, 'messageType','std_msgs/Float64');

        add_line(s, [bl  '/1'], [asg '/1'], 'autorouting','on');
        add_line(s, [fr  '/1'], [asg '/2'], 'autorouting','on');
        add_line(s, [asg '/1'], [pb  '/1'], 'autorouting','on');
    end

    add_block('built-in/Note', [s '/note'], 'Position',[60 460], 'Text', sprintf([ ...
        '그림용 발행 — 제어에는 쓰이지 않는다' newline ...
        '' newline ...
        '  /sim/psi_los   LOS 가 낸 명령        [rad, NED]' newline ...
        '  /sim/psi_cmd   제어기가 받은 명령    [rad, NED]' newline ...
        '' newline ...
        'ca_viz.py 가 이 둘을 받아 극좌표에 초록 점선·검정 실선으로 그린다.' newline ...
        '두 선이 갈라져 있는 동안이 곧 회피 구간이다.' newline ...
        '단위를 ENU 로 바꾸지 않는다 — 받는 쪽이 NED 로 읽는다.']));
end
