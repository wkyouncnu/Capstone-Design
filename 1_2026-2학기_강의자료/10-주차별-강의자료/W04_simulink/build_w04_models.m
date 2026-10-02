function build_w04_models(only)
% BUILD_W04_MODELS  4주차 3~5단계 Simulink 예제 모델 9개를 생성한다.
%
%   build_w04_models()                    전부 다시 만든다 (평소에는 이것)
%   build_w04_models('W04_7_ssa_test')    한 모델만 — 고치는 중에 빨리 보려고
%
%   이 스크립트를 실행하면 아래 모델이 이 폴더에 만들어진다.
%     W04_1_straight.slx          직진
%     W04_2_turn.slx              시간에 따라 직진 -> 우선회 -> 좌선회
%     W04_3_heading.slx           헤딩 제어 (outer)
%     W04_4_inner_loop.slx        속도 + 헤딩 제어 (inner loop 완성)
%     W04_5_offline.slx           2단계 시나리오를 운동방정식으로
%     W04_3_heading_offline.slx   3단계와 같은 제어기, Gazebo 대신 운동방정식
%     W04_4_inner_loop_offline.slx 4단계와 같은 제어기, Gazebo 대신 운동방정식
%     W04_6_wrap.slx              +-180 deg 이음매. 계단 두 번, use_ssa 하나로 20 vs 340 deg
%     W04_7_ssa_test.slx          ssa 함수 하나만. 배도 제어기도 없다 (6단계 앞에 본다)
%
%   게인과 스위치 값은 전부 W04_setup.m 에 있다. 블록 안에 숫자가 아니라
%   Kp_psi · head_open · port_eff 가 적혀 있는 것이 정상이다.
%
%   3·4단계는 오프라인 쌍둥이가 있다. 제어기 · 배분기 블록은 같은 함수로 만든다.
%   바뀌는 것은 두 자리뿐이다.
%     VRX      : OdomSub -> Sel -> Quat2Yaw  ...  Alloc -> Blank/Asg/Pub (x2)
%     오프라인 : MotionModel (psi, r, u)     ...  Alloc -> MotionModel
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 원래대로 복구된다.
%
%   전제
%     - MATLAB R2024b + Simulink + ROS Toolbox
%     - VRX 가 ground_truth_odometry 를 발행하도록 설정되어 있을 것
%       (강의자료 4주차 B절 참조)

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);
    load_system('ros2lib');
    if evalin('base', '~exist(''Kp_psi'',''var'')')
        evalin('base', 'W04_setup');
    end

    if nargin < 1 || isempty(only), only = ''; end
    want = @(n) isempty(only) || any(strcmp(n, cellstr(only)));

    if want('W04_1_straight'),            build_straight();       end
    if want('W04_2_turn'),                build_turn();           end
    if want('W04_3_heading'),             build_heading(false);   end
    if want('W04_4_inner_loop'),          build_inner_loop(false);end
    if want('W04_5_offline'),             build_offline();        end
    if want('W04_3_heading_offline'),     build_heading(true);    end
    if want('W04_4_inner_loop_offline'),  build_inner_loop(true); end
    if want('W04_6_wrap'),                build_wrap();           end
    if want('W04_7_ssa_test'),            build_ssa_test();       end


    % 배치와 색을 정리한다. 선은 직선 또는 직각으로만 다시 그린다.
    % dir 의 문자 클래스는 Windows 에서 먹지 않는다. 목록을 받아 이름으로 거른다
    slxList = dir('W04_*.slx');
    slxList = slxList(~cellfun(@isempty, regexp({slxList.name}, '^W04_[1-7]_', 'once')));   % 오프라인 쌍둥이 · wrap · ssa 시험 포함
    if ~isempty(only)
        keep = cellfun(@(n) want(erase(n,'.slx')), {slxList.name});
        slxList = slxList(keep);
    end
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try

            %  'KeepRoot' — 최상위 블록은 빌더가 gnc_chain 으로 잡아 둔 열에
            %  그대로 둔다. arrangeSystem 은 선 길이만 보고 단계 순서를 모른다.
            %  (2026-09-30 이 옵션이 없을 때 W04_3_heading_offline 의 지령이
            %   제어기 **오른쪽**으로, 운동모델이 제어기 **왼쪽**으로 갔다)
            tidy_model(mName, 'KeepRoot', true);

            paint_roles(mName);        % 역할표는 _tools/gnc_roles.m 하나뿐이다

            check_colour(mName);

            %  통로를 옮길 수 없는 이름표 위 선은 블록을 비켜서 푼다
            %  (line-routing.md §9. arrangeSystem 이 소스를 통로 밑에 놓는 일이 있다)
            nudge_labels(mName);

            check_lines(mName, true);  % 일곱 항목이 전부 0 이 합격선

            check_flow(mName, true);   % 최상위가 왼쪽에서 오른쪽으로 읽히는가. 0 이 합격선

            check_tags(mName);         % 태그 이름이 신호 이름인가 · To Workspace 개수. 0 이 합격선

            check_gains(mName);        % 0 인 게인 · 음수 게인. 합격선은 없고 **읽고 판단**한다

            export_model_pngs(mName);

        catch e, warning(e.message); end
    end
    fprintf('\n완료. 생성된 모델:\n');
    d = dir('W04_*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
end

% =====================================================================
% 공통 헬퍼
% =====================================================================
function addThrusterPublisher(m, side, tag, x, y)
% 추력 발행 3종 세트: Blank Message -> Bus Assignment -> Publish
    add_block('ros2lib/Blank Message', [m '/Blank' tag], ...
              'Position', [x y+70 x+100 y+110]);
    set_param([m '/Blank' tag], 'entityType','std_msgs/Float64', ...
              'messageType','std_msgs/Float64', 'SampleTime','0.05');
    add_block('simulink/Signal Routing/Bus Assignment', [m '/Asg' tag], ...
              'Position', [x+160 y x+220 y+115]);
    set_param([m '/Asg' tag], 'AssignedSignals','data');
    add_block('ros2lib/Publish', [m '/Pub' tag], ...
              'Position', [x+290 y+35 x+390 y+75]);
    set_param([m '/Pub' tag], 'topicSource','Specify your own', ...
              'topic', ['/wamv/thrusters/' side '/thrust'], ...
              'messageType','std_msgs/Float64');

    %  Blank 의 출력을 Asg 의 1번 입력 **높이에 맞추고**, Pub 의 입력을 Asg 의 출력
    %  높이에 맞춘다. Bus Assignment 는 115 px 키에 입력이 둘이라 1번 포트가 위쪽에
    %  치우쳐 있어, 블록 가운데를 맞추는 것으로는 선이 두 번 꺾인다 (2026-10-01
    %  꺾임 2회 세기에서 네 모델 모두 Blank->Asg · Asg->Pub 가 잡혔다)
    align_to(m, ['Blank' tag], 'Outport', port_xy(m, ['Asg' tag], 'Inport',  1));
    align_to(m, ['Pub'   tag], 'Inport',  port_xy(m, ['Asg' tag], 'Outport', 1));

    add_line(m, ['Blank' tag '/1'], ['Asg' tag '/1'], 'autorouting','on');
    add_line(m, ['Asg'   tag '/1'], ['Pub' tag '/1'], 'autorouting','on');
end

function addFirstMsgGate(m, src, tag, x, y)
% odom_ok = 0 인 동안(첫 오도메트리 전 + 그 뒤 1 초) 추력 0 을 발행한다.
%   Subscribe 는 첫 메시지 전에 0 으로 채운 버스를 내고, Quat2Yaw 는 그것을 선수각 90 deg 로 읽는다.
%   또 Simulink 는 시작 직후 몇 스텝을 벽시계로 수 초씩 멈추는데, 그동안 Gazebo 는 첫 추력을 계속 준다.
%   막지 않으면 계단이 시작되기도 전에 배가 돌아, 헤딩 오버슈트가 실행마다 3 · 54 · 347 % 로
%   달리 찍혔다 (2026-09-24 노트북 실측). 1 초 예열 뒤 정지한 배에서 계단을 시작한다.
    %  Gate 의 출력을 Asg 의 2번 입력 **높이에 맞춰** 놓는다. 어긋나 있으면
    %  Gate -> Asg 가 꺾이고, 꺾임이 세 번이 되면 tidy_model 이 그것을 Goto/From
    %  으로 바꿔 버린다 — 바로 옆 단계로 가는 본선이 태그가 되는 것은 잘못이다
    %  (2026-10-01 W04_4_inner_loop 의 Fr_FR_1). 높이를 맞추면 직선 한 토막이다
    qa  = port_xy(m, ['Asg' tag], 'Inport', 2);
    yG  = qa(2) - 30;                      % Product 30 px 높이의 가운데가 그 포트에
    add_block('simulink/Math Operations/Product', [m '/Gate' tag], ...
              'Position',[x+100 yG x+130 yG+60]);
    %  블록 이름은 'Fr_odom_ok', 중복이면 **번호만** (from_name.m). 'From_okL' 처럼
    %  블록 이름을 섞지 않는다 — 2026-10-01 교수 지시
    qg = port_xy(m, ['Gate' tag], 'Inport', 2);
    fr = from_name(m, 'odom_ok');
    add_block('simulink/Signal Routing/From', [m '/' fr], ...
              'GotoTag','odom_ok', 'Position',[x qg(2)-11 x+70 qg(2)+11]);
    add_line(m, src,          ['Gate' tag '/1'], 'autorouting','on');
    add_line(m, [fr '/1'],    ['Gate' tag '/2'], 'autorouting','on');
    add_line(m, ['Gate' tag '/1'], ['Asg' tag '/2'],  'autorouting','on');
end

function setSolver(m)
%  VRX 모델도 **고정스텝 연속 솔버 ode4** 를 쓴다 (교수 지시 2026-10-01).
%
%  전에는 FixedStepDiscrete 였다. 그 때문에 제어기의 적분기를 이산으로 둘
%  수밖에 없었는데, 재검토해 보니 **솔버 선택의 문제이지 VRX 의 제약이
%  아니었다.** ode4 로 바꾸면 연속 적분기가 그대로 돈다 (2026-10-01 실측:
%  FixedStepDiscrete + 연속 적분기는 "연속 상태가 포함되어 있다" 로 실패,
%  ode4 는 통과).
%
%  스텝은 0.05 s 그대로다. ROS Subscribe/Publish 는 이산 블록이라 major step
%  에서만 돌므로 토픽 주기도 페이싱도 달라지지 않는다.
%
%  StopTime 은 **무한대로 두지 않는다** (교수 지시 2026-10-02).
%  전에는 inf 였다. 그래서 학생이 Run 을 누르면 모델이 스스로 끝나지 않고,
%  Stop 을 손으로 눌러야 했다 — 언제 눌러야 하는지는 아무도 알려 주지 않았다.
%  게다가 Gazebo 가 떠 있지 않으면 토픽이 오지 않아 화면이 빈 채로 영원히
%  돌았다 (2026-10-02 교수가 W04_4_inner_loop 에서 겪은 것이 이것이다).
%  이제 시나리오 길이만큼만 돌고, 응답이 안정되면 그 전에 스스로 멈춘다
%  (addAutoStop 참고).
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','0.05', 'StopTime','T_run', 'SimulationMode','normal');
end

function setFcn(m, name, code)
    S  = sfroot;
    fpos = get_param([m '/' name], 'Position');   % 포트가 생기며 블록이 멋대로 자란다
    ch = S.find('-isa','Stateflow.EMChart','Path',[m '/' name]);
    ch.Script = code;
    set_param([m '/' name], 'Position', fpos);    % 다시 놓아야 포트 위치가 저장 뒤와 같아진다 (사선 방지)
end

function note(m, txt, x, y)
    add_block('built-in/Note', [m '/note'], ...
              'Position', [x y x y], 'Text', txt);
end

function fresh(m)
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end

% =====================================================================
% 최상위 열 — 왼쪽에서 오른쪽으로
%
%   교수 지시 2026-09-30. "가장 왼쪽에 명령이 나오고, 그다음 제어기, 마지막
%   오른쪽에 운동 모델이 나오는 형태로 해서 왼쪽에서 오른쪽으로 흐름을 볼 수
%   있게 할 것."
%
%       [지령] -> [제어기] -> [배분] -> [운동모델] -> [로깅·화면]
%
%   x 를 손으로 적지 않는다. 단계 이름과 그 단계가 쓸 **폭**만 적으면
%   _tools/gnc_chain 이 열의 왼쪽 모서리를 정해 준다. 폭을 적는 이유는 단계마다
%   상자 수가 다르기 때문이다 — 제어기 하나뿐인 주차와, 그 옆에 개루프 스위치까지
%   선 주차를 같은 간격으로 놓으면 한쪽은 비고 한쪽은 겹친다.
%
%   되먹임(psi · r · u)은 선으로 되돌리지 않는다. tidy_model 의 tag_feedback 이
%   세 번 넘게 꺾이는 선을 Goto/From 한 쌍으로 바꾼다. 계산은 한 자리도
%   달라지지 않고, 화면을 가로지르는 선만 사라진다.
%
%   이 배치가 지켜졌는지는 `check_flow` 가 센다. 합격선은 0 이다.
% =====================================================================
function P = w04cols(varargin)
%   w04cols('command',300, 'controller',340, ...) -> 단계별 열 좌표 struct
    st = varargin(1:2:end);
    wd = varargin(2:2:end);
    P  = gnc_chain(st, 'Width', cell2struct(wd(:), st(:), 1), 'Y', 140, 'Gap', 50);
end

% =====================================================================
% 실시간 화면 — 일곱 모델이 같은 함수(W04_animate.m)를 쓴다
%
%   교수 지시 2026-09-24. 3주차에는 실시간 화면이 있는데 4주차 모델에는 없었다.
%   4주차는 **제어**를 하므로 화면이 답해야 할 질문이 하나 늘었다 —
%   시킨 대로 따라갔는가. 그래서 궤적 옆에 지령 대비 응답 두 칸이 더 있다.
%
%   붙은 모델
%     오프라인  W04_3_heading_offline · W04_4_inner_loop_offline · W04_5_offline
%     VRX       W04_1_straight · W04_2_turn · W04_3_heading · W04_4_inner_loop
%
%   >>> 묶는 순서 계약 — 여기와 W04_animate.m 에 **같은 표**가 있다 <<<
%
%     anim 벡터   1 x_n   2 y_n   3 psi   4 u   5 v   6 r   7 FL   8 FR
%     그 뒤       [u_ref]  [psi_ref]   +  t  +  en
%
%   교수 지시 2026-10-01. "화면·로깅이 태그를 늘리는 주범이면 묶어서 보낸다."
%   전에는 여덟 신호를 **태그 여덟 개**로 따로 보냈다. 지금은 Mux 하나로 묶어
%   태그 **하나**(`anim`)로 보내고, 받는 쪽에서 `a(k)` 로 풀어 쓴다.
%   숫자는 한 자리도 달라지지 않고 도면의 태그만 줄어든다.
%
%   순서를 고칠 일이 생기면 **animBundle 의 주석표 · 아래 코드 · W04_animate.m
%   머리말** 세 곳을 함께 고친다. 셋이 어긋나면 그림이 조용히 틀린다.
%
%   지령이 없는 모델은 그 태그를 **아예 만들지 않고** AnimateFcn 이 NaN 을 넣어
%   부른다. W04_animate 는 NaN 을 보면 그 칸에 "지령 없음 (개루프)" 라고 적는다.
%   빈 칸으로 두면 학생은 그림이 고장난 줄 안다.
% =====================================================================
function addW04Animate(m, x, y, hasURef, hasPsiRef)
    tags = {'anim'};
    if hasURef,   tags{end+1} = 'u_ref';   end
    if hasPsiRef, tags{end+1} = 'psi_ref'; end

    if hasURef,   aU = 'u_ref';   else, aU = 'NaN'; end
    if hasPsiRef, aP = 'psi_ref'; else, aP = 'NaN'; end

    code = [ ...
    sprintf('function ok = AnimateFcn(%s, t, en)', strjoin(tags, ', '))           newline ...
    '%#codegen'                                                                   newline ...
    '% 실시간 그림. MATLAB Function 블록은 그림을 그리지 못하므로 그리는 함수를'    newline ...
    '% extrinsic 으로 선언한다 — 코드를 만들지 않고 평범한 MATLAB 을 부른다.'       newline ...
    '% en = base workspace 의 animate (0 이면 그리지 않는다).'                      newline ...
    '%'                                                                           newline ...
    '% anim 은 Mux 로 묶어 온 여덟 신호다 (빌더의 animBundle 과 같은 순서).'        newline ...
    '%   1 x_n   2 y_n   3 psi   4 u   5 v   6 r   7 FL   8 FR'                    newline ...
    'coder.extrinsic(''W04_animate'');'                                           newline ...
    'ok = 1;'                                                                     newline ...
    'if en > 0.5'                                                                 newline ...
    sprintf(['    W04_animate(anim(1), anim(2), anim(3), anim(4), anim(5), ' ...
             'anim(6), anim(7), anim(8), %s, %s, t);'], aU, aP)                   newline ...
    'end'];

    add_animate_box(m, tags, 'W04_animate', code, [x y], '0.05');
end

% ---- 화면용 여덟 신호를 Mux 하나로 묶어 태그 하나로 보낸다 --------------
%
%   >>> 순서 계약 (addW04Animate · W04_animate.m 과 같은 표) <<<
%
%     1 x_n   2 y_n   3 psi   4 u   5 v   6 r   7 FL   8 FR
%
%   SRCS 는 그 순서대로 적은 출발 포트 여덟 개다 ('OdomTap/1' 꼴).
%   실시간 화면은 이 값들을 **구경만** 한다. 제어 경로는 건드리지 않는다.
%   H 는 Mux 의 높이다. 신호 여덟 개가 **한 블록**에서 나올 때는 그 블록과 같은
%   높이로 두어야 입력 포트가 줄줄이 마주 보며 선이 전부 수평 직선이 된다.
%   SRCS{k} 가 '#psi' 처럼 '#' 로 시작하면 그 자리에 **From 하나를 만들어** 꽂는다.
%   아직 만들어지지 않은 블록(추력 발행단)의 값을 받을 때 쓴다. From 은 Mux 입력
%   포트 높이를 **읽어서** 놓으므로 선이 수평 직선이고 서로 겹치지 않는다.
function animBundle(sys, srcs, x, y, h)
    if nargin < 5 || isempty(h), h = 240; end
    add_block('simulink/Signal Routing/Mux', [sys '/MuxAnim'], ...
              'Inputs','8', 'Position',[x y x+5 y+h]);
    for k = 1:8
        src = srcs{k};
        if src(1) == '#'
            tag = src(2:end);
            q   = port_xy(sys, 'MuxAnim', 'Inport', k);
            %  블록 이름은 'Fr_<태그>', 중복이면 **번호만** (from_name.m).
            %  Mux 입력 포트 **바로 왼쪽**에 둔다 — 선이 수평 직선 한 토막이다
            nm  = from_name(sys, tag);
            add_block('simulink/Signal Routing/From', [sys '/' nm], ...
                      'GotoTag', tag, 'Position',[x-110 q(2)-11 x-40 q(2)+11]);
            src = [nm '/1'];
        end
        add_line(sys, src, sprintf('MuxAnim/%d',k), 'autorouting','on');
    end
    q = port_xy(sys, 'MuxAnim', 'Outport', 1);
    add_block('simulink/Signal Routing/Goto', [sys '/Go_anim'], ...
              'GotoTag','anim', 'TagVisibility','global', ...
              'Position',[x+90 q(2)-11 x+160 q(2)+11]);
    add_line(sys, 'MuxAnim/1', 'Go_anim/1');
end

% ---- From 하나를 놓고 잇는다. 제어기·Scope 가 태그에서 값을 받는 자리 ----
%
%   자리는 손으로 잡지 않고 `feed_from` 에게 맡긴다. 그 함수가 **도착 포트 바로
%   왼쪽**(같은 높이)에 놓아 꺾임 0회로 이어 주고, 그 자리가 차 있을 때만 DY 쪽으로
%   비킨다. 손으로 x·y 를 주면 그 자리가 이미 차 있을 때 세 번 꺾이는 선이 생기고,
%   배치 도구가 그것을 끝내 풀지 못한다 (2026-10-01 W04_6_wrap 에서 재현).
%
%   블록 이름은 `Fr_<태그>` 다. 같은 태그를 여러 곳에서 받으면 **번호만** 붙는다
%   (Fr_psi · Fr_psi_2). 도착 블록 이름을 섞지 않는다 — 2026-10-01 교수 지시
function fromTo(sys, tag, dst, dp, dy)
    if nargin < 5 || isempty(dy), dy = 90; end
    f = feed_from(sys, tag, dst, dp, dy);
    set_param(f, 'BackgroundColor', gnc_colour('measurement'));
end

% ---- 출발 포트 **옆**에 Goto 를 놓는다 ----------------------------------
%   drop_tag 가 출발 포트와 **같은 높이**, 한 칸 오른쪽에 세운다 (꺾임 0회).
%   그 자리가 다음 단계로 가는 본선 위이면 spot_free 가 막고 DY 쪽으로 비킨다
%   (2026-10-01 W04_4_inner_loop 의 deg2rad -> HeadingCtrl 이 Go_psi_ref 를
%   가로질렀다). DY 는 비켜 갈 **방향**일 뿐, 평소에 쓰이는 값이 아니다.
function dropTag(sys, src, sp, name, dy)
    g = drop_tag(sys, src, sp, name, dy);
    set_param(g, 'TagVisibility','global', 'BackgroundColor', gnc_colour('measurement'));
end

% ---- 출발 포트 **옆**에 Goto 태그를 한 줄로 세운다 -> 선이 전부 수평 직선 ----
%   실시간 화면은 제어 신호를 **구경만** 한다. 본선에 가지를 쳐서 태그에 걸 뿐,
%   블록 하나 게인 하나 건드리지 않는다.
%
%   자리는 `drop_tag` 가 잡는다. 전에는 x 를 손으로 주었는데, 그 자리에 다음 단계
%   블록이 앉아 있으면 태그가 그 위에 포개졌다 (2026-10-01 W04_3_heading_offline 의
%   Go_FR 이 MotionModel 위에. 전에는 lay_sinks 가 태그를 도면 아래로 쓸어 내려
%   가려져 있었을 뿐이다). drop_tag 는 빈자리를 재고 놓는다.
function tapGotos(sys, src, names, x) %#ok<INUSD>
%   NAMES 의 k 번째가 빈 문자열이면 그 출력 포트는 건너뛴다 — 두 출력 중
%   하나만 태그로 뺄 때 쓴다 (예: Alloc 의 FR 만. FL 은 PortEff 를 지난 값이다)
%   X 는 쓰이지 않는다. 태그는 **출발 포트 옆**에 놓는다 (2026-10-01 교수 지시)
    for k = 1:numel(names)
        if isempty(names{k}), continue, end
        dropTag(sys, src, k, names{k}, 120);
    end
end

% =====================================================================
% 1단계 — 직진
% =====================================================================
function build_straight()
    m = 'W04_1_straight'; fresh(m);

    %  [지령] -> [Gazebo 로 내보내기·읽어오기] -> [로깅·화면]
    P  = w04cols('command',200, 'plant',620, 'measurement',330);
    xC = P.command(1);  xP = P.plant(1);  xM = P.measurement(1);

    add_block('simulink/Sources/Constant', [m '/FL'], ...
              'Value','200', 'Position',[xC 95 xC+60 125]);
    add_block('simulink/Sources/Constant', [m '/FR'], ...
              'Value','200', 'Position',[xC 275 xC+60 305]);

    addThrusterPublisher(m, 'left',  'L', xP, 60);
    addThrusterPublisher(m, 'right', 'R', xP, 240);

    %  지령 상수를 Asg 의 2번 입력 **높이에 맞춘다** — 선이 수평 직선 한 토막이 된다
    align_to(m, 'FL', 'Outport', port_xy(m, 'AsgL', 'Inport', 2));
    align_to(m, 'FR', 'Outport', port_xy(m, 'AsgR', 'Inport', 2));

    add_line(m,'FL/1','AsgL/2','autorouting','on');
    add_line(m,'FR/1','AsgR/2','autorouting','on');

    %  실시간 화면 — 내보낸 추력과, 그 결과로 배가 어디까지 갔는지를 함께 본다.
    %  이 모델은 제어를 하지 않으므로 지령 칸 둘은 "지령 없음" 이 된다.
    %  FL·FR 은 맨 왼쪽 지령 열에 있고 화면은 맨 오른쪽이다. 선으로 이으면
    %  도면을 가로지르므로 태그로 보낸다 — 이름은 신호 이름 그대로 (2026-10-01)
    tapGotos(m, 'FL', {'FL'}, xC+90);
    tapGotos(m, 'FR', {'FR'}, xC+90);
    addOdomReader(m, false, true, false, [xP 430]);
    addW04Animate(m, xM, 1020, false, false);

    setSolver(m);
    note(m, sprintf(['[1단계] 직진\n' ...
        '좌우 추력을 같은 값(200 N)으로 발행한다.\n' ...
        'FL 과 FR 값을 바꿔 보고 배가 어떻게 반응하는지 관찰할 것.\n' ...
        '\n' ...
        'Animate 상자가 도는 동안 항적과 상태를 그린다 (W04_animate.m).\n' ...
        '끄려면 W04_setup.m 의 animate = 0.']), xC, 1050);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% 2단계 — 직진 / 우선회 / 좌선회
% =====================================================================
function build_turn()
    m = 'W04_2_turn'; fresh(m);

    %  [시각] -> [시나리오] -> [Gazebo 로 내보내기·읽어오기] -> [로깅·화면]
    P  = w04cols('command',100, 'reference',260, 'plant',620, 'measurement',330);
    xC = P.command(1);  xR = P.reference(1);  xP = P.plant(1);  xM = P.measurement(1);

    add_block('simulink/Sources/Digital Clock', [m '/Clock'], ...
              'SampleTime','0.05', 'Position',[xC 185 xC+60 215]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Scenario'], ...
              'Position',[xR 165 xR+130 235]);
    setFcn(m, 'Scenario', [ ...
        'function [FL, FR] = Scenario(t)' newline ...
        '%#codegen' newline ...
        '% Time-based thrust scenario [N]' newline ...
        'if t < 20' newline ...
        '    FL = 200;  FR = 200;   % go straight' newline ...
        'elseif t < 40' newline ...
        '    FL = 300;  FR =  50;   % turn starboard (right)' newline ...
        'elseif t < 60' newline ...
        '    FL =  50;  FR = 300;   % turn port (left)' newline ...
        'else' newline ...
        '    FL = 0;    FR = 0;     % stop' newline ...
        'end' newline]);

    addThrusterPublisher(m, 'left',  'L', xP, 60);
    addThrusterPublisher(m, 'right', 'R', xP, 240);

    %  시나리오의 1번 출력을 AsgL 의 2번 입력 높이에 맞춘다. 두 출력이 70 px
    %  떨어져 있고 Asg 둘은 180 px 떨어져 있으므로 **둘 다** 직선이 될 수는 없다 —
    %  한쪽이라도 꺾임 0 회로 만든다 (2026-10-01 꺾임 2회 세기)
    align_to(m, 'Scenario', 'Outport', port_xy(m, 'AsgL', 'Inport', 2), 1);
    align_to(m, 'Clock',    'Outport', port_xy(m, 'Scenario', 'Inport', 1));

    add_line(m,'Clock/1','Scenario/1','autorouting','on');
    add_line(m,'Scenario/1','AsgL/2','autorouting','on');
    add_line(m,'Scenario/2','AsgR/2','autorouting','on');

    %  실시간 화면 — 시나리오가 추력을 바꾸는 순간과 항적이 휘는 순간을 나란히 본다
    tapGotos(m, 'Scenario', {'FL','FR'}, xR+160);
    addOdomReader(m, false, true, false, [xP 430]);
    addW04Animate(m, xM, 1020, false, false);

    setSolver(m);
    set_param(m,'StopTime','80');
    note(m, sprintf(['[2단계] 직진 -> 우선회 -> 좌선회\n' ...
        '0~20s 직진 / 20~40s 우선회 / 40~60s 좌선회 / 60s~ 정지\n' ...
        '좌현 추력이 크면 뱃머리가 오른쪽으로 돈다.\n' ...
        '\n' ...
        'Animate 상자가 도는 동안 추력과 항적을 함께 그린다 (W04_animate.m).\n' ...
        '추력이 바뀌는 20 · 40 · 60 초에 항적이 어떻게 휘는지 볼 것.']), xC, 1050);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% 상태 읽기 블록 (3·4단계 공통)
% =====================================================================
function addOdomReader(m, withSpeed, anim, gate, org)
%   ANIM  true 이면 실시간 화면이 쓸 신호(위치·속도)를 **더 뽑아** 태그로 건다.
%         제어에는 쓰이지 않는다. 뽑는 자리가 늘 뿐 제어 경로는 그대로다.
%   ORG   [x y] — OdomSub 의 왼쪽 위 모서리. **운동모델 단계의 열**이다.
%         오프라인 쌍둥이의 MotionModel 이 서 있는 바로 그 자리에 선다.
%         배의 상태를 내놓는 자리가 같아야 두 모델이 같은 그림으로 읽힌다.
%
%   OdomTap 은 셀렉터 **바로 아래**에 둔다. 화면용 신호를 뽑기만 하는 상자여서
%   로깅 열로 보내면 버스에서 나온 선 넷이 도면을 가로질러 서로 겹친다
%   (2026-09-30 측정). 사슬보다 아래에 나란히 있으면 check_flow 도 통과다 —
%   model-layout.md §1 의 "오른쪽 끝 또는 그 아래에 나란히".
    if nargin < 3, anim = false; end
    if nargin < 4, gate = false; end
    if nargin < 5 || isempty(org), org = [40 40]; end
    x0 = org(1);  y0 = org(2);
    xTag = x0 + 530;                     % 태그는 이 열에 한 줄로
    add_block('ros2lib/Subscribe', [m '/OdomSub'], ...
              'Position',[x0 y0 x0+120 y0+60]);
    set_param([m '/OdomSub'], 'topicSource','Specify your own', ...
              'topic','/wamv/sensors/position/ground_truth_odometry', ...
              'messageType','nav_msgs/Odometry', 'sampleTime','0.05');

    sig = ['pose.pose.orientation.x,pose.pose.orientation.y,' ...
           'pose.pose.orientation.z,pose.pose.orientation.w'];
    if withSpeed
        sig = [sig ',twist.twist.linear.x'];
    end
    %  요각속도는 **항상** 뽑는다. 헤딩 제어의 D 항이 이 값을 쓴다.
    %  맨 뒤에 붙이므로 앞의 포트 번호는 그대로다.
    sig = [sig ',twist.twist.angular.z'];
    iWz = 5 + double(withSpeed);

    %  실시간 화면용 신호도 **맨 뒤에** 붙인다. 그래야 위 포트 번호가 그대로다
    if anim
        sig  = [sig ',pose.pose.position.x,pose.pose.position.y,twist.twist.linear.y'];
        iPx  = iWz + 1;  iPy = iWz + 2;  iVy = iWz + 3;
        if withSpeed
            iVx = 5;                       % 이미 뽑아 둔 것을 나눠 쓴다
        else
            sig = [sig ',twist.twist.linear.x'];
            iVx = iWz + 4;
        end
    end

    %  셀렉터와 Quat2Yaw 를 넉넉히 벌린다. 붙여 놓으면 출력 여섯~아홉 개가
    %  60 px 안에서 입력 다섯 개로 모이며 선이 서로 겹친다 (2026-09-30)
    add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], ...
              'Position',[x0+170 y0 x0+180 y0+220]);
    set_param([m '/Sel'], 'OutputSignals', sig);
    %  Subscribe 의 2번 출력(버스)을 셀렉터 입력 **높이에 맞춘다.** Subscribe 는
    %  출력이 둘(isNew·msg)이라 2번 포트가 아래쪽에 있어, 블록 가운데를 맞추면
    %  선이 두 번 꺾인다 (2026-10-01 꺾임 2회 세기에서 네 모델 모두 잡혔다)
    align_to(m, 'OdomSub', 'Outport', port_xy(m, 'Sel', 'Inport', 1), 2);
    add_line(m,'OdomSub/2','Sel/1','autorouting','on');

    %  GATE  true 이면 Quat2Yaw 가 셋째 출력 ok 를 내고 태그 odom_ok 로 건다.
    %        제어기가 있는 모델(3·4단계)만 쓴다 — addFirstMsgGate 가 이 태그로 추력을 막는다.
    if gate
        hdr   = 'function [psi_ned, r, ok] = Quat2Yaw(qx, qy, qz, qw, wz)';
        okFcn = [ newline ...
            '% ok = 0 holds the thrusters at 0 (addFirstMsgGate). Two reasons:' newline ...
            '%  1) Before the first odometry arrives the Subscribe block outputs an all-zero bus.' newline ...
            '%     A zero quaternion reads as exactly 90 deg.' newline ...
            '%  2) Simulink stalls for up to a few wall-clock seconds in its first steps while' newline ...
            '%     Gazebo keeps running on the first thrust command. The boat turned 9 to 55 deg' newline ...
            '%     before the model resumed (2026-09-24). So wait 1 s (20 samples) after the first' newline ...
            '%     valid message, then start the step from a boat that is still at rest.' newline ...
            'persistent n' newline ...
            'if isempty(n), n = 0; end' newline ...
            'valid = qx ~= 0 || qy ~= 0 || qz ~= 0 || qw ~= 0;' newline ...
            'if valid, n = n + 1; end' newline ...
            'ok = double(valid && n > 20);' newline];
    else
        hdr   = 'function [psi_ned, r] = Quat2Yaw(qx, qy, qz, qw, wz)';
        okFcn = '';
    end
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Quat2Yaw'], ...
              'Position',[x0+340 y0 x0+460 y0+150]);
    setFcn(m, 'Quat2Yaw', [ ...
        hdr newline ...
        '%#codegen' newline ...
        '% ROS quaternion (ENU body) -> NED heading [rad] and yaw rate [rad/s]' newline ...
        'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));' newline ...
        'psi = pi/2 - yaw_enu;' newline ...
        'psi_ned = atan2(sin(psi), cos(psi));   % wrap to [-pi, pi]' newline ...
        '' newline ...
        '% psi_ned = pi/2 - yaw_enu  ->  d(psi_ned)/dt = -d(yaw_enu)/dt.' newline ...
        '% ENU is z-up and NED is z-down, so the turn direction flips.' newline ...
        'r = -wz;' newline okFcn]);
    for k = 1:4
        add_line(m, sprintf('Sel/%d',k), sprintf('Quat2Yaw/%d',k), 'autorouting','on');
    end
    add_line(m, sprintf('Sel/%d',iWz), 'Quat2Yaw/5', 'autorouting','on');

    %  상태는 **신호 이름 그대로** 태그로 낸다 — psi · r. 제어기·Scope·로깅이
    %  전부 이 태그 하나씩을 From 으로 받는다 (한 신호에 태그 하나, 2026-10-01)
    %  제어기가 없는 모델(1·2단계)에서는 psi·r 을 **아무도 받지 않는다.** 받는
    %  From 이 없는 Goto 는 도면만 늘린다 — 화면용은 anim 묶음으로 따로 간다
    if gate
        tapGotos(m, 'Quat2Yaw', {'psi','r','odom_ok'}, xTag);
    end
    if withSpeed
        %  속도 u 는 버스에서 바로 나온다 (twist.twist.linear.x). 태그 이름도 u.
        %  자리는 drop_tag 가 **출발 포트 옆**에 잡는다 (2026-10-01 교수 지시)
        dropTag(m, 'Sel', 5, 'u', 120);
    end

    if ~anim, return, end

    %  ---- 실시간 화면이 쓸 신호를 NED 로 바꿔 태그에 건다 -----------------
    %  ENU (ROS · Gazebo) -> NED (선박) 는 3주차 1-5 절의 그 규약이다.
    %  위치  x_n(북) = p_y(ENU),  y_n(동) = p_x(ENU)
    %  속도  선체 고정축은 ROS 가 FLU (앞-왼쪽-위), NED 는 앞-오른쪽-아래다.
    %        전진 u 는 같고, 옆으로 미는 v 는 **부호가 뒤집힌다.**
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/OdomTap'], ...
              'Position',[x0+340 y0+300 x0+480 y0+520]);
    setFcn(m, 'OdomTap', [ ...
        'function [x_n, y_n, u, v] = OdomTap(px, py, vx, vy)' newline ...
        '%#codegen' newline ...
        '% Ground truth odometry -> the numbers the live plot draws.' newline ...
        '% Display only: nothing here feeds the controller.' newline ...
        'x_n = py;      % ENU y is north' newline ...
        'y_n = px;      % ENU x is east' newline ...
        'u   =  vx;     % surge is the same in FLU and NED body axes' newline ...
        'v   = -vy;     % FLU +y is port, NED +y is starboard' newline]);
    set_param([m '/OdomTap'], 'Position',[x0+340 y0+300 x0+480 y0+520]);
    add_line(m, sprintf('Sel/%d',iPx), 'OdomTap/1', 'autorouting','on');
    add_line(m, sprintf('Sel/%d',iPy), 'OdomTap/2', 'autorouting','on');
    add_line(m, sprintf('Sel/%d',iVx), 'OdomTap/3', 'autorouting','on');
    add_line(m, sprintf('Sel/%d',iVy), 'OdomTap/4', 'autorouting','on');

    %  화면용 여덟 신호는 **Mux 하나**로 묶어 태그 `anim` 하나로 보낸다.
    %  FL·FR 은 이 자리에서 아직 만들어지지 않았으므로(추력 발행단이 뒤에 선다)
    %  '#FL' · '#FR' 로 적어 두면 animBundle 이 From 을 만들어 꽂는다
    animBundle(m, {'OdomTap/1','OdomTap/2','Quat2Yaw/1','OdomTap/3', ...
                   'OdomTap/4','Quat2Yaw/2','#FL','#FR'}, ...
               x0+620, y0+300, 340);
end

% =====================================================================
% 선수각 오차 함수 — **이 파일에서 이 한 곳에만 있다**
%
%   HeadingCtrl 안의 HeadingErr 과 W04_7_ssa_test 의 시험용 상자가 **같은 문자열**을
%   받는다. 복사본을 두 벌 두면 한쪽만 고쳐져 어긋난다 — 시험용 모델이 통과해도
%   진짜 제어기는 다른 코드를 돌리고 있는, 가장 나쁜 종류의 사고다.
%   고칠 일이 생기면 아래 함수 하나만 고친다.
% =====================================================================
function c = headingErrCode()
    c = [ ...
        'function e = HeadingErr(psi_ref, psi, use_ssa)' newline ...
        '%#codegen' newline ...
        '% Heading error [rad].' newline ...
        'd = psi_ref - psi;' newline ...
        'if use_ssa >= 0.5' newline ...
        '    % ssa : shortest signed angle, wrapped to (-pi, pi]' newline ...
        '    e = atan2(sin(d), cos(d));' newline ...
        'else' newline ...
        '    % no wrap : 170 deg -> -170 deg becomes -340 deg, not +20 deg' newline ...
        '    e = d;' newline ...
        'end' newline];
end

% =====================================================================
% 자동 정지 — 할 일이 끝나면 모델이 스스로 Stop 을 누른다
%
%   교수 지시 2026-10-02. "inf 무한대까지 시뮬레이션 하지 말고, 끝나면
%   Stop 버튼으로 시뮬링크에서 자동으로 멈추게 해 달라."
%
%   어떻게 끝났다고 아는가 / how it knows it is done
%       선수각 오차가 settle_band [deg] 안에 들어와 settle_hold [s] 를
%       버티면 끝난 것으로 본다. "들어왔다" 가 아니라 "버텼다" 로 재는 이유는,
%       오버슈트로 지나가는 길에 한 번 스치는 것과 실제로 자리를 잡은 것을
%       가르기 위해서다.
%
%   버틴 시간을 **연속으로** 센다
%       적분기 하나면 된다. 입력은 1, 외부 리셋은 "오차가 띠 밖" 이다.
%       띠 안에 있는 동안 적분기는 1초에 1씩 올라가고, 한 번이라도 벗어나면
%       0 으로 떨어진다. 그 값이 settle_hold 를 넘으면 Stop 이다.
%       Memory 나 Unit Delay 가 필요 없다 — 모델 전체를 연속으로 두는
%       규칙(2026-10-01)을 깨지 않는다.
%
%   StopTime 은 그대로 T_run 으로 남는다. 영영 안정되지 않는 게인을 학생이
%   넣어 보더라도 T_run 에서는 반드시 끝난다.
function addAutoStop(m, x, y, withSpeed)
    if nargin < 4, withSpeed = false; end
    pin = {'psi_ref','psi'};
    if withSpeed, pin = {'psi_ref','psi','u_ref','u'}; end
    s = add_subsys(m, 'AutoStop', [x y x+150 y+90], pin, {}, ...
                   gnc_colour('logging'));

    %  오차는 여기서 직접 구한다. ssa 로 접어야 ±180 deg 이음매에서 340 deg 로
    %  읽히지 않는다 (2-11 절). 제어기의 use_ssa 스위치와는 무관하다 —
    %  **끝났는지 재는 자[尺]는 언제나 접은 값**이어야 한다
    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/ErrDeg'], ...
              'Position',[60 85 190 135]);
    setFcn(s, 'ErrDeg', [ ...
'function e = ErrDeg(psi_ref, psi)'                              newline ...
'%#codegen'                                                      newline ...
'% 선수각 오차 [deg], ssa 로 접은 최단 각'                        newline ...
'd = psi_ref - psi;'                                             newline ...
'e = atan2(sin(d), cos(d)) * 180/pi;'                            newline]);

    add_block('simulink/Math Operations/Abs', [s '/AbsE'], ...
              'Position',[230 95 260 125]);
    add_block('simulink/Sources/Constant', [s '/Band'], ...
              'Value','settle_band', 'Position',[150 160 250 190]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/Outside'], ...
              'Operator','>', 'Position',[280 100 310 130]);

    %  띠 안에 머문 시간 [s] — 벗어나 있는 동안은 0 에 묶인다.
    %
    %  리셋은 **level** 이어야 한다. 'rising' 은 리셋 신호가 0 에서 1 로 올라가는
    %  **순간**에만 한 번 리셋한다. 그런데 실행 시작부터 오차가 띠 밖이면 그
    %  신호는 처음부터 1 이라 올라가는 모서리가 없다 — 리셋이 영영 안 걸리고
    %  적분기는 그냥 경과 시간을 센다. 2026-10-02 에 이것 때문에 내부루프가
    %  헤딩만 맞고 속도는 1.03 m/s 인 5.05 s 에 멈췄다. 'level' 은 신호가 1 인
    %  **동안** 초기값에 붙들어 두므로, 띠 안에 들어온 뒤부터 비로소 올라간다.
    add_block('simulink/Continuous/Integrator', [s '/HeldFor'], ...
              'ExternalReset','level', 'InitialCondition','0', ...
              'Position',[380 95 420 135]);
    add_block('simulink/Sources/Constant', [s '/One'], ...
              'Value','1', 'Position',[280 40 330 70]);

    add_block('simulink/Sources/Constant', [s '/Hold'], ...
              'Value','settle_hold', 'Position',[380 190 480 220]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/Done'], ...
              'Operator','>=', 'Position',[520 110 550 140]);
    add_block('simulink/Sinks/Stop Simulation', [s '/StopSim'], ...
              'Position',[610 110 650 140]);

    add_line(s,'psi_ref/1','ErrDeg/1','autorouting','on');
    add_line(s,'psi/1',    'ErrDeg/2','autorouting','on');
    add_line(s,'ErrDeg/1','AbsE/1','autorouting','on');
    add_line(s,'AbsE/1','Outside/1','autorouting','on');
    add_line(s,'Band/1','Outside/2','autorouting','on');
    add_line(s,'One/1','HeldFor/1','autorouting','on');

    if withSpeed
        %  속도 루프도 자리를 잡아야 끝난 것이다. 헤딩만 보고 멈추면 내부루프
        %  모델이 u = 1.03 m/s 인 채로 5 s 에 꺼진다 (2026-10-02 실측)
        add_sum(s, 'SumUerr', '+-', [250 260]);
        add_block('simulink/Math Operations/Abs', [s '/AbsU'], ...
                  'Position',[300 245 330 275]);
        add_block('simulink/Sources/Constant', [s '/BandU'], ...
                  'Value','settle_band_u', 'Position',[300 310 400 340]);
        add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/OutsideU'], ...
                  'Operator','>', 'Position',[420 250 450 280]);
        add_block('simulink/Logic and Bit Operations/Logical Operator', [s '/AnyOut'], ...
                  'Operator','OR', 'Inputs','2', 'Position',[500 170 530 210]);
        add_line(s,'u_ref/1','SumUerr/1','autorouting','on');
        add_line(s,'u/1',    'SumUerr/2','autorouting','on');
        add_line(s,'SumUerr/1','AbsU/1','autorouting','on');
        add_line(s,'AbsU/1','OutsideU/1','autorouting','on');
        add_line(s,'BandU/1','OutsideU/2','autorouting','on');
        add_line(s,'Outside/1', 'AnyOut/1','autorouting','on');
        add_line(s,'OutsideU/1','AnyOut/2','autorouting','on');
        add_line(s,'AnyOut/1','HeldFor/2','autorouting','on');
    else
        add_line(s,'Outside/1','HeldFor/2','autorouting','on');
    end
    add_line(s,'HeldFor/1','Done/1','autorouting','on');
    add_line(s,'Hold/1','Done/2','autorouting','on');
    add_line(s,'Done/1','StopSim/1','autorouting','on');
end

% =====================================================================
% 서지 속도 제어기 — 헤딩 제어기와 같은 층위의 상자 하나
% =====================================================================
function addSpeedCtrl(m, x, y, withGate)
% 속도 제어기를 **서브시스템 하나**로 만든다. 밖에서는 이 상자만 보인다.
%
%   입력  u_ref   [m/s]  목표 전진속도
%         u       [m/s]  지금 전진속도
%         gate    [0/1]  (VRX 만) 첫 odom 전에는 0 — 오차를 묶어 둔다
%   출력  X       [N]    전진력 지령
%
%   제어식
%
%       X = Kp_u * e  +  Ki_u * INT(e),      e = u_ref - u
%
%   왜 상자로 묶는가 / why a subsystem
%       전에는 SumU · GateE · PI_u 가 최상위에 흩어져 있었다. 바로 옆 헤딩
%       제어기는 상자 하나인데 속도 쪽만 속이 드러나, 도면을 보면 제어기가
%       몇 개인지 세기 어려웠다. 두 루프가 같은 층위의 상자 둘로 보여야
%       "안쪽 루프 둘이 추력 배분 하나로 모인다" 는 구조가 한눈에 읽힌다.
%       교수 지시 2026-10-02.
%
%   PI 는 **연속 시간**이다 (교수 지시 2026-10-01)
%       전에는 Discrete PID (Ts = 0.05, Forward Euler) 였다. 검사 도구가
%       이것을 놓치고 있었는데 (PID 블록의 BlockType 은 'SubSystem' 이다),
%       2026-10-02 에 check_discrete 를 고치면서 드러났다. 게인 P · I 와
%       출력 한계는 그대로 두고 시간 영역만 바꾼다.
%
%   예열 게이트 (VRX 만)
%       첫 odom 메시지가 오기 전에는 u 가 0 으로 들어와 오차가 1.5 m/s 로
%       잡힌다. 그대로 두면 적분기가 그 오차를 쌓아, 게이트가 열리는 순간
%       포화 500 N 에서 출발한다 (u 가 63 % 에 1.4 s 만에 닿는다 — 오프라인은
%       2.5 s, 2026-09-24 실측). 오차를 0 으로 묶어 두면 열린 뒤 오프라인과
%       같은 0 에서 출발한다. 오프라인 모델에는 이 포트가 없다.

    nIn = {'u_ref','u'};
    if withGate, nIn = {'u_ref','u','gate'}; end
    s = add_subsys(m, 'SpeedCtrl', [x y x+150 y+120], nIn, {'X'}, gnc_colour('control'));

    %  합산점은 부호 둘 다 왼쪽 가장자리에 — add_sum 의 머리글 참고 (2026-10-02)
    add_sum(s, 'SumU', '+-', [250 110]);

    add_block('simulink/Continuous/PID Controller', [s '/PI_u'], ...
              'Position',[430 80 530 140]);
    %  게인과 한계는 **전과 같은 값**이다 (P 300 · I 40 · ±500 N).
    %  바꾸는 것은 시간 영역뿐이다 — 값을 같이 건드리면 무엇 때문에 응답이
    %  달라졌는지 가릴 수 없게 된다
    set_param([s '/PI_u'], 'Controller','PI', 'TimeDomain','Continuous-time', ...
              'P','300', 'I','40', 'LimitOutput','on', ...
              'UpperSaturationLimit','500', 'LowerSaturationLimit','-500', ...
              'AntiWindupMode','clamping');

    add_line(s,'u_ref/1','SumU/1','autorouting','on');
    add_line(s,'u/1',    'SumU/2','autorouting','on');
    if withGate
        add_block('simulink/Math Operations/Product', [s '/GateE'], ...
                  'Position',[330 95 360 125]);
        add_line(s,'SumU/1',  'GateE/1','autorouting','on');
        add_line(s,'gate/1',  'GateE/2','autorouting','on');
        add_line(s,'GateE/1', 'PI_u/1', 'autorouting','on');
    else
        add_line(s,'SumU/1','PI_u/1','autorouting','on');
    end
    add_line(s,'PI_u/1','X/1','autorouting','on');
end

% =====================================================================
% 헤딩 제어기 (3·4단계 공통) — 독립 모듈 하나
% =====================================================================
function addHeadingCtrl(m, x, y)
% 헤딩 제어기를 **서브시스템 하나**로 만든다. 밖에서는 이 상자만 보인다.
%
%   입력  psi_ref [rad]    목표 선수각
%         psi     [rad]    지금 선수각
%         r       [rad/s]  지금 요각속도 (NED)
%   출력  N       [N*m]    요 모멘트 지령
%
%   제어식 — P 는 오차에, D 는 **요각속도에 직접**
%
%       N = Kp_psi * ssa(psi_ref - psi)  +  Ki_psi * INT(e)  -  Kd_psi * r
%
%   부호 규약 — **되먹임 게인은 양수, 빼는 일은 합산점이 한다** (교수 지시 2026-10-01).
%   Kd_psi 는 +400 이고 SumPD 가 '+-' 로 받는다. 게인에 마이너스를 숨겨 두면
%   도면만 보고는 덧셈인지 뺄셈인지 알 수 없다 — 부호는 **보이는 자리**에 둔다.
%   값의 뜻은 그대로다. -400 을 더하는 것과 +400 을 빼는 것은 같은 계산이다.
%
%   Ki_psi 는 기본 0 이다. 한쪽 추진기가 약할 때(port_eff < 1) PD 가 남기는
%   정상상태 오차를 없애는 자리이고, 그때만 켠다.
%
%   use_ssa 스위치 — HeadingErr 안의 if 한 줄
%       1 이면 ssa 로 접은 최단 오차, 0 이면 그냥 뺀 값이다. +-180 deg
%       이음매에서 20 deg 대신 340 deg 를 도는 것을 보이는 스위치다 (W04_6_wrap).
%
%   왜 오차를 미분하지 않는가
%       e = psi_ref - psi 이므로 de/dt = d(psi_ref)/dt - r 이고, 목표가 가만히
%       있는 동안에는 de/dt = -r 이다. 즉 -Kd*r 과 +Kd*de/dt 는 **같은 값**이다.
%       다만 목표가 계단으로 바뀌는 순간 de/dt 는 크게 튀고(미분 킥), r 은 배의
%       실제 회전이라 튀지 않는다. 같은 값을 더 얌전한 신호로 얻는 셈이다.
%
%   왜 빼는가
%       D 항은 **브레이크**다. 배가 왼쪽으로 돌고 있으면(r < 0) 그 회전을 멈추는
%       방향으로 모멘트를 내야 하므로 r 에 반대로 작용해야 한다. 빼기를 더하기로
%       바꾸면 감쇠가 Nr + Kd 에서 Nr - Kd 로 줄어 오버슈트가 커진다 (Kd = 400 에서
%       17 %, 4주차 2-8절·W04_heading_sign). 2차 항력 Nrr 이 버텨 발산까지는 가지 않는다.
%
%   MSS 툴박스의 demoOtterUSVHeadingControl 도 같은 구조다 (Fossen). 그쪽 D 항은
%   Kp*Td*(r_d - r) 인데, 목표 각속도 r_d = 0 이면 -Kp*Td*r 이다.

    %  상자를 150 px 로 키운다. 입력이 셋이라 90 px 이면 포트 간격이 23 px 이고,
    %  되먹임 psi·r 의 From 태그 두 개가 그 아래 같은 자리로 몰려 포개진다
    %  (2026-09-30 W04_6_wrap 의 Fr_MotionModel_1_1 / _2_1). 포트를 벌리면 풀린다
    s = add_subsys(m, 'HeadingCtrl', [x y x+150 y+150], ...
                   {'psi_ref','psi','r'}, {'N'}, gnc_colour('control'));

    %  use_ssa 가 0 이면 ssa 를 건너뛴다 — 같은 상자 안의 두 줄을 비교해 볼 것
    add_block('simulink/Sources/Constant', [s '/use_ssa_c'], ...
              'Value','use_ssa', 'Position',[60 260 160 290]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/HeadingErr'], ...
              'Position',[250 60 400 170]);
    setFcn(s, 'HeadingErr', headingErrCode());   % 코드는 headingErrCode 한 곳에만 있다

    add_block('simulink/Math Operations/Gain', [s '/Kp_psi'], ...
              'Gain','Kp_psi', 'Position',[520 80 570 110]);
    add_block('simulink/Math Operations/Gain', [s '/Ki_psi'], ...
              'Gain','Ki_psi', 'Position',[520 170 570 200]);
    %  **연속** 적분기다. 제어기는 연속으로 적는다 (교수 지시 2026-10-01).
    %  전에 이산으로 둔 이유는 VRX 쌍둥이의 솔버가 FixedStepDiscrete 여서
    %  "연속 상태가 포함되어 있다" 로 막혔기 때문인데, 그것은 **솔버 선택의
    %  문제이지 VRX 의 제약이 아니었다.** 고정스텝 연속 솔버 ode4 로 바꾸면
    %  같은 0.05 s 스텝으로 그대로 돈다 (2026-10-01 실측). setSolver 참조.
    add_block('simulink/Continuous/Integrator', [s '/IntegN'], ...
              'InitialCondition','0', 'LimitOutput','on', ...
              'UpperSaturationLimit','N_max', 'LowerSaturationLimit','-N_max', ...
              'Position',[620 170 650 200]);
    add_block('simulink/Math Operations/Gain', [s '/Kd_rate'], ...
              'Gain','Kd_psi', 'Position',[520 340 570 370]);
    %  '+-' — D 항을 **뺀다**. 게인 Kd_psi 는 양수이고 부호는 여기서 준다
    add_block('simulink/Math Operations/Sum', [s '/SumPD'], ...
              'Inputs','+-', 'Position',[700 80 730 110]);
    add_block('simulink/Math Operations/Sum', [s '/SumN'], ...
              'Inputs','++', 'Position',[790 80 820 110]);
    add_block('simulink/Discontinuities/Saturation', [s '/SatN'], ...
              'UpperLimit','N_max', 'LowerLimit','-N_max', ...
              'Position',[880 80 920 110]);

    add_line(s,'psi_ref/1',  'HeadingErr/1','autorouting','on');
    add_line(s,'psi/1',      'HeadingErr/2','autorouting','on');
    add_line(s,'use_ssa_c/1','HeadingErr/3','autorouting','on');
    add_line(s,'HeadingErr/1','Kp_psi/1','autorouting','on');
    add_line(s,'HeadingErr/1','Ki_psi/1','autorouting','on');
    add_line(s,'Ki_psi/1','IntegN/1','autorouting','on');
    add_line(s,'r/1',      'Kd_rate/1','autorouting','on');
    add_line(s,'Kp_psi/1', 'SumPD/1','autorouting','on');
    add_line(s,'Kd_rate/1','SumPD/2','autorouting','on');
    add_line(s,'SumPD/1',  'SumN/1','autorouting','on');
    add_line(s,'IntegN/1', 'SumN/2','autorouting','on');
    add_line(s,'SumN/1',   'SatN/1','autorouting','on');
    add_line(s,'SatN/1',   'N/1','autorouting','on');

    note(s, sprintf(['헤딩 제어기 — P 는 오차에, D 는 요각속도에\n' ...
        '\n' ...
        '    N = Kp_psi * e  +  Ki_psi * INT(e)  -  Kd_psi * r\n' ...
        '    e = ssa(psi_ref - psi)   (use_ssa = 0 이면 그냥 뺀 값)\n' ...
        '\n' ...
        '부호 규약 — 되먹임 게인은 **양수**로 두고 빼는 일은 합산점이 한다.\n' ...
        'Kd_psi = +400 이고 SumPD 가 "+-" 로 받는다. 브레이크인 것은 게인\n' ...
        '숫자가 아니라 **도면의 이 부호**가 말한다.\n' ...
        '더하기로 바꾸면 감쇠가 Nr - Kd 로 줄어 오버슈트가 커진다 (17 %%).\n' ...
        '\n' ...
        '목표가 가만히 있으면 de/dt = -r 이므로 오차 미분과 값이 같다.\n' ...
        '다만 목표가 계단으로 바뀔 때 de/dt 는 튀고 r 은 튀지 않는다.\n' ...
        '\n' ...
        'Ki_psi 는 기본 0 이다. 한쪽 추진기가 약할 때(port_eff < 1)\n' ...
        'PD 가 남기는 정상상태 오차를 없애는 자리다 (2-10 절 실습에서 켠다).\n' ...
        'IntegN 은 **연속** 적분기이고 +-N_max 포화가 걸려 있다\n' ...
        '(clamping 안티와인드업). 모델 솔버는 고정스텝 ode4 다.\n' ...
        '\n' ...
        'SatN 의 +-N_max = 500 N m 는 임의의 수가 아니다. 추진기만으로 낼 수\n' ...
        '있는 물리 한계가 2*b_half*F_max = 2*1.027135*250 = 513.57 N m 이고,\n' ...
        '500 은 그 97.4 %% 다. 전진 추력 X 를 함께 쓰면 2*b_half*(F_max - X/2)\n' ...
        '로 줄어, X_head = 300 N 에서는 205.4 N m 가 진짜 한계다 (2-5 절 유도 5).\n' ...
        '\n' ...
        '값은 전부 W04_setup.m — Kp_psi = 800, Kd_psi = +400.\n' ...
        '근거는 4주차 극배치 절과 W04_pole_place.m.']), 200, 430);
end

% =====================================================================
% 배분기 (3·4단계 공통) — 차동 추력배분 + 포화
% =====================================================================
function addAllocator(m, x, y)
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Alloc'], ...
              'Position',[x y x+140 y+70]);
    setFcn(m, 'Alloc', [ ...
        'function [FL, FR] = Alloc(X, N)' newline ...
        '%#codegen' newline ...
        '% Differential thrust allocation for the 2-thruster WAM-V' newline ...
        '%   X : surge force  [N]' newline ...
        '%   N : yaw moment   [N*m], positive turns to starboard' newline ...
        'B_half = 1.027135;      % half distance between thrusters [m]' newline ...
        'Fmax   = 250;           % thrust limit per thruster [N]' newline ...
        'FL = X/2 + N/(2*B_half);' newline ...
        'FR = X/2 - N/(2*B_half);' newline ...
        'FL = max(min(FL, Fmax), -Fmax);' newline ...
        'FR = max(min(FR, Fmax), -Fmax);' newline]);
end

% =====================================================================
% 오프라인 운동모델 (3·4단계 쌍둥이 공통) — Gazebo 자리를 대신한다
%   입력 FL, FR [N]   출력 psi [rad], r [rad/s], u [m/s]
%   식과 계수는 3주차 1-8 절 · W03_0_offline 과 같다.
%   초기 선수각은 VRX 스폰과 같게 32.7 deg (3주차 3-1 좌표 검산)
% =====================================================================
function addMotionModel(m, x, y, psi0, anim)
%   PSI0  초기 선수각을 rad 로 적은 문자열. 생략하면 VRX 스폰과 같은 32.7 deg
%   ANIM  true 이면 실시간 화면이 쓸 여덟 신호를 상자 **안에서** 태그로 건다.
%         밖에서 보이는 포트(psi · r · u)는 그대로다 — 제어 배선이 바뀌지 않는다.
    if nargin < 4 || isempty(psi0), psi0 = '32.7*pi/180'; end
    if nargin < 5, anim = false; end
    s = add_subsys(m, 'MotionModel', [x y x+150 y+110], ...
                   {'FL','FR'}, {'psi','r','u'}, gnc_colour('plant'));
    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/EOM'], ...
              'Position',[200 40 340 160]);
    setFcn(s, 'EOM', [ ...
'function xdot = EOM(s, FL, FR)'                                        newline ...
'%#codegen'                                                             newline ...
'% 3-DOF WAM-V equations of motion, NED (3주차 1-8 절).'                  newline ...
'%   s = [u v r x_n y_n psi]'''                                          newline ...
'm = 211;  Izz = 653;  Xu = 100;  Xuu = 150;  Yv = 100;  Yvv = 100;'    newline ...
'Nr = 800;  Nrr = 800;  b_half = 1.027135;'                             newline ...
'u = s(1); v = s(2); r = s(3); psi = s(6);'                             newline ...
'X = FL + FR;'                                                          newline ...
'N = (FL - FR)*b_half;'                                                 newline ...
'du = (X - (Xu + Xuu*abs(u))*u)/m + v*r;'                               newline ...
'dv = (  - (Yv + Yvv*abs(v))*v)/m - u*r;'                               newline ...
'dr = (N - (Nr + Nrr*abs(r))*r)/Izz;'                                   newline ...
'xdot = [du; dv; dr;'                                                   newline ...
'        u*cos(psi) - v*sin(psi);'                                      newline ...
'        u*sin(psi) + v*cos(psi);'                                      newline ...
'        r];']);
    add_block('simulink/Continuous/Integrator', [s '/Integ'], ...
              'Position',[400 80 440 120], ...
              'InitialCondition',['[0;0;0;0;0;' psi0 ']']);
    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/States'], ...
              'Position',[500 40 620 160]);
    setFcn(s, 'States', [ ...
'function [psi, r, u] = States(s)'                                      newline ...
'%#codegen'                                                             newline ...
'% Quat2Yaw 와 같은 출력 — 선수각은 [-pi, pi] 로 접는다'                   newline ...
'psi = atan2(sin(s(6)), cos(s(6)));'                                    newline ...
'r = s(3);'                                                             newline ...
'u = s(1);']);
    add_line(s,'FL/1','EOM/2','autorouting','on');
    add_line(s,'FR/1','EOM/3','autorouting','on');
    hDot = add_line(s,'EOM/1','Integ/1','autorouting','on');
    set_param(hDot, 'Name', 'xdot');     % 태그가 되더라도 이름이 신호 이름이 되게
    %  상태벡터가 EOM 으로 되돌아가는 선이다. 세 번 꺾이므로 tidy_model 이 태그로
    %  바꾸는데, **선에 이름을 주어 두면 그 이름이 곧 태그 이름이 된다.**
    %  이름을 안 주면 블록 이름에서 딴 Integ_1 이 된다 (2026-10-01 교수 지시)
    hState = add_line(s,'Integ/1','EOM/1','autorouting','on');
    set_param(hState, 'Name', 'state');
    add_line(s,'Integ/1','States/1','autorouting','on');
    add_line(s,'States/1','psi/1','autorouting','on');
    add_line(s,'States/2','r/1','autorouting','on');
    add_line(s,'States/3','u/1','autorouting','on');

    if ~anim, return, end

    %  ---- 실시간 화면이 쓸 여덟 신호 -----------------------------------
    %  States 는 제어가 쓰는 셋(psi · r · u)만 낸다. 화면은 항적과 추력까지
    %  보여야 하므로 상태벡터 s 와 들어온 추력을 한 번 더 들여다본다.
    %  **구경만 한다.** 여기서 나간 값은 태그로만 가고 되돌아오지 않는다.
    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/AnimTap'], ...
              'Position',[420 300 570 760]);
    setFcn(s, 'AnimTap', [ ...
'function [x_n, y_n, psi, u, v, r, fl, fr] = AnimTap(sv, FL, FR)'       newline ...
'%#codegen'                                                             newline ...
'% Display-only tap. sv = [u v r x_n y_n psi]'''                        newline ...
'x_n = sv(4);'                                                          newline ...
'y_n = sv(5);'                                                          newline ...
'psi = atan2(sin(sv(6)), cos(sv(6)));   % wrap to [-pi, pi]'            newline ...
'u   = sv(1);'                                                          newline ...
'v   = sv(2);'                                                          newline ...
'r   = sv(3);'                                                          newline ...
'fl  = FL;'                                                             newline ...
'fr  = FR;']);
    set_param([s '/AnimTap'], 'Position',[420 300 570 760]);
    add_line(s,'Integ/1','AnimTap/1','autorouting','on');
    add_line(s,'FL/1',   'AnimTap/2','autorouting','on');
    add_line(s,'FR/1',   'AnimTap/3','autorouting','on');
    %  여덟 출력을 태그 여덟 개로 내보내던 것을 Mux 하나로 묶었다 (2026-10-01).
    %  나가는 태그는 `anim` 하나뿐이고, 순서는 animBundle 의 표가 정한다
    animBundle(s, {'AnimTap/1','AnimTap/2','AnimTap/3','AnimTap/4', ...
                   'AnimTap/5','AnimTap/6','AnimTap/7','AnimTap/8'}, 680, 300, 460);
end

function setSolverOffline(m)
    % 연속 적분기가 있으므로 ode4. 스텝은 VRX 모델과 같은 0.05 s
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','0.05', 'StopTime','40', 'SimulationMode','normal');
end

% =====================================================================
% 로깅 — 모델 하나에 To Workspace **한 개**
%
%   교수 지시 2026-10-01. "신호마다 To Workspace 가 하나씩 붙어 블록이 너무 많다.
%   묶어서 하나로. 저장되는 신호의 개수·이름·값은 그대로."
%
%   Bus Creator 가 신호를 묶고, To Workspace 하나가 그 버스를 받는다.
%   SaveFormat 이 Timeseries 이므로 결과는 **필드 이름이 살아 있는 구조체**다.
%
%       out.log.psi   out.log.r   out.log.FL  ...
%
%   이름은 버스로 들어가는 **선의 이름**에서 온다. 그래서 아래에서 선마다
%   set_param(line,'Name', ...) 을 한다 — 이름을 안 주면 signal1, signal2 가 된다.
%   덤으로 도면에도 신호 이름이 찍힌다.
%
%   ENTRIES  {'Sweep/1','e_ssa'; 'Fr_d_1/1','d'; ...}  {출발포트, 신호이름}
% =====================================================================
function addLogBus(m, entries, x, y)
    n = size(entries,1);
    bc = [m '/LogBus'];
    add_block('simulink/Signal Routing/Bus Creator', bc, ...
              'Inputs', num2str(n), 'Position',[x y x+5 y+40*n]);
    for k = 1:n
        h = add_line(m, entries{k,1}, sprintf('LogBus/%d',k), 'autorouting','on');
        set_param(h, 'Name', entries{k,2});   % 이 이름이 곧 out.log 의 필드 이름이다
    end
    tw = [m '/log'];
    add_block('simulink/Sinks/To Workspace', tw, ...
              'Position',[x+120 y+20*n-15 x+220 y+20*n+15]);
    set_param(tw, 'VariableName','log', 'SaveFormat','Timeseries', 'SampleTime','0.05');
    add_line(m, 'LogBus/1', 'log/1', 'autorouting','on');
end

% ---- 태그에서 받아 한 자리에 모아 저장한다 (배 모델의 표준 로깅) --------
%
%   NAMES 의 각 이름은 **신호 이름이자 태그 이름이자 필드 이름**이다.
%   신호마다 From 하나를 Bus Creator 바로 왼쪽에 세우므로 선은 수평 직선이고,
%   로깅 블록이 사슬 한가운데로 끌려 들어가지 않는다.
%
%     out = sim('W04_3_heading_offline');   out.log.psi   out.log.N   ...
% =====================================================================
% 관찰용 Scope — 모델 하나에 **한 개**
%
%   교수 지시 2026-10-02. "scope 로 궤적은 필요 없다. 하나의 scope 에서
%   각 제어 명령과 실제 값을 볼 수 있게 해 달라."
%
%   왜 하나인가 / why one
%       전에는 Scope_u 와 Scope_psi 두 개였다. 창을 둘 띄워 놓고 눈이 왕복해야
%       했고, 시간축을 맞춰 보려면 두 창을 나란히 끌어다 놓아야 했다. 한 창에
%       칸을 나눠 쌓으면 **같은 시간축**에 전부 걸리므로, 속도가 흔들린 그 순간
%       헤딩이 무엇을 하고 있었는지가 세로로 읽힌다.
%
%       궤적은 Scope 에 넣지 않는다. 궤적은 x-y 평면 그림이라 시간축 Scope 와
%       축이 다르고, 실시간 화면(W04_animate)의 왼쪽 큰 칸이 이미 그 일을 한다.
%
%   PAIRS  {지령태그, 실제태그} 를 칸 순서대로. 지령이 없는 칸은 ''
%
%       addCompareScope(m, {'u_ref','u'; 'psi_ref','psi'; '','FL'; '','FR'}, x, y)
%
%   한 칸에 지령과 실제값을 겹쳐 놓으므로 오버슈트·정정시간·남는 오차가 그
%   칸 안에서 바로 읽힌다. 지령이 없는 칸은 응답선 하나만 그린다.
function addCompareScope(m, pairs, x, y)
    nAx  = size(pairs,1);
    sc   = [m '/Scope'];
    add_block('simulink/Sinks/Scope', sc, 'Position',[x+170 y x+220 y+50*nAx]);

    %  칸마다 포트 하나. 지령이 있는 칸은 Mux 로 두 선을 묶어 한 포트로 넣는다.
    %  포트가 여럿이면 Scope 는 칸을 세로로 쌓아 같은 시간축에 걸어 준다
    %  (칸 수를 따로 지정하는 LayoutDimensions 는 set_param 으로는 못 쓴다)
    set_param(sc, 'NumInputPorts', num2str(nAx));

    for i = 1:nAx
        ref = pairs{i,1};  act = pairs{i,2};
        yi  = y + 50*(i-1);
        if isempty(ref)
            fromTo(m, act, 'Scope', i, 110);
        else
            mx = sprintf('%s/MuxSc%d', m, i);
            add_block('simulink/Signal Routing/Mux', mx, ...
                      'Inputs','2', 'Position',[x+120 yi x+125 yi+40]);
            dropFromInto(m, ref, mx, 1, x, yi);
            dropFromInto(m, act, mx, 2, x, yi+22);
            add_line(m, sprintf('MuxSc%d/1', i), sprintf('Scope/%d', i), ...
                     'autorouting','on');
        end
    end
end

function dropFromInto(m, tag, mux, port, x, y)
%  From 하나를 Mux 포트 바로 왼쪽에 세운다 (선이 수평 직선이 되게)
    nm = from_name(m, tag);
    add_block('simulink/Signal Routing/From', [m '/' nm], ...
              'GotoTag', tag, 'Position',[x y x+70 y+20]);
    add_line(m, [nm '/1'], sprintf('%s/%d', get_param(mux,'Name'), port), ...
             'autorouting','on');
end

function addLogFromTags(m, names, x, y)
    n  = numel(names);
    bc = [m '/LogBus'];
    %  From 은 측정 열의 **맨 왼쪽**(x), Bus Creator 는 그 **바로** 오른쪽에 둔다.
    %  전에는 From 을 x-180 에 두었다가 운동모델 위에 올라앉았다 (2026-10-01).
    %  틈은 40 px 이다. 200 px 을 띄우면 선이 쓸데없이 길어진다 — 태그는 받는
    %  포트 바로 옆에 있어야 한다 (2026-10-01 교수 지시, snug_tags 와 같은 규칙)
    add_block('simulink/Signal Routing/Bus Creator', bc, ...
              'Inputs', num2str(n), 'Position',[x+110 y x+115 y+65*n]);
    for k = 1:n
        q = port_xy(m, 'LogBus', 'Inport', k);
        %  Bus Creator 입력 포트 높이를 **읽어서** 놓는다. 계산으로 맞추면 사선이 된다.
        %  블록 이름은 'Fr_<태그>', 중복이면 번호만 (from_name.m) — 2026-10-01 교수 지시
        nm = from_name(m, names{k});
        add_block('simulink/Signal Routing/From', [m '/' nm], ...
                  'GotoTag', names{k}, 'Position',[x q(2)-11 x+70 q(2)+11]);
        h = add_line(m, [nm '/1'], sprintf('LogBus/%d',k));
        set_param(h, 'Name', names{k});   % 이 이름이 곧 out.log 의 필드 이름이다
    end
    q = port_xy(m, 'LogBus', 'Outport', 1);
    tw = [m '/log'];
    add_block('simulink/Sinks/To Workspace', tw, ...
              'Position',[x+190 q(2)-15 x+290 q(2)+15]);
    set_param(tw, 'VariableName','log', 'SaveFormat','Timeseries', 'SampleTime','0.05');
    add_line(m, 'LogBus/1', 'log/1');
end


% =====================================================================
% 3단계 — 헤딩 제어  (offline = true 이면 오프라인 쌍둥이)
% =====================================================================
function build_heading(offline)
    %  [지령] -> [제어기·개루프 스위치] -> [배분·좌현효율] -> [운동모델] -> [로깅·화면]
    %  오프라인과 VRX 는 **운동모델 열만 다르다.** 오프라인은 MotionModel 한 상자,
    %  VRX 는 그 자리에 추력 발행과 오도메트리 구독이 선다 (model-layout.md §1)
    if offline
        m = 'W04_3_heading_offline'; fresh(m);
        P = w04cols('command',300, 'controller',350, 'allocation',250, ...
                    'plant',160, 'measurement',260);
    else
        m = 'W04_3_heading'; fresh(m);
        P = w04cols('command',300, 'controller',350, 'allocation',250, ...
                    'plant',620, 'measurement',300);
    end
    xC = P.command(1);  xK = P.controller(1);  xA = P.allocation(1);
    xP = P.plant(1);    xM = P.measurement(1);

    %  실시간 화면 상자는 사슬 **바로 아래**에 둔다. 더 내리면 lay_sinks 가
    %  로깅 열을 그보다 또 아래로 밀어, 도면 한가운데가 텅 비고 세로선만 길어진다
    if offline
        addMotionModel(m, xP, 190, '', true);      % true = 실시간 화면용 태그까지
        yAnim = 560;
    else
        %  마지막 true = 첫 메시지 전 추력 차단
        addOdomReader(m, false, true, true, [xP 430]);
        yAnim = 1020;
    end

    add_block('simulink/Sources/Constant', [m '/psi_ref_deg'], ...
              'Value','psi_ref_deg', 'Position',[xC 200 xC+90 230]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad'], ...
              'Gain','pi/180', 'Position',[xC+130 200 xC+170 230]);
    addHeadingCtrl(m, xK, 185);

    %  제어기를 통째로 건너뛰는 스위치. head_open = 1 이면 계단 모멘트를 직접 준다
    %  자리는 **제어기 바로 뒤, 배분 앞** — 신호가 실제로 지나가는 그 자리다
    add_switch_box(m, 'OpenLoop', [xK+210 185 xK+350 275], {'N_ctrl','N_raw'}, 'head_open', ...
        struct('name','N_step', 'lib','simulink/Sources/Constant', ...
               'params',{{'Value','N_open'}}, 'fed',false, 'w',55, 'h',30), ...
        gnc_colour('control'), sprintf([ ...
        '제어기를 쓸 것인가, 요 모멘트를 직접 줄 것인가\n' ...
        '\n' ...
        '  head_open = 0   HeadingCtrl 이 낸 모멘트 (폐루프)\n' ...
        '  head_open = 1   N_open [N m] 을 그대로 (개루프)\n' ...
        '\n' ...
        '개루프로 두고 Scope 를 보면 선수각이 **끝없이 올라간다.**\n' ...
        '일정 모멘트 -> 일정 선회율 -> psi 는 멈추지 않는다.\n' ...
        '배가 이미 적분기를 하나 갖고 있다는 뜻이다 (dpsi/dt = r).\n' ...
        '\n' ...
        '  >> W04_heading_compare(''open'')']));

    %  제어기 상자(185~335)의 **이름표 아래**로 충분히 내린다. 340 에 두면
    %  Alloc 으로 가는 선이 HeadingCtrl 의 이름 글자 위를 지난다 (2026-10-01)
    add_block('simulink/Sources/Constant', [m '/X_const'], ...
              'Value','X_head', 'Position',[xC 400 xC+80 430]);

    addAllocator(m, xA, 200);
    add_line(m,'X_const/1','Alloc/1','autorouting','on');
    add_line(m,'HeadingCtrl/1','OpenLoop/1','autorouting','on');
    add_line(m,'OpenLoop/1','Alloc/2','autorouting','on');
    add_line(m,'psi_ref_deg/1','deg2rad/1','autorouting','on');
    add_line(m,'deg2rad/1', 'HeadingCtrl/1','autorouting','on');

    %  ---- 신호마다 태그 하나 (2026-10-01 교수 지시) -----------------------
    %  psi_ref 는 지령 열에서 나와 Scope·화면·제어기로 간다. 제어기는 바로
    %  옆이라 **선**이고, 멀리 있는 Scope·화면·로깅만 From 으로 받는다
    dropTag(m, 'deg2rad', 1, 'psi_ref', 120);

    %  되먹임 psi·r 은 운동모델에서 제어기로 **되돌아가는** 신호다. 선으로
    %  이으면 화면을 가로지르므로 태그로 남긴다 — 이름은 신호 이름 그대로
    fromTo(m, 'psi', 'HeadingCtrl', 2, 110);
    fromTo(m, 'r',   'HeadingCtrl', 3, 190);

    %  좌현 추진기를 약하게 만드는 자리. port_eff = 1 이면 아무 일도 안 한다
    %  배분 바로 뒤 — 추력이 실제로 줄어드는 그 자리에 둔다
    add_block('simulink/Math Operations/Gain', [m '/PortEff'], ...
              'Gain','port_eff', 'Position',[xA+200 200 xA+250 236]);
    add_line(m,'Alloc/1','PortEff/1','autorouting','on');

    %  N 은 제어기 열에서 나와 배분(바로 옆, 선)과 로깅(멀리, 태그)으로 간다
    tapGotos(m, 'OpenLoop', {'N'}, xK+390);

    if offline
        add_line(m,'PortEff/1','MotionModel/1','autorouting','on');
        add_line(m,'Alloc/2',  'MotionModel/2','autorouting','on');
        %  배로 실제 들어가는 추력 — 오프라인은 PortEff 를 지난 값이 그것이다
        tapGotos(m, 'PortEff', {'FL'}, xA+280);
        tapGotos(m, 'Alloc',   {'', 'FR'}, xA+280);
        %  운동모델이 내는 상태 — 신호 이름 그대로 태그 하나씩
        tapGotos(m, 'MotionModel', {'psi','r'}, xP+180);
    else
        addThrusterPublisher(m, 'left',  'L', xP+170, 90);
        addThrusterPublisher(m, 'right', 'R', xP+170, 270);
        addFirstMsgGate(m, 'PortEff/1', 'L', xP,     60);
        addFirstMsgGate(m, 'Alloc/2',   'R', xP,    240);
        %  VRX 는 게이트를 지난 값 — 배로 실제 나간 추력. 지표의 시작 시각을 여기서 읽는다
        dropTag(m, 'GateL', 1, 'FL', 120);   % 게이트 **바로 아래** — 가지가 길어지지 않는 자리
        dropTag(m, 'GateR', 1, 'FR', 120);
        %  psi · r 태그는 addOdomReader 가 이미 걸어 두었다
    end

    % 관찰용 — **Scope 하나**에 지령과 실제값을 나란히 (교수 지시 2026-10-02)
    addCompareScope(m, {'psi_ref','psi'; '','N'; '','FL'; '','FR'}, xM, 60);

    %  헤딩이 자리를 잡으면 스스로 멈춘다 (속도 루프가 없으므로 헤딩만 본다)
    addAutoStop(m, xM, 320);
    fromTo(m, 'psi_ref', 'AutoStop', 1, 110);
    fromTo(m, 'psi',     'AutoStop', 2, 190);

    %  로깅은 To Workspace **한 개**다. Bus Creator 가 다섯 신호를 묶고,
    %  꺼낼 때는 이름이 그대로 살아 있다 — out.log.psi · out.log.FL · ...
    addLogFromTags(m, {'psi','r','FL','FR','N'}, xM, 200);

    %  ---- 실시간 화면 ----------------------------------------------------
    %  헤딩 지령은 deg2rad 를 지난 rad 값을 그대로 쓴다 — 제어기가 보는 그 값이다.
    %  속도 지령은 **없다.** 이 모델은 헤딩만 돌린다 (전진 추력은 X_head 상수).
    %  그래서 속도 칸은 응답 u 만 그리고 "지령 없음" 이라고 적힌다.
    addW04Animate(m, xM, yAnim, false, true);

    if offline
        setSolverOffline(m);
        note(m, sprintf(['[3단계 오프라인] 헤딩 제어 — Gazebo 대신 운동방정식\n' ...
            'W04_3_heading 과 HeadingCtrl · OpenLoop · Alloc 이 같은 함수로 만들어졌다.\n' ...
            'OdomSub/Quat2Yaw 와 Publish 자리에 MotionModel 하나가 있다.\n' ...
            '초기 선수각 32.7 deg 는 VRX 스폰과 같다. 40 초가 1 초 안쪽에 끝난다.\n' ...
            '\n' ...
            '스위치는 전부 W04_setup.m 에 있다.\n' ...
            '  head_open = 0/1   폐루프 / 개루프 (OpenLoop 상자)\n' ...
            '  use_ssa   = 0/1   ssa 끔 / 켬     (HeadingCtrl 안)\n' ...
            '  port_eff  = 0.7   좌현 추진기를 30 %% 약하게 (PortEff 게인)\n' ...
            '  Ki_psi    > 0     port_eff 가 남긴 오차를 I 로 지운다\n' ...
            '\n' ...
            '  >> W04_heading_compare(''open''|''Kp''|''Kd''|''Ki''|''wrap'')\n' ...
            '비교: >> W04_step_compare(3)']), xC, 1050);
        save_system(m); close_system(m,0);
        fprintf('  [OK] %s\n', m);
        return
    end
    setSolver(m);
    note(m, sprintf(['[3단계] 헤딩 제어\n' ...
        '목표 선수각(psi_ref_deg)을 바꿔 가며 스텝응답을 본다.\n' ...
        'Scope_psi 에 실제 헤딩과 목표 헤딩이 함께 그려진다.\n' ...
        '\n' ...
        '제어기는 HeadingCtrl 상자 하나다. 더블클릭하면 안이 보인다.\n' ...
        '  N = Kp_psi * ssa(psi_ref - psi) + Ki_psi * INT(e) + Kd_psi * r\n' ...
        '게인은 전부 W04_setup.m 에 있다. 오프라인 쌍둥이와 **같은 변수**다.\n' ...
        'Kp_psi, Kd_psi 를 조정해 오버슈트와 정정시간을 비교할 것.\n' ...
        '먼저 W04_3_heading_offline 으로 숫자를 적어 두고 VRX 를 켠다.']), xC, 1050);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% 4단계 — 속도 + 헤딩 (inner loop)
% =====================================================================
function build_inner_loop(offline)
    %  [지령] -> [제어기 둘] -> [배분] -> [운동모델] -> [로깅·화면]
    if offline
        m = 'W04_4_inner_loop_offline'; fresh(m);
        P = w04cols('command',300, 'controller',450, 'allocation',160, ...
                    'plant',160, 'measurement',260);
    else
        m = 'W04_4_inner_loop'; fresh(m);
        P = w04cols('command',300, 'controller',450, 'allocation',160, ...
                    'plant',620, 'measurement',300);
    end
    xC = P.command(1);  xK = P.controller(1);  xA = P.allocation(1);
    xP = P.plant(1);    xM = P.measurement(1);

    %  실시간 화면 상자는 사슬 바로 아래 (build_heading 의 같은 주석 참조)
    if offline
        addMotionModel(m, xP, 220, '', true);      % true = 실시간 화면용 태그까지
        yAnim = 700;
    else
        %  twist.twist.linear.x 까지 뽑음 · 첫 메시지 전 추력 차단
        addOdomReader(m, true, true, true, [xP 600]);   % 발행단(60~385)과 넉넉히 떨어뜨린다
        yAnim = 1020;
    end

    % --- 헤딩 루프 ---
    add_block('simulink/Sources/Constant', [m '/psi_ref_deg'], ...
              'Value','psi_ref_deg', 'Position',[xC 200 xC+90 230]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad'], ...
              'Gain','pi/180', 'Position',[xC+130 200 xC+170 230]);
    addHeadingCtrl(m, xK, 185);

    % --- 속도 루프 — 헤딩 제어기 상자(185~335) 아래 한 줄 ---
    %  **서지 속도 제어도 서브시스템 하나다** (교수 지시 2026-10-02).
    %  전에는 SumU·GateE·PI_u 세 블록이 최상위에 흩어져 있어, 바로 옆의
    %  HeadingCtrl 은 상자 하나인데 속도 쪽만 속이 드러나 보였다. 두 제어기가
    %  같은 층위로 보여야 "안쪽 루프 둘" 이라는 구조가 읽힌다.
    add_block('simulink/Sources/Constant', [m '/u_ref'], ...
              'Value','1.5', 'Position',[xC 440 xC+90 470]);
    addSpeedCtrl(m, xK, 425, ~offline);

    addAllocator(m, xA, 250);
    add_line(m,'psi_ref_deg/1','deg2rad/1','autorouting','on');
    add_line(m,'deg2rad/1', 'HeadingCtrl/1','autorouting','on');
    add_line(m,'u_ref/1','SpeedCtrl/1','autorouting','on');

    %  ---- 신호마다 태그 하나 (2026-10-01 교수 지시) -----------------------
    dropTag(m, 'deg2rad', 1, 'psi_ref', 120);
    dropTag(m, 'u_ref',   1, 'u_ref',   120);

    %  되먹임 psi · r · u 는 운동모델에서 제어기로 되돌아간다 — 태그로 남긴다
    fromTo(m, 'psi', 'HeadingCtrl', 2, 110);
    fromTo(m, 'r',   'HeadingCtrl', 3, 190);
    fromTo(m, 'u',   'SpeedCtrl',   2, 110);
    if ~offline
        %  예열 게이트 — 첫 odom 전에는 오차를 0 으로 묶는다 (addSpeedCtrl 설명 참고)
        fromTo(m, 'odom_ok', 'SpeedCtrl', 3, 190);
    end
    add_line(m,'SpeedCtrl/1','Alloc/1','autorouting','on');
    add_line(m,'HeadingCtrl/1','Alloc/2','autorouting','on');

    if offline
        add_line(m,'Alloc/1','MotionModel/1','autorouting','on');
        add_line(m,'Alloc/2','MotionModel/2','autorouting','on');
        tapGotos(m, 'Alloc', {'FL','FR'}, xA+180);
        tapGotos(m, 'MotionModel', {'psi','r','u'}, xP+180);
    else
        addThrusterPublisher(m, 'left',  'L', xP+170,  90);
        addThrusterPublisher(m, 'right', 'R', xP+170, 270);
        addFirstMsgGate(m, 'Alloc/1', 'L', xP,      60);
        addFirstMsgGate(m, 'Alloc/2', 'R', xP,     240);
        %  VRX 는 게이트를 지난 값 — 배로 실제 나간 추력. 지표의 시작 시각을 여기서 읽는다
        tapGotos(m, 'GateL', {'FL'}, xP+600);
        tapGotos(m, 'GateR', {'FR'}, xP+600);
        %  psi · r · u 태그는 addOdomReader 가 이미 걸어 두었다
    end

    % 관찰용 — **Scope 하나**에 지령과 실제값을 나란히 (교수 지시 2026-10-02)
    addCompareScope(m, {'u_ref','u'; 'psi_ref','psi'; '','FL'; '','FR'}, xM+150, 60);

    %  할 일이 끝나면 스스로 멈춘다 — StopTime 은 T_run 이 뒤를 받친다.
    %  내부루프는 **두 루프가 다 자리를 잡아야** 끝난 것이다
    addAutoStop(m, xM+150, 420, true);
    fromTo(m, 'psi_ref', 'AutoStop', 1, 110);
    fromTo(m, 'psi',     'AutoStop', 2, 190);
    fromTo(m, 'u_ref',   'AutoStop', 3, 270);
    fromTo(m, 'u',       'AutoStop', 4, 350);

    %  로깅은 To Workspace **한 개**다 — out.log.psi · out.log.u · ...
    addLogFromTags(m, {'psi','u','FL','FR'}, xM, 340);

    %  ---- 실시간 화면 ----------------------------------------------------
    %  이 모델만 **지령이 둘 다 있다.** 속도 칸과 헤딩 칸에 지령선이 함께 그려지므로
    %  두 루프가 서로를 어떻게 방해하는지가 한 화면에서 보인다 (선회하면 u 가 준다).
    addW04Animate(m, xM, yAnim, true, true);

    if offline
        setSolverOffline(m);
        note(m, sprintf(['[4단계 오프라인] 속도 + 헤딩 — Gazebo 대신 운동방정식\n' ...
            'W04_4_inner_loop 과 HeadingCtrl · PI_u · Alloc 이 같은 함수로 만들어졌다.\n' ...
            'OdomSub/Sel/Quat2Yaw 와 Publish 자리에 MotionModel 하나가 있다.\n' ...
            '초기 선수각 32.7 deg (VRX 스폰), 초기 속도 0.\n' ...
            '비교: >> W04_step_compare(4)']), xC, 1050);
        save_system(m); close_system(m,0);
        fprintf('  [OK] %s\n', m);
        return
    end
    setSolver(m);
    note(m, sprintf(['[4단계] 속도 + 헤딩 (inner loop)\n' ...
        'u_ref [m/s] 와 psi_ref_deg [deg] 를 각각 바꿔 가며 응답을 본다.\n' ...
        '속도는 ground_truth_odometry 의 twist.twist.linear.x 를 그대로 쓴다.\n' ...
        '\n' ...
        '제어기는 상자 두 개다 — HeadingCtrl (요 모멘트), PI_u (전진력).\n' ...
        'HeadingCtrl 의 D 항은 요각속도 r 을 직접 되먹인다 (-Kd*r).\n' ...
        'PI_u 는 안티와인드업(clamping)이 켜져 있다.']), xC, 1050);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% 6단계 — +-180 deg 이음매. 스위치 하나로 두 번 Run 한다
%
%   170 deg 에서 -170 deg 로 가라고 시킨다. 최단 거리는 20 deg 다.
%   그런데 그냥 빼면 -170 - 170 = -340 deg 가 나온다.
%   배는 그 말을 곧이곧대로 듣고 **반대쪽으로 340 deg** 를 돈다.
%
%   시계에서 11시 -> 1시는 2시간이지 10시간이 아니다. ssa 가 그 계산이다.
%
%   계단을 **두 번** 준다 (t_wrap1 에 170, t_wrap2 에 -170).
%     첫 계단 0 -> 170 deg 는 이음매를 넘지 않아 use_ssa 와 무관하게 같다.
%     둘째 계단 170 -> -170 deg 에서만 두 경우가 갈린다 — 버그가 언제 숨고
%     언제 드러나는지를 한 화면에서 보이려고 두 계단으로 둔다.
%   계단 두 개를 더해 만든다. 둘째 Step 의 After 는 **차이**다
%   (psi_wrap2_deg - psi_wrap1_deg = -340), 그래야 합이 절대 지령이 된다.
% =====================================================================
function build_wrap()
    m = 'W04_6_wrap'; fresh(m);

    %  [계단 둘 -> 합 -> deg2rad] -> [제어기] -> [배분] -> [운동모델] -> [로깅]
    P  = w04cols('command',300, 'controller',160, 'allocation',150, ...
                 'plant',160, 'measurement',160);
    xC = P.command(1);  xK = P.controller(1);  xA = P.allocation(1);
    xP = P.plant(1);    xM = P.measurement(1);

    add_block('simulink/Sources/Step', [m '/psi_step1'], ...
              'Time','t_wrap1', 'Before','0', 'After','psi_wrap1_deg', ...
              'Position',[xC 190 xC+50 220]);
    add_block('simulink/Sources/Step', [m '/psi_step2'], ...
              'Time','t_wrap2', 'Before','0', 'After','psi_wrap2_deg - psi_wrap1_deg', ...
              'Position',[xC 280 xC+50 310]);
    add_block('simulink/Math Operations/Sum', [m '/SumRef'], ...
              'Inputs','++', 'Position',[xC+110 195 xC+140 225]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad'], ...
              'Gain','pi/180', 'Position',[xC+200 195 xC+240 225]);
    addHeadingCtrl(m, xK, 185);

    %  제자리에서 돌기만 한다 — 전진 추력 0. 도는 각도만 보면 되기 때문이다
    add_block('simulink/Sources/Constant', [m '/X_const'], ...
              'Value','0', 'Position',[xC 380 xC+80 410]);

    addAllocator(m, xA, 200);
    addMotionModel(m, xP, 190, 'psi0_deg*pi/180');

    %  선에 이름을 준다. 배치 도구가 태그로 바꾸더라도 태그 이름이 **신호 이름**이
    %  되게 하려는 것이다 — 이름을 안 주면 블록 이름에서 딴 psi_step1_1 이 된다
    h1 = add_line(m,'psi_step1/1','SumRef/1','autorouting','on');
    h2 = add_line(m,'psi_step2/1','SumRef/2','autorouting','on');
    set_param(h1, 'Name', 'step1_deg');
    set_param(h2, 'Name', 'step2_deg');
    add_line(m,'SumRef/1','deg2rad/1','autorouting','on');
    add_line(m,'deg2rad/1','HeadingCtrl/1','autorouting','on');
    add_line(m,'X_const/1','Alloc/1','autorouting','on');
    add_line(m,'HeadingCtrl/1','Alloc/2','autorouting','on');
    add_line(m,'Alloc/1','MotionModel/1','autorouting','on');
    add_line(m,'Alloc/2','MotionModel/2','autorouting','on');

    %  ---- 신호마다 태그 하나 (2026-10-01 교수 지시) -----------------------
    dropTag(m, 'deg2rad', 1, 'psi_ref', 120);
    tapGotos(m, 'HeadingCtrl', {'N'},         xK+190);
    tapGotos(m, 'MotionModel', {'psi','r'},   xP+180);
    %  되먹임 — 운동모델에서 제어기로 되돌아간다
    fromTo(m, 'psi', 'HeadingCtrl', 2, 110);
    fromTo(m, 'r',   'HeadingCtrl', 3, 190);

    add_block('simulink/Sinks/Scope', [m '/Scope_psi'], 'Position',[xM 60 xM+50 110]);
    set_param([m '/Scope_psi'],'NumInputPorts','2');
    fromTo(m, 'psi',     'Scope_psi', 1, 110);
    fromTo(m, 'psi_ref', 'Scope_psi', 2, 190);

    %  로깅은 To Workspace **한 개** — out.log.psi · out.log.r · out.log.N
    addLogFromTags(m, {'psi','r','N'}, xM, 220);

    setSolverOffline(m);
    set_param(m, 'StopTime','60');
    note(m, sprintf(['[6단계] +-180 deg 이음매 — 스위치 하나로 두 번 Run\n' ...
        '\n' ...
        '  초기 선수각 psi0_deg      = 0 deg\n' ...
        '  1차 지령    psi_wrap1_deg = 170 deg   (t_wrap1 = 5 s)\n' ...
        '  2차 지령    psi_wrap2_deg = -170 deg  (t_wrap2 = 20 s)\n' ...
        '  둘째 계단의 최단 거리는 20 deg 다.\n' ...
        '\n' ...
        '  >> use_ssa = 1;  sim(''W04_6_wrap'')    20 deg 만 돈다\n' ...
        '  >> use_ssa = 0;  sim(''W04_6_wrap'')    반대쪽으로 340 deg 를 돈다\n' ...
        '  >> W04_setup                          기본값(1)으로 되돌리기\n' ...
        '\n' ...
        '스위치는 HeadingCtrl 안의 HeadingErr 한 줄이다. 더블클릭해 볼 것.\n' ...
        '  use_ssa = 1  e = atan2(sin(d), cos(d))   d 를 (-180, 180] 로 접는다\n' ...
        '  use_ssa = 0  e = d = psi_ref - psi       -340 deg 가 그대로 들어간다\n' ...
        '\n' ...
        '첫 계단(0 -> 170 deg)은 이음매를 넘지 않아 두 경우가 똑같다.\n' ...
        '20 s 의 둘째 계단에서만 갈린다 — 버그는 이음매를 넘을 때만 드러난다.\n' ...
        '\n' ...
        '전진 추력은 0 이다. 제자리에서 도는 각도만 본다.\n' ...
        '  >> W04_wrap_run                   두 실행을 한 번에 — 돈 각을 표로\n' ...
        '  >> W04_heading_compare(''wrap'')   같은 두 실행의 자세한 지표']), xC, 700);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% 7단계 — `ssa` 함수 하나만 시험한다 (배도 제어기도 없다)
%
%   W04_6_wrap 은 **배가 도는 것**을 본다. 그 전에 이 모델로 **함수가 무엇을
%   하는지**를 먼저 본다. 루프가 없으므로 게인도 관성도 끼어들지 않는다 —
%   각도를 넣으면 오차가 나오고, 그것이 전부다.
%
%   보는 것 두 가지
%     ① 쓸어보기  d 를 -540 deg 에서 +540 deg 까지 훑는다.
%                 ssa 를 거친 값은 **톱니**(+-180 deg 마다 접힘),
%                 그대로 뺀 값은 **직선**. 이 한 장이 ssa 의 전부다.
%     ② 한 점     psi = 170 deg, psi_ref = -170 deg 에서
%                 ssa 켜면 +20 deg, 끄면 -340 deg. Display 두 개에 숫자로 뜬다
%
%   d 를 시간으로 훑는다 — Ramp 기울기 1 deg/s, 시작 -540 deg.
%   그래서 **t [s] 와 d [deg] 가 540 만큼 어긋난 같은 수**다 (d = t - 540).
%   고정 스텝 0.05 s 는 다른 모델과 같으므로 d 의 해상도는 0.05 deg 다.
% =====================================================================
function build_ssa_test()
    m = 'W04_7_ssa_test'; fresh(m);

    %  [각도 지령] -> [오차 함수 두 벌] -> [로깅·표시]
    P  = w04cols('command',300, 'controller',320, 'measurement',300);
    xC = P.command(1);  xK = P.controller(1);  xM = P.measurement(1);

    % ---- ① 쓸어보기 지령 — psi 는 0 에 두고 psi_ref 만 훑는다 -----------
    %    d = psi_ref - psi 이므로 psi = 0 이면 psi_ref 가 곧 d 다
    %    Ramp 대신 Digital Clock + Bias 로 적는다. Ramp 는 마스크 서브시스템이라
    %    색 검사가 "단계를 나르는 상자" 로 잡는데, 이것은 상자가 아니라 눈금이다.
    %    덧붙여 d = t - 540 이라는 관계가 도면에 그대로 보인다 (2026-10-01)
    add_block('simulink/Sources/Digital Clock', [m '/Clock'], ...
              'SampleTime','0.05', 'Position',[xC 110 xC+60 140]);
    add_block('simulink/Math Operations/Bias', [m '/d_deg'], ...
              'Bias','-540', 'Position',[xC+110 110 xC+170 140]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad_sweep'], ...
              'Gain','pi/180', 'Position',[xC+220 110 xC+280 140]);
    add_block('simulink/Sources/Constant', [m '/psi_zero'], ...
              'Value','0', 'Position',[xC+220 200 xC+280 230]);

    % ---- ② 한 점 확인 — 170 deg 에 있는 배에 -170 deg 를 시킨다 ---------
    add_block('simulink/Sources/Constant', [m '/psi_ref_pt'], ...
              'Value','-170', 'Position',[xC 320 xC+90 350]);
    add_block('simulink/Sources/Constant', [m '/psi_pt'], ...
              'Value','170', 'Position',[xC 410 xC+90 440]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad_ref'], ...
              'Gain','pi/180', 'Position',[xC+140 320 xC+200 350]);
    add_block('simulink/Math Operations/Gain', [m '/deg2rad_psi'], ...
              'Gain','pi/180', 'Position',[xC+140 410 xC+200 440]);

    % ---- 시험 대상 — 같은 상자 두 벌. 안에서 use_ssa 만 1 과 0 이다 ------
    addSsaBox(m, 'Sweep', xK,  90);
    addSsaBox(m, 'Point',  xK, 320);

    add_line(m,'Clock/1','d_deg/1','autorouting','on');
    add_line(m,'d_deg/1','deg2rad_sweep/1','autorouting','on');
    add_line(m,'deg2rad_sweep/1','Sweep/1','autorouting','on');
    add_line(m,'psi_zero/1',     'Sweep/2','autorouting','on');
    add_line(m,'psi_ref_pt/1','deg2rad_ref/1','autorouting','on');
    add_line(m,'psi_pt/1',    'deg2rad_psi/1','autorouting','on');
    add_line(m,'deg2rad_ref/1','Point/1','autorouting','on');
    add_line(m,'deg2rad_psi/1','Point/2','autorouting','on');

    % ---- 보기 -----------------------------------------------------------
    add_block('simulink/Sinks/Scope', [m '/Scope_e'], 'Position',[xM 90 xM+50 140]);
    set_param([m '/Scope_e'],'NumInputPorts','2');
    add_line(m,'Sweep/1','Scope_e/1','autorouting','on');
    add_line(m,'Sweep/2','Scope_e/2','autorouting','on');

    add_block('simulink/Sinks/Display', [m '/e_ssa_deg'], ...
              'Position',[xM 320 xM+90 350]);
    add_block('simulink/Sinks/Display', [m '/e_raw_deg'], ...
              'Position',[xM 410 xM+90 440]);
    add_line(m,'Point/1','e_ssa_deg/1','autorouting','on');
    add_line(m,'Point/2','e_raw_deg/1','autorouting','on');

    %  로깅 — 로그 변수 이름은 **신호 이름 그대로**다 (out.d · out.e_ssa · out.e_raw).
    %  e_ssa · e_raw 는 바로 왼쪽 Sweep 에서 오므로 **선으로** 잇는다.
    %  d 만 태그다 — 맨 왼쪽 command 열에서 오는 신호라 선으로 이으면 Sweep 상자를
    %  가로질러 관통한다 (2026-10-01). 태그 이름은 접미사 없이 신호 이름 'd' 하나다
    tapGotos(m, 'd_deg', {'d'}, xC+350);
    add_block('simulink/Signal Routing/From', [m '/Fr_d'], ...
              'GotoTag','d', 'Position',[xM-160 500 xM-90 522]);
    addLogBus(m, {'Fr_d/1','d'; 'Sweep/1','e_ssa'; 'Sweep/2','e_raw'}, xM, 500);

    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','0.05', 'StopTime','1080', 'SimulationMode','normal');
    note(m, sprintf(['[7단계] ssa 함수만 시험한다 — 배도 제어기도 없다\n' ...
        '\n' ...
        '위 줄 (쓸어보기)  psi = 0 에 두고 psi_ref 를 -540 -> +540 deg 로 훑는다.\n' ...
        '  d_deg = Clock - 540 이다. t [s] 와 d [deg] 는 540 만큼 어긋난 같은 수다.\n' ...
        '  Scope_e 위 곡선(ssa)  +-180 deg 마다 접히는 **톱니**\n' ...
        '  Scope_e 아래 곡선(그대로) 접히지 않는 **직선**\n' ...
        '\n' ...
        '아래 줄 (한 점)  psi = 170 deg 인 배에 psi_ref = -170 deg 를 시킨다.\n' ...
        '  e_ssa_deg 에 **+20**,  e_raw_deg 에 **-340** 이 뜬다.\n' ...
        '  20 deg 를 오른쪽으로 돌면 될 일을 340 deg 왼쪽으로 돌게 만드는 수다.\n' ...
        '\n' ...
        'Sweep 과 Point 는 **같은 상자**다 (use_ssa 를 1 과 0 으로 고정한 HeadingErr 두 벌).\n' ...
        '그 HeadingErr 은 W04_3_heading_offline 의 HeadingCtrl 이 쓰는 것과 **같은 코드**다\n' ...
        '(빌더의 headingErrCode 한 곳에서 나온다).\n' ...
        '\n' ...
        '로깅은 To Workspace **한 개**다. Bus Creator 가 세 신호를 묶어 보내고,\n' ...
        '꺼낼 때는 이름이 그대로 살아 있다.\n' ...
        '  >> out = sim(''W04_7_ssa_test'');  out.log.d  out.log.e_ssa  out.log.e_raw\n' ...
        '\n' ...
        '  >> W04_ssa_test                  그림과 표를 한 번에\n' ...
        '배가 실제로 도는 것은 >> W04_wrap_run  (W04_6_wrap)']), xC, 760);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end

% ---- 오차 함수 두 벌을 담은 상자 (ssa 켬 / 끔) ------------------------
%   입력  psi_ref [rad], psi [rad]
%   출력  e_ssa [deg], e_raw [deg]   — 학생이 읽는 단위는 도(deg)다
function addSsaBox(m, name, x, y)
    s = add_subsys(m, name, [x y x+160 y+120], ...
                   {'psi_ref','psi'}, {'e_ssa','e_raw'}, gnc_colour('control'));

    add_block('simulink/Sources/Constant', [s '/ssa_on'], ...
              'Value','1', 'Position',[60 210 140 240]);
    add_block('simulink/Sources/Constant', [s '/ssa_off'], ...
              'Value','0', 'Position',[60 470 140 500]);

    for k = {'On','Off'}
        b = ['HeadingErr' k{1}];
        add_block('simulink/User-Defined Functions/MATLAB Function', [s '/' b], ...
                  'Position',[260 60 410 170]);
        setFcn(s, b, headingErrCode());     % 제어기와 **같은 코드**다
    end
    set_param([s '/HeadingErrOn'],  'Position',[260  60 410 170]);
    set_param([s '/HeadingErrOff'], 'Position',[260 320 410 430]);

    add_block('simulink/Math Operations/Gain', [s '/rad2deg_ssa'], ...
              'Gain','180/pi', 'Position',[500 100 570 130]);
    add_block('simulink/Math Operations/Gain', [s '/rad2deg_raw'], ...
              'Gain','180/pi', 'Position',[500 360 570 390]);

    add_line(s,'psi_ref/1','HeadingErrOn/1', 'autorouting','on');
    add_line(s,'psi/1',    'HeadingErrOn/2', 'autorouting','on');
    add_line(s,'ssa_on/1', 'HeadingErrOn/3', 'autorouting','on');
    add_line(s,'psi_ref/1','HeadingErrOff/1','autorouting','on');
    add_line(s,'psi/1',    'HeadingErrOff/2','autorouting','on');
    add_line(s,'ssa_off/1','HeadingErrOff/3','autorouting','on');
    add_line(s,'HeadingErrOn/1', 'rad2deg_ssa/1','autorouting','on');
    add_line(s,'HeadingErrOff/1','rad2deg_raw/1','autorouting','on');
    add_line(s,'rad2deg_ssa/1','e_ssa/1','autorouting','on');
    add_line(s,'rad2deg_raw/1','e_raw/1','autorouting','on');

    note(s, sprintf(['같은 함수를 두 벌 놓고 use_ssa 만 1 과 0 으로 고정했다.\n' ...
        '한 번 실행으로 두 곡선이 같이 나온다 — 따로 두 번 돌릴 일이 없다.\n' ...
        '\n' ...
        '  위  use_ssa = 1   e = atan2(sin(d), cos(d))   (-180, 180] 로 접는다\n' ...
        '  아래 use_ssa = 0   e = d = psi_ref - psi       접지 않는다\n' ...
        '\n' ...
        '나가는 값의 단위는 **도(deg)** 다. 안쪽 계산은 라디안이고,\n' ...
        '경계인 rad2deg 게인에서 도로 바꾼다.\n' ...
        '\n' ...
        'HeadingErr 코드는 W04_3_heading_offline 의 HeadingCtrl 과 같다.\n' ...
        '빌더의 headingErrCode 한 곳에서 두 모델로 나간다.']), 60, 560);
end

% =====================================================================
% 5단계 · 오프라인 WAM-V — Gazebo 없이 같은 실험을 한다
%
%   앞의 네 모델은 추력을 ROS 2 토픽으로 내보내고 Gazebo 가 배를 움직였다.
%   이 모델은 그 자리에 WAM-V 운동방정식을 직접 넣는다.
%   시나리오 블록은 2단계(W04_2_turn)와 글자 하나까지 같다.
%   바뀌는 것은 뒷단뿐이다.
%
%     W04_2_turn    : Scenario -> Blank/Assign/Publish -> Gazebo
%     W04_5_offline : Scenario -> MotorLag -> MotionModel -> Scope
% =====================================================================
function build_offline()
    m = 'W04_5_offline'; fresh(m);

    %  [시각] -> [시나리오] -> [추진기 지연] -> [운동모델] -> [로깅·화면]
    P  = w04cols('command',100, 'reference',140, 'allocation',200, ...
                 'plant',520, 'measurement',330);
    xC = P.command(1);  xR = P.reference(1);  xT = P.allocation(1);
    xP = P.plant(1);    xM = P.measurement(1);

    % --- 1단 · 시나리오 (2단계와 같은 코드) ---------------------------
    add_block('simulink/Sources/Digital Clock', [m '/Clock'], ...
              'SampleTime','0.05', 'Position',[xC 185 xC+60 215]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Scenario'], ...
              'Position',[xR 165 xR+130 235]);
    setFcn(m, 'Scenario', [ ...
        'function [FL, FR] = Scenario(t)' newline ...
        '%#codegen' newline ...
        '% Time-based thrust scenario [N] - identical to W04_2_turn' newline ...
        'if t < 20' newline ...
        '    FL = 200;  FR = 200;   % go straight' newline ...
        'elseif t < 40' newline ...
        '    FL = 300;  FR =  50;   % turn starboard (right)' newline ...
        'elseif t < 60' newline ...
        '    FL =  50;  FR = 300;   % turn port (left)' newline ...
        'else' newline ...
        '    FL = 0;    FR = 0;     % stop' newline ...
        'end' newline]);

    % --- 2단 · 추진기 (모터 1차 지연) ---------------------------------
    add_block('simulink/Signal Routing/Mux', [m '/MuxF'], ...
              'Inputs','2', 'Position',[xT 175 xT+5 225]);

    %  모터 1차 지연 1/(T_m s + 1) 을 **연속 시간**으로 적는다 (교수 지시 2026-10-01
    %  — "이산 제어기든 전달함수든 전부 연속으로"). 전에는 전진 오일러로 이산화한
    %  Discrete Transfer Fcn (분자 Ts/T_m, 분모 [1, Ts/T_m - 1], Ts = 0.05) 이었다.
    %
    %  연속 Transfer Fcn 은 **벡터 입력을 받지 못한다.** 여기 들어오는 것은 MuxF 가
    %  묶은 (FL, FR) 두 원소다. 그래서 같은 법칙을 State-Space 한 블록으로 적는다 —
    %  5~8주차의 MotorLag 과 같은 꼴이다.
    %
    %      xdot = -x/T_m + u/T_m ,  y = x      <=>   y/u = 1/(T_m s + 1)
    %
    %  시상수는 그대로 T_m = tau_m = 0.30 s 다 (W04_setup.m). 바꾼 것은 적는 방식뿐이다.
    add_block('simulink/Continuous/State-Space', [m '/MotorLag'], ...
              'Position',[xT+70 175 xT+190 225]);
    set_param([m '/MotorLag'], 'A','-eye(2)/tau_m', 'B','eye(2)/tau_m', ...
              'C','eye(2)', 'D','zeros(2)', 'X0','zeros(2,1)');

    % --- 3단 · WAM-V 운동모델 -----------------------------------------
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/EOM'], ...
              'Position',[xP 140 xP+180 260]);
    setFcn(m, 'EOM', [ ...
'function xdot = EOM(s, F)'                                           newline ...
'%#codegen'                                                              newline ...
'% 3-DOF WAM-V equations of motion in NED.'                              newline ...
'% Every coefficient below is taken from the Gazebo VRX plugins, so'     newline ...
'% this model and the simulator answer the same question the same way.'  newline ...
'%   drag : wamv_gazebo_dynamics_plugin.xacro (SimpleHydrodynamics)'     newline ...
'%   mass : 211 kg = 180 hull + 2x15 engines + 2x0.5 propellers'         newline ...
'%   added mass is zero in VRX (xDotU = yDotV = nDotR = 0)'              newline ...
'%   s = [u v r x_n y_n psi]    F = [FL; FR]'                                newline ...
''                                                                       newline ...
'mm  = 211;    Izz = 653;'                                               newline ...
'Xu  = 100;    Xuu = 150;'                                               newline ...
'Yv  = 100;    Yvv = 100;'                                               newline ...
'Nr  = 800;    Nrr = 800;'                                               newline ...
'b   = 1.027135;          % half beam of the aft thrusters [m]'          newline ...
''                                                                       newline ...
'u = s(1); v = s(2); r = s(3); psi = s(6);'                              newline ...
''                                                                       newline ...
'% differential thrust -> surge force and yaw moment'                    newline ...
'X = F(1) + F(2);'                                                       newline ...
'N = (F(1) - F(2))*b;'                                                   newline ...
''                                                                       newline ...
'Dx = (Xu + Xuu*abs(u))*u;'                                              newline ...
'Dy = (Yv + Yvv*abs(v))*v;'                                              newline ...
'Dn = (Nr + Nrr*abs(r))*r;'                                              newline ...
''                                                                       newline ...
'du = (X - Dx)/mm + v*r;     % rigid-body Coriolis'                      newline ...
'dv = (  - Dy)/mm - u*r;'                                                newline ...
'dr = (N - Dn)/Izz;'                                                     newline ...
''                                                                       newline ...
'xdot = [du; dv; dr;'                                                    newline ...
'        u*cos(psi) - v*sin(psi);'                                       newline ...
'        u*sin(psi) + v*cos(psi);'                                       newline ...
'        r];']);

    add_block('simulink/Continuous/Integrator', [m '/Integ'], ...
              'Position',[xP+240 175 xP+290 225], 'InitialCondition','[0;0;0;0;0;0]');

    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/States'], ...
              'Position',[xP+370 130 xP+520 270]);
    setFcn(m, 'States', [ ...
'function [x_n, y_n, psi_deg, u, r_deg] = States(s)'          newline ...
'%#codegen'                                                 newline ...
'% Pull the numbers we want to look at out of the state.'   newline ...
'x_n = s(4);'                                                newline ...
'y_n = s(5);'                                                newline ...
'psi_deg = s(6)*180/pi;'                                    newline ...
'u  = s(1);'                                                newline ...
'r_deg = s(3)*180/pi;']);

    % --- 4단 · 관찰 -----------------------------------------------------
    add_block('simulink/Sinks/Scope', [m '/Scope_u'],   'Position',[xM 100 xM+40 140]);
    add_block('simulink/Sinks/Scope', [m '/Scope_psi'], 'Position',[xM 180 xM+40 220]);
    add_block('simulink/Sinks/XY Graph', [m '/Track'],  'Position',[xM 270 xM+60 330]);
    set_param([m '/Track'],'xmin','-20','xmax','120','ymin','-40','ymax','60');

    % --- 배선 -----------------------------------------------------------
    add_line(m, 'Clock/1', 'Scenario/1', 'autorouting','on');
    add_line(m, 'Scenario/1', 'MuxF/1', 'autorouting','on');
    add_line(m, 'Scenario/2', 'MuxF/2', 'autorouting','on');
    add_line(m, 'MuxF/1', 'MotorLag/1', 'autorouting','on');
    add_line(m, 'MotorLag/1', 'EOM/2', 'autorouting','on');
    hDot = add_line(m, 'EOM/1', 'Integ/1', 'autorouting','on');
    set_param(hDot, 'Name', 'xdot');
    %  상태벡터가 EOM 으로 되돌아가는 선 — 이름을 주어 태그 이름이 state 가 되게
    hState = add_line(m, 'Integ/1', 'EOM/1', 'autorouting','on');
    set_param(hState, 'Name', 'state');
    add_line(m, 'Integ/1', 'States/1', 'autorouting','on');
    add_line(m, 'States/4', 'Scope_u/1', 'autorouting','on');
    add_line(m, 'States/3', 'Scope_psi/1', 'autorouting','on');
    add_line(m, 'States/2', 'Track/1', 'autorouting','on');     % y (동쪽) 를 가로축으로
    add_line(m, 'States/1', 'Track/2', 'autorouting','on');     % x (북쪽) 를 세로축으로

    %  로깅은 To Workspace **한 개**다 — out.log.x_n · out.log.y_n · out.log.psi ·
    %  out.log.u · out.log.r. psi 와 r 은 States 가 Scope 용으로 내는 **deg** 값이다.
    %
    %  이 모델만 로깅을 **태그로** 받는다. 측정 열에 이미 Scope 둘 · XY Graph ·
    %  화면용 AnimTap(여덟 출력)이 서 있어서, States 에서 다섯 줄을 더 끌면 그
    %  상자들을 가로지른다 (2026-10-01 실측: 블록관통 2 · 겹침 1). 다른 모델처럼
    %  옆 단계가 아니라 **꽉 찬 열을 건너가는** 신호라 태그가 맞다
    tapGotos(m, 'States', {'x_n','y_n','psi','u','r'}, xP+540);
    addLogFromTags(m, {'x_n','y_n','psi','u','r'}, xM+450, 100);

    % --- 5단 · 실시간 화면 ----------------------------------------------
    %  States 는 Scope 가 쓰기 좋은 단위(deg)로 낸다. 화면 함수는 rad 를 받고
    %  스웨이 v 와 추력 둘을 더 쓰므로, 상태벡터와 추력을 한 번 더 들여다본다.
    %  이 모델은 추력을 직접 주는 개루프라 지령 칸 둘은 "지령 없음" 이 된다.
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/AnimTap'], ...
              'Position',[xM 420 xM+150 880]);
    setFcn(m, 'AnimTap', [ ...
'function [x_n, y_n, psi, u, v, r, fl, fr] = AnimTap(s, F)'             newline ...
'%#codegen'                                                             newline ...
'% Display-only tap. s = [u v r x_n y_n psi]'', F = [FL; FR] after the' newline ...
'% motor lag, i.e. the thrust the hull actually feels.'                 newline ...
'x_n = s(4);'                                                           newline ...
'y_n = s(5);'                                                           newline ...
'psi = atan2(sin(s(6)), cos(s(6)));   % wrap to [-pi, pi]'              newline ...
'u   = s(1);'                                                           newline ...
'v   = s(2);'                                                           newline ...
'r   = s(3);'                                                           newline ...
'fl  = F(1);'                                                           newline ...
'fr  = F(2);']);
    set_param([m '/AnimTap'], 'Position',[xM 420 xM+150 880]);
    add_line(m, 'Integ/1',    'AnimTap/1', 'autorouting','on');
    add_line(m, 'MotorLag/1', 'AnimTap/2', 'autorouting','on');
    %  여덟 신호를 Mux 하나로 묶어 태그 `anim` 하나로 보낸다 (2026-10-01)
    animBundle(m, {'AnimTap/1','AnimTap/2','AnimTap/3','AnimTap/4', ...
                   'AnimTap/5','AnimTap/6','AnimTap/7','AnimTap/8'}, xM+200, 420, 460);
    addW04Animate(m, xM, 960, false, false);

    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','0.05', 'StopTime','80', 'SimulationMode','normal');
    note(m, sprintf(['[5단계] 오프라인 WAM-V — Gazebo 없이 같은 실험\n' ...
        '시나리오 블록은 2단계(W04_2_turn)와 완전히 같다.\n' ...
        '뒤에 Publish 대신 WAM-V 운동방정식이 붙어 있다.\n' ...
        '0~20s 직진 / 20~40s 우선회 / 40~60s 좌선회 / 60s~ 정지\n' ...
        '계수는 전부 Gazebo VRX 플러그인에서 가져온 값이다.\n' ...
        '실행 뒤 >> W04_offline_plot 으로 그림을 본다.\n' ...
        '\n' ...
        '도는 동안에는 Animate 상자가 항적과 상태를 실시간으로 그린다.\n' ...
        '끄려면 W04_setup.m 의 animate = 0 (끄면 훨씬 빨리 끝난다).']), xC, 1050);
    save_system(m); close_system(m,0);
    fprintf('  [OK] %s\n', m);
end
