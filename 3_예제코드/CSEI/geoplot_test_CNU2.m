clc; close all; clear all;

figure(1)
LatLimits = [36.371463  36.374004]; 
LonLimits = [127.384836 127.392925];
geobasemap satellite;
geolimits(LatLimits, LonLimits);
hold on;
%% Obtain the centor location of circle in LLA frame using ginput
% Lat, Lon is the center position of circle in LLA frame
[Lat, Lon] = ginput(1);
origin = [LatLimits(1), LonLimits(1), 0];
target = [Lat, Lon, 0];

% NED center is the center position of circle in NED frame
NED_center = lla2ned(target, origin,'flat');

%% Circle compuation in NED frame
r = 10; % radius
N = 100;
theta = linspace(0, 2*pi, N);
x_ned = NED_center(1) + r*cos(theta);
y_ned = NED_center(2) + r*sin(theta);
z_ned = zeros(1,N);

ned_circle = [x_ned(:), y_ned(:), z_ned(:)];

%% Convert the circle in NED to LLA frame
lla_circle = ned2lla(ned_circle, origin, 'flat');
% draw circle in LLA frame
geoplot(lla_circle(:,1), lla_circle(:,2), 'r-', 'LineWidth', 2);
% draw the centor point frame
geoplot(Lat, Lon, 'go', 'MarkerSize', 5, 'MarkerFaceColor', 'g');

lat_lon_max = [LatLimits(2), LonLimits(2), 0];
ned_max = lla2ned(lat_lon_max, origin, 'flat');

%% Plot the USV in LLA frame
L = 5; % Length of USV [m]
B = 2; % Width of USV [m];
vehx = L*[0.5,1,0.5,-1,-1,0.5]';
vehy = B*[1,0,-1,-1,1,1]';

psi = deg2rad(-90); % heading in radian
veh_x = NED_center(1);
veh_y = NED_center(2);
veh_psi = psi;

% posx, posy
posx = veh_x + vehx*cos(veh_psi) - vehy*sin(veh_psi);
posy = veh_y + vehx*sin(veh_psi) + vehy*cos(veh_psi);

% ship_NED is the USV position (heading) in NED frame
ship_NED = [posx posy 0*ones(length(posx), 1)];

% lla_ship is the USV position (heaidng) in LLA frame
lla_ship = ned2lla(ship_NED, origin, 'flat');
geoplot(lla_ship(:,1), lla_ship(:,2), 'w-', 'LineWidth', 1); % USB plot in LLA frame
%% Plot the circle in NED frame
figure(2)
plot(y_ned, x_ned, 'r-', 'LineWidth', 2); axis equal; grid on; hold on;
plot(posy, posx, 'b-', 'LineWidth', 2);  % USV plot in NED frame
xlabel(' East [m]'); ylabel(' North [m]');
plot(NED_center(2), NED_center(1), 'x', 'MarkerSize', 5);
xlim([0 ned_max(2)]);
ylim([0 ned_max(1)]);



