function tf = spot_free(sys, rect, name, pts, skip)
%SPOT_FREE  새 블록을 RECT 에 놓고 PTS 로 이어도 아무것과 포개지지 않는가.
%
%   tf = spot_free(s, [x1 y1 x2 y2], 'Go_X', [a; a(1) y; x1 y], {'MotorLag'})
%
%   drop_tag · feed_from 이 태그 자리를 고를 때 쓴다. 넷을 본다.
%     - 새 블록 사각형과 그 이름표(아래 14 px)가 다른 블록·이름표와 겹치는가
%     - 새 선 PTS 가 다른 블록을 지나는가 (SKIP 에 적은 블록은 뺀다)
%     - 이미 있는 선이 새 블록을 지나는가
%   check_lines 의 (2) 블록관통 · (6) 블록겹침 과 같은 판정이다.
%
%   왜 필요한가 / why this exists
%       tag_feedback 은 태그를 포트에서 정해진 거리(90 px) 아래에 매단다. 그 자리에
%       이미 다른 블록이 있으면 태그가 그 위에 포개진다 (2026-09-19 SB8 의
%       Fr_SumA_1_1 이 One 위에, W06_3·W06_4 의 Go_/Fr_ 가 Scope 위에).
%       자리를 먼저 재 보고 비어 있을 때만 놓는다.

if nargin < 5, skip = {}; end
tf = false;
nb = name_box(name, rect);
b = find_system(sys, 'SearchDepth',1, 'Type','Block');
b = b(~strcmp(b, sys));
for i = 1:numel(b)
    r = get_param(b{i}, 'Position');
    nm = get_param(b{i}, 'Name');
    if ov(rect, r) || ov(nb, r), return, end
    if ~strcmp(get_param(b{i},'ShowName'),'off') && ...
       any(strcmp(get_param(b{i},'Orientation'), {'right','left'}))
        if ov(rect, name_box(nm, r)), return, end
    end
    if any(strcmp(nm, skip)), continue, end
    for k = 1:size(pts,1)-1
        if seg_hits(pts(k,:), pts(k+1,:), r), return, end
    end
end
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    q = get_param(L(i), 'Points');
    for k = 1:size(q,1)-1
        if seg_hits(q(k,:), q(k+1,:), rect), return, end
    end
end
tf = true;
end

function t = name_box(nm, r)
parts = strsplit(nm, newline);  w = 0;
for k = 1:numel(parts)
    c = double(parts{k});  w = max(w, sum(c < 128)*6.5 + sum(c >= 128)*12);
end
w  = max(w, r(3)-r(1));  cx = (r(1)+r(3))/2;
t  = [cx-w/2, r(4)+2, cx+w/2, r(4)+2+14*numel(parts)];
end

function tf = ov(p, q)
tf = min(p(3),q(3)) - max(p(1),q(1)) > 1 && min(p(4),q(4)) - max(p(2),q(2)) > 1;
end

function tf = seg_hits(a, b, r)
%  check_lines 의 seg_hits_box 와 같다 (테두리 2 px 여유)
M = 2;  lo = [r(1)+M r(2)+M];  hi = [r(3)-M r(4)-M];
tf = false;
if any(hi <= lo), return, end
d = b - a;
if all(abs(d) < 1e-6), return, end
t0 = 0;  t1 = 1;
for k = 1:2
    if abs(d(k)) < 1e-9
        if a(k) <= lo(k) || a(k) >= hi(k), return, end
    else
        ta = (lo(k)-a(k))/d(k);  tb = (hi(k)-a(k))/d(k);
        if ta > tb, [ta, tb] = deal(tb, ta); end
        t0 = max(t0, ta);  t1 = min(t1, tb);
        if t0 >= t1, return, end
    end
end
tf = (t1 - t0) > 1e-6;
end
