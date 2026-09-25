function info = W09_anim_capture(which, varargin)
% W09_ANIM_CAPTURE  실시간 화면(W09_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W09_anim_capture('offline')     img/W09_anim_offline.png   (VRX 불필요)
%   W09_anim_capture('vrx')         img/W09_anim_vrx.png       (VRX 필요)
%
%   이름있는 인자
%     'Stop'   몇 초(시뮬레이션 시각)에서 멈출 것인가. 기본값 W09_setup 의 T_end
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(추력 · 시간 · 주기)도 남지 않는다.
%     이 함수는 조건을 함께 돌려주고, 그것이 문서 표의 근거가 된다.
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (블록도 · 실시간 화면). gcf 로 저장하면
%     마지막으로 만진 창이 저장된다. W09_animate 가 자기 창 핸들을 돌려주므로
%     **그 핸들로** 저장한다 (스킬 규칙 17).
%
%   > [주의] 'vrx' 로 잰 수신 주기는 2-8-1 의 표와 다르다
%     이 캡처는 화면을 **켜고** 도는 실행이다. 그리는 일이 벽시계를 먹으므로
%     같은 PC 에서도 Hz 가 내려간다. 표에 싣는 값은 화면을 끄고 재는
%     W09_rates_run 의 것이다. 이 함수는 화면 그림만 남긴다.

p = inputParser;
p.addParameter('Stop', []);
p.parse(varargin{:});
tStop = p.Results.Stop;

here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here,'..','..','_tools'));
img = fullfile(here,'img');
if ~isfolder(img), mkdir(img); end

switch which
    case 'offline', m = 'W09_0_offline';       vrx = false;
    case 'vrx',     m = 'W09_1_sensor_rates';  vrx = true;
    otherwise, error('W09_anim_capture:which', '모르는 이름 ''%s'' (offline · vrx).', which);
end

evalin('base','W09_setup');                 % 설정을 언제나 기본값에서 출발시킨다
assignin('base','animate', 1);
if isempty(tStop), tStop = evalin('base','T_end'); end

load_system(m);
set_param(m, 'StopTime', num2str(tStop));

if vrx
    want = {evalin('base','topic_gps'), evalin('base','topic_imu')};
    tl = ros2('topic','list');
    for k = 1:numel(want)
        if ~any(strcmp(tl, want{k}))
            error('W09_anim_capture:novrx', ...
                  ['%s 가 보이지 않는다.\n' ...
                   '  - VRX 가 떠 있는가 (W03_vrx_lite/run_vrx.sh)\n' ...
                   '  - ROS_DOMAIN_ID 가 양쪽 같은가 (W09_setup 의 ros_domain_id)'], want{k});
        end
    end
end

wall = tic;
out  = sim(m);
wall = toc(wall);

f = W09_animate();                          % gcf 가 아니라 그리는 함수가 준 핸들
if isempty(f) || ~isvalid(f)
    error('W09_anim_capture:nofig', ...
          '실시간 화면이 열리지 않았다. animate = 1 인지, GPS 값이 오는지 확인할 것.');
end
figure(f); drawnow;

file = fullfile(img, ['W09_anim_' which '.png']);
exportgraphics(f, file, 'Resolution', 150);   % 1240 px * 150/96 = 1938 px (2000 이하)

B = @(v) evalin('base', v);
info = struct( ...
    'name',   which, ...
    'model',  m, ...
    'file',   file, ...
    'stop',   tStop, ...
    'wall',   wall, ...
    'vrx',    vrx, ...
    'hz_gps', out.log_hz_gps.Data(end), ...
    'hz_imu', out.log_hz_imu.Data(end), ...
    'animate_every', B('animate_every'), ...
    'Ts',     B('Ts'));

fprintf(['  [캡처] %-8s %-20s %5.1f s 시뮬 / %5.1f s 벽시계\n' ...
         '         GPS %.2f Hz, IMU %.2f Hz (화면 켠 채)  ->  %s\n'], ...
        which, m, info.stop, wall, info.hz_gps, info.hz_imu, file);
close_system(m, 0);
end
