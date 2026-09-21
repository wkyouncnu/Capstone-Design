function build_w06_pid_models()
% BUILD_W06_PID_MODELS  6주차 PID 입문 실습 모델 3개를 생성한다.
%
%   W06_P1_pid_step.slx    라이브러리 PID 블록 하나. 게인의 역할을 눈으로 본다
%   W06_P2_pid_byhand.slx  같은 PID 를 Gain·Integrator·Sum 으로 직접 조립한다.
%                          라이브러리 블록과 나란히 돌려 두 곡선이 겹치는지 본다.
%                          미분 필터와 안티와인드업이 그 안에 들어 있다
%   W06_P3_boat_speed.slx  직접 만든 PID 를 오프라인 배(WAM-V 종방향)로 옮긴다
%
%   전제
%     >> W06_pid_setup      % 파라미터가 base workspace 에 있어야 한다
%
%   배치 규약 (CLAUDE.md §11, 스킬 simulink-gnc-models)
%     - 왼쪽에서 오른쪽으로 : 설정값 -> 제어 -> 추진기 -> 운동모델 -> 로깅
%     - 한 줄 위의 블록은 전부 같은 높이. 그래야 신호선이 직선이 된다
%     - 되먹임은 Goto/From 태그. 화면을 가로지르는 선을 만들지 않는다
%     - 합산점은 MSS 규격 20x20 둥근 원 (add_sum)
%     - 로깅은 포트 없는 서브시스템 (Logging)
%     - 마지막에 mss_style 로 치수를 맞추고 check_overlaps 로 겹침 0 을 확인한다
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 원래대로 복구된다.

    here = fileparts(mfilename('fullpath'));
    cd(here);
    addpath(fullfile(here, '..', '..', '_tools'));
    if evalin('base', '~exist(''Kp'',''var'')')
        evalin('base', 'W06_pid_setup');
    end

    ROW = 200;          % 신호 사슬이 놓이는 높이. 모든 블록의 중심이 여기 온다

    build_p1(ROW);
    build_p2(ROW);
    build_p3(ROW);

    fprintf('\n배선 검사 — 겹침 0 · 블록관통 0 · 꺾임3회+ 0 이 합격선\n');
    names = {'W06_P1_pid_step','W06_P2_pid_byhand','W06_P3_boat_speed'};
    for k = 1:numel(names)
        check_lines(names{k}, true);
        paint_roles(names{k});        % 역할표는 _tools/gnc_roles.m 하나뿐이다
        check_colour(names{k});
        export_diagram(names{k});
    end
    %  F-3 절이 싣는 Dcompare 안쪽 도면. 강의노트는 W06_Dcompare.png 이름을 쓴다
    f = export_diagram('W06_P2_pid_byhand', '', 'Dcompare');
    movefile(f, fullfile(here, 'img', 'W06_Dcompare.png'), 'f');
end

% =====================================================================
% P1 — 라이브러리 PID 블록 하나. 게인의 역할만 본다
% =====================================================================
function build_p1(ROW)
    m = 'W06_P1_pid_step'; fresh(m);

    x = chain(1:4);
    blk(m, 'simulink/Sources/Step', 'Ref', x(1), ROW, 30, 30, ...
        {'Time','1','Before','0','After','1'});
    add_sum(m, 'SumE', '+-', [x(2) ROW]);
    blk(m, 'simulink/Continuous/PID Controller', 'PID', x(3), ROW, 90, 60, ...
        {'Controller','PID', 'TimeDomain','Continuous-time', ...
         'P','Kp', 'I','Ki', 'D','Kd', 'UseFilter','on', 'N','Nf'});
    blk(m, 'simulink/Continuous/Transfer Fcn', 'Plant', x(4), ROW, 60, 36, ...
        {'Numerator','plant_num', 'Denominator','plant_den'});

    goto(m, 'y', x(4)+110, ROW);

    straight(m, {'Ref','SumE'; 'SumE','PID'; 'PID','Plant'; 'Plant','Go_y'});
    feed_from(m, 'y', 'SumE', 2, 90);    % 되먹임은 원의 아래에서 올라온다
    drop_tag(m, 'PID', 1, 'tau', 90);      % 제어입력도 태그로 빼 둔다

    addLogging(m, {'y','tau'}, [x(4)+40 ROW+150]);
    paint(m, {'Ref','command'; 'SumE','control'; 'PID','control'; 'Plant','plant'});

    solver(m, 'ode4', '0.001', '10');
    stamp(m, ROW+330, [ ...
        '[PID 입문 1] 라이브러리 PID 블록 하나로 P, I, D 를 본다' newline ...
        '플랜트  G(s) = 1/(s^2 + 2s + 2)   질량-스프링-댐퍼. 배가 아니다' newline ...
        '' newline ...
        '게인은 숫자가 아니라 변수 이름으로 블록 안에 들어 있다.' newline ...
        '  >> W06_pid_setup                      기본값으로 되돌리기' newline ...
        '  >> Kp = 30;  sim(''W06_P1_pid_step'')   한 개만 바꿔 보기' newline ...
        '' newline ...
        '  Kp 만 키운다  ->  빨라진다. 출렁인다. 목표에 못 미친 채 멈춘다' newline ...
        '  Kd 를 더한다  ->  오버슈트가 깎인다' newline ...
        '  Ki 를 더한다  ->  못 미친 만큼을 시간이 메운다' newline ...
        '' newline ...
        'PID 블록 안에 무엇이 들어 있는지는 W06_P2_pid_byhand 에서 직접 조립한다.']);

    finish(m);
end

% =====================================================================
% P2 — PID 를 직접 조립하고, 라이브러리 블록과 나란히 돌린다
%      위 줄 : 라이브러리 PID 블록
%      아래 줄: Gain / Integrator / pseudo-derivative / Sum 으로 직접 만든 PID
% =====================================================================
function build_p2(ROW)
    m = 'W06_P2_pid_byhand'; fresh(m);

    ROW2 = ROW + 260;                % 아래 줄 (직접 만든 PID)
    MID  = (ROW + ROW2)/2;
    x    = chain(1:6);

    blk(m, 'simulink/Sources/Step', 'Ref', x(1), MID, 30, 30, ...
        {'Time','1','Before','0','After','r_step'});

    % 센서 잡음은 한 곳에서 만들어 태그로 두 줄에 똑같이 넣는다.
    % 그래야 두 제어기가 글자 그대로 같은 조건에서 비교된다
    blk(m, 'simulink/Sources/Random Number', 'SensorNoise', x(1), ROW-150, 50, 30, ...
        {'Mean','0', 'Variance','noise_var', 'Seed','12345', 'SampleTime','noise_ts'});
    drop_tag(m, 'SensorNoise', 1, 'noise', 0);

    % --- 위 줄 · 라이브러리 PID 블록 -----------------------------------
    add_sum(m, 'SumE_lib', '+-', [x(2) ROW]);
    blk(m, 'simulink/Continuous/PID Controller', 'PID_lib', x(3), ROW, 90, 60, ...
        {'Controller','PID', 'TimeDomain','Continuous-time', ...
         'P','Kp2', 'I','Ki2', 'D','Kd2', 'UseFilter','on', 'N','Nf2', ...
         'LimitOutput','on', 'UpperSaturationLimit','u_max', ...
         'LowerSaturationLimit','-u_max', 'AntiWindupMode','back-calculation', ...
         'Kb','Kb'});
    blk(m, 'simulink/Continuous/Transfer Fcn', 'Plant_lib', x(4), ROW, 60, 36, ...
        {'Numerator','plant_num', 'Denominator','plant_den'});
    add_sum(m, 'SumY_lib', '++', [x(5) ROW]);           % 측정값 = 참값 + 잡음
    goto(m, 'ym_lib', x(6), ROW);

    ax = port_xy(m, 'Ref', 'Outport', 1);
    lane_line(m, 'Ref', 1, 'SumE_lib', 1, ax(1));       % 한 줄기에서 위아래로 갈라진다
    straight(m, {'SumE_lib','PID_lib'; 'PID_lib','Plant_lib'; ...
                 'Plant_lib','SumY_lib'; 'SumY_lib','Go_ym_lib'});
    feed_from(m, 'ym_lib', 'SumE_lib', 2, 90);
    feed_from(m, 'noise',  'SumY_lib', 2, 90, '1');
    drop_tag(m, 'Plant_lib', 1, 'y_lib', -150);         % 로깅은 잡음 없는 참값으로
    drop_tag(m, 'PID_lib',   1, 'tau_lib', -150);

    % --- 아래 줄 · 직접 만든 PID ---------------------------------------
    add_sum(m, 'SumE_hand', '+-', [x(2) ROW2]);
    addPIDbyhand(m, 'PID_byhand', [x(3)-70 ROW2-80 x(3)+70 ROW2+80], ...
                 struct('P','Kp2','I','Ki2','D','Kd2','N','Nf2', ...
                        'Lim','u_max','Kb','Kb'));
    blk(m, 'simulink/Continuous/Transfer Fcn', 'Plant_hand', x(4), ROW2, 60, 36, ...
        {'Numerator','plant_num', 'Denominator','plant_den'});
    add_sum(m, 'SumY_hand', '++', [x(5) ROW2]);
    goto(m, 'ym_hand', x(6), ROW2);

    lane_line(m, 'Ref', 1, 'SumE_hand', 1, ax(1));
    straight(m, {'SumE_hand','PID_byhand'; 'PID_byhand','Plant_hand'; ...
                 'Plant_hand','SumY_hand'; 'SumY_hand','Go_ym_hand'});
    feed_from(m, 'ym_hand', 'SumE_hand', 2, 90);
    feed_from(m, 'noise',   'SumY_hand', 2, 90, '2');
    drop_tag(m, 'Plant_hand', 1, 'y_hand', 170);
    drop_tag(m, 'PID_byhand', 1, 'tau_hand', 170);

    addLogging(m, {'y_lib','tau_lib','y_hand','tau_hand'}, [x(6)+80 ROW2+200]);
    addDcompare(m, [x(1) ROW2+200]);
    paint(m, {'Ref','command'; 'SensorNoise','env'; ...
              'SumE_lib','control'; 'PID_lib','control'; 'Plant_lib','plant'; ...
              'SumY_lib','env'; ...
              'SumE_hand','control'; 'Plant_hand','plant'; 'SumY_hand','env'});

    solver(m, 'ode4', '0.001', '20');
    stamp(m, ROW2+330, [ ...
        '[PID 입문 2] PID 를 직접 조립하고 라이브러리 블록과 나란히 돌린다' newline ...
        '' newline ...
        '  위  줄 : 라이브러리 PID 블록' newline ...
        '  아래 줄 : PID_byhand — Gain 3개, Integrator 1개, 미분 필터 1개, 합산점 2개' newline ...
        '' newline ...
        '두 곡선이 겹치면 직접 만든 것이 블록 안의 것과 같다는 뜻이다.' newline ...
        'PID_byhand 를 열어 보면 P, I, D 갈래가 각각 어디로 가는지 보인다.' newline ...
        '' newline ...
        '  Kb = 0   안티와인드업 끔    Kb > 0   켬 (되감기 이득)' newline ...
        '  Nf2      미분 필터 계수. 크게 할수록 순수 미분에 가깝다' newline ...
        '' newline ...
        '  >> W06_pid_compare(''hand'')   직접 만든 것과 블록을 겹쳐 그린다' newline ...
        '  >> W06_pid_compare(''D'')      미분 필터를 풀면 제어입력이 어떻게 되는가' newline ...
        '  >> W06_pid_compare(''AW'')     안티와인드업 유무' newline ...
        '' newline ...
        '왼쪽 아래 Dcompare 는 루프와 무관한 곁들이 실험이다. 열어 볼 것']);

    finish(m);
end

% =====================================================================
% P3 — 직접 만든 PID 를 오프라인 배로 옮긴다 (종방향 속도 제어)
% =====================================================================
function build_p3(ROW)
    m = 'W06_P3_boat_speed'; fresh(m);
    x = chain(1:7);

    blk(m, 'simulink/Sources/Digital Clock', 'Clk', x(1), ROW, 20, 20, ...
        {'SampleTime','0.01'});

    fcn(m, 'RefScenario', x(2), ROW, 110, 50, [ ...
'function u_ref = RefScenario(t)'                                        newline ...
'%#codegen'                                                              newline ...
'% Surge speed command [m/s].'                                           newline ...
'%    0- 5 s : stop'                                                     newline ...
'%    5-30 s : 2.5 m/s  -- unreachable. Thrust saturates the whole time' newline ...
'%   30-60 s : 1.0 m/s  -- reachable again'                              newline ...
'if t < 5'                                                               newline ...
'    u_ref = 0;'                                                         newline ...
'elseif t < 30'                                                          newline ...
'    u_ref = 2.5;'                                                       newline ...
'else'                                                                   newline ...
'    u_ref = 1.0;'                                                       newline ...
'end']);

    add_sum(m, 'SumE', '+-', [x(3) ROW]);
    addPIDbyhand(m, 'PID_u', [x(4)-70 ROW-80 x(4)+70 ROW+80], ...
                 struct('P','Kp_u','I','Ki_u','D','Kd_u','N','Nf_u', ...
                        'Lim','X_max','Kb','Kb_u'));
    blk(m, 'simulink/Continuous/Transfer Fcn', 'MotorLag', x(5), ROW, 60, 36, ...
        {'Numerator','1', 'Denominator','[tau_m 1]'});

    fcn(m, 'EOM', x(6), ROW, 110, 60, [ ...
'function du = EOM(u, X)'                                           newline ...
'%#codegen'                                                         newline ...
'% Surge-only WAM-V equation of motion.'                            newline ...
'% Same coefficients as W06_5_offline, i.e. the Gazebo VRX plugin.' newline ...
'%   m du/dt = X - (Xu + Xuu*|u|)*u'                                newline ...
'mm  = 211;'                                                        newline ...
'Xu  = 100;'                                                        newline ...
'Xuu = 150;'                                                        newline ...
'du = (X - (Xu + Xuu*abs(u))*u)/mm;']);

    blk(m, 'simulink/Continuous/Integrator', 'Integ', x(7), ROW, 30, 30, ...
        {'InitialCondition','0'});

    goto(m, 'u', x(7)+90, ROW);

    % EOM(u, X) — 1번 포트가 속도, 2번 포트가 추력이다. 순서를 틀리면
    % 오류 없이 엉뚱한 배가 된다
    straight(m, {'Clk','RefScenario'; 'RefScenario','SumE'; 'SumE','PID_u'; ...
                 'PID_u','MotorLag'; 'EOM','Integ'; 'Integ','Go_u'});

    mx = port_xy(m, 'MotorLag', 'Outport', 1);
    lane_line(m, 'MotorLag', 1, 'EOM', 2, mx(1));   % 출발점에서 바로 내려간다
    feed_from(m, 'u', 'EOM',  1, -90, '2');
    feed_from(m, 'u', 'SumE', 2,  90, '1');
    drop_tag(m, 'RefScenario', 1, 'uref', -110);
    drop_tag(m, 'MotorLag',    1, 'X',    170);

    addLogging(m, {'uref','u','X'}, [x(7)+40 ROW+200]);
    paint(m, {'Clk','command'; 'RefScenario','guidance'; 'SumE','control'; ...
              'MotorLag','thruster'; 'EOM','plant'; 'Integ','plant'});

    solver(m, 'ode4', '0.01', '60');
    stamp(m, ROW+400, [ ...
        '[PID 입문 3] 직접 만든 PID 를 그대로 배로 옮긴다 — 종방향 속도 제어' newline ...
        'Gazebo 없이 돈다. 60초 시나리오가 1초 안에 끝난다.' newline ...
        '' newline ...
        '   5~30 s  목표 2.5 m/s : 추력 한계 X_max 때문에 도달할 수 없다' newline ...
        '  30~60 s  목표 1.0 m/s : 도달할 수 있다' newline ...
        '' newline ...
        '앞 구간에서 쌓인 적분값이 뒤 구간을 망가뜨리는지 본다.' newline ...
        '  Kb_u = 0  안티와인드업 끔' newline ...
        '  >> W06_pid_compare(''boat'')   안티와인드업 유무를 겹쳐 그린다']);

    finish(m);
end

% =====================================================================
% PID 를 블록으로 직접 조립한 서브시스템
%
%        e ─┬─ Kp ──────────────────────────────┐
%           ├─ Ki ─→ SumI ─→ 1/s ───────────────┼─→ SumU ─→ Sat ─→ tau
%           └─ Kd ─→ Nf·s/(s+Nf) ───────────────┘        │
%                      ↑ Kb·(tau_sat − tau_raw) ←── SumAW ←──┘
%
%   Kb 가 안티와인드업 되감기 이득이다. 0 이면 되감기가 없다.
% =====================================================================
function addPIDbyhand(mdl, name, pos, v)
    s = add_subsys(mdl, name, pos, {'e'}, {'tau'}, gnc_colour('control'));

    % P 갈래가 맨 위의 주선(主線)이고, I 와 D 는 아래에서 합류한다.
    % 둥근 합산점의 2번 입력은 원의 **아래쪽**에 있다. 그래서 아래에서
    % 올라오는 신호만 2번에 붙인다 — MSS 데모가 이 모양이다.
    RP = 100; RI = 220; RD = 340;         % P, I, D 갈래의 높이
    RAW = 440; RDET = 500; RBK = 560;     % 되감기 경로 세 줄

    set_param([s '/e'], 'Position', [ 45 RP-7  75 RP+7]);
    set_param([s '/tau'], 'Position', [805 RP-7 835 RP+7]);

    blk(s, 'simulink/Math Operations/Gain', 'Kp_gain', 200, RP, 50, 36, {'Gain', v.P});
    blk(s, 'simulink/Math Operations/Gain', 'Ki_gain', 200, RI, 50, 36, {'Gain', v.I});
    blk(s, 'simulink/Math Operations/Gain', 'Kd_gain', 200, RD, 50, 36, {'Gain', v.D});

    add_sum(s, 'SumI', '++', [320 RI]);
    blk(s, 'simulink/Continuous/Integrator', 'Integ', 420, RI, 30, 30, ...
        {'InitialCondition','0'});
    blk(s, 'simulink/Continuous/Transfer Fcn', 'PseudoD', 420, RD, 60, 36, ...
        {'Numerator', ['[' v.N ' 0]'], 'Denominator', ['[1 ' v.N ']']});

    add_sum(s, 'SumPI', '++', [540 RP]);          % P + I
    add_sum(s, 'SumU',  '++', [620 RP]);          % (P+I) + D  = tau_raw
    blk(s, 'simulink/Discontinuities/Saturation', 'Sat', 700, RP, 30, 30, ...
        {'UpperLimit', v.Lim, 'LowerLimit', ['-' v.Lim]});

    %  1번(왼쪽)에 tau_raw, 2번(아래)에 tau_sat 을 넣는다. 아래쪽 포트는 밑에서만
    %  접근할 수 있으므로, 위에 있는 Sat 이 그쪽으로 간다 — 그 한 선만 두 번 꺾인다.
    add_sum(s, 'SumAW', '-+', [760 RAW]);         % -tau_raw + tau_sat
    blk(s, 'simulink/Math Operations/Gain', 'Kb_gain', 560, RBK, 50, 36, ...
        {'Gain', v.Kb, 'Orientation','left'});    % 출력이 왼쪽을 본다

    % --- 배선 : 갈래마다 자기 높이에서 직선으로 --------------------------
    lane_line(s, 'e', 1, 'Kp_gain', 1, 130);
    ex = port_xy(s, 'e', 'Outport', 1);
    lane_line(s, 'e', 1, 'Ki_gain', 1, ex(1));
    lane_line(s, 'e', 1, 'Kd_gain', 1, ex(1));
    add_line(s, 'Ki_gain/1', 'SumI/1');
    straight(s, {'SumI','Integ'; 'Kd_gain','PseudoD'; ...
                 'Kp_gain','SumPI'; 'SumPI','SumU'; 'SumU','Sat'; 'Sat','tau'});
    lane_line(s, 'Integ',   1, 'SumPI', 2, 540);   % I 는 아래에서 올라온다
    lane_line(s, 'PseudoD', 1, 'SumU',  2, 620);   % D 도 아래에서 올라온다
    %  tau_raw 는 왼쪽 포트로 곧장 — 꺾임 1회
    ux = port_xy(s, 'SumU', 'Outport', 1);
    lane_line(s, 'SumU', 1, 'SumAW', 1, ux(1));

    %  tau_sat 은 아래쪽 포트라 밑에서 올라와야 한다 — 이 모델에서 유일한 2회 꺾임
    a = port_xy(s, 'Sat',   'Outport', 1);
    b = port_xy(s, 'SumAW', 'Inport',  2);
    add_line(s, [a; a(1) RDET; b(1) RDET; b]);

    wx = port_xy(s, 'SumAW', 'Outport', 1);
    lane_line(s, 'SumAW', 1, 'Kb_gain', 1, wx(1));
    lane_line(s, 'Kb_gain', 1, 'SumI',    2, 320);

    note(s, [ ...
        'PID 를 블록으로 직접 조립한 것. 라이브러리 PID 블록 안도 이것과 같다.' newline ...
        '' newline ...
        '  P 갈래  : 오차 x Kp                        지금 얼마나 틀렸는가' newline ...
        '  I 갈래  : 오차를 시간에 걸쳐 쌓음            계속 틀리고 있으면 더 밀어라' newline ...
        '  D 갈래  : 오차가 줄어드는 속도 x Kd          곧 도착하니 브레이크' newline ...
        '' newline ...
        'D 갈래에 순수 미분(Derivative 블록)을 쓰지 않는 이유' newline ...
        '  미분은 빠른 신호일수록 크게 키운다. 센서 잡음이 제일 빠른 신호다.' newline ...
        '  Nf*s/(s+Nf) 는 느린 변화에는 미분처럼, 빠른 변화에는 이득이 Nf 에서 멈춘다.' newline ...
        '  = 미분 + 저역통과필터. 이것을 pseudo-derivative 라고 부른다.' newline ...
        '' newline ...
        '적분기 되감기 (안티와인드업)' newline ...
        '  Sat 에서 잘려 나간 만큼 (tau_sat - tau_raw) 을 Kb 배 해서 적분기 입력에 더한다.' newline ...
        '  포화 중에는 이 값이 음수라 적분기가 더 쌓이지 못한다.' newline ...
        '  Kb = 0 으로 두면 되감기가 사라진다. 그것이 와인드업이다.'], 45, RBK+90);
end

% =====================================================================
% 곁들이 실험 — 순수 미분 vs pseudo-derivative (포트 없는 서브시스템)
% =====================================================================
function addDcompare(mdl, xy)
    s = add_subsys(mdl, 'Dcompare', [xy(1) xy(2) xy(1)+150 xy(2)+60], {}, {}, ...
                   gnc_colour('measurement'));

    %  Scope 를 먼저 놓고 세 입력 포트의 높이를 **읽어서** 줄 높이로 쓴다.
    %  포트 간격을 계산으로 맞추면 몇 px 어긋나 세 선이 전부 사선이 된다.
    blk(s, 'simulink/Sinks/Scope', 'Scope_D', 760, 220, 30, 280, ...
        {'NumInputPorts','3'});
    R = zeros(1,3);
    for k = 1:3
        q = port_xy(s, 'Scope_D', 'Inport', k);  R(k) = q(2);
    end
    R1 = R(1); R2 = R(2); R3 = R(3);

    blk(s, 'simulink/Sources/Sine Wave',    'SineTrue', 80,  R1, 50, 50, ...
        {'Amplitude','1','Frequency','0.5'});
    blk(s, 'simulink/Sources/Random Number','NoiseD',   80,  R2, 50, 50, ...
        {'Mean','0','Variance','4e-4','Seed','777','SampleTime','0.01'});
    add_sum(s, 'SumS', '++', [220 R1]);

    blk(s, 'simulink/Continuous/Derivative', 'Dpure',   380, R1, 60, 36, {});
    blk(s, 'simulink/Continuous/Transfer Fcn','Dpseudo',380, R2, 60, 36, ...
        {'Numerator','[Nf2 0]','Denominator','[1 Nf2]'});
    blk(s, 'simulink/Sources/Sine Wave',     'Dtrue',   380, R3, 50, 50, ...
        {'Amplitude','0.5','Frequency','0.5','Phase','pi/2'});

    add_line(s, 'SineTrue/1', 'SumS/1');
    lane_line(s, 'NoiseD', 1, 'SumS', 2, []);
    sxy = port_xy(s, 'SumS', 'Outport', 1);
    lane_line(s, 'SumS', 1, 'Dpure',   1, sxy(1));
    lane_line(s, 'SumS', 1, 'Dpseudo', 1, sxy(1));

    logs = {'dpure','Dpure'; 'dpseudo','Dpseudo'; 'dtrue','Dtrue'};
    for k = 1:3
        add_line(s, [logs{k,2} '/1'], sprintf('Scope_D/%d', k));   % 직선
        %  분기선은 출발 포트에서 수직으로 내려가 로깅 블록 입력으로 수평 진입 — 꺾임 1회.
        %  로깅 블록은 출발 포트보다 오른쪽에 둔다 (왼쪽 테두리 = a(1)+20)
        a = port_xy(s, logs{k,2}, 'Outport', 1);
        blk(s, 'simulink/Sinks/To Workspace', ['log_' logs{k,1}], a(1)+50, a(2)+45, ...
            60, 30, {'VariableName',['log_' logs{k,1}], 'SaveFormat','Timeseries'});
        b = port_xy(s, ['log_' logs{k,1}], 'Inport', 1);
        add_line(s, [a(1)+10 a(2); a(1)+10 b(2); b]);   % 본선 위 한 점에서 갈라짐
    end

    note(s, [ ...
        '잡음이 조금 섞인 sin(0.5t) 를 두 가지 방법으로 미분한다.' newline ...
        '  1번 순수 미분 (Derivative 블록)     2번 pseudo-derivative     3번 참값 0.5cos(0.5t)' newline ...
        '1번은 참값을 알아볼 수 없을 만큼 튄다. 2번은 참값에 붙어 있다.' newline ...
        '잡음의 크기가 아니라 잡음의 "빠르기"가 미분에서 증폭되기 때문이다.'], 80, R3+120);
end

% =====================================================================
% 로깅 — 포트 없는 서브시스템. 안에서 From 태그로 받는다
% =====================================================================
function addLogging(mdl, tags, xy)
%  Scope 의 입력 포트 높이를 **읽어서** 그 높이에 From 을 놓는다.
%  그러면 From -> Scope 가 전부 직선이 되고, To Workspace 는 그 선에서
%  한 번만 꺾어 내려 받는다. 통로를 지어내면 반드시 겹치거나 두 번 꺾인다.
    n = numel(tags);
    s = add_subsys(mdl, 'Logging', [xy(1) xy(2) xy(1)+130 xy(2)+60], {}, {}, ...
                   gnc_colour('measurement'));

    blk(s, 'simulink/Sinks/Scope', 'Scope_all', 460, 80 + (n-1)*30, ...
        30, 40 + 60*(n-1), {'NumInputPorts', num2str(n)});

    for k = 1:n
        q = port_xy(s, 'Scope_all', 'Inport', k);
        blk(s, 'simulink/Signal Routing/From', ['Fr_' tags{k}], 140, q(2), 60, 22, ...
            {'GotoTag', tags{k}});
        add_line(s, ['Fr_' tags{k} '/1'], sprintf('Scope_all/%d', k));   % 직선

        %  본선 위 한 점(a(1)+10)에서 수직으로 내려가 To Workspace 입력으로 수평 진입.
        %  꺾임 1회. 포트는 테두리 밖에 있어 x 를 맞추려 들면 몇 px 사선이 된다
        a = port_xy(s, ['Fr_' tags{k}], 'Outport', 1);
        blk(s, 'simulink/Sinks/To Workspace', ['log_' tags{k}], a(1)+50, q(2)+34, ...
            60, 30, {'VariableName', ['log_' tags{k}], 'SaveFormat','Timeseries'});
        b = port_xy(s, ['log_' tags{k}], 'Inport', 1);
        add_line(s, [a(1)+10 a(2); a(1)+10 b(2); b]);
    end
end

% =====================================================================
% 배치 · 생성 헬퍼
% =====================================================================
function x = chain(idx)
% 신호 사슬의 k 번째 칸의 중심 x 좌표
    x = 80 + 150*(idx-1);
end

function blk(sys, lib, name, cx, cy, w, h, params)
% 중심 좌표로 블록을 놓는다. 중심을 맞추면 한 줄 위의 선이 전부 직선이 된다.
    add_block(lib, [sys '/' name], ...
              'Position', round([cx-w/2, cy-h/2, cx+w/2, cy+h/2]));
    for k = 1:2:numel(params)
        set_param([sys '/' name], params{k}, params{k+1});
    end
end

function fcn(sys, name, cx, cy, w, h, code)
    blk(sys, 'simulink/User-Defined Functions/MATLAB Function', name, cx, cy, w, h, {});
    fpos = get_param([sys '/' name], 'Position');   % 포트가 생기며 블록이 멋대로 자란다
    ch = sfroot().find('-isa','Stateflow.EMChart','Path',[sys '/' name]);
    ch.Script = code;
    set_param([sys '/' name], 'Position', fpos);    % 다시 놓아야 포트 위치가 저장 뒤와 같아진다 (사선 방지)
end

function goto(sys, tag, cx, cy)
    blk(sys, 'simulink/Signal Routing/Goto', ['Go_' tag], cx, cy, 60, 22, ...
        {'GotoTag', tag, 'TagVisibility','global'});
end

function from(sys, tag, sfx, cx, cy)
    blk(sys, 'simulink/Signal Routing/From', ['Fr_' tag '_' sfx], cx, cy, 60, 22, ...
        {'GotoTag', tag});
end

function straight(sys, pairs)
% 같은 높이에 있는 블록끼리 직선으로 잇는다
    for k = 1:size(pairs,1)
        add_line(sys, [pairs{k,1} '/1'], [pairs{k,2} '/1']);
    end
end

function note(sys, txt, x, y)
    n = Simulink.Annotation([sys '/note']);
    n.Text = txt;
    n.Position = [x y];
end

function stamp(m, y, txt)
% 모델 설명은 항상 도면 아래에 둔다. 위에 두면 블록과 겹친다
    note(m, txt, 60, y);
end

function paint(sys, pairs)
% 역할별 배경색. 색표는 _tools/gnc_colour.m 하나뿐이다
    for k = 1:size(pairs,1)
        set_param([sys '/' pairs{k,1}], 'BackgroundColor', gnc_colour(pairs{k,2}));
    end
    % 태그와 스코프는 전부 회색. 신호 흐름이 아니라 배선·관찰이기 때문
    for bt = {'Goto','From','Scope','ToWorkspace'}
        b = find_system(sys, 'SearchDepth',1, 'BlockType', bt{1});
        for i = 1:numel(b)
            set_param(b{i}, 'BackgroundColor', gnc_colour('measurement'));
        end
    end
end

function solver(m, name, step, stop)
    set_param(m, 'SolverType','Fixed-step', 'SolverName',name, ...
                 'FixedStep',step, 'StopTime',stop, 'SimulationMode','normal');
end

function fresh(m)
    if bdIsLoaded(m), close_system(m, 0); end
    if isfile([m '.slx']), delete([m '.slx']); end
    new_system(m); load_system(m);
end

function finish(m)
    mss_style(m);
    save_system(m); close_system(m, 0);
    fprintf('  [OK] %s\n', m);
end
