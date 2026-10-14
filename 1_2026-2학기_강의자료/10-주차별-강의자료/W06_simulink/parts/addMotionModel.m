% =====================================================================
% 사슬 5 · 1단에서 생김  MotionModel — 배가 어떻게 반응하는가 (오프라인에서만 쓴다)
% =====================================================================
%   3자유도 운동방정식. 5주차와 다른 것은 횡방향에 힘이 들어온다는 것뿐이다.
%
%     X = FL + FR                     전후력
%     Y = FB                          횡력      <- 6주차에 새로 생겼다
%     N = (FL - FR)*b + l3*FB         요 모멘트 <- 선수추진기 몫이 더해졌다
%
%   계수는 VRX 의 설정파일에서 그대로 읽은 값이다 (W06_setup.m 7절). 그래서
%   오프라인에서 맞춘 게인이 Gazebo 에서도 대체로 그대로 먹는다.
function addMotionModel(m, x, y)
    ss = add_subsys(m, 'MotionModel', [x y x+210 y+200], ...
                    {'FL','FR','FB'}, ...
                    {'x_n','y_n','psi','u','v','r','beta','chi','U'}, ...
                    gnc_colour('plant'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/EOM'], ...
              'Position', [300 60 470 560]);
    sl_fcn(ss, 'EOM', strjoin({
      'function xdot = EOM(s, FL, FR, FB, V_c, beta_c, p)'
      '%#codegen'
      '%  3자유도 운동방정식.  s = [u v r x_n y_n psi]'''
      '%'
      '%    조류는 상대속도에만 들어간다 — 저항은 물에 대한 속도로 생긴다'
      '%    부가질량은 0 으로 둔다 (VRX 설정도 0 이다)'
      'u = s(1);  v = s(2);  r = s(3);  psi = s(6);'
      'm_s  = p(1);  Izz = p(2);'
      'Xu   = p(3);  Xuu = p(4);'
      'Yv   = p(5);  Yvv = p(6);'
      'Nr   = p(7);  Nrr = p(8);'
      'b_h  = p(9);  l3  = p(10);'
      ''
      '%  조류를 선체좌표로 — 물에 대한 상대속도 u_r, v_r'
      'u_c = V_c*cos(beta_c - psi);'
      'v_c = V_c*sin(beta_c - psi);'
      'u_r = u - u_c;'
      'v_r = v - v_c;'
      ''
      '%  추진기가 내는 힘과 모멘트'
      'X = FL + FR;'
      'Y = FB;'
      'N = (FL - FR)*b_h + l3*FB;'
      ''
      '%  저항 — 선형 + 제곱 (제곱항이 있어 속도가 커질수록 빨리 늘어난다)'
      'Dx = (Xu + Xuu*abs(u_r))*u_r;'
      'Dy = (Yv + Yvv*abs(v_r))*v_r;'
      'Dn = (Nr + Nrr*abs(r))*r;'
      ''
      '%  v*r, -u*r 은 좌표계가 함께 돌기 때문에 생기는 항이다'
      'du = (X - Dx)/m_s + v*r;'
      'dv = (Y - Dy)/m_s - u*r;'
      'dr = (N - Dn)/Izz;'
      ''
      '%  선체속도를 NED 로 — 이것이 위치의 미분이다'
      'xdot = [du; dv; dr; ...'
      '        u*cos(psi) - v*sin(psi); ...'
      '        u*sin(psi) + v*cos(psi); ...'
      '        r];'
      }, newline));

    sl_const(ss, 'V_c',    'current_speed', 110, 600);
    sl_const(ss, 'beta_c', 'beta_c',        110, 650);
    sl_const(ss, 'p', '[m_usv; Izz; Xu; Xuu; Yv; Yvv; Nr; Nrr; half_beam; l_bow]', 60, 700);

    add_block('simulink/Continuous/Integrator', [ss '/Integ'], ...
              'Position', [560 290 590 320], 'InitialCondition','x0');
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/States'], ...
              'Position', [680 60 850 560]);
    sl_fcn(ss, 'States', strjoin({
      'function [x_n, y_n, psi, u, v, r, beta, chi, U] = States(s)'
      '%#codegen'
      '%  상태벡터를 쓰기 좋은 이름으로 풀어 놓는다.'
      '%    U    대지속력 [m/s]'
      '%    beta 크랩각 — 뱃머리와 실제 가는 방향의 차이 [rad]'
      '%    chi  침로 = psi + beta, 실제 가는 방향 [rad]'
      'u = s(1);  v = s(2);  r = s(3);'
      'x_n = s(4);  y_n = s(5);  psi = s(6);'
      'U = sqrt(u*u + v*v);'
      'beta = atan2(v, u);'
      'c = psi + beta;'
      'chi = atan2(sin(c), cos(c));'
      }, newline));

    row_feed(ss, 'EOM', {'','FL','FR','FB','V_c','beta_c','p'});
    add_line(ss, 'EOM/1',  'Integ/1');
    add_line(ss, 'Integ/1','States/1');

    %  상태를 운동방정식으로 되먹인다 — 선으로 거슬러 올리면 도면을 가로지른다
    drop_tag(ss, 'Integ', 1, 'x_state', 300);
    b = port_xy(ss, 'EOM', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_x_state'], ...
              'Position', [190 b(2)-11 260 b(2)+11], 'GotoTag','x_state');
    add_line(ss, 'Fr_x_state/1', 'EOM/1');

    outs = {'x_n','y_n','psi','u','v','r','beta','chi','U'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'States', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [920 p(2)-10 950 p(2)+10]);
        add_line(ss, sprintf('States/%d',k), [outs{k} '/1']);
    end

    sl_note(ss, 'n_m', [ ...
        '계수는 VRX 설정파일에서 그대로 읽은 값 — 그래서 오프라인 게인이 Gazebo 에서도 먹음' newline ...
        '선수추진기는 Y 와 함께 요 모멘트 l_bow*FB 도 만듦 (그래서 배분이 되받아야 함)' newline ...
        '조류는 상대속도에만 들어감 — 저항은 물에 대한 속도로 생김'], 300, 780);
end
