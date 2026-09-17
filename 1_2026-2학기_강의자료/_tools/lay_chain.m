function lay_chain(m, stages, varargin)
%LAY_CHAIN  최상위를 GNC 신호 사슬로 배치하고, 모든 선을 규칙대로 다시 긋는다.
%
%   lay_chain('W07_0_offline', {'Guidance','InnerLoop','Thrusters','MotionModel'})
%   lay_chain(m, stages, 'Row', 400, 'Pitch', 330, 'Boxes', {'Animate','Logging'})
%
%   하는 일 / what it does
%     1) 사슬 단계를 한 줄 위에 **가운데 정렬**로 놓는다 (왼쪽 -> 오른쪽)
%     2) 최상위의 모든 신호선을 지웠다가 다시 긋는다
%        - 사슬 단계끼리 : 통로 x = 출발 포트 x  -> 꺾임 1회
%        - Goto  : 출발 포트 높이로 옮기고 오른쪽에 붙인다 -> **직선**
%        - From  : 도착 포트 높이로 옮기고 왼쪽에 붙인다  -> **직선**
%     3) 포트 없는 상자(Animate·Logging)는 사슬 아래에 나란히 놓는다
%
%   왜 tidy_layout 을 쓰지 않는가 / why not tidy_layout
%       tidy_layout 은 autorouting 에 배선을 맡긴다. autorouting 은 짧은 경로를
%       고르지 **읽기 좋은** 경로를 고르지 않는다. 그래서 같은 통로를 여러 신호가
%       나눠 쓰고(겹침), 블록 사이가 좁으면 블록 위를 지나간다(관통).
%       배치를 정하면 배선은 따라온다 — references/line-routing.md
%
%   NAME/VALUE
%     'Row'    사슬이 놓이는 높이. 기본 400
%     'Pitch'  단계 사이의 간격. 기본 340. 태그 열과 통로가 들어갈 만큼 띄운다 —
%              좁히면 From 태그 열과 사슬 통로가 부딪힌다 (2026-09-17 W07 에서 재현)
%     'X0'     첫 단계의 왼쪽. 기본 260
%     'Boxes'  포트 없는 서브시스템 이름들. 사슬 아래에 놓는다
%     'Gap'    태그 블록과 포트 사이의 간격. 기본 45
%     'Wrap'   한 줄에 놓을 단계 수. 기본 inf (한 줄)
%
%   줄 접기 / wrapping the chain
%       다섯 칸짜리 사슬을 한 줄에 놓으면 캔버스가 2700 x 800 이 된다. 가로세로 비가
%       3:1 이 넘으면 그림을 쪽 너비에 맞추는 순간 세로가 남고, 글씨는 읽을 수
%       없을 만큼 작아진다. **같은 픽셀 예산이면 정사각형에 가까울수록 크게 보인다.**
%
%       'Wrap' 을 주면 사슬을 여러 줄로 접는다. 줄이 바뀌는 자리의 연결은
%       Goto/From 한 쌍으로 바꾼다 — 선으로 이으면 오른쪽 끝에서 왼쪽 끝으로
%       거슬러 올라가야 해서 도면을 가로지른다.
%
%       측정 (W10_0_offline, 39블록) — 한 줄 3660 x 624 에서 두 줄 1900 x 1290 으로.
%       2000 px 안에 담을 때 39 dpi 에서 79 dpi 로, 글씨 크기가 두 배가 된다.

p = inputParser;
p.addParameter('Row',   400);
p.addParameter('Pitch', 340);
p.addParameter('X0',    260);
p.addParameter('Boxes', {});
p.addParameter('Gap',   45);
p.addParameter('Wrap',  inf);
p.parse(varargin{:});
o = p.Results;

opened = false;
if ~bdIsLoaded(m), load_system(m); opened = true; end

% --- 1) 연결을 기억한다 ------------------------------------------------
conn = grab(m);

%  블록마다 태그가 몇 개 달리는지 먼저 센다. 태그 열은 통로들 오른쪽에 와야 하고,
%  단계 사이 간격은 그 열이 들어갈 만큼은 되어야 한다. 넉넉히 잡으면 사슬 한 칸이
%  그만큼 넓어져 일곱 칸짜리 도면이 8000 px 을 넘는다 (2026-09-17 측정).
cnt = containers.Map('KeyType','char','ValueType','double');
for i = 1:numel(conn)
    if is_type(m, conn(i).dst, 'Goto')
        if ~isKey(cnt, conn(i).src), cnt(conn(i).src) = 0; end
        cnt(conn(i).src) = cnt(conn(i).src) + 1;
    end
end




% --- 2) 선을 전부 지운다 ----------------------------------------------
L = find_system(m, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    try, delete_line(L(i)); catch, end
end

% --- 3) 사슬 단계를 줄에 나누어 놓는다 ---------------------------------
%   포트가 많은 블록은 **키운다.** 포트 간격이 52 px 보다 좁으면 옆에 붙는 태그가
%   서로 겹치고, 겹친 태그를 피하느라 선이 네 번 꺾인다 (2026-09-16 재현).
%  ceil(k/Inf) 은 0 이라 줄 번호가 전부 0 이 되고, 뒤의 줄 반복이 한 번도 돌지
%  않아 블록이 하나도 놓이지 않는다. 한 줄이면 단계 수를 그대로 쓴다.
wrap  = max(1, min(o.Wrap, numel(stages)));
rowOf = containers.Map('KeyType','char','ValueType','double');
for k = 1:numel(stages), rowOf(stages{k}) = ceil(k / wrap); end

%  줄이 바뀌는 자리의 연결은 곧 태그 한 쌍이 된다 (3.5). 태그가 늘면 그 블록 아래
%  더미도 깊어지므로, 자리를 잡기 **전에** 미리 세어 둔다.
for i = 1:numel(conn)
    c = conn(i);
    if ~isKey(rowOf, c.src) || ~isKey(rowOf, c.dst), continue, end
    if rowOf(c.src) == rowOf(c.dst), continue, end
    if ~isKey(cnt, c.src), cnt(c.src) = 0; end
    cnt(c.src) = cnt(c.src) + 1;
end

%  크기를 먼저 정하고, 줄마다 **가장 큰 블록**에 맞춰 높이를 잡는다. 한 블록의
%  가운데에 맞춰 줄을 시작하면 그 줄의 키 큰 블록이 위아래로 삐져나와 옆 줄과
%  겹친다 (2026-09-17 W08_0 에서 InnerLoop 와 MotionModel 이 40 px 겹쳤다).
W = zeros(1,numel(stages));  H = zeros(1,numel(stages));  D = zeros(1,numel(stages));
for k = 1:numel(stages)
    r  = get_param([m '/' stages{k}], 'Position');
    ph = get_param([m '/' stages{k}], 'PortHandles');
    n  = max([numel(ph.Inport), numel(ph.Outport), 2]);
    W(k) = r(3)-r(1);
    H(k) = max(r(4)-r(2), 52*(n-1) + 40);
    nt   = 0;  if isKey(cnt, stages{k}), nt = cnt(stages{k}); end
    D(k) = 70 + 45*max(nt-1,0) + 26;          % 블록 아래 태그 더미의 깊이
end

nRow = 0;
for k = 1:numel(stages), nRow = max(nRow, rowOf(stages{k})); end
yTop = o.Row;
for rr = 1:nRow
    idx  = find(cellfun(@(s) rowOf(s) == rr, stages));
    hMax = max(H(idx));
    yc   = yTop + hMax/2;
    x    = o.X0;
    for k = idx
        set_param([m '/' stages{k}], 'Position', ...
                  round([x, yc-H(k)/2, x+W(k), yc+H(k)/2]));
        %  간격은 **그 단계가 내는 태그 수**에 맞춘다. 태그가 여덟 개인 블록 하나
        %  때문에 모든 칸을 넓히면 도면이 통째로 늘어난다 (W07_1_vrx 가 그랬다).
        g  = o.Pitch;
        nt = 0;  if isKey(cnt, stages{k}), nt = cnt(stages{k}); end
        if nt > 0, g = max(g, 26*nt + 130); end
        x = x + W(k) + g;
    end
    yTop = yc + max(hMax/2, max(D(idx))) + 90;
end
yBot = yTop - 90;

% --- 3.5) 줄이 바뀌는 자리는 태그 한 쌍으로 -----------------------------
%   오른쪽 끝에서 왼쪽 끝으로 선을 끌면 도면을 통째로 가로지른다. 사슬이 줄을
%   바꾸는 자리에서는 신호에 이름을 붙여 내보내고 받는다.
isStage = @(nm) isKey(rowOf, nm);
for i = 1:numel(conn)
    c = conn(i);
    if ~isStage(c.src) || ~isStage(c.dst), continue, end
    if rowOf(c.src) == rowOf(c.dst), continue, end
    tag = matlab.lang.makeValidName(sprintf('%s_%d', c.src, c.sp));
    j   = 0;
    while ~isempty(find_system(m,'SearchDepth',1,'BlockType','Goto','GotoTag',tag))
        j = j + 1;
        tag = matlab.lang.makeValidName(sprintf('%s_%d_%d', c.src, c.sp, j));
    end
    g = add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], ...
                  'MakeNameUnique','on', 'Position',[0 0 60 22], ...
                  'GotoTag', tag, 'TagVisibility','local');
    f = add_block('simulink/Signal Routing/From', [m '/Fr_' tag], ...
                  'MakeNameUnique','on', 'Position',[0 0 60 22], 'GotoTag', tag);
    gn = get_param(g, 'Name');  fn = get_param(f, 'Name');
    conn(i) = struct('src', c.src, 'sp', c.sp, 'dst', gn, 'dp', 1);
    conn(end+1) = struct('src', fn, 'sp', 1, 'dst', c.dst, 'dp', c.dp); %#ok<AGROW>
end

% --- 4) 포트 없는 상자는 맨 아래에 --------------------------------------
%   아래 줄도 사슬 폭을 넘으면 접는다. 상자 몇 개 때문에 도면 전체가 옆으로
%   늘어나면 사슬을 접은 뜻이 없다 (2026-09-17 W10_1 이 그랬다).
xLim = o.X0;
for k = 1:numel(stages)
    r    = get_param([m '/' stages{k}], 'Position');
    xLim = max(xLim, r(3));
end
bx = o.X0;  by = yBot + 120;  bh = 0;
for k = 1:numel(o.Boxes)
    b = [m '/' o.Boxes{k}];
    if ~ismember(b, find_system(m,'SearchDepth',1,'Type','Block')), continue, end
    r = get_param(b, 'Position');
    w = r(3)-r(1);  h = r(4)-r(2);
    if bx > o.X0 && bx + w > xLim, bx = o.X0;  by = by + bh + 70;  bh = 0; end
    set_param(b, 'Position', round([bx, by, bx+w, by+h]));
    bx = bx + w + 170;
    bh = max(bh, h);
end

%  사슬에도 상자에도 들지 않은 블록 — 태그에만 신호를 주는 상수 따위. 자리를 정해
%  주지 않으면 빌더가 놓았던 자리에 그대로 남아 도면을 옆으로 늘린다
%  (2026-09-17 W10_1 의 ZeroEnv·ZeroThr 가 x=2440 에 남아 폭이 2685 였다).
%
%  **사슬로 신호를 주는 블록은 내리지 않는다.** 그런 블록은 받는 포트 옆에 있어야
%  선이 곧다. 아래로 내리면 화면을 가로질러 올라오며 남의 태그를 뚫는다
%  (2026-09-17 W09_1 의 URf2 가 Go_chi 를 뚫었다).
rest = find_system(m, 'SearchDepth',1, 'Type','Block');
for k = 1:numel(rest)
    nmk = get_param(rest{k}, 'Name');
    if strcmp(rest{k}, m), continue, end
    if ismember(nmk, stages) || ismember(nmk, o.Boxes), continue, end
    if any(strcmp(get_param(rest{k},'BlockType'), {'Goto','From'})), continue, end
    feeds = false;
    for i = 1:numel(conn)
        if strcmp(conn(i).src, nmk) && isKey(rowOf, conn(i).dst), feeds = true; break, end
    end
    if feeds, continue, end          % 사슬 먹임 — 5)에서 받는 포트 옆에 놓는다
    r = get_param(rest{k}, 'Position');
    w = r(3)-r(1);  h = r(4)-r(2);
    if bx > o.X0 && bx + w + 130 > xLim, bx = o.X0;  by = by + bh + 70;  bh = 0; end
    set_param(rest{k}, 'Position', round([bx, by, bx+w, by+h]));
    bx = bx + w + 200;
    bh = max(bh, max(h, 120));       % 이 상수의 태그가 아래에 쌓인다
end
yBot = by + bh;

% --- 5) 태그 블록을 짝의 포트 높이로 옮긴다 ------------------------------
%   그러면 태그로 가는 선이 **직선 한 토막**이 된다. 태그는 신호 사슬이 아니라
%   "여기서 이 신호가 나간다" 는 표시이므로, 포트 바로 옆에 있어야 읽힌다.
%   같은 자리에 둘이 겹치면 한쪽을 아래로 밀어 둔다.
%   Goto 는 포트 높이에 두지 않는다. 같은 포트에서 본선도 나가기 때문에,
%   태그를 포트 옆에 두면 본선이 **태그를 관통한다** (2026-09-16 재현).
%   그래서 태그는 내는 블록 **아래**에 한 열로 쌓는다.
%
%   통로 x 는 **도면 전체에서** 겹치지 않아야 한다. 사슬을 여러 줄로 접으면 윗줄과
%   아랫줄의 같은 칸이 x 를 나눠 쓰게 되고, 두 신호의 세로 토막이 포개진다
%   (2026-09-17 W07_0 을 두 줄로 접었을 때 재현). 높이가 겹치는 통로끼리만
%   따지면 되므로, 쓰고 있는 [x, 위, 아래] 를 적어 두고 부딪히면 옆으로 민다.
used  = zeros(0, 2);
busy  = zeros(0, 3);
nTag  = containers.Map('KeyType','char','ValueType','double');
lane  = containers.Map('KeyType','char','ValueType','double');
tagY  = containers.Map('KeyType','char','ValueType','double');
colOf = containers.Map('KeyType','char','ValueType','double');

for i = 1:numel(conn)
    c = conn(i);
    if is_type(m, c.dst, 'Goto')
        r = get_param([m '/' c.src], 'Position');
        if ~isKey(nTag, c.src), nTag(c.src) = 0; end
        j = nTag(c.src);  nTag(c.src) = j + 1;
        ty = r(4) + 70 + 45*j;
        lx = r(3) + 18 + 26*j;
        while ~isempty(busy) && ...
              any(abs(busy(:,1)-lx) < 1 & busy(:,2) < ty-1 & r(2) < busy(:,3)-1)
            lx = lx + 26;
        end
        busy(end+1,:) = [lx, r(2), ty]; %#ok<AGROW>
        lane(c.dst)   = lx;
        tagY(c.dst)   = ty;
        if ~isKey(colOf, c.src), colOf(c.src) = r(3) + 250; end
        colOf(c.src) = max(colOf(c.src), lx + 40);   % 태그 열은 마지막 통로보다 오른쪽
    elseif isKey(rowOf, c.dst) && ~isKey(rowOf, c.src) && ...
           ~ismember(c.src, o.Boxes) && ~is_type(m, c.src, 'Goto')
        %  From 태그와 사슬을 먹이는 상수 — 둘 다 받는 포트 **왼쪽**에 둔다.
        %  그러면 선이 곧고, 무엇이 그 포트로 들어오는지 한눈에 읽힌다.
        q = port_xy(m, c.dst, 'Inport', c.dp);
        [x, y] = free_slot(used, q(1)-o.Gap, q(2));
        used(end+1,:) = [x y]; %#ok<AGROW>
        move_to(m, c.src, x, y, 'right');                 % 출력이 오른쪽 테두리
    end
end

%  통로가 다 정해진 뒤에야 태그 열의 x 를 알 수 있다. 그래서 자리 옮기기는 뒤로 미룬다
for c = keys(tagY)
    move_to(m, c{1}, colOf(srcOf(conn, c{1})), tagY(c{1}), 'left');
end

% --- 6) 선을 규칙대로 다시 긋는다 ---------------------------------------
%   포트 높이가 같으면 직선(꺾임 0회).
%   다르면 **두 블록 사이의 빈 곳**에서 한 번 내려가고 한 번 나온다(꺾임 2회).
%   출발·도착 블록의 테두리 위에서 꺾으려 하면 Simulink 가 그 구간을 거부하고
%   스스로 우회해 꺾임이 넷으로 늘어난다 — 2026-09-16 에 재현.
for i = 1:numel(conn)
    c = conn(i);
    a = port_xy(m, c.src, 'Outport', c.sp);
    b = port_xy(m, c.dst, 'Inport',  c.dp);
    if abs(a(2)-b(2)) < 0.5
        add_line(m, [a; b]);
    elseif is_type(m, c.dst, 'Goto') && isKey(lane, c.dst)
        %  태그는 블록 아래에 있다. 태그마다 제 통로로 내려가 옆으로 붙인다.
        %  통로를 공유하면 서로 다른 신호가 한 선으로 겹쳐 보인다
        add_line(m, [a; lane(c.dst) a(2); lane(c.dst) b(2); b]);
    else
        %  통로 x 는 **출발 포트 번호**로만 정한다. 그래야 한 신호의 여러 갈래가
        %  같은 줄기를 공유하고(팬아웃은 그것이 옳다), 다른 신호끼리는 어긋난다.
        xm = round((a(1) + b(1))/2) + 26*(c.sp - 1);
        %  태그로 내려가는 통로들이 출발 포트 오른쪽에 줄지어 있다 (+18 부터
        %  26 씩). 사슬 통로를 그 안에 두면 두 신호가 같은 x 를 나눠 쓴다.
        lo = a(1) + 150;
        if isKey(cnt, c.src), lo = max(lo, a(1) + 24 + 26*cnt(c.src)); end
        if xm < lo, xm = lo; end
        if xm > b(1)-15, xm = max(a(1)+15, b(1)-15); end
        add_line(m, [a; xm a(2); xm b(2); b]);
    end
end

%  직접 연 모델은 **저장하고** 닫는다. 저장하지 않으면 여기서 한 배치가
%  전부 버려진다 (2026-09-16 에 한참 헤맴).
if opened, save_system(m); close_system(m, 0); end
end

% -------------------------------------------------------------------------
function conn = grab(m)
%GRAB  최상위 신호선을 (출발 블록·포트, 도착 블록·포트) 목록으로 읽는다.
conn = struct('src',{},'sp',{},'dst',{},'dp',{});
L = find_system(m, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    sp = get_param(L(i), 'SrcPortHandle');
    dp = get_param(L(i), 'DstPortHandle');
    if sp < 0, continue, end
    for d = dp(:)'
        if d < 0, continue, end
        conn(end+1) = struct( ...
            'src', get_param(get_param(sp,'Parent'), 'Name'), ...
            'sp',  get_param(sp, 'PortNumber'), ...
            'dst', get_param(get_param(d, 'Parent'), 'Name'), ...
            'dp',  get_param(d,  'PortNumber')); %#ok<AGROW>
    end
end

%  팬아웃은 부모선과 가지선이 같은 (출발, 도착) 을 두 번 보고할 수 있다.
%  그대로 두면 같은 자리에 선을 두 번 그어 길이 0 인 토막이 남는다.
if ~isempty(conn)
    key = arrayfun(@(c) sprintf('%s|%d|%s|%d', c.src, c.sp, c.dst, c.dp), ...
                   conn, 'UniformOutput', false);
    [~, ia] = unique(key, 'stable');
    conn = conn(ia);
end
end

% -------------------------------------------------------------------------
function s = srcOf(conn, dst)
%SRCOF  그 태그에 신호를 주는 블록의 이름.
s = '';
for i = 1:numel(conn)
    if strcmp(conn(i).dst, dst), s = conn(i).src; return, end
end
end

% -------------------------------------------------------------------------
function [x, y] = free_slot(used, x, y)
%FREE_SLOT  같은 자리에 태그가 이미 있으면 40 px 씩 아래로 비켜 준다.
%   태그가 겹치면 어느 선이 어느 태그로 가는지 알 수 없다.
while ~isempty(used) && any(abs(used(:,1)-x) < 80 & abs(used(:,2)-y) < 26)
    y = y + 30;
end
end

% -------------------------------------------------------------------------
function tf = is_type(m, name, t)
try, tf = strcmp(get_param([m '/' name], 'BlockType'), t); catch, tf = false; end
end

% -------------------------------------------------------------------------
function move_to(m, name, x, y, edge)
%MOVE_TO  블록의 지정한 테두리가 (x, y) 에 오도록 옮긴다. 크기는 그대로.
b = [m '/' name];
r = get_param(b, 'Position');
w = r(3)-r(1);  h = r(4)-r(2);
if strcmp(edge, 'left')
    set_param(b, 'Position', round([x, y-h/2, x+w, y+h/2]));
else
    set_param(b, 'Position', round([x-w, y-h/2, x, y+h/2]));
end
end
