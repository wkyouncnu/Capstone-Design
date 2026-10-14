% =====================================================================
% 사슬 1 · 4단에서 생김  Guidance (도착 판정) — 목표에 닿으면 gate 를 닫는다
% =====================================================================
%   3단까지는 gate 가 늘 1 이었다. 배는 목표에 닿아도 속도 지령을 계속 받아
%   그 자리를 "잡고" 있었다. 4단에서 처음으로 **멈추는 법**이 생긴다.
%
%     도착 = 거리가 R_stop 안이고 선수각 오차가 5 deg 안
%     도착하면 phase 가 0 -> 1 로 올라가고 gate 가 1 -> 0 으로 닫힌다
%     한 번 올라간 phase 는 내려오지 않는다 (래치)
%
%   왜 래치가 필요한가
%     gate 가 닫히면 속도 지령이 0 이 되어 배가 관성으로 조금 더 간다. 그러면
%     거리가 R_stop 을 다시 넘어 gate 가 열리고, 또 닫히고 — 깜빡인다. 한 번
%     도착했으면 끝이라고 기억해야 한다.
%
%   왜 Unit Delay 가 끼는가
%     phase 는 자기 자신의 입력이다. 그대로 되먹이면 대수 루프(algebraic loop)가
%     되어 Simulink 가 풀지 못한다. 한 스텝 전 값을 쓰면 끊어진다.
function addGuidanceStop(m, x, y)
    ss = add_subsys(m, 'Guidance', [x y x+190 y+150], ...
                    {'x_n','y_n','psi'}, ...
                    {'x_ref','y_ref','psi_ref','gate','phase'}, ...
                    gnc_colour('guidance'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/TaskHold'], ...
              'Position', [330 60 510 400]);
    sl_fcn(ss, 'TaskHold', strjoin({
      'function [x_ref, y_ref, psi_ref, gate, phase] = TaskHold(x_n, y_n, psi, q, Rs, ph_prev)'
      '%#codegen'
      '%  한 점·한 선수각을 목표로 주고, 거기 닿았는지 판정한다.'
      '%'
      '%    q  = [x_d; y_d; psi_d]   목표 자세 (psi_d 는 rad)'
      '%    Rs = R_stop              도착으로 보는 반지름 [m]'
      '%'
      '%  gate = 1 이면 바깥 고리가 속도 지령을 낸다. 0 이면 0 을 내어 배가 선다.'
      'x_ref = q(1);  y_ref = q(2);  psi_ref = q(3);'
      'd = sqrt((x_ref - x_n)^2 + (y_ref - y_n)^2);'
      'e = atan2(sin(psi_ref - psi), cos(psi_ref - psi));'
      'ph = ph_prev;'
      'if ph < 1 && d < Rs && abs(e) < 5*pi/180'
      '    ph = 1;                   %  도착 — 한 번 올라가면 내려오지 않는다'
      'end'
      'phase = ph;'
      'gate  = double(ph < 1);'
      }, newline));

    sl_const(ss, 'q',  '[x_d; y_d; psi_d]', 170, 250);
    sl_const(ss, 'Rs', 'R_stop',            170, 300);
    row_feed(ss, 'TaskHold', {'x_n','y_n','psi','q','Rs',''});

    %  단계 래치 — 한 스텝 전 값을 되먹여 대수 루프를 끊는다
    b = port_xy(ss, 'TaskHold', 'Inport', 6);
    add_block('simulink/Discrete/Unit Delay', [ss '/PhaseDly'], ...
              'Position', [200 b(2)-15 240 b(2)+15], ...
              'InitialCondition','0', 'SampleTime','Ts_ctrl', ...
              'Description', ['phase 래치가 자기 자신을 입력으로 받으므로 ' ...
               '그대로 되먹이면 대수 루프가 된다. 한 스텝 전 값을 쓰는 것 ' ...
               '말고는 끊을 방법이 없는 자리다. 표본 간격을 고정 스텝' ...
               '(Ts_ctrl)과 같게 두어 연속 솔버(ode4)와 어긋나지 않는다.']);
    add_line(ss, 'PhaseDly/1', 'TaskHold/6');

    outs = {'x_ref','y_ref','psi_ref','gate','phase'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'TaskHold', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [700 p(2)-10 730 p(2)+10]);
        add_line(ss, sprintf('TaskHold/%d',k), [outs{k} '/1']);
    end
    drop_tag(ss, 'TaskHold', 5, 'phase_prev', 120);
    pb = port_xy(ss, 'PhaseDly', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_phase_prev'], ...
              'Position', [110 pb(2)-11 180 pb(2)+11], 'GotoTag','phase_prev');
    add_line(ss, 'Fr_phase_prev/1', 'PhaseDly/1');

    sl_note(ss, 'n_g', [ ...
        '도착 판정 하나가 새로 생김 — 거리 < R_stop 이고 선수각 오차 < 5 deg' newline ...
        'phase 는 한 번 올라가면 내려오지 않음 (래치). Unit Delay 가 대수 루프를 끊음' newline ...
        'gate = 0 이 되면 바깥 고리가 속도 지령을 0 으로 내려 배가 섬' newline ...
        'AutoStop 상자가 gate = 0 을 보고 stop_hold 초 뒤 시뮬레이션을 멈춤'], 330, 550);
end
