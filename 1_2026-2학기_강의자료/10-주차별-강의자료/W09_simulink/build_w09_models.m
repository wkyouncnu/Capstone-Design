function build_w09_models()
% BUILD_W09_MODELS  9주차 Simulink 모델을 생성한다.
%
%     W09_1_vrx.slx   VRX 연동 — 유도는 둘, 제어는 하나
%
%   이 주차의 모델은 **새로 짓지 않는다.** 5주차 `W05_1_vrx.slx` 를 복사해 와서
%   한 자리만 끊고 그 사이에 상자 하나를 끼운다.
%
%       5주차   Guidance ──────────────────────────────> InnerLoop -> Thrusters
%       9주차   Guidance -> AvoidSeam -> InnerLoop ─────────────> (토픽)
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
%   빼는 상자 둘
%     Animate        실시간 그림은 이 주차에서 **파이썬이 그린다** (ca_viz.py).
%                    궤적·장애물·헤딩 명령 넷을 극좌표로 겹쳐 보여야 하는데,
%                    장애물은 /scan 에 있고 그것은 파이썬 쪽 자료다
%     Thrusters      5주차의 Plugin 칸은 가제보 추진기 플러그인이 하는 계산
%                    (포화 · 추력->회전수 · 검산)을 **옮겨 적은 것**이다. 가제보가
%                    같은 계산을 스스로 하므로 VRX 연동에서는 지령이 그대로 지나간다.
%                    5주차에서는 오프라인 쌍둥이와 견주려고 두었으나 이 주차에는
%                    쌍둥이가 없다 — 배분이 낸 추력을 곧장 토픽으로 보낸다
%                    (교수 지시 2026-11-17)
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
lay_chain(m, {'Guidance','AvoidSeam','InnerLoop','CmdPublisher','PoseSubscriber'}, ...
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

%  속 그림 — 이 주차에 바뀐 상자만 따로 뽑는다. 나머지는 5주차 그림이 그대로 맞다.
%  InnerLoop 는 새로 생긴 것이 아니라 **고쳐진** 것이다 (속력 스위치·6주차 배분) —
%  이름이 5주차 것과 겹치지 않게 W09_ 를 붙여 저장한다
for nm = {'AvoidSeam','GoalPublisher','VizPublisher'}
    f = export_diagram(m, '', nm{1});
    movefile(f, fullfile(here, 'img', [nm{1} '.png']), 'f');
end
f = export_diagram(m, '', 'InnerLoop');
movefile(f, fullfile(here, 'img', 'W09_InnerLoop.png'), 'f');
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

    % --- 4) 선수추진기 — 6주차 추력배분을 가져와 붙인다 -----------------
    addBowThrust(here, m);

    % --- 5) 목표점 발행 -------------------------------------------------
    addGoalPublisher(m, 1660, 1100);
    addVizPublisher(m, 1660, 1300);

    % --- 6) 로깅·화면 ---------------------------------------------------
    addLogging(m, 2400, 60);
    addObserve(m, {'psi_ref','psi'; 'psi_los','psi_oa'; '','oa'; 'u_oa','u'; '','y_e'; '','FB'; '','wp_idx'}, ...
               2750, 1800);

    % --- 7) 설명 --------------------------------------------------------
    retitle(m, ['W09 실습 D  —  LOS 와 파이썬 회피를 한 제어기에 (Gazebo 필요)' newline ...
        'Guidance -> AvoidSeam -> Inner Loop -> Gazebo -> Navigation' newline ...
        '' newline ...
        '제어기의 식은 5주차 그대로다 — 헤딩 P-D 와 속도 PI 의 이득도 블록도 같다.' newline ...
        '달라진 것은 그 앞에 붙은 스위치 둘뿐이다 (방위각 Pick · 속력 PickU).' newline ...
        '바뀐 것은 둘이다 — (1) 제어기에 들어가는 명령을 누가 내는가,' newline ...
        '                  (2) 그 명령을 추진기 **셋**에 어떻게 나누는가 (배분은 6주차 것).' newline ...
        '  oa_flag 가 0 : LOS 의 psi_los 와 평상 속력 u_ref 가 간다 (5주차와 완전히 같다)' newline ...
        '  oa_flag 가 1 : 파이썬의 psi_oa 와 회피 속력 u_oa 가 대신 간다' newline ...
        '깃발 하나가 방위각과 속력을 **함께** 돌린다 — 그래서 이음새의 신선도 감시 하나가 둘을 다 지킨다.' newline ...
        'Y(횡력) 는 늘 0 이고, 따라서 FB = 0 이다. 배분식의 M = N - l3*FB 가 M = N 이 되어' newline ...
        '9주차 배분이 5주차 것과 글자까지 같아진다. 선수추진기 자리는 비워 둔 채 남겨 둔다.' newline ...
        '로그에서 회피 구간은 psi_los 와 psi_ref 가 갈라지는 곳이고, 거기서 u_oa 가 u_ref 아래로 내려간다.' newline ...
        '' newline ...
        '간격은 시뮬링크가 아니라 **파이썬 쪽 keep-out 반경**이 번다 — 회피기가 그 여유를 거의 다 쓰므로' newline ...
        '실제 틈은 반경보다 1.1 m 쯤 작다. run_ca_nodes.sh 가 2.00 m 로 띄운다 (1-8절).' newline ...
        '' newline ...
        '실행 전: (1) W09_setup  (2) bash run_vrx_ca.sh  (3) bash run_ca_nodes.sh'], ...
        250, -342);
    %  -342 인 까닭 — 이 주차의 설명은 5주차의 것보다 길어서 열다섯 줄(약 180 px)이다.
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
                   {'psi_ref','psi_oa','oa','u_oa'}, gnc_colour('guidance'));

    %  add_subsys 가 포트를 기본 자리(입력 x=60, 출력 x=700)에 떨어뜨린다.
    %  그 자리는 아래 상자들과 겹치므로 네 포트를 먼저 제자리에 놓는다
    set_param([s '/psi_los'], 'Position',[  60 240   90 260]);
    set_param([s '/psi_oa' ], 'Position',[1160  20 1190  40]);
    set_param([s '/u_oa'   ], 'Position',[1160  50 1190  70]);
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

    %  한 메시지에서 둘을 뽑는다 — **속력**(linear.x) 과 **방위각**(angular.z).
    %  차례는 OutputSignals 에 적은 순서다. 1번이 속력, 2번이 방위각이다.
    %  속력까지 받는 것이 2026-11-17 의 변경이다 — 전에는 방위각만 받고 속력은
    %  버렸고, 그 대신 선수추진기로 옆으로 밀었다 (addBowThrust 머리글)
    add_block('simulink/Signal Routing/Bus Selector', [s '/SelCmd'], ...
              'Position',[380 100 430 160]);
    set_param([s '/SelCmd'], 'OutputSignals','linear.x,angular.z');

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
    lane_line(s, 'SelCmd',   2, 'EnuToNed', 1, 465);    % 방위각 — 꺾임 1 (y=140 -> 130)
    lane_line(s, 'SelCmd',   1, 'u_oa',     1, 470);    % 속력 — 도면 위(y=60)로 돌려 내보낸다
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
        '넘겨받는 것은 둘이다 — 방위각(여기서 고른다) 과 속력(u_oa 로 그대로 내보낸다).\n' ...
        '속력을 고르는 스위치는 InnerLoop 안에 있다. 판단(oa) 하나가 둘을 함께 돌린다.\n' ...
        '\n' ...
        '토픽 둘 — 둘 다 받기만 한다. 이 모델은 회피 쪽으로 아무것도 보내지 않는다.\n' ...
        '  /vfh/command   geometry_msgs/Twist  linear.x = 속력, angular.z = 절대 방위각 (ENU, rad)\n' ...
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
%  5주차 목록에 회피 신호 넷을 더했다 — psi_los, psi_oa, oa, u_oa.
%  psi_ref 는 이제 "제어기가 실제로 받은 명령" 이다.
%  u_oa 는 회피기가 낸 속력 지령 [m/s] 다. 회피 구간에서 u 가 그것을 따라
%  내려가는 것이 "속력도 넘겨받았다" 는 말의 증거다.
%  FB 도 더했다 — 선수추진기 추력 [N]. 이 주차에서는 **내내 0 이어야** 한다
%  (Y = 0 으로 묶었다). 0 이 아니면 배분이나 배선이 틀린 것이다
    sig = {'x_n','y_n','psi','psi_ref','psi_los','psi_oa','oa','u_oa', ...
           'y_e','x_e','beta','chi','u','r','U','gate','FL','FR','FB','wp_idx'};
    tag = {'x_n','y_n','psi','psi_ref','psi_los','psi_oa','oa','u_oa', ...
           'y_e','x_e','beta','chi','u','r','U','gate','FL','FR','FB','wp_idx'};
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
% =====================================================================
% 선수추진기 — 6주차 추력배분을 가져와 5주차 제어기 뒤에 붙인다
%
%   제어기는 손대지 않는다. 헤딩 P-D 와 속도 PI 는 블록 하나도 바뀌지 않는다.
%   바뀌는 것은 **배분**이다. 같은 X·N 요구를 받아 추진기 셋으로 나눈다.
%
%       5주차   X = FL + FR,   N = (FL - FR)*b
%       9주차   X = FL + FR,   Y = FB,   N = (FL - FR)*b + l3*FB
%
%   Y 지령은 **없다** — 늘 0 이다 (2026-11-17 변경)
%       Y = 0 -> FB = 0 -> 배분식의 M = N - l3*FB 가 M = N 이 되어
%       9주차 배분이 5주차 것과 **글자까지 같아진다.**
%   그래도 배분·FB 출력·토픽은 그대로 둔다. 선수추진기를 쓸 자리가 생기면
%   (예: 도킹 시 옆붙이기) Y 에 들어오는 선 하나만 갈아 끼우면 된다.
%
%   왜 옆걸음을 뺐는가 / why the sway branch is gone
%       전에는 여기서 Y_cmd = K_sway * ssa(psi_ref - psi) * oa 를 만들어
%       회피 구간에서 선수추진기로 옆으로 밀었다. 뺀 까닭은 둘이다.
%       (1) 역할이 겹친다. 회피는 이제 파이썬 회피기가 낸 **방위각**으로 한다.
%           같은 헤딩 오차를 한 번 더 써서 옆으로 미는 것은 두 번째 회피기다 —
%           어느 쪽이 배를 비켰는지 로그에서 가릴 수 없다.
%       (2) 학부 수준에서 설명값이 낮다. 9주차에서 배울 것은 "누가 방위각을
%           내는가" 하나다. 옆힘은 거기에 더하는 것이 없다.
%
%   대신 **속력**을 받는다 — 같은 깃발 하나(oa)로 둘을 돌린다
%       u_cmd = oa ? u_oa : u_ref
%       /vfh/command 의 linear.x 가 회피기가 재어 낸 안전 속력이다. 전에는
%       이것을 버리고 u_ref 로 계속 달렸다. 느려지면 선회 반경이 함께 줄고
%       (R = u/r_max), 그래서 호 다발 회피기가 선회 반경에 묶여 못 피하던 자리를
%       **돌아서** 번다. 그리고 버리던 신호를 쓰는 것이므로 공짜다.
%
%   그런데 속력만으로는 간격이 돌아오지 않았다 — 모자란 것은 keep-out 반경이었다
%       2026-11-17 실측. K_sway = 0 만 하면 gap_min 이 0.01~0.10 m 까지 줄고
%       (접촉은 clear 2.73 m), 속력까지 넘겨받아도 0.07 m 였다. 캐어 보니
%       회피기가 keep-out 반경 robot.safety_margin_m = 1.20 m 로 호를 고르는데,
%       (가) 점수식이 목표 정렬을 더 무겁게 보아 (clearance_weight 0.30) 그 여유를
%       거의 다 쓰는 호를 고르고, (나) 그 여유는 **예측한 호**에 대한 것이라
%       헤딩 PD 의 지연·선회 반경 때문에 실제 배는 호의 안쪽을 깎아 간다.
%       그래서 실제 틈이 반경보다 1.1 m 쯤 작았다. K_sway = 250 은 그 모자람을
%       옆으로 밀어 메우고 있었던 것이다.
%       keep-out 을 2.00 m 로 올리니 (run_ca_nodes.sh 의 CA_MARGIN, ROS 파라미터이므로
%       다시 빌드할 필요 없다) gap_min 이 0.76 · 0.79 m 가 되었다 — 옆힘을 쓰던
%       예전(0.29~0.52 m)보다 **낫고** F_B ≡ 0 이다. 강의자료 1-8절의 표를 볼 것.
%
%   왜 요(yaw) 를 돕게 하지 않았는가 — 작동기로서 더 못하기 때문이다
%       지레팔이 선수추진기는 l3 = 0.75 m, 선미 한 쌍은 b = 1.027 m 다.
%       뉴턴당 모멘트가 **더 작다**. 게다가 선미 쌍은 포화되지도 않았다
%       (SatN 의 한계가 2*F_max*half_beam = 1027 N m 이고 Kp_psi = 400 이다).
%       빌릴 데가 없는데 빌리면, 원치 않는 옆힘만 딸려 온다 — Yv = Yvv = 100 인
%       이 선체에서 N 의 30 % 를 선수추진기로 내면 FB = 160 N, 정상 옆속도가
%       v = 0.86 m/s 다. u = 1.5 m/s 에서 30도 비스듬히 가는 셈이다.
%
%   6주차의 핵심은 그대로 남는다 — allocFcn 의 M = N - l3*FB 한 줄이다.
%   이 주차에서는 FB = 0 이라 그 줄이 아무 일도 하지 않지만, 식은 6주차 것 그대로다.
%   한 식을 두 군데 적어 두지 않는다는 규칙을 지키기 위해 베끼지 않고 가져다 쓴다.
%
%   포트는 **끼워 넣지 않고 뒤에 붙인다.** InnerLoop 입력 1~5번과 출력 1~2번,
%   새 포트(입력 oa·u_oa, 출력 FB)는 맨 뒤에 붙인다 — 5주차 신호선의 번호가 밀리지 않는다.
% =====================================================================
function addBowThrust(here, m)
    %  6주차 배분식 본문을 **글자 그대로** 가져온다. 베껴 적지 않는다 —
    %  두 군데에 같은 식을 적어 두면 한쪽만 고쳐져 어긋난다 (parts/allocFcn.m 머리글)
    p6 = fullfile(here, '..', 'W06_simulink', 'parts');
    addpath(p6);
    cl = onCleanup(@() rmpath(p6));   %#ok<NASGU> — 함수를 빠져나갈 때 되돌린다

    % ---------- 1) InnerLoop : 회피 깃발·회피 속력 입력 둘, 선수추력 출력 하나 ----------
    ss = [m '/InnerLoop'];
    add_block('simulink/Sources/In1', [ss '/oa'], ...
              'Position', [40 460 75 490], 'Port','6');
    add_block('simulink/Sources/In1', [ss '/u_oa'], ...
              'Position', [40 510 75 540], 'Port','7');

    %  u_cmd = oa ? u_oa : u_ref
    %  이음새(AvoidSeam) 가 방위각을 고르는 것과 **똑같은 꼴**이다. 깃발 하나가
    %  방위각과 속력을 함께 돌린다 — 그래서 신선도 감시 하나가 둘을 다 지킨다.
    %  스위치를 도면에 보이게 두는 까닭도 이음새와 같다 (addAvoidSeam 머리글)
    add_block('simulink/Signal Routing/Switch', [ss '/PickU'], ...
              'Position', [200 370 240 450]);
    set_param([ss '/PickU'], 'Criteria','u2 >= Threshold', 'Threshold','0.5');
    delete_line(ss, 'u_ref/1', 'Gate/1');
    add_line(ss, 'u_oa/1',  'PickU/1', 'autorouting','on');   % 1번 : 회피 속력
    add_line(ss, 'oa/1',    'PickU/2', 'autorouting','on');   % 2번 : 판단
    add_line(ss, 'u_ref/1', 'PickU/3', 'autorouting','on');   % 3번 : 평상 속력
    add_line(ss, 'PickU/1', 'Gate/1',  'autorouting','on');

    % ---------- 2) 배분을 6주차 것으로 갈아 끼운다 ----------
    delete_line(ss, 'PI_u/1',  'Alloc/1');
    delete_line(ss, 'SatN/1',  'Alloc/2');
    delete_line(ss, 'HB/1',    'Alloc/3');
    delete_line(ss, 'FM/1',    'Alloc/4');
    delete_line(ss, 'Alloc/1', 'FL/1');
    delete_line(ss, 'Alloc/2', 'FR/1');
    delete_block([ss '/Alloc']);
    delete_block([ss '/HB']);     % 상수 둘은 묶음 하나(alloc_prm)로 대신한다
    delete_block([ss '/FM']);

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/Alloc'], 'Position', [730 210 880 360]);
    setFcn(ss, 'Alloc', allocFcn());        % 6주차 parts/allocFcn.m — 손대지 않았다

    add_block('simulink/Sources/Constant', [ss '/PRM'], ...
              'Position', [600 460 690 490], 'Value','alloc_prm');
    %  Y 는 늘 0 이다 — 상수를 **보이게** 둔다. 선을 지워 포트를 비우면
    %  "안 쓰는 것" 과 "쓰려다 잊은 것" 을 도면에서 가릴 수 없다 (이 함수 머리글)
    add_block('simulink/Sources/Constant', [ss '/Y_zero'], ...
              'Position', [600 510 690 540], 'Value','0');
    add_block('simulink/Sinks/Out1', [ss '/FB'], ...
              'Position', [960 370 995 400], 'Port','3');

    add_line(ss,'PI_u/1',    'Alloc/1','autorouting','on');   % X  전후력
    add_line(ss,'Y_zero/1',  'Alloc/2','autorouting','on');   % Y  횡력 — 늘 0
    add_line(ss,'SatN/1',    'Alloc/3','autorouting','on');   % N  요 모멘트
    add_line(ss,'PRM/1',     'Alloc/4','autorouting','on');   % p  = alloc_prm
    add_line(ss,'Alloc/1','FL/1','autorouting','on');
    add_line(ss,'Alloc/2','FR/1','autorouting','on');
    add_line(ss,'Alloc/3','FB/1','autorouting','on');
    Simulink.BlockDiagram.arrangeSystem(ss);

    % ---------- 3) Thrusters 상자를 뺀다 ----------
    %  5주차의 Plugin 칸은 가제보 추진기 플러그인(gz-sim7 Thruster.cc)의 계산을
    %  옮겨 적은 것이다 — 포화(±2353 N) · 추력->회전수 · 되돌려 보는 검산.
    %  가제보가 같은 계산을 스스로 한다. 그리고 배분(Alloc)이 이미 ±500 · ±250 N
    %  으로 자르므로 플러그인 한계 2353 N 에는 닿지도 않는다 — 지령이 그대로 지나갈 뿐이다.
    %  그래서 배분이 낸 F_L · F_R · F_B 를 곧장 토픽으로 보낸다
    ts = [m '/Thrusters'];
    lh = get_param(ts, 'LineHandles');
    hs = [lh.Inport(:).' lh.Outport(:).'];
    for h = hs(hs > 0), delete_line(h); end
    delete_block(ts);
    delete_block([m '/Go_nprop']);     % 회전수 · 검산 태그 — 받던 곳(Logging)도 다시 짓는다
    delete_block([m '/Go_Ferr']);
    add_line(m, 'InnerLoop/1', 'Go_FL/1', 'autorouting','on');
    add_line(m, 'InnerLoop/2', 'Go_FR/1', 'autorouting','on');

    % ---------- 4) 윗단 배관 ----------
    add_line(m, 'AvoidSeam/3', 'InnerLoop/6', 'autorouting','on');   % oa 깃발 (가지)
    G(m, 'FB', 1230, 780);
    add_line(m, 'InnerLoop/3', 'Go_FB/1', 'autorouting','on');       % FB 지령
    %  회피 속력은 **태그로** 보낸다. 로깅이 어차피 u_oa 태그를 받으므로
    %  (addLogging) 같은 태그를 InnerLoop 7번 입력에도 쓴다 — 도면을 가로지르는
    %  긴 선을 하나 안 그린다. oa(6번) 가 직선으로 가는 것과 꼴이 다른 까닭이다.
    %  이것이 이 주차에서 눈으로 볼 수 있는 회피의 흔적 둘 중 하나다
    %  (다른 하나는 psi_los 와 psi_ref 가 갈라지는 것)
    G(m, 'u_oa', 940, 205);
    add_line(m, 'AvoidSeam/4', 'Go_u_oa/1', 'autorouting','on');
    fu = F(m, 'u_oa', 900, 860);
    add_line(m, [fu '/1'], 'InnerLoop/7', 'autorouting','on');

    % ---------- 5) 발행 토픽을 셋으로 ----------
    %  상자 안에 벌 하나를 손으로 끼우기보다 add_cmd_publisher 에 토픽 셋을
    %  주고 다시 짓는 편이 짧다. 6주차 parts/plant.m 과 **같은 호출**이다
    fl  = find_system(m,'SearchDepth',1,'BlockType','From','GotoTag','FL');
    fr  = find_system(m,'SearchDepth',1,'BlockType','From','GotoTag','FR');
    nFL = get_param(fl{1},'Name');
    nFR = get_param(fr{1},'Name');
    delete_line(m, [nFL '/1'], 'CmdPublisher/1');
    delete_line(m, [nFR '/1'], 'CmdPublisher/2');
    pos = get_param([m '/CmdPublisher'], 'Position');
    delete_block([m '/CmdPublisher']);
    add_cmd_publisher(m, pos(1:2), ...
        {'/wamv/thrusters/left/thrust', ...
         '/wamv/thrusters/right/thrust', ...
         '/wamv/thrusters/bow/thrust'}, 'Ts_ctrl', {'FL','FR','FB'});

    nFB = from_name(m, 'FB');
    add_block('simulink/Signal Routing/From', [m '/' nFB], ...
              'Position', [pos(1)-70 pos(2)+110 pos(1) pos(2)+135], 'GotoTag','FB');
    add_line(m, [nFL '/1'], 'CmdPublisher/1', 'autorouting','on');
    add_line(m, [nFR '/1'], 'CmdPublisher/2', 'autorouting','on');
    add_line(m, [nFB '/1'], 'CmdPublisher/3', 'autorouting','on');
end

function setFcn(sys, path, code)
    S  = sfroot;
    fpos = get_param([sys '/' path], 'Position');
    ch = S.find('-isa','Stateflow.EMChart','Path',[sys '/' path]);
    ch.Script = code;
    set_param([sys '/' path], 'Position', fpos);
end

function nm = F(m, tag, x, y)
%  From 블록 이름은 `Fr_<태그>` 다 — 5주차 빌더의 F 와 같은 것이다
    nm = from_name(m, tag);
    add_block('simulink/Signal Routing/From', [m '/' nm], ...
              'Position', [x y x+70 y+25], 'GotoTag', tag);
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
