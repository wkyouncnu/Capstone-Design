function [n, v, rows] = check_sums(mdl, verbose)
%CHECK_SUMS  합산점이 표준 모양인지 전수로 본다 — 모양·부호·크기·들어오는 방향.
%            Audit every summing junction: shape, signs, size, where its wires arrive.
%
%   n = check_sums('W06_5_dock')          지적 개수만
%   check_sums(mdl, true)                 어느 합산점의 무엇이 틀렸는지 나열
%   [n, v, rows] = check_sums(mdl)        v = 항목별 개수, rows = 자세한 표
%
%   v = [모양 부호 크기 지령옆 되먹임밑]
%
%     1) 모양      IconShape 가 'round' 가 아니다 — 네모난 Sum 은 도면에서 슬래브다
%     2) 부호      부호 목록이 막대('|') 하나로 시작하지 않는다
%     3) 크기      20 x 20 이 아니다 (MSS 치수)
%     4) 지령옆    첫 입력선이 **수평으로** 닿지 않는다 — 지령은 왼쪽에서 들어온다
%     5) 되먹임밑  마지막 입력선이 **밑에서 수직으로** 올라오지 않는다
%
%   합격선은 다섯 가지 **모두 0** 이다.
%
%   왜 이 다섯 가지인가 / why these five
%
%       교수 지시 2026-10-14 — "Simulink sum 블록은 항상 |+- 이런 부호 목록만
%       사용." 막대는 포트가 아니라 원의 **위 자리를 비우는 띄우개**다. 비워 두면
%       첫 입력이 왼쪽 가장자리에 남고 둘째 입력만 아래로 내려간다.
%
%           지령 ------->(+)-----> 제어기 ...
%                         ^
%                         | (-)
%                      되먹임
%
%       모양과 부호만 맞아도 **그림이 저절로 이렇게 되지는 않는다.** 포트가 왼쪽에
%       있어도 지령선이 위에서 내려와 ㄱ 자로 꺾여 들어올 수 있고, 되먹임선이
%       옆에서 와서 아래 포트로 비스듬히 붙을 수도 있다. 그래서 (4)·(5) 로 선이
%       닿는 **방향**까지 본다. 다섯 가지가 전부 0 이면 지령선과 출력선이 한 줄로
%       수평이 되어 합산점 자리에서 꺾임이 사라진다 (check_straight 와 짝이다).
%
%   왜 전수 검사가 필요했나 / what this found
%
%       2026-10-15 에 모델 71 개의 합산점을 전수로 재 보니 112 개가 막대 없이
%       저장되어 있었다. `add_sum` 은 막대를 붙이고 있었지만 빌더 끝의
%       `mss_style` 이 2026-10-02 규칙대로 **다시 떼어 내고** 있었다. 손으로 한
%       모델만 열어 보는 것으로는 못 찾는 종류의 어긋남이다.
%
%   라이브러리 블록 안쪽은 보지 않는다 / library internals are left alone
%
%       PID Controller 같은 내장 블록은 안에 Sum 을 몇 개씩 품고 있다. 그것은
%       MathWorks 의 도면이고 우리가 고칠 것이 아니다. 조상 중에 라이브러리
%       연결(`ReferenceBlock`)이나 마스크가 있으면 건너뛴다.
%
%   고치는 법 / how to fix
%
%     모양·부호·크기 — 빌더에서 `add_sum(부모, 이름, 부호, [중심x 중심y])` 로
%                      만든다. 생짜 `add_block('…/Sum', …)` 은 쓰지 않는다.
%                      이미 만든 모델은 `mss_style(mdl)` 한 번으로 고쳐진다
%     지령옆         — 합산점의 **중심 높이**를 지령이 지나는 높이에 맞춘다.
%                      `align_to(sys, 합산점, 'Inport', port_xy(sys, 앞블록, 'Outport', k))`
%     되먹임밑       — 되먹임선을 `lane_line` 으로 합산점 **아래쪽 통로**에 띄운
%                      뒤 합산점의 x 에서 올려 붙인다. 통로 x 는 신호마다 다르게

if nargin < 2, verbose = false; end
if ~bdIsLoaded(bdroot_name(mdl)), load_system(mdl); end

v    = zeros(1,5);
rows = {};
TOL  = 1;                                   % px. 포트 정렬의 허용 오차

S = find_system(mdl, 'LookUnderMasks','all', 'BlockType','Sum');
for i = 1:numel(S)
    blk = S{i};
    if inside_library(blk, mdl), continue, end

    nm   = strrep(blk, [mdl '/'], '');
    nm   = strrep(nm, newline, ' ');
    bad  = {};

    %  --- (1) 모양 ---------------------------------------------------
    if ~strcmp(get_param(blk, 'IconShape'), 'round')
        v(1) = v(1) + 1;   bad{end+1} = '모양';
    end

    %  --- (2) 부호 ---------------------------------------------------
    sg = get_param(blk, 'Inputs');
    if isempty(sg) || sg(1) ~= '|' || sum(sg == '|') ~= 1
        v(2) = v(2) + 1;   bad{end+1} = sprintf('부호(%s)', sg);
    end

    %  --- (3) 크기 ---------------------------------------------------
    p = get_param(blk, 'Position');
    if (p(3)-p(1)) ~= 20 || (p(4)-p(2)) ~= 20
        v(3) = v(3) + 1;   bad{end+1} = sprintf('크기(%dx%d)', p(3)-p(1), p(4)-p(2));
    end

    %  --- (4)·(5) 선이 닿는 방향 --------------------------------------
    %  막대를 뺀 실제 입력 개수. 첫 입력은 왼쪽, 마지막 입력은 아래다
    LH = get_param(blk, 'LineHandles');
    PH = get_param(blk, 'PortHandles');
    nin = numel(PH.Inport);

    if nin >= 1
        [ok, why] = arrives(LH.Inport(1), PH.Inport(1), 'h', TOL);
        if ~ok
            v(4) = v(4) + 1;   bad{end+1} = ['지령옆:' why];
        end
    end
    if nin >= 2
        [ok, why] = arrives(LH.Inport(nin), PH.Inport(nin), 'v', TOL);
        if ~ok
            v(5) = v(5) + 1;   bad{end+1} = ['되먹임밑:' why];
        end
    end

    if ~isempty(bad)
        rows{end+1} = sprintf('%-34s %s', nm, strjoin(bad, ' · '));
    end
end

n = sum(v);

if verbose
    for i = 1:numel(rows), fprintf('    [합산점] %s\n', rows{i}); end
    fprintf('  %-26s 모양 %d · 부호 %d · 크기 %d · 지령옆 %d · 되먹임밑 %d\n', ...
            mdl, v(1), v(2), v(3), v(4), v(5));
end
end

% =====================================================================
function [ok, why] = arrives(lh, ph, want, tol)
%ARRIVES  선이 포트에 닿는 **마지막 토막**의 방향을 본다.
%
%   want 'h'  수평으로 닿아야 한다 (지령은 왼쪽에서 들어온다)
%   want 'v'  수직으로, 그리고 **밑에서** 올라와야 한다 (되먹임)
%
%   매달린 선은 여기서 세지 않는다 — check_lines 의 (4) 가 센다.
ok = true;  why = '';
if lh <= 0, return, end                         % 선이 없다. 여기서는 넘긴다

pts = get_param(lh, 'Points');
if size(pts,1) < 2, return, end

%  포트에 닿는 쪽이 어느 끝인지 읽는다. 가지선도 마지막 점이 포트다
pp = get_param(ph, 'Position');
if norm(pts(end,:) - pp) <= norm(pts(1,:) - pp)
    a = pts(end-1,:);   b = pts(end,:);
else
    a = pts(2,:);       b = pts(1,:);
end

d = b - a;
switch want
    case 'h'
        if abs(d(2)) > tol
            ok = false;   why = sprintf('%+d px 기울어 닿음', round(d(2)));
        end
    case 'v'
        if abs(d(1)) > tol
            ok = false;   why = sprintf('%+d px 옆에서 닿음', round(d(1)));
        elseif d(2) >= 0
            ok = false;   why = '위에서 내려옴';
        end
end
end

% =====================================================================
function tf = inside_library(blk, mdl)
%INSIDE_LIBRARY  조상 중에 라이브러리 연결이나 마스크가 있는가.
tf = false;
par = get_param(blk, 'Parent');
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
