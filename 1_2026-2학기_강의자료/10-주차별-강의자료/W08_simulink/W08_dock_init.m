function W08_dock_init(mdl)
% W08_DOCK_INIT  실습 E 모델의 InitFcn — 설정을 깔고 실시간 창을 **미리** 짓는다.
%
%   두 모델(W08_2_dock · W08_3_dock_vrx)의 InitFcn 이 이것을 부른다.
%   학생이 .slx 를 두 번 눌러 열고 Run 만 눌러도 자기 설정으로 돌게 하는 장치다.
%
%   하는 일은 셋뿐이다
%     1. 베이스 워크스페이스에 설정이 없으면 W08_dock_setup 을 부른다 (실행은 막는다)
%     2. VRX 모델이면 페이싱·토픽 주의를 한 번 적어 준다
%     3. animate = 1 이면 실시간 창을 **시계가 돌기 전에** 짓는다
%
%   왜 창을 여기서 짓는가 — 6주차 2026-10-28 VRX 실측
%     창 만들기(축 넷 · 범례 · 부두 패치)를 **첫 모델 스텝 안에서** 하면 그 동안
%     모델은 멈춰 있고 Gazebo 는 마지막 추력 명령을 그대로 지킨다. 모델 시간
%     0.4 s 사이에 배가 9.4 m 를 갔다 (k = 1.52, 13.1 m 이격). 창은 미리 짓는다.
%
%   왜 appdata 만으로 "이미 깔았다" 를 판단하지 않는가
%     6주차에서 밟은 지뢰다. 베이스 워크스페이스를 clear 하면 appdata 표시는
%     남고 변수는 없다. 그 상태에서 Run 을 누르면 설정을 다시 깔지 않은 채
%     모델이 돌아 Ts_ctrl 을 찾지 못하고 멈춘다. **변수로** 확인한다.

mdl = char(mdl);
is_vrx = contains(mdl, 'vrx');

%  StopFcn 이 "직접 Run 인가 sim() 인가" 를 베이스의 out 으로 가린다.
%  앞 실행의 out 이 남아 있으면 sim() 으로 돌려도 StopFcn 이 그림을 또 그린다
evalin('base', 'clear out');

cfg_laid = evalin('base', ...
    ['exist(''dock_q'',''var'') && exist(''animate'',''var'')' ...
     ' && exist(''Ts_ctrl'',''var'')']) == 1;

if ~cfg_laid
    setappdata(0, 'W08_dock_skip_run', true);   % 설정만. setup 이 sim 을 부르면 안 된다
    evalin('base', 'W08_dock_setup');
end

if is_vrx
    fprintf(['[W08_3_dock_vrx] 확인할 것\n' ...
             '  (1) VRX 가 떠 있는가 — ros2 topic list 에 /wamv/thrusters/bow/thrust 가 보이는가\n' ...
             '  (2) 선수추진기 토픽이 없으면 WSL 에서  bash W06_vrx_lite/make_wamv_bow.sh\n' ...
             '  (3) 페이싱 비율을 **실측 RTF 그대로** 둘 것 — 더 높이면 오히려 느려진다\n']);
end

if evalin('base', 'animate')
    W08_dock_animate('init');
end
end
