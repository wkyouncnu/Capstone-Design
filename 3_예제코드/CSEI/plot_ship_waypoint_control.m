time = simout.tout;

% 선박 외형 정의 (북쪽을 향하도록 설정)
scale_factor = 0.5;
original_shape_x = [-1 -1 0 1 1 -1];
original_shape_y = [-1 1 2 1 -1 -1];
R_init = [cosd(-90), -sind(-90);
          sind(-90),  cosd(-90)];
rotated_shape = R_init * [original_shape_x; original_shape_y];
base_shape_x = rotated_shape(1, :) * scale_factor;
base_shape_y = rotated_shape(2, :) * scale_factor;

% 초기 위치
y_init = simout.y_out(1,5);
x_init = simout.y_out(1,4);

% Figure 및 subplot 생성
figure('Name', 'USV Waypoint Following Visualization');
sgtitle('USV Path Visualization');

% 왼쪽: 전체 경로 뷰
ax_left = subplot(1,2,1);
hold(ax_left, 'on');
title(ax_left, '전체 항적 및 웨이포인트');
scatter(ax_left, y_init, x_init, "blue", ".");
if ~isempty(wp_north)
    plot(ax_left, wp_east, wp_north, 'rx', 'LineWidth', 2);
end
% center_x, center_y, orientation_deg, width, height, thickness
drawDockingStation_axis(ax_left, 50, 40 + 5, 0, 10, 10, 2);     % 북쪽
axis(ax_left, 'equal');
xlabel(ax_left, 'y (m)');
ylabel(ax_left, 'x (m)');
grid(ax_left, 'on');

% 오른쪽: 확대된 현재 위치 뷰
ax_right = subplot(1,2,2);
hold(ax_right, 'on');
title(ax_right, '현재 위치 확대 뷰');
axis(ax_right, 'equal');
grid(ax_right, 'on');
trajectory_line = plot(ax_right, nan, nan, 'b-', 'LineWidth', 1.5);
if ~isempty(wp_north)
    plot(ax_right, wp_east, wp_north, 'rx', 'LineWidth', 2);
end
current_position_marker = plot(ax_right, nan, nan, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k');
ship_outline = plot(ax_right, base_shape_x, base_shape_y, 'm-', 'LineWidth', 2);
drawDockingStation_axis(ax_right, 50, 40 + 5, 0, 10, 10, 2);     % 북쪽
xlabel(ax_right, 'y (m)');
ylabel(ax_right, 'x (m)');
legend(ax_right, 'Trajectory','Waypoint', 'USV');

% 비디오 설정
% myVideo = VideoWriter('Waypoint_following');
% myVideo.FrameRate = 10;
% open(myVideo);

% 시야 여유
margin = 5;

% 실시간 루프
for t_idx = 1:length(time)
    if mod(time(t_idx), 2) == 0
        x = simout.y_out(t_idx,4);  
        y = simout.y_out(t_idx,5);  
        psi = simout.y_out(t_idx,6); 

        % 왼쪽 subplot: 전체 항적 업데이트
        scatter(ax_left, y, x, "blue", ".");

        % 오른쪽 subplot: 확대 뷰
        R = [cos(psi), -sin(psi); 
             sin(psi),  cos(psi)];
        rotated_coords = R * [base_shape_x; base_shape_y];
        translated_x = rotated_coords(1, :) + x;
        translated_y = rotated_coords(2, :) + y;

        set(ship_outline, 'XData', translated_y, 'YData', translated_x);
        set(trajectory_line, 'XData', simout.y_out(1:t_idx,5), 'YData', simout.y_out(1:t_idx,4));
        set(current_position_marker, 'XData', y, 'YData', x);

        xlim(ax_right, [y - margin, y + margin]);
        ylim(ax_right, [x - margin, x + margin]);
        
        pause(0.1);
        % frame = getframe(gcf);
        % writeVideo(myVideo, frame);
        drawnow limitrate;
    end
end

% close(myVideo);
