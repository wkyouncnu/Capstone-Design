function build_w09_seam_demo()
% BUILD_W09_SEAM_DEMO  "명령의 나이" 가 왜 안전장치인가 — 가제보 없이 보는 작은 모델
%
%     W09_0_seam_demo.slx   ROS 도 가제보도 필요 없다. 20 초짜리다.
%
%   장면 (전부 가짜 신호로 만든다)
%     t = 0 ~ 3 s   평상 주행. LOS 가 0 도(정북)를 가리킨다
%     t = 3 s       기둥을 만나 회피가 켜진다. 파이썬이 oa_flag = 1, psi_oa = -30 도를 낸다
%     t = 5 s       **파이썬 노드가 죽는다.** 메시지가 더 오지 않는다 (IsNew = 0)
%                   Subscribe 블록은 마지막 값을 그대로 들고 있다 — oa_flag = 1, psi_oa = -30 도
%
%   같은 장면을 이음새 둘에 넣는다
%     A  감시 없음   판단 = oa_flag                       (스위치만 있다)
%     B  감시 있음   판단 = oa_flag AND (Age < oa_timeout) (9주차 AvoidSeam 과 같은 블록 · 같은 배치)
%
%   배는 가장 단순한 것으로 둔다 — 헤딩이 명령을 1차 지연(T = 2 s)으로 따라가고
%   속력 1.5 m/s 로 간다. 옆으로 밀린 거리 y 가 "그래서 배가 어디로 갔는가" 다.
%
%   선은 짧게 긋고, 멀리 가는 신호는 태그(Goto/From)로 보낸다 — 9주차 본 모델과 같은 규칙이다.
%
%   >> W09_seam_demo        % 이 모델을 만들고(없으면) 돌려 Scope 와 그림을 띄운다

here = fileparts(mfilename('fullpath'));
m = 'W09_0_seam_demo';
try, close_system(m, 0); catch, end
f = fullfile(here, [m '.slx']);
if isfile(f), delete(f); end
new_system(m);
set_param(m, 'Solver','FixedStepDiscrete', 'FixedStep','0.05', 'StopTime','20', ...
             'SaveFormat','Dataset', 'ReturnWorkspaceOutputs','on');

% ---- 색 (볼트 규칙) ---------------------------------------------------
cSet  = 'white';                    % 설정값 · 가짜 신호
cRos  = '[0.87 0.83 0.95]';         % ROS 통신 자리 (여기서는 가짜 신호가 대신한다)
cGuid = '[0.80 0.88 0.97]';         % 유도 — 파랑
cPlant= '[0.80 0.93 0.80]';         % 운동모델 — 초록
cLog  = '[0.90 0.90 0.90]';         % 로깅 · 표시 — 회색
Ts = '0.05';
B  = @(lib, name, pos, varargin) add_block(lib, [m '/' name], 'Position', pos, varargin{:});
L  = @(a, b) add_line(m, a, b, 'autorouting', 'smart');

% ================= 1) 감시 — AvoidSeam 의 아래 절반과 같은 배치 =========
%  가짜 토픽 : /vfh/oa_flag 의 data (3 s 에 서고, 노드가 죽은 뒤에도 1 로 남는다)
B('simulink/Sources/Step', 'oa_flag', [ 60  60 120 100], 'Time','3', 'Before','0', 'After','1', ...
  'SampleTime',Ts, 'BackgroundColor',cRos);
%  가짜 IsNew : /vfh/command 가 그 스텝에 새로 왔는가 (5 s 에 노드가 죽어 0 이 된다)
B('simulink/Sources/Step', 'IsNew',   [ 60 250 120 290], 'Time','5', 'Before','1', 'After','0', ...
  'SampleTime',Ts, 'BackgroundColor',cRos);
B('simulink/Sources/Constant', 'One', [220 155 280 185], 'Value','1', 'SampleTime',Ts, ...
  'BackgroundColor',cSet);
B('simulink/Discrete/Discrete-Time Integrator', 'Age', [380 140 470 300], ...
  'IntegratorMethod','Integration: Forward Euler', 'SampleTime',Ts, ...
  'ExternalReset','level', 'InitialCondition','0', 'BackgroundColor',cGuid);
B('simulink/Sources/Constant', 'TimeOut', [380 345 470 375], 'Value','0.5', 'SampleTime',Ts, ...
  'BackgroundColor',cSet);
B('simulink/Logic and Bit Operations/Relational Operator', 'Fresh', [550 190 600 250], ...
  'Operator','<', 'BackgroundColor',cGuid);
B('simulink/Logic and Bit Operations/Logical Operator', 'Take', [700 50 750 130], ...
  'Operator','AND', 'Inputs','2', 'BackgroundColor',cGuid);
B('simulink/Signal Attributes/Data Type Conversion', 'ToD', [820 70 890 110], ...
  'OutDataTypeStr','double', 'BackgroundColor',cGuid);

L('oa_flag/1','Take/1');
L('One/1','Age/1');     L('IsNew/1','Age/2');
L('Age/1','Fresh/1');   L('TimeOut/1','Fresh/2');
L('Fresh/1','Take/2');
L('Take/1','ToD/1');

go('oa_flag/1', 'flag',  [180 115 250 135]);
go('IsNew/1',   'isnew', [180 305 250 325]);
go('Age/1',     'age',   [550 280 620 300]);
go('ToD/1',     'oa',    [960  80 1030 100]);

% ================= 2) 가짜 헤딩 명령 둘 ================================
B('simulink/Sources/Step', 'psi_oa',  [ 60 470 120 510], 'Time','3', 'Before','0', 'After','-30', ...
  'SampleTime',Ts, 'BackgroundColor',cRos);        % 회피 방위각 [deg] — 죽은 뒤에는 낡은 값
B('simulink/Sources/Constant', 'psi_los', [ 60 560 120 600], 'Value','0', ...
  'SampleTime',Ts, 'BackgroundColor',cSet);        % LOS 방위각 [deg] — 정북
go('psi_oa/1',  'psi_oa',  [180 480 260 500]);
go('psi_los/1', 'psi_los', [180 570 260 590]);

% ================= 3) 이음새 둘 + 배 둘 =================================
seam('A', 'flag', 440);      % A — 감시 없음 : 깃발만 본다
seam('B', 'oa',   660);      % B — 감시 있음 : 깃발 AND 신선함

% ================= 4) Scope — 세 칸 ====================================
x0 = 1440;
B('simulink/Signal Routing/Mux', 'MuxSig', [x0+130  40 x0+136 180], 'Inputs','4');
B('simulink/Signal Routing/Mux', 'MuxPsi', [x0+130 230 x0+136 340], 'Inputs','3');
B('simulink/Signal Routing/Mux', 'MuxY',   [x0+130 390 x0+136 470], 'Inputs','2');
fr('isnew',   'MuxSig/1', [x0  47 x0+70  67], 'IsNew');
fr('flag',    'MuxSig/2', [x0  82 x0+70 102], 'oa_flag');
fr('age',     'MuxSig/3', [x0 117 x0+70 137], 'Age [s]');
fr('oa',      'MuxSig/4', [x0 152 x0+70 172], 'oa');
fr('psi_los', 'MuxPsi/1', [x0 238 x0+70 258], 'psi_los');
fr('refA',    'MuxPsi/2', [x0 275 x0+70 295], 'psi_ref A (no watchdog)');
fr('refB',    'MuxPsi/3', [x0 312 x0+70 332], 'psi_ref B (watchdog)');
fr('yA',      'MuxY/1',   [x0 400 x0+70 420], 'y A (no watchdog) [m]');
fr('yB',      'MuxY/2',   [x0 440 x0+70 460], 'y B (watchdog) [m]');

B('simulink/Sinks/Scope', 'Scope', [x0+330 200 x0+400 320], 'NumInputPorts','3', ...
  'BackgroundColor',cLog);
L('MuxSig/1','Scope/1'); L('MuxPsi/1','Scope/2'); L('MuxY/1','Scope/3');
cfg = get_param([m '/Scope'], 'ScopeConfiguration');
cfg.LayoutDimensions = [3 1];
cfg.ShowLegend = true;
cfg.OpenAtSimulationStart = true;
cfg.Position = [80 80 900 760];

% ================= 5) 로그 (그림 스크립트가 쓴다) ======================
tw('MuxSig', 'seam_sig', [x0+330  95 x0+420 125]);
tw('MuxPsi', 'seam_psi', [x0+330 360 x0+420 390]);
tw('MuxY',   'seam_y',   [x0+330 415 x0+420 445]);

add_block('built-in/Note', [m '/note'], 'Position', [60 860], 'Text', sprintf([ ...
    '명령의 나이가 왜 안전장치인가 — 5 s 에 파이썬이 죽는 장면\n' ...
    '\n' ...
    '  IsNew    메시지가 오는 동안 1, 끊기면 0 (본 모델에서는 /vfh/command Subscribe 의 1번 출력)\n' ...
    '  oa_flag  3 s 에 서고, 노드가 죽은 뒤에도 마지막 값 1 로 남는다\n' ...
    '  psi_oa   -30 도. 죽은 뒤에는 낡은 값이다\n' ...
    '\n' ...
    '  A (감시 없음)  판단 = oa_flag                    -> 낡은 -30 도를 영원히 따라간다\n' ...
    '  B (감시 있음)  판단 = oa_flag AND (Age < 0.5)    -> 0.55 s 뒤 LOS(0 도)로 되돌아간다\n' ...
    '\n' ...
    '배는 헤딩 1차 지연(T = 2 s) + 속력 1.5 m/s.  y 는 경로(정북)에서 옆으로 밀린 거리다.\n' ...
    '실행:  >> W09_seam_demo']));

save_system(m, f);
close_system(m, 0);
fprintf('  %s      생성\n', m);

    % ------------------------------------------------------------------
    function seam(tag, judge, y)
        %  스위치 하나 — 위 = 회피, 가운데 = 판단, 아래 = LOS.  그 뒤에 배
        B('simulink/Signal Routing/Switch', ['Pick_' tag], [560 y 610 y+120], ...
          'Criteria','u2 >= Threshold', 'Threshold','0.5', 'BackgroundColor',cGuid);
        fr('psi_oa',  ['Pick_' tag '/1'], [400 y+10 480 y+30], '');
        fr(judge,     ['Pick_' tag '/2'], [400 y+50 480 y+70], '');
        fr('psi_los', ['Pick_' tag '/3'], [400 y+90 480 y+110], '');
        x = 700;
        %  헤딩 :  psi[k+1] = psi[k] + Ts*(psi_ref - psi)/T      옆밀림 : y[k+1] = y[k] + Ts*U*sin(psi)
        B('simulink/Math Operations/Sum', ['Err_' tag], [x y+45 x+30 y+75], ...
          'Inputs','|+-', 'IconShape','round', 'BackgroundColor',cPlant);
        B('simulink/Math Operations/Gain', ['invT_' tag], [x+70 y+40 x+130 y+80], ...
          'Gain','1/2', 'BackgroundColor',cPlant);
        B('simulink/Discrete/Discrete-Time Integrator', ['Psi_' tag], [x+170 y+30 x+240 y+90], ...
          'IntegratorMethod','Integration: Forward Euler', 'SampleTime',Ts, ...
          'InitialCondition','0', 'BackgroundColor',cPlant);
        B('simulink/User-Defined Functions/Fcn', ['Vy_' tag], [x+300 y+40 x+420 y+80], ...
          'Expr','1.5*sin(u*pi/180)', 'BackgroundColor',cPlant);
        B('simulink/Discrete/Discrete-Time Integrator', ['Y_' tag], [x+460 y+30 x+530 y+90], ...
          'IntegratorMethod','Integration: Forward Euler', 'SampleTime',Ts, ...
          'InitialCondition','0', 'BackgroundColor',cPlant);
        L(['Pick_' tag '/1'], ['Err_' tag '/1']);
        L(['Err_' tag '/1'],  ['invT_' tag '/1']);
        L(['invT_' tag '/1'], ['Psi_' tag '/1']);
        L(['Psi_' tag '/1'],  ['Vy_' tag '/1']);
        L(['Psi_' tag '/1'],  ['Err_' tag '/2']);
        L(['Vy_' tag '/1'],   ['Y_' tag '/1']);
        go(['Pick_' tag '/1'], ['ref' tag], [640 y-30 710 y-10]);
        go(['Y_' tag '/1'],    ['y' tag],   [x+570 y+50 x+640 y+70]);
    end
    function go(src, tag, pos)
        add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], 'GotoTag', tag, 'Position', pos);
        add_line(m, src, ['Go_' tag '/1'], 'autorouting','smart');
    end
    function fr(tag, dst, pos, name)
        n = 1; while ~isempty(find_system(m,'SearchDepth',1,'Name',sprintf('Fr_%s_%d',tag,n))), n = n+1; end
        b = sprintf('Fr_%s_%d', tag, n);
        add_block('simulink/Signal Routing/From', [m '/' b], 'GotoTag', tag, 'Position', pos, ...
                  'ShowName','off');
        h = add_line(m, [b '/1'], dst, 'autorouting','smart');
        %  신호선 이름 = Scope 범례. 한글은 Scope 범례에서 깨질 수 있어 영문으로 둔다
        if ~isempty(name), set_param(h, 'Name', name); end
    end
    function tw(src, var, pos)
        add_block('simulink/Sinks/To Workspace', [m '/' var], 'Position', pos, ...
                  'VariableName', var, 'SaveFormat','Timeseries', 'BackgroundColor',cLog);
        add_line(m, [src '/1'], [var '/1'], 'autorouting','smart');
    end
end
