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
%             밖으로 다 밀어 본 뒤에는 **한 번 당겨 본다** (Gap 보다 15 px 가까이).
%             Goto 와 From 이 같은 통로에서 마주 보는 자리가 있다 — 2026-10-15
%             W06_1_point 의 `InnerLoop -> Go_FR … Fr_FR -> MotionModel` 은
%             220 px 틈에 태그 둘(80+70 px)이 들어가야 해서 30 px 자리에서는
%             두 상자가 15 px 겹친다. 하나가 당겨 앉으면 둘 다 직선이 된다
%     'Passes' 다시 돌아 볼 횟수. 기본 5 (옮긴 것이 없으면 그 자리에서 그친다)
%
%   돌려주는 값은 자리를 옮긴 태그의 수다.

p = inputParser;
p.addParameter('Gap',    30);
p.addParameter('Tries',  [0 40 90 150 220]);
p.addParameter('Passes', 5);
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

%  그 안에서는 **직선으로 앉을 수 있는 태그가 먼저** 자리를 고른다. 비켜 앉을
%  태그(제 포트가 다른 블록으로도 가지를 치는 것)는 어차피 한 번 꺾이므로 남은
%  자리를 쓰면 된다. 순서를 안 두면 비켜 앉을 태그가 이웃 포트의 높이를 먼저
%  차지해 **직선으로 앉을 수 있던 태그를 밀어낸다** — 2026-10-15 W06_1_point 에서
%  `Go_y_ref` 가 120 px 아래로 비켜 앉아 `Go_gate` 의 높이(y = 220)를 덮었다.
rank = zeros(1, numel(blks));
for i = order, rank(i) = tag_rank(sys, blks{i}, kind{i}); end
[~, k] = sort(rank(order), 'ascend');
order  = order(k);

%  한 번만 돌면 태그가 서로의 자리를 막는다. 태그 다섯 개가 제 포트보다 한 칸
%  위에 줄지어 서 있으면 첫째는 둘째가 앉은 자리를 노리고 둘째는 셋째의 자리를
%  노린다 — 맨 아래 하나만 옮겨지고 나머지는 그대로 남는다 (2026-10-14
%  W06_3_thrust 에서 Fr_v 가 OuterLoop 선의 통로에 남아 겹침·블록관통 3건).
%  아래 것이 비켜 주면 위 것의 자리가 열리므로, 옮긴 것이 없을 때까지 다시 돈다
for pass = 1:o.Passes
    moved = 0;
    for i = order
        blk = blks{i};
        nm  = get_param(blk, 'Name');
        if strcmp(kind{i}, 'Goto')
            moved = moved + snug_goto(sys, blk, nm, o);
        else
            moved = moved + snug_from(sys, blk, nm, o);
        end
    end
    n = n + moved;
    if moved == 0, break, end
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

%  이미 **제 자리**에 앉아 있으면 둘 일이 없다. 제 자리는 포트와 같은 높이,
%  포트에서 Gap 만큼 오른쪽이다. "그 언저리면 됐다" 로 넘기면 열이 들쭉날쭉해진다 —
%  2026-10-15 W06_1_point 의 `Fr_gate` 가 제 열에서 90 px 튀어나온 채로 남았다.
%  교수 지시 2026-10-15 — "가능하면 위치도 통일해서… 가로 세로도 정렬 되도록."
%  같은 블록에 붙는 태그는 Gap 이 같으므로, 제 자리에 앉히면 열이 저절로 맞는다.
if abs(mid(r) - a(2)) < 0.5 && abs((r(1) - a(1)) - o.Gap) <= 2, return, end

seg = lanes(sys, nm);
gaps = try_gaps(o);

%  같은 포트에서 **더 오른쪽으로** 가는 다른 선이 있으면 그 높이는 그 선의
%  통로다. 태그를 거기 앉히면 선이 태그를 돌아 세 번 꺾인다
%  (2026-10-14 W06_1_point — Go_x_ref 가 Guidance/1 -> OuterLoop/1 통로에 앉아
%   직선이던 선이 215 -> 195 -> 345 -> 70 으로 돌아갔다).
%  그때는 1) 을 건너뛰고 포트 가까이에서 위아래로 비킨다
if ~right_run(sp, a, blk)
    %  1) 같은 높이 — 선은 수평 직선, 꺾임 0 회
    for g = gaps
        x = round(a(1) + g);  y = round(a(2));
        if try_put(sys, blk, nm, [x, y-h/2, x+w, y+h/2], [a; x y], ...
                   {src_name(sp)}, seg, sp, 'Inport'), moved = 1; return, end
    end
end

%  2) 옆이 전부 차 있으면 **포트 가까이에서** 위아래로 비킨다 (꺾임 1회).
%     멀리 보내지 않는 것이 요점이다 — 태그는 제 신호 곁에 있어야 한다.
%
%     비키는 쪽은 포트 줄의 **바깥쪽**이다. 안쪽으로 비키면 이웃 포트의 높이에
%     앉아 그 포트의 태그가 직선으로 못 나간다 — 2026-10-15 W06_1_point 에서
%     Guidance 의 2 번 출력 태그(`Go_y_ref`)가 60 px 아래로 비켜 3 번 출력
%     높이(y = 170)를 덮었고, 그래서 `Go_psi_ref` 가 두 번 꺾여 내려갔다.
for dy = aside_order(sp)
    for g = gaps
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
if side && abs(mid(r) - b(2)) < 0.5 && abs((b(1) - r(3)) - (o.Gap + 10)) <= 2, return, end

seg = lanes(sys, nm);
gaps = try_gaps(o) + 10;

%  1) 같은 높이 — 선은 수평 직선, 꺾임 0 회
if side
    for g = gaps
        x = round(b(1) - g);  y = round(b(2));
        if try_put(sys, blk, nm, [x-w, y-h/2, x, y+h/2], [x y; b], ...
                   {dnm}, seg, dp, 'Outport'), moved = 1; return, end
    end
end

%  2) 옆이 차 있거나 포트가 블록 **아래쪽**(둥근 Sum 의 2번)이면 포트 가까이에서
%     위아래로 비킨다. 옆면 포트는 세로로 간 뒤 가로로, 아래쪽 포트는 그 반대다.
for dy = [90 -90 60 -60 120 -120 160 -160 210 -210]
    for g = gaps
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

function r = tag_rank(sys, blk, kind)
%TAG_RANK  자리를 고르는 차례. 작을수록 먼저다.
%   1 직선으로 앉을 수 있는 Goto   2 비켜 앉을 Goto
%   3 옆면 포트로 들어가는 From     4 아래쪽 포트로 들어가는 From (둥근 Sum 의 2번)
r = 4;
ph = get_param(blk, 'PortHandles');
try
    if strcmp(kind, 'Goto')
        r  = 2;
        if numel(ph.Inport) ~= 1, return, end
        sp = src_of(sys, ph.Inport(1));
        if sp <= 0, return, end
        if ~right_run(sp, get_param(sp,'Position'), blk), r = 1; end
    else
        if numel(ph.Outport) ~= 1, return, end
        dp = dst_of(ph.Outport(1));
        if numel(dp) ~= 1 || dp <= 0, return, end
        b  = get_param(dp, 'Position');
        dr = get_param(get_param(dp,'Parent'), 'Position');
        if b(1) <= dr(1) || b(1) >= dr(3), r = 3; end
    end
catch
end
end

function dys = aside_order(sp)
%ASIDE_ORDER  비켜 볼 높이들 — 포트 줄의 바깥쪽을 먼저 본다.
%   출발 포트가 그 블록 출력 줄의 위쪽 절반이면 위로, 아래쪽 절반이면 아래로.
%   포트가 하나뿐이면 이웃이 없으니 순서를 바꿀 까닭이 없다.
dys = [60 -60 90 -90 120 -120 160 -160 210 -210];
try
    ph = get_param(get_param(sp,'Parent'), 'PortHandles');
    y  = arrayfun(@(h) get_param(h,'Position')*[0;1], ph.Outport);
    if numel(y) < 2, return, end
    a2 = get_param(sp,'Position')*[0;1];
    if a2 <= (min(y) + max(y))/2
        dys = -dys;                            % 위쪽 절반 — 위로 비킨다
    end

    %  이웃 포트의 높이는 그 포트의 태그가 쓸 자리다. 태그 상자는 26 px 이므로
    %  30 px 안쪽으로 다가가면 두 상자가 겹친다. 그 높이들은 아예 빼고 고른다 —
    %  그래야 **직선으로 앉을 수 있는 이웃이 제 높이를 지킨다**.
    other = y(abs(y - a2) > 1);
    if ~isempty(other)
        ok = arrayfun(@(d) all(abs(a2 + d - other) >= 30), dys);
        if any(ok), dys = dys(ok); end
    end
catch
end
end

function g = try_gaps(o)
%TRY_GAPS  포트에서 태그까지 재 볼 거리들 — 밖으로 밀어 보고, 마지막에 당겨 본다.
%   당기는 자리는 Gap 보다 15 px 가깝다. 포트에서 10 px 안쪽으로는 가지 않는다 —
%   그만큼 붙으면 태그 상자가 포트 화살표를 덮는다.
g = o.Gap + o.Tries;
if o.Gap - 15 >= 10, g = [g, o.Gap - 15]; end
end

function tf = right_run(sp, a, me)
%RIGHT_RUN  이 출발 포트에서 오른쪽으로 더 가는 **다른** 도착지가 있는가.
%   있으면 출발 포트 높이는 그 선이 쓸 통로이므로 태그가 비켜 주어야 한다.
%
%   가지 친 선은 뿌리의 DstPortHandle 이 -1 이라 선으로는 세기 어렵다. 그래서
%   출발 블록의 PortConnectivity 로 이 포트의 도착 블록들을 바로 읽는다.
%
%   ME 는 지금 옮기려는 태그다. **빼고 세지 않으면 스스로를 장애물로 센다.**
%   태그가 제 포트에서 멀리 끌려가 있는 상태(바로 이 도구가 고치려는 상태)는
%   언제나 `q(1) > a(1)+80` 이므로, 빼지 않으면 모든 태그가 1) 같은 높이를
%   건너뛰고 2) 로 내려가 꺾임이 1 회씩 남는다 — 2026-10-15 W06_1_point 에서
%   MotionModel 의 출력 9 개가 전부 그랬다 (Goto 는 x = 1795, 포트는 x = 1545).
tf = false;
sb = get_param(sp, 'Parent');
k  = get_param(sp, 'PortNumber');
pc = get_param(sb, 'PortConnectivity');
mh = get_param(me, 'Handle');
for i = 1:numel(pc)
    if isempty(pc(i).DstBlock), continue, end             % 출력 포트만 DstBlock 을 갖는다
    if ~strcmp(pc(i).Type, num2str(k)), continue, end
    for j = 1:numel(pc(i).DstBlock)
        if pc(i).DstBlock(j) == mh, continue, end          % 나는 비켜 줄 상대가 아니다
        q = get_param(pc(i).DstBlock(j), 'Position');
        if q(1) > a(1) + 80, tf = true; return, end        % 태그가 들어설 자리보다 멀다
    end
end
end

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
        %  두 토막이 8 px 안에 들어오면 인쇄물에선 한 선이다 (check_lines 와 같은 잣대).
        %  좌표가 꼭 같은지만 물으면 빗나간다 — 옮길 자리로 미리 그려 본 점은
        %  태그의 테두리이고 진짜 선은 그 5 px 밖 포트에서 시작하므로, 1e-6 로
        %  물으면 바로 옆의 통로를 빈 자리로 보고 앉는다 — 2026-10-14 W06_1_point 에서
        %  Fr_x_n 과 Fr_y_n 의 세로 토막이 x = 430 에서 10 px 겹쳤다
        if seg(i,1) ~= hz || abs(seg(i,2)-c) > 8, continue, end
        if min(seg(i,4),hi) - max(seg(i,3),lo) > 1, tf = true; return, end
    end
end
end
