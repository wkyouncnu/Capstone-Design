function n = lay_notes(mdl)
%LAY_NOTES  블록·이름표·선에 겹친 주석(Note)을 도면 맨 아래로 내린다.
%
%   n = lay_notes('SB5_pid_done')          % 최상위와 모든 서브시스템
%
%   왜 필요한가 / why this exists
%       빌더는 주석을 블록 아래 빈자리에 놓는다. 그런데 tidy_model 이 부르는
%       arrangeSystem 은 **블록만** 옮기고 주석은 제자리에 둔다. 블록이 넓게
%       펼쳐지면 주석이 Scope·Display 위에 앉는다 (2026-09-19 SB2·SB5·SB7·SB8,
%       check_lines 의 (6) 블록겹침).
%
%   어떻게 / how
%       겹친 주석만 옮긴다. x 는 그대로 두고, 그 시스템의 블록·이름표·선 중 가장
%       아래보다 30 px 아래로 내린다. 둘 이상이면 차례로 쌓는다.
%       겹치지 않은 주석은 건드리지 않는다.
%
%   돌려주는 값은 옮긴 주석의 수다.

n = 0;
sys = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
for s = 1:numel(sys)
    try
        if ~strcmp(get_param(sys{s},'Type'),'block_diagram') && ...
           ~strcmp(get_param(sys{s},'SFBlockType'),'NONE'), continue, end
    catch
    end
    a = find_system(sys{s}, 'FindAll','on', 'SearchDepth',1, 'Type','annotation');
    if isempty(a), continue, end
    b = find_system(sys{s}, 'SearchDepth',1, 'Type','Block');
    b = b(~strcmp(b, sys{s}));
    occ = zeros(0,4);
    for i = 1:numel(b)
        r = get_param(b{i}, 'Position');
        occ(end+1,:) = r; %#ok<AGROW>
        if ~strcmp(get_param(b{i},'ShowName'),'off')
            occ(end+1,:) = [r(1)-20 r(2)-18 r(3)+20 r(4)+18]; %#ok<AGROW>  이름표 자리 (위·아래)
        end
    end
    L = find_system(sys{s}, 'FindAll','on', 'SearchDepth',1, 'Type','line');
    for i = 1:numel(L)
        q = get_param(L(i), 'Points');
        occ(end+1,:) = [min(q(:,1)) min(q(:,2)) max(q(:,1)) max(q(:,2))] + [-2 -2 2 2]; %#ok<AGROW>
    end
    if isempty(occ), continue, end
    yb = max(occ(:,4)) + 30;
    for k = 1:numel(a)
        try, r = get_param(a(k), 'Position'); catch, continue, end
        if numel(r) < 4, continue, end
        hit = false;
        for i = 1:size(occ,1)
            if overlap(r, occ(i,:)), hit = true; break, end
        end
        if ~hit, continue, end
        h = r(4) - r(2);
        set_param(a(k), 'Position', r + [0 yb-r(2) 0 yb-r(2)]);
        yb = yb + h + 20;
        n  = n + 1;
    end
end
end

function tf = overlap(p, q)
tf = min(p(3),q(3)) - max(p(1),q(1)) > 1 && min(p(4),q(4)) - max(p(2),q(2)) > 1;
end
