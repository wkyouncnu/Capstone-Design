function n = flatten_lines(mdl)
%FLATTEN_LINES  포트 높이가 같아진 선을 다시 곧게 긋는다. 꺾임만 줄인다.
%
%   n = flatten_lines('W06_4_stop')      % 최상위와 모든 서브시스템
%
%   왜 생기나 / where the stale detours come from
%       `lay_chain` 은 블록을 놓고 **그 자리에서** 선을 긋는다. 그 다음 차례인
%       `straighten_chain` 이 포트 높이를 맞추려고 앞블록을 통째로 위아래로
%       옮기면, Simulink 는 선의 **끝점만** 새 포트로 당기고 가운데 점은 그대로
%       둔다. 그래서 두 포트가 같은 높이에 서 있는데도 선은 내려갔다 올라오는
%       옛 길을 붙들고 있다 — 2026-10-14 W06_4_stop 에서 측정, Guidance 출력이
%       넷에서 다섯으로 늘어 straighten_chain 이 26 px 를 옮긴 뒤
%
%           Guidance -> OuterLoop : [235 65; 235 115; 389 115; 389 65; 525 65]
%
%       꺾임 3회 2건에 겹침 1건이 여기서 나왔다. `lay_links` 는 이 선을 집어내되
%       갈래(태그로 가는 가지)까지 한꺼번에 풀 길을 못 찾아 그대로 두었다.
%
%   무엇을 하는가 / what it does
%       끝이 하나인 가지마다 **출발 포트와 도착 포트의 높이가 같은지** 본다.
%       같고, 앞으로 가는 선이고, 그 높이의 직선 통로에 다른 블록도 그 이름표도
%       없으면 — 가지를 지우고 두 점짜리 직선으로 다시 긋는다. 꺾임이 줄기만
%       하므로 되돌릴 일이 없다. 하나라도 걸리면 손대지 않는다.
%
%       갈래의 다른 가지는 건드리지 않는다. 같은 출발 포트에서 다시 그으면
%       Simulink 가 줄기를 알아서 함께 쓴다.
%
%   무엇을 건드리지 않는가 / what does not change
%       블록은 한 px 도 움직이지 않는다. 연결도 그대로다. 신호에 붙은 기록
%       표시는 선과 함께 지워지므로 `keep_signals` 로 챙겼다 되돌린다.
%
%   돌려주는 값 n 은 다시 그은 가지의 수다.

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end
keep = keep_signals(mdl);
n = 0;

sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
for s = 1:numel(sys)
    %  Stateflow 차트·MATLAB Function 의 안은 Simulink 선이 아니다
    try
        if ~strcmp(get_param(sys{s},'Type'), 'block_diagram') && ...
           ~strcmp(get_param(sys{s},'SFBlockType'), 'NONE'), continue, end
    catch
    end
    n = n + flatten_one_system(sys{s});
end

keep_signals(mdl, keep);
if opened, save_system(mdl); close_system(mdl, 0); end
end

% ---------------------------------------------------------------------
function n = flatten_one_system(sys)
%  한 서브시스템 안의 가지를 훑는다. 장애물 표는 한 번만 만든다.
n = 0;
blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));
if isempty(blks), return, end

hnd = zeros(numel(blks),1);  box = zeros(numel(blks),4);  nbx = nan(numel(blks),4);
for i = 1:numel(blks)
    hnd(i) = get_param(blks{i}, 'Handle');
    box(i,:) = get_param(blks{i}, 'Position');
    nbx(i,:) = name_box(blks{i});
end

L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    h = L(i);
    if ~ishandle(h), continue, end
    try
        dp = get_param(h, 'DstPortHandle');
        if numel(dp) ~= 1 || dp < 0, continue, end     % 끝이 하나인 가지만
        if ~isempty(get_param(h, 'LineChildren')), continue, end
        q = get_param(h, 'Points');
        if size(q,1) <= 2, continue, end               % 이미 직선이다
        sp = src_port(h);
        if sp < 0, continue, end
        a = get_param(sp, 'Position');
        b = get_param(dp, 'Position');
        if abs(a(2) - b(2)) > 0.5, continue, end       % 높이가 다르면 둘 일이 아니다
        if b(1) < a(1) + 15, continue, end             % 되돌아가는 선은 직선이 못 된다

        own = [get_param(get_param(sp,'Parent'), 'Handle'); ...
               get_param(get_param(dp,'Parent'), 'Handle')];
        kp  = ~ismember(hnd, own);
        if blocked(box(kp,:), nbx(kp,:), a, b), continue, end

        delete_line(h);
        %  점이 아니라 **포트 손잡이**로 긋는다. 좌표로 그으면 몇 px 만 어긋나도
        %  붙지 않고 한쪽이 매달린다 — 2026-10-14 W06_4_stop 에서 x_ref·y_ref 두
        %  가닥이 그렇게 떨어졌다 (check_lines 의 (4) 매달림 2건)
        add_line(sys, sp, dp);
        n = n + 1;
    catch
    end
end
end

% ---------------------------------------------------------------------
function p = src_port(h)
%SRC_PORT  가지에서 줄기로 올라가 출발 포트를 찾는다.
p = get_param(h, 'SrcPortHandle');
for depth = 1:16
    if p > 0, return, end
    try, par = get_param(h, 'LineParent'); catch, p = -1; return, end
    if isempty(par) || par <= 0, p = -1; return, end
    h = par;
    p = get_param(h, 'SrcPortHandle');
end
end

% ---------------------------------------------------------------------
function tf = blocked(box, nbx, a, b)
%BLOCKED  a 에서 b 로 가는 가로 직선이 남의 블록이나 이름표를 지나는가.
%   이름표를 함께 보는 것은 이름이 블록 **밖**에 쓰이기 때문이다 — 사각형만
%   피한 직선은 이름 글자를 그어 버린다 (check_lines 의 (7) 이름표 위 선).
tf = false;
x1 = min(a(1), b(1));  x2 = max(a(1), b(1));  y = a(2);
r = [box; nbx(~any(isnan(nbx),2), :)];
for k = 1:size(r,1)
    if r(k,1) < x2 - 1 && x1 < r(k,3) - 1 && r(k,2) - 1 < y && y < r(k,4) + 1
        tf = true;  return
    end
end
end
