function info = W07_anim_capture(which, varargin)
% W07_ANIM_CAPTURE  실시간 화면(W07_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W07_anim_capture('offline')    img/W07_anim_offline.png
%   W07_anim_capture('vrx')        img/W07_anim_vrx.png     (VRX 기동 필요)
%
%   이름있는 인자
%     'Pacing'  VRX 에서 쓸 페이싱 비율. **실측 RTF 를 그대로 넣는다.**
%               더 높이면 모델과 시뮬레이터가 CPU 를 다퉈 오히려 느려진다
%               (3주차 2-3). 주지 않으면 여기서 20초 동안 잰다
%     'Stop'    몇 초(시뮬레이션 시각)에서 멈출 것인가.
%               기본값 330 (오프라인) · 420 (VRX).
%               **상태가 세 번 바뀐 뒤**의 화면이 남아야 한다 —
%               오프라인 기준 실행은 임무 종료가 314.4 s 이므로 330 이면 충분하고,
%               VRX 는 페이싱 탓에 벽시계로 더 걸리므로 420 을 둔다
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(게인·시간·RTF)도 남지 않는다.
%     이 함수는 조건을 함께 돌려준다.
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (성능 그림 · 추진기 그림 · 실시간 화면).
%     gcf 로 저장하면 마지막으로 만진 창이 저장된다. W07_animate 가 자기 창
%     핸들을 돌려주므로 **그 핸들로** 저장한다 (스킬 규칙 17).
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
addpath(fullfile(here,'..','..','_tools'));
img = fullfile(here,'img');
if ~isfolder(img), mkdir(img); end

switch which
    case 'offline', m = 'W07_0_offline';  vrx = false;  dflt = 330;
    case 'vrx',     m = 'W07_1_vrx';      vrx = true;   dflt = 420;
    otherwise, error('W07_anim_capture:which', '모르는 이름 ''%s''. offline 또는 vrx.', which);
end
if isempty(tStop), tStop = dflt; end

%  게인·미션 설정을 언제나 기본값에서 출발시킨다. W07_setup 은 스스로
%  오프라인 모델을 돌리므로(auto_run) 그 자동 실행만 건너뛴다
setappdata(0, 'W07_skip_run', true);
evalin('base', 'W07_setup');
assignin('base','animate',1);

bdclose('all');
load_system(m);

in = Simulink.SimulationInput(m);
in = in.setModelParameter('StopTime', num2str(tStop));

if vrx
    TOP = '/wamv/sensors/position/ground_truth_odometry';
    if ~any(strcmp(ros2('topic','list'), TOP))
        error('W07_anim_capture:novrx', ...
              ['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가 (W03_vrx_lite/run_vrx.sh lite)\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가 (전 주차 7)'], TOP);
    end

    %  스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다
    %  다르다 (같은 2.4.0-2 인데 ENU y 가 162 인 컴퓨터와 200 인 컴퓨터가 있다,
    %  2026-09-18 · 스킬 규칙 15). 고정값을 쓰면 그 차이만큼 경로가 통째로 밀려
    %  안전 수역을 벗어난다. W07_vrx_run 이 하는 일과 같다.
    [rtf, x0_n, y0_n] = measure_spawn(TOP, 20);
    assignin('base','origin_north', x0_n);
    assignin('base','origin_east',  y0_n);
    fprintf('  스폰 (x, y) = (%.1f, %.1f) m · RTF %.3f\n', x0_n, y0_n, rtf);
    if isempty(pacing), pacing = rtf; end

    %  페이싱은 **실측 RTF** 그대로. 더 높이면 모델과 시뮬레이터가 CPU 를 다퉈
    %  오히려 느려진다
    in = in.setModelParameter('EnablePacing','on', 'PacingRate', num2str(pacing));
else
    if isempty(pacing), pacing = 0; end
end

wall = tic;
out = sim(in);
wall = toc(wall);

%  추진기 플러그인은 **마지막 값을 유지**한다. 시뮬레이션이 끝나도 배가 계속
%  간다 — 0 을 보내고 끝내지 않으면 다음 실험이 달리는 배 위에서 시작한다
if vrx, stop_thrusters(); end

f = W07_animate();                          % gcf 가 아니라 그리는 함수가 준 핸들
if isempty(f) || ~isvalid(f)
    error('W07_anim_capture:nofig', ...
          '실시간 화면이 열리지 않았다. animate = 1 인지 확인할 것.');
end
figure(f); drawnow;

file = fullfile(img, ['W07_anim_' which '.png']);
exportgraphics(f, file, 'Resolution', 150);   % 1240 px * 150/96 = 1938 px (2000 이하)

%  화면에 무엇이 남았는지 — 전이가 세 번 보여야 캡처로 쓸 수 있다
md = out.log_mode.Data(:);  tm = out.log_mode.Time(:);
ktr = find(diff(round(md)) ~= 0) + 1;
t_tr = tm(ktr)';

B = @(v) evalin('base', v);
info = struct( ...
    'name',    which, ...
    'model',   m, ...
    'file',    file, ...
    'stop',    tStop, ...
    'wall',    wall, ...
    'pacing',  pacing*double(vrx), ...
    'vrx',     vrx, ...
    'n_trans', numel(t_tr), ...
    't_trans', t_tr, ...
    'turns',   max(out.log_turns.Data(:)), ...
    'loiter_wp', B('loiter_wp'), 'loiter_radius', B('loiter_radius'), ...
    'loiter_turns', B('loiter_turns'), 'p_c', B('p_c'), 'crab_comp', B('crab_comp'), ...
    'Delta',   B('Delta'), 'R_LOS', B('R_LOS'), 'u_ref', B('u_ref'), ...
    'Kp_psi',  B('Kp_psi'), 'Kd_psi', B('Kd_psi'), ...
    'Kp_u',    B('Kp_u'),   'Ki_u',   B('Ki_u'), 'F_max', B('F_max'), ...
    'animate_every', B('animate_every'));

fprintf('  [캡처] %-8s %-14s %5.1f s 시뮬 / %5.1f s 벽시계 -> %s\n', ...
        which, m, tStop, wall, file);
fprintf('  상태 전이 %d회  (%s s)   최대 %.2f 바퀴\n', ...
        numel(t_tr), strjoin(compose('%.1f', t_tr), ' -> '), info.turns);
if numel(t_tr) < 3
    warning('W07_anim_capture:few', ...
            '전이가 %d회뿐이다. Stop 을 키워 상태가 세 번 바뀐 뒤를 찍을 것.', numel(t_tr));
end
close_system(m, 0);
end

% ---- 스폰 위치와 RTF 를 한 번에 잰다 (W07_vrx_run 의 measureRTF 와 같다) ----
function [RTF, x0_n, y0_n] = measure_spawn(topic, sec)
n = ros2node(sprintf('/w07_anim_probe_%d', randi(9999)));
c = onCleanup(@() clear('n'));  %#ok<NASGU>
s = ros2subscriber(n, topic, 'nav_msgs/Odometry');
m0 = receive(s, 15);  w = tic;
t0 = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
y0_n = m0.pose.pose.position.x;   x0_n = m0.pose.pose.position.y;   % ENU -> NED
pause(sec);
m1 = receive(s, 15);  dw = toc(w);
t1 = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
RTF = (t1 - t0) / dw;
end

% ---- 좌·우 추진기에 0 N 을 몇 번 보낸다 (W03_vrx_run 과 같은 뒷정리) -------
function stop_thrusters()
try
    n  = ros2node(sprintf('/w07_stop_%d', randi(9999)));
    pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
    pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
    msg = ros2message(pl);  msg.data = 0;
    for k = 1:5, send(pl, msg);  send(pr, msg);  pause(0.1); end
    clear pl pr n
    fprintf('  추력 0 송신 완료\n');
catch e
    warning('W07_anim_capture:stop', '추력 0 송신 실패: %s', e.message);
end
end
