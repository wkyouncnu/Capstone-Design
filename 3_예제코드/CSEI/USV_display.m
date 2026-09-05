  
function USV_display(uu)
    x = uu(1);
    y = uu(2);
    psi = uu(3);
    time = uu(4);

    margin = 5; % 시야 여유 공간

    % 선박 외형 정의 (북쪽을 향하도록 설정)
    scale_factor = 0.5;   
    % 기존 선박 모양을 -90도 회전시켜 북쪽(x축) 향하도록 수정
    original_shape_x = [-1 -1 0 1 1 -1];
    original_shape_y = [-1 1 2 1 -1 -1];
    R_init = [cosd(-90), -sind(-90); 
              sind(-90),  cosd(-90)];
    rotated_shape = R_init * [original_shape_x; original_shape_y];
    base_shape_x = rotated_shape(1, :) * scale_factor;
    base_shape_y = rotated_shape(2, :) * scale_factor;

    persistent ship_outline current_position_marker    
    
    if time==0       
        figure(1)
        subplot(121)
        hold on
        scatter(y,x,"blue", "."	);
        axis equal
        xlabel('y (m)');
        ylabel('x (m)'); grid on;

        subplot(122)
        hold on;
        scatter(y,x,"blue", "."	);
        ship_outline = plot(base_shape_x, base_shape_y, 'r-', 'LineWidth', 2); % 초기 선박 외곽선
        current_position_marker = plot(nan, nan, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k'); % 현재 위치       
        axis equal
        xlabel('y (m)');
        ylabel('x (m)'); grid on;
        xlim([x - margin, x + margin]);
        ylim([y - margin, y + margin]);
    end
        subplot(121)
        scatter(y,x,"blue", ".");
        R = [cos(psi), -sin(psi); 
             sin(psi),  cos(psi)];
        rotated_coords = R * [base_shape_x; base_shape_y];
        translated_x = rotated_coords(1, :) + x; % North
        translated_y = rotated_coords(2, :) + y; % East

        subplot(122)
        set(ship_outline, 'XData', translated_y, 'YData', translated_x);
        set(current_position_marker, 'XData', y, 'YData', x);
        scatter(y,x,"blue", "."	);
        xlim([y - margin, y + margin]);
        ylim([x - margin, x + margin]);
        drawnow

end
