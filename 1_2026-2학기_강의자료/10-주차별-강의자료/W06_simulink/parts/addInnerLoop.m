% =====================================================================
% 사슬 3 · 1단에서 생김  InnerLoop — 속도 지령을 추력으로, 그리고 세 추진기로 나눔
% =====================================================================
%   세 가지가 한 블록 안에 있다.
%     (1) 전후 속도 PI   u_cmd -> X [N]        5주차와 같다
%     (2) 횡 속도 PI     v_cmd -> Y [N]        6주차에 새로 생겼다
%     (3) 선수각 P-D     psi_ref -> N [N m]    5주차와 같다
%   그 셋을 추력 배분이 받아 좌·우·선수 추진기의 힘으로 나눈다.
%
%   입력 포트 순서가 (지령, 되먹임) 짝으로 번갈아 든다 — u_cmd, u, v_cmd, v, ...
%   합산점이 '|+-' 이므로 지령은 **왼쪽**에서, 되먹임은 **아래**에서 들어온다.
%   짝을 붙여 놓으면 두 선이 짧고 꺾이지 않는다.
%
%   bow 인자
%     true 면 횡력 지령 Y 에 bow_on 게인이 하나 붙는다. bow_on = 0 으로 두면
%     선수추진기가 꺼진 배가 된다 — 2단 실습에서 끄고 켜 보는 스위치다.
%     Y 를 Alloc **앞에서** 끊는 까닭: Alloc 뒤에서 끊으면 N - l3*FB 보정이
%     내지도 않은 모멘트를 되받아 선수각까지 틀어진다. 앞에서 끊으면 "횡력만
%     못 내는 배" 가 되어 선수추진기의 몫만 또렷하게 보인다.
function addInnerLoop(m, x, y, bow)
    if nargin < 4, bow = false; end
    ss = add_subsys(m, 'InnerLoop', [x y x+190 y+190], ...
                    {'u_cmd','u','v_cmd','v','psi_ref','psi','r'}, ...
                    {'FL','FR','FB'}, gnc_colour('control'));

    %  되먹임 입력은 합산점 **아래**로 들어간다 (부호 목록이 '|+-' 이므로).
    %  지령 입력과 같은 x 에 두면 settle_links 가 둘을 25 px 안으로 모으는데,
    %  이름표가 블록 14 px + 글 12 px = 26 px 라 서로 가려진다.
    %  되먹임 쪽만 오른쪽으로 비켜 세운다 — 이름표가 다른 x 에 놓여 겹치지 않는다
    for nm = {'u','v','psi'}
        p = get_param([ss '/' nm{1}], 'Position');
        set_param([ss '/' nm{1}], 'Position', p + [120 0 120 0]);
    end

    add_sum(ss, 'SumU', '+-', [250  90]);
    add_sum(ss, 'SumV', '+-', [250 210]);
    add_line(ss, 'u_cmd/1','SumU/1');  add_line(ss, 'u/1','SumU/2');
    add_line(ss, 'v_cmd/1','SumV/1');  add_line(ss, 'v/1','SumV/2');

    %  속도 PI — 적분기 wind-up 은 clamping 으로 막는다 (출력이 포화면 적분 정지)
    sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', '2*F_max',   350,  60);
    sl_pi(ss, 'PI_v', 'Kp_v', 'Ki_v', 'F_bow_max', 350, 180);
    add_line(ss, 'SumU/1','PI_u/1');
    add_line(ss, 'SumV/1','PI_v/1');

    %  선수각 P-D — 각도차는 반드시 ssa 로 ±pi 로 접는다
    add_ssa(ss, 'ErrPsi', 'Ssa', [250 330], 70);
    add_line(ss, 'psi_ref/1','ErrPsi/1');  add_line(ss, 'psi/1','ErrPsi/2');
    sl_gain(ss, 'Kp_psi',  'Kp_psi', 450, 310);
    sl_gain(ss, 'Kd_rate', 'Kd_psi', 450, 440);
    add_line(ss, 'Ssa/1','Kp_psi/1');
    add_line(ss, 'r/1',  'Kd_rate/1');
    add_sum(ss, 'SumN', '+-', [580 330]);
    add_line(ss, 'Kp_psi/1', 'SumN/1');
    add_line(ss, 'Kd_rate/1','SumN/2');
    sl_sat(ss, 'SatN', '2*F_max*half_beam + F_bow_max*l_bow', 650, 310);
    add_line(ss, 'SumN/1','SatN/1');

    %  추력 배분 — 세 추진기가 X · Y · N 을 나눠 낸다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Alloc'], ...
              'Position', [830 60 1010 460]);
    sl_fcn(ss, 'Alloc', strjoin({
      'function [FL, FR, FB] = Alloc(X, Y, N, p)'
      '%#codegen'
      '%  추력 배분 — 요구 힘·모멘트를 세 추진기로 나눈다.'
      '%'
      '%    X = FL + FR                      전후력 [N]'
      '%    Y = FB                           횡력 [N]  — 선수추진기만 낸다'
      '%    N = (FL - FR)*b + l3*FB          요 모멘트 [N m]'
      '%'
      '%  p = [b; l3; Fmax; Fbmax]'
      '%    b     half_beam   좌·우 추진기까지의 반폭 [m]'
      '%    l3    l_bow       무게중심에서 선수추진기까지 [m]'
      '%    Fmax  선미 추진기 추력 한계 [N],  Fbmax 선수추진기 추력 한계 [N]'
      '%'
      '%  선수추진기가 횡력을 내면 요 모멘트 l3*FB 가 딸려 온다. 그것을 좌·우'
      '%  추진기가 되받아 빼야 선수각이 돌아가지 않는다 — 아래 N - l3*FB 가 그것이다.'
      'b = p(1);  l3 = p(2);  Fmax = p(3);  Fbmax = p(4);'
      'FB = Y;'
      'if FB >  Fbmax, FB =  Fbmax; end'
      'if FB < -Fbmax, FB = -Fbmax; end'
      '%  포화된 뒤의 FB 로 모멘트를 센다 — 실제로 딸려 온 만큼만 되받는다'
      'M  = N - l3*FB;'
      'FL = X/2 + M/(2*b);'
      'FR = X/2 - M/(2*b);'
      'if FL >  Fmax, FL =  Fmax; end'
      'if FL < -Fmax, FL = -Fmax; end'
      'if FR >  Fmax, FR =  Fmax; end'
      'if FR < -Fmax, FR = -Fmax; end'
      }, newline));
    add_line(ss, 'PI_u/1','Alloc/1');
    if bow
        sl_gain(ss, 'BowOn', 'bow_on', 700, 180);
        add_line(ss, 'PI_v/1','BowOn/1');
        add_line(ss, 'BowOn/1','Alloc/2');
    else
        add_line(ss, 'PI_v/1','Alloc/2');
    end
    add_line(ss, 'SatN/1','Alloc/3');
    sl_const(ss, 'PRM', '[half_beam; l_bow; F_max; F_bow_max]', 640, 425);
    add_line(ss, 'PRM/1','Alloc/4');

    outs = {'FL','FR','FB'};
    for k = 1:3
        p = port_xy(ss, 'Alloc', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [1090 p(2)-10 1120 p(2)+10]);
        add_line(ss, sprintf('Alloc/%d',k), [outs{k} '/1']);
    end

    txt = ['속도 PI 둘(전후·횡) + 선수각 P-D 하나 -> 추력 배분' newline ...
           '선수추진기가 횡력을 내면 요 모멘트가 딸려 오므로 좌·우 추진기가 그만큼 되받음' newline ...
           'PI 는 clamping — 출력이 포화면 적분을 멈춤 (wind-up 방지)'];
    if bow
        txt = [txt newline 'BowOn 게인 — bow_on = 0 이면 횡력 지령이 끊김 (선수추진기 없는 배)'];
    end
    sl_note(ss, 'n_i', txt, 250, 560);
end
