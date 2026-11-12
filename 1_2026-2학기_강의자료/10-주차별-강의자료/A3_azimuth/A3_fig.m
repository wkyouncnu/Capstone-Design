function f = A3_fig(tag, name, pos)
%A3_FIG  이름표를 단 창을 하나만 쓴다 — 같은 창을 찾아 지우고 다시 그린다.
%
%   f = A3_fig(tag, name, pos)
%
%   입력
%     tag    창 이름표 (예: 'A3_result', 'A3_thruster', 'A3_env')
%     name   창 제목 — 단 이름이 들어가므로 돌릴 때마다 바뀐다
%     pos    [left bottom width height] 픽셀
%
%   왜 필요한가 — 6주차 W06_fig 와 같은 이유다
%     figure('Name',...) 는 부를 때마다 새 창을 연다. 단을 몇 번 바꿔 돌리면
%     바탕화면에 같은 그림이 열 장 쌓이고, 어느 것이 방금 돌린 것인지 알 수
%     없다. exportgraphics 로 저장하면 옛 창이 저장된다.

f = findobj(0, 'Type','figure', 'Tag',tag);
if isempty(f)
    f = figure('Tag',tag);
else
    f = f(1);
    clf(f);
    figure(f);          % 앞으로 가져온다
end
set(f, 'Name',name, 'NumberTitle','off', 'Position',pos, 'Color','w');
end
