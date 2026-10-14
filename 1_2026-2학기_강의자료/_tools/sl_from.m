function nm = sl_from(m, tag, x, y)
%SL_FROM  From 블록 하나를 놓고 그 **이름**을 돌려준다.
%
%   f = sl_from(m, 'psi', 1020, 105);   add_line(m, [f '/1'], 'InnerLoop/4');
%
%   같은 태그를 여러 번 받을 수 있으므로 이름은 from_name 이 번호를 붙여 짓는다.
%   돌려받은 이름을 그대로 add_line 에 쓴다 — 'Fr_psi' 라고 손으로 적지 않는다.
    nm = from_name(m, tag);
    add_block('simulink/Signal Routing/From', [m '/' nm], ...
              'Position', [x y x+70 y+25], 'GotoTag', tag);
end
