function RTF = W06_vrx_prep(twin)
% W06_VRX_PREP  VRX 쌍둥이를 Gazebo 에 붙이기 전 준비 — 쌍둥이 모델의 InitFcn 이 부른다
%
%   Simulink 에서 `*_vrx` 모델을 직접 Run 하면 이것이 먼저 돈다. 손으로 할 일이 없다.
%
%   네 가지를 맞춘다. **넷 다 틀려도 오류 메시지가 없다** — 결과만 조용히 어긋난다
%     1. Domain ID   Simulink 블록은 ROS 네트워크 **프로필**, ros2* 함수는 **환경변수**를 본다
%     2. 토픽        ground truth 와 선수추진기 토픽이 보이는가
%     3. 스폰 위치   첫 샘플로 재서 origin_north · origin_east 로 쓴다 (설치마다 다르다)
%     4. 페이싱      RTF 를 20 초 재서 그 값을 페이싱 비율로 (실측 그대로. 더 높이면 느려진다)
%
%   실행 전에 WSL 에서 **선수추진기를 단** VRX 가 떠 있어야 한다 (실험마다 새로)
%     cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W06_vrx_lite
%     bash ../W03_vrx_lite/stop_vrx.sh && bash run_vrx_bow.sh
%
%   끝나면 반드시 정리한다 — 남은 gz sim 이 수십 GB 까지 자란다
%     ros2 run vrx_llm_dock cleanup

twin  = char(twin);
[st, is_vrx] = W06_stage_of(twin);
assert(is_vrx, 'W06_vrx_prep 은 *_vrx 모델에만 쓴다 (%s)', twin);
TOPIC = '/wamv/sensors/position/ground_truth_odometry';
B = @(v) evalin('base', v);

%% 1. Domain ID — 프로필과 환경변수가 같아야 한다
dom = B('ros_domain_id');
try
    prof = getpref('ROS_Toolbox', 'ROS_NetworkAddress_Profiles');
    dom_prof = double(prof{1}.DomainID);
catch
    dom_prof = [];                          % 프로필 없음 (새로 설치한 MATLAB 의 기본 상태)
end
if isempty(dom_prof)
    setenv('ROS_DOMAIN_ID', dom);           % 프로필이 없으면 Simulink 도 환경변수를 따른다
elseif dom_prof ~= str2double(dom)
    error('W06_vrx_prep:domain', ...
          ['Simulink ROS 프로필의 Domain ID 는 %d, W06_setup 의 ros_domain_id 는 %s 이다.\n' ...
           '  Simulink 툴스트립 시뮬레이션 -> ROS 네트워크 에서 Domain ID 를 %s 로 바꾸고 다시 Run'], ...
          dom_prof, dom, dom);
end

%% 2. 토픽 확인
fprintf('  VRX 준비 1/3 — ROS_DOMAIN_ID = %s, 토픽 확인\n', getenv('ROS_DOMAIN_ID'));
tl = ros2('topic', 'list');
if ~any(strcmp(tl, TOPIC))
    error('W06_vrx_prep:notopic', ...
          ['%s 가 보이지 않는다.\n  - VRX 가 떠 있는가 (bash run_vrx_bow.sh)\n' ...
           '  - WSL 의 echo $ROS_DOMAIN_ID 가 %s 인가'], TOPIC, getenv('ROS_DOMAIN_ID'));
end
if ~any(strcmp(tl, '/wamv/thrusters/bow/thrust'))
    error('W06_vrx_prep:nobow', ...
          ['/wamv/thrusters/bow/thrust 가 없다 — 선수추진기 없는 WAM-V 로 띄웠다.\n' ...
           '  5주차의 run_vrx.sh 가 아니라 W06_vrx_lite/run_vrx_bow.sh 로 띄울 것']);
end
fprintf('     OK — 토픽 %d 개 (bow 토픽 있음)\n', numel(tl));

%% 3. 스폰 위치와 RTF
fprintf('  VRX 준비 2/3 — 스폰 위치와 RTF 측정 (20 초, 그대로 기다릴 것)\n');
nd = ros2node(sprintf('/w06_rtf_probe_%d', randi(9999)));
sb = ros2subscriber(nd, TOPIC, 'nav_msgs/Odometry');
m0 = receive(sb, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
pause(20);
m1 = receive(sb, 15);  tw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / tw;
clear sb nd
on = m0.pose.pose.position.y;   oe = m0.pose.pose.position.x;   % ENU -> NED
assignin('base', 'origin_north', on);
assignin('base', 'origin_east',  oe);
assignin('base', 'W06_RTF', RTF);
fprintf('     스폰 위치 (N, E) = (%.2f, %.2f) m — 이 점을 원점으로 쓴다\n', on, oe);
fprintf('     RTF = %.3f — 페이싱 비율을 이 값으로 둔다\n', RTF);

%% 4. 실행 길이 · 페이싱 · 실시간 화면
%  1~3단에는 정지 게이트가 없어 T_run(300 s) 을 끝까지 돈다. 오프라인으로 40 s 안쪽에
%  목표에 서므로 Gazebo 에서는 120 s 로 줄인다 (오프라인 대조도 같은 길이로 맞춘다)
if st <= 3, assignin('base', 'T_run', 120); end
set_param(twin, 'EnablePacing', 'on', 'PacingRate', num2str(RTF));

%  실시간 화면은 켜 둔다 — 주행을 눈으로 보는 것이 이 모델을 직접 Run 하는 목적이다.
%  다만 다시 그리는 간격을 넓힌다. 0.25 s 로 두면 Simulink 가 VRX 를 못 따라간다
%  (2026-10-16). 따라갔는지는 끝에 나오는 동기 점검 k 로 확인한다
if B('animate')
    assignin('base', 'animate_every', max(B('animate_every'), 0.5));
end
setappdata(0, 'W06_cfg_for', twin);         % 이 설정은 쌍둥이용으로 손댄 것이다
if B('animate'), anim = '켜짐'; else, anim = '꺼짐'; end
fprintf('  VRX 준비 3/3 — 페이싱 %.3f, 최대 %g 초, 실시간 화면 %s. 실행 시작\n', ...
        RTF, B('T_run'), anim);
end
