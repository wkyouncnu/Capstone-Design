function sl_note(sys, tag, txt, x, y)
%SL_NOTE  도면에 주석 한 덩이를 붙인다.
%
%   sl_note(ss, 'n_g', ['첫 줄' newline '둘째 줄'], 330, 600)
%
%   블록이 아니라 메모다. 학생이 도면만 보고도 "이 블록이 왜 여기 있는지" 를
%   알 수 있게 한다. 자리는 다른 블록과 겹치지 않는 빈 곳으로 — check_lines 의
%   「블록겹침」이 메모도 센다.
    add_block('built-in/Note', [sys '/' tag], 'Position',[x y x y], 'Text', txt);
end
