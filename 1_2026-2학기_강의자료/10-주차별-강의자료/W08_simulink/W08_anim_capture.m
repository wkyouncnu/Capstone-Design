function info = W08_anim_capture(which, varargin)
% W08_ANIM_CAPTURE  실시간 화면(W08_animate)을 돌려서 그대로 PNG 로 저장한다.
%
%   W08_anim_capture('offline')    img/W08_anim_offline.png
%   W08_anim_capture('vrx')        img/W08_anim_vrx.png     (VRX 기동 필요)
%
%   이름있는 인자
%     'Pacing'  VRX 에서 쓸 페이싱 비율. **실측 RTF 를 그대로 넣는다.**
%               더 높이면 모델과 시뮬레이터가 CPU 를 다퉈 오히려 느려진다
%               (3주차 2-3). 주지 않으면 여기서 20초 동안 잰다
%     'Stop'    몇 초(시뮬레이션 시각)에서 멈출 것인가.
%               기본값 290 — dp_step 표의 계단 **셋이 모두 지나가고**
%               (60 s 전진 · 140 s 횡이동 · 220 s 제자리 선수 45°) 마지막 것이
%               정착한 시점이다. 다음 계단(300 s 선수 복귀)에는 아직 닿지 않는다.
%               왜 200 s 가 아닌가 — 140 s 의 횡이동은 계단 목표 기준으로는
%               28 s 에 정착하지만 기준모델 목표 eta_d 기준 오차는 200 s 에도
%               0.74 m 로 남아 있다 (실측, 2026-09-25). 그 화면을 실으면
%               "DP 가 목표에 붙는다" 가 아니라 따라가는 중간이 찍힌다.
%               280~300 s 구간은 위치 오차 RMS 0.094 m 로 완전히 붙어 있다
%
%   왜 스크립트로 찍는가
%     강의자료에 싣는 그림은 **재현되어야 한다.** 손으로 창을 잡아 찍으면
%     다음 사람이 같은 그림을 얻지 못하고, 조건(게인·시간·외란)도 남지 않는다.
%     이 함수는 조건을 함께 돌려준다.
%
%   왜 gcf 를 쓰지 않는가
%     한 세션에 창이 여럿 열려 있다 (배분 그림 · 결과 그림 · 실시간 화면).
%     gcf 로 저장하면 마지막으로 만진 창이 저장된다. W08_animate 가 자기 창
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
    case 'offline', m = 'W08_0_offline';  vrx = false;  dflt = 290;
    case 'vrx',     m = 'W08_1_vrx';      vrx = true;   dflt = 290;
    otherwise, error('W08_anim_capture:which', '모르는 이름 ''%s''. offline 또는 vrx.', which);
end
if isempty(tStop), tStop = dflt; end

%  게인·시나리오·외란을 언제나 기본값에서 출발시킨다. W08_setup 은 스스로
%  오프라인 모델을 돌리므로(auto_run) 그 자동 실행만 건너뛴다
setappdata(0, 'W08_skip_run', true);
evalin('base', 'W08_setup');
assignin('base','animate',1);

bdclose('all');
load_system(m);

in = Simulink.SimulationInput(m);
in = in.setModelParameter('StopTime', num2str(tStop));

if vrx
    TOP = '/wamv/sensors/position/ground_truth_odometry';
    if ~any(strcmp(ros2('topic','list'), TOP))
        error('W08_anim_capture:novrx', ...
              ['%s 가 보이지 않는다.\n' ...
               '  - VRX 가 떠 있는가 (W03_vrx_lite/run_vrx.sh)\n' ...
               '  - ROS_DOMAIN_ID 가 양쪽 같은가 (전 주차 7)'], TOP);
    end

    %  스폰 위치를 직접 읽어 원점으로 쓴다. launch.py 의 스폰 좌표가 설치마다
    %  다르다 (같은 2.4.0-2 인데 ENU y 가 162 인 컴퓨터와 200 인 컴퓨터가 있다,
    %  2026-09-18 · 스킬 규칙 15). 고정값을 쓰면 DP 목표가 통째로 밀린다.
    %  W08_vrx_run 이 하는 일과 같다.
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

f = W08_animate();                          % gcf 가 아니라 그리는 함수가 준 핸들
if isempty(f) || ~isvalid(f)
    error('W08_anim_capture:nofig', ...
          '실시간 화면이 열리지 않았다. animate = 1 인지 확인할 것.');
end
figure(f); drawnow;

file = fullfile(img, ['W08_anim_' which '.png']);
%  exportgraphics 가 아니라 print 를 쓴다.
%    exportgraphics 는 내용에 딱 맞춰 잘라 내는데, 그 경계 계산이 **회전된
%    한글 축 이름표**를 짧게 잡는다. 오른쪽 ③ 칸의 '방위각 \delta_i [deg]'
%    (yyaxis 오른쪽 이름표) 가 세로로 반쯤 잘려 나갔다 (2026-09-25 실측).
%    print 는 창 전체를 그대로 찍으므로 잘리지 않는다.
%    1240 px x 150/96 = 1938 px (가로) — 2000 px 이하 규약을 지킨다.
set(f, 'PaperPositionMode', 'auto');
print(f, file, '-dpng', '-r150');

%  화면에 무엇이 남았는지 — 마지막 20 s 의 오차가 정착값이다
te  = out.log_eta.Time(:);
eta = squeeze(out.log_eta.Data)';
etd = squeeze(out.log_eta_d.Data)';
etr = squeeze(out.log_eta_raw.Data)';
kw  = te >= te(end) - 20;
epos = hypot(etd(:,1)-eta(:,1), etd(:,2)-eta(:,2));
epsi = atan2(sin(eta(:,3)-etd(:,3)), cos(eta(:,3)-etd(:,3)));
T    = squeeze(out.log_Tact.Data)';
D    = squeeze(out.log_Dact.Data)';

%  목표가 몇 번 옮겨졌는가 — 계단 목표가 바뀐 시각
jump = find(any(abs(diff(etr,1,1)) > 1e-6, 2)) + 1;
t_jump = te(jump)';
t_jump = t_jump(diff([-inf t_jump]) > 1);     % 같은 계단의 연속 샘플은 하나로

B = @(v) evalin('base', v);
info = struct( ...
    'name',   which, ...
    'model',  m, ...
    'file',   file, ...
    'stop',   tStop, ...
    'wall',   wall, ...
    'pacing', pacing*double(vrx), ...
    'vrx',    vrx, ...
    'n_jump', numel(t_jump), ...
    't_jump', t_jump, ...
    'epos_rms',  sqrt(mean(epos(kw).^2)), ...
    'epos_max',  max(epos), ...
    'epsi_rms',  rad2deg(sqrt(mean(epsi(kw).^2))), ...
    'T_mean',    mean(abs(T(kw,:)), 'all'), ...
    'del_max',   rad2deg(max(abs(D(kw,:)), [], 'all')), ...
    'wind_on', B('wind_on'), 'wind_speed', B('wind_speed'), ...
    'wave_on', B('wave_on'), 'Hs', B('Hs'), 'Tp', B('Tp'), ...
    'Kp_dp', diag(B('Kp_dp'))', 'Kd_dp', diag(B('Kd_dp'))', 'Ki_dp', diag(B('Ki_dp'))', ...
    'F_max', B('F_max'), 'delta_lim', rad2deg(B('del_max')), ...
    'animate_every', B('animate_every'));

fprintf('  [캡처] %-8s %-14s %5.1f s 시뮬 / %5.1f s 벽시계 -> %s\n', ...
        which, m, tStop, wall, file);
fprintf('  계단 목표 이동 %d회 (%s s)\n', ...
        numel(t_jump), strjoin(compose('%.0f', t_jump), ' -> '));
fprintf('  마지막 20 s   위치오차 RMS %.3f m   선수각 RMS %.2f°   평균추력 %.1f N\n', ...
        info.epos_rms, info.epsi_rms, info.T_mean);
if numel(t_jump) < 1
    warning('W08_anim_capture:nojump', ...
            '목표가 한 번도 옮겨지지 않았다. Stop 을 키울 것.');
end
close_system(m, 0);
end

% ---- 스폰 위치와 RTF 를 한 번에 잰다 (W08_vrx_run 의 measureRTF 와 같다) ----
function [RTF, x0_n, y0_n] = measure_spawn(topic, sec)
n = ros2node(sprintf('/w08_anim_probe_%d', randi(9999)));
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
%   8주차는 방위각도 함께 0 으로 되돌린다. 추력만 0 으로 두고 나가면 다음
%   실험이 **비스듬히 꺾인 추진기** 위에서 시작한다.
function stop_thrusters()
try
    n  = ros2node(sprintf('/w08_stop_%d', randi(9999)));
    pt = { ros2publisher(n, '/wamv/thrusters/left/thrust',  'std_msgs/Float64'), ...
           ros2publisher(n, '/wamv/thrusters/right/thrust', 'std_msgs/Float64'), ...
           ros2publisher(n, '/wamv/thrusters/left/pos',     'std_msgs/Float64'), ...
           ros2publisher(n, '/wamv/thrusters/right/pos',    'std_msgs/Float64') };
    msg = ros2message(pt{1});  msg.data = 0;
    for k = 1:5
        for i = 1:4, send(pt{i}, msg); end
        pause(0.1);
    end
    clear pt n
    fprintf('  추력·방위각 0 송신 완료\n');
catch e
    warning('W08_anim_capture:stop', '추력 0 송신 실패: %s', e.message);
end
end
