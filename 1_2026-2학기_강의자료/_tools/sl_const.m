function sl_const(sys, name, value, x, y)
%SL_CONST  상수 블록 하나. 크기는 95 x 30 으로 고정한다.
%
%   sl_const(ss, 'q', 'task_q', 170, 250)
%
%     value   작업공간 변수 이름을 그대로 쓴다. 숫자를 도면에 박지 않는다 —
%             게인을 바꾸려고 모델을 열어야 한다면 그 모델은 잘못 만든 것이다
    add_block('simulink/Sources/Constant', [sys '/' name], ...
              'Position', [x y x+95 y+30], 'Value', value);
end
