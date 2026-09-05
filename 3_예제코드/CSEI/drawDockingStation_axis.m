function drawDockingStation_axis(axis, center_x, center_y, orientation_deg, width, height, thickness)

% 중심 좌표 기준으로 도킹 스테이션을 그림
% 텍스트: (North, East, Heading) = (y, x, deg)

% 구조물 매개변수
W = width;
H = height;
T = thickness;

% 도형 정의 (입구가 위쪽인 U자형, 중심 기준)
shape = [ ...
    -W/2,   H/2;
    -W/2,  -H/2;
    -W/2+T, -H/2;
    -W/2+T,  H/2-T;
     W/2-T,  H/2-T;
     W/2-T, -H/2;
     W/2,  -H/2;
     W/2,   H/2;
    -W/2,   H/2];

% 회전 (NED 기준 → 시계방향)
theta = deg2rad(-orientation_deg);
R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
rotated_shape = (R * shape')';

% 평행이동
translated_shape = rotated_shape + [center_x, center_y];

% 도형 그리기
fill(translated_shape(:,1), translated_shape(:,2), [0.2 0.2 0.2], ...
     'DisplayName', 'Docking Position');

% 중심점 빨간 원
plot(axis, center_x, center_y, 'ro', 'LineWidth', 1.5, 'MarkerSize', 6);

% 중심점 바로 위 텍스트 (5m 위로 오프셋)
text_offset = 5;
text(center_x, center_y + text_offset, ...
    sprintf('(%dm, %dm, %d deg)', round(center_y), round(center_x), mod(orientation_deg, 360)), ...
    'Color', 'red', 'FontSize', 9, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
end
