clc; clear all; close all;

% 선박 외형 정의 (북쪽을 향하도록 설정)
scale_factor = 0.2;

% 기존 선박 모양을 -90도 회전시켜 북쪽(x축) 향하도록 수정
original_shape_x = [-1 -1 0 1 1 -1];
original_shape_y = [-1 1 2 1 -1 -1];
R_init = [cosd(-90), -sind(-90); 
          sind(-90),  cosd(-90)];
rotated_shape = R_init * [original_shape_x; original_shape_y];

base_shape_x = rotated_shape(1, :) * scale_factor;
base_shape_y = rotated_shape(2, :) * scale_factor;

% 선박 위치
x = 0; % North
y = 0; % East

% heading 각도 (시계방향이 양의 방향, NED 기준)
psi_deg = 45;
psi = deg2rad(psi_deg);

% 회전 행렬 (시계방향 회전)
R = [cos(psi), -sin(psi); 
     sin(psi),  cos(psi)];

% 회전 및 위치 이동 적용
rotated_coords = R * [base_shape_x; base_shape_y];
translated_x = rotated_coords(1, :) + x; % North
translated_y = rotated_coords(2, :) + y; % East

% 시각화
figure()
hold on
scatter(y, x, "blue", "."); % 중심 위치 (East, North)
ship_outline = plot(base_shape_x, base_shape_y, 'r-', 'LineWidth', 2);
set(ship_outline, 'XData', translated_y, 'YData', translated_x); % (East, North)
xlim([-1 1]); ylim([-1 1]);

axis equal
xlabel('East (m)');
ylabel('North (m)');
title(['Heading = ', num2str(psi_deg), '° (NED 기준)']);
grid on;

