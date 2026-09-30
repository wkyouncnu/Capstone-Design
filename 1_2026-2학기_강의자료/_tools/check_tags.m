function [n, rows] = check_tags(mdl, verbose)
%CHECK_TAGS  태그 이름이 **신호 이름**인지 세고, To Workspace 개수를 알린다. 0 이 합격선.
%
%   n = check_tags('W04_3_heading_offline')
%   check_tags('W04_3_heading_offline', true)     % 걸린 태그를 나열한다
%   [n, rows] = check_tags(m)
%
%   무엇을 세는가 / what is counted — 셋 다 0 이 합격선
%     (1) **블록 이름 꼴 태그**  `MotionModel_1` · `Quat2Yaw_2` · `Integ_1`
%         모델에 같은 이름의 블록이 있고 뒤에 포트 번호가 붙은 태그다.
%         tag_feedback 이 신호 이름을 못 찾았을 때 짓는 마지막 수단의 이름이다
%     (2) **접미사 태그**  `psi_1` · `u_ref_1_1` · `FL_1`
%         같은 값을 나르는 태그가 둘 이상 생겼다는 뜻이다. 한 신호에 태그 하나다
%     (3) **받는 From 이 없는 Goto** — 아무도 안 받는 태그는 도면만 늘린다
%
%   함께 알리는 것 (합격선 없음)
%     To Workspace 개수. 모델당 **한 개**가 규칙이다. Bus Creator 로 묶어 보내고
%     꺼낼 때 이름이 살아 있게 한다 (out.log.psi). 두 개 이상이면 이유를 적을 것
%
%   왜 세는가 / why this is a gate
%       교수 지시 2026-10-01 — "Goto/From 이 너무 복잡하다. 태그 이름을 실제
%       신호 이름으로 쓸 것. Fr_psi_a_1 꼴의 접미사·중복 태그를 없애고, 같은
%       신호는 태그 하나를 여러 From 이 받게 할 것."
%
%       경고만으로는 아무도 알아차리지 못한다. check_flow 를 만든 것과 같은
%       이유로 **세는 도구**를 둔다. 2026-10-01 에 처음 돌렸을 때 4주차 여덟
%       모델에 블록 이름 꼴 태그가 29개, To Workspace 가 28개 있었다.
%
%   고치는 법 / how to fix
%       빌더에서 그 **선에 이름을 준다** — set_param(h, 'Name', 'psi').
%       tag_feedback 이 태그를 지을 때 그 이름을 먼저 본다. 이름이 없으면
%       서브시스템의 포트 이름을, 그것도 없으면 블록 이름을 쓴다 (마지막 수단).

if nargin < 2, verbose = false; end
[~, name] = fileparts(char(mdl));
was = bdIsLoaded(name);
if ~was, load_system(name); end

opts  = {'LookUnderMasks','all', 'FollowLinks','on', ...
         'MatchFilter', @Simulink.match.allVariants};
gotos = find_system(name, opts{:}, 'BlockType','Goto');
froms = find_system(name, opts{:}, 'BlockType','From');
tws   = find_system(name, opts{:}, 'BlockType','ToWorkspace');

gTag = cellfun(@(b)get_param(b,'GotoTag'), gotos, 'uni',0);
fTag = cellfun(@(b)get_param(b,'GotoTag'), froms, 'uni',0);
bName = cellfun(@(b)get_param(b,'Name'), ...
                find_system(name, opts{:}, 'Type','Block'), 'uni',0);

rows = cell(0,3);                                   % {태그, 종류, 설명}
for i = 1:numel(gTag)
    t = gTag{i};

    %  (1) 블록 이름 꼴 — <모델 안의 블록 이름>_<숫자> 로 쪼개진다
    tok = regexp(t, '^(.*?)_(\d+(_\d+)*)$', 'tokens', 'once');
    if ~isempty(tok) && any(strcmp(tok{1}, bName))
        rows(end+1,:) = {t, '블록이름 꼴', ...
            sprintf('블록 %s 의 이름에서 딴 것으로 보인다', tok{1})}; %#ok<AGROW>
        continue
    end

    %  (2) 접미사 — 꼬리의 _1 · _1_1 을 떼면 다른 태그와 같아진다
    if ~isempty(tok)
        base = tok{1};
        if any(strcmp(base, gTag))
            rows(end+1,:) = {t, '접미사 태그', ...
                sprintf('%s 와 같은 값이다. 태그 하나를 여러 From 이 받게 할 것', base)}; %#ok<AGROW>
            continue
        end
    end

    %  (3) 받는 사람이 없는 태그
    if ~any(strcmp(t, fTag))
        rows(end+1,:) = {t, '받는 From 없음', '아무도 안 받는 태그다'};  %#ok<AGROW>
    end
end

n = size(rows,1);
if verbose || n > 0
    fprintf('  [태그] %-26s 지적 %d건 · Goto %d · From %d · To Workspace %d\n', ...
            name, n, numel(gotos), numel(froms), numel(tws));
elseif nargout == 0
    fprintf('  [태그] %-26s 통과 (Goto %d · From %d · To Workspace %d)\n', ...
            name, numel(gotos), numel(froms), numel(tws));
end
if numel(tws) > 1
    fprintf('        To Workspace 가 %d개다. 모델당 한 개가 규칙이다 — 이유를 적을 것\n', numel(tws));
end
if verbose
    for i = 1:n
        fprintf('        %-14s %-20s %s\n', rows{i,2}, rows{i,1}, rows{i,3});
    end
end
if ~was, close_system(name, 0); end
end
