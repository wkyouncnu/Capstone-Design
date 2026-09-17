function moved = lay_sinks(sys, varargin)
%LAY_SINKS  선이 지저분해진 종착 블록만 아래 한 열로 내리고, 갈래마다 제 통로를 준다.
%
%   lay_sinks('W04_1_sensor_rates')
%   n = lay_sinks(m, 'Band', 120, 'Row', 45, 'Lane', 26)
%
%   종착 블록 / a sink
%       출력이 없고 입력만 있는 블록 — Display, To Workspace, Goto, Scope,
%       Terminator, 그리고 입력만 받는 서브시스템. Outport 는 뺀다. 종착처럼
%       보이지만 바깥 사슬로 신호를 **내보내는** 자리라, 서브시스템 오른쪽
%       테두리에 포트 순서대로 있어야 한다.
%
%   무엇을 고치는가 / what it fixes
%       한 출력이 Display 와 Goto 둘로 갈라지면 배치기는 둘을 **같은 줄에**
%       나란히 놓는다. 그러면 뒤쪽으로 가는 가지가 앞쪽 블록을 가로지르고,
%       도면은 "Display 를 지난 신호가 Goto 로 간다" 고 거짓말을 한다.
%
%           나쁨                              좋음
%           Sel ──┬──▶[log_x]──▶[Disp_x]      Sel ──────▶[log_x]
%                 └──▶ (관통)                       └──────▶[Disp_x]
%
%   무엇을 건드리지 않는가 / what it leaves alone
%       **이미 깨끗한 선은 손대지 않는다.** 깨끗하다는 것은 두 포트의 높이가
%       같아 직선 한 토막이고, 그 토막이 어떤 블록도 지나지 않는다는 뜻이다.
%       1:1 로 곧게 이어진 선까지 아래로 내리면 내려간 선들이 통로에 몰려
%       서로 겹친다 (2026-09-17 에 W04 Logging 에서 15건 재현).
%
%       사슬 블록과 사슬 선은 그대로 두므로
%       Simulink.BlockDiagram.arrangeSystem 뒤에 이어서 부를 수 있다.
%
%   통로는 모두 다른 x 를 쓴다 / every lane gets its own x
%       내려간 선은 전부 같은 구역으로 모이므로, 두 통로가 x 를 나눠 쓰면
%       어딘가에서 반드시 겹친다. 그래서 통로 x 는 시스템 전체에서 유일하다.
%
%   돌려주는 값은 자리를 옮긴 블록의 수다.

p = inputParser;
p.addParameter('Band', 100);
p.addParameter('Row',   45);
p.addParameter('Lane',  26);
p.addParameter('Out',  120);
p.addParameter('All', false);
p.parse(varargin{:});
o = p.Results;
moved = 0;

blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));
if isempty(blks), return, end

name = cell(numel(blks),1);  box = zeros(numel(blks),4);
sink = false(numel(blks),1);
for i = 1:numel(blks)
    name{i} = get_param(blks{i}, 'Name');
    box(i,:) = get_param(blks{i}, 'Position');
    ph = get_param(blks{i}, 'PortHandles');
    sink(i) = isempty(ph.Outport) && ~isempty(ph.Inport) && ...
              ~strcmp(get_param(blks{i}, 'BlockType'), 'Outport');
end
if ~any(sink), return, end

% --- 1) 종착 블록으로 가는 연결을 모은다 --------------------------------
conn = struct('src',{},'sp',{},'dst',{},'dp',{},'h',{});
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    s = get_param(L(i), 'SrcPortHandle');
    if s < 0, continue, end
    for dd = get_param(L(i), 'DstPortHandle')'
        if dd < 0, continue, end
        dn = get_param(get_param(dd,'Parent'), 'Name');
        if ~any(sink & strcmp(name, dn)), continue, end
        conn(end+1) = struct( ...
            'src', get_param(get_param(s,'Parent'), 'Name'), ...
            'sp',  get_param(s,  'PortNumber'), ...
            'dst', dn, 'dp', get_param(dd,'PortNumber'), 'h', L(i)); %#ok<AGROW>
    end
end
if isempty(conn), return, end

%  팬아웃은 부모선과 가지선이 같은 (출발, 도착) 을 두 번 보고한다. 그대로 두면
%  같은 자리에 선을 두 번 그어 길이 0 인 토막이 남는다 — lay_chain 과 같은 문제.
key = arrayfun(@(c) sprintf('%s|%d|%s|%d', c.src, c.sp, c.dst, c.dp), ...
               conn, 'UniformOutput', false);
[~, ia] = unique(key, 'stable');
conn    = conn(ia);

% --- 2) 이미 깨끗한 선인가 ----------------------------------------------
dirty = false(numel(conn),1);
for i = 1:numel(conn)
    a = port_xy(sys, conn(i).src, 'Outport', conn(i).sp);
    b = port_xy(sys, conn(i).dst, 'Inport',  conn(i).dp);
    keep = ~strcmp(name, conn(i).src) & ~strcmp(name, conn(i).dst);
    dirty(i) = o.All || abs(a(2)-b(2)) >= 0.5 || hits_any(box(keep,:), a, b);
end

% --- 3) 한 선이라도 지저분하면 그 종착 블록을 통째로 내린다 --------------
%  입력이 여럿인 종착 블록(Record 등)은 선 하나만 다시 그으면 나머지 선이
%  옛 자리를 가리킨 채 남는다. 그래서 블록 단위로 정한다.
down = unique({conn(dirty).dst});
if isempty(down), return, end
mv   = find(ismember({conn.dst}, down));

%  가지 하나만 끊는다. 뿌리 선을 지우면 같은 신호의 다른 가지까지 사라진다
for i = mv
    pd = get_param([sys '/' conn(i).dst], 'PortHandles');
    cut_line(sys, pd.Inport(conn(i).dp));
end

% --- 4) 남는 블록들 아래에 종착 구역을 연다 ------------------------------
stay  = ~ismember(name, down);
occ   = box(stay,:);
%  남은 선들보다도 아래여야 한다. lay_feedback 이 되먹임을 블록 아래 통로로
%  돌려 놓았다면, 종착 구역이 그 통로 위에 앉아 선을 관통한다.
yLine = -inf;
for i = 1:numel(L)
    if ~ishandle(L(i)), continue, end
    try, q = get_param(L(i), 'Points'); catch, continue, end
    yLine = max(yLine, max(q(:,2)));
end
yBand = max(max(occ(:,4)), yLine) + o.Band;

% --- 5) 통로 x 를 시스템 전체에서 유일하게 준다 --------------------------
%  내려간 선은 모두 같은 구역으로 모인다. 두 통로가 x 를 나눠 쓰면 반드시
%  어딘가에서 겹치므로, 이미 쓴 x 와 블록을 뚫는 x 를 모두 피한다.
lane  = zeros(numel(conn),1);
taken = [];
for i = mv
    a = port_xy(sys, conn(i).src, 'Outport', conn(i).sp);
    r = get_param([sys '/' conn(i).src], 'Position');

    %  가로로 달릴 수 있는 한계 — 이 포트 높이에서 처음 만나는 블록 앞까지.
    %  그 너머로는 아무리 밀어도 가로 토막이 그 블록을 뚫는다. 한계를 모르고
    %  계속 밀면 통로가 도면 밖까지 나가 그림이 두세 배로 넓어진다
    %  (2026-09-17 W03_1 이 2823 px -> 5890 px 로 벌어졌다).
    xmax = inf;
    for q = 1:size(occ,1)
        if occ(q,2)+2 < a(2) && a(2) < occ(q,4)-2 && occ(q,1) > a(1)
            xmax = min(xmax, occ(q,1) - 4);
        end
    end

    x = r(3);  got = [];
    while x <= xmax
        if ~any(taken == x) && ~hits_any(occ, [x a(2)], [x yBand])
            got = x; break
        end
        x = x + o.Lane;
    end
    if isempty(got)
        %  한계 안에 깨끗한 자리가 없다. 그래도 **유일하기는** 해야 한다.
        %  겹친 통로는 인쇄물에서 한 선이 되지만, 블록을 스치는 통로는
        %  뒤에 오는 lay_links 가 다시 그어 준다 (2026-09-17 W06_5 에서 재현).
        got = r(3);
        while any(taken == got), got = got + o.Lane; end
    end
    x = got;
    lane(i)      = x;
    taken(end+1) = x; %#ok<AGROW>
end

% --- 6) 종착 블록을 통로 오른쪽 한 열에 쌓는다 ---------------------------
%  한 줄에 하나씩만 둔다. 그래야 통로에서 블록으로 들어가는 마지막 가로 토막이
%  제 블록 말고는 아무것도 만나지 않는다.
x0   = max(lane(mv)) + o.Out;
row  = 0;
done = containers.Map('KeyType','char','ValueType','logical');
for i = mv
    if isKey(done, conn(i).dst), continue, end     % 입력이 여럿인 블록 — 이미 놓았다
    done(conn(i).dst) = true;
    b = get_param([sys '/' conn(i).dst], 'Position');
    w = b(3)-b(1);  h = b(4)-b(2);
    y = yBand + o.Row*row;
    set_param([sys '/' conn(i).dst], 'Position', round([x0 y x0+w y+h]));
    row   = row + 1;
    moved = moved + 1;
end

% --- 7) 선을 다시 긋는다 -------------------------------------------------
for i = mv
    a = port_xy(sys, conn(i).src, 'Outport', conn(i).sp);
    b = port_xy(sys, conn(i).dst, 'Inport',  conn(i).dp);
    x = lane(i);
    if abs(a(2)-b(2)) < 0.5
        pts = [a; b];
    elseif abs(x - a(1)) < 0.5
        pts = [a; x b(2); b];                   % 포트 바로 아래로 — 꺾임 1회
    else
        pts = [a; x a(2); x b(2); b];           % 꺾임 2회
    end
    %  포트로 먼저 잇는다. 점만 주면 끝점이 포트에 붙지 않고 매달릴 수 있다
    ps = get_param([sys '/' conn(i).src], 'PortHandles');
    pd = get_param([sys '/' conn(i).dst], 'PortHandles');
    draw_line(sys, ps.Outport(conn(i).sp), pd.Inport(conn(i).dp), pts);
end
end

% -------------------------------------------------------------------------
function tf = hits_any(occ, a, b)
%HITS_ANY  구간 a-b 가 사각형 하나라도 안쪽으로 지나는가. check_lines 와 같은 판정.
M  = 2;
tf = false;
d  = b - a;
if all(abs(d) < 1e-6), return, end
for i = 1:size(occ,1)
    r  = occ(i,:);
    lo = [r(1)+M, r(2)+M];
    hi = [r(3)-M, r(4)-M];
    if any(hi <= lo), continue, end
    t0 = 0;  t1 = 1;  out = false;
    for k = 1:2
        if abs(d(k)) < 1e-9
            if a(k) <= lo(k) || a(k) >= hi(k), out = true; break, end
        else
            ta = (lo(k) - a(k)) / d(k);
            tb = (hi(k) - a(k)) / d(k);
            if ta > tb, tmp = ta; ta = tb; tb = tmp; end
            t0 = max(t0, ta);  t1 = min(t1, tb);
            if t0 >= t1, out = true; break, end
        end
    end
    if ~out && (t1 - t0) > 1e-6, tf = true; return, end
end
end
