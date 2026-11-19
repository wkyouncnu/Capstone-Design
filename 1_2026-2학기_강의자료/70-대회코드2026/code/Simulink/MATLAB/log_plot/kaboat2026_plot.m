%% plot_kaboat_ulog.m : KABOAT Simulink 제어기 ulog 플롯
clear; close all; clc;

%% 1. 사용자 설정 --------------------------------------------------------
logDir  = 'C:\Users\user\Desktop\대학원\3.대회\KABOAT_2026\실험영상\ulog\20261103';
logName = 'log_334_2026-11-3-13-38-08.ulg';     % ''로 두면 파일 선택 창이 열림
ref_lla = [36.395991, 127.401794, 25.1110];     % otter_params_fixed.m 의 NED 원점

if isempty(logName)
    [logName, logDir] = uigetfile(fullfile(logDir, '*.ulg'), 'ulog 선택');
    if isequal(logName, 0), return; end
end
ulog = ulogreader(fullfile(logDir, logName));

%% 2. 토픽 읽기 ----------------------------------------------------------
mc  = getTopic(ulog, 'mission_command');        % 50 Hz
sa  = getTopic(ulog, 'states_and_actuators');   % 50 Hz
mr  = getTopic(ulog, 'mission_result');         % 값이 바뀔 때만 기록
lp  = getTopic(ulog, 'vehicle_local_position'); % 10 Hz
gp  = getTopic(ulog, 'vehicle_global_position');%  5 Hz
nav = getTopic(ulog, 'navigator_mission_item'); % PX4가 실행한 WP

t0   = seconds(mc.Properties.RowTimes(1));      % t = 0 : 로그 첫 샘플
tsec = @(tt) seconds(tt.Properties.RowTimes) - t0;

% 제어기 신호
tM   = tsec(mc);
op   = round(double(mc.operation_mode));
% ★ 모델 Bus Assignment 배선이 한 칸 밀려 있어 이름이 서로 바뀌어 기록됨
%   로그 필드 loiter_angle_deg = 실제 docking_flag (1/2/3)
%   로그 필드 docking_flag     = 실제 loiter 각도 (360/540)
dockFlag = round(double(mc.loiter_angle_deg));
dockFlag(op ~= 4) = NaN;                        % Docking 꺼진 구간의 유지값 제외
detectOn    = double(mc.detect_on);
detectValid = double(mc.detect_valid);
detectOn(op ~= 4)    = NaN;
detectValid(op ~= 4) = NaN;
wpOutN = double(mc.test_wp_x);                  % 도킹 유도기의 NED 목표점
wpOutE = double(mc.test_wp_y);

tS   = tsec(sa);
tauX = double(sa.taux_time_log);                % [N]
tauN = double(sa.taun_time_log);                % [N*m]
n1   = double(sa.motor1_time_log);              % 좌현 회전수 [rad/s]
n2   = double(sa.motor2_time_log);              % 우현 회전수 [rad/s]

% states_and_actuators 의 u,x,y,psi 는 이 로그에서 전부 0이므로 PX4 토픽에서 복원
tL  = tsec(lp);
psi = double(lp.heading);
u   = double(lp.vx).*cos(psi) + double(lp.vy).*sin(psi);   % 선체 전진속도
psiDeg = rad2deg(unwrap(psi));

tG  = tsec(gp);
ned = lla2ned([double(gp.lat), double(gp.lon), zeros(height(gp),1)], ref_lla, 'ellipsoid');
pN  = ned(:,1);
pE  = ned(:,2);

% Curr_idx = seq_current + 1 (끝까지 이어 그리도록 마지막 값 연장)
tI   = [tsec(mr); tM(end)];
cIdx = double(mr.seq_current) + 1;
cIdx = [cIdx; cIdx(end)];

% WP 좌표 (같은 번호는 마지막 기록만 사용)
navNed = lla2ned([double(nav.latitude), double(nav.longitude), zeros(height(nav),1)], ref_lla, 'ellipsoid');
[wpNum, iLast] = unique(double(nav.sequence_current) + 1, 'last');
wpN = navNed(iLast,1);
wpE = navNed(iLast,2);

%% 3. 공통 스타일 --------------------------------------------------------
modeId   = [1 2 3 4 5];
modeName = ["Waypoint" "Loitering" "Collision Avoid" "Docking" "Buoy Avoid"];
modeClr  = hex2rgb(["#2a78d6" "#eb6834" "#1baf7a" "#eda100" "#e87ba4"]);
ink      = [0.32 0.32 0.31];
c1 = modeClr(1,:);  c2 = modeClr(2,:);

%% 4. Figure 1 : 궤적 (운용 모드별 색) ----------------------------------
figure('Name','Trajectory','Color','w','Position',[80 80 760 680]);
ax = axes; hold(ax,'on');
opG = interp1(tM, op, tG, 'previous', 'extrap');
hMode = gobjects(0); lblMode = strings(0);
for k = 1:numel(modeId)
    m = double(opG == modeId(k));
    if ~any(m), continue; end
    m(m == 0) = NaN;
    hMode(end+1) = plot(ax, pE.*m, pN.*m, '-', 'LineWidth', 2, 'Color', modeClr(k,:)); %#ok<SAGROW>
    lblMode(end+1) = modeName(k);                                                     %#ok<SAGROW>
end
hWp = plot(ax, wpE, wpN, 'o', 'MarkerSize', 9, 'LineWidth', 1.5, 'Color', ink, 'MarkerFaceColor', 'w');
text(ax, wpE, wpN, "  WP" + string(wpNum), 'Color', ink, 'FontSize', 10);
hSt = plot(ax, pE(1), pN(1), 's', 'MarkerSize', 9, 'Color', ink, 'MarkerFaceColor', ink);
axis(ax,'equal'); grid(ax,'on'); ax.GridAlpha = 0.12; box(ax,'off');
xlabel(ax,'East [m]'); ylabel(ax,'North [m]');
legend(ax, [hMode hWp hSt], [lblMode "WP" "start"], 'Location','bestoutside', 'Box','off');

%% 5. Figure 2 : 시계열 --------------------------------------------------
figure('Name','Time history','Color','w','Position',[120 40 980 900]);
tl = tiledlayout(7,1,'TileSpacing','compact','Padding','compact');
axs = gobjects(7,1);

axs(1) = nexttile(tl);
stairs(tI, cIdx, 'LineWidth', 2, 'Color', c1);
ylabel('Curr\_idx'); yticks(1:max(cIdx)); ylim([0.5 max(cIdx)+0.5]);

axs(2) = nexttile(tl);
stairs(tM, op, 'LineWidth', 2, 'Color', c1);
ylabel('mode'); yticks(modeId); yticklabels(modeName); ylim([0.5 5.5]);

axs(3) = nexttile(tl);
plot(tL, u, 'LineWidth', 1.5, 'Color', c1);
ylabel('u [m/s]');

axs(4) = nexttile(tl);
plot(tL, psiDeg, 'LineWidth', 1.5, 'Color', c1);
ylabel('\psi [deg]');

axs(5) = nexttile(tl);
plot(tS, tauX, 'LineWidth', 1, 'Color', c1);
ylabel('\tau_X [N]');

axs(6) = nexttile(tl);
plot(tS, tauN, 'LineWidth', 1, 'Color', c1);
ylabel('\tau_N [N·m]');

axs(7) = nexttile(tl);
plot(tS, n1, 'LineWidth', 1, 'Color', c1); hold on;
plot(tS, n2, 'LineWidth', 1, 'Color', c2);
ylabel('n [rad/s]'); xlabel('time [s]');
lgM = legend('L_ Thruster','R_ Thruster','Orientation','horizontal','Box','off');
lgM.Layout.Tile = 'south';

for k = 1:numel(axs)
    grid(axs(k),'on'); axs(k).GridAlpha = 0.12; box(axs(k),'off');
    if k < numel(axs), axs(k).XTickLabel = []; end
end
linkaxes(axs,'x'); xlim(axs(1), [0 tM(end)]);

%% 6. Figure 3 : 도킹 구간 확대 -----------------------------------------
if any(op == 4)
    tD = [tM(find(op == 4, 1, 'first')), tM(find(op == 4, 1, 'last'))];
    win = tD + [-3 3];

    figure('Name','Docking','Color','w','Position',[160 60 1100 760]);
    tl3 = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

    % (왼쪽) 도킹 궤적과 flag 3 목표점
    axP = nexttile(tl3, 1, [3 1]); hold(axP,'on');
    iG = tG >= tD(1) & tG <= tD(2);
    hTr = plot(axP, pE(iG), pN(iG), '-', 'LineWidth', 2, 'Color', c1);
    i3  = dockFlag == 3;
    hLg = hTr; lg = "궤적";
    if any(i3)
        tgt = unique(round([wpOutE(i3) wpOutN(i3)], 3), 'rows', 'stable');
        hT = plot(axP, tgt(:,1), tgt(:,2), 'd', 'MarkerSize', 10, 'LineWidth', 1.5, 'Color', c2, 'MarkerFaceColor', 'w');
        hLg(end+1) = hT; lg(end+1) = "도킹 목표(경유/최종)";
    end
    axis(axP,'equal'); axis(axP,'padded'); grid(axP,'on'); axP.GridAlpha = 0.12; box(axP,'off');
    xlabel(axP,'East [m]'); ylabel(axP,'North [m]'); title(axP,'도킹 궤적');
    legend(axP, hLg, lg, 'Location','best','Box','off');

    % (오른쪽) flag / 검출 / 속도
    a1 = nexttile(tl3, 2);
    stairs(tM, dockFlag, 'LineWidth', 2, 'Color', c1);
    ylabel('docking flag'); yticks(1:4); ylim([0.5 4.5]); title('도킹 단계');

    a2 = nexttile(tl3, 4);
    stairs(tM, detectOn, 'LineWidth', 2, 'Color', c1); hold on;
    stairs(tM, detectValid, '--', 'LineWidth', 2, 'Color', c2);
    ylabel('0 / 1'); yticks([0 1]); ylim([-0.15 1.15]);
    legend('detect\_on','detect\_valid','Location','northwest','Box','off');

    a3 = nexttile(tl3, 6);
    plot(tL, u, 'LineWidth', 1.5, 'Color', c1);
    ylabel('u [m/s]'); xlabel('time [s]');

    for a = [a1 a2 a3]
        grid(a,'on'); a.GridAlpha = 0.12; box(a,'off');
    end
    linkaxes([a1 a2 a3],'x'); xlim(a1, win);
else
    fprintf('이 로그에는 Docking(operation_mode = 4) 구간이 없습니다.\n');
end

%% 로컬 함수 -------------------------------------------------------------
function tt = getTopic(ulog, name)
    msg = readTopicMsgs(ulog, 'TopicNames', {name});
    if isempty(msg) || height(msg) == 0
        error('토픽 %s 이(가) 로그에 없습니다.', name);
    end
    tt = msg.TopicMessages{1};
end

function rgb = hex2rgb(hex)
    h = char(extractAfter(hex(:), 1));
    rgb = reshape(sscanf(h', '%2x'), 3, [])' / 255;
end
