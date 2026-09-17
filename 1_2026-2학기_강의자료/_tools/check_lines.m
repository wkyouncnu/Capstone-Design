function n = check_lines(mdl, verbose)
%CHECK_LINES  도면을 읽을 수 없게 만드는 세 가지를 찾아 보고한다.
%
%   n = check_lines('W06_P3_boat_speed')
%   check_lines('W06_P3_boat_speed', true)      % 건건이 나열한다
%
%   네 가지 / the four findings
%     1) 겹친 선      — 같은 직선 위를 나누어 쓰는 두 선. 인쇄하면 한 선이다
%     2) 블록 관통    — 자기와 무관한 블록의 사각형을 가로지르는 선
%     3) 꺾임 3회 이상 — 눈이 선을 놓친다. 2회는 따로 세어 보여 준다
%     4) 매달린 선    — 한쪽 끝이 포트에 붙지 않은 선. 이어져 **보이는데** 끊겨 있다
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
%   합격선은 겹침 0 · 블록관통 0 · 꺾임3회+ 0 · 매달림 0 이다. 꺾임 2회는 최소로 줄인다.
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

if nargin < 2, verbose = false; end

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end

sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
n   = 0;  nc = 0;  nb = 0;  nk = 0;  n2 = 0;  nd = 0;

for s = 1:numel(sys)
    [a, b, c, d, e] = check_one(sys{s}, verbose);
    nc = nc + a;  nb = nb + b;  nk = nk + c;  n2 = n2 + d;  nd = nd + e;
end
n = nc + nb + nk + nd;

if opened, close_system(mdl, 0); end

if verbose || n > 0
    fprintf('  %-26s 겹침 %d · 블록관통 %d · 꺾임3회+ %d · 매달림 %d   (꺾임2회 %d)\n', ...
            mdl, nc, nb, nk, nd, n2);
end
end

% -------------------------------------------------------------------------
function [nc, nb, nk, n2, nd] = check_one(sys, verbose)
lines = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
blks  = find_system(sys, 'SearchDepth',1, 'Type','Block');

%  서브시스템 안을 볼 때 find_system 은 **그 서브시스템 자신**도 돌려준다.
%  자기 좌표는 바깥 캔버스의 것이라 안쪽 선이 전부 "관통"으로 잡힌다.
blks = blks(~strcmp(blks, sys));

box = zeros(numel(blks), 4);
for i = 1:numel(blks), box(i,:) = get_param(blks{i}, 'Position'); end
hnd = cellfun(@(b) get_param(b,'Handle'), blks);

seg = [];                       % [horizontal? coord lo hi srcPort lineHandle]
nb  = 0;  nk = 0;  n2 = 0;  nd = 0;

for i = 1:numel(lines)
    p  = get_param(lines(i), 'Points');

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
