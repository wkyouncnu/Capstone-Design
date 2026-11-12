% =====================================================================
% 사슬 1 · 1단에서 생김  AutoStop (오차 판정) — 목표에 닿으면 스스로 멈춘다
% =====================================================================
%   1단은 유도부가 상수다 (addGuidanceConst). gate 가 끝까지 1 이므로 배는
%   목표에 닿아도 그 자리를 잡고 있고, 시뮬레이션은 T_run 까지 돈다 —
%   도착한 뒤의 긴 정지 구간이 그대로 기록에 섞인다.
%
%   그래서 **gate 를 보지 않고 오차를 직접 보는** 정지 판정을 따로 둔다.
%     정지 조건 = 위치 오차가 e_stop 안이고, 선수각 오차가 epsi_stop 안이며,
%                 그 상태가 stop_hold 초 이어질 때
%
%   2·3단의 AutoStop (addAutoStop) 과 다른 점
%     | 상자            | 무엇을 보는가            | 어디서 쓰는가 |
%     | addAutoStop     | gate 가 0 이 된 뒤의 시간 | 2·3단        |
%     | addAutoStopErr  | 위치·선수각 오차 자체     | 1단 (·4단)   |
%     2·3단은 유도부가 도착 판정을 이미 하므로 gate 하나만 보면 된다.
%     1단은 도착 판정이 아예 없으므로 여기서 오차를 재야 한다.
%
%   왜 "유지" 를 요구하는가 (stop_hold)
%     오차가 임계를 한 번 스치는 것과 거기 머무는 것은 다르다. 지나가는
%     순간에 멈추면 정착 성능을 재지 못한다. 적분기를 **오차가 작은 동안만**
%     돌려 머문 시간을 세고, stop_hold 초를 넘으면 멈춘다.
%
%   끄는 법
%     stop_on = 0 — 끝까지 (T_run 까지) 돈다. 도착 후 제자리 유지가 오래
%     보고 싶을 때 쓴다. 상자를 빼지 않아도 되므로 모델 모양이 바뀌지 않는다.
function addAutoStopErr(m, x, y)
    s = add_subsys(m, 'AutoStop', [x y x+150 y+80], {}, {}, gnc_colour('logging'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [s '/StopChk'], ...
              'Position', [330 60 530 470]);
    sl_fcn(s, 'StopChk', strjoin({
      'function notdone = StopChk(x_ref, y_ref, psi_ref, x_n, y_n, psi, p)'
      '%#codegen'
      '%  StopChk — 아직 도착하지 않았는가. 1 이면 "아직", 0 이면 "도착"'
      '%'
      '%  ===== 입력 =========================================================='
      '%    x_ref  [m]    목표 북쪽 위치'
      '%    y_ref  [m]    목표 동쪽 위치'
      '%    psi_ref[rad]  목표 선수각'
      '%    x_n    [m]    실제 북쪽 위치'
      '%    y_n    [m]    실제 동쪽 위치'
      '%    psi    [rad]  실제 선수각'
      '%    p      [-]    stop_prm'
      '%      p(1) = e_stop    [m]    위치 오차 임계'
      '%      p(2) = epsi_stop [rad]  선수각 오차 임계'
      '%      p(3) = stop_on   [0/1]  0 이면 절대 멈추지 않는다'
      '%'
      '%  ===== 출력 =========================================================='
      '%    notdone [0/1]  1 = 아직 도착하지 않음. 뒤쪽 적분기의 리셋으로 쓴다'
      '%'
      '%  선수각 오차는 **반드시** atan2(sin, cos) 로 감는다. psi_ref - psi 를'
      '%  그대로 쓰면 +180 deg 와 -180 deg 가 360 deg 차이로 읽혀, 다 왔는데도'
      '%  영원히 도착하지 않는다 (오류 메시지 없이 안 멈춘다).'
      'd = sqrt((x_ref - x_n)^2 + (y_ref - y_n)^2);'
      'e = atan2(sin(psi_ref - psi), cos(psi_ref - psi));'
      'ok = (p(3) > 0.5) && (d <= p(1)) && (abs(e) <= p(2));'
      'notdone = double(~ok);'
      }, newline));

    sl_const(s, 'p', 'stop_prm', 150, 500);
    add_line(s, 'p/1', 'StopChk/7', 'autorouting','on');

    tags = {'x_ref','y_ref','psi_ref','x_n','y_n','psi'};
    for k = 1:numel(tags)
        pb = port_xy(s, 'StopChk', 'Inport', k);
        add_block('simulink/Signal Routing/From', [s '/Fr_' tags{k}], ...
                  'Position', [160 pb(2)-11 270 pb(2)+11], 'GotoTag', tags{k});
        add_line(s, ['Fr_' tags{k} '/1'], sprintf('StopChk/%d', k));
    end

    %  머문 시간 세기 — notdone 이 1 인 동안 적분기를 0 에 묶는다.
    %  'level' 이라야 처음부터 notdone = 1 일 때도 리셋이 걸린다 ('rising' 은 안 걸린다)
    add_block('simulink/Sources/Constant', [s '/One'], ...
              'Value','1', 'Position',[600 110 650 140]);
    add_block('simulink/Continuous/Integrator', [s '/HeldFor'], ...
              'ExternalReset','level', 'InitialCondition','0', ...
              'Position',[720 165 760 205]);
    add_block('simulink/Sources/Constant', [s '/Hold'], ...
              'Value','stop_hold', 'Position',[720 260 820 290]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/Done'], ...
              'Operator','>=', 'Position',[870 180 900 210]);
    add_block('simulink/Sinks/Stop Simulation', [s '/StopSim'], ...
              'Position',[960 180 1000 210]);

    add_line(s,'One/1',     'HeldFor/1','autorouting','on');
    add_line(s,'StopChk/1', 'HeldFor/2','autorouting','on');
    add_line(s,'HeldFor/1', 'Done/1',   'autorouting','on');
    add_line(s,'Hold/1',    'Done/2',   'autorouting','on');
    add_line(s,'Done/1',    'StopSim/1','autorouting','on');

    sl_note(s, 'n_as', [ ...
        '정지 판정 — 위치 오차 <= e_stop 이고 선수각 오차 <= epsi_stop 인 상태가' newline ...
        'stop_hold 초 이어지면 시뮬레이션을 끝낸다 (gate 를 보지 않는다)' newline ...
        '적분기는 오차가 작은 동안만 돈다 — 임계를 스치는 순간에는 멈추지 않음' newline ...
        'stop_on = 0 으로 두면 끝까지 (T_run 까지) 돈다'], 330, 570);
end
