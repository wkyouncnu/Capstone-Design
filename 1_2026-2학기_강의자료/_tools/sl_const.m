function sl_const(sys, name, value, x, y)
%SL_CONST  상수 블록 하나. 처음 크기는 95 x 30 이다.
%
%   sl_const(ss, 'q', 'task_q', 170, 250)
%
%     value   작업공간 변수 이름을 그대로 쓴다. 숫자를 도면에 박지 않는다 —
%             게인을 바꾸려고 모델을 열어야 한다면 그 모델은 잘못 만든 것이다
%
%   마지막 크기는 mss_style 이 정한다 — MSS 치수 55 x 30 을 최소값으로 두고,
%   변수 이름이 그 폭에 안 들어가면 이름 길이에 맞춰 넓힌다. 넓히지 않으면
%   Simulink 가 값을 숨기고 `-C-` 를 그려 어느 값인지 알 수 없게 된다.
    add_block('simulink/Sources/Constant', [sys '/' name], ...
              'Position', [x y x+95 y+30], 'Value', value);
end
