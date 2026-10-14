function n = scope_legend(m)
%SCOPE_LEGEND  모델 안의 모든 Scope 에 **범례**를 켜고, 범례에 쓸 이름을 붙인다.
%              Turn the legend on for every Scope, and give it names to show.
%
%   n = scope_legend('W05_0_offline')      % 손본 Scope 개수를 돌려준다
%
%   왜 필요한가 / why this exists
%
%     교수 지시 2026-10-14 — "scope 도 범례를 항상 추가할 수 있도록."
%
%     Scope 한 칸에 선이 둘 이상 그려지면(지령과 실제값) 어느 쪽이 무엇인지
%     그림만 보고는 알 수 없다. 수업 중에 "위가 지령입니다" 를 말로 덧붙여야
%     하고, 자료에 그림으로 실으면 그 말이 함께 가지 않는다.
%
%   범례는 **신호 이름**을 쓴다 / the legend prints signal names
%
%     Simulink 의 Scope 범례는 들어오는 **선의 이름**을 적는다. 이름이 없으면
%     'Signal 1' 이라고 적는다 — 범례를 켜 놓고 이름을 안 붙이면 아무 쓸모가
%     없다는 뜻이다. 그래서 이 도구는 두 가지를 한꺼번에 한다.
%
%       1) ShowLegends = 'on'
%       2) 이름 없는 입력선에 **출처에서 따온 이름**을 붙인다
%            From 블록이 출처면  -> GotoTag (그것이 곧 신호 이름이다)
%            Mux 가 출처면       -> Mux 로 들어가는 선들에 같은 규칙을 적용
%                                   (범례는 묶인 원소 이름을 차례로 적는다)
%
%     이미 이름이 붙어 있는 선은 건드리지 않는다. 손으로 지어 준 이름이
%     태그 이름보다 나은 경우가 있기 때문이다 (예: psi_ref_deg).
%
%   언제 돌리는가 / when to run it
%     tidy_model 이 선을 다 손질한 **뒤**에 부른다. 선을 지웠다 다시 그으면
%     이름이 함께 지워지므로 (keep_signals 의 설명과 같은 이유다).

opened = false;
if ~bdIsLoaded(m), load_system(m); opened = true; end

n = 0;
scopes = find_system(m, 'LookUnderMasks','all', 'FollowLinks','on', ...
                        'MatchFilter', @Simulink.match.allVariants, 'BlockType','Scope');
for i = 1:numel(scopes)
    sc = scopes{i};
    try, set_param(sc, 'ShowLegends', 'on'); catch, end
    ph = get_param(sc, 'PortHandles');
    for k = 1:numel(ph.Inport)
        name_upstream(get_param(ph.Inport(k), 'Line'), 0);
    end
    n = n + 1;
end

if opened, close_system(m, 0); end
end

% ---------------------------------------------------------------------
function name_upstream(lh, depth)
%  선 하나에 이름을 붙인다. 출처가 Mux 면 그 위로 한 단계 더 올라간다.
if lh <= 0 || depth > 2, return, end
try
    src = get_param(lh, 'SrcBlockHandle');
    if src <= 0, return, end
    bt = get_param(src, 'BlockType');
catch
    return
end

if strcmp(bt, 'Mux')
    %  묶음선 자체에는 이름을 붙이지 않는다 — 범례가 원소 이름을 차례로 적는다
    ph = get_param(src, 'PortHandles');
    for k = 1:numel(ph.Inport)
        name_upstream(get_param(ph.Inport(k), 'Line'), depth + 1);
    end
    return
end

try
    if ~isempty(get_param(lh, 'Name')), return, end   % 손으로 지은 이름은 그대로
catch
    return
end

nm = '';
switch bt
    case 'From',     nm = get_param(src, 'GotoTag');
    case 'Goto',     nm = get_param(src, 'GotoTag');
    otherwise
        %  From 이 아닌 출처는 이름을 **지어내지 않는다.** 블록 이름(R2D 따위)을
        %  신호 이름으로 쓰면 범례가 거짓말을 한다 — 그 자리는 빌더가 직접
        %  이름을 붙이는 곳이다 (4주차 psi_ref_deg · psi_deg).
        return
end
if isempty(nm), return, end
try, set_param(lh, 'Name', char(nm)); catch, end
end
