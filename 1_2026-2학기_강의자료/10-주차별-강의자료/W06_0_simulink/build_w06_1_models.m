function build_w06_1_models()
% BUILD_W06_1_MODELS  6주차 보충 2일차(G~L절) 모델 12개를 만든다.
%
%   >> build_w06_1_models
%
%   1일차 모델(SB1~SB6)은 build_w06_0_models.m 이 만든다.
%   여기서 만드는 것은 SB7~SB12 이며, 7~9주차에서 **실제로 쓰는** 블록들이다.
%
%     SB7  신호 묶기·풀기      Mux / Demux / Selector / Reshape
%     SB8  이산 시스템         샘플타임 / Unit Delay / 멀티레이트
%     SB9  연속 시스템         Integrator / Transfer Fcn / 솔버
%     SB10 판단                Relational / Switch / Multiport Switch / Stop
%     SB11 조건부 실행         Enabled / Triggered Subsystem
%     SB12 재사용              Mask / 라이브러리
%
%   각 주제마다 `_done` (완성본) 과 `_todo` (학생이 채울 것) 두 개가 나온다.

    here = fileparts(mfilename('fullpath'));
    cd(here);

    build_SB7_done();   build_SB7_todo();
    build_SB8_done();   build_SB8_todo();
    build_SB9_done();   build_SB9_todo();
    build_SB10_done();  build_SB10_todo();
    build_SB11_done();  build_SB11_todo();
    build_SB12_done();  build_SB12_todo();

    % 배치와 색을 정리한다
    for k = 7:12
        d = dir(sprintf('SB%d_*.slx', k));
        for j = 1:numel(d)
            [~, mName] = fileparts(d(j).name);
            try, tidy_layout(mName); tidy_layout(mName); catch, end
        end
    end

    fprintf('\n완료. 생성된 모델:\n');
    d = dir('SB*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
end

% =====================================================================
% 공통 헬퍼 — 1일차 스크립트와 같은 관용구
% =====================================================================
function fresh(m)
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end

function setSolverD(m, stopTime)
% 이산 전용 — 고정 스텝
    set_param(m, 'SolverType','Fixed-step', 'SolverName','FixedStepDiscrete', ...
                 'FixedStep','0.05', 'StopTime',stopTime, 'SimulationMode','normal');
end

function setSolverC(m, stopTime)
% 연속 상태(Integrator, Transfer Fcn)가 있으면 이 솔버를 쓴다
    set_param(m, 'SolverType','Variable-step', 'SolverName','ode45', ...
                 'StopTime',stopTime, 'SimulationMode','normal', ...
                 'MaxStep','0.01');
end

function note(m, txt, x, y)
    add_block('built-in/Note', [m '/note'], 'Position',[x y x y], 'Text', txt);
end

function wire(m, src, dst)
    add_line(m, src, dst, 'autorouting','on');
end

function finish(m)
    save_system(m); close_system(m, 0);
    fprintf('  [OK] %s\n', m);
end

function B(m, lib, name, pos, varargin)
    add_block(lib, [m '/' name], 'Position', pos, varargin{:});
end

% =====================================================================
% G. SB7 — 신호 묶기와 풀기
% =====================================================================
function build_SB7_done()
    m = 'SB7_signal_done'; fresh(m);

    B(m,'simulink/Sources/Sine Wave','Sine',[40 40 90 90], ...
      'Amplitude','1','Frequency','1','SampleTime','0.05');
    B(m,'simulink/Sources/Constant','Two',[40 130 90 160],'Value','2');
    B(m,'simulink/Sources/Digital Clock','Clk',[40 200 90 230],'SampleTime','0.05');

    B(m,'simulink/Signal Routing/Mux','Mux3',[170 45 175 225],'Inputs','3');

    % (1) 벡터 통째로 이득 -> Scope
    B(m,'simulink/Math Operations/Gain','G10',[260 40 300 70],'Gain','10');
    B(m,'simulink/Sinks/Scope','ScVec',[380 35 420 75]);

    % (2) Demux 로 셋 다 풀기
    B(m,'simulink/Signal Routing/Demux','Demux3',[260 110 265 250],'Outputs','3');
    B(m,'simulink/Sinks/Display','D1',[360 105 430 135]);
    B(m,'simulink/Sinks/Display','D2',[360 165 430 195]);
    B(m,'simulink/Sinks/Display','D3',[360 225 430 255]);

    % (3) Selector 로 2번째만 뽑기
    B(m,'simulink/Signal Routing/Selector','Sel2',[260 310 310 350], ...
      'NumberOfDimensions','1','IndexOptions','Index vector (dialog)','Indices','2');
    B(m,'simulink/Sinks/Display','DSel',[380 315 450 345]);

    wire(m,'Sine/1','Mux3/1');
    wire(m,'Two/1', 'Mux3/2');
    wire(m,'Clk/1', 'Mux3/3');
    wire(m,'Mux3/1','G10/1');
    wire(m,'G10/1','ScVec/1');
    wire(m,'Mux3/1','Demux3/1');
    wire(m,'Demux3/1','D1/1');
    wire(m,'Demux3/2','D2/1');
    wire(m,'Demux3/3','D3/1');
    wire(m,'Mux3/1','Sel2/1');
    wire(m,'Sel2/1','DSel/1');

    setSolverD(m,'10');
    note(m, sprintf(['[G] 신호 묶기와 풀기\n' ...
        'Mux  : 여러 신호를 한 선(벡터)으로 묶는다. 선이 굵게 표시된다\n' ...
        'Demux: 벡터를 다시 낱개로 푼다\n' ...
        'Selector: 벡터에서 원하는 번호만 뽑는다 (여기서는 2번 = 상수 2)\n' ...
        'Gain 은 벡터 전체에 한꺼번에 걸린다 -> 세 값이 모두 10배']), 40, 420);
    finish(m);
end

function build_SB7_todo()
    m = 'SB7_signal_todo'; fresh(m);
    B(m,'simulink/Sources/Sine Wave','Sine',[40 40 90 90], ...
      'Amplitude','1','Frequency','1','SampleTime','0.05');
    B(m,'simulink/Sources/Constant','Two',[40 130 90 160],'Value','2');
    B(m,'simulink/Sources/Digital Clock','Clk',[40 200 90 230],'SampleTime','0.05');
    B(m,'simulink/Sinks/Scope','ScVec',[380 35 420 75]);
    setSolverD(m,'10');
    note(m, sprintf(['[G] 할 일\n' ...
        '1. Mux (Signal Routing) 를 놓고 입력 개수를 3 으로\n' ...
        '2. Sine, Two, Clk 을 차례로 Mux 에 연결\n' ...
        '3. Mux 출력을 Gain(10) 에 넣고 Scope 로 본다  -> 선이 굵어지는 것을 확인\n' ...
        '4. Demux (출력 3개) 로 다시 풀어 Display 세 개에 연결\n' ...
        '5. Selector 를 놓고 Indices 를 2 로 -> 상수 2 만 나오는지 확인\n' ...
        '6. Mux 출력선을 우클릭 -> Signal Properties 에서 이름을 state 로']), 40, 300);
    finish(m);
end

% =====================================================================
% H. SB8 — 이산 시스템
% =====================================================================
function build_SB8_done()
    m = 'SB8_discrete_done'; fresh(m);

    B(m,'simulink/Sources/Constant','One',[40 100 90 130],'Value','1');

    % (1) Unit Delay 로 손수 만든 누적기:  y[k] = y[k-1] + Ts*u[k]
    B(m,'simulink/Math Operations/Gain','GTs',[160 100 200 130],'Gain','0.05');
    B(m,'simulink/Math Operations/Sum','SumA',[260 95 290 135],'Inputs','++');
    B(m,'simulink/Discrete/Unit Delay','UD',[260 200 300 240],'SampleTime','0.05');

    % (2) 같은 일을 하는 기성 블록
    B(m,'simulink/Discrete/Discrete-Time Integrator','DTI',[260 300 320 340], ...
      'SampleTime','0.05','IntegratorMethod','Integration: Backward Euler');

    B(m,'simulink/Sinks/Scope','Sc',[430 140 470 190]);
    set_param([m '/Sc'],'NumInputPorts','2');

    % (3) 멀티레이트 — 느린 신호를 빠른 쪽으로 넘긴다
    B(m,'simulink/Sources/Sine Wave','Slow',[40 420 90 470], ...
      'Amplitude','1','Frequency','1','SampleTime','0.5');
    B(m,'simulink/Signal Attributes/Rate Transition','RT',[180 425 230 465]);
    set_param([m '/RT'],'OutPortSampleTime','0.05');
    B(m,'simulink/Sinks/Scope','ScRate',[330 420 370 470]);

    wire(m,'One/1','GTs/1');
    wire(m,'GTs/1','SumA/1');
    wire(m,'SumA/1','UD/1');
    wire(m,'UD/1','SumA/2');
    wire(m,'SumA/1','Sc/1');
    wire(m,'One/1','DTI/1');
    wire(m,'DTI/1','Sc/2');
    wire(m,'Slow/1','RT/1');
    wire(m,'RT/1','ScRate/1');

    setSolverD(m,'10');
    set_param(m,'SampleTimeColors','on');
    note(m, sprintf(['[H] 이산 시스템\n' ...
        '위: Unit Delay 로 만든 누적기.  y[k] = y[k-1] + Ts*u[k]\n' ...
        '  -> 10초 뒤 값이 10 이 되면 맞다 (1 을 0.05 씩 200번 더함)\n' ...
        '아래: Discrete-Time Integrator (Backward Euler) 는 같은 일을 하는 기성 블록\n' ...
        '  두 곡선이 정확히 겹친다. 적분법을 Forward Euler 로 바꾸면 한 스텝(0.05) 어긋난다\n' ...
        '맨 아래: 0.5 s 신호를 0.05 s 쪽으로 넘길 때 Rate Transition 이 필요하다\n' ...
        '샘플타임 색 표시가 켜져 있다 (Debug -> Information Overlays -> Sample Time)']), ...
        40, 540);
    finish(m);
end

function build_SB8_todo()
    m = 'SB8_discrete_todo'; fresh(m);
    B(m,'simulink/Sources/Constant','One',[40 100 90 130],'Value','1');
    B(m,'simulink/Sinks/Scope','Sc',[430 140 470 190]);
    B(m,'simulink/Sources/Sine Wave','Slow',[40 420 90 470], ...
      'Amplitude','1','Frequency','1','SampleTime','0.5');
    B(m,'simulink/Sinks/Scope','ScRate',[330 420 370 470]);
    setSolverD(m,'10');
    note(m, sprintf(['[H] 할 일\n' ...
        '1. Gain(0.05) -> Sum(++) -> Unit Delay 되먹임으로 누적기를 만든다\n' ...
        '   Unit Delay 출력이 Sum 의 두 번째 입력으로 돌아가야 한다\n' ...
        '2. 10초 뒤 값이 10 인지 확인\n' ...
        '3. Discrete-Time Integrator 를 놓고 같은 입력을 줘 두 곡선을 겹쳐 본다\n' ...
        '4. Unit Delay 를 빼면 무슨 오류가 나는가?  (대수 루프)\n' ...
        '5. Slow(0.5 s) 를 Scope 로 바로 보내면 경고가 난다. Rate Transition 을 넣는다\n' ...
        '6. 샘플타임 색을 켠다: Debug -> Information Overlays -> Sample Time']), 40, 540);
    finish(m);
end

% =====================================================================
% I. SB9 — 연속 시스템
% =====================================================================
function build_SB9_done()
    m = 'SB9_continuous_done'; fresh(m);

    B(m,'simulink/Sources/Step','Step',[40 120 90 170],'Time','1','After','1');

    % (1) 전달함수로 1차 지연
    B(m,'simulink/Continuous/Transfer Fcn','TF',[200 40 280 90], ...
      'Numerator','[1]','Denominator','[0.3 1]');

    % (2) 같은 것을 Integrator 로 직접
    B(m,'simulink/Math Operations/Sum','SumB',[200 150 230 190],'Inputs','+-');
    B(m,'simulink/Math Operations/Gain','Ginv',[280 155 320 185],'Gain','1/0.3');
    B(m,'simulink/Continuous/Integrator','Int',[370 150 410 190]);

    % (3) 물리적 한계 — 포화가 걸린 적분기
    B(m,'simulink/Sources/Constant','Big',[40 300 90 330],'Value','5');
    B(m,'simulink/Continuous/Integrator','IntSat',[200 295 240 335]);
    set_param([m '/IntSat'],'LimitOutput','on','UpperSaturationLimit','3', ...
                            'LowerSaturationLimit','-3');
    B(m,'simulink/Sinks/Scope','ScSat',[350 295 390 335]);

    B(m,'simulink/Sinks/Scope','Sc',[500 90 540 140]);
    set_param([m '/Sc'],'NumInputPorts','2');

    wire(m,'Step/1','TF/1');
    wire(m,'TF/1','Sc/1');
    wire(m,'Step/1','SumB/1');
    wire(m,'SumB/1','Ginv/1');
    wire(m,'Ginv/1','Int/1');
    wire(m,'Int/1','SumB/2');
    wire(m,'Int/1','Sc/2');
    wire(m,'Big/1','IntSat/1');
    wire(m,'IntSat/1','ScSat/1');

    setSolverC(m,'5');
    note(m, sprintf(['[I] 연속 시스템\n' ...
        '위: Transfer Fcn 1/(0.3s+1) — 1차 지연. 7주차 모터 모델이 바로 이것이다\n' ...
        '가운데: 같은 식을 Integrator 로 직접 짠 것.  dy/dt = (u - y)/tau\n' ...
        '  두 곡선이 겹쳐야 한다. 겹치지 않으면 배선이나 게인을 확인\n' ...
        '아래: Integrator 에 출력 한계 +-3 을 걸었다 (Limit output)\n' ...
        '  물리적 한계가 있는 상태는 이렇게 막는다. 안 막으면 무한히 커진다\n' ...
        '솔버가 ode45(가변 스텝)로 바뀐 것에 주의 — 연속 상태가 있으면 필요하다']), ...
        40, 420);
    finish(m);
end

function build_SB9_todo()
    m = 'SB9_continuous_todo'; fresh(m);
    B(m,'simulink/Sources/Step','Step',[40 120 90 170],'Time','1','After','1');
    B(m,'simulink/Sinks/Scope','Sc',[500 90 540 140]);
    setSolverC(m,'5');
    note(m, sprintf(['[I] 할 일\n' ...
        '1. Transfer Fcn 을 놓고 분자 [1], 분모 [0.3 1] 로 둔다\n' ...
        '2. Step 을 넣고 Scope 로 본다. 63%% 에 도달하는 시각이 0.3 s 인지 확인\n' ...
        '3. 같은 것을 Sum(+-) -> Gain(1/0.3) -> Integrator -> 되먹임 으로 직접 만든다\n' ...
        '4. 두 곡선을 한 Scope 에 겹쳐 본다\n' ...
        '5. Integrator 를 하나 더 놓고 Limit output 을 켜서 +-3 으로 막는다\n' ...
        '   상수 5 를 넣고 출력이 3 에서 멈추는지 확인\n' ...
        '6. 솔버를 ode45 <-> 고정스텝 0.05 로 바꿔 가며 결과가 달라지는지 본다']), ...
        40, 300);
    finish(m);
end

% =====================================================================
% J. SB10 — 판단
% =====================================================================
function build_SB10_done()
    m = 'SB10_logic_done'; fresh(m);

    B(m,'simulink/Sources/Sine Wave','Sine',[40 40 90 90], ...
      'Amplitude','1','Frequency','0.5','SampleTime','0.05');
    B(m,'simulink/Sources/Constant','Zero',[40 130 90 160],'Value','0');
    B(m,'simulink/Logic and Bit Operations/Relational Operator','Rel',[170 60 210 100], ...
      'Operator','>');

    % Switch — 조건이 참이면 위 입력, 아니면 아래 입력
    B(m,'simulink/Sources/Constant','Plus',[170 150 220 180],'Value','1');
    B(m,'simulink/Sources/Constant','Minus',[170 250 220 280],'Value','-1');
    B(m,'simulink/Signal Routing/Switch','Sw',[300 150 340 250]);
    set_param([m '/Sw'],'Criteria','u2 > Threshold','Threshold','0.5');
    B(m,'simulink/Sinks/Scope','ScSw',[420 175 460 225]);

    % Multiport Switch — 9주차 ModeSwitch 의 원리
    B(m,'simulink/Sources/Constant','Mode',[40 380 90 410],'Value','2');
    B(m,'simulink/Sources/Constant','A',[40 450 90 480],'Value','10');
    B(m,'simulink/Sources/Constant','Bc',[40 510 90 540],'Value','20');
    B(m,'simulink/Sources/Constant','Cc',[40 570 90 600],'Value','30');
    B(m,'simulink/Signal Routing/Multiport Switch','MSw',[220 380 260 600]);
    set_param([m '/MSw'],'Inputs','3','DataPortOrder','One-based contiguous');
    B(m,'simulink/Sinks/Display','DMs',[360 475 430 505]);

    % Stop Simulation — 8·9주차 임무 종료가 이 방식이다
    B(m,'simulink/Sources/Digital Clock','Clk',[40 680 90 710],'SampleTime','0.05');
    B(m,'simulink/Sources/Constant','T15',[40 750 90 780],'Value','15');
    B(m,'simulink/Logic and Bit Operations/Relational Operator','RelT',[200 695 240 735], ...
      'Operator','>=');
    B(m,'simulink/Sinks/Stop Simulation','Stop',[340 700 380 730]);

    wire(m,'Sine/1','Rel/1');
    wire(m,'Zero/1','Rel/2');
    wire(m,'Plus/1','Sw/1');
    wire(m,'Rel/1','Sw/2');
    wire(m,'Minus/1','Sw/3');
    wire(m,'Sw/1','ScSw/1');
    wire(m,'Mode/1','MSw/1');
    wire(m,'A/1','MSw/2');
    wire(m,'Bc/1','MSw/3');
    wire(m,'Cc/1','MSw/4');
    wire(m,'MSw/1','DMs/1');
    wire(m,'Clk/1','RelT/1');
    wire(m,'T15/1','RelT/2');
    wire(m,'RelT/1','Stop/1');

    setSolverD(m,'60');
    note(m, sprintf(['[J] 판단 블록\n' ...
        'Relational Operator: 두 값을 비교해 참(1)/거짓(0) 을 낸다\n' ...
        'Switch: 가운데 입력이 조건을 만족하면 위, 아니면 아래를 내보낸다\n' ...
        '  -> 사인파의 부호에 따라 +1 / -1 이 나온다\n' ...
        'Multiport Switch: 첫 입력이 번호. Mode=2 이므로 두 번째 값 20 이 나온다\n' ...
        '  -> 9주차 ModeSwitch(유도법칙 갈아 끼우기)가 바로 이 블록이다\n' ...
        'Stop Simulation: 입력이 0 이 아니면 시뮬레이션을 멈춘다\n' ...
        '  정지 시간을 60 으로 뒀지만 15초에서 멈춘다. 8·9주차 임무 종료가 이 방식']), ...
        40, 830);
    finish(m);
end

function build_SB10_todo()
    m = 'SB10_logic_todo'; fresh(m);
    B(m,'simulink/Sources/Sine Wave','Sine',[40 40 90 90], ...
      'Amplitude','1','Frequency','0.5','SampleTime','0.05');
    B(m,'simulink/Sources/Constant','Zero',[40 130 90 160],'Value','0');
    B(m,'simulink/Sinks/Scope','ScSw',[420 175 460 225]);
    B(m,'simulink/Sources/Digital Clock','Clk',[40 380 90 410],'SampleTime','0.05');
    setSolverD(m,'60');
    note(m, sprintf(['[J] 할 일\n' ...
        '1. Relational Operator(>) 로 Sine 과 0 을 비교한다\n' ...
        '2. Switch 를 놓고 상수 +1 / -1 을 위·아래 입력에, 비교 결과를 가운데에\n' ...
        '   Criteria 를 u2 > Threshold, Threshold 0.5 로 둔다\n' ...
        '3. Scope 로 보면 사각파가 나와야 한다\n' ...
        '4. Multiport Switch(입력 3개)를 놓고 상수 10/20/30 을 연결\n' ...
        '   맨 위 입력에 Mode 상수를 넣고 1,2,3 으로 바꿔 가며 Display 확인\n' ...
        '5. Digital Clock >= 15 이면 Stop Simulation 이 걸리도록 만든다\n' ...
        '   정지 시간은 60 인데 15초에 멈추는지 확인']), 40, 470);
    finish(m);
end

% =====================================================================
% K. SB11 — 조건부 실행 서브시스템
% =====================================================================
function build_SB11_done()
    m = 'SB11_enabled_done'; fresh(m);

    B(m,'simulink/Sources/Constant','One',[40 60 90 90],'Value','1');
    B(m,'simulink/Sources/Pulse Generator','Pulse',[40 160 90 210], ...
      'Period','4','PulseWidth','50','SampleTime','0.05');

    add_block('simulink/Ports & Subsystems/Enabled Subsystem', [m '/EnSub'], ...
              'Position',[220 40 320 130]);
    fillAccumulator(m, 'EnSub');

    add_block('simulink/Ports & Subsystems/Triggered Subsystem', [m '/TrigSub'], ...
              'Position',[220 230 320 320]);
    fillAccumulator(m, 'TrigSub');

    B(m,'simulink/Sinks/Scope','Sc',[430 130 470 200]);
    set_param([m '/Sc'],'NumInputPorts','3');

    wire(m,'One/1','EnSub/1');
    wire(m,'Pulse/1','EnSub/enable');
    wire(m,'One/1','TrigSub/1');
    wire(m,'Pulse/1','TrigSub/Trigger');
    wire(m,'EnSub/1','Sc/1');
    wire(m,'TrigSub/1','Sc/2');
    wire(m,'Pulse/1','Sc/3');

    setSolverD(m,'20');
    note(m, sprintf(['[K] 조건부 실행 서브시스템\n' ...
        '두 서브시스템 안에는 똑같은 누적기가 들어 있다 (Unit Delay + Sum)\n' ...
        'Enabled : enable 이 1 인 동안 **매 스텝** 돈다.  0 이면 값을 그대로 유지\n' ...
        'Triggered: 신호가 **올라가는 순간에만 한 번** 돈다\n' ...
        '  -> Enabled 는 계단처럼 쭉쭉 오르고, Triggered 는 한 칸씩만 오른다\n' ...
        '6주차의 ROS Subscribe 는 IsNew 를 enable 로 쓰면 딱 이 구조가 된다\n' ...
        '  "새 메시지가 왔을 때만 계산한다"']), 40, 400);
    finish(m);
end

function build_SB11_todo()
    m = 'SB11_enabled_todo'; fresh(m);
    B(m,'simulink/Sources/Constant','One',[40 60 90 90],'Value','1');
    B(m,'simulink/Sources/Pulse Generator','Pulse',[40 160 90 210], ...
      'Period','4','PulseWidth','50','SampleTime','0.05');
    B(m,'simulink/Sinks/Scope','Sc',[430 130 470 200]);
    setSolverD(m,'20');
    note(m, sprintf(['[K] 할 일\n' ...
        '1. Ports & Subsystems 에서 Enabled Subsystem 을 가져온다\n' ...
        '2. 안을 열어 In1 -> Sum(++) -> Unit Delay 되먹임 -> Out1 누적기를 만든다\n' ...
        '3. Pulse Generator 를 enable 포트에 연결\n' ...
        '4. 같은 누적기를 넣은 Triggered Subsystem 을 하나 더 만든다\n' ...
        '5. Scope 에 두 출력과 Pulse 를 함께 넣고 차이를 관찰한다\n' ...
        '   무엇이 다른가? 왜 그런가?\n' ...
        '6. Enabled Subsystem 의 Outport 를 열어 "Output when disabled" 를\n' ...
        '   held <-> reset 으로 바꿔 보고 차이를 적는다']), 40, 300);
    finish(m);
end

function fillAccumulator(m, sub)
% 서브시스템 안의 In1 -> Out1 직결을 지우고 누적기를 넣는다
    p = [m '/' sub];
    ln = find_system(p,'SearchDepth',1,'FindAll','on','Type','line');
    for i = numel(ln):-1:1, try, delete_line(ln(i)); catch, end, end

    add_block('simulink/Math Operations/Sum', [p '/SumA'], ...
              'Inputs','++','Position',[160 60 190 100]);
    add_block('simulink/Discrete/Unit Delay', [p '/UD'], ...
              'SampleTime','-1','Position',[160 160 200 200]);
    set_param([p '/In1'], 'Position',[40 65 70 95]);
    set_param([p '/Out1'],'Position',[300 65 330 95]);
    add_line(p,'In1/1','SumA/1','autorouting','on');
    add_line(p,'SumA/1','UD/1','autorouting','on');
    add_line(p,'UD/1','SumA/2','autorouting','on');
    add_line(p,'SumA/1','Out1/1','autorouting','on');
end

% =====================================================================
% L. SB12 — 재사용 (마스크)
% =====================================================================
function build_SB12_done()
    m = 'SB12_reuse_done'; fresh(m);

    B(m,'simulink/Sources/Step','Step',[40 120 90 170],'Time','1','After','1');
    makeLagSubsystem(m, 'Lag_fast', '0.1', [220 60 320 120]);
    makeLagSubsystem(m, 'Lag_slow', '1.0', [220 200 320 260]);
    B(m,'simulink/Sinks/Scope','Sc',[430 120 470 190]);
    set_param([m '/Sc'],'NumInputPorts','3');

    wire(m,'Step/1','Lag_fast/1');
    wire(m,'Step/1','Lag_slow/1');
    wire(m,'Lag_fast/1','Sc/1');
    wire(m,'Lag_slow/1','Sc/2');
    wire(m,'Step/1','Sc/3');

    setSolverC(m,'6');
    note(m, sprintf(['[L] 마스크로 재사용하기\n' ...
        '같은 서브시스템 두 개가 tau 만 다르게 들어 있다 (0.1 s / 1.0 s)\n' ...
        '블록을 더블클릭하면 **다이얼로그 상자**가 뜬다. 안을 열지 않아도 값을 바꿀 수 있다\n' ...
        '  -> 마스크(Mask). Simulink 의 PID 블록도 이렇게 만들어져 있다\n' ...
        '마스크를 보려면 우클릭 -> Mask -> Edit Mask\n' ...
        '안을 보려면 우클릭 -> Mask -> Look Under Mask\n' ...
        '이 수업의 모든 모델은 build_wXX_models.m 이 코드로 만든다.\n' ...
        '마스크도 Simulink.Mask.create 로 코드에서 만들 수 있다']), 40, 340);
    finish(m);
end

function build_SB12_todo()
    m = 'SB12_reuse_todo'; fresh(m);
    B(m,'simulink/Sources/Step','Step',[40 120 90 170],'Time','1','After','1');
    B(m,'simulink/Sinks/Scope','Sc',[430 120 470 190]);
    setSolverC(m,'6');
    note(m, sprintf(['[L] 할 일\n' ...
        '1. Sum(+-) -> Gain(1/tau) -> Integrator -> 되먹임 으로 1차 지연을 만든다\n' ...
        '2. 그 블록들을 모두 선택하고 우클릭 -> Create Subsystem from Selection\n' ...
        '3. 서브시스템 우클릭 -> Mask -> Create Mask\n' ...
        '   Parameters 탭에서 Name=tau, Prompt=시상수 [s], Value=0.3 추가\n' ...
        '4. 안의 Gain 을 1/tau 로 바꾼다 (마스크 변수를 그대로 쓴다)\n' ...
        '5. 블록을 복사해 두 개로 만들고 tau 를 0.1 과 1.0 으로 각각 설정\n' ...
        '6. Step 을 두 블록에 넣고 Scope 로 겹쳐 본다\n' ...
        '7. Icon 탭에 disp(sprintf(''1/(%%gs+1)'',tau)) 를 넣어 아이콘에 식이 뜨게 한다']), ...
        40, 260);
    finish(m);
end

function makeLagSubsystem(m, name, tauVal, pos)
% 1차 지연 서브시스템을 만들고 마스크를 씌운다
    p = [m '/' name];
    add_block('built-in/Subsystem', p, 'Position', pos);

    add_block('simulink/Ports & Subsystems/In1',  [p '/u'],  'Position',[40 90 70 120]);
    add_block('simulink/Math Operations/Sum',     [p '/Sm'], 'Inputs','+-', ...
              'Position',[140 85 170 125]);
    add_block('simulink/Math Operations/Gain',    [p '/Gi'], 'Gain','1/tau', ...
              'Position',[230 90 270 120]);
    add_block('simulink/Continuous/Integrator',   [p '/It'], 'Position',[330 85 370 125]);
    add_block('simulink/Ports & Subsystems/Out1', [p '/y'],  'Position',[440 90 470 120]);

    add_line(p,'u/1','Sm/1','autorouting','on');
    add_line(p,'Sm/1','Gi/1','autorouting','on');
    add_line(p,'Gi/1','It/1','autorouting','on');
    add_line(p,'It/1','y/1','autorouting','on');
    add_line(p,'It/1','Sm/2','autorouting','on');

    mk = Simulink.Mask.create(p);
    mk.addParameter('Name','tau','Prompt','시상수 tau [s]','Value',tauVal);
    mk.Display = 'disp(sprintf(''1/(%gs+1)'', tau))';
    mk.Description = ['1차 지연.  dy/dt = (u - y)/tau' newline ...
                      '7주차 모터 응답 모델과 같은 식이다.'];
end
