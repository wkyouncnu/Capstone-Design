% =====================================================================
% 사슬 2 · 8단에서 생김  OuterLoopNED — 위치 오차를 **NED 속도 지령**으로
% =====================================================================
%   5·7단의 바깥 고리(addOuterLoop)는 NED 위치 오차를 **먼저 선체좌표로
%   돌려** 전후·횡 속도 지령을 냈다. 8단은 돌리지 않는다. 북·동 두 축에서
%   그대로 비례 제어를 하고, 북 속도 지령과 동 속도 지령을 낸다
%   (실험실 논문 Bang et al. 2025 식 13).
%
%       e_N = x_ref - x_n,      xdot_cmd = Kp_ned * e_N
%       e_E = y_ref - y_n,      ydot_cmd = Kp_ned * e_E
%
%   **psi 가 입력에 없다.** 바깥 고리가 선수각을 모른다 — 이것이 두 전략의
%   첫째 차이이고, 포트 목록만 봐도 드러난다. 회전행렬은 사라진 것이 아니라
%   안쪽 고리의 **끝으로** 옮겨 갔다 (addInnerLoopNED 의 ToBody).
%
%   속도 지령의 크기를 왜 v_max 로 묶는가
%     선체좌표에서는 전후 1.5 m/s · 횡 0.6 m/s 로 축마다 다르게 묶을 수
%     있었다. 어느 추진기가 그 속도를 내는지 알기 때문이다. NED 축은 그것을
%     모른다 — 북쪽으로 1.5 m/s 를 지시해도 선수가 동쪽을 보고 있으면 그것은
%     횡방향 1.5 m/s 이고, 선수추진기 하나로는 낼 수 없는 속도다. 그래서
%     **느린 축의 한계**로 묶는다 (V_ned_max = v_max). NED 전략이 치르는
%     첫째 값은 접근이 느려지는 것이다.
%
%     묶는 방법도 축마다가 아니라 **벡터의 크기**로 한다. 두 축을 따로 0.6
%     으로 자르면 비스듬한 방향에서 0.6*sqrt(2) = 0.85 m/s 가 되어 한계를
%     넘는다. 크기로 자르면 방향은 그대로 두고 빠르기만 줄어든다.
%
%   gate 곱셈은 5단과 같은 자리에 둔다 — 도착하면 속도 지령이 0 이 된다.
function addOuterLoopNED(m, x, y)
    ss = add_subsys(m, 'OuterLoop', [x y x+190 y+170], ...
                    {'x_ref','y_ref','x_n','y_n','gate'}, ...
                    {'xdot_cmd','ydot_cmd'}, gnc_colour('control'));

    add_sum(ss, 'ErrN', '+-', [250  90]);
    add_sum(ss, 'ErrE', '+-', [250 250]);
    add_line(ss, 'x_ref/1', 'ErrN/1');  add_line(ss, 'x_n/1', 'ErrN/2');
    add_line(ss, 'y_ref/1', 'ErrE/1');  add_line(ss, 'y_n/1', 'ErrE/2');

    %  비례 제어 — 북·동 두 축에 같은 게인. 선체축이 아니므로 전후·횡을
    %  가릴 근거가 없다 (논문도 NED 전략에는 독립 게인을 따로 둔다)
    sl_gain(ss, 'Kp_N', 'Kp_ned', 350,  80);
    sl_gain(ss, 'Kp_E', 'Kp_ned', 350, 240);
    add_line(ss, 'ErrN/1', 'Kp_N/1');
    add_line(ss, 'ErrE/1', 'Kp_E/1');

    %  속도 지령의 크기를 묶는다 — 방향은 그대로, 빠르기만 줄인다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/CapV'], ...
              'Position', [460 60 640 300]);
    sl_fcn(ss, 'CapV', strjoin({
      'function [xdot_cmd, ydot_cmd] = CapV(xdot_p, ydot_p, vmax)'
      '%#codegen'
      '%  NED 속도 지령의 크기를 vmax 로 묶는다 (방향은 그대로).'
      '%'
      '%  축마다 따로 자르지 않는 까닭: 두 축을 각각 vmax 로 자르면 비스듬한'
      '%  방향에서 크기가 vmax*sqrt(2) 가 되어 한계를 넘는다.'
      's = sqrt(xdot_p^2 + ydot_p^2);'
      'if s > vmax'
      '    xdot_cmd = xdot_p*vmax/s;'
      '    ydot_cmd = ydot_p*vmax/s;'
      'else'
      '    xdot_cmd = xdot_p;'
      '    ydot_cmd = ydot_p;'
      'end'
      }, newline));
    sl_const(ss, 'Vmax', 'V_ned_max', 350, 390);
    add_line(ss, 'Kp_N/1', 'CapV/1');
    add_line(ss, 'Kp_E/1', 'CapV/2');
    add_line(ss, 'Vmax/1', 'CapV/3');

    add_block('simulink/Math Operations/Product', [ss '/GateN'], ...
              'Position', [780 70 810 110]);
    add_block('simulink/Math Operations/Product', [ss '/GateE'], ...
              'Position', [780 230 810 270]);
    add_line(ss, 'CapV/1','GateN/1');   add_line(ss, 'gate/1','GateN/2');
    add_line(ss, 'CapV/2','GateE/1');   add_line(ss, 'gate/1','GateE/2');
    add_line(ss, 'GateN/1','xdot_cmd/1');
    add_line(ss, 'GateE/1','ydot_cmd/1');
    Simulink.BlockDiagram.arrangeSystem(ss);

    sl_note(ss, 'n_o', [ ...
        'NED 전략 — 위치 오차를 돌리지 않고 북·동 축에서 바로 비례 제어' newline ...
        '입력에 psi 가 없음 — 회전행렬은 안쪽 고리의 끝(ToBody)으로 옮겨 감' newline ...
        '속도 지령은 축마다가 아니라 벡터 크기로 V_ned_max 에 묶음'], 250, 480);
end
