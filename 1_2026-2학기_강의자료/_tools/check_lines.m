function [n, v] = check_lines(mdl, verbose)
%CHECK_LINES  도면을 읽을 수 없게 만드는 일곱 가지를 찾아 보고한다.
%
%   n = check_lines('W04_P3_boat_speed')
%   check_lines('W04_P3_boat_speed', true)      % 건건이 나열한다
%   [n, v] = check_lines(m)
%       v = [겹침 블록관통 꺾임3회+ 매달림 사선 블록겹침 이름표위선]
%
%   일곱 가지 / the seven findings
%     1) 겹친 선      — 같은 직선 위를 나누어 쓰는 두 선. 인쇄하면 한 선이다
%     2) 블록 관통    — 자기와 무관한 블록의 사각형을 가로지르는 선
%     3) 꺾임 3회 이상 — 눈이 선을 놓친다. 2회는 따로 세어 보여 준다
%     4) 매달린 선    — 한쪽 끝이 포트에 붙지 않은 선. 이어져 **보이는데** 끊겨 있다
%     5) 사선         — 가로도 세로도 아닌 구간. 포트 높이가 몇 px 어긋난 흔적이다
%     6) 블록겹침     — 블록 사각형끼리, 블록 이름표(블록 아래 글자 줄)가 다른 블록에,
%                      주석(Note)이 블록이나 이름표에 겹친 것. 한 서브시스템 안에서만 본다
%     7) 이름표 위 선 — 자기와 무관한 선이 블록 이름표 위를 지나 이름을 그어 버린 것
%
%   왜 이 셋인가 / why these three
%       읽는 사람은 선을 **눈으로 따라간다.** 겹친 선은 따라갈 수 없고, 블록을
%       관통하는 선은 그 블록에 연결된 것처럼 보이며, 두 번 꺾인 선은 다른 선과
%       구별되지 않는다. 셋 다 도면이 **실제로 없는 연결을 주장하게** 만든다.
%
%       A reader follows a line with their eye. Overlapping lines cannot be
%       followed, a line crossing a block looks connected to it, and a line
%       that turns twice is indistinguishable from its neighbours. All three
%       make the diagram claim a connection that does not exist.
%
%   합격선은 일곱 가지 **모두 0** 이다. 꺾임 2회만 따로 세어 보여 주고 최소로 줄인다.
%
%   블록겹침을 왜 세는가 / why block clashes are counted
%       선 검사는 블록이 **어디에 있는지**를 묻지 않는다. 종착 블록을 한 열에 쌓거나
%       태그를 포트 아래에 매달면 이웃 블록과 포개지고, 포트 간격이 글자 높이보다
%       좁으면 이름표가 아래 블록에 가려진다 (2026-09-19 PoseSubscriber 의 orgN 이
%       orgE 에 가려짐). 선은 전부 깨끗한데 블록 이름을 읽을 수 없다.
%       이름표 크기는 어림이다 — 글자 폭 (ASCII 6.5 px, 한글 12 px) 과 블록 폭 중 큰 쪽
%       x 줄 수 x 14 px. ShowName 이 off 인 블록은 이름표가 없다.
%       같은 계산이 _tools/name_box.m 에 있다. 배치 도구는 그것으로 이름표를 피한다.
%
%   이름표 위 선을 왜 세는가 / why lines over name labels are counted
%       블록 이름은 블록 **밖**에 쓰인다. 그래서 사각형만 피해 고른 통로가 이름
%       글자 위를 그대로 지나가고, 인쇄하면 이름이 선에 지워져 읽히지 않는다.
%       블록은 멀쩡한데 그 블록이 무엇인지 알 수 없는 도면이 된다.
%       2026-09-21 에 참고값에서 **합격선**으로 올렸다 — 전 모델 11건을 배치로 풀고서다.
%
%
%   매달린 선을 왜 세는가 / why dangling lines are counted
%       `add_line` 에 점만 주면 Simulink 가 끝점의 좌표로 포트를 찾는데, 몇 픽셀만
%       어긋나면 붙지 않고 한쪽이 매달린다. 그런 선은 겹치지도 블록을 뚫지도
%       않으므로 나머지 세 검사를 모두 통과한다. 도면은 흠잡을 데 없는데 모델이
%       컴파일되지 않는다 (2026-09-17 W02_2 의 TurtlePlant). 배선 규칙을 지켰는지
%       재는 도구가 **신호가 이어져 있는지**부터 못 보면 소용이 없다.
%
%   한 신호의 분기(팬아웃)는 겹침으로 세지 않는다. 한 줄기를 일부러 공유한다.
%
%   고치는 법 / how to fix
%     겹침       — lane_line 의 통로 x 를 신호마다 다르게 준다
%     블록 관통  — 받는 블록을 통로의 **오른쪽**에 놓는다 (drop_tag 참조)
%     꺾임      — 통로 x 를 **출발 포트의 x** 또는 **도착 포트의 x** 와 같게 한다.
%                  그러면 길이 0 인 구간이 지워지고 꺾임이 한 번만 남는다
%     블록겹침  — 배치로 푼다. 쌓는 도구가 옆 블록과 이름표 자리를 피하게 하고,
%                  포트 간격이 좁아 이름표가 가려지면 받는 블록의 키를 키운다
%     이름표위선 — 통로 x 를 옮기거나(lay_sinks·lay_links·lay_chain 은 name_box 를
%                  사각형과 함께 피한다), 이름표가 걸리는 블록·태그를 옆으로 옮긴다.
%                  꺾임을 늘려 돌아가지 말 것 — 선 하나 살리자고 도면을 버린다

if nargin < 2, verbose = false; end

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end


sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
n   = 0;  nc = 0;  nb = 0;  nk = 0;  n2 = 0;  nd = 0;  ns = 0;  no = 0;  nl = 0;

for s = 1:numel(sys)
    [a, b, c, d, e, f] = check_one(sys{s}, verbose);
    nc = nc + a;  nb = nb + b;  nk = nk + c;  n2 = n2 + d;  nd = nd + e;  ns = ns + f;
    [a, b] = check_blocks(sys{s}, verbose);
    no = no + a;  nl = nl + b;
end
n = nc + nb + nk + nd + ns + no + nl;
v = [nc nb nk nd ns no nl];

if opened, close_system(mdl, 0); end

if verbose || n > 0
    fprintf(['  %-26s 겹침 %d · 블록관통 %d · 꺾임3회+ %d · 매달림 %d · 사선 %d · ' ...
             '블록겹침 %d · 이름표위선 %d   (꺾임2회 %d)\n'], ...
            mdl, nc, nb, nk, nd, ns, no, nl, n2);
end
end

% -------------------------------------------------------------------------
function [nc, nb, nk, n2, nd, ns] = check_one(sys, verbose)
lines = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
blks  = find_system(sys, 'SearchDepth',1, 'Type','Block');

%  서브시스템 안을 볼 때 find_system 은 **그 서브시스템 자신**도 돌려준다.
%  자기 좌표는 바깥 캔버스의 것이라 안쪽 선이 전부 "관통"으로 잡힌다.
blks = blks(~strcmp(blks, sys));

box = zeros(numel(blks), 4);
for i = 1:numel(blks), box(i,:) = get_param(blks{i}, 'Position'); end
hnd = cellfun(@(b) get_param(b,'Handle'), blks);

seg = [];                       % [horizontal? coord lo hi srcPort lineHandle]
nb  = 0;  nk = 0;  n2 = 0;  nd = 0;  ns = 0;

for i = 1:numel(lines)
    p  = get_param(lines(i), 'Points');

    % --- (5) 사선 ----------------------------------------------------
    %  가로도 세로도 아닌 구간. 포트 높이가 몇 px 어긋나면 생긴다
    %  (2026-09-19 W04_P2 Dcompare — Scope 포트 간격을 계산으로 맞춰 세 선이 전부 사선)
    for k = 1:size(p,1)-1
        dd = abs(p(k+1,:) - p(k,:));
        if dd(1) > 0.5 && dd(2) > 0.5
            ns = ns + 1;
            if verbose
                fprintf('    [사선] %-38s %s  (%g, %g px)\n', ...
                        strrep(sys,newline,' '), line_name(lines(i)), dd(1), dd(2));
            end
            break
        end
    end

    % --- (4) 매달린 선 ------------------------------------------------
    %  가지가 달린 부모 선은 도착 포트가 없는 것이 정상이다. 가지가 없는데도
    %  한쪽이 비어 있으면 그 선은 아무것도 잇고 있지 않다.
    kids = [];
    try, kids = get_param(lines(i), 'LineChildren'); catch, end
    noSrc = get_param(lines(i), 'SrcPortHandle') <= 0;
    dh    = get_param(lines(i), 'DstPortHandle');
    noDst = isempty(dh) || all(dh <= 0);
    if noSrc || (noDst && isempty(kids))
        nd = nd + 1;
        if verbose
            fprintf('    [매달림] %-38s %s\n', ...
                    strrep(sys,newline,' '), line_name(lines(i)));
        end
    end

    %  한 신호의 갈래(팬아웃)는 겹침이 아니다. 가지선은 SrcPortHandle 이 비어
    %  있을 수 있으므로, 부모를 따라 올라가 **뿌리 선의 핸들**을 신원으로 삼는다.
    %  같은 뿌리에서 나온 구간끼리는 비교하지 않는다.
    sp  = lines(i);
    for depth = 1:16
        try, par = get_param(sp, 'LineParent'); catch, break, end
        if isempty(par) || par <= 0, break, end
        sp = par;
    end

    % --- (3) 꺾임 수 -------------------------------------------------
    %  1회가 목표다. 2회는 배치상 불가피한 경우가 있으므로 따로 세어 보여 주고,
    %  3회 이상은 배치가 잘못된 것이므로 지적으로 센다.
    turns = max(0, size(p,1) - 2);
    if turns == 2
        n2 = n2 + 1;
        if verbose
            fprintf('    (꺾임 2회) %-38s %s\n', ...
                    strrep(sys,newline,' '), line_name(lines(i)));
        end
    elseif turns >= 3
        nk = nk + 1;
        if verbose
            fprintf('    [꺾임 %d회] %-38s %s\n', turns, ...
                    strrep(sys,newline,' '), line_name(lines(i)));
        end
    end

    % --- (2) 블록 관통 ----------------------------------------------
    skip = own_blocks(lines(i));
    for k = 1:size(p,1)-1
        a = p(k,:);  b = p(k+1,:);
        for j = 1:numel(blks)
            if any(hnd(j) == skip), continue, end
            if seg_hits_box(a, b, box(j,:))
                nb = nb + 1;
                if verbose
                    fprintf('    [블록관통] %-38s %s  ->  %s 를 가로지름\n', ...
                            strrep(sys,newline,' '), line_name(lines(i)), ...
                            get_param(blks{j},'Name'));
                end
            end
        end

        % --- (1) 겹침용 구간 수집 -----------------------------------
        if abs(a(1)-b(1)) < 1e-6 && abs(a(2)-b(2)) > 1e-6
            seg(end+1,:) = [0 a(1) min(a(2),b(2)) max(a(2),b(2)) sp lines(i)]; %#ok<AGROW>
        elseif abs(a(2)-b(2)) < 1e-6 && abs(a(1)-b(1)) > 1e-6
            seg(end+1,:) = [1 a(2) min(a(1),b(1)) max(a(1),b(1)) sp lines(i)]; %#ok<AGROW>
        end
    end
end

nc = 0;
for a = 1:size(seg,1)
    for b = a+1:size(seg,1)
        if seg(a,1) ~= seg(b,1),          continue, end
        if abs(seg(a,2)-seg(b,2)) > 1e-6, continue, end
        if seg(a,5) == seg(b,5),          continue, end   % 한 신호의 분기
        ov = min(seg(a,4),seg(b,4)) - max(seg(a,3),seg(b,3));
        if ov > 1
            nc = nc + 1;
            if verbose
                if seg(a,1), what = 'y'; else, what = 'x'; end
                fprintf('    [겹침] %-38s %s = %g, %g px   %s  vs  %s\n', ...
                        strrep(sys,newline,' '), what, seg(a,2), ov, ...
                        line_name(seg(a,6)), line_name(seg(b,6)));
            end
        end
    end
end
end

% -------------------------------------------------------------------------
function h = own_blocks(ln)
%OWN_BLOCKS  이 선이 붙어 있는 블록들. 자기 블록을 지나는 것은 관통이 아니다.
%
%   재귀하지 않는다. LineParent 와 LineChildren 은 서로를 가리키므로
%   따라가면 무한 루프에 빠진다 (2026-09-16 에 MATLAB 이 멈춤).
%   한 단계만 본다 — 분기선과 그 부모가 같은 출발 블록을 공유하면 충분하다.
h = [];
try, h = [h; get_param(ln,'SrcBlockHandle')]; catch, end
try, h = [h; get_param(ln,'DstBlockHandle')]; catch, end
try
    par = get_param(ln,'LineParent');
    if par > 0
        try, h = [h; get_param(par,'SrcBlockHandle')]; catch, end
    end
catch
end
try
    kids = get_param(ln,'LineChildren');
    for k = kids(:)'
        try, h = [h; get_param(k,'DstBlockHandle')]; catch, end %#ok<AGROW>
    end
catch
end
h = h(h > 0);
end

% -------------------------------------------------------------------------
function tf = seg_hits_box(a, b, r)
%SEG_HITS_BOX  축에 나란한 구간이 사각형 안쪽을 실제로 지나는가.
%   테두리를 스치는 것은 세지 않는다 (포트가 테두리에 있으므로).
%  구간 대 사각형의 정식 교차 판정(slab method). 가로·세로·사선을 한 식으로 다룬다.
%  방향별로 나누어 쓰면 길이 0 인 구간이나 사선이 엉뚱한 가지로 떨어져
%  모든 블록을 관통한 것으로 잡힌다 (2026-09-16 에 34건 오검출).
M  = 2;                                   % 테두리 여유 [px]. 포트는 테두리에 있다
lo = [r(1)+M, r(2)+M];
hi = [r(3)-M, r(4)-M];
if any(hi <= lo), tf = false; return, end

d = b - a;
if all(abs(d) < 1e-6), tf = false; return, end      % 길이 0

t0 = 0;  t1 = 1;
for k = 1:2
    if abs(d(k)) < 1e-9                              % 그 축으로는 움직이지 않는다
        if a(k) <= lo(k) || a(k) >= hi(k), tf = false; return, end
    else
        ta = (lo(k) - a(k)) / d(k);
        tb = (hi(k) - a(k)) / d(k);
        if ta > tb, tmp = ta; ta = tb; tb = tmp; end
        t0 = max(t0, ta);
        t1 = min(t1, tb);
        if t0 >= t1, tf = false; return, end
    end
end
tf = (t1 - t0) > 1e-6;
end

% -------------------------------------------------------------------------
function s = line_name(h)
try, a = get_param(get_param(h,'SrcBlockHandle'), 'Name'); catch, a = '?'; end
try
    d = get_param(h, 'DstBlockHandle');
    if ~isempty(d) && d(1) > 0, b = get_param(d(1), 'Name'); else, b = '(분기)'; end
catch
    b = '?';
end
s = strrep(sprintf('%s -> %s', a, b), newline, ' ');
end

% -------------------------------------------------------------------------
function [no, nl] = check_blocks(sys, verbose)
%CHECK_BLOCKS  (6) 블록겹침. 블록끼리 · 이름표 대 블록 · 주석 대 블록/이름표.
%   nl 은 (7) 이름표 위 선 — 자기와 무관한 선이 이름표 위를 지나는 수. 합격선 0.
no = 0;  nl = 0;
%  Stateflow 차트·MATLAB Function 의 안에는 보이지 않는 Simulink 블록이 있다
try
    if ~strcmp(get_param(sys,'Type'),'block_diagram') && ...
       ~strcmp(get_param(sys,'SFBlockType'),'NONE'), return, end
catch
end
b = find_system(sys, 'SearchDepth',1, 'Type','Block');
b = b(~strcmp(b, sys));                 % 자기 서브시스템 경계는 뺀다
k = numel(b);
R = zeros(k,4);  T = nan(k,4);  H = zeros(k,1);
for i = 1:k
    R(i,:) = get_param(b{i}, 'Position');
    H(i)   = get_param(b{i}, 'Handle');
    T(i,:) = name_box(b{i}, R(i,:));
end
nm = @(x) strrep(get_param(x,'Name'), newline, ' ');
say = @(what, x, y) fprintf('    [블록겹침] %-38s %s : %s  /  %s\n', ...
                            strrep(sys,newline,' '), what, x, y);
for i = 1:k
    for j = i+1:k
        if ov(R(i,:), R(j,:)) > 1
            no = no + 1;
            if verbose, say('블록끼리', nm(b{i}), nm(b{j})); end
        end
    end
    if isnan(T(i,1)), continue, end
    for j = 1:k
        if j == i, continue, end
        if ov(T(i,:), R(j,:)) > 1
            no = no + 1;
            if verbose, say('이름표가 가려짐', nm(b{i}), nm(b{j})); end
        end
    end
end
%  주석 (Note). 위치는 [왼 위 오른 아래]
a = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','annotation');
for q = 1:numel(a)
    try, r = get_param(a(q), 'Position'); catch, continue, end
    if numel(r) < 4, continue, end
    for i = 1:k
        if ov(r, R(i,:)) > 1 || (~isnan(T(i,1)) && ov(r, T(i,:)) > 1)
            no = no + 1;
            if verbose, say('주석', '(Note)', nm(b{i})); end
        end
    end
end
%  (7) 이름표 위를 지나는 남의 선
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for q = 1:numel(L)
    p = get_param(L(q), 'Points');
    own = own_blocks(L(q));
    for i = 1:k
        if isnan(T(i,1)) || any(own == H(i)), continue, end
        for s = 1:size(p,1)-1
            if seg_hits_box(p(s,:), p(s+1,:), T(i,:) + [-1 -1 1 1])
                nl = nl + 1;
                if verbose
                    fprintf('    (이름표 위 선) %-34s %s  ->  %s 의 이름\n', ...
                            strrep(sys,newline,' '), line_name(L(q)), nm(b{i}));
                end
                break
            end
        end
    end
end
end

function t = name_box(blk, r)
%NAME_BOX  블록 이름이 차지하는 자리 (어림). 이름을 숨긴 블록은 NaN.
%   재는 도구는 스스로 서야 하므로 여기 한 벌을 둔다. 배치 도구가 쓰는
%   _tools/name_box.m 과 **같은 계산**이다 — 고칠 때는 둘을 함께 고칠 것.
t = nan(1,4);
if strcmp(get_param(blk,'ShowName'), 'off'), return, end
parts = strsplit(get_param(blk,'Name'), newline);
w = 0;
for k = 1:numel(parts)
    c = double(parts{k});
    w = max(w, sum(c < 128)*6.5 + sum(c >= 128)*12);
end
h   = 14*numel(parts);
alt = strcmp(get_param(blk,'NamePlacement'), 'alternate');
if any(strcmp(get_param(blk,'Orientation'), {'right','left'}))
    ww = max(w, r(3)-r(1));  cx = (r(1)+r(3))/2;
    if alt, y = [r(2)-2-h, r(2)-2]; else, y = [r(4)+2, r(4)+2+h]; end
    t = [cx-ww/2 y(1) cx+ww/2 y(2)];
else
    cy = (r(2)+r(4))/2;
    if alt, x = [r(1)-2-w, r(1)-2]; else, x = [r(3)+2, r(3)+2+w]; end
    t = [x(1) cy-h/2 x(2) cy+h/2];
end
end

function a = ov(p, q)
%OV  두 사각형이 겹친 폭과 높이 중 작은 쪽 [px]. 테두리가 닿기만 하면 0.
a = min(max(0, min(p(3),q(3)) - max(p(1),q(1))), ...
        max(0, min(p(4),q(4)) - max(p(2),q(2))));
end
