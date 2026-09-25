function info = W06_anim_capture(which, varargin)
% W06_ANIM_CAPTURE  실시간 화면(W06_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W06_anim_capture('offline')    img/W06_anim_offline.png
%   W06_anim_capture('vrx')        img/W06_anim_vrx.png     (VRX 기동 필요)
%
%   이름있는 인자
%     'Pacing'  VRX 에서 쓸 페이싱 비율. **실측 RTF 를 그대로 넣는다.**
%               더 높이면 모델과 시뮬레이터가 CPU 를 다퉈 오히려 느려진다
%               (3주차 2-3 · CLAUDE.md §11). 주지 않으면 여기서 20초 동안 잰다
%     'Stop'    몇 초(시뮬레이션 시각)에서 멈출 것인가.
%               기본값 260. 기본 설정에서 두 바퀴가 240.6 s 에 끝나므로
%               **두 바퀴를 다 돌고 배가 선 뒤**의 화면이 남는다
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(게인·유도 설정·시간·RTF)도
%     남지 않는다. 이 함수는 조건과 지표를 구조체로 함께 돌려준다.
%
%   돌려주는 구조체
%     조건   model · stop · wall · pacing · 중심·반경·p_c·u_ref·게인·animate_every
%     지표   t_enter (원 도달) · t_done (정지) · turns · r_mean · e_mean · e_max
%            u_mean · FL_mean · FR_mean   — **그림과 같은 실행**에서 뽑은 값이며
%            판정 기준은 W06_plot 과 같다 (정착 = 원 도달 30 s 뒤부터 정지까지)
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (성능 그림 · 벡터필드 그림 · 실시간 화면).
%     gcf 로 저장하면 마지막으로 만진 창이 저장된다. W06_animate 가 자기 창
%     핸들을 돌려주므로 **그 핸들로** 저장한다 (스킬 규칙 17).
%
%   모델은 건드리지 않는다
%     StopTime·페이싱은 Simulink.SimulationInput 으로만 준다. set_param 으로
%     모델에 써 넣으면 .slx 가 바뀌어 다음 빌드와 어긋난다.

p = inputParser;
p.addParameter('Pacing', []);
p.addParameter('Stop',   260);
p.parse(varargin{:});
pacing = p.Results.Pacing;
tStop  = p.Results.Stop;

here = fileparts(mfilename('fullpath'));
cd(here);
addpath(fullfile(here,'..','..','_tools'));
img = fullfile(here,'img');
if ~isfolder(img), mkdir(img); end

switch which
    case 'offline', m = 'W06_0_offline';  vrx = false;
    case 'vrx',     m = 'W06_1_vrx';      vrx = true;
    otherwise, error('W06_anim_capture:which', '모르는 이름 ''%s''. offline 또는 vrx.', which);
end

%  게인·유도 설정을 언제나 기본값에서 출발시킨다. W06_setup 은 스스로
%  오프라인 모델을 돌리므로(auto_run) 그 자동 실행만 건너뛴다
setappdata(0, 'W06_skip_run', true);
evalin('base', 'W06_setup');
assignin('base','animate',1);

bdclose('all');
load_system(m);

in = Simulink.SimulationInput(m);
in = in.setModelParameter('StopTime', num2str(tStop));

if vrx
    TOP = '/wamv/sensors/position/ground_truth_odometry';
    if ~any(strcmp(ros2('topic','list'), TOP))
        error('W06_anim_capture:novrx', ...
              ['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가 (W03_vrx_lite/run_vrx.sh lite)\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가 (전 주차 7)'], TOP);
    end

    %  스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다
    %  다르다 (같은 2.4.0-2 인데 ENU y 가 162 인 컴퓨터와 200 인 컴퓨터가 있다,
    %  2026-09-18 · 스킬 규칙 15). 고정값을 쓰면 그 차이만큼 원이 통째로 밀려
    %  안전 수역을 벗어난다. W06_vrx_run 이 하는 일과 같다.
    [rtf, x0_n, y0_n] = measure_spawn(TOP, 20);
    assignin('base','origin_north', x0_n);
    assignin('base','origin_east',  y0_n);
    fprintf('  스폰 (x, y) = (%.1f, %.1f) m · RTF %.3f\n', x0_n, y0_n, rtf);
    if isempty(pacing), pacing = rtf; end

    %  페이싱은 **실측 RTF** 그대로. 더 높이면 모델과 시뮬레이터가 CPU 를 다퉈
    %  오히려 느려진다 (CLAUDE.md §11)
    in = in.setModelParameter('EnablePacing','on', 'PacingRate', num2str(pacing));
else
    if isempty(pacing), pacing = 0; end
end

wall = tic;
out  = sim(in);
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
exportgraphics(f, file, 'Resolution', 150);   % 1240 px * 150/96 = 1938 px (2000 이하)

%  그림과 **같은 실행**에서 지표를 뽑는다. 판정 기준은 W06_plot 과 똑같이 둔다
%  (원 도달 = 반경 오차가 0.3 r_d 안에 처음 든 시각, 정착 = 도달 30 s 뒤부터 정지까지).
%  그림 옆에 적는 숫자가 그 그림이 아닌 다른 실행에서 나오면 안 된다.
M = anim_metrics(out, evalin('base','r_d'));

B = @(v) evalin('base', v);
info = struct( ...
    'name',    which, ...
    'model',   m, ...
    'file',    file, ...
    'stop',    tStop, ...
    'wall',    wall, ...
    'pacing',  pacing*double(vrx), ...
    'vrx',     vrx, ...
    'center_north', B('center_north'), 'center_east', B('center_east'), ...
    'r_d',     B('r_d'),   'p_c',   B('p_c'), 'u_ref', B('u_ref'), ...
    'crab_comp', B('crab_comp'), 'required_turns', B('required_turns'), ...
    'Kp_psi',  B('Kp_psi'), 'Kd_psi', B('Kd_psi'), ...
    'Kp_u',    B('Kp_u'),   'Ki_u',   B('Ki_u'), 'F_max', B('F_max'), ...
    'animate_every', B('animate_every'), 'boat_scale', B('boat_scale'), ...
    't_enter', M.t_enter, 't_done', M.t_done, 'turns', M.turns, ...
    'r_mean',  M.r_mean,  'e_mean', M.e_mean, 'e_max', M.e_max, ...
    'u_mean',  M.u_mean,  'FL_mean', M.FL_mean, 'FR_mean', M.FR_mean);

fprintf('  [캡처] %-8s %-14s %5.1f s 시뮬 / %5.1f s 벽시계 -> %s\n', ...
        which, m, tStop, wall, file);
fprintf(['  원 도달 %.1f s · 정지 %.1f s · %.2f 바퀴 · 정착 r %.2f m ' ...
         '(오차 %+.3f m, 최대 %+.3f m) · u %.3f m/s · F_L %.1f N · F_R %.1f N\n'], ...
        M.t_enter, M.t_done, M.turns, M.r_mean, M.e_mean, M.e_max, ...
        M.u_mean, M.FL_mean, M.FR_mean);
close_system(m, 0);
end

% ---- 지표 — 판정 기준은 W06_plot 과 같다 ---------------------------------
function M = anim_metrics(out, rd)
t  = out.log_r_dist.Time;
r  = out.log_r_dist.Data(:);   g  = out.log_gate.Data(:);
u  = out.log_u.Data(:);        tn = out.log_turns.Data(:);
FL = out.log_FL.Data(:);       FR = out.log_FR.Data(:);

k = find(abs(r - rd) <= 0.3*rd, 1);            % 원 도달 (TurnCount 와 같은 띠)
if isempty(k), M.t_enter = NaN; k = 1; else, M.t_enter = t(k); end
kd = find(g < 0.5, 1);                          % 임무 종료
if isempty(kd), M.t_done = NaN; kd = numel(t); else, M.t_done = t(kd); end

sel = t >= t(k) + 30 & t <= t(kd);              % 정착 구간
if ~any(sel), sel = true(size(t)); end
M.turns   = tn(kd);
M.r_mean  = mean(r(sel));
M.e_mean  = mean(r(sel)) - rd;
[~, im]   = max(abs(r(sel) - rd));  rs = r(sel);
M.e_max   = rs(im) - rd;
M.u_mean  = mean(u(sel));
M.FL_mean = mean(FL(sel));
M.FR_mean = mean(FR(sel));
end

% ---- 스폰 위치와 RTF 를 한 번에 잰다 (W06_vrx_run 의 measureRTF 와 같다) ----
function [RTF, x0_n, y0_n] = measure_spawn(topic, sec)
n = ros2node(sprintf('/w06_anim_probe_%d', randi(9999)));
c = onCleanup(@() clear('n'));
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
    n  = ros2node(sprintf('/w06_stop_%d', randi(9999)));
    pl = ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64');
    pr = ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64');
    msg = ros2message(pl);  msg.data = 0;
    for k = 1:5, send(pl, msg);  send(pr, msg);  pause(0.1); end
    clear pl pr n
    fprintf('  추력 0 송신 완료\n');
catch e
    warning('W06_anim_capture:stop', '추력 0 송신 실패: %s', e.message);
end
end
