function S = W10_sway_demo(T_open, Y_cmd, pos_sign)
%W10_SWAY_DEMO  개루프 횡이동 실험 — 10주차 §E-2 를 재현한다.
%
%   먼저 W10_setup 을 실행해 T_pinv 를 만들어 둔다. VRX 가 떠 있어야 한다.
%
%     W10_setup
%     S = W10_sway_demo;          % 25초, 횡력 200 N
%     S = W10_sway_demo(25, 200); % 같은 뜻
%
%   되먹임 없이 배분 결과만 발행하고, 선체 기준 이동량을 잰다.
%   틸팅 추진기가 없으면 옆으로 못 간다는 것을 수치로 보이는 것이 목적이다.

if nargin < 1 || isempty(T_open), T_open = 25;  end
if nargin < 2 || isempty(Y_cmd),  Y_cmd  = 200; end
% pos 토픽 부호. 기본 -1 은 모델 안의 Gain(-1) 과 같다 (ENU 관절각)
if nargin < 3 || isempty(pos_sign), pos_sign = -1; end

% --- ROS 2 도메인 맞추기 (Simulink 프로필 기준) -----------------------
try
    prof = getpref('ROS_Toolbox','ROS_NetworkAddress_Profiles');
    if ~isempty(prof) && isfield(prof{1},'DomainID')
        setenv('ROS_DOMAIN_ID', num2str(double(prof{1}.DomainID)));
    end
catch
end
if isempty(getenv('ROS_DOMAIN_ID')), setenv('ROS_DOMAIN_ID','0'); end
fprintf('0) ROS_DOMAIN_ID = %s\n', getenv('ROS_DOMAIN_ID'));

TOP = '/wamv/sensors/position/ground_truth_odometry';
tl  = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error(['%s 가 보이지 않는다.\n' ...
           '  VRX 가 떠 있는가 / ground_truth_enabled 가 true 인 urdf 인가 / ' ...
           'ROS_DOMAIN_ID 가 양쪽 같은가'], TOP);
end

% --- 배분 계산 -------------------------------------------------------
T_pinv = evalin('base','T_pinv');       % W10_setup 이 만든 의사역행렬
tau = [0; Y_cmd; 0];
f   = T_pinv*tau;                       % [FxL FyL FxR FyR]
[FL, aL] = toFrontAngle(f(1), f(2));
[FR, aR] = toFrontAngle(f(3), f(4));
fprintf('1) 배분 결과  tau = [0 %g 0]\n', Y_cmd);
fprintf('   f = [%.1f %.1f %.1f %.1f] N\n', f);
fprintf('   좌현 %.1f N @ %+.1f deg,  우현 %.1f N @ %+.1f deg\n', ...
        FL, rad2deg(aL), FR, rad2deg(aR));

% pos 토픽은 ENU 관절각이라 부호를 뒤집는다 (모델의 Gain(-1) 과 같은 이유)
posL = pos_sign*aL;  posR = pos_sign*aR;
fprintf('   pos 발행값  좌 %+.1f deg,  우 %+.1f deg  (부호 %+d)\n', ...
        rad2deg(posL), rad2deg(posR), pos_sign);

% --- 발행 준비 -------------------------------------------------------
n   = ros2node(sprintf('/w10_sway_%d', randi(9999)));
c   = onCleanup(@() clear('n'));
sub = ros2subscriber(n, TOP, 'nav_msgs/Odometry');
pTL = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
pTR = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
pPL = ros2publisher(n, '/wamv/thrusters/left/pos',     'std_msgs/Float64');
pPR = ros2publisher(n, '/wamv/thrusters/right/pos',    'std_msgs/Float64');
mT  = ros2message('std_msgs/Float64');

% --- 개루프 T_open 초 (시뮬레이션 시각) --------------------------------
%  벽시계로 재면 RTF 가 낮은 컴퓨터일수록 시뮬레이션 시간이 덜 흐른다.
%  odometry 의 시각 도장으로 재야 어느 컴퓨터에서나 같은 실험이 된다.
fprintf('2) %g 초 개루프 발행 (시뮬레이션 시각, 되먹임 없음)\n', T_open);
mT.data = posL; send(pPL, mT);
mT.data = posR; send(pPR, mT);
pause(1.0);                              % 방위각이 자리를 잡을 시간
m0 = receive(sub, 20);                   % 추력을 켜는 순간을 출발점으로
[y0_n, x0_n, psi0] = unpackENU(m0);
t0 = stampSec(m0);
w = tic;
while true
    mT.data = FL; send(pTL, mT);
    mT.data = FR; send(pTR, mT);
    mT.data = posL; send(pPL, mT);
    mT.data = posR; send(pPR, mT);
    mm = sub.LatestMessage;
    if ~isempty(mm) && stampSec(mm) - t0 >= T_open, break; end
    if toc(w) > 20*T_open, warning('시뮬레이션 시간이 흐르지 않는다 — VRX 가 멈췄는가'); break; end
    pause(0.1);
end
mT.data = 0; send(pTL, mT); send(pTR, mT); send(pPL, mT); send(pPR, mT);

m1 = receive(sub, 20);
[y1_n, x1_n, psi1] = unpackENU(m1);
t1 = stampSec(m1);

% --- 선체 기준 변위 --------------------------------------------------
dY = y1_n - y0_n;  dX = x1_n - x0_n;
fwd = dY*cos(psi0) + dX*sin(psi0);       % 전후 (+ 선수 방향)
stb = dY*sin(psi0) - dX*cos(psi0);       % 좌우 (+ 우현)

fprintf('\n===== 개루프 횡이동 (%.1f s, 시뮬레이션 시각 기준) =====\n', t1 - t0);
fprintf('  선체 기준 우현 이동      %+7.2f m\n', stb);
fprintf('  선체 기준 전후 이동      %+7.2f m\n', fwd);
% 선수각 변화는 NED (북에서 시계 +) 로 보고한다. ENU 요각과 부호가 반대
dpsi = -rad2deg(wrapToPiLocal(psi1 - psi0));
fprintf('  선수각 변화 (NED, 시계 +) %+7.1f deg\n', dpsi);

S = struct('stb', stb, 'fwd', fwd, 'dpsi_deg', dpsi, ...
           'dt_sim', t1 - t0, 'f', f, 'FL', FL, 'FR', FR, ...
           'aL_deg', rad2deg(aL), 'aR_deg', rad2deg(aR));
end

% =====================================================================
function [F, a] = toFrontAngle(fx, fy)
%  방위각을 ±90 deg 안으로 접는다. 밖으로 나가면 추력 부호를 뒤집는다.
%  추진기 방위각 한계가 ±45 deg 이므로 156 deg 같은 값을 그대로 보내면 안 된다.
F = hypot(fx, fy);
a = atan2(fy, fx);
if abs(a) > pi/2
    a = a - sign(a)*pi;
    F = -F;
end
end

function [E, N, psi] = unpackENU(m)
E = m.pose.pose.position.x;
N = m.pose.pose.position.y;
q = m.pose.pose.orientation;
psi = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y^2 + q.z^2));   % ENU yaw
end

function t = stampSec(m)
t = double(m.header.stamp.sec) + double(m.header.stamp.nanosec)*1e-9;
end

function a = wrapToPiLocal(a)
a = mod(a + pi, 2*pi) - pi;
end
