close all;

% === 목표 위치 및 자세 설정 ===
x_d = x_dock;         % 목표 x위치 (North)
y_d = y_dock;         % 목표 y위치 (East)
psi_d = psi_ref_deg;  % 목표 heading (rad)
time = simout.tout;

% === 선박 기본 형상 정의 (house shape, 선수 방향 = +x = North) ===
scale_factor = 0.5;
original_shape_x = [-1 1 2 1 -1 -1];    % 앞뒤 (x: North)
original_shape_y = [-1 -1 0 1 1 -1];    % 좌우 (y: East)

% === 목표 위치의 선박 형상 회전 및 이동 (시계방향 회전) ===
R_goal = [cosd(psi_d), -sind(psi_d);
         sind(psi_d), cosd(psi_d)];
goal_shape = R_goal * [original_shape_x; original_shape_y];

goal_x = goal_shape(1,:) * scale_factor + x_d;  % North
goal_y = goal_shape(2,:) * scale_factor + y_d;  % East

% === 시각화 설정 ===
figure(); hold on; axis equal; grid on;
xlabel('y (m)'); ylabel('x (m)');  % y: East, x: North
plot(goal_y, goal_x, 'r-', 'LineWidth', 1.5);  % 목표 위치 선박 형상

trajectory_line = plot(nan, nan, 'b-', 'LineWidth', 1.5); % 경로 추적
current_marker = plot(nan, nan, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k'); % 현재 위치 점

% === 초기 위치 선박 형상 표시 (heading = 0이면 North를 바라봄) ===
R_init = [cos(0), sin(0); -sin(0), cos(0)];
init_shape = R_init * [original_shape_x; original_shape_y];
init_x = init_shape(1,:) * scale_factor;
init_y = init_shape(2,:) * scale_factor;
ship_outline = plot(init_y, init_x, 'm-', 'LineWidth', 2);  % 초기 위치 선박 형상
% center_x, center_y, orientation_deg, width, height, thickness
drawDockingStation(y_dock, x_dock, psi_ref_deg + 90, 5, 4.5, 1.2);     % 북쪽

pause(1);

% === 실시간 시각화 루프 ===
for t_idx = 1:length(time)
    if mod(time(t_idx), 5) == 0
        x = simout.y_out(t_idx,4);   % North
        y = simout.y_out(t_idx,5);   % East
        psi = simout.y_out(t_idx,6); % Heading (rad)

        % 실시간 위치 경로 점 찍기
        scatter(y, x, "blue", ".");

        % 선박 형상 회전 및 이동
        R = [cos(psi), -sin(psi); 
             sin(psi), cos(psi)];  % 시계방향 회전
        ship_shape = R * [original_shape_x; original_shape_y];
        ship_x = ship_shape(1,:) * scale_factor + x;
        ship_y = ship_shape(2,:) * scale_factor + y;

        % 시각화 업데이트
        set(ship_outline, 'XData', ship_y, 'YData', ship_x);
        set(trajectory_line, 'XData', simout.y_out(1:t_idx,5), ...
                              'YData', simout.y_out(1:t_idx,4));
        set(current_marker, 'XData', y, 'YData', x);

        pause(0.1);
        drawnow limitrate;
    end
end

% === 최종 오차 출력 ===
x_final = simout.y_out(end, 4);
y_final = simout.y_out(end, 5);
psi_final = simout.y_out(end, 6);

fprintf('최종 도달 위치: x = %.2f, y = %.2f, psi = %.2f deg\n', ...
    x_final, y_final, rad2deg(wrapToPi(psi_final)));
fprintf('목표 위치: x = %.2f, y = %.2f, psi = %.2f deg\n', ...
    x_d, y_d, psi_d);
fprintf('위치 오차: dx = %.2f m, dy = %.2f m, dpsi = %.2f deg\n', ...
    x_final - x_d, y_final - y_d, psi_d - rad2deg(wrapToPi(psi_final)));
