% =====================================================================
% 사슬 4 · 3단에서 생김  Thrusters — 요구 추력을 실제 추진기가 낼 수 있는 추력으로
% =====================================================================
%   5주차와 똑같은 세 토막인데 축이 둘에서 셋으로 늘었을 뿐이다.
%
%     요구 추력 -> (역 프로펠러 법칙) 회전수 -> (포화) -> (모터 1차 지연)
%               -> (프로펠러 법칙) 실제 추력
%
%   VRX 의 추진기 토픽은 뉴턴을 받는다. 그래서 이 블록의 출력을 그대로 보낸다.
%   회전수 n 은 그림으로만 쓴다 — 포화가 어디서 걸렸는지 눈으로 보려는 것이다.
function addThrusters(m, x, y)
    ss = add_subsys(m, 'Thrusters', [x y x+190 y+150], ...
                    {'FL_cmd','FR_cmd','FB_cmd'}, {'FL','FR','FB','n'}, ...
                    gnc_colour('thruster'));

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/F2n'], ...
              'Position', [250 60 400 360]);          % 포트 5개 — 52*4+40 = 248 이상
    sl_fcn(ss, 'F2n', strjoin({
      'function n_cmd = F2n(FL, FR, FB, k, n_max)'
      '%#codegen'
      '%  역 프로펠러 법칙 — 내고 싶은 추력을 회전수로 되돌린다.'
      '%     F = k*n*|n|   ->   n = sign(F)*sqrt(|F|/k)'
      '%  포화는 회전수에 걸린다. 모터가 묶는 것은 힘이 아니라 회전수다.'
      'F = [FL; FR; FB];'
      'n_cmd = zeros(3,1);'
      'for i = 1:3'
      '    ni = sign(F(i)) * sqrt(abs(F(i))/k);'
      '    if ni >  n_max, ni =  n_max; end'
      '    if ni < -n_max, ni = -n_max; end'
      '    n_cmd(i) = ni;'
      'end'
      }, newline));
    sl_const(ss, 'Kp', 'k_prop', 60, 420);
    sl_const(ss, 'Nm', 'n_max',  60, 470);
    row_feed(ss, 'F2n', {'FL_cmd','FR_cmd','FB_cmd','Kp','Nm'});

    %  모터 1차 지연 — 연속 시간. dn/dt = (n_cmd - n)/tau_n 을 상태공간으로 적는다.
    %  연속 Transfer Fcn 은 벡터 입력을 받지 않는다 (n 은 3원소다). A·B·C 가 대각
    %  이므로 세 추진기가 서로 섞이지 않는다 — 식은 5주차와 같고 축만 셋이다
    add_block('simulink/Continuous/State-Space', [ss '/MotorLag'], ...
              'Position', [470 180 590 240]);         % 가운데 210 = F2n 출력 높이
    set_param([ss '/MotorLag'], 'A','-eye(3)/tau_n', 'B','eye(3)/tau_n', ...
              'C','eye(3)', 'D','zeros(3)', 'X0','zeros(3,1)');
    add_line(ss, 'F2n/1', 'MotorLag/1');

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/n2F'], ...
              'Position', [660 160 810 310]);         % 입력 1 이 210 에 오게 (= MotorLag)
    sl_fcn(ss, 'n2F', strjoin({
      'function [FL, FR, FB] = n2F(n, k)'
      '%#codegen'
      '%  프로펠러 법칙. |n| 이 붙어 있다 — 추력은 회전수의 제곱이므로'
      '%  회전수에 건 제한이 추력에 그대로 비례해 걸리지 않는다.'
      'FL = k * n(1) * abs(n(1));'
      'FR = k * n(2) * abs(n(2));'
      'FB = k * n(3) * abs(n(3));'
      }, newline));
    add_line(ss, 'MotorLag/1', 'n2F/1');

    %  k_prop 을 쓰는 곳이 둘이라 상수 블록도 둘이다. 같은 작업공간 변수를
    %  읽으므로 값은 늘 같다. 하나만 두고 선을 끌면 그 선이 F2n(x = 250~400)
    %  을 가로지른다 — 2026-10-14 측정, check_lines 의 [블록관통] 1건.
    %  상수는 복제해도 손해가 없는 블록이다. 선을 꺾는 것보다 낫다
    sl_const(ss, 'Kp2', 'k_prop', 470, 245);          % 가운데 260 = n2F 입력 2
    add_line(ss, 'Kp2/1', 'n2F/2');

    outs = {'FL','FR','FB'};
    for k = 1:3
        p = port_xy(ss, 'n2F', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [880 p(2)-10 915 p(2)+10]);
        add_line(ss, sprintf('n2F/%d',k), [outs{k} '/1']);
    end
    set_param([ss '/n'], 'Position', [880 360 915 380]);
    add_line(ss, 'MotorLag/1', 'n/1', 'autorouting','on');

    sl_note(ss, 'n_t', [ ...
        '추력 -> 회전수 -> 포화 -> 모터 1차 지연 -> 추력. 세 추진기가 같은 식을 쓴다' newline ...
        '포화가 회전수에 걸리므로 지령이 커도 추력이 n_max 에서 멈춘다' newline ...
        'VRX 추진기 토픽은 뉴턴을 받으므로 이 출력을 그대로 보낸다'], 250, 430);
end
