clc; close all; clear all;


    
figure(1)
LatLimits = [36.371961 36.374161];
LonLimits = [127.384273 127.393020];
geobasemap satellite;
geolimits(LatLimits, LonLimits);
hold on;

% 위도, 경도 좌표계 입력 받기
[lat, Lon] = ginput(1);
origin = [LatLimits(1), LonLimits(1), 0];
target = [lat, Lon, 0];

NED_center = lla2ned(target, origin, 'flat');

%% NED 좌표계에서 원 계산
r = 30;
N = 100;
theta = linspace(0, 2*pi, N);
x_ned = NED_center(1) + r*cos(theta);
y_ned = NED_center(2) + r*sin(theta);
z_ned = zeros(1,N);

ned_circle = [x_ned(:), y_ned(:), z_ned(:)];

%% USV 
L = 5;
B = 2;
vehx = L*[0.5,1,0.5,-1,-1,0.5]';
vehy = B*[1,0,-1,-1,1,1]';

psi = deg2rad(50); 
veh_x = NED_center(1);
veh_y = NED_center(2);
veh_psi = psi;

posx = veh_x + vehx*cos(veh_psi) - vehy*sin(veh_psi);
posy = veh_y + vehx*sin(veh_psi) + vehy*cos(veh_psi);

xyzNED = [posx posy 0*ones(length(posx),1)];

lla = ned2lla(xyzNED, origin, 'flat');
Lat = lla(:,1);
Lon = lla(:,2);
geoplot(Lat, Lon, 'w-', 'LineWidth', 1); 
%% NED원을 위도, 경도, 고도로 변환
lla_circle = ned2lla(ned_circle, origin, 'flat');
geoplot(lla_circle(:,1), lla_circle(:,2), 'r-', 'LineWidth', 2);
% LLA_target = ned2lla(NED_target, origin, 'flat');

lat_lon_max = [LatLimits(2), LonLimits(2), 0];
ned_max = lla2ned(lat_lon_max, origin, 'flat');

figure(2)
plot(y_ned, x_ned, 'r-', 'LineWidth', 2); axis equal; grid on;
xlabel('East [m]'); ylabel('North [m]');
hold on; 
plot(NED_center(2), NED_center(1), 'x', 'MarkerSize', 5);
xlim([0 ned_max(2)]);
ylim([0 ned_max(1)]);



