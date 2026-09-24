function n = lay_feedback(sys, varargin)
%LAY_FEEDBACK  되돌아가는 선을 블록들 아래 제 통로로 돌려 보낸다. 꺾임 2회.
%
%   n = lay_feedback('SB8_discrete_done')
%   lay_feedback(sys, 'Gap', 60, 'Lane', 30)
%
%   무엇을 고치는가 / what it fixes
%       되먹임 선은 오른쪽 출력에서 나와 왼쪽 입력으로 돌아가야 한다. 배치기에
%       맡기면 블록 사이를 비집고 다니며 네 번 꺾인다. 눈이 따라갈 수 없다.
%
%       내려갔다 왼쪽으로 가로질러 올라오면 **두 번**이면 끝난다.
%
%           ┌─[SumA]─▶ ... ─▶[UD]─┐        [UD]───▶[SumA]
%           │                     │          ▲         │
%           └─── (네 번 꺾임) ────┘          └─────────┘  두 번
%
%   왜 태그로 바꾸지 않는가 / why not a Goto/From pair
%       W05~W08 처럼 되먹임을 태그로 바꾸면 도면은 깨끗해지지만, 되먹임이 있다는
%       사실 자체가 그림에서 사라진다. SB8·SB9 처럼 "되먹임이 무엇인지" 를
%       가르치는 모델에서는 선이 보여야 한다. 배치만으로 두 번에 끝나므로
%       구조를 바꿀 이유가 없다.
%
%   되돌아가는 선 / a backward line
%       받는 블록의 왼쪽 테두리가 내는 포트보다 **왼쪽에** 있는 선. 그런 선은
%       반드시 왼쪽으로 달려야 하고, 가는 길에 블록들이 놓여 있다.
%
%   NAME/VALUE
%     'Gap'   맨 아래 블록과 첫 통로 사이의 간격. 기본 60
%     'Lane'  통로 사이의 간격. 기본 30
%
%   돌려주는 값은 다시 그은 선의 수다.

p = inputParser;
p.addParameter('Gap',  60);
p.addParameter('Lane', 30);
p.parse(varargin{:});
o = p.Results;
n = 0;

blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));
if isempty(blks), return, end

box = zeros(numel(blks), 4);
for i = 1:numel(blks), box(i,:) = get_param(blks{i}, 'Position'); end
ych = max(box(:,4)) + o.Gap;

% --- 되돌아가는 선을 찾는다 ---------------------------------------------
back = struct('src',{},'sp',{},'dst',{},'dp',{},'h',{},'span',{});
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    s = get_param(L(i), 'SrcPortHandle');
    if s < 0, continue, end
    a = get_param(s, 'Position');
    for dd = get_param(L(i), 'DstPortHandle')'
        if dd < 0, continue, end
        b = get_param(dd, 'Position');
        if b(1) >= a(1), continue, end            % 앞으로 가는 선은 그대로 둔다
        back(end+1) = struct( ...
            'src', get_param(get_param(s,'Parent'), 'Name'), ...
            'sp',  get_param(s,  'PortNumber'), ...
            'dst', get_param(get_param(dd,'Parent'), 'Name'), ...
            'dp',  get_param(dd, 'PortNumber'), ...
            'h',   L(i), 'span', a(1)-b(1)); %#ok<AGROW>
    end
end
if isempty(back), return, end

%  멀리 도는 선을 더 아래 통로에 둔다. 그래야 통로끼리 서로 건너뛰지 않는다.
[~, ord] = sort([back.span]);
back = back(ord);

%  가지 하나만 끊는다. 뿌리 선을 지우면 같은 신호의 다른 가지까지 사라진다
for i = 1:numel(back)
    pd = get_param([sys '/' back(i).dst], 'PortHandles');
    cut_line(sys, pd.Inport(back(i).dp));
end

for i = 1:numel(back)
    a = port_xy(sys, back(i).src, 'Outport', back(i).sp);
    b = port_xy(sys, back(i).dst, 'Inport',  back(i).dp);
    y = ych + o.Lane*(i-1);
    %  출력 포트 바로 아래로 내려가 가로지른 뒤, 입력 포트 바로 아래로 올라간다.
    %  세로 토막이 블록을 뚫으면 내는 쪽만 옆으로 비켜 준다 (꺾임 3회가 되지만
    %  블록을 뚫는 것보다는 낫다).
    x = a(1);
    for t = 1:40
        if ~hits_any(box, [x a(2)], [x y]), break, end
        x = x + 26;
    end
    if abs(x - a(1)) < 0.5
        pts = [a; x y; b(1) y; b];
    else
        pts = [a; x a(2); x y; b(1) y; b];
    end
    %  포트로 먼저 잇는다. 점만 주면 끝점이 포트에 붙지 않고 매달릴 수 있다
    ps = get_param([sys '/' back(i).src], 'PortHandles');
    pd = get_param([sys '/' back(i).dst], 'PortHandles');
    draw_line(sys, ps.Outport(back(i).sp), pd.Inport(back(i).dp), pts);
    n = n + 1;
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
