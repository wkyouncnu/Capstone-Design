function n = nudge_labels(mdl, verbose)
%NUDGE_LABELS  이름표가 가려지거나 그어지면 블록을 옆으로 비킨다.
%   check_lines 의 (6) "이름표가 가려짐" 과 (7) "이름표 위 선" 만 다룬다.
%
%   n = nudge_labels('W04_4_inner_loop_offline')
%   nudge_labels(mdl, true)      % 무엇을 옮겼는지 말한다
%
%   왜 이 도구가 필요한가 / why this exists
%       `check_lines` 의 일곱째 항목 — 남의 선이 블록 이름 글자 위를 지나는 것 —
%       은 **통로를 옮겨** 푸는 것이 원칙이다 (line-routing.md §9). 그런데 통로가
%       출발 포트의 x 에 묶여 있으면 옮길 수가 없다. 아래로 내려가는 갈래는
%       전부 그 x 를 쓰기 때문이다.
%
%       그때 남는 수는 하나다 — **이름표가 걸리는 블록을 옆으로 옮긴다.**
%       2026-09-24 W04_4_inner_loop_offline 에서 `arrangeSystem` 이 u_ref 를
%       MotionModel 출력 통로 바로 아래에 놓아, log_u 로 내려가는 선이 u_ref 의
%       이름을 그었다. 통로는 못 옮기고 블록은 옮길 수 있었다.
%
%   어떻게 / how
%       걸린 블록을 찾아 좌우·상하로 차례로 밀어 보고, `settle_links` 로 선을
%       다시 그은 뒤 지적 수가 **줄어든 자리만** 남긴다. 나빠지면 되돌린다.
%       그래서 몇 번을 돌려도 손해가 없다 — `tidy_model` 과 같은 약속이다.
%
%   되돌아오는 값 n 은 마지막 `check_lines` 의 지적 수다.

if nargin < 2, verbose = false; end

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end

STEPS = {[0 60], [0 -60], [-80 0], [80 0], [-120 0], [120 0], ...
         [0 120], [0 -120], [-220 0], [220 0]};

for pass = 1:3
    [n, v] = check_lines(mdl);
    if v(6) == 0 && v(7) == 0, break, end

    hits = label_hits(mdl);
    if isempty(hits), break, end
    moved = false;

    for h = 1:numel(hits)
        blk  = hits{h};
        p0   = get_param(blk, 'Position');
        best = n;
        for s = 1:numel(STEPS)
            d = STEPS{s};
            set_param(blk, 'Position', p0 + [d d]);
            settle_links(mdl);
            nn = check_lines(mdl);
            if nn < best
                best = nn;  moved = true;
                if verbose
                    fprintf('  [nudge] %s 를 (%+d, %+d) 옮겨 지적 %d -> %d\n', ...
                            blk, d(1), d(2), n, nn);
                end
                break
            end
            set_param(blk, 'Position', p0);          % 나빠졌다. 되돌린다
        end
        if best < n, n = best; end
        if n == 0, break, end
    end

    settle_links(mdl);
    if ~moved, break, end
end

n = check_lines(mdl);
save_system(mdl);
if opened, close_system(mdl, 0); end
end

% ---------------------------------------------------------------------
function out = label_hits(mdl)
%LABEL_HITS  이름표가 남의 선에 그어진 블록의 전체 경로들.
out = {};
sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
for s = 1:numel(sys)
    b = find_system(sys{s}, 'SearchDepth',1, 'Type','Block');
    b = b(~strcmp(b, sys{s}));
    if isempty(b), continue, end
    T = nan(numel(b),4);  H = zeros(numel(b),1);  R = zeros(numel(b),4);
    for i = 1:numel(b)
        T(i,:) = name_box(b{i});
        R(i,:) = get_param(b{i}, 'Position');
        H(i)   = get_param(b{i}, 'Handle');
    end

    %  (6) 이름표가 다른 블록에 가려진 경우 — **가린 쪽**을 비킨다
    for i = 1:numel(b)
        if isnan(T(i,1)), continue, end
        for j = 1:numel(b)
            if j == i, continue, end
            w = min(max(0, min(T(i,3),R(j,3)) - max(T(i,1),R(j,1))), ...
                    max(0, min(T(i,4),R(j,4)) - max(T(i,2),R(j,2))));
            if w > 1, out{end+1} = b{j}; end   %#ok<AGROW>
        end
    end

    L = find_system(sys{s}, 'FindAll','on', 'SearchDepth',1, 'Type','line');
    for q = 1:numel(L)
        p   = get_param(L(q), 'Points');
        own = line_blocks(L(q));
        for i = 1:numel(b)
            if isnan(T(i,1)) || any(own == H(i)), continue, end
            for k = 1:size(p,1)-1
                if hits_box(p(k,:), p(k+1,:), T(i,:) + [-1 -1 1 1])
                    out{end+1} = b{i};   %#ok<AGROW>
                    break
                end
            end
        end
    end
end
out = unique(out, 'stable');
end

% ---------------------------------------------------------------------
function h = line_blocks(ln)
h = [];
try, h = [h; get_param(ln,'SrcBlockHandle')]; catch, end
try, h = [h; get_param(ln,'DstBlockHandle')]; catch, end
try
    par = get_param(ln,'LineParent');
    if par > 0, h = [h; get_param(par,'SrcBlockHandle')]; end
catch
end
try
    for k = reshape(get_param(ln,'LineChildren'), 1, [])
        try, h = [h; get_param(k,'DstBlockHandle')]; catch, end %#ok<AGROW>
    end
catch
end
h = h(h > 0);
end

% ---------------------------------------------------------------------
function tf = hits_box(a, b, r)
%  check_lines 의 seg_hits_box 와 같은 판정 (slab method)
M  = 2;
lo = [r(1)+M, r(2)+M];  hi = [r(3)-M, r(4)-M];
if any(hi <= lo), tf = false; return, end
d = b - a;
if all(abs(d) < 1e-6), tf = false; return, end
t0 = 0;  t1 = 1;
for k = 1:2
    if abs(d(k)) < 1e-9
        if a(k) <= lo(k) || a(k) >= hi(k), tf = false; return, end
    else
        ta = (lo(k)-a(k))/d(k);  tb = (hi(k)-a(k))/d(k);
        if ta > tb, t = ta; ta = tb; tb = t; end
        t0 = max(t0, ta);  t1 = min(t1, tb);
        if t0 >= t1, tf = false; return, end
    end
end
tf = (t1 - t0) > 1e-6;
end
