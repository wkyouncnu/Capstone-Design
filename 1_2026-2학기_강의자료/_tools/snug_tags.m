function n = snug_tags(sys, varargin)
%SNUG_TAGS  Goto 는 출발 포트 옆, From 은 도착 포트 옆으로 끌어와 선을 직선으로 만든다.
%
%   n = snug_tags('W04_3_heading_offline')
%   n = snug_tags(sys, 'Gap', 30)
%
%   왜 이 도구가 필요한가 / why this exists
%       2026-10-01 교수 지시 — "Goto 부분은 실제 신호에 최대한 가까이 모아 주고,
%       선들도 꺾이는 부분을 최소화해서 해 줄 것."
%
%       빌더는 `drop_tag` · `feed_from` 으로 태그를 포트 옆에 놓는다. 그런데 그
%       뒤에 도는 배치 도구가 태그를 **멀리 끌고 간다.** Goto 는 출력이 없고
%       입력만 있어 `lay_sinks` 가 종착 블록으로 보고 도면 아래 종착 구역으로
%       쓸어 내리고, `arrangeSystem` 은 태그를 층 끝으로 밀어낸다. 그래서
%       `Go_N` 이 제 신호에서 1000 px 아래에 앉고, 잇는 선이 길게 꺾여 내려갔다
%       (2026-10-01 W04_3_heading_offline 에서 교수가 직접 고쳐 보고 지적).
%
%       이 도구는 **마지막에 한 번 더** 태그를 제 신호 옆으로 끌어온다.
%
%           나쁨                                좋음
%           Alloc ──┐                           Alloc ──▶[Go_N]
%                   │ (1000 px 아래로)
%                 [Go_N]
%
%   무엇을 지키는가 / what it guarantees
%       옮긴 자리가 다른 블록·이름표·선과 포개지지 않는지 `spot_free` 로 먼저
%       재고, 새로 그을 가로 토막이 남의 세로·가로 토막과 통로를 나눠 쓰지
%       않는지도 본다. 하나라도 걸리면 **그 태그는 그대로 둔다.** 어설프게
%       옮겨 다른 선을 망치는 것보다 낫다 (lay_links 와 같은 태도).
%
%   무엇을 건드리지 않는가 / what does not change
%       연결 · 게인 · 태그 이름(GotoTag)은 한 자도 바뀌지 않는다. 옮기는 것은
%       태그 블록의 **자리**와 그 한 가닥 선의 모양뿐이다.
%
%   NAME/VALUE
%     'Gap'   포트에서 태그까지의 가로 거리 [px]. 기본 30
%     'Tries' 자리가 차 있을 때 더 밀어 볼 거리들 [px]. 기본 [0 40 90 150 220]
%
%   돌려주는 값은 자리를 옮긴 태그의 수다.

p = inputParser;
p.addParameter('Gap',   30);
p.addParameter('Tries', [0 40 90 150 220]);
p.parse(varargin{:});
o = p.Results;
n = 0;

blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));
if isempty(blks), return, end

%  Goto 를 먼저, From 을 뒤에 — 앞에서 자리를 비워 주면 뒤가 수월하다.
kind = cell(numel(blks),1);
for i = 1:numel(blks), kind{i} = get_param(blks{i}, 'BlockType'); end
order = [find(strcmp(kind,'Goto'))' find(strcmp(kind,'From'))'];

for i = order
    blk = blks{i};
    nm  = get_param(blk, 'Name');
    if strcmp(kind{i}, 'Goto')
        n = n + snug_goto(sys, blk, nm, o);
    else
        n = n + snug_from(sys, blk, nm, o);
    end
end
end

% =========================================================================
function moved = snug_goto(sys, blk, nm, o)
%  Goto 의 입력 포트를 출발 포트와 **같은 높이**, 한 칸 오른쪽에 둔다.
moved = 0;
ph = get_param(blk, 'PortHandles');
if numel(ph.Inport) ~= 1, return, end
dp = ph.Inport(1);
sp = src_of(sys, dp);
if sp <= 0, return, end

a = get_param(sp, 'Position');              % 출발 포트
r = get_param(blk, 'Position');
w = r(3)-r(1);  h = r(4)-r(2);

%  이미 포트와 같은 높이에 붙어 있으면 둘 일이 없다
if abs(mid(r) - a(2)) < 0.5 && r(1) > a(1) && ...
   (r(1) - a(1)) <= o.Gap + max(o.Tries) + 2, return, end

seg = lanes(sys, nm);

%  1) 같은 높이 — 선은 수평 직선, 꺾임 0 회
for g = o.Gap + o.Tries
    x = round(a(1) + g);  y = round(a(2));
    if try_put(sys, blk, nm, [x, y-h/2, x+w, y+h/2], [a; x y], ...
               {src_name(sp)}, seg, sp, 'Inport'), moved = 1; return, end
end

%  2) 옆이 전부 차 있으면 **포트 가까이에서** 위아래로 비킨다 (꺾임 1회).
%     멀리 보내지 않는 것이 요점이다 — 태그는 제 신호 곁에 있어야 한다.
for dy = [60 -60 90 -90 120 -120 160 -160 210 -210]
    for g = o.Gap + o.Tries
        x = round(a(1) + g);  y = round(a(2) + dy);
        if try_put(sys, blk, nm, [x, y-h/2, x+w, y+h/2], [a; a(1) y; x y], ...
                   {src_name(sp)}, seg, sp, 'Inport'), moved = 1; return, end
    end
end
end

% =========================================================================
function moved = snug_from(sys, blk, nm, o)
%  From 의 출력 포트를 도착 포트와 **같은 높이**, 한 칸 왼쪽에 둔다.
moved = 0;
ph = get_param(blk, 'PortHandles');
if numel(ph.Outport) ~= 1, return, end
dp = dst_of(ph.Outport(1));
if numel(dp) ~= 1 || dp <= 0, return, end   % 여러 곳으로 갈라지는 From 은 둔다

b  = get_param(dp, 'Position');             % 도착 포트
db = get_param(dp, 'Parent');
dr = get_param(db, 'Position');
%  옆면 포트(왼·오른 테두리)만 같은 높이로 들어올 수 있다. 포트는 테두리보다
%  몇 px 바깥에 있으므로 **블록의 x 범위 밖**이면 옆면이다. 둥근 Sum 의 2번
%  입력처럼 x 범위 **안**에 있는 것은 아래쪽 포트다 (feed_from 과 같은 판정).
side = b(1) <= dr(1) || b(1) >= dr(3);
dnm  = get_param(db, 'Name');

r = get_param(blk, 'Position');
w = r(3)-r(1);  h = r(4)-r(2);
if side && abs(mid(r) - b(2)) < 0.5 && r(3) < b(1) && ...
   (b(1) - r(3)) <= o.Gap + 10 + max(o.Tries) + 2, return, end

seg = lanes(sys, nm);

%  1) 같은 높이 — 선은 수평 직선, 꺾임 0 회
if side
    for g = (o.Gap + 10) + o.Tries
        x = round(b(1) - g);  y = round(b(2));
        if try_put(sys, blk, nm, [x-w, y-h/2, x, y+h/2], [x y; b], ...
                   {dnm}, seg, dp, 'Outport'), moved = 1; return, end
    end
end

%  2) 옆이 차 있거나 포트가 블록 **아래쪽**(둥근 Sum 의 2번)이면 포트 가까이에서
%     위아래로 비킨다. 옆면 포트는 세로로 간 뒤 가로로, 아래쪽 포트는 그 반대다.
for dy = [90 -90 60 -60 120 -120 160 -160 210 -210]
    for g = (o.Gap + 10) + o.Tries
        x = round(b(1) - g);  y = round(b(2) + dy);
        if side, pts = [x y; x b(2); b]; else, pts = [x y; b(1) y; b]; end
        if try_put(sys, blk, nm, [x-w, y-h/2, x, y+h/2], pts, ...
                   {dnm}, seg, dp, 'Outport'), moved = 1; return, end
    end
end
end

% =========================================================================
function ok = try_put(sys, blk, nm, rect, pts, skip, seg, port, kind)
%TRY_PUT  RECT 가 비어 있고 PTS 가 남의 통로를 뺏지 않으면 옮기고 다시 긋는다.
ok = false;
if ~spot_free(sys, rect, nm, pts, skip, {nm}), return, end
if lane_clash(seg, pts), return, end
set_param(blk, 'Position', round(rect));
ph = get_param(blk, 'PortHandles');
if strcmp(kind, 'Inport')
    relink(sys, port, ph.Inport(1), pts);
else
    relink(sys, ph.Outport(1), port, pts);
end
ok = true;
end

% =========================================================================
function relink(sys, sp, dp, pts)
%  가지 하나만 끊고 다시 긋는다. 뿌리 선을 지우면 같은 신호의 다른 가지가 사라진다
cut_line(sys, dp);
draw_line(sys, sp, dp, pts);
end

function y = mid(r), y = (r(2)+r(4))/2; end

function sp = src_of(sys, dp)
%  이 도착 포트로 들어오는 선의 출발 포트
sp = -1;
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    d = get_param(L(i), 'DstPortHandle');
    if ~any(d == dp), continue, end
    h = L(i);
    for depth = 1:16                       % 가지면 뿌리로 올라가 출발 포트를 찾는다
        s = get_param(h, 'SrcPortHandle');
        if s > 0, sp = s; return, end
        try, par = get_param(h, 'LineParent'); catch, break, end
        if isempty(par) || par <= 0, break, end
        h = par;
    end
end
end

function nm = src_name(sp)
nm = get_param(get_param(sp, 'Parent'), 'Name');
end

function dp = dst_of(sp)
%  이 출발 포트에서 나가는 선들의 도착 포트 전부 (가지 포함)
dp = [];
for L = get_param(sp, 'Line')'
    if L <= 0, continue, end
    dp = [dp; collect(L)]; %#ok<AGROW>
end
dp = unique(dp(dp > 0));
end

function d = collect(L)
d = get_param(L, 'DstPortHandle');
d = d(:);
try
    for k = get_param(L, 'LineChildren')'
        d = [d; collect(k)]; %#ok<AGROW>
    end
catch
end
end

% =========================================================================
function seg = lanes(sys, mine)
%LANES  이 시스템의 선 토막들. MINE 에 붙은 선은 뺀다 (다시 그을 것이므로).
%   [가로인가? 좌표 lo hi]
seg = zeros(0,4);
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    if attached(L(i), mine), continue, end
    q = get_param(L(i), 'Points');
    for k = 1:size(q,1)-1
        a = q(k,:);  b = q(k+1,:);
        if abs(a(1)-b(1)) < 1e-6 && abs(a(2)-b(2)) > 1e-6
            seg(end+1,:) = [0 a(1) min(a(2),b(2)) max(a(2),b(2))]; %#ok<AGROW>
        elseif abs(a(2)-b(2)) < 1e-6 && abs(a(1)-b(1)) > 1e-6
            seg(end+1,:) = [1 a(2) min(a(1),b(1)) max(a(1),b(1))]; %#ok<AGROW>
        end
    end
end
end

function tf = attached(L, mine)
tf = false;
for f = {'SrcBlockHandle','DstBlockHandle'}
    try
        h = get_param(L, f{1});
        for k = h(h>0)'
            if strcmp(get_param(k,'Name'), mine), tf = true; return, end
        end
    catch
    end
end
try
    par = get_param(L, 'LineParent');
    if par > 0, tf = attached(par, mine); end
catch
end
end

function tf = lane_clash(seg, pts)
%LANE_CLASH  새 토막이 남의 토막과 같은 직선 위를 나눠 쓰는가 (check_lines 의 (1)).
tf = false;
for k = 1:size(pts,1)-1
    a = pts(k,:);  b = pts(k+1,:);
    if abs(a(2)-b(2)) < 1e-6
        hz = 1;  c = a(2);  lo = min(a(1),b(1));  hi = max(a(1),b(1));
    elseif abs(a(1)-b(1)) < 1e-6
        hz = 0;  c = a(1);  lo = min(a(2),b(2));  hi = max(a(2),b(2));
    else
        continue
    end
    for i = 1:size(seg,1)
        if seg(i,1) ~= hz || abs(seg(i,2)-c) > 1e-6, continue, end
        if min(seg(i,4),hi) - max(seg(i,3),lo) > 1, tf = true; return, end
    end
end
end
