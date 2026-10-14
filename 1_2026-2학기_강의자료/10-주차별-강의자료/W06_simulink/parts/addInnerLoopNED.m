% =====================================================================
% 사슬 3 · 8단에서 생김  InnerLoopNED — NED 축에서 속도 PI, 끝에서 힘을 돌림
% =====================================================================
%   addInnerLoop 과 같은 것
%     (1) 선수각 P-D      psi_ref -> N [N m]      글자까지 같다
%     (2) 추력 배분       X · Y · N -> FL·FR·FB   parts/allocFcn.m 을 함께 쓴다
%
%   addInnerLoop 과 다른 것 — 속도 PI 가 **NED 축**에서 돈다
%     (1) 측정 속도를 NED 로 돌린다 (논문 식 14, 회전행렬 식 1a)
%
%           xdot = u*cos(psi) - v*sin(psi)
%           ydot = u*sin(psi) + v*cos(psi)
%
%     (2) NED 속도 오차에 PI 를 하나씩 건다 (논문 식 15)
%
%           ErrXd = xdot_cmd - xdot   ->  PI  ->  X_N   북쪽 힘 지령 [N]
%           ErrYd = ydot_cmd - ydot   ->  PI  ->  Y_E   동쪽 힘 지령 [N]
%
%     (3) 힘 지령을 선체좌표로 돌린다 (논문 식 16, 회전행렬 식 2)
%
%           X =  X_N*cos(psi) + Y_E*sin(psi)
%           Y = -X_N*sin(psi) + Y_E*cos(psi)
%
%   회전행렬이 둘인 까닭
%     선체고정 전략은 회전행렬이 **하나**였다 (바깥 고리에서 위치 오차를
%     돌렸다). NED 전략은 바깥 고리에서 돌리지 않는 대신, 되먹임을 들일 때와
%     힘을 낼 때 두 번 돌린다. 제어기가 도는 좌표계를 NED 로 두면 들어오는
%     것과 나가는 것을 모두 그 좌표계로 맞춰야 하기 때문이다.
%
%   anti-windup 이 느슨해진다
%     선체고정 전략에서는 횡 속도 PI 의 clamping 한계를 F_bow_max 로 둘 수
%     있었다 — 그 힘을 선수추진기가 낸다는 것을 알기 때문이다. NED 축에서는
%     북쪽 힘을 어느 추진기가 낼지 선수각에 따라 달라지므로 그렇게 묶을 수
%     없다. 두 축 모두 2*F_max 로 두고, 실제 한계는 배분(Alloc)에서 FB 가
%     F_bow_max 로 잘리며 드러난다. 잘린 만큼은 적분기가 모르므로 쌓인다 —
%     NED 전략이 치르는 둘째 값이다.
%
%   도면을 어떻게 앉혔는가 (배선 검사를 0 으로 두려면 이 순서가 필요하다)
%     (1) ToNED 를 도면 **아래**에 둔다. 되먹임은 합산점의 2 번(아래) 포트로
%         들어오므로 아래에서 올라오는 것이 읽기 쉽다.
%     (2) 되먹임 두 가닥(xdot·ydot)과 psi 세 갈래는 **태그**로 푼다. 선을 그으면
%         합산점 아래 같은 세로 통로를 함께 쓰거나 ToNED 를 가로질러 지나간다.
%     (3) 입력 포트의 높이를 **받는 포트 높이에 맞춘다**. 그러면 선이 수평
%         직선 한 토막이고, 한 열에 쌓여도 세로 통로를 겹치지 않는다.
function addInnerLoopNED(m, x, y)
    ss = add_subsys(m, 'InnerLoop', [x y x+190 y+190], ...
                    {'xdot_cmd','ydot_cmd','u','v','psi_ref','psi','r'}, ...
                    {'FL','FR','FB'}, gnc_colour('control'));

    %  ---- 블록 ----------------------------------------------------------
    %  (1) 측정 속도를 NED 로 — 논문 식 14
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/ToNED'], ...
              'Position', [250 520 430 640]);
    sl_fcn(ss, 'ToNED', strjoin({
      'function [xdot, ydot] = ToNED(u, v, psi)'
      '%#codegen'
      '%  선체고정 속도를 NED 속도로 돌린다 (논문 식 14).'
      '%'
      '%    xdot  북쪽 속도 [m/s],   ydot  동쪽 속도 [m/s]'
      'xdot = u*cos(psi) - v*sin(psi);'
      'ydot = u*sin(psi) + v*cos(psi);'
      }, newline));

    %  (2) NED 속도 오차 -> PI — 논문 식 15
    add_sum(ss, 'ErrXd', '+-', [520  90]);
    add_sum(ss, 'ErrYd', '+-', [520 210]);
    sl_pi(ss, 'PI_xd', 'Kp_vn', 'Ki_vn', '2*F_max', 620,  60);
    sl_pi(ss, 'PI_yd', 'Kp_vn', 'Ki_vn', '2*F_max', 620, 180);

    %  (3) 힘 지령을 선체좌표로 — 논문 식 16
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/ToBody'], ...
              'Position', [780 60 950 200]);
    sl_fcn(ss, 'ToBody', strjoin({
      'function [X, Y] = ToBody(X_N, Y_E, psi)'
      '%#codegen'
      '%  NED 힘 지령을 선체고정 힘 지령으로 돌린다 (논문 식 16).'
      '%'
      '%    X  전후력 [N] — 좌·우 추진기가 낸다'
      '%    Y  횡력   [N] — 선수추진기가 낸다'
      'X =  X_N*cos(psi) + Y_E*sin(psi);'
      'Y = -X_N*sin(psi) + Y_E*cos(psi);'
      }, newline));

    %  선수각 P-D — addInnerLoop 과 자리까지 같다 (x 만 270 px 오른쪽)
    add_ssa(ss, 'ErrPsi', 'Ssa', [520 330], 70);
    sl_gain(ss, 'Kp_psi',  'Kp_psi', 720, 310);
    sl_gain(ss, 'Kd_rate', 'Kd_psi', 720, 440);
    add_sum(ss, 'SumN', '+-', [850 330]);
    sl_sat(ss, 'SatN', '2*F_max*half_beam + F_bow_max*l_bow', 920, 310);

    %  추력 배분 — 선체고정 전략과 글자까지 같은 함수를 쓴다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Alloc'], ...
              'Position', [1100 60 1280 460]);
    sl_fcn(ss, 'Alloc', allocFcn());
    sl_const(ss, 'PRM', '[half_beam; l_bow; F_max; F_bow_max]', 910, 425);

    %  ---- 입력 포트를 받는 포트 높이에 맞춘다 ---------------------------
    pin = {'xdot_cmd','ErrXd',1; 'ydot_cmd','ErrYd',1; ...
           'u','ToNED',1;        'v','ToNED',2; ...
           'psi_ref','ErrPsi',1; 'r','Kd_rate',1};
    for k = 1:size(pin,1)
        p = port_xy(ss, pin{k,2}, 'Inport', pin{k,3});
        set_param([ss '/' pin{k,1}], 'Position', [60 p(2)-10 90 p(2)+10]);
    end
    %  psi 는 세 곳(ToNED·ToBody·ErrPsi)이 쓴다. 선으로 뻗으면 ToNED 를
    %  가로지르므로 태그로 푼다 — 그래서 포트는 도면 맨 아래에 둔다
    set_param([ss '/psi'], 'Position', [60 690 90 710]);

    %  ---- 선 --------------------------------------------------------------
    add_line(ss, 'u/1', 'ToNED/1');
    add_line(ss, 'v/1', 'ToNED/2');
    drop_tag(ss, 'psi', 1, 'psi_in');
    feed_from(ss, 'psi_in', 'ToNED',  3);
    feed_from(ss, 'psi_in', 'ToBody', 3);
    feed_from(ss, 'psi_in', 'ErrPsi', 2);

    add_line(ss, 'xdot_cmd/1','ErrXd/1');
    add_line(ss, 'ydot_cmd/1','ErrYd/1');
    drop_tag(ss, 'ToNED', 1, 'xdot_fb');
    drop_tag(ss, 'ToNED', 2, 'ydot_fb');
    feed_from(ss, 'xdot_fb', 'ErrXd', 2);
    feed_from(ss, 'ydot_fb', 'ErrYd', 2);

    add_line(ss, 'ErrXd/1','PI_xd/1');
    add_line(ss, 'ErrYd/1','PI_yd/1');
    add_line(ss, 'PI_xd/1','ToBody/1');
    add_line(ss, 'PI_yd/1','ToBody/2');

    add_line(ss, 'psi_ref/1','ErrPsi/1');
    add_line(ss, 'Ssa/1','Kp_psi/1');
    add_line(ss, 'r/1',  'Kd_rate/1');
    add_line(ss, 'Kp_psi/1', 'SumN/1');
    add_line(ss, 'Kd_rate/1','SumN/2');
    add_line(ss, 'SumN/1','SatN/1');

    add_line(ss, 'ToBody/1','Alloc/1');
    add_line(ss, 'ToBody/2','Alloc/2');
    add_line(ss, 'SatN/1',  'Alloc/3');
    add_line(ss, 'PRM/1',   'Alloc/4');

    outs = {'FL','FR','FB'};
    for k = 1:3
        p = port_xy(ss, 'Alloc', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [1360 p(2)-10 1390 p(2)+10]);
        add_line(ss, sprintf('Alloc/%d',k), [outs{k} '/1']);
    end

    sl_note(ss, 'n_i', [ ...
        'NED 전략 — 속도 PI 가 북·동 축에서 돔 (선체 전후·횡이 아님)' newline ...
        '회전행렬이 둘 : 되먹임을 들일 때(ToNED) 와 힘을 낼 때(ToBody)' newline ...
        '선수각 P-D 와 추력 배분은 선체고정 전략과 같음' newline ...
        'PI clamping 을 2*F_max 로 느슨하게 둠 — 실제 한계는 Alloc 에서 드러남'], 520, 760);
end
