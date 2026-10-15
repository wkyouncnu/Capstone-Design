% =====================================================================
% 사슬 1 · 7단에서 생김  Guidance (전진 접안) — 선수를 선석으로 들이댄다
% =====================================================================
%   5단의 접안은 옆걸음이었다 (lateral approach). 선석과 나란히 서서 횡방향
%   으로만 붙였다. 7단은 같은 접근점에서 **선수를 선석으로 돌려** 전진으로
%   붙인다 (bow-first). 실험실 논문 Bang et al. (2025) 3.2.1 절이 이 전략이다.
%
%   달라지는 것은 접안 선수각 하나뿐이다
%
%       옆걸음 (5단)  psi_f = psi_t                 선석 방위와 같게
%       전진   (7단)  psi_f = psi_t - side*pi/2     선석 방위에 수직하게
%
%     여기서 psi_t 는 선석(접안시설)의 방위이고 side 는 berth_side 다.
%     side = +1 이면 부두가 좌현쪽이므로, 선수를 부두로 돌리려면 좌현쪽
%     (= -90 deg) 으로 틀어야 한다.
%
%   접근점은 논문 식 (5) 꼴로 적는다 — 최종 접안점에서 접안 선수각의
%   뒤쪽으로 L_app 만큼 물러난 점이다
%
%       ax = dx - L_app*cos(psi_f)
%       ay = dy - L_app*sin(psi_f)
%
%   이 두 식을 펼치면 5단의 접근점과 같은 점이 된다
%
%       cos(psi_f) =  side*sin(psi_t),   sin(psi_f) = -side*cos(psi_t)
%       -> ax = dx - side*L_app*sin(psi_t),  ay = dy + side*L_app*cos(psi_t)
%
%   즉 **같은 점에서 선수각만 90 deg 틀면 옆걸음이 전진으로 바뀐다.** 3단계
%   에서 바깥 고리가 선체좌표로 돌린 오차가 e_y 가 아니라 e_x 로 남기 때문
%   이다 (OuterLoop 의 회전행렬을 다시 보면 된다). 그래서 3단계에 드는 횡추력
%   이 크게 줄어든다 — 측정값은 W06_berth_compare 가 5·7·8단을 나란히 찍는다
%   (max|F_B| 7단 176.5 N, 5단 189.6 N, 8단 210.6 N. 2026-10-15 측정).
%
%   그렇다고 선수추진기가 없어도 되는 것은 아니다
%     이 모델은 3단계도 위치제어로 한다. 2단계에서 돌아설 때 생긴 횡방향
%     오차는 선수추진기 없이는 지울 수 없어 끝까지 남는다 — W06_setup 뒤에
%     bow_on = 0 으로 두고 돌리면 옆축 1.818 m 가 남은 채 300 s 를 다 쓴다.
%     논문의 전진 접안은 3단계를 위치제어가 아니라 전후 속도 + 선수각 제어로
%     하므로 추진기 둘뿐인 배도 할 수 있다. 그 유도부는 이 사다리에 아직 없다.
%
%   논문의 목표점과 강의 모델의 목표점
%     논문 식 (3) 의 접안 목표는 접안시설 위의 점 (x_t, y_t) 이고, 최종
%     접안점은 거기서 선체 길이의 절반과 여유를 뺀 점이다 — 식 (9) 의
%     (LOA/2 + 여유). 강의 모델의 dock_north·dock_east 는 **이미 물러난
%     최종 접안점**으로 둔다. 선체 치수를 더 넣으면 식이 둘로 늘어나고
%     단계마다 숫자가 달라져 사다리가 흐려진다.
%
%   gate 가 0/1 스위치가 아니라 **감속 계수**다 (7단에서 달라진 둘째 자리)
%     5단 옆걸음은 느린 축(횡)으로 들어오므로 도착 반지름에서 지령을 끊어도
%     타성이 1 m 를 넘지 않는다. 7단은 빠른 축(전후)으로 들어오므로 그대로
%     두면 선석을 1.7 m 지나친 자리에서 끝났다 — 끝 오차가 R_stop(1.5 m)
%     보다 컸고, 선석을 지나친 쪽이므로 접안시설과 겹치는 자리였다.
%
%     지나치는 까닭은 추력이 부족해서가 아니다. 전진 15 m 를 u_max 로 달리는
%     동안 속도 PI 의 적분기가 쌓이고(지령 1.5 m/s 를 아직 못 따라간 상태),
%     gate 가 닫혀 지령이 0 이 되어도 그 적분이 몇 초 동안 앞으로 밀어낸다.
%     적분기 출력이 포화선(2*F_max)까지 가지 않으므로 역계산도 걸리지 않는다.
%
%     그래서 끊지 않고 **줄인다**
%
%         gate = min(1, d_target / R_brake)      d_target = 목표점까지 거리
%
%     목표점에서 R_brake 안으로 들어오면 속도 지령이 거리에 비례해 줄고,
%     바깥 고리의 비례 제어까지 합쳐 지령이 거리의 제곱으로 떨어진다. 지령이
%     실제 속도보다 먼저 내려가므로 적분기는 **아직 거리가 남은 동안** 되감기고,
%     접안점에는 이미 느린 속도로 닿는다.
%
%   도착 판정에 속도 조건을 더한다
%     거리만 보면 빠른 속도로 지나가는 순간에도 도착으로 보고 gate 를 0 으로
%     래치해 버린다. 한 번 래치되면 다시 열리지 않으므로(깜빡임을 막으려고
%     그렇게 두었다 — buildStage4 머리글) 지나친 오차를 되돌릴 길이 없다.
%     "가까이 있고 **거의 멈춰** 있을 때" 를 도착으로 본다
%
%         d < R_stop  이고  sqrt(u^2 + v^2) < U_berth
%
%     그래서 유도부가 속도 u·v 를 입력으로 받는다 (5단 유도부는 받지 않는다).
function addGuidanceFront(m, x, y)
    ss = add_subsys(m, 'Guidance', [x y x+190 y+150], ...
                    {'x_n','y_n','psi','u','v'}, ...
                    {'x_ref','y_ref','psi_ref','gate','phase'}, ...
                    gnc_colour('guidance'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/TaskFront'], ...
              'Position', [330 60 510 520]);
    sl_fcn(ss, 'TaskFront', strjoin({
      'function [x_ref, y_ref, psi_ref, gate, phase] = TaskFront(x_n, y_n, psi, u, v, q, phase_prev)'
      '%#codegen'
      '%  전진 접안(bow-first)이 요구하는 목표 자세와 진행 단계를 내놓는다.'
      '%'
      '%    q(7:9)   접안 목표       north, east, 선석 방위 [rad]'
      '%    q(10)    R_dock      접근점에 닿았다고 보는 반지름 [m]'
      '%    q(11)    L_app       접안점에서 접근점까지의 거리 [m]'
      '%    q(12)    berth_side  +1 이면 부두가 좌현쪽'
      '%    q(13)    R_stop      접안점에 닿았다고 보는 반지름 [m]'
      '%    q(15)    R_brake     이 거리 안에서 접근 속도를 줄인다 [m]'
      '%    q(16)    U_berth     도착으로 보는 속도 한계 [m/s]'
      '%'
      '%  gate 는 0/1 스위치가 아니라 감속 계수다 — 목표점까지 거리에 비례해'
      '%  속도 지령을 줄이고, 도착(가깝고 느림)하면 0 으로 래치한다.'
      'dx = q(7);  dy = q(8);  dpsi = q(9);'
      'Rd = q(10); La = q(11); sd = q(12); Rs = q(13);'
      'Rb = q(15); Ub = q(16);'
      ''
      '%  접안 선수각 — 선석 방위에 수직. 선수가 부두를 향한다'
      'psi_f = dpsi - sd*pi/2;'
      ''
      '%  접근점 — 접안점에서 접안 선수각의 뒤쪽으로 L_app (논문 식 5)'
      'ax = dx - La*cos(psi_f);'
      'ay = dy - La*sin(psi_f);'
      ''
      'ph = phase_prev;'
      'if ph < 1'
      '    %  1단계 — 접근점으로 간다. 선수각은 가는 방향으로 둔다 (저항이 작다)'
      '    x_ref = ax;  y_ref = ay;'
      '    psi_ref = atan2(ay - y_n, ax - x_n);'
      '    if sqrt((ax - x_n)^2 + (ay - y_n)^2) < Rd'
      '        ph = 1;'
      '    end'
      'elseif ph < 2'
      '    %  2단계 — 접근점에 머물며 선수각만 접안 선수각으로 돌린다'
      '    x_ref = ax;  y_ref = ay;  psi_ref = psi_f;'
      '    e = atan2(sin(psi_f - psi), cos(psi_f - psi));'
      '    if abs(e) < 5*pi/180'
      '        ph = 2;'
      '    end'
      'else'
      '    %  3단계 — 선수각을 지킨 채 전진으로 접안점에 붙인다'
      '    x_ref = dx;  y_ref = dy;  psi_ref = psi_f;'
      '    %  도착 = 가깝고 **거의 멈춰** 있을 때. 속도 조건이 없으면 빠르게'
      '    %  지나가는 순간에 래치되어 지나친 오차를 되돌릴 길이 없어진다'
      '    if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs && sqrt(u^2 + v^2) < Ub'
      '        ph = 3;'
      '    end'
      'end'
      'phase = ph;'
      ''
      '%  감속 — 목표점까지 거리가 R_brake 안으로 들면 속도 지령을 깎는다.'
      '%  바깥 고리의 비례 제어와 겹쳐 지령이 거리의 제곱으로 떨어지므로,'
      '%  지령이 실제 속도보다 먼저 내려가 속도 PI 의 적분이 되감긴다.'
      'if ph < 3'
      '    d_t = sqrt((x_ref - x_n)^2 + (y_ref - y_n)^2);'
      '    gate = min(1, d_t / Rb);'
      'else'
      '    gate = 0;'
      'end'
      }, newline));

    sl_const(ss, 'q', 'task_q', 170, 250);
    row_feed(ss, 'TaskFront', {'x_n','y_n','psi','u','v','q',''});

    %  단계 래치 — 한 스텝 전 값을 되먹여 대수 루프를 끊는다
    b = port_xy(ss, 'TaskFront', 'Inport', 7);
    add_block('simulink/Discrete/Unit Delay', [ss '/PhaseDly'], ...
              'Position', [200 b(2)-15 240 b(2)+15], ...
              'InitialCondition','0', 'SampleTime','Ts_ctrl', ...
              'Description', ['phase 래치가 자기 자신을 입력으로 받으므로 ' ...
               '그대로 되먹이면 대수 루프가 된다. 한 스텝 전 값을 쓰는 것 ' ...
               '말고는 끊을 방법이 없는 자리다. 표본 간격을 고정 스텝' ...
               '(Ts_ctrl)과 같게 두어 연속 솔버(ode4)와 어긋나지 않는다.']);
    add_line(ss, 'PhaseDly/1', 'TaskFront/7');

    outs = {'x_ref','y_ref','psi_ref','gate','phase'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'TaskFront', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [700 p(2)-10 730 p(2)+10]);
        add_line(ss, sprintf('TaskFront/%d',k), [outs{k} '/1']);
    end
    drop_tag(ss, 'TaskFront', 5, 'phase_prev', 120);   % 출력 5 = phase
    pb = port_xy(ss, 'PhaseDly', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_phase_prev'], ...
              'Position', [110 pb(2)-11 180 pb(2)+11], 'GotoTag','phase_prev');
    add_line(ss, 'Fr_phase_prev/1', 'PhaseDly/1');

    sl_note(ss, 'n_g', [ ...
        '전진 접안 — 접안 선수각이 선석 방위에 수직 (psi_f = psi_t - side*90 deg)' newline ...
        '접근점은 5단과 같은 점. 선수각만 90 deg 틀어 옆걸음이 전진으로 바뀜' newline ...
        '3단계에서 선체좌표 오차가 e_x 로 남음 — 횡추력이 거의 들지 않음' newline ...
        'gate = min(1, 목표점까지 거리/R_brake) — 끊지 않고 줄임 (빠른 축으로 들어오므로)' newline ...
        '도착 = 거리 < R_stop 이고 또한 속도 < U_berth. 속도 조건이 없으면 지나친 채 래치됨'], ...
        330, 660);
end
