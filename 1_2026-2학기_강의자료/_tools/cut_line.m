function tf = cut_line(sys, dp)
%CUT_LINE  도착 포트 하나로 들어오는 가지만 끊는다. 같은 신호의 다른 가지는 둔다.
%
%   cut_line(m, dstPortHandle)
%
%   왜 delete_line(선핸들) 로는 안 되는가 / why not delete the line handle
%       한 출력에서 갈라진 신호는 **뿌리 선 하나에 가지들이 달린** 구조다. 뿌리를
%       지우면 가지가 전부 사라진다. 옮기려던 가지 하나만 다시 그으면 나머지는
%       조용히 없어진다 — 도면에는 선이 줄어든 것으로만 보이고, 모델은 차원
%       전파가 끊겨 컴파일되지 않는다 (2026-09-17 W02_2 의 TurtlePlant).
%
%       그래서 **도착 포트를 지목해** 그 포트로 들어오는 가지만 찾아 끊는다.
%
%   돌려주는 값은 끊었는지 여부다.

tf = false;
L  = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    if ~ishandle(L(i)), continue, end
    d = get_param(L(i), 'DstPortHandle');
    if numel(d) == 1 && d == dp
        try, delete_line(L(i)); tf = true; catch, end
        return
    end
end

%  가지가 아니라 뿌리 선이 그 포트를 직접 쥐고 있는 경우 — 가지가 없으면 안전하다
for i = 1:numel(L)
    if ~ishandle(L(i)), continue, end
    d = get_param(L(i), 'DstPortHandle');
    if ~any(d == dp), continue, end
    kids = [];
    try, kids = get_param(L(i), 'LineChildren'); catch, end
    if isempty(kids) && numel(d) == 1
        try, delete_line(L(i)); tf = true; catch, end
        return
    end
end
end
