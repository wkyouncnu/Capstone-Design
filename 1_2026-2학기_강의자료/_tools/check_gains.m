function [n, rows] = check_gains(mdl, verbose)
%CHECK_GAINS  0 인 게인과 **음수 되먹임 게인**을 센다. 세는 도구이지 관문은 아니다.
%
%   n = check_gains('W04_3_heading_offline')
%   check_gains('W04_3_heading_offline', true)    % 건건이 나열한다
%   [n, rows] = check_gains(m)
%
%   무엇을 세는가 / what is counted
%     (1) **값이 0 인 게인** — 그 갈래는 아무 일도 하지 않는다. 블록·적분기·합산
%         입력이 통째로 도면만 차지한다
%     (2) **값이 음수인 게인** — 되먹임 게인은 양수로 두고 부호는 합산점에서 준다
%
%   왜 관문(합격선 0)이 아닌가 / why this is a report, not a gate
%       교수 지시 2026-10-01 — "게인이 0 인 경로는 지운다. **단 문서가 그 갈래를
%       켜는 실습을 하고 있으면 지우지 말 것.**"
%
%       4주차가 정확히 그런 경우다. 0 인 게인 셋이 전부 **가르치려고 켜는 갈래**다.
%         Ki_psi = 0    2-10 절에서 0 -> 50 -> 200 으로 켜 본다 (port_eff 실습)
%         Kd_u   = 0    2-3 절에서 켜 보고 "속도축의 D 는 해롭다" 를 확인한다
%         Ki, Kd = 0    1-6 ~ 1-9 절에서 P·I·D 를 하나씩 켜 본다
%
%       그래서 이 도구는 **세어서 알릴 뿐** 합격선을 두지 않는다. 걸린 게인마다
%       "문서의 어느 절이 이것을 켜는가" 를 답할 수 있어야 하고, 답할 수 없으면
%       그때 지운다. 도구가 사람 대신 판단하게 두면 실습이 조용히 사라진다.
%
%   음수 게인은 다르다 / negative gains are a real finding
%       부호는 **합산점에 보이게** 둔다. 게인에 마이너스를 숨기면 도면만 보고는
%       덧셈인지 뺄셈인지 알 수 없다. 2026-09 까지 Kd_psi = -400 이 그랬다.
%
%   돌려주는 값 N 은 (1)+(2) 의 합이다.

if nargin < 2, verbose = false; end
[~, name] = fileparts(char(mdl));
was = bdIsLoaded(name);
if ~was, load_system(name); end

rows = cell(0,4);                                   % {경로, 식, 값, 종류}
gains = find_system(name, 'LookUnderMasks','all', 'FollowLinks','on', ...
                    'MatchFilter', @Simulink.match.allVariants, 'BlockType','Gain');
for i = 1:numel(gains)
    expr = get_param(gains{i}, 'Gain');
    v = value_of(expr, gains{i});
    if isempty(v) || ~isnumeric(v), continue, end
    if all(v(:) == 0)
        rows(end+1,:) = {gains{i}, expr, mat2str(v), '0 인 게인'};     %#ok<AGROW>
    elseif all(v(:) < 0)
        rows(end+1,:) = {gains{i}, expr, mat2str(v), '음수 게인'};     %#ok<AGROW>
    end
end

n = size(rows,1);
if verbose || n > 0
    fprintf('  [게인] %-26s 0 인 게인·음수 게인 %d개 (합격선 없음 — 아래를 읽고 판단할 것)\n', name, n);
end
if verbose
    for i = 1:n
        fprintf('        %-10s %-46s %s = %s\n', rows{i,4}, ...
                strrep(rows{i,1}, newline, ' '), rows{i,2}, rows{i,3});
    end
end
if ~was, close_system(name, 0); end
end

% ---------------------------------------------------------------------
function v = value_of(expr, blk)
%  게인 식을 값으로 푼다. 변수 이름이면 모델·base workspace 에서 찾는다.
v = [];
try
    v = slResolve(expr, blk);
catch
    try, v = evalin('base', expr); catch, v = []; end
end
end
