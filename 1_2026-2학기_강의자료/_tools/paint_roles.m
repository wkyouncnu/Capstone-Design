function n = paint_roles(mdl, role)
%PAINT_ROLES  역할표대로 블록에 배경색을 칠한다. 색표는 gnc_colour.m 하나뿐이다.
%
%   n = paint_roles(m, {'Guidance','guidance'; 'InnerLoop','control'})
%
%   인자를 하나만 주면 gnc_roles.m 의 표를 쓴다. 바뀐 것이 있으면 저장한다.
%
%   role  N×2 cell — {블록이름 또는 상대경로, gnc_colour 의 단계 이름}
%         'InnerLoop/Kp' 처럼 '/' 가 들어가면 경로로 보고 그 블록만 칠한다.
%         모델에 없는 이름은 조용히 건너뛴다 (모델마다 구성이 다르므로).
%
%   빌더는 최상위 블록만 적으면 된다. 나머지는 이 함수가 채운다.
%
%   세 단계로 칠한다
%
%     1) 역할표      최상위 상자에 단계 색을 준다
%     2) 물려받기    안쪽 서브시스템은 부모의 색을 물려받는다
%     3) 회색 칠하기 Scope·Display·ToWorkspace·Goto·From·Terminator 는 회색
%
%   WHY INHERITANCE
%
%   Guidance 안의 WpManager 는 유도의 일부다. 빌더가 그것까지 적으면 표가
%   모델마다 서른 줄이 되고, 그러면 아무도 최신 상태로 두지 않는다. 안쪽 상자는
%   부모를 물려받게 두고, 예외만 표에 경로로 적는다.
%
%   최상위인데 표에 없는 서브시스템은 흰색으로 남는다. 일부러 그렇게 두었다 —
%   check_colour 가 그것을 잡아서 빌더에 한 줄을 추가하게 만든다.
%
%   WHY A TOOL AND NOT A COPY-PASTED LOOP
%
%   같은 루프가 빌더 4개에 흩어져 있었고, 그래서 W02·W03·W09·W04 의 빌더에는
%   아예 빠져 있었다. 2026-09-17 감사에서 강의 모델 48개 전부가 걸렸고 흰색
%   블록이 1034개였다. 색을 칠하는 곳이 하나면 빠뜨릴 곳도 하나다.
%
%   THE COLOUR FOLLOWS THE STAGE, NOT THE BLOCK TYPE
%
%   W04_P1 의 SumE 는 Sum 블록이지만 제어기의 일부여서 주황이다. 덧셈이라서
%   무슨 색인 것이 아니라, 제어 단계에 속해서 주황이다. 역할표를 쓸 때도 그렇게
%   적는다 — 블록이 무엇인지가 아니라 어느 단계에 속하는지를 적는다.

mdl = load_named(mdl);
if nargin < 2, role = gnc_roles(mdl); end
if isempty(role), role = cell(0,2); end
n = 0;

%  1) 역할표
for k = 1:size(role,1)
    col = gnc_colour(role{k,2});
    b = resolve(mdl, role{k,1});
    for i = 1:numel(b), n = n + paint(b{i}, col); end
end

%  2) 물려받기 — 위에서 아래로 내려가야 3층 이상도 채워진다
subs = find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem');
subs = [subs; find_system(mdl, 'LookUnderMasks','all', 'BlockType','Chart')];
[~, ord] = sort(cellfun(@(s) sum(s == '/'), subs));
subs = subs(ord);
for i = 1:numel(subs)
    if insideLink(subs{i}), continue; end
    p = get_param(subs{i}, 'Parent');
    if isempty(p) || strcmp(p, mdl), continue; end     % 최상위는 표가 정한다
    if strcmp(get_param(subs{i},'BackgroundColor'), 'white')
        n = n + paint(subs{i}, get_param(p,'BackgroundColor'));
    end
end

%  3) 내보내기·이어주기 블록 — 어느 층에서든 회색
%     그 여섯은 무엇을 계산하지 않고 내보내거나 이어 줄 뿐이어서, 어느 모델
%     어느 층에서든 뜻이 같다. 그래서 역할표에 적지 않는다.
grey = gnc_colour('measurement');
SINK = {'Scope','Display','ToWorkspace','Goto','From','Terminator','Record', ...
        'XYGraph','Floating Scope'};
for t = 1:numel(SINK)
    b = find_system(mdl, 'LookUnderMasks','all', 'BlockType', SINK{t});
    for i = 1:numel(b)
        if insideLink(b{i}), continue; end
        n = n + paint(b{i}, grey);
    end
end

if n > 0, save_system(mdl); end
end

% -------------------------------------------------------------------------
function b = resolve(mdl, name)
if any(name == '/')
    b = find_system(mdl, 'LookUnderMasks','all', 'Type','Block', ...
                    'Name', nameOf(name));
    b = b(strcmp(b, [mdl '/' name]));
else
    b = find_system(mdl, 'SearchDepth',1, 'LookUnderMasks','all', ...
                    'Type','Block', 'Name', name);
end
end

function k = paint(blk, col)
k = 0;
if isempty(col) || strcmp(col, 'white'), return; end
try
    if ~strcmp(get_param(blk,'BackgroundColor'), col)
        set_param(blk, 'BackgroundColor', col); k = 1;
    end
catch
end
end

function s = nameOf(p)
i = find(p == '/', 1, 'last');
if isempty(i), s = p; else, s = p(i+1:end); end
end

function tf = insideLink(blk)
%  블록이 라이브러리 링크 안에 있는가. 조상을 모두 거슬러 본다 — 링크된 상자의
%  두 칸 안쪽 블록은 자기 ReferenceBlock 이 비어 있어서 한 칸만 보면 놓친다.
tf = false;
blk = get_param(blk, 'Parent');          % 자기 자신은 세지 않는다
while ~isempty(blk) && any(blk == '/')
    if isLinked(blk), tf = true; return; end
    blk = get_param(blk, 'Parent');
end
end

function tf = isLinked(blk)
%  라이브러리 블록 안은 건드리지 않는다. 링크가 끊어지고, 다음 갱신에서 되돌아온다
tf = false;
try
    tf = ~isempty(get_param(blk,'ReferenceBlock')) && ...
         ~strcmp(get_param(blk,'LinkStatus'),'none');
catch
end
end

function m = load_named(m)
%  파일 경로를 받아도 동작하게 한다. find_system 은 경로가 아니라 모델 이름을
%  받는다 — 'C:\...' 를 넘기면 'C' 라는 시스템을 찾다가 실패한다.
load_system(m);
if any(m == filesep) || any(m == '/'), [~, m] = fileparts(m); end
end
