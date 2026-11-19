function TP_manual_init(mdl)
%TP_MANUAL_INIT  수동 조종 모델의 InitFcn — Run 을 누르면 블록 파라미터를 읽기 전에 먼저 돈다
%
%   손으로 할 일을 없애는 것이 목적이다. 모델을 열고 Run 만 누르면 된다.
%
%   하는 일
%     1. 경로        이 폴더와 TP_haeyang (미션 지점표) 을 경로에 넣는다
%     2. 설정        TP_manual_setup 을 돌려 값을 베이스 워크스페이스에 깐다
%     3. VRX 준비    (`*_vrx` 모델만) Domain ID · 토픽 확인 · RTF 측정 → 페이싱
%     4. GCS         위성지도 창을 **첫 스텝 전에** 세운다
%
%   GCS 를 미리 세우는 까닭
%     첫 스텝 안에서 창을 만들면 지도 타일을 받는 몇 초 동안 모델이 멎는다. 그 사이
%     가제보는 마지막 추력 명령을 그대로 쥐고 있어 배는 계속 간다 (6주차 4단 실측 9.4 m).
%
%   VRX 준비의 네 가지는 틀려도 **오류 메시지가 없다** — 그래서 여기서 먼저 막는다
%     Domain ID   Simulink 블록은 ROS 네트워크 **프로필**, ros2 함수는 **환경변수**를 본다
%     토픽        선수추진기(bow) · GPS · 오도메트리 토픽이 보이는가
%     RTF         가제보가 실시간의 몇 배로 도는가. 그 값을 그대로 페이싱 비율로 쓴다

mdl  = char(mdl);
here = fileparts(get_param(mdl, 'FileName'));
if isempty(here), here = fileparts(mfilename('fullpath')); end
addpath(here);
hy = fullfile(fileparts(here), 'TP_haeyang');
if isfolder(hy), addpath(hy); end

%% 2. 설정 — 확인 스크립트가 제 값을 깔아 두었으면 건드리지 않는다
if ~isequal(getappdata(0, 'TP_skip_setup'), true)
    evalin('base', 'TP_manual_setup');
end
evalin('base', 'clear out');
setappdata(0, 'TP_keys', zeros(1, 6));
%  정지 버튼이 눌린 채로 끝났으면 풀어 놓고 시작한다 (눌린 채면 아무 키도 안 먹는다)
try, set_param([mdl '/ManualPad/c_stop'], 'Value', '0'); catch, end
if isappdata(0, 'TP_state'), rmappdata(0, 'TP_state'); end
setappdata(0, 'TP_gcs_model', mdl);
B = @(v) evalin('base', v);

%% 3. VRX 준비
if endsWith(mdl, '_vrx')
    dom = B('ros_domain_id');
    try
        prof = getpref('ROS_Toolbox', 'ROS_NetworkAddress_Profiles');
        dom_prof = double(prof{1}.DomainID);
    catch
        dom_prof = [];                       % 프로필 없음 — 새로 설치한 MATLAB 의 기본 상태
    end
    if isempty(dom_prof)
        setenv('ROS_DOMAIN_ID', dom);        % 프로필이 없으면 Simulink 도 환경변수를 따른다
    elseif dom_prof ~= str2double(dom)
        error('TP_manual:domain', ...
              ['Simulink ROS 프로필의 Domain ID 는 %d, TP_manual_setup 의 ros_domain_id 는 %s 이다.\n' ...
               '  Simulink 툴스트립 시뮬레이션 -> ROS 네트워크 에서 Domain ID 를 %s 로 바꾸고 다시 Run'], ...
              dom_prof, dom, dom);
    else
        setenv('ROS_DOMAIN_ID', dom);
    end

    fprintf('\n[%s] VRX 준비 1/2 — ROS_DOMAIN_ID = %s, 토픽 확인\n', mdl, getenv('ROS_DOMAIN_ID'));
    tl   = ros2('topic', 'list');
    need = {'/wamv/thrusters/bow/thrust', '/wamv/sensors/gps/gps/fix', ...
            '/wamv/sensors/position/ground_truth_odometry'};
    miss = need(~ismember(need, tl));
    if ~isempty(miss)
        error('TP_manual:notopic', ...
              ['토픽이 보이지 않는다 : %s\n' ...
               '  - WSL 에서 가제보를 띄웠는가  (bash run_haeyang.sh lite gui)\n' ...
               '  - 띄운 터미널의 ROS_DOMAIN_ID 가 %s 인가'], strjoin(miss, ', '), dom);
    end
    fprintf('     OK — 토픽 %d 개 (선수추진기 · GPS · 오도메트리 있음)\n', numel(tl));

    fprintf('[%s] VRX 준비 2/2 — RTF 측정 (10 초, 그대로 기다릴 것)\n', mdl);
    nd = ros2node(sprintf('/tp_rtf_probe_%d', randi(9999)));
    sb = ros2subscriber(nd, need{3}, 'nav_msgs/Odometry');
    m0 = receive(sb, 15);   w = tic;
    t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
    pause(10);
    m1 = receive(sb, 15);   tw = toc(w);
    t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
    clear sb nd
    RTF = (t1 - t0)/tw;
    assignin('base', 'TP_RTF', RTF);
    set_param(mdl, 'EnablePacing', 'on', 'PacingRate', sprintf('%.3f', min(max(RTF, 0.1), 1.0)));
    %  실시간 화면이 모델을 붙잡지 않게 다시 그리는 간격을 넓힌다 (6주차 실측 — 0.25 s 는 못 따라감)
    assignin('base', 'animate_every', max(B('animate_every'), 0.5));
    fprintf('     배 위치 (북 %.2f, 동 %.2f) m,  RTF = %.3f — 이 값을 페이싱 비율로 둔다\n', ...
            m0.pose.pose.position.y, m0.pose.pose.position.x, RTF);
    fprintf('     배가 안 움직이면 WSL 에서 :  export GZ_PARTITION=hy1; gz topic -t /vrx/release -m gz.msgs.Empty -p ""\n');
end

%% 4. GCS 창
setappdata(0, 'TP_gcs_on', logical(B('animate')));
if B('animate')
    TP_gcs('init', mdl);
    fprintf('[%s] GCS 준비 완료 — 창을 한 번 클릭한 뒤 W S A D Q E 로 조종한다\n', mdl);
end
end
