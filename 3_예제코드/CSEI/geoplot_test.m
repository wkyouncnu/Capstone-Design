clc; clear all; close all;

figure(1)
LatLimits = [35.4687   35.4743];
LonLimits = [129.4100  129.4217];
geobasemap satellite;
geolimits(LatLimits, LonLimits);
hold on;



% 기준점 (위도, 경도, 고도)
refLat = LatLimits(1); 
refLon = LonLimits(1);
refAlt = 0;

[waypoint_lat, waypoint_lon] = ginput(1);

% 클릭 지점 -> NED 좌표계 변환
origin = [refLat, refLon, refAlt];
Lat_Lon_max = [LatLimits(1), LatLimits(2), 
    ]

ned_max = lla2ned(target, origin, 'flat');


target = [waypoint_lat, waypoint_lon, 0];
ned_center = lla2ned(target, origin, 'flat');

% NED 좌표계에서 반지름 r인 원 만들기
r = 30; % meter
N = 100;
theta = linspace(0, 2*pi, N);
x_ned = ned_center(2) + r * cos(theta); % East
y_ned = ned_center(1) + r * sin(theta); % North
z_ned = zeros(1, N);

% 다시 위도 경도로 변환
ned_circle = [y_ned(:), x_ned(:), z_ned(:)];
lla_circle = ned2lla(ned_circle, origin, 'flat');
geoplot(lla_circle(:,1), lla_circle(:,2), 'r-', 'LineWidth', 2)


% NED 좌표계 시각화
figure(2)
plot(x_ned, y_ned, 'r-', 'LineWidth', 2); axis equal; grid on;
xlabel('East [m]'); ylabel('North [m]')
title('NED 좌표계에서 반지름 30m 원')
hold on; plot(ned_center(2), ned_center(1), 'go', 'MarkerSize', 8)
legend('원 경계', '중심점')

return;



% 위성 지도 띄우기
figure(1)
gx = geoaxes;
geobasemap(gx, 'satellite');
title('Click on the map (1 point)')
disp('Click a point on the map...')

% 사용자 클릭 (위도 경도를 직접 얻음)
[lat_click, lon_click] = ginputGeo(gx);

% 클릭 좌표 표시
hold(gx, 'on');
geoplot(gx, lat_click, lon_click, 'go', 'MarkerSize', 8, 'LineWidth', 2)

% 클릭 지점 -> NED 좌표계 변환
origin = [refLat, refLon, refAlt];
target = [lat_click, lon_click, 0];
ned_center = lla2ned(target, origin, 'flat');

% NED 좌표계에서 반지름 r인 원 만들기
r = 100; % meter
N = 100;
theta = linspace(0, 2*pi, N);
x_ned = ned_center(2) + r * cos(theta); % East
y_ned = ned_center(1) + r * sin(theta); % North
z_ned = zeros(1, N);

% 다시 위도 경도로 변환
ned_circle = [y_ned(:), x_ned(:), z_ned(:)];
lla_circle = ned2lla(ned_circle, origin, 'flat');

% 위성 지도에 원 표시
geoplot(gx, lla_circle(:,1), lla_circle(:,2), 'r-', 'LineWidth', 2)
legend(gx, '클릭 지점', '반지름 100m 원')

% NED 좌표계 시각화
figure(2)
plot(x_ned, y_ned, 'r-', 'LineWidth', 2); axis equal; grid on;
xlabel('East [m]'); ylabel('North [m]')
title('NED 좌표계에서 반지름 100m 원')
hold on; plot(ned_center(2), ned_center(1), 'go', 'MarkerSize', 8)
legend('원 경계', '중심점')


% ===== 보조 함수: ginputGeo =====
function [lat, lon] = ginputGeo(gx)
    % geoaxes에서 마우스로 클릭한 위도/경도를 얻는 함수
    try
        [x, y] = ginput(1); % Figure 좌표
        cp = get(gx, 'CurrentPoint'); % 위도 경도 값 포함된 행렬
        lat = cp(1,1);
        lon = cp(1,2);
    catch
        error('ginputGeo 실패: geoaxes를 사용 중인지 확인하세요.')
    end
end
