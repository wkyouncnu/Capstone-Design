function [n, rows] = check_flow(mdl, verbose)
%CHECK_FLOW  최상위 도면이 왼쪽에서 오른쪽으로 읽히는가. 합격선은 0 이다.
%
%   n = check_flow('W04_3_heading_offline')
%   check_flow('W04_3_heading_offline', true)     % 어긋난 짝을 건건이 나열한다
%   [n, rows] = check_flow(m)
%
%   무엇을 세는가 / what is counted
%       최상위 블록을 GNC 여섯 단계로 나누고, **뒷 단계 블록이 앞 단계 블록보다
%       왼쪽에 놓인 짝**의 수를 센다. 0 이면 도면이 한 방향으로 읽힌다.
%
%         command  <  reference  <  controller  <  allocation  <  plant  <  measurement
%            1           2             3              4            5           6
%
%   왜 이것을 재는가 / why this is a gate and not a preference
%       2026-09-30 에 교수가 W04_3_heading_offline 을 열어 보고 "너무 가독성이
%       낮다. 선들도 정신없다" 고 했다. 재어 보니 실제로 이랬다.
%
%         psi_ref_deg (지령)  x = 685        HeadingCtrl (제어기)  x = 1030
%         Alloc (배분)        x = 600        MotionModel (운동모델) x =  800
%         Animate (화면)      x = 126        OpenLoop (제어기)      x =  410
%
%       지령이 제어기보다 오른쪽에 있고, 운동모델이 제어기보다 왼쪽에 있고,
%       화면이 맨 왼쪽에 있었다. 배선 검사(check_lines)는 **일곱 항목 0** 으로
%       통과한 상태였다 — 선은 깨끗한데 읽을 수가 없었다. 선이 깨끗한 것과
%       도면이 읽히는 것은 다른 문제이고, 그래서 검사가 따로 있어야 한다.
%
%       범인은 tidy_model 안의 Simulink.BlockDiagram.arrangeSystem 이었다.
%       그것은 선 길이를 줄이는 데는 좋지만 **단계 순서를 모른다.**
%       model-layout.md §8 이 이미 경고하고 있었는데, 경고만으로는 아무도
%       어긋난 것을 알아차리지 못했다. 그래서 세는 도구를 만든다.
%
%   어떻게 단계를 아는가 / where the stages come from
%       색을 정하는 그 표, `gnc_roles.m` 하나다. 표를 두 벌 두지 않는다 —
%       색과 순서가 같은 뜻을 나르므로 같은 표에서 나와야 한다.
%       표에 없는 블록은 블록 종류로 짐작한다 (Constant·Step 은 지령,
%       Scope·To Workspace 는 로깅). 그래도 모르면 **세지 않고** 따로 알린다.
%
%   무엇을 빼는가 / what is left out
%       Goto · From    되먹임을 푸는 도구다. 이것들이 사슬 밖에 있는 것이
%                      곧 목적이므로 자리를 따지지 않는다
%       종착 블록      출력 포트가 없는 블록(To Workspace · Scope · ROS Publish)과
%                      로깅·화면 상자는 맨 오른쪽 **또는 사슬 아래**면 통과다.
%                      사슬 전체보다 아래로 내려간 것은 x 를 따지지 않는다
%                      (model-layout.md §1 — "오른쪽 끝 또는 그 아래에 나란히").
%                      `lay_sinks` 가 종착 블록을 아래 한 줄로 내리는 것이
%                      이 볼트의 배치 규칙이므로, 그것을 어김으로 세지 않는다.
%                      사슬 **안에** 남아 있는 종착 블록은 그대로 자리를 따진다
%       주석(Note)     블록이 아니다
%
%   어떻게 고치는가 / how to fix
%       좌표를 손으로 고치지 않는다. 빌더에서 `gnc_chain` 으로 단계 열을 받고
%       그 x 를 블록 생성 함수에 넘긴다. 그리고 tidy_model 을 부를 때
%       'KeepRoot', true 를 준다 — 최상위에는 arrangeSystem 을 걸지 않는다는 뜻이다.
%
%   돌려주는 것
%       n     어긋난 짝의 수. 합격선 0
%       rows  N×4 cell — {뒷단계블록, 그 단계, 앞단계블록, 그 단계}

if nargin < 2 || isempty(verbose), verbose = false; end

mdl = load_named(mdl);

%  --- 단계 이름 -> 순위. gnc_colour 가 아는 이름을 전부 받는다 ----------
RANK = { 'command',1; 'reference',2; 'guidance',2; 'mission',2; ...
         'control',3; 'controller',3; 'allocation',4; 'thruster',4; ...
         'plant',5; 'env',5; 'ros',5; 'measurement',6; 'logging',6 };

%  ros 가 5 인 이유 — ROS 블록은 배(Gazebo)와 맞닿는 경계다. 오프라인 모델의
%  MotionModel 이 서 있는 바로 그 자리에 Publish·Subscribe 가 선다. 오프라인과
%  VRX 쌍둥이가 **같은 자리에서 같은 것**을 보여 주어야 하기 때문이다.

%  --- 표에 없는 블록을 종류로 짐작한다 ----------------------------------
SRC  = {'Constant','Step','Ramp','Sin','SignalGenerator','DigitalClock', ...
        'Clock','FromWorkspace','FromFile','SignalBuilder','UniformRandomNumber', ...
        'RandomNumber','BandLimitedWhiteNoise','Inport'};
SINK = {'Scope','Display','ToWorkspace','Terminator','Record','XYGraph', ...
        'Floating Scope','ToFile','Outport'};
SKIP = {'Goto','From'};

role = gnc_roles(mdl);
if isempty(role), role = cell(0,2); end
stageOf = containers.Map('KeyType','char','ValueType','char');
for k = 1:size(role,1)
    nm = role{k,1};
    if any(nm == '/'), continue, end       % 경로로 적힌 예외는 안쪽 블록이다
    stageOf(nm) = role{k,2};               % 뒤에 적힌 것이 이긴다 (paint_roles 와 같다)
end
rankOfStage = containers.Map(RANK(:,1), RANK(:,2));

b = find_system(mdl, 'SearchDepth',1, 'Type','Block');
b = b(~strcmp(b, mdl));

N    = numel(b);
name = cell(N,1);  stg = cell(N,1);
pos  = zeros(N,4); rk = zeros(N,1);
unknown = {};
for i = 1:N
    name{i} = get_param(b{i}, 'Name');
    pos(i,:) = get_param(b{i}, 'Position');
    bt = get_param(b{i}, 'BlockType');
    if ismember(bt, SKIP)
        rk(i) = 0;  stg{i} = '(태그)';
        continue
    end
    if isKey(stageOf, name{i}) && isKey(rankOfStage, lower(stageOf(name{i})))
        stg{i} = lower(stageOf(name{i}));
    elseif ismember(bt, SRC)
        stg{i} = 'command';
    elseif ismember(bt, SINK)
        stg{i} = 'measurement';
    else
        rk(i) = 0;  stg{i} = '(모름)';
        unknown{end+1} = name{i}; %#ok<AGROW>
        continue
    end
    rk(i) = rankOfStage(stg{i});
end

%  --- 사슬 아래로 내려간 종착 블록은 x 를 따지지 않는다 ------------------
%  종착 = 출력 포트가 없는 블록, 또는 로깅 단계로 적힌 블록.
%  사슬의 맨 아래보다 더 아래에 있으면 "그 아래에 나란히" 놓인 것으로 본다.
term = false(N,1);
for i = 1:N
    if rk(i) == 6, term(i) = true; continue, end
    try
        ph = get_param(b{i}, 'PortHandles');
        term(i) = isempty(ph.Outport) && ~isempty(ph.Inport);
    catch
    end
end
chain  = rk >= 1 & rk <= 6 & ~term;
exempt = false(N,1);
if any(chain)
    chainBottom = max(pos(chain,4));
    exempt = term & (pos(:,2) >= chainBottom);
end

%  --- 어긋난 짝 세기 -----------------------------------------------------
%  뒷 단계 블록의 왼쪽 모서리가 앞 단계 블록의 왼쪽 모서리보다 왼쪽이면 한 건.
rows = cell(0,4);
ok = rk > 0 & ~exempt;
idx = find(ok);
for a = 1:numel(idx)
    for c = 1:numel(idx)
        i = idx(a); j = idx(c);
        if rk(i) >= rk(j), continue, end               % i 가 앞 단계여야 한다
        if pos(j,1) < pos(i,1)
            rows(end+1,:) = {name{j}, stg{j}, name{i}, stg{i}}; %#ok<AGROW>
        end
    end
end
n = size(rows,1);

%  --- 보고 -------------------------------------------------------------
if verbose || n > 0
    if n == 0
        fprintf('  [흐름] %-26s 통과\n', mdl);
    else
        fprintf('  [흐름] %-26s 어긋남 %d건 (좌->우 단계 순서)\n', mdl, n);
    end
    if verbose && n > 0
        shown = min(n, 24);
        for i = 1:shown
            jx = find(strcmp(name, rows{i,1}), 1);
            ix = find(strcmp(name, rows{i,3}), 1);
            fprintf('        %-18s %-12s x=%4d  <  %-18s %-12s x=%4d\n', ...
                    rows{i,1}, ['(' rows{i,2} ')'], pos(jx,1), ...
                    rows{i,3}, ['(' rows{i,4} ')'], pos(ix,1));
        end
        if n > shown, fprintf('        ... 그 밖에 %d건\n', n - shown); end
    end
    if verbose && ~isempty(unknown)
        fprintf('        단계를 모르는 블록 %d개 — gnc_roles.m 에 적을 것: %s\n', ...
                numel(unknown), strjoin(unique(unknown), ', '));
    end
end
end

% -------------------------------------------------------------------------
function m = load_named(m)
%  파일 경로를 받아도 동작하게 한다. find_system 은 경로가 아니라 모델 이름을 받는다.
if any(m == filesep) || any(m == '/')
    load_system(m); [~, m] = fileparts(m);
else
    load_system(m);
end
end
