function build_w05_models()
% BUILD_W05_MODELS  5주차 Simulink 모델 2개를 생성한다.
%
%     W05_0_offline.slx   오프라인 WAM-V — Gazebo 없이 돈다. 조류 실험용
%     W05_1_vrx.slx       VRX 연동 — 운동모델만 Gazebo 로 바뀐다
%
%   실제 GNC 루프 순서대로 왼쪽에서 오른쪽으로 배치된다.
%
%   Guidance → Inner Loop → Thrusters → 운동모델 → Navigation
%   (유도)      (헤딩 P-D +   (프로펠러   (플랜트)    (상태 산출)
%               속도 PI +      + 모터)
%               추력배분)
%       ↑            ↑                                    |
%       └── Goto/From 태그로 되먹임 ─────────────────────────┘
%
%   구조는 MSS 툴박스의 demoOtterUSVHeadingControl.slx 와 GNC/LOSchi.m 을 따른다.
%     - 유도는 psi_ref (선수각) 를 낸다.  침로각이 아니다
%     - 헤딩 제어는 P-D 요각속도 되먹임:  tau_N = Kp*ssa(psi_ref-psi) - Kd*r
%       오차를 미분하지 않으므로 웨이포인트 전환 때 미분 킥이 없다
%     - 속도 제어는 u (surge velocity) 되먹임.  U = sqrt(u^2+v^2) 가 아니다
%
%   두 모델은 유도부·내부루프·게인이 전부 같다. 다른 것은 두 가지뿐이다.
%     1) 운동모델 : MATLAB Function (VRX 와 같은 계수)  vs  Gazebo 실물
%     2) 조류     : 오프라인만 가능. VRX 에는 해류 플러그인이 없다
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 복구된다.
%   실행 전에 반드시 >> W05_setup 을 먼저 실행할 것.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''wp_north'',''var'')')
        error('먼저 W05_setup 을 실행하십시오.');
    end

    build_offline();
    build_vrx();
    build_idx_memory();     % 실습 F — 웨이포인트 번호의 기억 (persistent vs Unit Delay)

    % 최상위 배치 — autorouting 에 맡기지 않고 규칙대로 직접 놓는다.
    % 겹침·블록관통 0, 꺾임 1회가 합격선이다 (references/line-routing.md)
    chain = {'Guidance','InnerLoop','Thrusters','MotionModel'};
    %  Wrap — 사슬을 몇 칸에서 접을지. 도면이 정사각형에 가까울수록 같은 픽셀 안에
    %  크게 보인다. 값은 주차마다 재서 골랐다 (겹침 0 이 되는 것 중 가장 작은 쪽)
    %  Wrap 3 — VRX 쌍둥이와 같은 자리에서 줄을 바꾼다. 그 자리의 연결은 빌더가
    %  이미 FL·FR 태그로 받아 두었으므로 lay_chain 이 새 태그를 만들 일이 없다
    %  Observe(Scope) 와 AutoStop 도 **포트 없는 상자**라 Boxes 에 적는다.
    %  적지 않으면 lay_chain 이 그 자리를 모르고 다른 블록을 겹쳐 놓는다
    lay_chain('W05_0_offline', chain, 'Boxes', {'Animate','Logging','Observe','AutoStop'}, 'Wrap', 3);
    lay_chain('W05_1_vrx', {'Guidance','InnerLoop','Thrusters','CmdPublisher','PoseSubscriber'}, ...
              'Boxes', {'Animate','Logging','Observe','AutoStop'}, 'Wrap', 3);
    %  색 — 역할표는 _tools/gnc_roles.m 하나뿐이다. 빌더는 부르기만 한다
    for mm = {'W05_0_offline','W05_1_vrx'}
        m = mm{1}; load_system(m);
        paint_roles(m);
        check_colour(m);
        mss_style(m); save_system(m); close_system(m, 0);
        %  선 정리 — 포트가 늘면 전에 비어 있던 통로가 막힌다. 지적 0 까지
        settle_links(m);
        %  태그를 신호 옆으로 — lay_chain 은 Goto 를 내는 블록 **아래**에 쌓는다.
        %  그러면 잇는 선이 통로로 내려가며 두 번 꺾인다. 마지막에 한 번 끌어오면
        %  수평 한 토막이 된다 (2026-10-01 교수 지시, line-routing.md §3).
        %  tidy_model 을 쓰는 주차는 그것이 안에서 두 번 부른다. 이 주차는 직접 부른다
        load_system(m); snug_tags(m);
        %  snug_tags 가 태그를 끌어올린 **뒤에** 포트 없는 상자를 사슬 바로 아래로
        %  당긴다. lay_chain 이 잡아 둔 태그 더미 깊이가 그대로 빈 칸이 되기 때문이다
        %  (교수 지시 2026-10-01 — 빈 공간을 남기지 않는다)
        pack_boxes(m, {'Animate','Logging','Observe','AutoStop'});
        save_system(m);
        check_lines(m, false); export_diagram(m);
        close_system(m, 0);
    end

    %  실습 F 모델은 사슬 구조가 아니라 tidy_model 이 안에서 다 했다. 그림만 뽑는다
    load_system('W05_2_idx_memory');
    check_lines('W05_2_idx_memory', false);
    export_diagram('W05_2_idx_memory');
    close_system('W05_2_idx_memory', 0);

    %  강의노트가 쓰는 서브시스템 도면 (img/Guidance.png 등). 모델과 함께 다시 뽑는다
    for nm = {'Guidance','InnerLoop','MotionModel','Thrusters'}
        f = export_diagram('W05_0_offline', '', nm{1});
        movefile(f, fullfile(here, 'img', [nm{1} '.png']), 'f');
    end
    fprintf('\n완료. 생성된 모델:\n');
    d = dir('W05_*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
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
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime',stopTime, 'SimulationMode','normal');
end

function setFcn(sys, path, code)
    S  = sfroot;
    fpos = get_param([sys '/' path], 'Position');   % 포트가 생기며 블록이 멋대로 자란다
    ch = S.find('-isa','Stateflow.EMChart','Path',[sys '/' path]);
    ch.Script = code;
    set_param([sys '/' path], 'Position', fpos);    % 다시 놓아야 포트 위치가 저장 뒤와 같아진다 (사선 방지)
end

function C(m, name, value, x, y)
    add_block('simulink/Sources/Constant', [m '/' name], ...
              'Position', [x y x+95 y+30], 'Value', value);
end

function note(m, tag, txt, x, y)
    add_block('built-in/Note', [m '/' tag], 'Position',[x y x y], 'Text', txt);
end

% =====================================================================
% 1단 · GUIDANCE
% =====================================================================
function addGuidance(m, x, y)
% 1단 · GUIDANCE — 서브시스템 하나. 웨이포인트와 설정은 **상자 안에** 둔다.
%
%   포트   x_n, y_n  ->  psi_ref, y_e, x_e, gate
%
%   웨이포인트 배열·Delta·R·mode 는 신호가 아니라 **설정**이다. 최상위에 늘어놓으면
%   상수 여섯 개와 선 여섯 개가 신호 사슬 앞을 가린다. 상자 안에 넣으면 최상위는
%   "위치를 받아 목표 선수각을 낸다" 는 사실만 보여 준다.
%
%   웨이포인트 인덱스 되먹임(IdxDly)도 안에 있다. 유도부 **내부의 기억**이지
%   모델의 되먹임이 아니기 때문이다.
    %  wp_idx 도 **밖으로 낸다** (교수 지시 2026-10-02 — "scope 에 waypoint k
    %  index 도"). 안쪽 되먹임용 태그는 로컬이라 최상위 Scope 가 받을 수 없다.
    %  지금 몇 번째 구간을 달리는지는 그래프를 읽을 때 가장 먼저 찾는 값이다 —
    %  y_e 가 튀는 순간이 구간이 바뀐 자리인지 아닌지가 그것으로 갈린다
    ss = add_subsys(m, 'Guidance', [x y x+190 y+150], {'x_n','y_n'}, ...
                    {'psi_ref','y_e','x_e','gate','wp_idx'}, gnc_colour('guidance'));

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/GuidanceLaw'], 'Position', [320 60 500 560]);
    setFcn(ss, 'GuidanceLaw', [ ...
'function [psi_ref, y_e, x_e, wp_idx, gate] = GuidanceLaw(x_n, y_n, wp_x, wp_y, Delta, R, mode, sw_mode, idx_prev)' newline ...
'%#codegen'                                                                     newline ...
'% Waypoint guidance. Two laws in one block. Both return a HEADING command,'    newline ...
'% following the MSS demo demoOtterUSVHeadingControl.slx and GNC/LOSchi.m.'         newline ...
'%   mode 1 = atan2 : aim straight at the next waypoint (point chasing)'        newline ...
'%   mode 2 = LOS   : follow the straight line between two waypoints'           newline ...
'% Switching criterion (sw_mode):'                                              newline ...
'%   1 = along-track : d - x_e < R      (MSS / Fossen default, cannot hang)'    newline ...
'%   2 = circle      : distance to the next waypoint <= R'                      newline ...
''                                                                              newline ...
'n = numel(wp_x);'                                                              newline ...
'k = min(max(idx_prev, 1), n-1);        % index of the active leg'              newline ...
''                                                                              newline ...
'xk  = wp_x(k);    yk  = wp_y(k);       % leg start'                            newline ...
'xk1 = wp_x(k+1);  yk1 = wp_y(k+1);     % leg end = next waypoint'              newline ...
''                                                                              newline ...
'% path-tangential angle of the active leg, measured from North'                newline ...
'pi_p = atan2(yk1 - yk, xk1 - xk);'                                             newline ...
''                                                                              newline ...
'% Both errors come out of ONE rotation of (p - p_k) into the path frame.'      newline ...
'% x_e = how far ALONG the leg,  y_e = how far TO THE SIDE of it.'              newline ...
'% Computed the same way for BOTH guidance laws so that the two can be'         newline ...
'% compared with the same yardstick.'                                           newline ...
'x_e =  (x_n - xk)*cos(pi_p) + (y_n - yk)*sin(pi_p);'                             newline ...
'y_e = -(x_n - xk)*sin(pi_p) + (y_n - yk)*cos(pi_p);'                             newline ...
''                                                                              newline ...
'if mode == 1'                                                                  newline ...
'    psi_ref = atan2(yk1 - y_n, xk1 - x_n);'                                      newline ...
'else'                                                                          newline ...
'    psi_ref = pi_p - atan(y_e / Delta);'                                       newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'% --- waypoint switching ---------------------------------------------'        newline ...
'% d is the leg length, so d - x_e is the along-track distance REMAINING.'      newline ...
'% The circle test is always the stricter of the two, because'                  newline ...
'%     distance = sqrt((d - x_e)^2 + y_e^2) >= d - x_e'                         newline ...
'% A boat blown wide of a waypoint never enters that circle, and a mission'     newline ...
'% that waits for it waits for ever. The along-track test cannot hang.'         newline ...
'd = sqrt((xk1 - xk)^2 + (yk1 - yk)^2);'                                        newline ...
'if sw_mode == 1'                                                               newline ...
'    reached = (d - x_e) < R;'                                                  newline ...
'else'                                                                          newline ...
'    reached = sqrt((xk1 - x_n)^2 + (yk1 - y_n)^2) <= R;'                         newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'% wp_idx = n means "mission finished" and it LATCHES: once the last leg is'   newline ...
'% done, the boat stays stopped even if the current pushes it back behind the' newline ...
'% finish line (then reached would turn false again).'                         newline ...
'if idx_prev >= n'                                                              newline ...
'    wp_idx = n;                         % already finished - stay finished'    newline ...
'elseif reached && (k < n-1)'                                                   newline ...
'    wp_idx = k + 1;'                                                           newline ...
'elseif reached && (k == n-1)'                                                  newline ...
'    wp_idx = n;                         % last leg done'                       newline ...
'else'                                                                          newline ...
'    wp_idx = k;'                                                               newline ...
'end'                                                                           newline ...
''                                                                              newline ...
'% gate = 0 brings the boat to a stop. Without it the boat would follow the'   newline ...
'% last leg forever.'                                                           newline ...
'gate = double(wp_idx < n);']);

    % 설정값 — 신호가 아니다. row_feed 가 각자 포트 높이로 옮겨 붙인다
    cfg = {'wp_x','wp_north'; 'wp_y','wp_east'; 'Delta','Delta'; ...
           'R','R_LOS'; 'mode','guidance_mode'; 'sw_mode','sw_mode'};
    for k = 1:size(cfg,1)
        add_block('simulink/Sources/Constant', [ss '/' cfg{k,1}], ...
                  'Position', [130 100+(k-1)*60 205 100+(k-1)*60+30], 'Value', cfg{k,2});
    end
    set_param([ss '/x_n'], 'Position', [160 100 190 114]);
    set_param([ss '/y_n'], 'Position', [160 160 190 174]);
    row_feed(ss, 'GuidanceLaw', {'x_n','y_n','wp_x','wp_y','Delta','R','mode','sw_mode',''});

    % --- 9번 입력: 한 스텝 전의 웨이포인트 인덱스 ------------------------
    q = port_xy(ss, 'GuidanceLaw', 'Inport', 9);
    add_block('simulink/Discrete/Unit Delay', [ss '/IdxDly'], ...
              'Position', [230 q(2)-20 300 q(2)+20], ...
              'InitialCondition','1', 'SampleTime','Ts_ctrl');
    set_param([ss '/IdxDly'], 'Description', ...
        ['대수 루프 차단 + 사건 계수기 — 웨이포인트 번호는 정수이고, 유도부가 낸 값이 유도부로 되돌아온다. 미분방정식의 상태가 아니다.']);
    %  안쪽 되먹임 태그는 `wp_idx_prev` 다. 최상위에도 `wp_idx` Goto 가 생겼으므로
    %  (Scope·로깅이 받는다) 같은 이름을 쓰면 Simulink 가 태그 충돌로 막는다.
    %  이름이 뜻도 더 맞다 — IdxDly 로 들어가는 것은 **한 스텝 전의** 번호다
    add_block('simulink/Signal Routing/From', [ss '/Fr_wp_idx_prev'], ...
              'Position', [130 q(2)-11 200 q(2)+11], 'GotoTag','wp_idx_prev');
    add_line(ss, 'Fr_wp_idx_prev/1', 'IdxDly/1');      % 직선
    add_line(ss, 'IdxDly/1', 'GuidanceLaw/9');    % 직선

    % --- 출력: 다섯 개를 포트로 ----------------------------------------
    outs = {'psi_ref',1; 'y_e',2; 'x_e',3; 'gate',5; 'wp_idx',4};
    for k = 1:size(outs,1)
        q = port_xy(ss, 'GuidanceLaw', 'Outport', outs{k,2});
        set_param([ss '/' outs{k,1}], 'Position', [700 q(2)-7 730 q(2)+7]);
        add_line(ss, sprintf('GuidanceLaw/%d', outs{k,2}), [outs{k,1} '/1']);
    end

    %  인덱스는 **안쪽 되먹임에도** 쓰인다. 포트로 나가는 그 선에서 갈라
    %  태그를 하나 떨어뜨리고, 위의 IdxDly 가 그것을 받는다 (태그는 로컬이다)
    drop_tag(ss, 'GuidanceLaw', 4, 'wp_idx_prev', 120);

    add_block('built-in/Note', [ss '/note'], 'Position', [130 700], 'Text', sprintf([ ...
        '유도 — 위치를 받아 목표 선수각을 낸다.\n' ...
        '  mode = 1  atan2 : 다음 웨이포인트를 곧장 겨눈다\n' ...
        '  mode = 2  LOS   : 두 웨이포인트를 잇는 직선을 따라간다\n' ...
        '\n' ...
        '전환 판정 sw_mode\n' ...
        '  1  경로 방향 : d - x_e < R   (MSS 기본값. 밀려나도 멈추지 않는다)\n' ...
        '  2  수락 원   : 다음 웨이포인트까지 직선거리 <= R\n' ...
        '\n' ...
        'wp_idx 는 밖으로 나가지 않는다. 지금 몇 번째 구간을 달리는지를\n' ...
        '유도부가 스스로 기억하는 값이라, 한 스텝 지연을 거쳐 자기에게 되돌아온다.\n' ...
        '이 지연이 없으면 대수 루프가 되어 모델이 컴파일되지 않는다.']));
end
% =====================================================================
% 2단 · INNER LOOP — 헤딩 P-D + 속도 PI + 추력배분
% =====================================================================
function addInnerLoop(m, x, y)
    ss = [m '/InnerLoop'];
    add_block('built-in/Subsystem', ss, 'Position', [x y x+190 y+170]);

    in = {'psi_ref','gate','psi','r','u'};
    for k = 1:numel(in)
        add_block('simulink/Sources/In1', [ss '/' in{k}], ...
                  'Position', [40 60+(k-1)*80 75 60+(k-1)*80+30], 'Port', num2str(k));
    end

    % 목표 속도는 신호가 아니라 설정이다. 상자 안에 둔다
    add_block('simulink/Sources/Constant', [ss '/u_ref'], ...
              'Position', [40 380 130 410], 'Value','u_ref');

    % ---------- 헤딩 제어 : tau_N = Kp*ssa(psi_ref - psi) - Kd*r ----------
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/HeadingErr'], 'Position', [200 60 340 130]);
    setFcn(ss, 'HeadingErr', [ ...
'function e = HeadingErr(psi_ref, psi)'                          newline ...
'%#codegen'                                                      newline ...
'% Shortest signed angle (ssa). Without it a command of 179 deg' newline ...
'% against a heading of -179 deg reads as a 358 deg error and'   newline ...
'% the boat turns the long way round.'                           newline ...
'd = psi_ref - psi;'                                             newline ...
'e = atan2(sin(d), cos(d));']);

    add_block('simulink/Math Operations/Gain', [ss '/Kp_psi'], ...
              'Position', [410 60 460 100], 'Gain','Kp_psi');

    %  D 항은 **요각속도 되먹임 하나**다 (교수 지시 2026-10-01).
    %
    %    tau_N = Kp_psi * ssa(psi_ref - psi)  -  Kd_psi * r
    %
    %  전에는 오차를 미분하는 갈래(`dedt`)와 둘 중 하나를 고르는 스위치(`Dsel`)가
    %  함께 있었다. 그 비교는 **4주차 2-8절**(`W04_heading_sign`)에서 이미 끝났으므로
    %  여기서는 결론만 쓴다 — 지령이 계단으로 바뀌어도 r 은 튀지 않는다.
    %
    %  게인은 **양수**이고 부호는 합산점에서 준다 (`SumN` 이 '+-'). 게인에
    %  마이너스를 숨기면 도면만 보고는 덧셈인지 뺄셈인지 알 수 없다.
    add_block('simulink/Math Operations/Gain', [ss '/Kd_rate'], ...
              'Position', [410 300 460 340], 'Gain','Kd_psi');

    add_block('simulink/Math Operations/Sum', [ss '/SumN'], ...
              'Position', [640 110 670 150], 'Inputs','+-');
    add_block('simulink/Discontinuities/Saturation', [ss '/SatN'], ...
              'Position', [720 110 760 150], ...
              'UpperLimit','2*F_max*half_beam', 'LowerLimit','-2*F_max*half_beam');

    add_line(ss,'psi_ref/1','HeadingErr/1','autorouting','on');
    add_line(ss,'psi/1',    'HeadingErr/2','autorouting','on');
    add_line(ss,'HeadingErr/1','Kp_psi/1','autorouting','on');
    add_line(ss,'r/1',        'Kd_rate/1','autorouting','on');
    add_line(ss,'Kp_psi/1', 'SumN/1','autorouting','on');
    add_line(ss,'Kd_rate/1','SumN/2','autorouting','on');
    add_line(ss,'SumN/1','SatN/1','autorouting','on');

    % ---------- 속도 제어 : u 되먹임 PI ----------
    add_block('simulink/Math Operations/Product', [ss '/Gate'], ...
              'Position', [200 380 235 420]);
    add_block('simulink/Math Operations/Sum', [ss '/SurgeErr'], ...
              'Position', [300 385 330 415], 'Inputs','+-');
    add_block('simulink/Continuous/PID Controller', [ss '/PI_u'], ...
              'Position', [400 370 490 430]);
    %  **연속 시간 PI** 다 (교수 지시 2026-10-01 — 제어기는 연속으로 적는다).
    %  적분기는 1/s 이고 안티와인드업은 clamping 이다. 전에는 같은 블록을
    %  Discrete-time 으로 두었는데, 그 근거로 적혀 있던 "VRX 라서 이산" 은
    %  이유가 아니었다 — 솔버를 ode4 로 바꾸면 같은 스텝으로 돈다 (4주차에서 확인).
    set_param([ss '/PI_u'], 'Controller','PI', ...
        'TimeDomain','Continuous-time', ...
        'P','Kp_u', 'I','Ki_u', ...
        'LimitOutput','on', ...
        'UpperSaturationLimit','2*F_max', 'LowerSaturationLimit','-2*F_max', ...
        'AntiWindupMode','clamping');

    add_line(ss,'u_ref/1','Gate/1','autorouting','on');
    add_line(ss,'gate/1', 'Gate/2','autorouting','on');
    add_line(ss,'Gate/1','SurgeErr/1','autorouting','on');
    add_line(ss,'u/1',   'SurgeErr/2','autorouting','on');
    add_line(ss,'SurgeErr/1','PI_u/1','autorouting','on');

    % ---------- 추력배분 ----------
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/Alloc'], 'Position', [730 230 880 340]);
    setFcn(ss, 'Alloc', [ ...
'function [FL, FR] = Alloc(X, N, half_beam, Fmax)'                newline ...
'%#codegen'                                                       newline ...
'% Differential thrust allocation for two aft thrusters.'         newline ...
'%   X = FL + FR              surge force [N]'                    newline ...
'%   N = (FL - FR)*half_beam  yaw moment  [N*m]'                  newline ...
'FL = X/2 + N/(2*half_beam);'                                     newline ...
'FR = X/2 - N/(2*half_beam);'                                     newline ...
'if FL >  Fmax, FL =  Fmax; end'                                  newline ...
'if FL < -Fmax, FL = -Fmax; end'                                  newline ...
'if FR >  Fmax, FR =  Fmax; end'                                  newline ...
'if FR < -Fmax, FR = -Fmax; end']);

    add_block('simulink/Sources/Constant', [ss '/HB'], ...
              'Position', [600 460 690 490], 'Value','half_beam');
    add_block('simulink/Sources/Constant', [ss '/FM'], ...
              'Position', [600 510 690 540], 'Value','F_max');

    add_block('simulink/Sinks/Out1', [ss '/FL'], 'Position',[960 250 995 280], 'Port','1');
    add_block('simulink/Sinks/Out1', [ss '/FR'], 'Position',[960 310 995 340], 'Port','2');

    add_line(ss,'PI_u/1','Alloc/1','autorouting','on');
    add_line(ss,'SatN/1','Alloc/2','autorouting','on');
    add_line(ss,'HB/1',  'Alloc/3','autorouting','on');
    add_line(ss,'FM/1',  'Alloc/4','autorouting','on');
    add_line(ss,'Alloc/1','FL/1','autorouting','on');
    add_line(ss,'Alloc/2','FR/1','autorouting','on');

    Simulink.BlockDiagram.arrangeSystem(ss);
end

% =====================================================================
% 3단 · THRUSTERS — 프로펠러 + 모터 모델
%   VRX 의 추진기 플러그인은 뉴턴을 받아 추력을 즉시 낸다.
%   실제 모터는 회전수 한계도 있고 응답 지연도 있다.
%   MSS otter.m 과 같은 프로펠러 법칙을 여기에 붙인다.
%
%     F_cmd -> n_cmd = sign(F)*sqrt(|F|/k) -> 포화 -> 1차 지연 -> n
%           -> F = k*n*|n|
%
%   같은 단을 두 모델에 똑같이 넣으므로 오프라인과 VRX 가 계속 일치한다.
% =====================================================================
function addThrusters(m, x, y)
    ss = [m '/Thrusters'];
    add_block('built-in/Subsystem', ss, 'Position', [x y x+170 y+120]);

    add_block('simulink/Sources/In1', [ss '/FL_cmd'], 'Position',[40 60 75 90],  'Port','1');
    add_block('simulink/Sources/In1', [ss '/FR_cmd'], 'Position',[40 140 75 170],'Port','2');

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/F2n'], 'Position', [170 70 320 266]);   % 포트 4개 — 52 px 간격 (52*3+40)
    setFcn(ss, 'F2n', [ ...
'function n_cmd = F2n(FL, FR, k, n_max)'                              newline ...
'%#codegen'                                                           newline ...
'% Inverse propeller law: turn a demanded thrust into a shaft speed.' newline ...
'%   F = k*n*|n|   ->   n = sign(F)*sqrt(|F|/k)'                      newline ...
'% Saturation happens on SPEED, not on force. That is what a real'    newline ...
'% motor limits.'                                                     newline ...
'F = [FL; FR];'                                                       newline ...
'n_cmd = zeros(2,1);'                                                 newline ...
'for i = 1:2'                                                         newline ...
'    ni = sign(F(i)) * sqrt(abs(F(i))/k);'                            newline ...
'    if ni >  n_max, ni =  n_max; end'                                newline ...
'    if ni < -n_max, ni = -n_max; end'                                newline ...
'    n_cmd(i) = ni;'                                                  newline ...
'end']);

    add_block('simulink/Sources/Constant', [ss '/Kp'], ...
              'Position',[40 250 130 280], 'Value','k_prop');
    add_block('simulink/Sources/Constant', [ss '/Nm'], ...
              'Position',[40 300 130 330], 'Value','n_max');

    %  모터 1차 지연 — **연속 시간**이다 (교수 지시 2026-10-01).
    %
    %      dn/dt = (n_cmd - n) / tau_n        <=>   n/n_cmd = 1/(tau_n*s + 1)
    %
    %  전에는 num(z)/den(z) 꼴의 Discrete Transfer Fcn 이었다. 연속 Transfer Fcn
    %  으로 바꾸려 했으나 **그 블록은 벡터 입력을 받지 않는다** — n 은 좌·우 두
    %  축의 2원소 신호다. 그래서 같은 1차 지연을 상태공간 한 블록으로 적는다.
    %  A = -I/tau_n, B = I/tau_n, C = I, D = 0 이 곧 위의 식이다 (대각이므로
    %  좌·우가 서로 섞이지 않는다). 시상수 tau_n 은 그대로고 구현만 바뀌었다.
    add_block('simulink/Continuous/State-Space', [ss '/MotorLag'], ...
              'Position',[380 85 500 145]);
    set_param([ss '/MotorLag'], 'A','-eye(2)/tau_n', 'B','eye(2)/tau_n', ...
              'C','eye(2)', 'D','zeros(2)', 'X0','zeros(2,1)');

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/n2F'], 'Position', [560 70 700 160]);
    setFcn(ss, 'n2F', [ ...
'function [FL, FR] = n2F(n, k)'                                  newline ...
'%#codegen'                                                      newline ...
'% Forward propeller law. Note the |n| : thrust is quadratic in' newline ...
'% shaft speed, so a rate limit on n is NOT a rate limit on F.'  newline ...
'FL = k * n(1) * abs(n(1));'                                     newline ...
'FR = k * n(2) * abs(n(2));']);

    add_block('simulink/Sinks/Out1', [ss '/FL'], 'Position',[780 70 815 100], 'Port','1');
    add_block('simulink/Sinks/Out1', [ss '/FR'], 'Position',[780 130 815 160],'Port','2');
    add_block('simulink/Sinks/Out1', [ss '/n'],  'Position',[780 190 815 220],'Port','3');

    add_line(ss,'FL_cmd/1','F2n/1','autorouting','on');
    add_line(ss,'FR_cmd/1','F2n/2','autorouting','on');
    add_line(ss,'Kp/1','F2n/3','autorouting','on');
    add_line(ss,'Nm/1','F2n/4','autorouting','on');
    add_line(ss,'F2n/1','MotorLag/1','autorouting','on');
    add_line(ss,'MotorLag/1','n2F/1','autorouting','on');
    add_line(ss,'Kp/1','n2F/2','autorouting','on');
    add_line(ss,'n2F/1','FL/1','autorouting','on');
    add_line(ss,'n2F/2','FR/1','autorouting','on');
    add_line(ss,'MotorLag/1','n/1','autorouting','on');

    Simulink.BlockDiagram.arrangeSystem(ss);

    %  설정 상수를 받는 포트 높이에 맞춘다 — 그러면 잇는 선이 직선 한 토막이다.
    %  arrangeSystem 은 선 길이만 보지 높이를 맞춰 주지는 않는다 (꺾임 2회가 남는다)
    align_to(ss, 'Kp', 'Outport', port_xy(ss, 'F2n', 'Inport', 3));
    align_to(ss, 'FL_cmd', 'Outport', port_xy(ss, 'F2n', 'Inport', 1));
    align_to(ss, 'FR_cmd', 'Outport', port_xy(ss, 'F2n', 'Inport', 2));
    align_to(ss, 'Nm', 'Outport', port_xy(ss, 'F2n', 'Inport', 4));

end

% =====================================================================
% 4단 · MOTION MODEL — 운동방정식 + 연속 적분 + 상태 산출을 한 블록에
%   VRX 모델에서 Gazebo 가 하는 일과 정확히 같은 자리를 차지한다.
%   두 모델의 최상위 구조가 이 블록 하나만 빼고 똑같아진다.
% =====================================================================
function addMotionModel(m, x, y)
    ss = [m '/MotionModel'];
    add_block('built-in/Subsystem', ss, 'Position', [x y x+210 y+200]);

    % EOM 의 2~6번 입력 순서. 앞의 둘만 신호이고 나머지 셋은 설정이다
    in = {'FL','FR','V_c','beta_c','p'};
    for k = 1:2
        add_block('simulink/Sources/In1', [ss '/' in{k}], ...
                  'Position', [40 60+(k-1)*70 75 60+(k-1)*70+30], 'Port', num2str(k));
    end

    % 조류와 선체 계수는 신호가 아니라 설정이다. 상자 안에 둔다.
    % 최상위에 두면 상수 세 개와 선 세 개가 운동모델 앞을 가린다.
    cfg = {'V_c','current_speed'; 'beta_c','beta_c'; ...
           'p','[m_usv; Izz; Xu; Xuu; Yv; Yvv; Nr; Nrr; half_beam]'};
    for k = 1:3
        add_block('simulink/Sources/Constant', [ss '/' cfg{k,1}], ...
                  'Position', [40 220+(k-1)*70 130 220+(k-1)*70+30], 'Value', cfg{k,2});
    end
    % ---- 운동방정식 (미분) ----
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/EOM'], 'Position', [200 60 380 260]);
    setFcn(ss, 'EOM', [ ...
'function xdot = EOM(s, FL, FR, V_c, beta_c, p)'                         newline ...
'%#codegen'                                                              newline ...
'% 3-DOF WAM-V equations of motion, NED.'                                newline ...
'% Coefficients come straight from the Gazebo VRX plugins:'              newline ...
'%   drag       : SimpleHydrodynamics  (Xu Xuu Yv Yvv Nr Nrr)'           newline ...
'%   mass       : wamv_base.urdf.xacro (180 kg hull + engines)'          newline ...
'%   added mass : zero in VRX (xDotU = yDotV = nDotR = 0)'               newline ...
'% Ocean current exists only here. Gazebo has no current plugin.'        newline ...
'%   s = [u v r N E psi]'''                                              newline ...
'%   p = [m Izz Xu Xuu Yv Yvv Nr Nrr half_beam]'''                       newline ...
''                                                                       newline ...
'u = s(1); v = s(2); r = s(3); psi = s(6);'                              newline ...
'm=p(1); Izz=p(2); Xu=p(3); Xuu=p(4); Yv=p(5); Yvv=p(6);'                newline ...
'Nr=p(7); Nrr=p(8); b_half=p(9);'                                        newline ...
''                                                                       newline ...
'% current in the body frame -> velocity relative to the water'          newline ...
'u_c = V_c*cos(beta_c - psi);'                                           newline ...
'v_c = V_c*sin(beta_c - psi);'                                           newline ...
'u_r = u - u_c;'                                                         newline ...
'v_r = v - v_c;'                                                         newline ...
''                                                                       newline ...
'% differential thrust -> surge force and yaw moment'                    newline ...
'X = FL + FR;'                                                           newline ...
'N = (FL - FR)*b_half;'                                                  newline ...
''                                                                       newline ...
'% drag acts on the velocity relative to the water'                      newline ...
'Dx = (Xu + Xuu*abs(u_r))*u_r;'                                          newline ...
'Dy = (Yv + Yvv*abs(v_r))*v_r;'                                          newline ...
'Dn = (Nr + Nrr*abs(r))*r;'                                              newline ...
''                                                                       newline ...
'du = (X - Dx)/m + v*r;      % rigid-body Coriolis'                      newline ...
'dv = (  - Dy)/m - u*r;'                                                 newline ...
'dr = (N - Dn)/Izz;'                                                     newline ...
''                                                                       newline ...
'xdot = [du; dv; dr;'                                                    newline ...
'        u*cos(psi) - v*sin(psi);   % kinematics use absolute velocity'  newline ...
'        u*sin(psi) + v*cos(psi);'                                       newline ...
'        r];']);

    % ---- 연속 적분기 ----
    add_block('simulink/Continuous/Integrator', [ss '/Integ'], ...
              'Position', [450 130 500 180], 'InitialCondition','x0');

    % ---- 상태 -> 항법량 ----
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/States'], 'Position', [570 60 720 260]);
    setFcn(ss, 'States', [ ...
'function [x_n, y_n, psi, u, r, beta, chi, U] = States(s)'    newline ...
'%#codegen'                                                 newline ...
'% Pick the navigation quantities out of the state vector.' newline ...
'% In the VRX model this job is done by the Nav block,'     newline ...
'% which also has to convert ENU to NED.'                   newline ...
'u = s(1); v = s(2); r = s(3);'                             newline ...
'x_n = s(4); y_n = s(5); psi = s(6);'                         newline ...
'U    = sqrt(u*u + v*v);      % speed over ground'          newline ...
'beta = atan2(v, u);          % crab angle'                 newline ...
'c    = psi + beta;           % course angle'               newline ...
'chi  = atan2(sin(c), cos(c));']);

    % --- 배치 : 한 줄에 EOM -> 1/s -> States. 포트 높이를 읽어서 맞춘다 ----
    ROW = 340;
    set_param([ss '/EOM'],    'Position', [280 100 460 580]);
    set_param([ss '/Integ'],  'Position', [560 ROW-15 590 ROW+15]);
    set_param([ss '/States'], 'Position', [680 100 840 580]);

    % 2~6번 입력(추력 둘 + 설정 셋)을 각자 포트 높이로 옮겨 직선으로 잇는다
    row_feed(ss, 'EOM', [{''}, in]);

    add_line(ss, 'EOM/1',   'Integ/1');
    add_line(ss, 'Integ/1', 'States/1');

    % 상태 되먹임 — 적분기 출력이 자기 미분식으로 돌아간다.
    % 화면을 가로지르는 대신 태그로 건너뛴다. 되먹임은 늘 이렇게 처리한다
    drop_tag(ss, 'Integ', 1, 'x_state', 280);
    b = port_xy(ss, 'EOM', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_x_state'], ...
              'Position', [180 b(2)-11 250 b(2)+11], 'GotoTag','x_state');
    add_line(ss, 'Fr_x_state/1', 'EOM/1');

    % 출력 포트를 States 의 포트 높이에 맞춘다 -> 여덟 선이 전부 직선
    out = {'x_n','y_n','psi','u','r','beta','chi','U'};
    for k = 1:numel(out)
        q = port_xy(ss, 'States', 'Outport', k);
        add_block('simulink/Sinks/Out1', [ss '/' out{k}], ...
                  'Position', [940 q(2)-7 970 q(2)+7], 'Port', num2str(k));
        add_line(ss, sprintf('States/%d',k), [out{k} '/1']);
    end
end

% =====================================================================
% 5단 · ANIMATE — 시뮬레이션이 도는 동안 실시간으로 그린다
%   MATLAB Function 블록은 원래 그림을 못 그린다.
%   coder.extrinsic 으로 선언하면 컴파일하지 않고 MATLAB 함수를 그대로 부른다.
%   실제 그리기는 W05_animate.m 이 한다.
%
%   두 모델이 같은 함수(W05_animate.m)를 쓴다 — 스킬 규칙 20·26.
%   바뀌는 것은 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   >>> 태그 순서가 곧 W05_animate 의 인자 순서다 <<<
%
%       x_n  y_n  psi  psi_ref  y_e  u  gate  FL  FR  wp_idx   +  t  +  en
%
%   From 을 더하거나 빼면 W05_animate 의 인자 순서도 같이 바뀐다. 아래 tags
%   한 줄이 그 계약이고, add_animate_box 가 그 순서대로 포트를 만든다.
%
%   태그가 어디서 나오는가 — **전부 이미 있던 태그다. 새로 뽑은 신호가 없다**
%     x_n·y_n·psi·u       MotionModel (오프라인) / PoseSubscriber (VRX) 의 Goto
%     psi_ref·y_e·gate    wireFront 가 Guidance 출력에 건 Goto
%     FL·FR               wireThrusterGotos
%     wp_idx              Guidance 안 drop_tag (TagVisibility = global)
%
%   속도 지령을 왜 gate 로 받는가
%     내부루프가 쓰는 지령은 u_ref × gate 다 (InnerLoop 의 Gate 블록). 그 곱을
%     태그로 빼려면 Gate 출력에 가지를 쳐야 하는데, 그러면 Simulink 가 본선
%     Gate -> SurgeErr 를 5 px 사선으로 다시 그어 배선 검사가 걸린다
%     (2026-09-24 실제로 밟았다). gate 는 이미 태그가 있고 u_ref 는 설정값이므로
%     그리는 함수가 둘을 곱한다. 모델에는 선이 한 줄도 늘지 않는다.
%
%   실시간 화면은 제어 신호를 **구경만** 한다. 이미 있는 태그를 읽을 뿐,
%   블록 하나 게인 하나 건드리지 않는다.
% =====================================================================
function addAnimate(m, x, y)
% 실시간 그림 — 포트 없는 서브시스템 하나로 묶는다.
% 공용 도구 _tools/add_animate_box.m 이 안을 채운다.
    tags = {'x_n','y_n','psi','psi_ref','y_e','u','gate','FL','FR','wp_idx'};
    add_animate_box(m, tags, 'W05_animate', '', [x y], 'Ts_ctrl');
end

% =====================================================================
% 설정 상수 + 유도/내부루프 입력 배선 (두 모델 공통)
% =====================================================================
function wireFront(m)
% 유도·내부루프의 되먹임 입력 배선 (두 모델 공통)
%
%   설정값(웨이포인트·Delta·R·mode·u_ref)은 각 서브시스템 **안에** 있다.
%   최상위에 남는 것은 **되먹임 다섯 개**뿐이다 — 그것이 이 모델이 하는 일이다.
    fx = F(m,'x_n', 40,  65);
    fy = F(m,'y_n', 40, 110);

    add_line(m,[fx '/1'],'Guidance/1','autorouting','on');
    add_line(m,[fy '/1'],'Guidance/2','autorouting','on');

    % 유도 출력에 로깅용 Goto 를 붙인다 (본선은 그대로 InnerLoop 로 간다)
    G(m,'psi_ref', 560,  70);
    G(m,'y_e',     560, 110);
    G(m,'x_e',     560, 150);
    G(m,'gate',    560, 190);
    G(m,'wp_idx',  560, 230);
    add_line(m,'Guidance/1','Go_psi_ref/1','autorouting','on');
    add_line(m,'Guidance/2','Go_y_e/1','autorouting','on');
    add_line(m,'Guidance/3','Go_x_e/1','autorouting','on');
    add_line(m,'Guidance/4','Go_gate/1','autorouting','on');
    add_line(m,'Guidance/5','Go_wp_idx/1','autorouting','on');

    % 2단 입력: 자세·속도 되먹임
    fp = F(m,'psi', 560, 360);
    fr = F(m,'r',   560, 400);
    fu = F(m,'u',   560, 440);

    add_line(m,'Guidance/1','InnerLoop/1','autorouting','on');
    add_line(m,'Guidance/4','InnerLoop/2','autorouting','on');
    add_line(m,[fp '/1'],'InnerLoop/3','autorouting','on');
    add_line(m,[fr '/1'],'InnerLoop/4','autorouting','on');
    add_line(m,[fu '/1'],'InnerLoop/5','autorouting','on');
end

function nm = F(m, tag, x, y)
%  From 블록 이름은 `Fr_<태그>` 다. 같은 태그를 여러 곳에서 받으면 **번호만** 붙인다
%  (line-routing.md §3.1). 이름을 손으로 짓지 않는다 — `Fr_psi_b` 처럼 받는 쪽
%  블록을 이름에 섞으면 이름표가 이웃을 덮고, 받는 블록을 바꿀 때 태그까지 손대야
%  한다. `_tools/from_name.m` 이 비어 있는 이름을 돌려준다.
    nm = from_name(m, tag);
    add_block('simulink/Signal Routing/From', [m '/' nm], ...
              'Position', [x y x+70 y+25], 'GotoTag', tag);
end

function G(m, tag, x, y)
    add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

function wireThrusterGotos(m, x, y)
    t = {'FL','FR','nprop'};
    for k = 1:3
        G(m, t{k}, x, y+(k-1)*40);
        add_line(m, sprintf('Thrusters/%d',k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end

function wireNavGotos(m, x, y)
% Nav 출력을 전부 Goto 태그로 내보낸다.
% 되먹임 선과 로깅 선이 화면을 가로지르지 않게 하는 표준 방법이다.
    tags = {'x_n','y_n','psi','u','r','beta','chi','U'};
    for k = 1:numel(tags)
        G(m, tags{k}, x, y+(k-1)*40);
        add_line(m, sprintf('Nav/%d',k), ['Go_' tags{k} '/1'], 'autorouting','on');
    end
end

% =====================================================================
% 실습 B~D — 오프라인 모델
% =====================================================================
function build_offline()
    m = 'W05_0_offline'; fresh(m);
    % 운동모델을 연속 적분기로 풀기 때문에 ode4 (4차 룽게쿠타) 를 쓴다.
    % 제어기·유도·추진기는 Ts_ctrl 로 도는 이산 블록이다 (하이브리드 구성).
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime','T_run', 'SimulationMode','normal');

    addGuidance(m, 250, 60);
    addInnerLoop(m, 720, 280);
    wireFront(m);
    addThrusters(m, 1000, 290);
    wireThrusterGotos(m, 1230, 290);

    % --- 4단 · 운동모델 (운동방정식 + 연속 적분 + 상태 산출) --------------

    addMotionModel(m, 1450, 280);

    add_line(m,'InnerLoop/1','Thrusters/1','autorouting','on');
    add_line(m,'InnerLoop/2','Thrusters/2','autorouting','on');

    %  사슬이 줄을 바꾸는 자리 — 선으로 이으면 오른쪽 끝에서 왼쪽 끝으로 거슬러
    %  올라가 도면을 가로지른다. lay_chain 은 그런 연결을 Goto/From 한 쌍으로
    %  바꾸는데, 이름을 몰라 `Thrusters_1` 처럼 **블록 이름 꼴 태그**를 만든다
    %  (check_tags 가 잡는다). 추진기 출력에는 이미 FL·FR 태그가 붙어 있으므로
    %  그것을 받는다 — 태그가 늘지 않고 이름이 신호 이름이다
    ff = {F(m,'FL', 1380, 300), F(m,'FR', 1380, 345)};
    add_line(m,[ff{1} '/1'],'MotionModel/1','autorouting','on');
    add_line(m,[ff{2} '/1'],'MotionModel/2','autorouting','on');

    % --- 되먹임 태그 + 로깅 ---------------------------------------------
    tags = {'x_n','y_n','psi','u','r','beta','chi','U'};
    for k = 1:numel(tags)
        G(m, tags{k}, 1760, 280+(k-1)*40);
        add_line(m, sprintf('MotionModel/%d',k), ['Go_' tags{k} '/1'], 'autorouting','on');
    end
    addAnimate(m, 1760, 650);
    addLogging(m, 2250, 60);

    %  관찰용 Scope 하나 + 자동 정지. 로깅(2250)과 **열을 갈라** 놓는다 —
    %  같은 x 에 두면 lay_sinks 가 종착 블록을 한 줄로 쓸어 내리며 선이 겹친다
    %  (2026-10-02 에 4주차에서 겪은 것과 같은 자리)
    addCompareScope(m, {'psi_ref','psi'; '','y_e'; '','u'; '','wp_idx'}, 2600, 1500);
    addAutoStop(m, 3100, 1500);

    note(m,'n1', ['W05 실습 B·C·D  —  오프라인 WAM-V (Gazebo 불필요)' newline ...
        'Guidance -> Inner Loop -> Thrusters -> 운동모델' newline ...
        '조류 실험은 이 모델에서만 가능하다.' newline ...
        '실행 전 >> W05_setup'], 250, -90);

    save_system(m); close_system(m);
    fprintf('  W05_0_offline  생성\n');
end

% =====================================================================
% 실습 E — VRX 연동 모델
% =====================================================================
function build_vrx()
    m = 'W05_1_vrx'; fresh(m);
    load_system('ros2lib');
    %  **inf 로 두지 않는다** (교수 지시 2026-10-02). 보통은 AutoStop 이 마지막
    %  웨이포인트를 지난 뒤 스스로 멈추고, T_run 은 그래도 안 끝날 때를 받친다
    setSolver(m, 'T_run');

    addGuidance(m, 250, 60);
    addInnerLoop(m, 720, 280);
    wireFront(m);
    addThrusters(m, 1000, 290);
    wireThrusterGotos(m, 1230, 620);

    % --- 4단 · 추력 발행 (운동모델 = Gazebo) -----------------------------
    add_cmd_publisher(m, [1300 260], ...
        {'/wamv/thrusters/left/thrust','/wamv/thrusters/right/thrust'}, 'Ts_ctrl');
    add_line(m,'InnerLoop/1','Thrusters/1','autorouting','on');
    add_line(m,'InnerLoop/2','Thrusters/2','autorouting','on');
    %  줄이 바뀌는 자리는 이미 있는 FL·FR 태그로 받는다 (W05_0_offline 과 같은 이유)
    fc = {F(m,'FL', 1230, 280), F(m,'FR', 1230, 325)};
    add_line(m,[fc{1} '/1'],'CmdPublisher/1','autorouting','on');
    add_line(m,[fc{2} '/1'],'CmdPublisher/2','autorouting','on');

    % --- 5단 · 항법 (ENU -> NED 변환) -----------------------------------
    navCode = [ ...
'function [x_n, y_n, psi, u, r, beta, chi, U] = Nav(ex, ey, qx, qy, qz, qw, bx, by, wz, org_x, org_y)' newline ...
'%#codegen'                                                                 newline ...
'% Gazebo/ROS uses ENU with a body frame of x-forward, y-LEFT, z-UP.'       newline ...
'% Marine control uses NED with a body frame of x-forward, y-STARBOARD.'    newline ...
'% Position :  N = y_ENU,  E = x_ENU'                                       newline ...
'% Heading  :  psi_NED = pi/2 - yaw_ENU'                                    newline ...
'% Body vel :  u = bx,  v = -by,  r = -wz    (y and z flip sign)'           newline ...
''                                                                          newline ...
'% 첫 메시지가 도착하기 전에는 Subscribe 가 0 으로 채운 버스를 낸다.'       newline ...
'% 그대로 쓰면 위치가 스폰 원점만큼(약 568 m) 튀어 로그 첫 점이 망가진다.'  newline ...
'if ex == 0 && ey == 0'                                                     newline ...
'    x_n = 0; y_n = 0; psi = 0; u = 0; r = 0; beta = 0; chi = 0; U = 0;'      newline ...
'    return'                                                                newline ...
'end'                                                                       newline ...
'x_n = ey - org_x;    % north, relative to the spawn point'                   newline ...
'y_n = ex - org_y;    % east'                                                 newline ...
''                                                                          newline ...
'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'                newline ...
'p   = pi/2 - yaw_enu;'                                                     newline ...
'psi = atan2(sin(p), cos(p));'                                              newline ...
''                                                                          newline ...
'u = bx;'                                                                   newline ...
'v = -by;'                                                                  newline ...
'r = -wz;'                                                                  newline ...
''                                                                          newline ...
'U    = sqrt(u*u + v*v);'                                                   newline ...
'beta = atan2(v, u);          % crab angle'                                 newline ...
'c    = psi + beta;'                                                        newline ...
'chi  = atan2(sin(c), cos(c));'];

    add_pose_subscriber(m, [1660 620], ...
        '/wamv/sensors/position/ground_truth_odometry', 'Ts_ctrl', navCode, ...
        {'x_n','y_n','psi','u','r','beta','chi','U'});

    % 항법 출력을 전부 Goto 태그로 내보낸다
    tags = {'x_n','y_n','psi','u','r','beta','chi','U'};
    for k = 1:numel(tags)
        G(m, tags{k}, 1980, 620+(k-1)*45);
        add_line(m, sprintf('PoseSubscriber/%d',k), ['Go_' tags{k} '/1'], 'autorouting','on');
    end

    addAnimate(m, 2080, 1100);
    addLogging(m, 2400, 60);

    %  Scope 하나 + 자동 정지 (오프라인 쌍둥이와 같은 구성·같은 자리 규칙)
    addCompareScope(m, {'psi_ref','psi'; '','y_e'; '','u'; '','wp_idx'}, 2750, 1800);
    addAutoStop(m, 3250, 1800);

    note(m,'n1', ['W05 실습 E  —  VRX 연동 (Gazebo 필요)' newline ...
        'Guidance -> Inner Loop -> Thrusters -> Gazebo -> Navigation' newline ...
        '유도부·내부루프·추진기·게인은 W05_0_offline 과 완전히 같다.' newline ...
        '운동모델만 Gazebo 로 바뀐다.' newline ...
        '실행 전: (1) W05_setup  (2) VRX 기동  (3) 페이싱을 RTF 에 맞출 것'], 250, -90);

    save_system(m); close_system(m);
    fprintf('  W05_1_vrx      생성\n');
end

% ---------------------------------------------------------------------
% 추력 발행 3종 세트 (4주차와 동일)
% ---------------------------------------------------------------------
function addThrusterPublisher(m, side, tag, x, y)
    add_block('ros2lib/Blank Message', [m '/Blank' tag], ...
              'Position', [x y+70 x+100 y+110]);
    set_param([m '/Blank' tag], 'entityType','std_msgs/Float64', ...
              'messageType','std_msgs/Float64', 'SampleTime','Ts_ctrl');
    add_block('simulink/Signal Routing/Bus Assignment', [m '/Asg' tag], ...
              'Position', [x+160 y x+220 y+115]);
    set_param([m '/Asg' tag], 'AssignedSignals','data');
    add_block('ros2lib/Publish', [m '/Pub' tag], ...
              'Position', [x+290 y+35 x+390 y+75]);
    set_param([m '/Pub' tag], 'topicSource','Specify your own', ...
              'topic', ['/wamv/thrusters/' side '/thrust'], ...
              'messageType','std_msgs/Float64');
    add_line(m, ['Blank' tag '/1'], ['Asg' tag '/1'], 'autorouting','on');
    add_line(m, ['Asg'   tag '/1'], ['Pub' tag '/1'], 'autorouting','on');
end

% ---------------------------------------------------------------------
% 로깅 — W05_plot.m 이 읽는다
% ---------------------------------------------------------------------
function addLogging(m, x, y)
% 로깅 — 포트 없는 서브시스템 하나로 묶는다. W05_plot.m 이 이 변수들을 읽는다.
%   신호 이름 = Goto 태그 이름 (n 만 nprop 태그를 쓴다)
    %  wp_idx 도 기록한다 — 그래프에서 구간이 바뀐 자리를 숫자로 확인하려면
    %  필요하다 (2026-10-02 에 Guidance 의 다섯째 출력으로 밖에 냈다)
    sig = {'x_n','y_n','psi','psi_ref','y_e','x_e','beta','chi','u','r','U','gate','FL','FR','n','wp_idx'};
    tag = {'x_n','y_n','psi','psi_ref','y_e','x_e','beta','chi','u','r','U','gate','FL','FR','nprop','wp_idx'};
    add_logging_box(m, sig, tag, [x y], 'Ts_ctrl');
end

% =====================================================================
% 자동 정지 — 마지막 웨이포인트를 지나면 모델이 스스로 Stop 을 누른다
%
%   교수 지시 2026-10-02. "inf 무한대까지 시뮬레이션 하지 말고, waypoint
%   끝나면 Stop 버튼으로 시뮬링크에서 자동으로 멈추게 해 달라."
%
%   끝났다는 것을 어떻게 아는가 / how it knows the mission is over
%       `GuidanceLaw` 가 내는 `gate` 가 그 답이다. 마지막 구간을 지나면
%       `wp_idx` 가 n 으로 **빗장이 걸리고**(latch), 그때 `gate` 가 0 이 된다.
%       즉 gate 는 "아직 갈 구간이 남았는가" 를 그대로 말한다.
%
%   왜 바로 멈추지 않고 조금 기다리는가
%       멈추는 순간까지의 몇 초가 그래프에 남아야 "도착해서 멈췄다" 가 보인다.
%       `stop_hold` 초만 더 돌고 끝낸다. 4주차 AutoStop 과 같은 꼴이며,
%       버틴 시간을 **연속 적분기**로 세는 것도 같다 (입력 1, 외부 리셋 = gate).
%
%   외부 리셋은 `level` 이다. `rising` 은 신호가 올라가는 순간만 리셋하므로,
%   처음부터 gate = 1 이면 모서리가 없어 리셋이 영영 안 걸린다 (2026-10-02).
function addAutoStop(m, x, y)
%  **포트 없는 상자**로 만든다. gate 는 안에서 From 으로 받는다.
%  lay_chain 의 'Boxes' 는 포트 없는 서브시스템만 자리를 잡아 주기 때문이다 —
%  포트를 밖으로 내면 lay_chain 이 그 자리를 모르고 다른 블록을 겹쳐 놓는다
%  (2026-10-02 에 블록겹침 7 이 그래서 났다). Animate·Logging 과 같은 꼴이다.
    s = add_subsys(m, 'AutoStop', [x y x+150 y+80], {}, {}, ...
                   gnc_colour('logging'));

    add_block('simulink/Signal Routing/From', [s '/Fr_gate'], ...
              'GotoTag','gate', 'Position',[40 100 110 125]);

    %  gate 가 1 인 동안(아직 갈 구간이 있다) 적분기를 0 에 묶어 둔다.
    %  0 이 되면(임무 끝) 그때부터 초를 센다
    add_block('simulink/Sources/Constant', [s '/One'], ...
              'Value','1', 'Position',[120 40 170 70]);
    add_block('simulink/Continuous/Integrator', [s '/HeldFor'], ...
              'ExternalReset','level', 'InitialCondition','0', ...
              'Position',[240 95 280 135]);
    add_block('simulink/Sources/Constant', [s '/Hold'], ...
              'Value','stop_hold', 'Position',[240 190 340 220]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/Done'], ...
              'Operator','>=', 'Position',[380 110 410 140]);
    add_block('simulink/Sinks/Stop Simulation', [s '/StopSim'], ...
              'Position',[470 110 510 140]);

    add_line(s,'One/1','HeldFor/1','autorouting','on');
    add_line(s,'Fr_gate/1','HeldFor/2','autorouting','on');
    add_line(s,'HeldFor/1','Done/1','autorouting','on');
    add_line(s,'Hold/1','Done/2','autorouting','on');
    add_line(s,'Done/1','StopSim/1','autorouting','on');
end

% =====================================================================
% 관찰용 Scope — 모델 하나에 **한 개**, 지령과 실제값을 나란히
%
%   교수 지시 2026-10-02. "scope 로 궤적은 필요 없다. 하나의 scope 에서 각
%   제어 명령과 실제 값을 볼 수 있게. waypoint k index 도."
%
%   궤적은 넣지 않는다 — x-y 평면이라 시간축과 축이 다르고, 실시간 화면
%   (W05_animate) 의 왼쪽 큰 칸이 이미 그 일을 한다.
%
%   PAIRS  {지령태그, 실제태그} 를 칸 순서대로. 지령이 없는 칸은 ''
function addCompareScope(m, pairs, x, y)
%  Animate·Logging 과 같이 **포트 없는 상자**다. 신호는 안에서 From 으로 받는다.
%  그래야 lay_chain 의 'Boxes' 가 자리를 잡아 준다 (addAutoStop 의 설명 참고).
    nAx = size(pairs,1);
    s   = add_subsys(m, 'Observe', [x y x+170 y+90], {}, {}, gnc_colour('logging'));
    sc  = [s '/Scope'];

    %  From 블록은 25 px 높이이고, **그 아래에 이름표가 12 px** 더 붙는다.
    %  그래서 한 칸 안의 두 From 은 25+12 보다 넓게 띄워야 하고 (GAP),
    %  칸과 칸 사이는 GAP+25+12 보다 넓어야 한다 (ROW). 2026-10-02 에 22 px 로
    %  두었다가 블록이 겹쳤고, 35 px 로는 이름표가 서로를 가렸다
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
% 실습 F — 웨이포인트 번호를 어디에 기억할 것인가
%
%   교수 지시 2026-10-02. "guidance 에서 k 값을 persistent 로 하지 말고
%   unit delay 이용해서 기존 값 기억하게 하는 버전도 추가로 만들어 달라."
%
%   왜 이 모델이 따로 있는가 / why this is its own model
%       `W05_matlab/LOSchi.m` 과 `Simple_guidance.m` 은 MATLAB 함수라 활성
%       웨이포인트 번호 k 를 `persistent` 에 둔다. 함수를 거듭 부르는 동안
%       값이 살아 있어야 하는데, 함수에는 그것을 둘 자리가 그곳뿐이기 때문이다.
%
%       Simulink 로 옮기면 선택지가 하나 더 생긴다 — **Unit Delay 블록**이다.
%       본 모델(`W05_0_offline`·`W05_1_vrx`)의 Guidance 는 이미 그쪽을 쓴다
%       (`IdxDly`). 이 실습 모델은 **두 방식을 나란히 돌려** 같은 답을 내는지
%       눈으로 보고, 무엇이 다른지 짚는 자리다.
%
%       | | persistent | Unit Delay |
%       |---|---|---|
%       | 상태가 보이는가 | 아니다 — 코드 안에 숨는다 | 도면에 블록으로 보인다 |
%       | 초기값 | 첫 호출 때 코드로 | 블록 파라미터로 |
%       | 되돌리기 | `clear 함수이름` | Run 하면 저절로 |
%       | 기록·관찰 | 밖에서 못 본다 | 신호라서 Scope·로깅에 걸린다 |
%       | 대수 루프 | 막지 못한다 | **끊어 준다** |
%
%       마지막 줄이 Simulink 에서 결정적이다. 유도부가 낸 번호가 유도부로
%       되돌아오므로 그대로 두면 대수 루프가 된다. Unit Delay 가 그 고리를 끊는다.
function build_idx_memory()
    m = 'W05_2_idx_memory'; fresh(m);
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime','20', 'SimulationMode','normal');

    %  "구간을 하나 지났다" 를 흉내 내는 사건 — 4 초마다 한 번씩 1 이 된다
    add_block('simulink/Sources/Pulse Generator', [m '/LegDone'], ...
              'Amplitude','1', 'Period','4/Ts_ctrl', 'PulseWidth','1', ...
              'PulseType','Sample based', 'SampleTime','Ts_ctrl', ...
              'Position',[60 120 110 170]);

    % --- 방식 A : persistent (MATLAB 함수가 혼자 기억한다) ----------------
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/IdxPersistent'], ...
              'Position',[260 60 430 130]);
    setFcn(m, 'IdxPersistent', [ ...
'function k = IdxPersistent(step)'                                      newline ...
'%#codegen'                                                             newline ...
'% 활성 웨이포인트 번호를 **함수 안에** 기억한다 (W05_matlab/LOSchi.m 방식).'  newline ...
'% 상태가 코드 안에 숨어 도면에는 보이지 않는다.'                        newline ...
'persistent k_mem'                                                      newline ...
'if isempty(k_mem)'                                                     newline ...
'    k_mem = 1;'                                                        newline ...
'end'                                                                   newline ...
'if step > 0.5'                                                         newline ...
'    k_mem = k_mem + 1;'                                                newline ...
'end'                                                                   newline ...
'k = k_mem;']);

    % --- 방식 B : Unit Delay (상태를 도면에 꺼내 놓는다) -------------------
    add_block('simulink/User-Defined Functions/MATLAB Function', [m '/IdxStep'], ...
              'Position',[260 260 430 330]);
    setFcn(m, 'IdxStep', [ ...
'function k = IdxStep(step, k_prev)'                                    newline ...
'%#codegen'                                                             newline ...
'% 기억하지 않는다 — **한 스텝 전의 값을 받아** 다음 값을 돌려줄 뿐이다.'  newline ...
'% 기억은 밖의 Unit Delay 가 맡는다. 그래서 이 함수는 순수 함수다.'       newline ...
'if step > 0.5'                                                         newline ...
'    k = k_prev + 1;'                                                   newline ...
'else'                                                                  newline ...
'    k = k_prev;'                                                       newline ...
'end']);

    add_block('simulink/Discrete/Unit Delay', [m '/IdxDly'], ...
              'InitialCondition','1', 'SampleTime','Ts_ctrl', ...
              'Position',[300 400 370 450]);
    set_param([m '/IdxDly'], 'Description', ...
        ['웨이포인트 번호의 기억. 정수 사건 상태이고 대수 루프를 끊는다 — ' ...
         '미분방정식의 상태가 아니므로 이산이 맞다.']);

    add_block('simulink/Sinks/Scope', [m '/Scope'], 'Position',[620 170 670 270]);
    set_param([m '/Scope'],'NumInputPorts','2');

    add_line(m,'LegDone/1','IdxPersistent/1','autorouting','on');
    add_line(m,'LegDone/1','IdxStep/1','autorouting','on');
    %  되먹임 선에 **이름을 준다.** tidy_model 의 tag_feedback 이 이 고리를
    %  Goto/From 으로 바꿀 때 그 이름을 태그로 쓴다. 이름이 없으면 블록 이름을
    %  빌려 `IdxStep_1` 같은 태그가 생기고 check_tags 가 잡는다 (2026-10-02)
    h = add_line(m,'IdxStep/1','IdxDly/1','autorouting','on');
    set_param(h, 'Name', 'k');
    h = add_line(m,'IdxDly/1','IdxStep/2','autorouting','on');
    set_param(h, 'Name', 'k_prev');
    add_line(m,'IdxPersistent/1','Scope/1','autorouting','on');
    add_line(m,'IdxStep/1','Scope/2','autorouting','on');

    note(m,'n1', ['W05 실습 F  —  웨이포인트 번호를 어디에 기억할 것인가' newline ...
        '위: persistent (상태가 코드 안에 숨는다)' newline ...
        '아래: Unit Delay (상태가 도면에 보이고 Scope 에 걸린다)' newline ...
        '두 선이 겹친다 — 답은 같고 다른 것은 상태를 어디에 두느냐다.' newline ...
        '실행 전 >> W05_setup'], 60, -60);

    save_system(m); close_system(m);
    tidy_model(m);            % 되먹임 고리가 있어 손으로 놓으면 세 번 꺾인다
    load_system(m); paint_roles(m); check_colour(m);
    save_system(m); close_system(m, 0);
    fprintf('  W05_2_idx_memory  생성\n');
end
