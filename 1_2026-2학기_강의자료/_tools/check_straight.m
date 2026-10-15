function [n, h, rows] = check_straight(mdl, verbose)
%CHECK_STRAIGHT  선이 얼마나 곧은지 센다 — 꺾임 0·1·2·3회 이상의 분포.
%                Count how straight the wires are: a histogram of bends per branch.
%
%   n = check_straight('W06_5_dock')      % 꺾임 2회 이상인 가지의 수
%   check_straight(mdl, true)             % 어느 선이 몇 번 꺾이는지 나열
%   [n, h, rows] = check_straight(mdl)    % h = [0회 1회 2회 3회+], rows = 자세한 표
%
%   무엇이 목표인가 / what the target is
%
%       교수 지시 2026-10-15 — "모든 선들은 가능하면 구부러지지 않고 직선으로."
%       그래서 합격선은 "꺾임 3회 이상 0" (그것은 `check_lines` 가 본다) 이 아니고
%       **직선율을 올리고 꺾임 2회 이상을 0 으로 내리는 것**이다. 0 회가 가장 좋고,
%       통로를 갈아타야 하는 되먹임선은 1 회가 어쩔 수 없다. 2 회는 배치를 고쳐
%       풀 수 있는 경우가 대부분이다.
%
%       꺾임 수는 `check_lines` 와 같은 셈법을 쓴다 — 점의 수에서 둘을 뺀 값이다.
%       두 점짜리 선이 직선이다.
%
%   무엇이 직선을 깨뜨리나 / what bends a wire
%
%     1) 포트 높이가 어긋남 — 블록 가운데를 맞추고 포트를 맞추지 않은 경우.
%        `align_to(sys, 블록, 'Inport', port_xy(sys, 앞블록, 'Outport', k))` 로 푼다
%     2) 선을 긋고 **나서** 블록을 옮김 — Simulink 는 끝점만 당기고 가운데 점을
%        두므로 옛 길이 남는다. `flatten_lines(mdl)` 이 집어낸다
%     3) 몇 px 짜리 계단 — 사선과 원인이 같다. `square_lines(mdl)` 이 편다
%     4) 되먹임선이 통로를 갈아탐 — 1 회가 정상이다. 합산점 **아래**에서 올려
%        붙이면 그 1 회로 끝난다 (`check_sums` 의 (5) 와 짝이다)
%
%   돌려주는 값 / what comes back
%
%       n       꺾임 2회 이상인 가지의 수. 0 이 목표다
%       h       [0회 1회 2회 3회+] 가지 수
%       rows    2회 이상 꺾인 가지의 목록 (시스템 · 선 이름 · 꺾임 수)
%
%   직선율은 h(1) / sum(h) 다. 모델 전체를 돌 때는 이 값을 같이 적어 둔다.

if nargin < 2, verbose = false; end
if ~bdIsLoaded(bdroot_name(mdl)), load_system(mdl); end

h    = zeros(1,4);
rows = {};

sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
for s = 1:numel(sys)
    if inside_library(sys{s}, mdl), continue, end
    [hh, rr] = count_one(sys{s}, mdl);
    h    = h + hh;
    rows = [rows, rr];                                           %#ok<AGROW>
end

n = h(3) + h(4);

if verbose
    for i = 1:numel(rows), fprintf('    %s\n', rows{i}); end
    tot = max(1, sum(h));
    fprintf('  %-26s 직선 %d · 1회 %d · 2회 %d · 3회+ %d   (직선율 %.0f%%)\n', ...
            mdl, h(1), h(2), h(3), h(4), 100*h(1)/tot);
end
end

% =====================================================================
function [h, rows] = count_one(sys, mdl)
h    = zeros(1,4);
rows = {};

lines = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(lines)
    p = get_param(lines(i), 'Points');

    %  길이 0 인 토막은 꺾임이 아니다. 블록을 옮긴 뒤 남은 흔적이다
    keep = [true; any(abs(diff(p,1,1)) > 0.5, 2)];
    p    = p(keep,:);

    turns = max(0, size(p,1) - 2);
    k     = min(turns + 1, 4);
    h(k)  = h(k) + 1;

    if turns >= 2
        rows{end+1} = sprintf('[꺾임 %d회] %-30s %s', turns, ...
                              strrep(strrep(sys, [mdl '/'], ''), newline, ' '), ...
                              line_name(lines(i)));                %#ok<AGROW>
    end
end
end

% =====================================================================
function s = line_name(lh)
%LINE_NAME  선을 사람이 알아볼 이름으로 — 신호 이름이 없으면 출발·도착 블록으로.
s = '';
try, s = get_param(lh, 'Name'); catch, end
if ~isempty(s), return, end
try
    sp = get_param(lh, 'SrcPortHandle');
    dp = get_param(lh, 'DstPortHandle');
    a = '?';  b = '?';
    if sp > 0, a = get_param(get_param(sp,'Parent'), 'Name'); end
    if ~isempty(dp) && dp(1) > 0, b = get_param(get_param(dp(1),'Parent'), 'Name'); end
    s = sprintf('%s -> %s', strrep(a,newline,' '), strrep(b,newline,' '));
catch
    s = '(이름 없음)';
end
end

% =====================================================================
function tf = inside_library(blk, mdl)
tf = false;
if strcmp(blk, mdl), return, end
par = blk;
while ~isempty(par) && ~strcmp(par, mdl)
    try
        if ~isempty(get_param(par, 'ReferenceBlock')), tf = true; return, end
        if strcmp(get_param(par, 'Mask'), 'on'),       tf = true; return, end
    catch
        return
    end
    par = get_param(par, 'Parent');
end
end

% =====================================================================
function r = bdroot_name(mdl)
k = strfind(mdl, '/');
if isempty(k), r = mdl; else, r = mdl(1:k(1)-1); end
end
