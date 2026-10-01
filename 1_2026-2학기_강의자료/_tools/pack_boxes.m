function moved = pack_boxes(mdl, names, gap)
%PACK_BOXES  포트 없는 상자(Animate·Logging 등)를 사슬 **바로 아래**로 끌어올린다.
%
%   pack_boxes('W05_1_vrx', {'Animate','Logging'})
%   pack_boxes(mdl, names, 60)
%
%   왜 필요한가 (교수 지시 2026-10-01 — 빈 공간을 남기지 않는다)
%
%   `lay_chain` 은 상자를 놓을 때 **태그 더미가 내려갈 깊이를 미리 잡아** 둔다.
%   그런데 그 뒤에 `snug_tags` 가 태그를 포트 옆으로 끌어올리므로, 잡아 둔 깊이가
%   통째로 빈 칸으로 남는다. `W05_1_vrx` 는 그렇게 약 500 px 이 비어 있었다.
%
%   자리를 다시 계산하지 않고 **있는 그대로 위로 민다.** 상자끼리의 간격과 줄은
%   `lay_chain` 이 잡은 것을 그대로 쓰고, 전체를 한 덩어리로 올리기만 한다.
%   포트가 없는 상자이므로 **선이 걸리지 않아** 배선이 틀어질 일이 없다.
%
%   GAP 은 사슬의 아래 끝에서 상자 줄까지의 거리. 기본 60 px.

if nargin < 3 || isempty(gap), gap = 60; end
if ischar(names) || isstring(names), names = {char(names)}; end

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end

all = find_system(mdl, 'SearchDepth',1, 'Type','Block');
all = all(~strcmp(all, mdl));

%  **선이 걸린 상자는 건드리지 않는다.** 블록만 옮기면 선의 중간 점은 그대로
%  남아 끝 토막이 사선이 된다 (check_lines 의 (5)). 포트가 없는 상자만 옮긴다.
isBox = false(size(all));
for k = 1:numel(all)
    if ~ismember(get_param(all{k}, 'Name'), names), continue, end
    try
        ph = get_param(all{k}, 'PortHandles');
        if ~isempty(ph.Inport) || ~isempty(ph.Outport), continue, end
    catch
        continue
    end
    isBox(k) = true;
end
if ~any(isBox), moved = 0; if opened, close_system(mdl,0); end, return, end

%  상자 말고 나머지가 실제로 어디까지 내려와 있는가 — **이름표까지** 본다.
%  이름표를 빼고 재면 상자가 남의 이름 위에 올라앉는다 (check_lines 의 블록겹침)
bottom = -inf;
for k = 1:numel(all)
    if isBox(k), continue, end
    p = get_param(all{k}, 'Position');
    if numel(p) < 4, continue, end
    bottom = max(bottom, p(4));
    t = name_box(all{k});
    if ~any(isnan(t)), bottom = max(bottom, t(4)); end
end
if ~isfinite(bottom), moved = 0; if opened, close_system(mdl,0); end, return, end

%  상자 덩어리의 맨 위
top = inf;
for k = 1:numel(all)
    if ~isBox(k), continue, end
    p = get_param(all{k}, 'Position');
    top = min(top, p(2));
end

dy = round(top - (bottom + gap));
if dy <= 0, moved = 0; if opened, close_system(mdl,0); end, return, end

moved = 0;
for k = 1:numel(all)
    if ~isBox(k), continue, end
    p = get_param(all{k}, 'Position');
    set_param(all{k}, 'Position', p - [0 dy 0 dy]);
    moved = moved + 1;
end

if opened, save_system(mdl); close_system(mdl, 0); end
end
