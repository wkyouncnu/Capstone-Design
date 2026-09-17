function n = tag_feedback(sys, varargin)
%TAG_FEEDBACK  아직도 세 번 이상 꺾이는 선을 Goto/From 한 쌍으로 바꾼다.
%
%   n = tag_feedback('W06_5_offline')
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
%       W07~W10 이 쓴 방법을 그대로 쓴다. 신호에 이름을 붙여 내보내고 받는다.
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
job = struct('src',{},'sp',{},'dst',{},'dp',{});
for i = 1:numel(L)
    q = get_param(L(i), 'Points');
    if size(q,1) - 2 < o.MinTurns, continue, end
    s = get_param(L(i), 'SrcPortHandle');
    if s < 0, continue, end
    %  태그를 또 태그하지 않는다. 한 번 더 돌리면 Fr_Fr_x_1_1 같은 이름이
    %  겹겹이 쌓이고 블록만 늘어난다 (2026-09-17 W06_4 에서 재현).
    if strcmp(get_param(get_param(s,'Parent'), 'BlockType'), 'From'), continue, end
    for dd = get_param(L(i), 'DstPortHandle')'
        if dd < 0, continue, end
        if strcmp(get_param(get_param(dd,'Parent'), 'BlockType'), 'Goto'), continue, end
        job(end+1) = struct( ...
            'src', get_param(get_param(s,'Parent'), 'Name'), ...
            'sp',  get_param(s,  'PortNumber'), ...
            'dst', get_param(get_param(dd,'Parent'), 'Name'), ...
            'dp',  get_param(dd, 'PortNumber')); %#ok<AGROW>
    end
end
if isempty(job), return, end

for k = 1:numel(job)
    c   = job(k);
    tag = matlab.lang.makeValidName(sprintf('%s_%d', c.src, c.sp));
    j   = 0;
    while ~isempty(find_system(sys, 'SearchDepth',1, 'BlockType','Goto', 'GotoTag', tag))
        j   = j + 1;
        tag = matlab.lang.makeValidName(sprintf('%s_%d_%d', c.src, c.sp, j));
    end

    try
        delete_line(sys, sprintf('%s/%d', c.src, c.sp), sprintf('%s/%d', c.dst, c.dp));
    catch ME
        warning('tag_feedback:delete', '%s: %s', sys, ME.message);
        continue
    end

    g = drop_tag(sys, c.src, c.sp, tag, o.Dy + 40*(k-1));
    f = feed_from(sys, tag, c.dst, c.dp, o.Dy + 40*(k-1));
    set_param(g, 'TagVisibility', 'local');
    set_param(g, 'BackgroundColor', gnc_colour('measurement'));
    set_param(f, 'BackgroundColor', gnc_colour('measurement'));
    n = n + 1;
end
end
