function S = W09_vrx_run(T_end, show)
% W09_VRX_RUN  VRX(Gazebo) 와 연동해 W09_1_vrx 를 돌리고 회피 결과를 그린다.
%
%   >> W09_setup
%   >> W09_vrx_run                 % 200초 — 장애물 둘을 피하고 완주한다
%   >> W09_vrx_run(90)             % 90초 — 첫 벽만 보고 끊는다
%   >> W09_vrx_run(200, 1)         % 시뮬링크 화면을 켠다 (권하지 않는다, 아래)
%
%   이 스크립트가 대신 해 주는 것
%     1. **네 가지 토픽**이 다 보이는지 확인 (하나라도 없으면 여기서 멈춘다)
%     2. RTF 를 20초 동안 실제로 측정해 페이싱 비율로 쓴다
%     3. 실행
%     4. 결과 그림 (W09_plot) + 동기 점검 k + 회피가 실제로 일어났는지 판정
%
%   5주차와 다른 것 — **오프라인 대조가 없다**
%     장애물은 Gazebo 월드에만 있다. 오프라인 운동모델에는 피할 것이 없으므로
%     대조할 상대가 없다. 그래서 이 주차의 판정은 "오프라인과 얼마나 같은가"
%     가 아니라 **최소 여유 몇 m 로 지나갔는가** 다 (W09_plot 참조).
%
%   돌리기 전에 WSL 에서 띄워야 하는 것 — **터미널 둘**이다
%     터미널 1 (시뮬레이터, 라이다 달린 선수추진기 모델)
%       cd ~/Capstone-Design && git pull
%       cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W09_vrx_lite
%       bash ../W03_vrx_lite/stop_vrx.sh
%       bash run_vrx_ca.sh
%     터미널 2 (회피 노드 + 극좌표 그림)
%       bash run_ca_nodes.sh
%     끝낼 때 (**반드시**)  ros2 run vrx_llm_dock cleanup
%       남은 gz sim 이 62 GB 까지 자라 메모리를 다 먹는다
%
%   시뮬링크 화면(show)을 기본으로 끄는 까닭
%     5주차 실측에서 화면을 그리는 동안 Simulink 가 VRX 를 못 따라가 같은 모델
%     1 초에 배가 1.7 배 더 갔다 (동기 점검 k = 1.69). 이 주차는 그 위에 회피
%     판단까지 얹히므로 더 민감하다. 도는 모습은 **파이썬 극좌표 그림**으로
%     본다 (ca_viz.py) — 그쪽이 이 주차에 보여 주려는 그림이다.

if nargin < 1 || isempty(T_end), T_end = 200; end
if nargin < 2 || isempty(show),  show  = 0;   end

m    = 'W09_1_vrx';
TOP  = '/wamv/sensors/position/ground_truth_odometry';
SCAN = '/wamv/sensors/lidars/lidar_wamv_sensor/scan';
CMD  = '/vfh/command';
FLAG = '/vfh/oa_flag';

%% 0. ROS 2 도메인 맞추기 ----------------------------------------------
% ---------------------------------------------------------------------
%  Simulink 블록은 'ROS 네트워크 프로필'의 Domain ID 를 쓰고, MATLAB 의 ros2*
%  함수는 환경변수 ROS_DOMAIN_ID(기본 0)를 쓴다. 둘이 다르면 토픽이 보이지
%  않는다. 프로필 값으로 환경변수를 맞춘다 (5주차와 같다)
% ---------------------------------------------------------------------
try
    prof = getpref('ROS_Toolbox','ROS_NetworkAddress_Profiles');
    if ~isempty(prof) && isfield(prof{1},'DomainID')
        setenv('ROS_DOMAIN_ID', num2str(double(prof{1}.DomainID)));
    end
catch
end
if isempty(getenv('ROS_DOMAIN_ID')), setenv('ROS_DOMAIN_ID','0'); end
fprintf('0) ROS_DOMAIN_ID = %s\n', getenv('ROS_DOMAIN_ID'));

%% 1. 토픽 넷 확인 -----------------------------------------------------
%  이 주차는 확인할 것이 5주차보다 둘 더 많다. 둘을 안 보고 돌리면 모델은
%  멈추지 않고 **LOS 만으로** 돌아 벽에 그대로 박는다. 그 모습이 꼭
%  "시뮬링크 쪽이 고장난 것" 처럼 보이므로 여기서 미리 걸러 낸다
fprintf('1) 토픽 확인\n');
tl = ros2('topic','list');
chk = { TOP,  '시뮬레이터(참값 오도메트리)', ...
        '터미널 1 에서 run_vrx_ca.sh 를 띄웠는가 · ground_truth_enabled 가 true 인가'
        SCAN, '라이다 스캔', ...
        '라이다 단 urdf 로 띄웠는가 (run_vrx_ca.sh 가 그 일을 한다)'
        CMD,  '파이썬 회피 명령', ...
        '터미널 2 에서 run_ca_nodes.sh 를 띄웠는가'
        FLAG, '파이썬 회피 깃발', ...
        '터미널 2 에서 run_ca_nodes.sh 를 띄웠는가' };
miss = false;
for i = 1:size(chk,1)
    if any(strcmp(tl, chk{i,1}))
        fprintf('   OK   %-52s %s\n', chk{i,1}, chk{i,2});
    else
        fprintf('   없음 %-52s %s\n', chk{i,1}, chk{i,2});
        fprintf('        -> %s\n', chk{i,3});
        miss = true;
    end
end
if miss
    error('W09_vrx_run:topics', ...
          ['토픽이 모자란다 (위 "없음" 줄). 띄우고 다시 돌린다.\n' ...
           '  터미널 1 :  bash run_vrx_ca.sh\n' ...
           '  터미널 2 :  bash run_ca_nodes.sh']);
end
fprintf('   넷 다 보인다 — 토픽 %d개\n', numel(tl));

%% 2. RTF 측정과 스폰 위치 ----------------------------------------------
fprintf('2) RTF 측정 (20초)\n');
[RTF, x0_n, y0_n] = measureRTF(TOP, 20);
%  경로 원점은 **월드에 고정**한다 (W09_setup 의 path_north0 · path_east0).
%  배가 어디서 뜨든 원점은 그대로다 — 9주차는 장애물표(W09_setup 1절)가 이 원점
%  기준으로 만들어져 있어 원점을 옮기면 그림의 장애물이 통째로 밀린다.
%  모델의 GoalPublisher 가 origin_* 를 상수로 읽으므로 여기서 맞춰 넣는다
pn0 = evalin('base','path_north0');   pe0 = evalin('base','path_east0');
assignin('base','origin_north', pn0);
assignin('base','origin_east',  pe0);
start_n = x0_n - pn0;   start_e = y0_n - pe0;
fprintf('   스폰 위치 (x, y) = (%.1f, %.1f) m\n', x0_n, y0_n);
fprintf('   경로 원점 (x, y) = (%.1f, %.1f) m — 배는 경로 좌표 (%.1f, %.1f) 에서 출발\n', ...
        pn0, pe0, start_n, start_e);
if hypot(start_n, start_e) > 2
    warning(['스폰이 경로 원점에서 %.1f m 떨어져 있다. 장애물표가 이 원점 기준이므로 ' ...
             '그림의 장애물 자리가 그만큼 틀어진다. W09_setup 의 path_north0 · ' ...
             'path_east0 을 스폰 값으로 맞추고 장애물표를 다시 만든다 (강의노트 2-3절)'], ...
            hypot(start_n, start_e));
end
fprintf('   RTF = %.3f  ->  페이싱 비율을 이 값으로 둔다\n', RTF);
if RTF < 0.25
    warning(['RTF 가 %.2f 다. 라이다를 단 탓이면 포인트 수를 줄인 판으로 띄운다 ' ...
             '(run_vrx_ca.sh 의 LIDAR 인자: ultralite · lite · full)'], RTF);
end

%% 3. 실행 -------------------------------------------------------------
fprintf('3) %s 실행 (%d초)\n', m, T_end);
if show
    fprintf('   [주의] 시뮬링크 화면을 켰다 — 동기 점검 k 가 1 을 넘기면 결과를 쓰지 않는다\n');
end
load_system(m);
set_param(m, 'EnablePacing','on', 'PacingRate', num2str(RTF), ...
             'StopTime', num2str(T_end));
out = sim(m);
assignin('base','out',out);   % 그림이 실패해도 주행 데이터는 남긴다

%% 4. 결과 ------------------------------------------------------------
fprintf('4) 결과 그림\n');
S        = W09_plot(out, sprintf('VRX / 회피 (%d초)', T_end));
S.RTF    = RTF;
S.k_sync = syncCheck(out);
saveFig(S.fig, 'W09_1_vrx_result.png');   % gcf 는 추진기 창이다 — 궤적 창을 저장한다

%% 5. 이음새가 일했는가 -------------------------------------------------
%  그림만 보면 "안 피했다" 와 "피할 것이 없었다" 가 같아 보인다. 숫자로 가른다
fprintf('5) 이음새 판정\n');
if S.oa_n == 0
    fprintf('   회피가 한 번도 켜지지 않았다. 볼 곳 셋\n');
    fprintf('     - 라이다가 장애물을 보는가      bash probe_lidar.sh\n');
    fprintf('     - 목표점이 파이썬에 닿았는가    ros2 topic echo --once /usv/state/goal_enu\n');
    fprintf('     - 회피 노드가 살아 있는가       tail /tmp/w09_ca_nodes.log\n');
elseif S.clear_min < 3
    fprintf('   회피는 켜졌는데 여유가 %.1f m 로 좁다. oa 가 늦게 켜진 것이다 —\n', S.clear_min);
    fprintf('   파이썬 쪽 안전거리(lidar.ignore_radius_m · 회피 반경)를 보고, 속도 u_ref 를 낮춰 본다\n');
else
    fprintf('   회피 %d회 켜짐, 최소 여유 %.1f m — 이음새가 제대로 일했다\n', ...
            S.oa_n, S.clear_min);
end
end

% =====================================================================
function k = syncCheck(out)
% Simulink 가 VRX 를 따라갔는가 — 로그만으로 판정한다 (5주차와 같은 잣대)
%   VRX 가 준 속도 u 는 "시뮬레이터 1 초에 몇 m" 다. Simulink 가 제때 돌았다면
%   모델 시각으로 적분한 거리와 실제로 지나간 거리가 같다 (k = 1).
%   늦어지면 같은 모델 1 초 동안 배가 더 가므로 k > 1 이 된다
t      = out.log_x_n.Time;
s_path = sum(hypot(diff(out.log_x_n.Data), diff(out.log_y_n.Data)));
s_int  = trapz(t, abs(out.log_u.Data));
k      = s_path / max(s_int, eps);
fprintf('   동기 점검 k = 지나간 거리 %.1f m / 속도 적분 %.1f m = %.3f', s_path, s_int, k);
if k > 1.08
    fprintf('  <- Simulink 가 VRX 를 못 따라갔다\n');
    fprintf('      이 결과는 쓰지 말 것. 화면을 끄고(show = 0) VRX 를 다시 띄워 재실행\n');
elseif k < 0.9
    %  명령은 나가는데 배가 그만큼 가지 않음 = Gazebo 가 멈춰 있었던 것
    fprintf('  <- 명령만큼 배가 가지 않았다 (Gazebo 가 멈춤)\n');
    fprintf('      ros2 daemon stop && ros2 daemon start 뒤 VRX 를 다시 띄워 재실행\n');
else
    fprintf('  (0.9 ~ 1.08 — 동기 정상)\n');
end
end

function [RTF, x0_n, y0_n] = measureRTF(topic, sec)
n  = ros2node(sprintf('/rtf_probe_%d', randi(9999)));
c  = onCleanup(@() clear('n'));
s  = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);   w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
y0_n = m0.pose.pose.position.x;   x0_n = m0.pose.pose.position.y;    % ENU -> NED
pause(sec);
m1 = receive(s, 15);   dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end

function saveFig(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, name), 'Resolution', 130);
fprintf('   그림 저장: img/%s\n', name);
end
