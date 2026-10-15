function f = W06_fig(tag, name, pos)
%W06_FIG  이름표를 단 창을 하나만 쓴다 — 같은 창을 찾아 지우고 다시 그린다.
%
%   f = W06_fig(tag, name, pos)
%
%   입력
%     tag    창 이름표 (예: 'W06_result', 'W06_thruster', 'W06_anim')
%     name   창 제목 — 단 이름이 들어가므로 돌릴 때마다 바뀐다
%     pos    [left bottom width height] 픽셀
%
%   왜 필요한가
%     figure('Name',...) 는 부를 때마다 **새 창**을 연다. 5단을 고치면서
%     세 번만 돌려도 결과 창 셋 · 추진기 창 셋 · 애니메이션 창 셋, 모두
%     아홉 장이 바탕화면에 쌓인다. 어느 것이 방금 돌린 것인지 알 수 없고,
%     exportgraphics(figure(2), ...) 로 그림을 저장하면 **옛 창**이 저장된다
%     (실제로 그렇게 저장해 놓고 수정이 안 먹은 줄 알았다).
%
%     이름표로 찾아 쓰면 창은 종류마다 한 장뿐이고, 제목의 단 이름만 바뀐다.

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
