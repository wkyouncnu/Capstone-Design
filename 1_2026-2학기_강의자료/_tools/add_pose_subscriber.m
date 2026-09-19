function s = add_pose_subscriber(m, pos, topic, ts, navCode, outs)
%ADD_POSE_SUBSCRIBER  Gazebo 의 odometry 를 받아 NED 항법량으로 바꾸는 상자.
%
%   add_pose_subscriber(m, [x y], topic, 'Ts_ctrl', navCode, ...
%                       {'pn','pe','psi','u','r','beta','chi','U'})
%
%   안에 들어가는 것
%     Subscribe      토픽에서 nav_msgs/Odometry 를 받는다
%     IsNew(Display) 새 메시지가 왔는지 눈으로 볼 수 있게
%     Bus Selector   필요한 아홉 필드만 꺼낸다
%     Nav            ENU -> NED 변환. 원점 상수 두 개를 안에 갖는다
%
%   NAVCODE 의 인자 순서는 Bus Selector 의 출력 아홉 개 다음에 orgN, orgE 다.
%
%   왜 상자에 넣는가
%       이 다섯 블록은 "배가 어디 있는지 읽는다" 한 가지 일을 한다. 최상위에
%       펼쳐 놓으면 Bus Selector 에서 나오는 선 아홉 개가 화면을 가로지른다.

if nargin < 4 || isempty(ts), ts = '-1'; end

s = add_subsys(m, 'PoseSubscriber', [pos(1) pos(2) pos(1)+170 pos(2)+140], ...
               {}, outs, gnc_colour('ros'));

add_block('ros2lib/Subscribe', [s '/OdomSub'], 'Position', [80 220 210 280]);
set_param([s '/OdomSub'], 'topicSource','Specify your own', ...
    'topic', topic, 'messageType','nav_msgs/Odometry', 'sampleTime', ts);

add_block('simulink/Sinks/Display', [s '/IsNew'], 'Position', [300 120 380 150]);

add_block('simulink/Signal Routing/Bus Selector', [s '/Sel'], ...
          'Position', [300 200 350 560]);
set_param([s '/Sel'], 'OutputSignals', ...
    ['pose.pose.position.x,pose.pose.position.y,' ...
     'pose.pose.orientation.x,pose.pose.orientation.y,' ...
     'pose.pose.orientation.z,pose.pose.orientation.w,' ...
     'twist.twist.linear.x,twist.twist.linear.y,twist.twist.angular.z']);

%  Nav 를 Bus Selector 의 아홉 출력 + 원점 둘을 받도록 만든다
add_block('simulink/User-Defined Functions/MATLAB Function', ...
          [s '/Nav'], 'Position', [520 180 700 640]);
ch = sfroot().find('-isa','Stateflow.EMChart','Path',[s '/Nav']);
ch.Script = navCode;
%  포트가 생기며 블록이 자라고, 그때의 포트 위치는 저장 뒤와 다르다. 다시 놓는다
set_param([s '/Nav'], 'Position', [520 180 700 640]);

%  Bus Selector 의 아홉 출력을 Nav 의 1~9 번 입력 높이에 **정확히** 맞춘다.
%  두 블록의 포트 간격이 다르면 아홉 선이 전부 몇 px 기운 사선이 된다
%  (2026-09-19 W07~W10 PoseSubscriber, 9건씩). 높이를 계산하지 않고 읽어서 맞춘다.
a = port_xy(s, 'Nav', 'Inport', 1);
b = port_xy(s, 'Nav', 'Inport', 9);
fit_span(s, 'Sel', 'Outport', a(2), b(2));

%  Subscribe 의 2번(메시지)을 Sel 의 입력 높이에 둔다 -> 직선.
%  1번(새 메시지 여부)은 Sel 위로 올라가 IsNew 로 간다 (꺾임 2회, Sel 을 넘지 않는다)
align_to(s, 'OdomSub', 'Outport', port_xy(s, 'Sel', 'Inport', 1), 2);
q  = get_param([s '/Sel'], 'Position');
yN = q(2) - 50;
set_param([s '/IsNew'], 'Position', [300 yN-15 380 yN+15]);
align_to(s, 'IsNew', 'Inport', yN);
p1 = port_xy(s, 'OdomSub', 'Outport', 1);
pn = port_xy(s, 'IsNew', 'Inport', 1);
po = get_param([s '/OdomSub'], 'PortHandles');
pd = get_param([s '/IsNew'],   'PortHandles');
pd2 = get_param([s '/Sel'],    'PortHandles');
draw_line(s, po.Outport(1), pd.Inport(1), [p1; p1(1)+30 p1(2); p1(1)+30 pn(2); pn]);
draw_line(s, po.Outport(2), pd2.Inport(1));

%  원점은 신호가 아니라 설정이다. 상자 안에 둔다
add_block('simulink/Sources/Constant', [s '/orgN'], ...
          'Position', [390 560 465 590], 'Value','origin_north');
add_block('simulink/Sources/Constant', [s '/orgE'], ...
          'Position', [390 610 465 640], 'Value','origin_east');

for k = 1:9
    add_line(s, sprintf('Sel/%d',k), sprintf('Nav/%d',k));
end
row_feed(s, 'Nav', [repmat({''},1,9), {'orgN','orgE'}]);

for k = 1:numel(outs)
    q = port_xy(s, 'Nav', 'Outport', k);
    set_param([s '/' outs{k}], 'Position', [820 q(2)-7 850 q(2)+7]);
    add_line(s, sprintf('Nav/%d',k), [outs{k} '/1']);
end

add_block('built-in/Note', [s '/note'], 'Position', [80 700], 'Text', sprintf([ ...
    '항법 — Gazebo 의 odometry 를 읽어 NED 항법량으로 바꾼다.\n' ...
    '  토픽 %s\n' ...
    '\n' ...
    'IsNew 는 새 메시지가 왔는지 보여 준다. 0 에서 안 바뀌면 토픽이 안 오는 것이다.\n' ...
    'Nav 첫머리의 가드가 없으면, 첫 메시지 전에 Subscribe 가 내는 0 버스를\n' ...
    '그대로 변환해 위치가 스폰 원점만큼(약 568 m) 튄다.'], topic));
end

% -------------------------------------------------------------------------
function fit_span(sys, blk, kind, y1, yN)
%FIT_SPAN  블록의 첫 포트가 Y1, 마지막 포트가 YN 에 오도록 키와 자리를 맞춘다.
%   Simulink 가 포트를 테두리에서 들여놓는 여백은 블록 종류마다 다르므로
%   재고, 고치고, 다시 잰다. 두세 번이면 1 px 안으로 들어온다.
b = [sys '/' blk];
h = get_param(b, 'PortHandles');
n = numel(h.(kind));
for it = 1:6
    p  = get_param(b, 'Position');
    f  = port_xy(sys, blk, kind, 1);
    l  = port_xy(sys, blk, kind, n);
    if abs(f(2)-y1) < 0.5 && abs(l(2)-yN) < 0.5, return, end
    top = p(2) - (f(2) - y1);
    bot = p(4) - (l(2) - yN);
    set_param(b, 'Position', round([p(1) top p(3) bot]));
end
end
