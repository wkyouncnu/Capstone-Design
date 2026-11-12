function addInnerLoopA3(m, x, y)
% addInnerLoopA3 — 안쪽 고리 (속도·선수각 -> 요구 힘·모멘트)
%
%   6주차의 addInnerLoop 에서 **추력 배분만 떼어 낸 것**이다. 고리 구조와 게인은
%   글자 하나까지 같다. 그래야 "배분을 바꾸면 무엇이 달라지는가" 가 보인다.
%
%   들어오는 것  u_cmd · u · v_cmd · v · psi_ref · psi · r
%   나가는 것    X_c · Y_c · N_c      요구 힘·모멘트 (선체고정). 배분 상자로 간다
%
%   고리 셋이 나란하다
%     전후   u_cmd - u    -> PI       -> X_c    한계 2*F_max
%     횡     v_cmd - v    -> PI       -> Y_c    한계 Y_max
%     선수각 psi_ref - psi -> P - D*r -> N_c    한계 N_max
%
%   한계값이 6주차와 다른 곳이 둘이다
%     Y 한계   6주차는 선수추진기 추력 F_bow_max (250 N) 가 그대로 한계였다.
%              여기서는 두 추진기를 비스듬히 틀어 만들므로 Y_max (약 397 N) 이다
%     N 한계   6주차는 2*F_max*b + F_bow_max*l_bow. 여기는 2*F_max*b 뿐이다
    ss = add_subsys(m, 'InnerLoop', [x y x+190 y+190], ...
                    {'u_cmd','u','v_cmd','v','psi_ref','psi','r'}, ...
                    {'X_c','Y_c','N_c'}, gnc_colour('control'));

    %  되먹임으로 들어오는 포트는 오른쪽으로 물려 둔다 — 지령 포트와 이름표가
    %  겹치지 않게 (6주차와 같은 처리)
    for nm = {'u','v','psi'}
        p = get_param([ss '/' nm{1}], 'Position');
        set_param([ss '/' nm{1}], 'Position', p + [120 0 120 0]);
    end

    %  전후·횡 속도 오차
    add_sum(ss, 'SumU', '+-', [250  90]);
    add_sum(ss, 'SumV', '+-', [250 210]);
    add_line(ss, 'u_cmd/1', 'SumU/1');  add_line(ss, 'u/1', 'SumU/2');
    add_line(ss, 'v_cmd/1', 'SumV/1');  add_line(ss, 'v/1', 'SumV/2');

    %  PI — 되감기는 역계산(back-calculation). 한계에 붙어 있는 동안 적분을 멈춘다
    sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', '2*F_max', 350,  60, 'Kb');
    sl_pi(ss, 'PI_v', 'Kp_v', 'Ki_v', 'Y_max',   350, 180, 'Kb');
    add_line(ss, 'SumU/1', 'PI_u/1');  add_line(ss, 'SumV/1', 'PI_v/1');

    %  선수각 오차 — ssa 로 ±180 deg 안으로 감는다 (359 deg 를 -1 deg 로 읽는다)
    add_ssa(ss, 'ErrPsi', 'Ssa', [250 330], 70);
    add_line(ss, 'psi_ref/1', 'ErrPsi/1');  add_line(ss, 'psi/1', 'ErrPsi/2');

    sl_gain(ss, 'Kp_psi',  'Kp_psi', 450, 310);
    sl_gain(ss, 'Kd_rate', 'Kd_psi', 450, 440);
    add_line(ss, 'Ssa/1', 'Kp_psi/1');  add_line(ss, 'r/1', 'Kd_rate/1');

    %  P - D*r — 각속도를 직접 빼므로 오차를 미분하지 않는다 (잡음이 증폭되지 않음)
    add_sum(ss, 'SumN', '+-', [580 330]);
    add_line(ss, 'Kp_psi/1', 'SumN/1');  add_line(ss, 'Kd_rate/1', 'SumN/2');
    sl_sat(ss, 'SatN', 'N_max', 650, 310);
    add_line(ss, 'SumN/1', 'SatN/1');

    %  요구를 그대로 내보낸다. 추력·각도 한계를 거는 일은 배분 상자가 한다
    src = {'PI_u', 'PI_v', 'SatN'};
    out = {'X_c',  'Y_c',  'N_c'};
    for k = 1:3
        p = port_xy(ss, src{k}, 'Outport', 1);
        set_param([ss '/' out{k}], 'Position', [820 p(2)-10 850 p(2)+10]);
        add_line(ss, [src{k} '/1'], [out{k} '/1'], 'autorouting','on');
    end
end
