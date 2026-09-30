function n = tag_feedback(sys, varargin)
%TAG_FEEDBACK  아직도 세 번 이상 꺾이는 선을 Goto/From 한 쌍으로 바꾼다.
%
%   n = tag_feedback('W04_5_offline')
%   tag_feedback(sys, 'MinTurns', 3, 'Dy', 90)
%
%   왜 태그인가 / why a tag pair
%       되먹임 선은 오른쪽 출력에서 나와 왼쪽 입력으로 돌아가야 한다. 블록을
%       넘지 않으려면 내려갔다 가로질러 올라와야 하고, Simulink 는 옆면 포트에
%       **반드시 가로 토막을 붙이므로** 세 번 꺾인다. 배치로는 더 줄지 않는다
%       (2026-09-17 에 여섯 모델에서 확인).
%
%           내려감 ─ 가로지름 ─ 올라옴 ─ 포트에 붙는 토막   = 세 번
%
%       W05~W08 이 쓴 방법을 그대로 쓴다. 신호에 이름을 붙여 내보내고 받는다.
%       선이 사라지는 대신 **이름이 남는다.** 되먹임이 있다는 사실은 태그 이름으로
%       읽히고, 도면은 앞으로만 흐른다.
%
%   무엇을 바꾸지 않는가 / what does not change
%       Goto/From 은 선과 완전히 같다. 계산 결과는 한 자리도 달라지지 않는다.
%
%   먼저 lay_feedback 을 부를 것. 배치만으로 두 번에 끝나는 선까지 태그로 바꾸면
%   그림에서 되먹임이 눈에 보이지 않게 된다.
%
%   NAME/VALUE
%     'MinTurns'  몇 번부터 바꿀지. 기본 3
%     'Dy'        태그를 포트에서 얼마나 아래에 둘지. 기본 90
%
%   돌려주는 값은 바꾼 연결의 수다.

p = inputParser;
p.addParameter('MinTurns', 3);
p.addParameter('Dy',       90);
p.parse(varargin{:});
o = p.Results;
n = 0;

L = find_system(sys, 'FindAll','on', 'SearchDepth',1, 'Type','line');
job = struct('src',{},'sp',{},'dst',{},'dp',{},'nm',{});
for i = 1:numel(L)
    q = get_param(L(i), 'Points');
    if size(q,1) - 2 < o.MinTurns, continue, end
    s = get_param(L(i), 'SrcPortHandle');
    if s < 0, continue, end
    %  태그를 또 태그하지 않는다. 한 번 더 돌리면 Fr_Fr_x_1_1 같은 이름이
    %  겹겹이 쌓이고 블록만 늘어난다 (2026-09-17 W04_4 에서 재현).
    if strcmp(get_param(get_param(s,'Parent'), 'BlockType'), 'From'), continue, end
    for dd = get_param(L(i), 'DstPortHandle')'
        if dd < 0, continue, end
        if strcmp(get_param(get_param(dd,'Parent'), 'BlockType'), 'Goto'), continue, end
        job(end+1) = struct( ...
            'src', get_param(get_param(s,'Parent'), 'Name'), ...
            'sp',  get_param(s,  'PortNumber'), ...
            'dst', get_param(get_param(dd,'Parent'), 'Name'), ...
            'dp',  get_param(dd, 'PortNumber'), ...
            'nm',  get_param(L(i), 'Name')); %#ok<AGROW>
    end
end
if isempty(job), return, end

for k = 1:numel(job)
    c = job(k);

    %  ---- 태그 이름 정하기 (2026-10-01 교수 지시) ------------------------
    %  1) 같은 출발 포트에 **이미 Goto 가 붙어 있으면 그 태그를 다시 쓴다.**
    %     한 신호에 태그 하나다. 전에는 같은 값을 내보내는 태그가 둘씩 생겼다
    %     (W04_3_heading_offline 의 psi 와 MotionModel_1 이 같은 값이었다)
    tag   = tapped_tag(sys, c.src, c.sp);
    reuse = ~isempty(tag);

    %  2) 없으면 **신호 이름**으로 짓는다. 블록 이름에서 따지 않는다
    if ~reuse
        tag = signal_name(sys, c);
        tag = free_tag(sys, tag);
    end

    try
        delete_line(sys, sprintf('%s/%d', c.src, c.sp), sprintf('%s/%d', c.dst, c.dp));
    catch ME
        warning('tag_feedback:delete', '%s: %s', sys, ME.message);
        continue
    end

    %  태그마다 60 px 씩 층을 내린다. 40 px 이면 위 태그의 **이름표**(상자 아래
    %  14 px)가 아래 태그 상자에 1 px 걸쳐 check_lines 의 여섯째 항목에 잡힌다
    %  (2026-09-30 W04_4_inner_loop 의 Fr_deg2rad_1_1 / Fr_Quat2Yaw_1_1_1)
    if ~reuse
        g = drop_tag(sys, c.src, c.sp, tag, o.Dy + 60*(k-1));
        set_param(g, 'TagVisibility', 'local');
        set_param(g, 'BackgroundColor', gnc_colour('measurement'));
    end
    f = feed_from(sys, tag, c.dst, c.dp, o.Dy + 60*(k-1), next_sfx(sys, tag));
    set_param(f, 'BackgroundColor', gnc_colour('measurement'));
    n = n + 1;
end
end

% =====================================================================
function tag = tapped_tag(sys, src, sp)
%  SRC 의 SP 번 출력이 이미 이 층의 Goto 로 가고 있으면 그 태그를 돌려준다.
    tag = '';
    try
        ph = get_param([sys '/' src], 'PortHandles');
    catch, return
    end
    if sp > numel(ph.Outport), return, end
    for L = get_param(ph.Outport(sp), 'Line')'
        if L < 0, continue, end
        for dd = get_param(L, 'DstPortHandle')'
            if dd < 0, continue, end
            b = get_param(dd, 'Parent');
            if strcmp(get_param(b, 'BlockType'), 'Goto')
                tag = get_param(b, 'GotoTag');  return
            end
        end
    end
end

% =====================================================================
function nm = signal_name(sys, c)
%  이 선이 나르는 값의 **이름**을 찾는다. 블록 이름은 마지막 수단이다.
%
%    1) 선에 붙은 이름          빌더가 set_param(line,'Name','psi') 로 준 것
%    2) 출발이 서브시스템이면   그 Outport 블록의 이름 (MotionModel -> psi)
%    3) 도착이 서브시스템이면   그 Inport 블록의 이름  (HeadingCtrl 의 psi)
%    4) 그래도 없으면           <블록>_<포트> — 예전 방식 (마지막 수단)

    nm = strtrim(c.nm);
    if ~isempty(nm), nm = matlab.lang.makeValidName(nm); return, end

    nm = port_label(sys, c.src, 'Outport', c.sp);
    if ~isempty(nm), return, end

    nm = port_label(sys, c.dst, 'Inport', c.dp);
    if ~isempty(nm), return, end

    nm = matlab.lang.makeValidName(sprintf('%s_%d', c.src, c.sp));
end

function nm = port_label(sys, blk, kind, k)
%  BLK 이 서브시스템이면 그 안의 KIND 블록 K 번의 이름을 돌려준다.
    nm = '';
    b = [sys '/' blk];
    try
        if ~strcmp(get_param(b,'BlockType'), 'SubSystem'), return, end
        p = find_system(b, 'SearchDepth',1, 'BlockType', kind, 'Port', num2str(k));
        if isempty(p), return, end
        nm = matlab.lang.makeValidName(get_param(p{1}, 'Name'));
    catch, nm = '';
    end
end

% =====================================================================
function tag = free_tag(sys, want)
%  같은 이름의 Goto 가 **모델 어디에도** 없어야 한다. global 태그 하나가
%  다른 층에 있으면 From 이 어느 쪽을 받을지 정해지지 않는다.
    root = bdroot(sys);
    tag  = want;  j = 1;
    while ~isempty(find_system(root, 'LookUnderMasks','all', ...
                               'BlockType','Goto', 'GotoTag', tag))
        j   = j + 1;
        tag = sprintf('%s_%d', want, j);
    end
end

function s = next_sfx(sys, tag)
%  같은 태그를 받는 From 이 여럿이면 블록 이름이 겹치지 않게 번호를 센다.
    j = 1;
    while ~isempty(find_system(sys, 'SearchDepth',1, 'LookUnderMasks','all', ...
                               'Name', sprintf('Fr_%s_%d', tag, j)))
        j = j + 1;
    end
    s = num2str(j);
end
