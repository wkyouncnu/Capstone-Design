function moved = lay_boxes(sys, names, varargin)
%LAY_BOXES  선이 **하나도 없는** 상자를 도면 아래 한 줄에 나란히 놓는다.
%
%   lay_boxes('W02_3_goto_turtlesim', {'Animate','Logging'})
%   n = lay_boxes(m, {'Animate','Logging'}, 'Gap', 120, 'Pitch', 170)
%
%   어떤 상자를 말하는가 / which boxes
%       Animate · Logging 처럼 **포트가 없는** 서브시스템이다. 신호를 바깥 선이
%       아니라 안쪽의 From 태그(global)로 받으므로 최상위에는 선이 한 가닥도
%       붙지 않는다. 그래서 옮겨도 선이 하나도 바뀌지 않는다 — 꺾임 수도,
%       check_lines 의 일곱 항목도 그대로다. 자리만 바뀐다.
%
%   왜 필요한가 / why this exists
%       `Simulink.BlockDiagram.arrangeSystem` 은 층을 신호로 정한다. 선이 없는
%       상자는 어느 층에도 속하지 않으므로 **왼쪽 위 빈자리**로 간다.
%       2026-10-01 에 이렇게 나왔다 —
%
%         W09_0_offline   Logging x =  15 · Animate x = 30
%                         (MotionModel 220 · SensorModel 450 · RateMeter 700)
%         W02_3_goto_…    Animate x = 250 · Logging x = 550
%                         (PoseSubscriber 850)
%         W03_1_frame_…   Logging x = -18   (캔버스 왼쪽 밖)
%
%       로깅·화면은 사슬의 **마지막** 단계(measurement)다. 그것이 맨 왼쪽에 서면
%       도면이 오른쪽에서 왼쪽으로 읽히고 `check_flow` 가 어긋남으로 센다.
%       선 검사는 이것을 보지 못한다 — 옮길 선이 없기 때문이다.
%
%       `lay_chain` 의 'Boxes' 가 하는 일이 바로 이것인데, `lay_chain` 을 쓰지 않는
%       빌더(W02 · W03 · W09)는 그 기능에 손이 닿지 않았다. 그래서 따로 둔다.
%
%   어디에 놓는가 / where they go
%       도면에 있는 **모든 것**(블록 사각형 · 블록 이름표 · 선의 점)보다 아래로
%       Gap 만큼 내려간 한 줄이다. 줄이 사슬보다 넓어지면 접는다.
%       `model-layout.md` §1 — "오른쪽 끝 또는 그 아래에 나란히".
%
%       순서는 **준 순서 그대로** 왼쪽에서 오른쪽이다. 같은 단계의 상자끼리는
%       `check_flow` 가 x 를 따지지 않으므로 읽기 좋은 순서로 적으면 된다.
%
%   언제 부르는가 / when to call it
%       `tidy_model` **뒤에** 부른다. tidy_model 안에서 arrangeSystem 이 최상위를
%       다시 놓기 때문이다. 선을 건드리지 않으므로 뒤에 불러도 배선이 상하지 않는다.
%
%   NAME/VALUE
%     'Gap'    도면 맨 아래에서 얼마나 떨어뜨릴지. 기본 120
%     'Pitch'  상자 사이의 가로 간격. 기본 170
%     'X0'     줄의 왼쪽. 기본 [] — 남은 블록 중 가장 왼쪽에 맞춘다
%     'Wrap'   줄의 오른쪽 한계. 기본 [] — 남은 블록 중 가장 오른쪽에 맞춘다
%
%   돌려주는 값은 자리를 옮긴 상자의 수다.

p = inputParser;
p.addParameter('Gap',   120);
p.addParameter('Pitch', 170);
p.addParameter('X0',    []);
p.addParameter('Wrap',  []);
p.parse(varargin{:});
o = p.Results;
moved = 0;

if ischar(names) || isstring(names), names = {char(names)}; end

opened = false;
if ~bdIsLoaded(sys), load_system(sys); opened = true; end

blks = find_system(sys, 'SearchDepth',1, 'Type','Block');
blks = blks(~strcmp(blks, sys));

%  옮길 상자를 고른다. 이름이 없는 모델은 조용히 넘어간다 (gnc_roles 와 같은 규약).
%  **선이 붙은 블록은 옮기지 않는다** — 자리를 바꾸면 선을 다시 그어야 하고,
%  그것은 이 도구의 일이 아니다.
move = {};
for k = 1:numel(names)
    b = [sys '/' names{k}];
    if getSimulinkBlockHandle(b) <= 0, continue, end
    ph = get_param(b, 'PortHandles');
    if ~isempty(ph.Inport) || ~isempty(ph.Outport)
        warning('lay_boxes:ports', '%s 에 포트가 있다 — 옮기지 않는다', names{k});
        continue
    end
    move{end+1} = names{k}; %#ok<AGROW>
end
if isempty(move)
    if opened, close_system(sys, 0); end
    return
end

%  남는 것들의 아래 끝. 사각형만 보면 **이름표**와 **선**이 상자 위로 올라온다
stay  = blks(~ismember(cellfun(@(b) get_param(b,'Name'), blks, 'UniformOutput',false), move));
yMax  = -inf;  xMin = inf;  xMax = -inf;
for i = 1:numel(stay)
    r = get_param(stay{i}, 'Position');
    yMax = max(yMax, r(4));  xMin = min(xMin, r(1));  xMax = max(xMax, r(3));
    nb = name_box(stay{i});
    if ~any(isnan(nb))
        yMax = max(yMax, nb(4));  xMin = min(xMin, nb(1));  xMax = max(xMax, nb(3));
    end
end
L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
for i = 1:numel(L)
    try, q = get_param(L(i), 'Points'); catch, continue, end
    yMax = max(yMax, max(q(:,2)));
    xMin = min(xMin, min(q(:,1)));  xMax = max(xMax, max(q(:,1)));
end
if ~isfinite(yMax)
    if opened, close_system(sys, 0); end
    return
end

x0   = o.X0;   if isempty(x0),   x0   = xMin; end
xLim = o.Wrap; if isempty(xLim), xLim = max(xMax, x0 + 400); end

bx = x0;  by = yMax + o.Gap;  bh = 0;
for k = 1:numel(move)
    b = [sys '/' move{k}];
    r = get_param(b, 'Position');
    w = r(3)-r(1);  h = r(4)-r(2);
    if bx > x0 && bx + w > xLim, bx = x0;  by = by + bh + 70;  bh = 0; end
    set_param(b, 'Position', round([bx, by, bx+w, by+h]));
    bx    = bx + w + o.Pitch;
    bh    = max(bh, h);
    moved = moved + 1;
end

save_system(sys);
if opened, close_system(sys, 0); end
end
