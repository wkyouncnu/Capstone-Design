function V = W06_vrx_record(T_end)
% W06_VRX_RECORD  VRX 에서 2단계 시나리오를 그대로 돌리고 항적을 기록한다.
%
%   >> V = W06_vrx_record;          % 80초
%   >> V = W06_vrx_record(80);
%
%   W06_2_turn.slx 이 하는 일과 같다. 다만 결과를 **기록**해서
%   오프라인 모델(W06_5_offline)과 겹쳐 볼 수 있게 만든다.
%
%     0~20 s  FL=200 FR=200  직진
%    20~40 s  FL=300 FR= 50  우선회
%    40~60 s  FL= 50 FR=300  좌선회
%    60 s~    FL=0   FR=0    정지
%
%   시각은 벽시계가 아니라 **시뮬레이션 시각**(odometry 헤더 스탬프)으로 센다.
%   그래야 RTF 와 무관하게 시나리오가 같은 지점에서 바뀐다.
%
%   실행 전에 VRX 가 떠 있어야 한다.

if nargin < 1 || isempty(T_end), T_end = 80; end

TOP = '/wamv/sensors/position/ground_truth_odometry';
tl = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error(['%s 가 보이지 않는다.\n' ...
           '  VRX 가 떠 있는가 / ground_truth_enabled 가 true 인가 / ' ...
           'ROS_DOMAIN_ID 가 같은가'], TOP);
end

n  = ros2node(sprintf('/w06rec_%d', randi(9999)), 0);
c  = onCleanup(@() clear('n'));
pL = ros2publisher(n,'/wamv/thrusters/left/thrust','std_msgs/Float64');
pR = ros2publisher(n,'/wamv/thrusters/right/thrust','std_msgs/Float64');
s  = ros2subscriber(n, TOP, 'nav_msgs/Odometry');
mL = ros2message(pL);  mR = ros2message(pR);

m0 = receive(s, 20);
t0 = stamp(m0);
[psi0, x0, y0] = pose(m0);

V.t = []; V.pn = []; V.pe = []; V.psi = []; V.u = []; V.r = [];
fprintf('VRX 기록 시작 (%d 초)\n', T_end);
while true
    m  = receive(s, 10);
    ts = stamp(m) - t0;
    if ts > T_end, break; end

    [FL, FR] = scenario(ts);
    mL.data = FL;  mR.data = FR;
    send(pL, mL);  send(pR, mR);

    [ps, x, y] = pose(m);
    d  = [y - y0; x - x0];                       % [dN; dE]  (ENU -> NED)
    Rr = [cos(psi0) sin(psi0); -sin(psi0) cos(psi0)];
    b  = Rr*d;                                   % 출발점 기준 선체 정렬 좌표

    V.t(end+1,1)   = ts;
    V.pn(end+1,1)  = b(1);
    V.pe(end+1,1)  = b(2);
    V.psi(end+1,1) = rad2deg(atan2(sin(ps-psi0), cos(ps-psi0)));
    V.u(end+1,1)   = m.twist.twist.linear.x;
    V.r(end+1,1)   = -rad2deg(m.twist.twist.angular.z);   % ENU -> NED
end
mL.data = 0;  mR.data = 0;  send(pL, mL);  send(pR, mR);

% 선수각은 ±180° 에서 접힌다. 오프라인 모델은 접지 않으므로 풀어서 비교한다.
V.psi = rad2deg(unwrap(deg2rad(V.psi)));

sg = @(a,b) V.t >= b-5 & V.t <= b;
V.u_ss   = mean(V.u(sg(0,20)));
V.r_stbd = mean(V.r(sg(20,40)));
V.r_port = mean(V.r(sg(40,60)));
V.R_stbd = mean(V.u(sg(20,40)))/abs(deg2rad(V.r_stbd));
V.R_port = mean(V.u(sg(40,60)))/abs(deg2rad(V.r_port));

fprintf('  직진 u        %6.3f m/s\n', V.u_ss);
fprintf('  우선회 r      %+6.2f deg/s   반경 %5.2f m\n', V.r_stbd, V.R_stbd);
fprintf('  좌선회 r      %+6.2f deg/s   반경 %5.2f m\n', V.r_port, V.R_port);
fprintf('\n  >> out = sim(''W06_5_offline''); W06_offline_plot(out, V)\n');
end

% ---------------------------------------------------------------
function t = stamp(m)
t = double(m.header.stamp.sec) + double(m.header.stamp.nanosec)*1e-9;
end

function [psi, x, y] = pose(m)
q  = m.pose.pose.orientation;
ye = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y^2 + q.z^2));   % ENU yaw
p  = pi/2 - ye;
psi = atan2(sin(p), cos(p));                                % NED heading
x = m.pose.pose.position.x;  y = m.pose.pose.position.y;
end

function [FL, FR] = scenario(t)
% W06_2_turn / W06_5_offline 의 Scenario 블록과 같은 코드
if t < 20
    FL = 200;  FR = 200;
elseif t < 40
    FL = 300;  FR =  50;
elseif t < 60
    FL =  50;  FR = 300;
else
    FL = 0;    FR = 0;
end
end
