function info = W06_anim_capture(which, varargin)
% W06_ANIM_CAPTURE  실시간 화면(W06_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W06_anim_capture('dock')     img/W06_anim_dock.png    5단 옆걸음 접안
%   W06_anim_capture('front')    img/W06_anim_front.png   7단 전진 접안
%   W06_anim_capture('ned')      img/W06_anim_ned.png     8단 NED 위치제어
%   W06_anim_capture('vrx')      img/W06_anim_vrx.png     6단 Gazebo (VRX 기동 필요)
%
%   이름있는 인자
%     'Pacing'  VRX 에서 쓸 페이싱 비율. **실측 RTF 를 그대로 넣는다.**
%               더 높이면 모델과 시뮬레이터가 CPU 를 다퉈 오히려 느려진다
%               (3주차 2-3). 주지 않으면 여기서 20 초 동안 잰다
%     'Stop'    몇 초(시뮬레이션 시각)에서 멈출 것인가. 주지 않으면 모델이
%               스스로 멈출 때까지 둔다 — 접안 사다리는 도착하고 stop_hold
%               초를 더 버틴 뒤 끝나므로, 그 화면이 남아야 읽을 수 있다
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(게인·시간·RTF)도 남지 않는다.
%     이 함수는 조건을 함께 돌려준다 (5주차 W05_anim_capture 와 같은 꼴).
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (성능 그림 · 추진기 그림 · 실시간 화면).
%     gcf 로 저장하면 마지막으로 만진 창이 저장된다. W06_animate 가 인자 없이
%     부르면 자기 창 핸들을 돌려주므로 **그 핸들로** 저장한다.
%
%   모델은 건드리지 않는다
%     StopTime·페이싱은 Simulink.SimulationInput 으로만 준다. set_param 으로
%     모델에 써 넣으면 .slx 가 바뀌어 다음 빌드와 어긋난다.

p = inputParser;
p.addParameter('Pacing', []);
p.addParameter('Stop',   []);
p.parse(varargin{:});
pacing = p.Results.Pacing;
tStop  = p.Results.Stop;

here = fileparts(mfilename('fullpath'));
cd(here);
img = fullfile(here, 'img');
if ~isfolder(img), mkdir(img); end

switch which
    case 'dock',  stage = 5;   vrx = false;
    case 'vrx',   stage = 6;   vrx = true;
    case 'front', stage = 7;   vrx = false;
    case 'ned',   stage = 8;   vrx = false;
    otherwise
        error('W06_anim_capture:which', ...
              '모르는 이름 ''%s''. dock · vrx · front · ned 중 하나.', which);
end

%  게인·과업을 언제나 기본값에서 출발시킨다. W06_setup 은 스스로 모델을
%  돌리므로(auto_run) 그 자동 실행만 건너뛴다
setappdata(0, 'W06_stage', stage);
setappdata(0, 'W06_skip_run', true);
evalin('base', 'W06_setup');
assignin('base', 'animate', 1);
mdl = evalin('base', 'mdl');

bdclose('all');
load_system(mdl);

in = Simulink.SimulationInput(mdl);
if ~isempty(tStop)
    in = in.setModelParameter('StopTime', num2str(tStop));
end

if vrx
    TOP = '/wamv/sensors/position/ground_truth_odometry';
    if ~any(strcmp(ros2('topic','list'), TOP))
        error('W06_anim_capture:novrx', ...
              ['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가 (W06_vrx_lite/run_vrx_bow.sh lite)\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가'], TOP);
    end

    %  스폰 위치를 직접 읽어 원점으로 쓴다. 스폰 좌표가 설치마다 다르다
    %  (같은 2.4.0-2 인데 ENU y 가 162 인 컴퓨터와 200 인 컴퓨터가 있다,
    %  2026-09-18). 고정값을 쓰면 접안 목표가 통째로 밀린다
    [rtf, x0_n, y0_n] = measure_spawn(TOP, 20);
    assignin('base', 'origin_north', x0_n);
    assignin('base', 'origin_east',  y0_n);
    fprintf('  스폰 (N, E) = (%.2f, %.2f) m · RTF %.3f\n', x0_n, y0_n, rtf);
    if isempty(pacing), pacing = rtf; end

    %  페이싱은 **실측 RTF** 그대로. 더 높이면 모델과 시뮬레이터가 CPU 를 다퉈
    %  오히려 느려진다
    in = in.setModelParameter('EnablePacing','on', 'PacingRate', num2str(pacing));
else
    if isempty(pacing), pacing = 0; end
end

wall = tic;
sim(in);
wall = toc(wall);

%  추진기 플러그인은 **마지막 값을 유지**한다. 시뮬레이션이 끝나도 배가 계속
%  간다 — 0 을 보내고 끝내지 않으면 다음 실험이 달리는 배 위에서 시작한다
if vrx, stop_thrusters(); end

f = W06_animate();                          % gcf 가 아니라 그리는 함수가 준 핸들
if isempty(f) || ~isvalid(f)
    error('W06_anim_capture:nofig', ...
          '실시간 화면이 열리지 않았다. animate = 1 인지 확인할 것.');
end
figure(f); drawnow;

file = fullfile(img, ['W06_anim_' which '.png']);
exportgraphics(f, file, 'Resolution', 150);   % 1340 px * 150/96 = 2094 px

B = @(v) evalin('base', v);
info = struct( ...
    'name',   which, ...
    'model',  mdl, ...
    'file',   file, ...
    'stage',  stage, ...
    'wall',   wall, ...
    'pacing', pacing*double(vrx), ...
    'vrx',    vrx, ...
    'dock',   [B('dock_north'), B('dock_east'), B('dock_deg')], ...
    'L_app',  B('L_app'), 'R_dock', B('R_dock'), 'R_stop', B('R_stop'), ...
    'Kp_x',   B('Kp_x'),  'u_max',  B('u_max'),  'v_max',  B('v_max'), ...
    'Kp_u',   B('Kp_u'),  'Ki_u',   B('Ki_u'),   'Kb',     B('Kb'), ...
    'Kp_psi', B('Kp_psi'), 'Kd_psi', B('Kd_psi'), ...
    'F_max',  B('F_max'), 'F_bow_max', B('F_bow_max'));

fprintf('  [캡처] %-6s %-12s %5.1f s 벽시계 -> %s\n', which, mdl, wall, file);
close_system(mdl, 0);
end

% ---- 스폰 위치와 RTF 를 한 번에 잰다 (W06_6_vrx_run 과 같은 방식) ----------
function [RTF, x0_n, y0_n] = measure_spawn(topic, sec)
n = ros2node(sprintf('/w06_anim_probe_%d', randi(9999)));
c = onCleanup(@() clear('n'));
s = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);   w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
y0_n = m0.pose.pose.position.x;   x0_n = m0.pose.pose.position.y;   % ENU -> NED
pause(sec);
m1 = receive(s, 15);   dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end

% ---- 추진기 **셋** 에 0 N 을 몇 번 보낸다 — 6주차는 선수추진기가 하나 더 있다 ----
function stop_thrusters()
try
    n  = ros2node(sprintf('/w06_stop_%d', randi(9999)));
    pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
    pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
    pb = ros2publisher(n, '/wamv/thrusters/bow/thrust',   'std_msgs/Float64');
    msg = ros2message(pl);   msg.data = 0;
    for k = 1:5
        send(pl, msg);   send(pr, msg);   send(pb, msg);   pause(0.1);
    end
    clear pl pr pb n
    fprintf('  추력 0 송신 완료 (좌·우·선수)\n');
catch e
    warning('W06_anim_capture:stop', '추력 0 송신 실패: %s', e.message);
end
end
