function [n, rows] = check_colour(mdl, verbose)
%CHECK_COLOUR  색이 빠진 블록을 찾아 보고한다. check_lines 와 같은 자리의 검사다.
%
%   n = check_colour('W03_4_teleop')
%   check_colour('W03_4_teleop', true)      % 건건이 나열한다
%
%   무엇을 흰색으로 두면 안 되는가
%
%     SubSystem · Chart · Model      단계를 나르는 상자다. 색이 곧 단계다
%     Scope · Display · ToWorkspace  내보내기. 회색 (measurement)
%     Goto · From · Terminator       이어주기. 회색
%
%   무엇은 흰색이어도 되는가
%
%     Constant · Step · Sine 같은 소스   흰색이 곧 'command' — 설정값이다
%     Gain · Sum · Integrator 같은 연산  속한 단계의 색을 받되, 강제하지 않는다
%     Inport · Outport                   서브시스템 경계이지 단계가 아니다
%
%   WHY THIS IS A GATE AND NOT A STYLE PREFERENCE
%
%   색은 장식이 아니라 읽는 순서다. 학생은 파랑에서 주황으로, 주황에서 노랑으로
%   눈을 옮기며 유도 → 제어 → 배분을 읽는다. 한 모델이라도 흰색이면 그 학생은
%   그 모델 앞에서 순서를 다시 찾아야 한다.
%
%   2026-09-17 에 이 검사를 처음 돌렸을 때 강의 모델 57개 중 40개가 걸렸다.
%   W07~W10 만 통과했다 — 그 빌더들만 색칠 루프를 들고 있었기 때문이다.
%
%   SB* 드릴도 검사한다
%
%   SB 모델은 GNC 사슬이 아니라 Simulink 블록 자체를 가르친다. 그래도 Scope 가
%   회색이고 전달함수가 초록인 것은 같다. 학생이 6주차에서 처음 만나는 색을
%   7주차에서 다시 만나야 색이 뜻을 갖는다.

if nargin < 2 || isempty(verbose), verbose = false; end

mdl = load_named(mdl);

MUST = {'SubSystem','Chart','ModelReference','Scope','Display','ToWorkspace', ...
        'Goto','From','Terminator','Record','XYGraph','Floating Scope'};

b = find_system(mdl,'LookUnderMasks','all','Type','Block');
rows = cell(0,3);
for i = 1:numel(b)
    bt = get_param(b{i},'BlockType');
    if ~ismember(bt, MUST), continue; end
    %  라이브러리 블록 안까지 파고들지 않는다. 링크된 블록은 상자 하나로 센다
    if insideLink(b{i}), continue; end
    if strcmp(get_param(b{i},'BackgroundColor'), 'white')
        rows(end+1,:) = {strrep(b{i}, newline, ' '), bt, 'white'}; %#ok<AGROW>
    end
end

n = size(rows,1);
if verbose || n > 0
    if n == 0
        fprintf('  [색] %-26s 통과\n', mdl);
    else
        fprintf('  [색] %-26s 흰색 %d개\n', mdl, n);
        if verbose
            for i = 1:n
                fprintf('        %-52s %s\n', rows{i,1}, rows{i,2});
            end
        end
    end
end
end

% -------------------------------------------------------------------------
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
if any(m == filesep) || any(m == '/')
    load_system(m); [~, m] = fileparts(m);
else
    load_system(m);
end
end
