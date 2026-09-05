function build_w06_0_models()
% BUILD_W06_0_MODELS  Simulink 속성 입문 실습 모델 12개를 생성한다.
%
%   실습마다 두 개씩 만들어진다.
%     *_todo.slx   빈칸본 — 학생이 채운다
%     *_done.slx   완성본 — 정답 대조용
%
%     SB1_first     첫 모델과 솔버
%     SB2_mfcn      MATLAB Function 블록
%     SB3_subsys    Subsystem 과 Goto/From
%     SB4_bus       버스 (Bus Creator / Selector / Assignment)
%     SB5_pid       이산 PID · 포화 · 안티와인드업
%     SB6_param     파라미터 · 신호 로깅 · Data Inspector
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 원래대로 복구된다.
%
%   전제: MATLAB R2024b + Simulink  (ROS Toolbox 불필요, VRX 불필요)

    here = fileparts(mfilename('fullpath'));
    cd(here);

    build_SB1_done();  build_SB1_todo();
    build_SB2_done();  build_SB2_todo();
    build_SB3_done();  build_SB3_todo();
    build_SB4_done();  build_SB4_todo();
    build_SB5_done();  build_SB5_todo();
    build_SB6_done();  build_SB6_todo();


    % 배치와 색을 정리한다. 선은 직선 또는 직각으로만 다시 그린다.
    slxList = dir('*.slx');
    for k = 1:numel(slxList)
        [~, mName] = fileparts(slxList(k).name);
        try, tidy_layout(mName); tidy_layout(mName); catch, end
    end
    fprintf('\n완료. 생성된 모델:\n');
    d = dir('SB*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
end

% =====================================================================
% 공통 헬퍼  (W06_simulink/build_w06_models.m 의 관용구를 그대로 따른다)
% =====================================================================
function fresh(m)
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end

function setSolver(m, stopTime)
    set_param(m, 'SolverType','Fixed-step', 'SolverName','FixedStepDiscrete', ...
                 'FixedStep','0.05', 'StopTime',stopTime, 'SimulationMode','normal');
end

function setFcn(m, name, code)
    S  = sfroot;
    ch = S.find('-isa','Stateflow.EMChart','Path',[m '/' name]);
    ch.Script = code;
end

function note(m, txt, x, y)
    add_block('built-in/Note', [m '/note'], 'Position',[x y x y], 'Text', txt);
end

function wire(m, src, dst)
    add_line(m, src, dst, 'autorouting','on');
end

function nwire(m, src, dst, nm)
% 신호선을 잇고 이름을 붙인다. 버스 원소 이름은 이 이름을 따라간다.
    h = add_line(m, src, dst, 'autorouting','on');
    set_param(h, 'Name', nm);
end

function finish(m)
    save_system(m); close_system(m, 0);
    fprintf('  [OK] %s\n', m);
end

% =====================================================================
% SB1 — 첫 모델과 솔버
% =====================================================================
function build_SB1_done()
    m = 'SB1_first_done'; fresh(m);

    add_block('simulink/Sources/Sine Wave', [m '/Sine'], ...
              'Amplitude','1', 'Frequency','1', 'SampleTime','0.05', ...
              'Position',[40 100 100 160]);
    add_block('simulink/Math Operations/Gain', [m '/Gain2'], ...
              'Gain','2', 'Position',[170 115 210 145]);
    add_block('simulink/Sinks/Scope', [m '/Scope'], ...
              'Position',[290 105 340 155]);
    set_param([m '/Scope'],'NumInputPorts','2');

    add_block('simulink/Sources/Digital Clock', [m '/Clock'], ...
              'SampleTime','0.05', 'Position',[40 240 100 280]);
    add_block('simulink/Sinks/Display', [m '/Display'], ...
              'Position',[170 245 240 275]);

    wire(m,'Sine/1','Gain2/1');
    wire(m,'Gain2/1','Scope/1');
    wire(m,'Sine/1','Scope/2');
    wire(m,'Clock/1','Display/1');

    setSolver(m,'20');
    note(m, sprintf(['[A] 첫 모델\n' ...
        'Sine -> Gain(2) -> Scope. 원래 신호도 Scope 2번 포트로 함께 넣었다.\n' ...
        'Digital Clock 은 지금 시각을 내보낸다. Display 로 확인.\n' ...
        '솔버: 고정 스텝 / 이산 / 0.05 s, 정지 시간 20 s.']), 40, 360);
    finish(m);
end

function build_SB1_todo()
    m = 'SB1_first_todo'; fresh(m);

    add_block('simulink/Sources/Sine Wave', [m '/Sine'], ...
              'Amplitude','1', 'Frequency','1', 'SampleTime','0.05', ...
              'Position',[40 100 100 160]);
    add_block('simulink/Sources/Digital Clock', [m '/Clock'], ...
              'SampleTime','0.05', 'Position',[40 240 100 280]);

    % 솔버를 일부러 기본값(가변 스텝)으로 둔다 — 학생이 고쳐야 한다
    set_param(m, 'SolverType','Variable-step', 'StopTime','10');

    note(m, sprintf(['[A] 할 일\n' ...
        '1. Gain 블록을 놓고 값을 2 로. Sine -> Gain -> Scope 로 잇는다\n' ...
        '2. Scope 의 입력 포트를 2개로 늘리고 Sine 을 2번 포트에도 잇는다\n' ...
        '3. Display 를 놓고 Clock 을 잇는다\n' ...
        '4. Ctrl+E -> Solver 를 고정 스텝 / 이산 / 0.05 로, 정지 시간 20 으로\n' ...
        '   (지금은 가변 스텝이다. 이것부터 고칠 것)']), 40, 360);
    finish(m);
end

% =====================================================================
% SB2 — MATLAB Function 블록
% =====================================================================
function build_SB2_done()
    m = 'SB2_mfcn_done'; fresh(m);

    % --- (1) 입력 2개 · 출력 1개 ---
    add_block('simulink/Sources/Constant', [m '/a1'], 'Value','3', 'Position',[40 40 90 70]);
    add_block('simulink/Sources/Constant', [m '/b1'], 'Value','4', 'Position',[40 90 90 120]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Scale'], ...
              'Position',[160 40 280 120]);
    setFcn(m, 'Scale', [ ...
        'function y = Scale(a, b)' newline ...
        '%#codegen' newline ...
        '% 입력이 2개, 출력이 1개. 포트는 이 첫 줄을 그대로 따라간다.' newline ...
        'y = a * b;' newline]);
    add_block('simulink/Sinks/Display', [m '/d_y'], 'Position',[340 65 410 95]);
    wire(m,'a1/1','Scale/1'); wire(m,'b1/1','Scale/2'); wire(m,'Scale/1','d_y/1');

    % --- (2) 출력 2개 ---
    add_block('simulink/Sources/Constant', [m '/a2'], 'Value','10', 'Position',[40 190 90 220]);
    add_block('simulink/Sources/Constant', [m '/b2'], 'Value','4',  'Position',[40 240 90 270]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/SumDiff'], ...
              'Position',[160 190 280 270]);
    setFcn(m, 'SumDiff', [ ...
        'function [s, d] = SumDiff(a, b)' newline ...
        '%#codegen' newline ...
        '% 출력을 대괄호로 여러 개 적으면 출력 포트도 그만큼 생긴다.' newline ...
        's = a + b;' newline ...
        'd = a - b;' newline]);
    add_block('simulink/Sinks/Display', [m '/d_s'], 'Position',[340 190 410 220]);
    add_block('simulink/Sinks/Display', [m '/d_d'], 'Position',[340 240 410 270]);
    wire(m,'a2/1','SumDiff/1'); wire(m,'b2/1','SumDiff/2');
    wire(m,'SumDiff/1','d_s/1'); wire(m,'SumDiff/2','d_d/1');

    % --- (3) 각도 wrap ---
    add_block('simulink/Sources/Constant', [m '/ang_a'], ...
              'Value','179*pi/180', 'Position',[40 350 130 380]);
    add_block('simulink/Sources/Constant', [m '/ang_b'], ...
              'Value','-179*pi/180', 'Position',[40 400 130 430]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/WrapPi'], ...
              'Position',[190 350 310 430]);
    setFcn(m, 'WrapPi', [ ...
        'function e = WrapPi(a, b)' newline ...
        '%#codegen' newline ...
        '% 두 각도의 차이를 -pi ~ +pi 로 접어서 돌려준다.' newline ...
        '% 그냥 빼기만 하면 179도와 -179도의 차이가 358도로 나온다.' newline ...
        'd = a - b;' newline ...
        'e = atan2(sin(d), cos(d));' newline]);
    add_block('simulink/Math Operations/Gain', [m '/rad2deg'], ...
              'Gain','180/pi', 'Position',[370 375 420 405]);
    add_block('simulink/Sinks/Display', [m '/d_wrap'], 'Position',[470 375 540 405]);
    wire(m,'ang_a/1','WrapPi/1'); wire(m,'ang_b/1','WrapPi/2');
    wire(m,'WrapPi/1','rad2deg/1'); wire(m,'rad2deg/1','d_wrap/1');

    setSolver(m,'1');
    note(m, sprintf(['[B] MATLAB Function\n' ...
        '함수의 첫 줄을 고치면 블록의 포트가 저절로 바뀐다. 이것만 기억하면 된다.\n' ...
        'WrapPi 의 Display 에 -2 가 떠야 정답이다.\n' ...
        '358 도가 아니라 -2 도다. 반대쪽으로 2도만 돌면 된다는 뜻이다.']), 40, 500);
    finish(m);
end

function build_SB2_todo()
    m = 'SB2_mfcn_todo'; fresh(m);

    add_block('simulink/Sources/Constant', [m '/a1'], 'Value','3', 'Position',[40 40 90 70]);
    add_block('simulink/Sources/Constant', [m '/b1'], 'Value','4', 'Position',[40 90 90 120]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/Scale'], ...
              'Position',[160 40 280 120]);
    setFcn(m, 'Scale', [ ...
        'function y = Scale(a)' newline ...
        '%#codegen' newline ...
        '% 할 일: 첫 줄을  function y = Scale(a, b)  로 고치면' newline ...
        '%        입력 포트가 2개로 늘어난다. 그 뒤 y = a * b; 로 바꿀 것.' newline ...
        'y = a;' newline]);
    add_block('simulink/Sinks/Display', [m '/d_y'], 'Position',[340 65 410 95]);
    wire(m,'a1/1','Scale/1'); wire(m,'Scale/1','d_y/1');

    add_block('simulink/Sources/Constant', [m '/a2'], 'Value','10', 'Position',[40 190 90 220]);
    add_block('simulink/Sources/Constant', [m '/b2'], 'Value','4',  'Position',[40 240 90 270]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/SumDiff'], ...
              'Position',[160 190 280 270]);
    setFcn(m, 'SumDiff', [ ...
        'function s = SumDiff(a)' newline ...
        '%#codegen' newline ...
        '% 할 일: function [s, d] = SumDiff(a, b) 로 고치고' newline ...
        '%        s = a + b;  d = a - b;  를 채울 것.' newline ...
        's = a;' newline]);
    add_block('simulink/Sinks/Display', [m '/d_s'], 'Position',[340 190 410 220]);
    wire(m,'a2/1','SumDiff/1'); wire(m,'SumDiff/1','d_s/1');

    add_block('simulink/Sources/Constant', [m '/ang_a'], ...
              'Value','179*pi/180', 'Position',[40 350 130 380]);
    add_block('simulink/Sources/Constant', [m '/ang_b'], ...
              'Value','-179*pi/180', 'Position',[40 400 130 430]);
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/WrapPi'], ...
              'Position',[190 350 310 430]);
    setFcn(m, 'WrapPi', [ ...
        'function e = WrapPi(a)' newline ...
        '%#codegen' newline ...
        '% 할 일: 입력을 (a, b) 두 개로 만들고 아래를 채울 것.' newline ...
        '%   d = a - b;' newline ...
        '%   e = atan2(sin(d), cos(d));' newline ...
        '% Display 에 -2 가 떠야 정답이다 (358 이 아니다).' newline ...
        'e = a;' newline]);
    add_block('simulink/Math Operations/Gain', [m '/rad2deg'], ...
              'Gain','180/pi', 'Position',[370 375 420 405]);
    add_block('simulink/Sinks/Display', [m '/d_wrap'], 'Position',[470 375 540 405]);
    wire(m,'ang_a/1','WrapPi/1');
    wire(m,'WrapPi/1','rad2deg/1'); wire(m,'rad2deg/1','d_wrap/1');

    setSolver(m,'1');
    note(m, sprintf(['[B] 할 일\n' ...
        '세 함수 블록의 첫 줄과 본문을 고쳐서 b1, b2, ang_b 를 각각 연결한다.\n' ...
        '연결되지 않은 Constant 가 3개 있다. 그것이 힌트다.\n' ...
        '마지막 Display 에 -2 가 뜨면 성공. 358 이 뜨면 wrap 이 빠진 것이다.']), 40, 500);
    finish(m);
end

% =====================================================================
% SB3 — Subsystem 과 Goto/From
% =====================================================================
function addCalcSubsystem(m, x, y)
% In1 2개 / Out1 1개짜리 서브시스템을 손으로 만든다.
    s = [m '/Calc'];
    add_block('built-in/Subsystem', s, 'Position',[x y x+120 y+80]);
    add_block('built-in/Inport',  [s '/a'],   'Position',[40  50  70  70]);
    add_block('built-in/Inport',  [s '/b'],   'Position',[40 130  70 150]);
    add_block('simulink/Math Operations/Sum', [s '/Sum'], ...
              'Inputs','+-', 'Position',[150 80 180 120]);
    add_block('simulink/Math Operations/Gain', [s '/K'], ...
              'Gain','2', 'Position',[240 85 280 115]);
    add_block('built-in/Outport', [s '/y'],   'Position',[350 90 380 110]);
    add_line(s,'a/1','Sum/1','autorouting','on');
    add_line(s,'b/1','Sum/2','autorouting','on');
    add_line(s,'Sum/1','K/1','autorouting','on');
    add_line(s,'K/1','y/1','autorouting','on');
end

function build_SB3_done()
    m = 'SB3_subsys_done'; fresh(m);

    add_block('simulink/Sources/Constant', [m '/a'], 'Value','10', 'Position',[40 60 90 90]);
    add_block('simulink/Sources/Constant', [m '/b'], 'Value','4',  'Position',[40 130 90 160]);
    addCalcSubsystem(m, 180, 70);
    add_block('simulink/Signal Routing/Goto', [m '/GotoY'], ...
              'GotoTag','RESULT', 'TagVisibility','local', 'Position',[360 95 420 125]);
    wire(m,'a/1','Calc/1'); wire(m,'b/1','Calc/2'); wire(m,'Calc/1','GotoY/1');

    % From 은 몇 개든 놓을 수 있다 — 선을 끌지 않고 같은 신호를 읽는다
    add_block('simulink/Signal Routing/From', [m '/FromY1'], ...
              'GotoTag','RESULT', 'Position',[40 250 100 280]);
    add_block('simulink/Sinks/Display', [m '/Display'], 'Position',[160 250 230 280]);
    wire(m,'FromY1/1','Display/1');

    add_block('simulink/Signal Routing/From', [m '/FromY2'], ...
              'GotoTag','RESULT', 'Position',[40 330 100 360]);
    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[160 320 210 370]);
    wire(m,'FromY2/1','Scope/1');

    setSolver(m,'5');
    note(m, sprintf(['[C] Subsystem 과 Goto/From\n' ...
        'Calc 를 더블클릭하면 안으로 들어간다. 안에는 Sum 과 Gain 뿐이다.\n' ...
        '포트 이름 a, b, y 는 안쪽 In1/Out1 블록의 이름이 그대로 나온 것이다.\n' ...
        'Goto[RESULT] 하나에 From[RESULT] 두 개가 붙어 있다. 선을 끌지 않았다.\n' ...
        '정답: (10 - 4) * 2 = 12']), 40, 430);
    finish(m);
end

function build_SB3_todo()
    m = 'SB3_subsys_todo'; fresh(m);

    % 평평한 모델 — 서브시스템 없이 모든 블록이 최상위에 놓여 있다
    add_block('simulink/Sources/Constant', [m '/a'], 'Value','10', 'Position',[40 60 90 90]);
    add_block('simulink/Sources/Constant', [m '/b'], 'Value','4',  'Position',[40 130 90 160]);
    add_block('simulink/Math Operations/Sum', [m '/Sum'], ...
              'Inputs','+-', 'Position',[180 80 210 120]);
    add_block('simulink/Math Operations/Gain', [m '/K'], ...
              'Gain','2', 'Position',[270 85 310 115]);
    add_block('simulink/Sinks/Display', [m '/Display'], 'Position',[400 85 470 115]);
    wire(m,'a/1','Sum/1'); wire(m,'b/1','Sum/2');
    wire(m,'Sum/1','K/1'); wire(m,'K/1','Display/1');

    setSolver(m,'5');
    note(m, sprintf(['[C] 할 일\n' ...
        '1. Sum 과 K 두 블록만 마우스로 선택한 뒤 Ctrl+G 를 누른다\n' ...
        '   -> Subsystem 이 만들어진다. 이름을 Calc 로 바꾼다\n' ...
        '2. Calc 를 더블클릭해 안으로 들어가 In1/In2/Out1 의 이름을 a, b, y 로 바꾼다\n' ...
        '   -> 바깥에서 보는 포트 이름이 따라 바뀐다\n' ...
        '3. Display 로 가는 선을 지우고, 대신 Goto 블록(태그 RESULT)을 붙인다\n' ...
        '4. From 블록(태그 RESULT)을 놓고 Display 에 잇는다\n' ...
        '5. From 을 하나 더 놓고 Scope 에도 이어 본다\n' ...
        '정답: (10 - 4) * 2 = 12']), 40, 250);
    finish(m);
end

% =====================================================================
% SB4 — 버스
% =====================================================================
function build_SB4_done()
    m = 'SB4_bus_done'; fresh(m);

    add_block('simulink/Sources/Constant', [m '/c_x'], 'Value','1', 'Position',[40 40 90 70]);
    add_block('simulink/Sources/Constant', [m '/c_y'], 'Value','2', 'Position',[40 90 90 120]);
    add_block('simulink/Sources/Constant', [m '/c_z'], 'Value','3', 'Position',[40 140 90 170]);

    add_block('simulink/Signal Routing/Bus Creator', [m '/Inner'], ...
              'Inputs','3', 'Position',[180 40 190 170]);
    nwire(m,'c_x/1','Inner/1','x');
    nwire(m,'c_y/1','Inner/2','y');
    nwire(m,'c_z/1','Inner/3','z');

    add_block('simulink/Sources/Digital Clock', [m '/c_stamp'], ...
              'SampleTime','0.05', 'Position',[40 230 90 270]);
    add_block('simulink/Signal Routing/Bus Creator', [m '/Outer'], ...
              'Inputs','2', 'Position',[300 90 310 260]);
    nwire(m,'Inner/1','Outer/1','Inner');
    nwire(m,'c_stamp/1','Outer/2','stamp');

    % 중첩 버스에서 원소를 뽑을 때는 전체 경로를 쓴다
    add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], ...
              'OutputSignals','Inner.y,stamp', 'Position',[400 130 410 220]);
    wire(m,'Outer/1','Sel/1');
    add_block('simulink/Sinks/Display', [m '/d_y'],     'Position',[480 125 550 155]);
    add_block('simulink/Sinks/Display', [m '/d_stamp'], 'Position',[480 195 550 225]);
    wire(m,'Sel/1','d_y/1'); wire(m,'Sel/2','d_stamp/1');

    % Bus Assignment — 버스는 그대로 두고 한 원소만 갈아끼운다
    add_block('simulink/Sources/Constant', [m '/c_new'], 'Value','99', 'Position',[400 330 460 360]);
    add_block('simulink/Signal Routing/Bus Assignment', [m '/Asg'], ...
              'AssignedSignals','Inner.z', 'Position',[540 280 600 370]);
    wire(m,'Outer/1','Asg/1'); wire(m,'c_new/1','Asg/2');
    add_block('simulink/Signal Routing/Bus Selector', [m '/Sel2'], ...
              'OutputSignals','Inner.z', 'Position',[660 300 670 350]);
    add_block('simulink/Sinks/Display', [m '/d_z'], 'Position',[720 310 790 340]);
    wire(m,'Asg/1','Sel2/1'); wire(m,'Sel2/1','d_z/1');

    setSolver(m,'1');
    note(m, sprintf(['[D] 버스\n' ...
        'Bus Creator 는 여러 신호를 한 줄로 묶는다. 원소 이름은 신호선 이름을 따라간다.\n' ...
        'Inner(x,y,z) 를 다시 Outer 안에 넣었다. 그래서 경로가 Inner.y 처럼 두 단이다.\n' ...
        'Bus Selector 에서 원소를 고를 때 이 전체 경로를 그대로 적어야 한다.\n' ...
        'Bus Assignment 는 버스를 통째로 받아 Inner.z 한 칸만 99 로 바꿔 내보낸다.\n' ...
        '확인: d_y = 2,  d_z = 99']), 40, 430);
    finish(m);
end

function build_SB4_todo()
    m = 'SB4_bus_todo'; fresh(m);

    add_block('simulink/Sources/Constant', [m '/c_x'], 'Value','1', 'Position',[40 40 90 70]);
    add_block('simulink/Sources/Constant', [m '/c_y'], 'Value','2', 'Position',[40 90 90 120]);
    add_block('simulink/Sources/Constant', [m '/c_z'], 'Value','3', 'Position',[40 140 90 170]);

    add_block('simulink/Signal Routing/Bus Creator', [m '/Inner'], ...
              'Inputs','3', 'Position',[180 40 190 170]);
    nwire(m,'c_x/1','Inner/1','x');
    nwire(m,'c_y/1','Inner/2','y');
    nwire(m,'c_z/1','Inner/3','z');

    add_block('simulink/Sources/Digital Clock', [m '/c_stamp'], ...
              'SampleTime','0.05', 'Position',[40 230 90 270]);
    add_block('simulink/Signal Routing/Bus Creator', [m '/Outer'], ...
              'Inputs','2', 'Position',[300 90 310 260]);
    nwire(m,'Inner/1','Outer/1','Inner');
    nwire(m,'c_stamp/1','Outer/2','stamp');

    % stamp 하나만 뽑아 둔 상태 — 학생이 Inner.y 를 추가한다
    add_block('simulink/Signal Routing/Bus Selector', [m '/Sel'], ...
              'OutputSignals','stamp', 'Position',[400 150 410 200]);
    wire(m,'Outer/1','Sel/1');
    add_block('simulink/Sinks/Display', [m '/d_stamp'], 'Position',[480 160 550 190]);
    wire(m,'Sel/1','d_stamp/1');

    add_block('simulink/Sources/Constant', [m '/c_new'], 'Value','99', 'Position',[400 330 460 360]);

    setSolver(m,'1');
    note(m, sprintf(['[D] 할 일\n' ...
        '1. Sel 을 더블클릭한다. 왼쪽 목록에 Inner 를 펼치면 x, y, z 가 보인다\n' ...
        '   Inner.y 를 골라 오른쪽으로 옮긴다 -> 출력 포트가 하나 늘어난다\n' ...
        '   Display 를 하나 더 놓고 잇는다 (2 가 떠야 한다)\n' ...
        '2. Bus Assignment 블록을 놓는다\n' ...
        '   - 1번 포트에 Outer 의 버스를 잇는다\n' ...
        '   - 대화상자에서 Inner.z 를 골라 오른쪽으로 옮긴다\n' ...
        '   - 새로 생긴 포트에 c_new(99) 를 잇는다\n' ...
        '3. Bus Selector 를 하나 더 놓아 Inner.z 를 뽑고 Display 로 확인한다 (99)']), 40, 430);
    finish(m);
end

% =====================================================================
% SB5 — 이산 PID · 포화 · 안티와인드업
% =====================================================================
function addToyPlant(m, x, y)
% 아무 물리적 의미도 없는 장난감 1차 이산 플랜트.
% 분자 차수가 분모보다 낮아 대수 루프가 생기지 않는다.
% 정상 이득은 0.1/(1-0.9) = 1 이다. 즉 입력이 1 이면 출력도 1 로 수렴한다.
    add_block('simulink/Discrete/Discrete Transfer Fcn', [m '/Plant'], ...
              'Numerator','[0.1]', 'Denominator','[1 -0.9]', 'SampleTime','0.05', ...
              'Position',[x y x+120 y+60]);
end

function addReference(m)
% 기준 신호: 0 -> 2 (t=1s) -> 0.5 (t=10s)
%
%   플랜트 정상 이득이 1 이고 포화가 +-1 이므로 출력은 1 을 넘을 수 없다.
%   따라서 목표 2 는 "도달할 수 없는 값"이다. 이 9초 동안 적분기가 계속 부푼다.
%   t=10s 에 목표를 0.5 로 내리면, 부푼 적분값이 빠지는 데 시간이 걸린다.
%   이것이 와인드업이다. 안티와인드업을 켜면 이 지연이 사라진다.
    add_block('simulink/Sources/Step', [m '/Ref_up'], ...
              'Time','1', 'Before','0', 'After','2', 'SampleTime','0.05', ...
              'Position',[40 60 90 100]);
    add_block('simulink/Sources/Step', [m '/Ref_dn'], ...
              'Time','10', 'Before','0', 'After','-1.5', 'SampleTime','0.05', ...
              'Position',[40 130 90 170]);
    add_block('simulink/Math Operations/Sum', [m '/Ref'], ...
              'Inputs','++', 'Position',[140 100 170 130]);
    add_line(m,'Ref_up/1','Ref/1','autorouting','on');
    add_line(m,'Ref_dn/1','Ref/2','autorouting','on');
end

function build_SB5_done()
    m = 'SB5_pid_done'; fresh(m);

    addReference(m);
    add_block('simulink/Math Operations/Sum', [m '/Err'], ...
              'Inputs','+-', 'Position',[230 100 260 130]);
    add_block('simulink/Discrete/Discrete PID Controller', [m '/PID'], ...
              'Position',[310 90 390 140]);
    set_param([m '/PID'], 'Controller','PI', 'P','1', 'I','2', ...
              'SampleTime','0.05', 'LimitOutput','on', ...
              'UpperSaturationLimit','1', 'LowerSaturationLimit','-1', ...
              'AntiWindupMode','clamping');
    add_block('simulink/Discontinuities/Saturation', [m '/Sat'], ...
              'UpperLimit','1', 'LowerLimit','-1', 'Position',[440 100 480 130]);
    addToyPlant(m, 530, 85);

    add_block('simulink/Signal Routing/Goto', [m '/GotoY'], ...
              'GotoTag','Y', 'TagVisibility','local', 'Position',[700 100 750 130]);
    add_block('simulink/Signal Routing/From', [m '/FromY'], ...
              'GotoTag','Y', 'Position',[230 190 280 220]);

    wire(m,'Ref/1','Err/1');
    wire(m,'FromY/1','Err/2');
    wire(m,'Err/1','PID/1');
    wire(m,'PID/1','Sat/1');
    wire(m,'Sat/1','Plant/1');
    wire(m,'Plant/1','GotoY/1');

    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[700 210 750 260]);
    set_param([m '/Scope'],'NumInputPorts','2');
    add_block('simulink/Signal Routing/From', [m '/FromY2'], ...
              'GotoTag','Y', 'Position',[600 215 650 245]);
    wire(m,'FromY2/1','Scope/1');
    wire(m,'Ref/1','Scope/2');

    setSolver(m,'30');
    note(m, sprintf(['[E] 이산 PID · 포화 · 안티와인드업\n' ...
        'Plant 는 아무 의미 없는 장난감 전달함수다. 물리와 상관없다.\n' ...
        '정상 이득이 1 이고 포화가 +-1 이라 출력은 1 을 못 넘는다.\n' ...
        '그런데 1~10초 목표는 2 다. 도달할 수 없는 목표라 적분기가 계속 부푼다.\n' ...
        '10초에 목표를 0.5 로 내렸을 때 얼마나 빨리 따라오는지가 관전 포인트.\n' ...
        'PID 대화상자에서 Anti-windup method 를 none <-> clamping 으로 바꿔 볼 것.']), 40, 330);
    finish(m);
end

function build_SB5_todo()
    m = 'SB5_pid_todo'; fresh(m);

    addReference(m);
    add_block('simulink/Math Operations/Sum', [m '/Err'], ...
              'Inputs','+-', 'Position',[230 100 260 130]);
    add_block('simulink/Discrete/Discrete PID Controller', [m '/PID'], ...
              'Position',[310 90 390 140]);
    set_param([m '/PID'], 'Controller','P', 'P','1', 'SampleTime','0.05');
    addToyPlant(m, 530, 85);

    add_block('simulink/Signal Routing/Goto', [m '/GotoY'], ...
              'GotoTag','Y', 'TagVisibility','local', 'Position',[700 100 750 130]);
    add_block('simulink/Signal Routing/From', [m '/FromY'], ...
              'GotoTag','Y', 'Position',[230 190 280 220]);

    wire(m,'Ref/1','Err/1');
    wire(m,'FromY/1','Err/2');
    wire(m,'Err/1','PID/1');
    wire(m,'PID/1','Plant/1');
    wire(m,'Plant/1','GotoY/1');

    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[700 210 750 260]);
    set_param([m '/Scope'],'NumInputPorts','2');
    add_block('simulink/Signal Routing/From', [m '/FromY2'], ...
              'GotoTag','Y', 'Position',[600 215 650 245]);
    wire(m,'FromY2/1','Scope/1');
    wire(m,'Ref/1','Scope/2');

    setSolver(m,'30');
    note(m, sprintf(['[E] 할 일 — 한 번에 하나씩, 매번 Run 해서 Scope 를 볼 것\n' ...
        '0. 지금은 P 제어만 있고 포화도 없다. 그대로 Run.\n' ...
        '   목표 2 인데 출력이 1 에서 멈춘다. 목표 0.5 에서도 못 맞춘다\n' ...
        '   -> P 만으로는 남는 오차(정상상태 오차)를 못 없앤다\n' ...
        '1. PID 더블클릭 -> Controller 를 PI 로, I 를 2 로. Run.\n' ...
        '   -> 이번엔 목표를 맞춘다\n' ...
        '2. PID 와 Plant 사이 선을 지우고 Saturation(+-1)을 끼워 넣는다. Run.\n' ...
        '   -> 10초에 목표가 0.5 로 내려가도 한참 안 내려온다. 이것이 와인드업\n' ...
        '3. PID 대화상자에서 Output saturation 을 켜고 한계 +-1,\n' ...
        '   Anti-windup method 를 clamping 으로. Run.\n' ...
        '   -> 10초 뒤 바로 따라 내려온다\n' ...
        '4. 2번과 3번의 Scope 를 Data Inspector 로 겹쳐 비교한다']), 40, 330);
    finish(m);
end

% =====================================================================
% SB6 — 파라미터 · 신호 로깅 · Data Inspector
% =====================================================================
function logPort(m, blk, nm)
    ph = get_param([m '/' blk], 'PortHandles');
    set_param(ph.Outport(1), 'DataLogging','on', ...
              'DataLoggingNameMode','Custom', 'DataLoggingName', nm);
end

function build_SB6_done()
    m = 'SB6_param_done'; fresh(m);

    add_block('simulink/Sources/Sine Wave', [m '/Sine'], ...
              'Amplitude','A_sig', 'Frequency','1', 'SampleTime','Ts', ...
              'Position',[40 100 100 160]);
    add_block('simulink/Math Operations/Gain', [m '/Gain'], ...
              'Gain','K_gain', 'Position',[180 115 230 145]);
    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[330 105 380 155]);
    add_block('simulink/Sinks/To Workspace', [m '/ToWs'], ...
              'VariableName','y_ts', 'SaveFormat','Timeseries', ...
              'Position',[330 200 390 240]);

    wire(m,'Sine/1','Gain/1');
    wire(m,'Gain/1','Scope/1');
    wire(m,'Gain/1','ToWs/1');
    logPort(m, 'Gain', 'y');

    set_param(m, 'SignalLogging','on', 'SignalLoggingName','logsout', ...
                 'SaveOutput','on', 'SaveTime','on');
    setSolver(m,'10');
    note(m, sprintf(['[F] 파라미터 · 로깅\n' ...
        'Sine 의 진폭이 A_sig, Gain 이 K_gain, 샘플 타임이 Ts 로 되어 있다.\n' ...
        '숫자가 아니라 변수 이름이다. 값은 MATLAB 작업공간에서 읽어 온다.\n' ...
        '먼저  >> SB_setup  을 실행해야 돌아간다.\n' ...
        'Gain 출력에 y 라는 이름으로 로깅이 켜져 있다 -> out.logsout\n' ...
        'To Workspace 는 같은 신호를 y_ts 로 따로 내보낸다.\n' ...
        '실행:  >> SB_setup;  out = sim(''SB6_param_done'');  SB_plot(out)']), 40, 320);
    finish(m);
end

function build_SB6_todo()
    m = 'SB6_param_todo'; fresh(m);

    add_block('simulink/Sources/Sine Wave', [m '/Sine'], ...
              'Amplitude','1', 'Frequency','1', 'SampleTime','0.05', ...
              'Position',[40 100 100 160]);
    add_block('simulink/Math Operations/Gain', [m '/Gain'], ...
              'Gain','2', 'Position',[180 115 230 145]);
    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[330 105 380 155]);

    wire(m,'Sine/1','Gain/1');
    wire(m,'Gain/1','Scope/1');

    setSolver(m,'10');
    note(m, sprintf(['[F] 할 일\n' ...
        '1. 숫자를 변수 이름으로 바꾼다\n' ...
        '   Sine 진폭 1 -> A_sig,  샘플 타임 0.05 -> Ts,  Gain 2 -> K_gain\n' ...
        '2. 그대로 Run 하면 "Undefined variable" 오류가 난다. 오류를 먼저 볼 것\n' ...
        '3. >> SB_setup 을 실행한 뒤 다시 Run\n' ...
        '4. Gain 출력 신호선을 우클릭 -> Log Selected Signals\n' ...
        '   신호 이름을 y 로 붙인다\n' ...
        '5. To Workspace 블록을 놓고 변수 이름을 y_ts 로\n' ...
        '6. K_gain 을 2 와 5 로 바꿔 두 번 돌린 뒤 Data Inspector 에서 겹쳐 본다']), 40, 250);
    finish(m);
end
