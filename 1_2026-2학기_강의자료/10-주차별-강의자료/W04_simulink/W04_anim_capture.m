function info = W04_anim_capture(which, varargin)
% W04_ANIM_CAPTURE  실시간 화면(W04_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W04_anim_capture('speed_offline')      img/W04_anim_speed_offline.png
%   W04_anim_capture('heading_offline')    img/W04_anim_heading_offline.png
%   W04_anim_capture('speed_vrx')          img/W04_anim_speed_vrx.png     (VRX 필요)
%   W04_anim_capture('heading_vrx')        img/W04_anim_heading_vrx.png   (VRX 필요)
%   W04_anim_capture('all_offline')        오프라인 두 장
%
%   이름있는 인자
%     'Pacing'  VRX 에서 쓸 페이싱 비율. **실측 RTF 를 그대로 넣는다.**
%               더 높이면 모델과 시뮬레이터가 CPU 를 다퉈 오히려 느려진다
%               (3주차 2-3 · CLAUDE.md §11). 기본값 0.8
%     'Stop'    VRX 실행을 몇 초(시뮬레이션 시각)에서 멈출 것인가. 기본값 60
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(게인·시간·RTF)도 남지 않는다.
%     이 함수는 조건을 함께 돌려주고, 그것이 W04_MEASURED.md 의 표가 된다.
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (Scope · 블록도 · 실시간 화면). gcf 로
%     저장하면 마지막으로 만진 창이 저장된다. W04_animate 가 자기 창 핸들을
%     돌려주므로 **그 핸들로** 저장한다 (스킬 규칙 17).

p = inputParser;
p.addParameter('Pacing', 0.8);
p.addParameter('Stop',   60);
p.parse(varargin{:});
pacing = p.Results.Pacing;
tStop  = p.Results.Stop;

here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here,'..','..','_tools'));
img = fullfile(here,'img');
if ~isfolder(img), mkdir(img); end

if strcmp(which,'all_offline')
    info = [W04_anim_capture('heading_offline'); W04_anim_capture('speed_offline')];
    return
end

switch which
    case 'heading_offline', m = 'W04_3_heading_offline';     vrx = false;
    case 'speed_offline',   m = 'W04_4_inner_loop_offline';  vrx = false;
    case 'heading_vrx',     m = 'W04_3_heading';             vrx = true;
    case 'speed_vrx',       m = 'W04_4_inner_loop';          vrx = true;
    otherwise, error('W04_anim_capture:which', '모르는 이름 ''%s''.', which);
end

evalin('base','W04_setup');                 % 게인을 언제나 기본값에서 출발시킨다
assignin('base','animate',1);
bdclose('all');
load_system(m);

if vrx
    TOP = '/wamv/sensors/position/ground_truth_odometry';
    if ~any(strcmp(ros2('topic','list'), TOP))
        error('W04_anim_capture:novrx', ...
              ['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가 (W03_vrx_lite/run_vrx.sh lite)\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가 (W04_setup 의 ros_domain_id)'], TOP);
    end
    %  페이싱은 **실측 RTF** 그대로. 더 높이면 모델과 시뮬레이터가 CPU 를 다퉈
    %  오히려 느려진다 (CLAUDE.md §11)
    set_param(m, 'EnablePacing','on', 'PacingRate', num2str(pacing), ...
                 'StopTime', num2str(tStop));
end

wall = tic;
sim(m);
wall = toc(wall);

%  추진기 플러그인은 **마지막 값을 유지**한다. 시뮬레이션이 끝나도 배가 계속
%  간다 — 0 을 보내고 끝내지 않으면 다음 실험이 달리는 배 위에서 시작한다
if vrx, stop_thrusters(); end

f = W04_animate();                          % gcf 가 아니라 그리는 함수가 준 핸들
if isempty(f) || ~isvalid(f)
    error('W04_anim_capture:nofig', ...
          '실시간 화면이 열리지 않았다. animate = 1 인지 확인할 것.');
end
figure(f); drawnow;

file = fullfile(img, ['W04_anim_' which '.png']);
exportgraphics(f, file, 'Resolution', 150);   % 1240 px * 150/96 = 1938 px (2000 이하)

B = @(v) evalin('base', v);
info = struct( ...
    'name',    which, ...
    'model',   m, ...
    'file',    file, ...
    'stop',    str2double(get_param(m,'StopTime')), ...
    'wall',    wall, ...
    'pacing',  pacing*double(vrx), ...
    'vrx',     vrx, ...
    'Kp_psi',  B('Kp_psi'), 'Kd_psi', B('Kd_psi'), 'Ki_psi', B('Ki_psi'), ...
    'psi_ref_deg', B('psi_ref_deg'), ...
    'animate_every', B('animate_every'));

fprintf('  [캡처] %-16s %-26s %5.1f s 시뮬 / %5.1f s 벽시계 -> %s\n', ...
        which, m, info.stop, wall, file);
close_system(m, 0);
end

% ---- 좌·우 추진기에 0 N 을 몇 번 보낸다 (W03_vrx_run 과 같은 뒷정리) -------
function stop_thrusters()
try
    n  = ros2node(sprintf('/w04_stop_%d', randi(9999)));
    pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
    pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
    msg = ros2message(pl);  msg.data = 0;
    for k = 1:5, send(pl, msg);  send(pr, msg);  pause(0.1); end
    clear pl pr n
    fprintf('  추력 0 송신 완료\n');
catch e
    warning('W04_anim_capture:stop', '추력 0 송신 실패: %s', e.message);
end
end
