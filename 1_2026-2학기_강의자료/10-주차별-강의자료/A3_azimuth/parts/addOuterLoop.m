% =====================================================================
% 사슬 2 · 1단에서 생김  OuterLoop — 위치 오차를 속도 지령으로 (바깥 고리, P 제어)
% =====================================================================
%   오차는 NED(지구고정)로 나오고 속도 지령은 선체고정이어야 한다. 그래서
%   회전행렬로 한 번 돌린다.
%
%     [e_x]   [ cos(psi)  sin(psi)] [x_ref - x_n]
%     [e_y] = [-sin(psi)  cos(psi)] [y_ref - y_n]
%
%   그 다음은 비례 제어 하나씩 — u_cmd = Kp_x*e_x, v_cmd = Kp_y*e_y. 그리고
%   포화로 접근 속도를 묶는다. 접안에서 u_max 를 1.5 m/s 로 두는 까닭은 그보다
%   빨리 부두에 닿으면 안 되기 때문이다.
%
%   gate 곱셈이 여기 있다 — 도착하면 속도 지령이 0 이 된다. 5주차에서는 안쪽
%   고리에 있었지만, 위치 제어에서는 "속도를 0 으로" 가 곧 "멈춤" 이라 여기가 맞다.
function addOuterLoop(m, x, y)
    ss = add_subsys(m, 'OuterLoop', [x y x+190 y+170], ...
                    {'x_ref','y_ref','x_n','y_n','psi','gate'}, ...
                    {'u_cmd','v_cmd'}, gnc_colour('control'));

    add_sum(ss, 'ErrN', '+-', [250  90]);
    add_sum(ss, 'ErrE', '+-', [250 250]);
    add_line(ss, 'x_ref/1', 'ErrN/1');  add_line(ss, 'x_n/1', 'ErrN/2');
    add_line(ss, 'y_ref/1', 'ErrE/1');  add_line(ss, 'y_n/1', 'ErrE/2');

    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Rotate'], ...
              'Position', [350 60 500 300]);
    sl_fcn(ss, 'Rotate', strjoin({
      'function [e_x, e_y] = Rotate(e_N, e_E, psi)'
      '%#codegen'
      '%  NED 위치 오차를 선체고정 오차로 돌린다. e_x 앞쪽, e_y 우현쪽 [m]'
      'e_x =  cos(psi)*e_N + sin(psi)*e_E;'
      'e_y = -sin(psi)*e_N + cos(psi)*e_E;'
      }, newline));
    add_line(ss, 'ErrN/1', 'Rotate/1');
    add_line(ss, 'ErrE/1', 'Rotate/2');
    add_line(ss, 'psi/1',  'Rotate/3');

    sl_gain(ss, 'Kp_x', 'Kp_x', 560,  80);
    sl_gain(ss, 'Kp_y', 'Kp_y', 560, 220);
    sl_sat(ss, 'SatU', 'u_max', 660,  80);
    sl_sat(ss, 'SatV', 'v_max', 660, 220);
    add_block('simulink/Math Operations/Product', [ss '/GateU'], ...
              'Position', [780 70 810 110]);
    add_block('simulink/Math Operations/Product', [ss '/GateV'], ...
              'Position', [780 210 810 250]);
    add_line(ss, 'Rotate/1','Kp_x/1');  add_line(ss, 'Kp_x/1','SatU/1');
    add_line(ss, 'Rotate/2','Kp_y/1');  add_line(ss, 'Kp_y/1','SatV/1');
    add_line(ss, 'SatU/1','GateU/1');   add_line(ss, 'gate/1','GateU/2');
    add_line(ss, 'SatV/1','GateV/1');   add_line(ss, 'gate/1','GateV/2');
    add_line(ss, 'GateU/1','u_cmd/1');  add_line(ss, 'GateV/1','v_cmd/1');
    Simulink.BlockDiagram.arrangeSystem(ss);

    sl_note(ss, 'n_o', [ ...
        '위치 오차 -> 선체고정 오차 -> 비례 제어 -> 속도 포화 -> gate' newline ...
        'u_max 1.5 m/s · v_max 0.6 m/s — 접근 속도를 추력이 아니라 속도로 묶음' newline ...
        '그래서 멀리 있어도 안쪽 적분기가 포화에 눌려 쌓이지 않음'], 250, 420);
end
