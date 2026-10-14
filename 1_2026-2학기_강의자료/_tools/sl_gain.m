function sl_gain(sys, name, k, x, y)
%SL_GAIN  게인 블록 하나. 크기는 50 x 40 으로 고정한다.
%
%   sl_gain(ss, 'Kp_x', 'Kp_x', 560, 80)
%
%   게인 값도 이름으로 준다 (sl_const 와 같은 이유). 0 인 게인과 양수 되먹임
%   게인은 check_gains 가 잡는다.
    add_block('simulink/Math Operations/Gain', [sys '/' name], ...
              'Position', [x y x+50 y+40], 'Gain', k);
end
