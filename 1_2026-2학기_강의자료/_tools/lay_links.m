function n = lay_links(sys, varargin)
%LAY_LINKS  아직 지저분한 선만 골라 통로 하나로 다시 긋는다. 마지막 손질.
%
%   n = lay_links('SB11_enabled_done')
%   lay_links(sys, 'Step', 10)
%
%   무엇을 고치는가 / what it fixes
%       블록을 다 옮기고 나면 대개는 깨끗해지지만, 배치기가 그어 둔 선 몇 가닥은
%       옛 자리를 기억한 채 남는다. 세 번 꺾이거나 남의 블록을 가로지르는 선이
%       그것이다. 그런 선만 골라 **통로 하나**로 다시 긋는다.
%
%           앞으로 가는 선   내려갔다 한 번에 간다            꺾임 2회
%           높이가 같으면   그냥 직선                        꺾임 0회
%           위·아래 포트    가로로 간 뒤 세로로 붙인다        꺾임 1회
%
%   되돌아가는 선은 건드리지 않는다. 배치로는 세 번 밑으로 내려가지 않으므로
%   tag_feedback 이 태그로 바꾼다.
%
%   통로 고르기 / choosing the lane
%       출발 포트와 도착 포트 사이를 훑어, **어떤 블록도 지나지 않고** 다른 선의
%       세로 토막과 x 를 나눠 쓰지 않는 자리를 찾는다. 찾지 못하면 그 선은 그대로
%       둔다. 어설프게 옮겨 다른 선을 망치는 것보다 낫다.
%
%   NAME/VALUE
%     'Step'  통로를 찾을 때의 간격. 기본 10
%
%   돌려주는 값은 다시 그은 선의 수다.

p = inputParser;
p.addParameter('Step', 10);
p.parse(varargin{:});
o = p.Results;
n = 0;

blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));
if isempty(blks), return, end
box = zeros(numel(blks),4);
nbx = nan(numel(blks),4);          % 이름표. 블록 밖에 쓰이므로 따로 피해야 한다
for i = 1:numel(blks)
    box(i,:) = get_param(blks{i}, 'Position');
    nbx(i,:) = name_box(blks{i});
end

L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
if isempty(L), return, end

% --- 지금 쓰이는 세로 토막을 적어 둔다 ----------------------------------
%  네 번째 칸은 **뿌리 선**의 핸들이다. 한 신호의 갈래끼리는 일부러 줄기를
%  나눠 쓰므로, 겹침을 따질 때 서로 비교하면 안 된다 — check_lines 와 같은 규칙.
root = zeros(numel(L),1);
for i = 1:numel(L)
    h = L(i);
    for depth = 1:16
        try, par = get_param(h, 'LineParent'); catch, break, end
        if isempty(par) || par <= 0, break, end
        h = par;
    end
    root(i) = h;
end

%  빈 값이면 seg(:,4) 가 터진다. 칸 수를 갖춘 빈 배열로 시작한다
seg = zeros(0, 4);                              % [x ylo yhi rootHandle]
for i = 1:numel(L)
    q = get_param(L(i), 'Points');
    for k = 1:size(q,1)-1
        if abs(q(k,1)-q(k+1,1)) < 1e-6 && abs(q(k,2)-q(k+1,2)) > 1e-6
            seg(end+1,:) = [q(k,1) min(q(k,2),q(k+1,2)) max(q(k,2),q(k+1,2)) root(i)]; %#ok<AGROW>
        end
    end
end

% --- 한 신호(뿌리 선)를 통째로 다룬다 ------------------------------------
%  갈래가 있는 선은 가지마다 따로 그어야 한다. 가지 하나만 손대면 나머지 가지가
%  옛 경로를 붙들고 있어, 같은 신호가 두 길로 가는 그림이 된다.
for rh = unique(root)'
    grp = L(root == rh);
    if ~all(arrayfun(@ishandle, grp)), continue, end
    s = get_param(rh, 'SrcPortHandle');
    if s < 0, continue, end
    a = get_param(s, 'Position');

    dst = [];
    bad = false;
    for i = 1:numel(grp)
        q = get_param(grp(i), 'Points');
        if size(q,1) - 2 >= 3, bad = true; end
        for dd = get_param(grp(i), 'DstPortHandle')'
            if dd > 0, dst(end+1) = dd; end %#ok<AGROW>
        end
    end
    dst = unique(dst);
    if isempty(dst), continue, end

    %  장애물은 **가지마다** 따로 센다. 한 신호가 A 와 B 로 갈라질 때 A 로 가는
    %  가지가 B 를 뚫는 것은 결함이다. 도착 블록을 통째로 빼 두면 그것을 못 본다
    %  (2026-09-17 SB11 에서 Pulse 의 enable 가지가 TrigSub 를 뚫고 있었다).
    hnd = zeros(numel(blks),1);
    for j = 1:numel(blks), hnd(j) = get_param(blks{j},'Handle'); end
    sb0 = get_param(rh, 'SrcBlockHandle');

    if ~bad
        other = seg(seg(:,4) ~= rh, :);
        for i = 1:numel(grp)
            q   = get_param(grp(i), 'Points');
            own = sb0;
            for dd = get_param(grp(i),'DstPortHandle')'
                if dd > 0, own(end+1) = get_param(get_param(dd,'Parent'),'Handle'); end %#ok<AGROW>
            end
            kp = ~ismember(hnd, own);
            ob = obstacles(box, nbx, kp);
            for k = 1:size(q,1)-1
                if hits_any(ob, q(k,:), q(k+1,:)), bad = true; break, end
                %  남의 세로 토막과 x 를 나눠 쓰면 인쇄물에서 한 선으로 보인다
                if abs(q(k,1)-q(k+1,1)) < 1e-6 && ...
                   clash(other, q(k,1), q(k,2), q(k+1,2)), bad = true; break
                end
            end
            if bad, break, end
        end
    end
    if ~bad, continue, end

    %  가지마다 깨끗한 경로를 미리 찾아 둔다. 하나라도 못 찾으면 손대지 않는다.
    %  어설프게 옮겨 나머지 가지를 망치는 것보다 그대로 두는 편이 낫다.
    keep = struct('hnd', hnd, 'src', sb0);
    [pts, ok] = routes(box, nbx, keep, seg, rh, a, dst, o.Step);

    %  제어 포트(enable·trigger)는 블록의 **위**에 있다. 먹이는 블록이 아래에
    %  있으면 선은 블록들을 돌아 올라가느라 네 번 꺾인다. 입력이 없는 순수한
    %  源 블록이라면 위로 올려 준다. 그러면 가로 한 번, 세로 한 번으로 끝난다.
    %  From 태그는 신호 사슬이 아니다. "이 신호를 여기서 받는다" 는 표시일 뿐이라
    %  받는 포트 곁이면 어디든 좋다. 길이 막혔으면 태그를 옮겨 길을 낸다.
    if ~ok
        sb = get_param(rh, 'SrcBlockHandle');
        if numel(dst) == 1 && strcmp(get_param(sb,'BlockType'), 'From')
            was = get_param(sb, 'Position');
            b   = get_param(dst, 'Position');
            w   = was(3)-was(1);  h = was(4)-was(2);
            %  포트에서 얼마나 떨어질지(gap)와 위아래(dy)를 함께 훑는다. 한쪽만
            %  훑으면 받는 포트 바로 왼쪽에 다른 블록이 앉아 있을 때 길이 없다.
            for gap = [40 90 140 200 260 330]
                for dy = [90 -90 60 -60 40 -40 30 -30 130 -130 170 -170 210 -210 20 -20]
                    y = b(2) + dy;
                    set_param(sb, 'Position', ...
                              round([b(1)-gap-w, y-h/2, b(1)-gap, y+h/2]));
                    a = get_param(s, 'Position');
                    ib = strcmp(blks, getfullname(sb));
                    box(ib,:) = get_param(sb, 'Position');
                    nbx(ib,:) = name_box(sb);
                    [pts, ok] = routes(box, nbx, keep, seg, rh, a, dst, o.Step);
                    if ok, break, end
                end
                if ok, break, end
            end
            if ~ok
                set_param(sb, 'Position', was);
                ib = strcmp(blks, getfullname(sb));
                box(ib,:) = was;
                nbx(ib,:) = name_box(sb);
                a = get_param(s, 'Position');
            end
        end
    end

    if ~ok
        sb  = get_param(rh, 'SrcBlockHandle');
        sph = get_param(sb, 'PortHandles');
        top = any(arrayfun(@(d) is_ctrl(d), dst));
        if isempty(sph.Inport) && top
            was = get_param(sb, 'Position');
            yt  = inf;
            for d = dst
                q  = get_param(get_param(d,'Parent'), 'Position');
                yt = min(yt, q(2));
            end
            h = was(4) - was(2);
            set_param(sb, 'Position', [was(1), yt-140-h, was(3), yt-140]);
            a = get_param(s, 'Position');
            ib = strcmp(blks, getfullname(sb));
            box(ib,:) = get_param(sb, 'Position');
            nbx(ib,:) = name_box(sb);
            [pts, ok] = routes(box, nbx, keep, seg, rh, a, dst, o.Step);

            %  제어 포트로 내려가는 세로 토막은 포트의 x 에 묶여 있다. 받는 블록들이
            %  세로로 포개져 있으면 아래 블록으로 가는 토막이 위 블록을 뚫는데,
            %  통로를 옮겨 피할 수 없다. 받는 블록을 옆으로 벌리는 수밖에 없다.
            cb = [];
            for k = 1:numel(dst)
                if is_ctrl(dst(k))
                    cb(end+1) = get_param(get_param(dst(k),'Parent'), 'Handle'); %#ok<AGROW>
                end
            end
            cb = unique(cb, 'stable');
            old = arrayfun(@(h) {get_param(h,'Position')}, cb);
            if ~ok && numel(cb) > 1
                for step = [220 320 440]
                    for j = 2:numel(cb)
                        q = old{j};  dx = (j-1)*step;
                        set_param(cb(j), 'Position', q + [dx 0 dx 0]);
                        ic = strcmp(blks, getfullname(cb(j)));
                        box(ic,:) = get_param(cb(j),'Position');
                        nbx(ic,:) = name_box(cb(j));
                    end
                    [pts, ok] = routes(box, nbx, keep, seg, rh, a, dst, o.Step);
                    if ok, break, end
                end
            end
            if ~ok
                set_param(sb, 'Position', was);
                ib = strcmp(blks, getfullname(sb));
                box(ib,:) = was;
                nbx(ib,:) = name_box(sb);
                for j = 1:numel(cb)
                    set_param(cb(j), 'Position', old{j});
                    ic = strcmp(blks, getfullname(cb(j)));
                    box(ic,:) = old{j};
                    nbx(ic,:) = name_box(cb(j));
                end
            end
        end
    end
    if ~ok, continue, end

    try
        delete_line(rh);
        seg(seg(:,4) == rh, :) = [];
        nr = [];
        for k = 1:numel(dst)
            h = draw_line(sys, s, dst(k), pts{k});
            if isempty(nr), nr = h; end   % 첫 선이 뿌리, 나머지는 그 가지가 된다
            for j = 1:size(pts{k},1)-1
                if abs(pts{k}(j,1)-pts{k}(j+1,1)) < 1e-6 && ...
                   abs(pts{k}(j,2)-pts{k}(j+1,2)) > 1e-6
                    seg(end+1,:) = [pts{k}(j,1), min(pts{k}(j,2),pts{k}(j+1,2)), ...
                                    max(pts{k}(j,2),pts{k}(j+1,2)), nr]; %#ok<AGROW>
                end
            end
            n = n + 1;
        end
    catch ME
        warning('lay_links:redraw', '%s: %s', sys, ME.message);
    end
end
end

% -------------------------------------------------------------------------
function [pts, ok] = routes(box, nbx, keep, seg, rh, a, dst, step)
%ROUTES  가지 전부의 경로를 찾는다. 하나라도 못 찾으면 ok 가 거짓이다.
%   어설프게 한 가지만 옮기면 나머지 가지가 옛 경로를 붙들어, 같은 신호가 두 길로
%   가는 그림이 된다. 그래서 전부 아니면 전부 두기다.
pts = cell(1, numel(dst));
ok  = true;
for k = 1:numel(dst)
    b = get_param(dst(k), 'Position');
    if b(1) < a(1), ok = false; return, end      % 되돌아가는 선은 태그가 맡는다
    db     = get_param(get_param(dst(k),'Parent'), 'Handle');
    r      = get_param(db, 'Position');
    side   = b(1) <= r(1) || b(1) >= r(3);
    %  이 가지의 장애물 — 내는 블록과 **이 가지가 가는** 블록만 뺀다
    kp     = ~ismember(keep.hnd, [keep.src; db]);
    pts{k} = pick(obstacles(box, nbx, kp), seg, rh, a, b, side, step);
    if isempty(pts{k}), ok = false; return, end
end
end

% -------------------------------------------------------------------------
function ob = obstacles(box, nbx, kp)
%OBSTACLES  사각형과 **이름표**를 함께 돌려준다.
%   이름은 블록 밖에 쓰인다. 사각형만 피해 고른 통로는 이름 글자 위를 지나가고,
%   도면에서는 이름을 읽을 수 없다 — check_lines 의 (7) 이름표 위 선.
nb = nbx(kp,:);
ob = [box(kp,:); nb(~any(isnan(nb),2), :)];
end

% -------------------------------------------------------------------------
function tf = is_ctrl(d)
%IS_CTRL  enable·trigger 처럼 블록 **위**에 달리는 제어 포트인가.
try
    tf = ismember(get_param(d, 'PortType'), {'enable','trigger','ifaction','reset'});
catch
    tf = false;
end
end

% -------------------------------------------------------------------------
function pts = pick(box, seg, self, a, b, side, step)
%PICK  깨끗한 경로를 찾는다. 못 찾으면 빈 값을 돌려준다.
pts = [];
if ~isempty(seg), seg = seg(~ismember(seg(:,4), self), :); end

if abs(a(2)-b(2)) < 0.5
    if ~hits_any(box, a, b), pts = [a; b]; end
    return
end

if ~side
    %  위·아래 포트 — 가로로 간 뒤 세로로 붙인다. 꺾임 1회
    c = [b(1) a(2)];
    if ~hits_any(box, a, c) && ~hits_any(box, c, b) && ~clash(seg, b(1), a(2), b(2))
        pts = [a; c; b];
    end
    return
end

%  옆면 포트 — 통로 하나로 내려(올라)갔다 들어간다. 꺾임 2회
lo = a(1);  hi = b(1) - 15;
if hi < lo, return, end
for x = lo:step:hi
    if clash(seg, x, a(2), b(2)), continue, end
    if hits_any(box, a, [x a(2)]),        continue, end
    if hits_any(box, [x a(2)], [x b(2)]), continue, end
    if hits_any(box, [x b(2)], b),        continue, end
    if abs(x - a(1)) < 0.5
        pts = [a; x b(2); b];
    else
        pts = [a; x a(2); x b(2); b];
    end
    return
end
end

% -------------------------------------------------------------------------
function tf = clash(seg, x, y1, y2)
%CLASH  x 를 이미 쓰는 세로 토막과 높이가 겹치는가.
ylo = min(y1,y2);  yhi = max(y1,y2);
tf  = ~isempty(seg) && any(abs(seg(:,1)-x) < 1 & seg(:,2) < yhi-1 & ylo < seg(:,3)-1);
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
