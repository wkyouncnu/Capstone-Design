% =====================================================================
% 사슬 4 · 1단에서 생김  MotionModel — 배가 어떻게 반응하는가 (오프라인)
% =====================================================================
%   6주차의 addMotionModel 과 **물리는 글자 하나까지 같다.** 다른 것은 입구뿐이다.
%
%     6주차    FL · FR · FB   고정 추진기 셋의 추력을 받아 X·Y·N 으로 합쳤다
%     부록 A3  TL · dL · TR · dR   추력 둘과 **각도 둘**을 받아 합친다
%
%   왜 운동모델이 각도를 받는가
%     노즐이 비스듬히 서 있으면 같은 추력이 전후·횡·요로 나뉘어 걸린다. 그 나뉘는
%     비율을 정하는 것은 추진기가 어디에 어떻게 달렸는가 — 곧 **배의 성질**이다.
%     그래서 변환(Wrench)을 운동모델 안에 둔다. 배분 상자는 "무엇을 명령할까"
%     까지만 책임지고, 그 명령이 선체에 실제로 얼마로 걸리는지는 배가 정한다.
%
%   안에 넷이 줄지어 있다
%     1. Wrench   추력·각도 -> 실제 렌치 X_a·Y_a·N_a (배분기와 같은 행렬 B)
%     2. EOM      3자유도 운동방정식
%     3. Integ    적분
%     4. States   상태벡터를 이름으로 풀어 놓기
%
%   실제 렌치 셋은 **바깥으로도 낸다** (출력 10~12). 요구 렌치와 겹쳐 그리면
%   각도·추력 한계 때문에 못 낸 몫이 그래프에 그대로 보인다.
%
%   계수는 VRX 의 설정파일에서 그대로 읽은 값이다 (A3_setup.m 5절).
function addMotionModelXYN(m, x, y)
    ss = add_subsys(m, 'MotionModel', [x y x+210 y+200], ...
                    {'TL','dL','TR','dR'}, ...
                    {'x_n','y_n','psi','u','v','r','beta','chi','U', ...
                     'X_a','Y_a','N_a'}, ...
                    gnc_colour('plant'));

    %  1. 추진기 명령 -> 선체에 걸리는 렌치
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Wrench'], ...
              'Position', [230 60 390 400]);
    sl_fcn(ss, 'Wrench', wrenchFcn());
    sl_const(ss, 'AZP', 'az_prm', 60, 450);
    row_feed(ss, 'Wrench', {'TL','dL','TR','dR','AZP'});

    %  2. 운동방정식
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/EOM'], ...
              'Position', [600 60 770 560]);
    sl_fcn(ss, 'EOM', strjoin({
      'function xdot = EOM(s, X, Y, N, V_c, beta_c, p)'
      '%#codegen'
      '%  3자유도 운동방정식.  s = [u v r x_n y_n psi] 의 열벡터'
      '%'
      '%    X, Y, N 은 Wrench 가 낸 **실제** 렌치다 (요구가 아니다)'
      '%    조류는 상대속도에만 들어간다 — 저항은 물에 대한 속도로 생긴다'
      '%    부가질량은 0 으로 둔다 (VRX 설정도 0 이다)'
      'u = s(1);  v = s(2);  r = s(3);  psi = s(6);'
      'm_s  = p(1);  Izz = p(2);'
      'Xu   = p(3);  Xuu = p(4);'
      'Yv   = p(5);  Yvv = p(6);'
      'Nr   = p(7);  Nrr = p(8);'
      ''
      '%  조류를 선체좌표로 — 물에 대한 상대속도 u_r, v_r'
      'u_c = V_c*cos(beta_c - psi);'
      'v_c = V_c*sin(beta_c - psi);'
      'u_r = u - u_c;'
      'v_r = v - v_c;'
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

    sl_const(ss, 'V_c',    'current_speed', 110, 620);
    sl_const(ss, 'beta_c', 'beta_c',        110, 670);
    sl_const(ss, 'p',      'usv_p',          60, 720);

    add_block('simulink/Continuous/Integrator', [ss '/Integ'], ...
              'Position', [860 290 890 320], 'InitialCondition','x0');
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/States'], ...
              'Position', [980 60 1150 560]);
    sl_fcn(ss, 'States', strjoin({
      'function [x_n, y_n, psi, u, v, r, beta, chi, U] = States(s)'
      '%#codegen'
      '%  상태벡터를 쓰기 좋은 이름으로 풀어 놓는다.'
      '%    U    대지속력 [m/s]'
      '%    beta 크랩각 — 뱃머리와 실제 가는 방향의 차이 [rad]'
      '%    chi  침로 = psi + beta, 실제 가는 방향 [rad]'
      '%  순수 횡이동에서는 beta 가 90 deg 에 가깝다 (뱃머리는 북, 가는 쪽은 동)'
      'u = s(1);  v = s(2);  r = s(3);'
      'x_n = s(4);  y_n = s(5);  psi = s(6);'
      'U = sqrt(u*u + v*v);'
      'beta = atan2(v, u);'
      'c = psi + beta;'
      'chi = atan2(sin(c), cos(c));'
      }, newline));

    %  실제 렌치를 태그로 받아 운동방정식에 넣는다 — Wrench 와 EOM 의 포트
    %  높이가 다르므로(입력 5개 대 7개) 선으로 이으면 셋이 모두 꺾인다
    drop_tag(ss, 'Wrench', 1, 'tau_X', -60);
    drop_tag(ss, 'Wrench', 2, 'tau_Y',  60);
    drop_tag(ss, 'Wrench', 3, 'tau_N',  60);
    feed_from(ss, 'tau_X', 'EOM', 2);
    feed_from(ss, 'tau_Y', 'EOM', 3);
    feed_from(ss, 'tau_N', 'EOM', 4);

    row_feed(ss, 'EOM', {'','','','','V_c','beta_c','p'});
    add_line(ss, 'EOM/1',  'Integ/1');
    add_line(ss, 'Integ/1','States/1');

    %  상태를 운동방정식으로 되먹인다 — 선으로 거슬러 올리면 도면을 가로지른다
    drop_tag(ss, 'Integ', 1, 'x_state', 300);
    b = port_xy(ss, 'EOM', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_x_state'], ...
              'Position', [490 b(2)-11 560 b(2)+11], 'GotoTag','x_state');
    add_line(ss, 'Fr_x_state/1', 'EOM/1');

    outs = {'x_n','y_n','psi','u','v','r','beta','chi','U'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'States', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [1220 p(2)-10 1250 p(2)+10]);
        add_line(ss, sprintf('States/%d',k), [outs{k} '/1']);
    end

    %  실제 렌치 셋도 바깥으로 — 요구와 겹쳐 그리기 위한 출력이다
    wr = {'X_a','tau_X'; 'Y_a','tau_Y'; 'N_a','tau_N'};
    for k = 1:3
        yy = 640 + 60*(k-1);
        set_param([ss '/' wr{k,1}], 'Position', [1220 yy 1250 yy+20]);
        nm = sl_from(ss, wr{k,2}, 1100, yy-3);
        add_line(ss, [nm '/1'], [wr{k,1} '/1'], 'autorouting','on');
    end

    sl_note(ss, 'n_m', [ ...
        '계수는 VRX 설정파일에서 그대로 읽은 값 — 6주차 모델과 같음' newline ...
        '추력 둘과 각도 둘을 받음. 실제 렌치로 바꾸는 일(Wrench)이 이 안에 있음' newline ...
        '조류는 상대속도에만 들어감 — 저항은 물에 대한 속도로 생김'], 600, 800);
end
