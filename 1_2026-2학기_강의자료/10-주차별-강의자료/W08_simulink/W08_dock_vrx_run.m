function S = W08_dock_vrx_run(T_end, do_compare)
% W08_DOCK_VRX_RUN  VRX(Gazebo) 와 연동해 W08_3_dock_vrx 를 돌리고 접안을 수치로 확인한다.
%
%   >> W08_dock_setup           % 설정 (오프라인도 한 번 돈다)
%   >> W08_dock_vrx_run         % 420초 주행 + 오프라인 대조
%   >> W08_dock_vrx_run(480)
%   >> W08_dock_vrx_run(420, false)   % 대조 없이 VRX 만
%
%   실습 A 의 W08_vrx_run 과 하는 일이 같다. 다른 것은 모델 하나와 마지막 단계다
%     1. 토픽 확인 — 참값 오도메트리 + **선수추진기**
%     2. RTF · 스폰 원점 측정
%     3. 페이싱을 실측 RTF 에 맞춰 실행
%     4. 결과 그림 (ㄷ 자 확대 포함)
%     5. 오프라인과 궤적 겹쳐 그리기
%
%   실행 전에 VRX 가 **선수추진기를 단 WAM-V 로** 떠 있어야 한다
%     WSL:  bash W06_vrx_lite/run_vrx_bow.sh headless
%     토픽 /wamv/thrusters/bow/thrust 가 보이지 않으면 좌·우 추진기만 있는 배다.
%     그 배로는 순수 옆걸음이 되지 않는다 (옆으로 미는 힘을 낼 수 없다)
%
%   끝낸 뒤에는 반드시 정리한다
%     WSL:  source ~/vrx_ws/install/setup.bash && ros2 run vrx_llm_dock cleanup
%     남은 gz sim 이 수십 GB 까지 자란다

if nargin < 1 || isempty(T_end),      T_end = 420;  end
if nargin < 2 || isempty(do_compare), do_compare = true; end

m   = 'W08_3_dock_vrx';
TOP = '/wamv/sensors/position/ground_truth_odometry';
BOW = '/wamv/thrusters/bow/thrust';

%  설정이 깔려 있지 않으면 깔되, W08_dock_setup 의 자동 오프라인 실행은 건너뛴다
cfg = evalin('base', 'exist(''dock_q'',''var'') && exist(''Ts_ctrl'',''var'')') == 1;
if ~cfg
    setappdata(0, 'W08_dock_skip_run', true);
    evalin('base', 'W08_dock_setup');
end

% ---------------------------------------------------------------------
%  0) ROS 2 도메인 맞추기 — Simulink 블록은 'ROS 네트워크 프로필'의 Domain ID 를,
%     MATLAB 의 ros2* 함수는 환경변수 ROS_DOMAIN_ID 를 본다. 둘이 다르면
%     토픽이 보이지 않는다. 프로필 값으로 환경변수를 맞춘다 (볼트 규칙)
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

fprintf('1) VRX 토픽 확인\n');
tl = ros2('topic','list');
if ~any(strcmp(tl, TOP))
    error('W08_dock_vrx_run:novrx', ...
          ['%s 가 보이지 않는다.\n' ...
           '  VRX 가 떠 있는가 / ground_truth_enabled 가 true 인가 / ' ...
           'ROS_DOMAIN_ID 가 같은가'], TOP);
end
if ~any(strcmp(tl, BOW))
    error('W08_dock_vrx_run:nobow', ...
          ['%s 가 없다 — 좌·우 추진기만 있는 WAM-V 다.\n' ...
           '  WSL 에서  bash W06_vrx_lite/run_vrx_bow.sh headless  로 다시 띄울 것'], BOW);
end
fprintf('   OK — 토픽 %d개 (선수추진기 있음)\n', numel(tl));

fprintf('2) RTF · 스폰 원점 측정 (20초)\n');
[RTF, x0_n, y0_n] = measureRTF(TOP, 20);
%  스폰 좌표는 설치마다 다르다 (같은 2.4.0-2 인데 ENU y 가 162 인 컴퓨터와 200 인
%  컴퓨터가 있다). 고정값을 쓰면 그만큼 경로가 통째로 밀려 안전 수역을 벗어난다
assignin('base', 'origin_north', x0_n);
assignin('base', 'origin_east',  y0_n);
fprintf('   스폰 (x, y) = (%.1f, %.1f) m — 이 점을 원점으로 쓴다\n', x0_n, y0_n);
fprintf('   RTF = %.3f  (페이싱 비율로 그대로 쓴다)\n', RTF);

% ---------------------------------------------------------------------
%  3) 실행 — StopTime·페이싱은 SimulationInput 으로만 준다.
%     set_param 으로 모델에 써 넣으면 .slx 가 바뀌어 다음 빌드와 어긋난다
% ---------------------------------------------------------------------
fprintf('3) %s 실행 (%g초, 페이싱 %.3f)\n', m, T_end, RTF);
load_system(m);
in = Simulink.SimulationInput(m);
in = in.setModelParameter('StopTime', num2str(T_end), ...
                          'EnablePacing','on', 'PacingRate', num2str(RTF));
wall = tic;
out  = sim(in);
wall = toc(wall);
fprintf('   %.0f s 시뮬 / %.0f s 벽시계  (실효 %.3f)\n', T_end, wall, T_end/wall);

%  추진기 플러그인은 **마지막 값을 유지**한다. 0 을 보내고 끝내지 않으면
%  다음 실험이 달리는 배 위에서 시작한다
stopThrusters();

fprintf('4) 결과 그림\n');
S        = W08_dock_plot(out, 'VRX 연동 — WP -> 로이터 -> WP -> 접안');
S.RTF    = RTF;
S.wall   = wall;
S.origin = [x0_n y0_n];
saveFig(S.fig, 'W08_3_dock_vrx_result.png');   % gcf 는 추진기 창이다

if ~do_compare, return; end

% ---------------------------------------------------------------------
%  5) 오프라인 대조 — 두 모델은 제어기가 같고 사슬 끝의 플랜트만 다르다.
%     이격이 크면 먼저 **궤적이 겹치는지** 본다. 겹치는데 시각만 밀렸다면
%     위상 오차이고, 모양이 다르면 그때 제어·좌표를 의심한다
% ---------------------------------------------------------------------
fprintf('5) 같은 정지 시간으로 오프라인 모델 실행\n');
animOld = evalin('base','animate');
assignin('base','animate', 0);
load_system('W08_2_dock');
o2 = sim(Simulink.SimulationInput('W08_2_dock').setModelParameter( ...
         'StopTime', num2str(T_end)));
assignin('base','animate', animOld);
So = W08_dock_plot(o2, '오프라인 대조');
S.offline = rmfield(So, intersect(fieldnames(So), {'fig'}));

x_n = out.log_x_n.Data(:);  y_n = out.log_y_n.Data(:);  t  = out.log_x_n.Time(:);
qn  = o2.log_x_n.Data(:);   qe  = o2.log_y_n.Data(:);   t2 = o2.log_x_n.Time(:);

%  두 시계가 겹치는 구간만 비교한다 — 밖으로 나가면 외삽이 폭주한다
tm   = t(t <= t2(end));  nm = numel(tm);
sep  = hypot(x_n(1:nm) - interp1(t2, qn, tm, 'linear'), ...
             y_n(1:nm) - interp1(t2, qe, tm, 'linear'));
S.sep_mean = mean(sep);  S.sep_max = max(sep);

drawOverlay(y_n, x_n, qe, qn, tm, sep, S, T_end);
saveFig(gcf, 'W08_dock_vrx_vs_offline.png');

fprintf('\n  === 오프라인 ↔ VRX 대조 (%g초) ===\n', T_end);
fprintf('  로이터 진입     오프라인 %6.1f s    VRX %6.1f s\n', So.t_loiter_in,  S.t_loiter_in);
fprintf('  로이터 종료     오프라인 %6.1f s    VRX %6.1f s\n', So.t_loiter_out, S.t_loiter_out);
fprintf('  접안 시작       오프라인 %6.1f s    VRX %6.1f s\n', So.t_dock_in,    S.t_dock_in);
fprintf('  접안 완료       오프라인 %6.1f s    VRX %6.1f s\n', So.t_finish,     S.t_finish);
fprintf('  멈춘 뒤 오차    오프라인 %6.2f m    VRX %6.2f m\n', So.berth_rest,   S.berth_rest);
fprintf('  선수각 유지     오프라인 %6.2f deg  VRX %6.2f deg\n', So.psi_hold,   S.psi_hold);
fprintf('  궤적 평균 이격 %6.2f m,  최대 %6.2f m\n', S.sep_mean, S.sep_max);
end

% =====================================================================
function [RTF, x0_n, y0_n] = measureRTF(topic, sec)
n = ros2node(sprintf('/dock_rtf_probe_%d', randi(9999)));
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

% ---- 세 추진기에 0 N 을 몇 번 보낸다 ---------------------------------
function stopThrusters()
try
    n = ros2node(sprintf('/w08_dock_stop_%d', randi(9999)));
    p = cell(1,3);
    nm = {'left','right','bow'};
    for k = 1:3
        p{k} = ros2publisher(n, ['/wamv/thrusters/' nm{k} '/thrust'], 'std_msgs/Float64');
    end
    msg = ros2message(p{1});  msg.data = 0;
    for i = 1:5
        for k = 1:3, send(p{k}, msg); end
        pause(0.1);
    end
    clear p n
    fprintf('   추력 0 송신 완료 (좌·우·선수)\n');
catch e
    warning('W08_dock_vrx_run:stop', '추력 0 송신 실패: %s', e.message);
end
end

% ---- 궤적 겹쳐 그리기 + 이격거리 -------------------------------------
function drawOverlay(y_n, x_n, qe, qn, t, sep, S, T_end)
th  = linspace(0, 2*pi, 361);
wpx = evalin('base','wp_north');    wpy = evalin('base','wp_east');
cn  = evalin('base','loiter_xc');   ce  = evalin('base','loiter_yc');
rd  = evalin('base','loiter_radius');
q   = evalin('base','dock_q');      % 접안 묶음 — 그림과 제어가 같은 값을 보게 한다
[qX, qY] = W08_dock_patch(q(1), q(2), q(3), q(5));

figure('Name','W08 실습 E  오프라인 vs VRX','Color','w','Position',[80 80 1020 450]);

subplot(1,2,1);
patch('XData',qY, 'YData',qX, 'FaceColor',[0.82 0.76 0.66], ...
      'EdgeColor',[0.45 0.33 0.20], 'LineWidth',1.1);
hold on;
plot(wpy, wpx, 'ks--', 'MarkerFaceColor','w', 'LineWidth',1.0);
plot(ce + rd*sin(th), cn + rd*cos(th), 'k:', 'LineWidth',1.0);
plot(qe, qn, 'b-', 'LineWidth',1.4);
plot(y_n, x_n, 'r-', 'LineWidth',1.4);
plot(y_n(1), x_n(1), 'ko', 'MarkerFaceColor','g', 'MarkerSize',8);
axis equal; grid on; xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({'ㄷ 자 도킹 스테이션','웨이포인트','로이터 원','오프라인','VRX','출발'}, ...
       'Location','southoutside', 'NumColumns',3);
title(sprintf('미션 궤적 — %g초, 평균 이격 %.2f m', T_end, S.sep_mean));

subplot(1,2,2);
plot(t, sep, 'k-', 'LineWidth',1.3); grid on; hold on;
if ~isnan(S.t_finish)
    xline(S.t_finish, ':', 'Color',[0.45 0.45 0.45], 'LineWidth',1.1);
end
xlabel('시간 [s]'); ylabel('두 궤적 사이 거리 [m]');
title(sprintf('이격거리 (평균 %.2f / 최대 %.2f m)', S.sep_mean, S.sep_max));
end

% ---- 그림 저장 -------------------------------------------------------
function saveFig(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, name), 'Resolution', 130);
fprintf('   그림 저장: img/%s\n', name);
end
