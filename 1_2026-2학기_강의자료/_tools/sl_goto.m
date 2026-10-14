function sl_goto(m, tag, x, y)
%SL_GOTO  Goto 블록 하나. 이름은 'Go_<태그>' 로 짓는다.
%
%   sl_goto(m, 'psi', 520, 150);   add_line(m, 'MotionModel/3', 'Go_psi/1');
%
%   TagVisibility 는 global 이다 — 서브시스템 안에서도 같은 태그로 받는다.
%   태그 이름은 **신호 이름**이어야 한다 (check_tags 가 센다).
    add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end
