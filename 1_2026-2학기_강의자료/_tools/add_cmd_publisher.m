function s = add_cmd_publisher(m, pos, topics, ts, inp)
%ADD_CMD_PUBLISHER  추력 발행 배관을 한 상자에 넣는다. 입력은 추진기 수만큼.
%
%   add_cmd_publisher(m, [x y], {'/wamv/thrusters/left/thrust', ...
%                                '/wamv/thrusters/right/thrust'}, 'Ts_ctrl')
%
%   ROS 2 로 숫자 하나를 보내려면 블록 세 개가 필요하다.
%     Blank Message   빈 메시지를 만들고
%     Bus Assignment  그 안의 data 필드를 채우고
%     Publish         토픽으로 내보낸다
%
%   추진기 수만큼 벌이 생긴다 — 좌·우면 여섯 블록, 선수추진기까지면 아홉이다.
%   최상위에 늘어놓으면 신호 사슬이 그만큼 늘어나는데, 늘어난 만큼 알려 주는 것은 없다 — "추력을 Gazebo 로 보낸다" 한 문장이 전부다.
%   그래서 상자 하나로 묶는다.

if nargin < 4 || isempty(ts), ts = '-1'; end
%  입력 이름 — 기본은 5주차의 좌·우 둘이다. 6주차는 선수추진기까지 셋을 준다
%  (add_cmd_publisher(m, pos, topics, ts, {'FL','FR','FB'})). 토픽 수와 같아야 한다
if nargin < 5 || isempty(inp), inp = {'FL','FR'}; end
nThr = numel(topics);
assert(numel(inp) == nThr, 'add_cmd_publisher: 토픽 %d 개, 입력 이름 %d 개', nThr, numel(inp));
%  블록 이름에 붙는 꼬리표 — FL -> L, FR -> R, FB -> B. 이름을 따로 짓지 않는다
side = cellfun(@(nm) nm(2:end), inp, 'UniformOutput', false);

s = add_subsys(m, 'CmdPublisher', [pos(1) pos(2) pos(1)+150 pos(2)+90], ...
               inp, {}, gnc_colour('ros'));

for k = 1:nThr
    y = 120 + (k-1)*180;
    t = side{k};

    ab = [s '/Asg' t];
    add_block('simulink/Signal Routing/Bus Assignment', ab, ...
              'Position', [360 y-40 440 y+40]);
    set_param(ab, 'AssignedSignals','data');

    %  Blank 는 Asg 의 **1번 포트 높이**에, Publish 는 Asg 의 출력 높이에 놓는다.
    %  Asg 가운데에 맞추면 1번 포트가 가운데보다 위에 있어 20 px 기운 사선이 된다
    %  (2026-09-19 W05~W08 CmdPublisher). 포트 높이는 계산하지 않고 읽는다.
    bb = [s '/Blank' t];
    add_block('ros2lib/Blank Message', bb, 'Position', [160 y-20 260 y+20]);
    set_param(bb, 'entityType','std_msgs/Float64', ...
                  'messageType','std_msgs/Float64', 'SampleTime', ts);
    align_to(s, ['Blank' t], 'Outport', port_xy(s, ['Asg' t], 'Inport', 1));

    pb = [s '/Pub' t];
    add_block('ros2lib/Publish', pb, 'Position', [540 y-20 660 y+20]);
    align_to(s, ['Pub' t], 'Inport', port_xy(s, ['Asg' t], 'Outport', 1));
    set_param(pb, 'topicSource','Specify your own', ...
                  'topic', topics{k}, 'messageType','std_msgs/Float64');

    %  버스는 1번, 채워 넣을 값은 2번. 두 선 모두 꺾임 1회를 넘지 않는다
    add_line(s, ['Blank' t '/1'], ['Asg' t '/1']);
    add_line(s, ['Asg'   t '/1'], ['Pub' t '/1']);

    %  입력 포트를 Bus Assignment 의 2번 포트 높이로 옮긴다 -> 선이 직선
    q = port_xy(s, ['Asg' t], 'Inport', 2);
    set_param([s '/' inp{k}], 'Position', [60 q(2)-7 90 q(2)+7]);
    add_line(s, [inp{k} '/1'], ['Asg' t '/2']);
end

%  주석은 마지막 벌 아래에 둔다. 추진기가 셋이 되면 세 번째 벌이 420 px 자리로
%  내려오므로 고정값이면 주석이 그 벌에 겹친다 (6주차 CmdPublisher, 블록겹침 2건)
add_block('built-in/Note', [s '/note'], ...
          'Position', [160 120+(nThr-1)*180+120], 'Text', sprintf([ ...
    'ROS 2 로 숫자 하나를 보내는 데 블록 세 개가 필요하다.\n' ...
    '  Blank Message   빈 메시지를 만든다\n' ...
    '  Bus Assignment  그 안의 data 필드를 채운다\n' ...
    '  Publish         토픽으로 내보낸다\n' ...
    '\n' ...
    '발행하는 토픽\n%s'], strjoin(topics, newline)));
end
