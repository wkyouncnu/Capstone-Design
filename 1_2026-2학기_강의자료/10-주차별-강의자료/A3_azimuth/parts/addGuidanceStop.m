% =====================================================================
% 사슬 1 · 4단에서 생김  Guidance (도착 판정) — 다 섰으면 gate 를 닫는다
% =====================================================================
%   3단까지는 gate 가 늘 1 이었다. 4단에서 처음으로 **도착을 적는 법**이 생긴다.
%
%     도착 = 거리가 R_stop 안이고 · 선수각 오차가 5 deg 안이고 · 속력이 U_stop 아래
%     도착하면 phase 가 0 -> 1 로 올라가고 gate 가 1 -> 0 으로 닫힌다
%     한 번 올라간 phase 는 내려오지 않는다 (래치)
%
%   gate 는 **표시등이지 스위치가 아니다** (2026-11-13 수정)
%     처음에는 gate 를 바깥 고리의 속도 지령에 곱했다 — 도착하면 지령을 끊는
%     구조였다. 이것이 목표점을 지나쳐 서는 원인이었다.
%       - 지령을 끊는 순간 비례항이 함께 사라진다. 멈추려는 쪽으로 걸려 있던
%         큰 음의 힘(실측 -150 N 가량)이 한 스텝에 없어진다
%       - 순항 중 쌓인 안쪽 고리 PI 의 적분항은 그대로 남는다 (실측 +94.5 N)
%       - 결과: 제동력만 사라지고 미는 힘은 남아 배가 다시 앞으로 간다.
%         실측에서 t = 31.2 s 에 X_c 가 -52.8 N -> +79.5 N 으로 튀었고,
%         1.12 m 까지 좁혔던 거리가 2.05 m 로 벌어졌다 — 되돌아오지 못한다
%     그래서 곱셈을 걷어 냈다 (parts/addOuterLoop.m). 제자리 유지(DP)가 곧
%     정지다 — 지령을 따로 끊을 일이 없다. gate 를 읽는 곳은 이제 셋뿐이다:
%     AutoStop · A3_plot · 로깅
%
%   판정에 **속력**이 들어가는 까닭
%     거리만 보면 아직 1 m/s 로 달리는 중에 판정이 선다. gate 가 아무것도
%     끊지 않는 지금도 그것은 거짓 기록이다 — "도착했다" 가 아니라 "도착선을
%     지나는 중" 이다. 속력 조건을 넣으면 판정이 **다 선 뒤에** 서므로,
%     gate 는 배를 세우는 장치가 아니라 **다 섰음을 적는 장치**가 된다
%
%   왜 래치가 필요한가
%     한 번 도착했으면 끝이라고 기억해야 한다. 판정이 깜빡이면 AutoStop 이
%     세던 초를 계속 되돌려 시뮬레이션이 끝나지 않는다.
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
              'Position', [330 60 510 470]);
    sl_fcn(ss, 'TaskHold', strjoin({
      'function [x_ref, y_ref, psi_ref, gate, phase] = TaskHold(x_n, y_n, psi, U, q, Rs, Ua, ph_prev)'
      '%#codegen'
      '%  한 점·한 선수각을 목표로 주고, 거기 가서 **섰는지** 판정한다.'
      '%'
      '%    U  = 대지속력 [m/s]      운동모델이 낸 sqrt(u^2 + v^2)'
      '%    q  = [x_d; y_d; psi_d]   목표 자세 (psi_d 는 rad)'
      '%    Rs = R_stop              도착으로 보는 반지름 [m]'
      '%    Ua = U_stop              도착으로 보는 속력 한계 [m/s]'
      '%'
      '%  gate = 1 이면 바깥 고리가 속도 지령을 낸다. 0 이면 0 을 내어 배가 선다.'
      'x_ref = q(1);  y_ref = q(2);  psi_ref = q(3);'
      'd = sqrt((x_ref - x_n)^2 + (y_ref - y_n)^2);'
      'e = atan2(sin(psi_ref - psi), cos(psi_ref - psi));'
      'ph = ph_prev;'
      'if ph < 1 && d < Rs && abs(e) < 5*pi/180 && U < Ua'
      '    ph = 1;                   %  도착 — 한 번 올라가면 내려오지 않는다'
      'end'
      'phase = ph;'
      'gate  = double(ph < 1);'
      }, newline));

    %  대지속력은 운동모델 출력이다 — 적분기를 지나 오므로 대수 루프가 생기지 않는다
    add_block('simulink/Signal Routing/From', [ss '/Fr_U'], ...
              'Position', [150 200 260 222], 'GotoTag', 'U');

    sl_const(ss, 'q',  'stop_q',  170, 250);
    sl_const(ss, 'Rs', 'R_stop',  170, 300);
    sl_const(ss, 'Ua', 'U_stop',  170, 350);
    row_feed(ss, 'TaskHold', {'x_n','y_n','psi','Fr_U','q','Rs','Ua',''});

    %  단계 래치 — 한 스텝 전 값을 되먹여 대수 루프를 끊는다
    b = port_xy(ss, 'TaskHold', 'Inport', 8);
    add_block('simulink/Discrete/Unit Delay', [ss '/PhaseDly'], ...
              'Position', [200 b(2)-15 240 b(2)+15], ...
              'InitialCondition','0', 'SampleTime','Ts_ctrl', ...
              'Description', ['phase 래치가 자기 자신을 입력으로 받으므로 ' ...
               '그대로 되먹이면 대수 루프가 된다. 한 스텝 전 값을 쓰는 것 ' ...
               '말고는 끊을 방법이 없는 자리다. 표본 간격을 고정 스텝' ...
               '(Ts_ctrl)과 같게 두어 연속 솔버(ode4)와 어긋나지 않는다.']);
    add_line(ss, 'PhaseDly/1', 'TaskHold/8');

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
        '도착 판정 하나가 새로 생김 — 거리 < R_stop · 선수각 오차 < 5 deg · 속력 < U_stop' newline ...
        '속력 조건을 빼면 아직 달리는 중에 판정이 서서 도착 기록이 거짓이 됨' newline ...
        'phase 는 한 번 올라가면 내려오지 않음 (래치). Unit Delay 가 대수 루프를 끊음' newline ...
        'gate = 0 은 배를 세우는 장치가 아니라 **다 섰음을 적는 장치**임' newline ...
        'AutoStop 상자가 gate = 0 을 보고 stop_hold 초 뒤 시뮬레이션을 멈춤'], 330, 620);
end
