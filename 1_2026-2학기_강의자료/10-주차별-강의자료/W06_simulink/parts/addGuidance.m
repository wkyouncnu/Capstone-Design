% =====================================================================
% 사슬 1 · 5단에서 생김  Guidance — 과업이 요구하는 목표 자세 (x_ref, y_ref, psi_ref)
% =====================================================================
%   5주차의 유도부는 "다음 웨이포인트를 향한 방향"만 내놓았다. 6주차는 위치까지
%   내놓는다. 과업 세 가지를 한 블록이 처리한다 (task_mode 로 고른다).
%
%     task_mode = 1  위치·선수각 유지 — 한 점에 그 자세로 서 있기
%     task_mode = 2  순수 횡이동(pure sway) — 선수각을 지키며 옆으로만
%     task_mode = 3  접안 — 접근점 -> 선수각 정렬 -> 전진 접안, 세 단계
%
%   왜 단계(phase)를 기억해야 하는가
%     접안은 "지금 어느 단계인가"에 따라 목표가 달라진다. 단계가 올라간 뒤에는
%     내려오지 않아야 한다(래치). 그런데 단계는 자기 자신의 입력이 되므로 그대로
%     되먹이면 대수 루프가 된다. Unit Delay 를 한 칸 끼워 한 스텝 전 값을 쓴다.
%
%   dock_on 스위치 — 단계를 나누는 값어치를 재는 자리다
%     dock_on = 1  접근점 -> 선수각 정렬 -> 옆걸음, 세 단계를 밟는다
%     dock_on = 0  선석으로 바로 간다. 목표는 처음부터 선석이고 선수각은 가는
%                  방향으로 둔다 — 즉 **어느 현을 댈지 고르지 않는다**
%     거리로는 두 벌이 거의 같게 닿는다. 다른 것은 닿을 때의 선수각이다.
%     계류줄·방충재·승하선 위치가 현에 따라 정해져 있으므로 그것이 성패를 가른다.
function addGuidance(m, x, y)
    ss = add_subsys(m, 'Guidance', [x y x+190 y+150], ...
                    {'x_n','y_n','psi'}, ...
                    {'x_ref','y_ref','psi_ref','gate','phase'}, ...
                    gnc_colour('guidance'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/TaskRef'], ...
              'Position', [330 60 510 560]);
    sl_fcn(ss, 'TaskRef', strjoin({
      'function [x_ref, y_ref, psi_ref, gate, phase] = TaskRef(x_n, y_n, psi, q, mode, phase_prev)'
      '%#codegen'
      '%  과업이 요구하는 목표 자세와 진행 단계를 내놓는다.'
      '%'
      '%    q(1:3)   위치유지 목표   north, east, 선수각 [rad]'
      '%    q(4:6)   횡이동 목표     north, east, 선수각 [rad]'
      '%    q(7:9)   접안 목표       north, east, 선수각 [rad]'
      '%    q(10)    R_dock      접근점에 닿았다고 보는 반지름 [m]'
      '%    q(11)    L_app       접안점에서 접근점까지의 거리 [m]'
      '%    q(12)    berth_side  +1 이면 부두가 좌현쪽 — 접근점이 우현쪽에 생긴다'
      '%    q(13)    R_stop      목표에 닿았다고 보는 반지름 [m]'
      '%    q(14)    dock_on     1 이면 세 단계를 밟고, 0 이면 선석으로 바로 간다'
      '%'
      '%  gate = 1 이면 바깥 고리가 속도 지령을 낸다. 0 이면 멈춘다.'
      'hx = q(1);  hy = q(2);  hpsi = q(3);'
      'sx = q(4);  sy = q(5);  spsi = q(6);'
      'dx = q(7);  dy = q(8);  dpsi = q(9);'
      'Rd = q(10); La = q(11); sd = q(12); Rs = q(13);  don = q(14);'
      'ph = phase_prev;'
      ''
      'if mode == 1 || mode == 2'
      '    %  한 점·한 선수각으로 가서 서 있는다. 1 과 2 는 목표만 다르다'
      '    if mode == 1'
      '        x_ref = hx;  y_ref = hy;  psi_ref = hpsi;'
      '    else'
      '        x_ref = sx;  y_ref = sy;  psi_ref = spsi;'
      '    end'
      '    d = sqrt((x_ref - x_n)^2 + (y_ref - y_n)^2);'
      '    e = atan2(sin(psi_ref - psi), cos(psi_ref - psi));'
      '    if ph < 1 && d < Rs && abs(e) < 5*pi/180'
      '        ph = 1;                   %  도착 — 한 번 올라가면 내려오지 않는다'
      '    end'
      '    phase = ph;'
      '    gate  = double(ph < 1);'
      'else'
      '    %  접안 — 접근점은 접안점에서 부두 반대쪽으로 L_app 만큼 떨어진 점.'
      '    %  선수각 dpsi 로 들어가려면 접근점이 그 뒤쪽에 있어야 한다'
      '    ax = dx - sd*La*sin(dpsi);'
      '    ay = dy + sd*La*cos(dpsi);'
      '    if don < 0.5'
      '        %  단계를 나누지 않는 경우 — 목표가 처음부터 선석이다. 선수각은'
      '        %  가는 방향으로 두므로 어느 현을 댈지 고르지 못한다'
      '        x_ref = dx;  y_ref = dy;'
      '        psi_ref = atan2(dy - y_n, dx - x_n);'
      '        if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs'
      '            ph = 3;'
      '        end'
      '    elseif ph < 1'
      '        %  1단계 — 접근점으로 간다. 선수각은 가는 방향으로 둔다 (저항이 작다)'
      '        x_ref = ax;  y_ref = ay;'
      '        psi_ref = atan2(ay - y_n, ax - x_n);'
      '        if sqrt((ax - x_n)^2 + (ay - y_n)^2) < Rd'
      '            ph = 1;'
      '        end'
      '    elseif ph < 2'
      '        %  2단계 — 접근점에 머물며 선수각만 접안 선수각으로 돌린다'
      '        x_ref = ax;  y_ref = ay;  psi_ref = dpsi;'
      '        e = atan2(sin(dpsi - psi), cos(dpsi - psi));'
      '        if abs(e) < 5*pi/180'
      '            ph = 2;'
      '        end'
      '    else'
      '        %  3단계 — 선수각을 지킨 채 접안점으로 밀어 넣는다'
      '        x_ref = dx;  y_ref = dy;  psi_ref = dpsi;'
      '        if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs'
      '            ph = 3;'
      '        end'
      '    end'
      '    phase = ph;'
      '    gate  = double(ph < 3);'
      'end'
      }, newline));

    sl_const(ss, 'q',    'task_q',    170, 250);
    sl_const(ss, 'mode', 'task_mode', 170, 300);
    row_feed(ss, 'TaskRef', {'x_n','y_n','psi','q','mode',''});

    %  단계 래치 — 한 스텝 전 값을 되먹여 대수 루프를 끊는다
    b = port_xy(ss, 'TaskRef', 'Inport', 6);
    add_block('simulink/Discrete/Unit Delay', [ss '/PhaseDly'], ...
              'Position', [200 b(2)-15 240 b(2)+15], ...
              'InitialCondition','0', 'SampleTime','Ts_ctrl', ...
              'Description', ['phase 래치가 자기 자신을 입력으로 받으므로 ' ...
               '그대로 되먹이면 대수 루프가 된다. 한 스텝 전 값을 쓰는 것 ' ...
               '말고는 끊을 방법이 없는 자리다. 표본 간격을 고정 스텝' ...
               '(Ts_ctrl)과 같게 두어 연속 솔버(ode4)와 어긋나지 않는다.']);
    add_line(ss, 'PhaseDly/1', 'TaskRef/6');

    outs = {'x_ref','y_ref','psi_ref','gate','phase'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'TaskRef', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [700 p(2)-10 730 p(2)+10]);
        add_line(ss, sprintf('TaskRef/%d',k), [outs{k} '/1']);
    end
    drop_tag(ss, 'TaskRef', 5, 'phase_prev', 120);
    pb = port_xy(ss, 'PhaseDly', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_phase_prev'], ...
              'Position', [110 pb(2)-11 180 pb(2)+11], 'GotoTag','phase_prev');
    add_line(ss, 'Fr_phase_prev/1', 'PhaseDly/1');

    sl_note(ss, 'n_g', [ ...
        'task_mode 로 과업을 고름 — 1 위치·선수각 유지 / 2 순수 횡이동 / 3 접안' newline ...
        'phase 는 한 번 올라가면 내려오지 않음 (래치). Unit Delay 가 대수 루프를 끊음' newline ...
        'gate = 0 이 되면 바깥 고리가 속도 지령을 0 으로 내려 배가 섬' newline ...
        'dock_on = 0 (q(14)) 이면 단계를 밟지 않고 선석으로 바로 감 — 댈 현을 못 고름'], 330, 700);
end
