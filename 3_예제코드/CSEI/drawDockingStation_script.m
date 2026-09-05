close all; clear all;
figure; 
hold on; axis equal; grid on;
xlabel('East (m)'); ylabel('North (m)');
title('USV Docking Station Example');

% center_x, center_y, orientation_deg, width, height, thickness
drawDockingStation(150, 440, 0, 30, 15, 5);     % 북쪽
drawDockingStation(150, 360, 180, 30, 15, 5);   % 남쪽
drawDockingStation(100, 400, 90, 30, 15, 5);    % 동쪽
drawDockingStation(200, 400, 270, 30, 15, 5);   % 서쪽