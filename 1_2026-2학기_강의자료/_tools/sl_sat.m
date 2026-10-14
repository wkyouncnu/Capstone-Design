function sl_sat(sys, name, lim, x, y)
%SL_SAT  포화 블록 하나. 위·아래가 대칭이다 — 전진과 후진, 좌와 우가 같다.
%
%   sl_sat(ss, 'SatU', 'u_max', 660, 80)
%
%   위 한계만 이름으로 주면 아래 한계는 '-(이름)' 으로 만들어 붙인다. 두 곳에
%   같은 숫자를 적어 두면 한쪽만 고치는 일이 반드시 생긴다.
    add_block('simulink/Discontinuities/Saturation', [sys '/' name], ...
              'Position', [x y x+50 y+40], ...
              'UpperLimit', lim, 'LowerLimit', ['-(' lim ')']);
end
