% W05_AIM_DEMO  웨이포인트를 곧장 겨냥하면 경로를 따라가는가.
%
%   >> W05_setup
%   >> W05_aim_demo
%
%   묻는 것
%     atan2 유도는 **다음 웨이포인트라는 점**을 겨냥한다. 점까지의 거리는
%     줄지만, 그 점을 잇는 **선**까지의 거리도 줄어드는가.
%
%   어떻게 보이는가
%     경로를 북쪽으로 곧게 편다 (웨이포인트 N = 0, 100, 200, 300 m, E = 0).
%     배는 경로에서 동쪽으로 20 m 벗어난 자리에서 출발한다. 유도법칙만
%     atan2 와 LOS 로 바꿔 두 번 돌린다. 나머지 값은 손대지 않는다.
%
%   읽을 것
%     - atan2 는 경로에 **웨이포인트에서야** 닿는다. 북쪽 50 m 에서도 아직
%       크게 벗어나 있다. 점을 겨냥하기 때문이다.
%     - LOS 는 그 전에 이미 경로에 붙는다. 선을 겨냥하기 때문이다.
%     - 첫 웨이포인트를 지난 뒤에는 둘 다 경로 위를 간다. 차이는 **구간
%       중간**에서만 드러난다.
%
%   같은 실험이 대학원 과목 "센서신호처리 및 융합" W05 실험 5-2 에 있다.
%   그쪽은 모델이 다르므로 수치는 같지 않다. 보이는 성질이 같은지를 본다.
%
%   만드는 것: img/W05_aim_demo.png

setappdata(0, 'W05_skip_run', true);   % 설정 파일의 자동 실행은 건너뛴다
W05_setup;
animate = 0;                           %#ok<NASGU>  두 번 연달아 돌리므로 그림은 끈다

%% 시나리오 — 북쪽으로 곧은 경로, 경로에서 동쪽 20 m 에서 출발 -------
%  사각형 경로로는 선회가 섞여 "점이냐 선이냐" 가 묻히므로 한 직선만 쓴다.
wp_north = [0 100 200 300];            %#ok<NASGU>  웨이포인트 x (북쪽) [m]
wp_east  = [0   0   0   0];            %#ok<NASGU>  웨이포인트 y (동쪽) [m]

current_speed = 0;                     %#ok<NASGU>  조류는 끈다 — 변수는 유도법칙 하나뿐
x0 = [0.1; 0; 0; 0; 20; 0];            %#ok<NASGU>  [u v r N E psi], 동쪽 20 m, 선수 북
T_sim = 300;                           % 실행 시간 [s]

LAWS = {1, 'atan2'; 2, 'LOS'};
COL  = [0 0.45 0.74; 0.85 0.33 0.10];
load_system('W05_0_offline');

res = struct([]);
for i = 1:size(LAWS,1)
    guidance_mode = LAWS{i,1};         %#ok<NASGU>  바꾸는 것은 이 한 줄뿐
    out = sim('W05_0_offline', 'StopTime', num2str(T_sim));

    res(i).name = LAWS{i,2};
    res(i).N    = out.log_x_n.Data;
    res(i).E    = out.log_y_n.Data;
    res(i).ye   = out.log_y_e.Data;
end

%% 북쪽으로 50, 100, 150 m 갔을 때의 경로 이탈량 ----------------------
%  interp1(북쪽 위치, 이탈량, 50) = 배가 북쪽 50 m 에 있을 때의 이탈량.
%  북쪽 위치는 단조증가해야 보간이 되므로 그 구간만 잘라 쓴다.
MARK = [50 100 150];
fprintf('\n===== 점을 겨냥할 때와 선을 겨냥할 때 (경로에서 20 m 벗어난 채 출발) =====\n');
fprintf('%8s %13s %13s %13s\n', '유도', 'y_e @ 50m', 'y_e @ 100m', 'y_e @ 150m');
for i = 1:numel(res)
    n = res(i).N;  k = find(diff(n) <= 0, 1);
    if isempty(k), k = numel(n); end
    v = interp1(n(1:k), res(i).ye(1:k), MARK);
    fprintf('%8s %13.2f %13.2f %13.2f\n', res(i).name, v(1), v(2), v(3));
    res(i).mark = v;
end
fprintf('\natan2 는 점까지의 거리를 줄일 뿐이므로 구간 중간에서 선에 붙지 못한다.\n');

%% 그림 --------------------------------------------------------------
h = figure('Name','W05  점을 겨냥할 때와 선을 겨냥할 때', ...
           'Position',[80 80 1180 520], 'Color','w');

% ---- 왼쪽: 항적 -----------------------------------------------------
subplot(1,3,1); hold on; grid on; box on; axis equal;
plot([0 0], [0 300], 'k--', 'LineWidth', 1.2, 'DisplayName','계획 경로');
for i = 1:numel(res)
    plot(res(i).E, res(i).N, 'LineWidth', 1.8, 'Color', COL(i,:), ...
         'DisplayName', res(i).name);
end
plot(0, 100, 'ko', 'MarkerFaceColor','k', 'MarkerSize', 6, 'HandleVisibility','off');
text(1.5, 95, '웨이포인트', 'FontSize', 9);   % 범례와 겹치지 않게 아래쪽에 둔다
xlim([-10 30]); ylim([0 120]);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title('항적'); legend('Location','northeast');

% ---- 오른쪽: 경로 이탈량 --------------------------------------------
subplot(1,3,[2 3]); hold on; grid on; box on;
yline(0, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
for i = 1:numel(res)
    n = res(i).N;  k = find(diff(n) <= 0, 1);
    if isempty(k), k = numel(n); end
    plot(n(1:k), res(i).ye(1:k), 'LineWidth', 1.8, 'Color', COL(i,:), ...
         'DisplayName', res(i).name);
end
xlim([0 200]); xlabel('북쪽으로 간 거리 [m]'); ylabel('경로 이탈량  y_e  [m]');
title('atan2 는 웨이포인트에 가서야 경로에 닿는다');
legend('Location','northeast');

d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, 'W05_aim_demo.png'), 'Resolution', 130);
fprintf('그림: img/W05_aim_demo.png\n');
