function kaboat2026_plot_ulog(ulgFile)
% KABOAT2026_PLOT_ULOG  states_and_actuators + mission_command 로그 플롯
%   kaboat2026_plot_ulog()                -> 파일 선택 창
%   kaboat2026_plot_ulog('C:\...\log.ulg') -> 경로 지정

if nargin < 1, ulgFile = ''; end
close all;

%% 1. ulg 파일 지정
if isempty(ulgFile)
    [fn, fp] = uigetfile({'*.ulg','PX4 ulog (*.ulg)'}, 'ulg 파일 선택');
    if isequal(fn, 0), error('파일이 선택되지 않았습니다.'); end
    ulgFile = fullfile(fp, fn);
end
ulgFile = char(ulgFile);
if ~isfile(ulgFile), error('파일을 찾을 수 없습니다: %s', ulgFile); end
fprintf('불러오는 파일: %s\n', ulgFile);

%% 2. 설정
angleInRad = true;   % psi, r, alpha 가 rad 이면 true (deg로 변환해 표시), 이미 deg이면 false
if angleInRad, ang = @(x) rad2deg(x); else, ang = @(x) x; end

%% 3. 로그 읽기
ulg = ulogreader(ulgFile);
topics = ulg.AvailableTopics.TopicNames;

sa = readTopic(ulg, topics, 'states_and_actuators');
mc = readTopic(ulg, topics, 'mission_command');

% 시간축: 존재하는 토픽 중 가장 먼저 시작한 시각을 0초로 통일
starts = [];
if ~isempty(sa), tsa_raw = toSec(sa); starts(end+1) = tsa_raw(1); end
if ~isempty(mc), tmc_raw = toSec(mc); starts(end+1) = tmc_raw(1); end
if isempty(starts), error('두 토픽 모두 로그에 없습니다.'); end
t0 = min(starts);
if ~isempty(sa), tsa = tsa_raw - t0; end
if ~isempty(mc), tmc = tmc_raw - t0; end

%% 4. StatesAndActuators
if ~isempty(sa)
    figure('Name','Velocity');
    subplot(3,1,1); plot(tsa, sa.u_time_log, tsa, sa.u_ref_time_log,'--'); grid on
    ylabel('u [m/s]'); legend('u','u_{ref}'); title('Surge / Sway / Yaw rate')
    subplot(3,1,2); plot(tsa, sa.v_time_log); grid on; ylabel('v [m/s]')
    subplot(3,1,3); plot(tsa, ang(sa.r_time_log)); grid on
    ylabel('r [deg/s]'); xlabel('time [s]')

    figure('Name','Heading');
    plot(tsa, ang(sa.psi_time_log), tsa, ang(sa.psi_ref_time_log),'--'); grid on
    xlabel('time [s]'); ylabel('\psi [deg]'); legend('\psi','\psi_{ref}'); title('Heading')

    figure('Name','Trajectory');
    plot(sa.y_time_log, sa.x_time_log, 'LineWidth',1.2); hold on
    plot(sa.y_time_log(1),   sa.x_time_log(1),   'go', 'MarkerFaceColor','g');
    plot(sa.y_time_log(end), sa.x_time_log(end), 'rs', 'MarkerFaceColor','r');
    axis equal; grid on; xlabel('East y [m]'); ylabel('North x [m]');
    legend('path','start','end'); title('XY trajectory')

    figure('Name','Tau');
    subplot(3,1,1); plot(tsa, sa.taux_time_log); grid on; ylabel('\tau_x'); title('Control forces / moment')
    subplot(3,1,2); plot(tsa, sa.tauy_time_log); grid on; ylabel('\tau_y')
    subplot(3,1,3); plot(tsa, sa.taun_time_log); grid on; ylabel('\tau_n'); xlabel('time [s]')

    figure('Name','Actuators');
    subplot(2,1,1);
    plot(tsa, [sa.motor1_time_log sa.motor2_time_log sa.motor3_time_log sa.motor4_time_log]); grid on
    ylabel('motor'); legend('m1','m2','m3','m4'); title('Motors / Azimuth angles')
    subplot(2,1,2);
    plot(tsa, ang([sa.alpha1_time_log sa.alpha2_time_log sa.alpha3_time_log sa.alpha4_time_log])); grid on
    ylabel('\alpha [deg]'); xlabel('time [s]'); legend('\alpha_1','\alpha_2','\alpha_3','\alpha_4')
else
    warning('states_and_actuators 토픽이 로그에 없습니다. (logged_topics.cpp 확인)');
end

%% 5. MissionCommand
if ~isempty(mc)
    figure('Name','Mission flags');
    subplot(4,1,1); stairs(tmc, mc.operation_mode); grid on
    ylabel('operation\_mode'); title('Mission command')
    subplot(4,1,2); stairs(tmc, [mc.docking_flag mc.guidance_flag]); grid on
    ylabel('flag'); legend('docking','guidance')
    subplot(4,1,3); stairs(tmc, [mc.detect_on mc.detect_valid]); grid on
    ylabel('detect'); legend('on','valid')
    subplot(4,1,4); stairs(tmc, [mc.loiter_used mc.loiter_done mc.rc_on_off mc.on_off]); grid on
    ylabel('loiter / sw'); xlabel('time [s]')
    legend('loiter\_used','loiter\_done','rc\_on\_off','on\_off')

    figure('Name','Docking rel');
    subplot(2,2,1); plot(tmc, mc.dock_rel_x_ned, tmc, mc.dock_prev_x_ned,'--'); grid on
    ylabel('x NED [m]'); legend('rel','prev'); title('Docking target (NED)')
    subplot(2,2,3); plot(tmc, mc.dock_rel_y_ned, tmc, mc.dock_prev_y_ned,'--'); grid on
    ylabel('y NED [m]'); xlabel('time [s]')
    subplot(2,2,2); plot(tmc, mc.dock_rel_x_body, tmc, mc.dock_prev_x_body,'--'); grid on
    ylabel('x body [m]'); title('Docking target (body)')
    subplot(2,2,4); plot(tmc, mc.dock_rel_y_body, tmc, mc.dock_prev_y_body,'--'); grid on
    ylabel('y body [m]'); xlabel('time [s]')

    figure('Name','Loiter');
    subplot(2,1,1); plot(tmc, mc.loiter_angle_deg); grid on; ylabel('loiter angle [deg]')
    subplot(2,1,2); plot(tmc, mc.dist_loiter); grid on; ylabel('dist\_loiter [m]'); xlabel('time [s]')

    figure('Name','Test WP');
    plot(mc.test_wp_y, mc.test_wp_x, 'o-'); axis equal; grid on
    xlabel('East [m]'); ylabel('North [m]'); title('test\_wp')
else
    warning('mission_command 토픽이 로그에 없습니다. (logged_topics.cpp 확인)');
end
end

%% ===== 보조 함수 =====
function T = readTopic(ulg, topics, name)
% 토픽이 있으면 타임테이블 반환, 없으면 []
    T = [];
    if ~any(strcmp(topics, name)), return; end
    r = readTopicMsgs(ulg, 'TopicNames', {name});
    T = r.TopicMessages{1};
end

function s = toSec(tbl)
% 시간 열을 초(double)로 변환. 열 이름/타입이 달라도 동작
    vn = tbl.Properties.VariableNames;
    if any(strcmp(vn,'timestamp')),      col = tbl.timestamp;
    elseif any(strcmp(vn,'Timestamp')),  col = tbl.Timestamp;
    elseif ~isempty(tbl.Properties.RowTimes), col = tbl.Properties.RowTimes;
    else, error('시간 열을 찾을 수 없습니다: %s', strjoin(vn,', '));
    end
    if isduration(col),     s = seconds(col);
    elseif isdatetime(col), s = posixtime(col);
    else,                   s = double(col) * 1e-6;   % uint64 마이크로초
    end
    s = s(:);
end