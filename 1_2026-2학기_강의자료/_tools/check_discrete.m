function [n, rows] = check_discrete(mdl, verbose)
%CHECK_DISCRETE  모델 안에 남은 **이산 시간 블록**을 세어 나열한다.
%                Count the discrete-time blocks left in a model.
%
%   n = check_discrete(mdl)          조용히 세기만 한다
%   [n, rows] = check_discrete(mdl, true)   나열하고 개수를 돌려준다
%
%   합격선은 **0 이 아니다.** 예외로 남겨도 되는 블록이 있기 때문이다.
%   그 대신 **왜 이산인가를 그 자리에 적게** 만드는 도구다.
%
%   교수 지시 2026-10-01 — *"이산 시간 제어기든 전달함수든 전부 연속 시간으로
%   바꿀 것."* 원칙은 **전부 연속**이다.
%
%   | 블록 | 연속 등가 |
%   |---|---|
%   | `Discrete Transfer Fcn`  num(z)/den(z) | `Transfer Fcn`  num(s)/den(s) |
%   | `Discrete-Time Integrator`             | `Integrator` |
%   | `Discrete Derivative`                  | 되먹임으로 대신한다 (미분하지 않는다) |
%   | `Discrete Filter`                      | `Transfer Fcn` |
%   | `Discrete PID` / `PID (Discrete-time)` | `PID Controller` (Continuous-time) |
%
%   예외로 **인정되는 것은 셋뿐**이다. 그 셋은 `Reason` 칸에 적히고 개수에서 빠진다.
%
%     1  대수 루프를 끊는 `Unit Delay`   — 끊을 다른 방법이 없다
%     2  Stateflow 차트의 이산 샘플      — 차트는 이산 사건으로 돈다
%     3  ROS `Subscribe`·`Publish`       — 통신은 사건이지 미분방정식이 아니다
%
%   **"솔버가 FixedStepDiscrete 라서" 는 이유가 아니다.** 고정스텝 연속 솔버
%   `ode4` 로 바꾸면 같은 스텝으로 돈다 (2026-10-01 4주차 VRX 모델에서 확인).
%
%   예외를 쓰려면 그 블록의 `Description` 에 **왜 이산인지 한 줄**을 적는다.
%   적혀 있지 않으면 `(이유 없음)` 으로 나열되고 **개수에 들어간다**.

if nargin < 2, verbose = false; end

%  이름에 'Discrete' 가 들어가는 BlockType 과, 이산으로 설정할 수 있는 블록
hard = {'DiscreteTransferFcn','DiscreteFilter','DiscreteIntegrator', ...
        'DiscreteStateSpace','DiscreteZeroPole','DiscreteFir', ...
        'DiscreteDerivative'};

rows   = cell(0, 4);      % {블록, 종류, 예외인가, 이유}
blocks = find_system(mdl, 'LookUnderMasks','all', 'Type','Block');

for i = 1:numel(blocks)
    b = blocks{i};
    try, t = get_param(b, 'BlockType'); catch, continue; end

    kind = '';  exempt = false;  why = '';

    switch t
        case hard
            kind = t;

        case 'UnitDelay'
            kind   = 'UnitDelay';
            why    = reason_of(b);
            %  대수 루프 차단은 인정되는 예외다. 이유가 적혀 있어야 한다
            exempt = ~isempty(why);

        case 'Memory'
            kind   = 'Memory';
            why    = reason_of(b);
            exempt = ~isempty(why);

        case 'PID Controller'
            try
                if strcmp(get_param(b, 'TimeDomain'), 'Discrete-time')
                    kind = 'PID(Discrete-time)';
                end
            catch
            end

        case {'SubSystem','S-Function','M-S-Function'}
            %  마스크 이름이 Discrete 로 시작하는 라이브러리 블록
            try
                r = get_param(b, 'ReferenceBlock');
                if ~isempty(r) && contains(r, 'Discrete')
                    kind = 'ref:Discrete';
                end
            catch
            end
    end

    if isempty(kind), continue; end

    %  Stateflow 차트 안쪽과 ROS 블록은 조건 없이 예외다
    if in_chart(b) || is_ros(b)
        exempt = true;
        if isempty(why), why = 'Stateflow/ROS — 사건 구동'; end
    end

    if isempty(why), why = '(이유 없음)'; end
    rows(end+1, :) = {strrep(b, newline, ' '), kind, exempt, why};  %#ok<AGROW>
end

keep = ~cell2mat(rows(:,3));
if isempty(rows), keep = false(0,1); end
n = sum(keep);

if verbose
    fprintf('  check_discrete %s — 고쳐야 할 이산 블록 %d개', mdl, n);
    ex = size(rows,1) - n;
    if ex > 0, fprintf(' (예외 %d개는 뺌)', ex); end
    fprintf('\n');
    for i = 1:size(rows,1)
        if rows{i,3}, mark = '  예외'; else, mark = '**고칠것**'; end
        fprintf('    %-10s %-22s %-50s %s\n', mark, rows{i,2}, rows{i,1}, rows{i,4});
    end
end
end

% -------------------------------------------------------------------------
function why = reason_of(b)
%  Description 에 적힌 "왜 이산인가" 한 줄을 읽는다
why = '';
try
    d = strtrim(get_param(b, 'Description'));
catch
    return
end
if isempty(d), return; end
%  첫 줄만 쓴다
c = strsplit(d, newline);
why = strtrim(c{1});
end

function tf = in_chart(b)
tf = false;
try
    p = get_param(b, 'Parent');
    while ~isempty(p) && ~strcmp(p, bdroot(b))
        if strcmp(get_param(p, 'BlockType'), 'SubSystem')
            r = get_param(p, 'ReferenceBlock');
            if contains(lower(r), 'stateflow'), tf = true; return; end
            if strcmp(get_param(p,'SFBlockType'), 'Chart'), tf = true; return; end
        end
        p = get_param(p, 'Parent');
    end
catch
end
end

function tf = is_ros(b)
tf = false;
try
    r = get_param(b, 'ReferenceBlock');
    tf = contains(lower(r), 'ros');
catch
end
if ~tf
    try
        tf = contains(lower(get_param(b,'Name')), {'subscribe','publish'});
    catch
    end
end
end
