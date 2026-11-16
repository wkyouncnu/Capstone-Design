% % 서울 근방의 위도와 경도 데이터 예시
% lat = [37.5665, 37.5700]; 
% lon = [126.9780, 126.9850];
% 
% % 지리 좌표에 선이나 점 플로팅
% geoplot(lat, lon, 'r-o', 'LineWidth', 2);
% 
% % 바탕 지도를 위성(satellite)으로 설정
% geobasemap satellite;


% geolimits([37.50 37.56], [126.90 126.98]);

bottom_right = [36.37219099023038, 127.39407910246837];
up_right     = [36.37363261948452, 127.39415323596059];
up_left      = [36.37378965672932, 127.37904318622378];
botton_left  = [36.37173515842844, 127.37898864551128]; 

figure(1)
LatLimits = [36.37173515842844  36.37378965672932];
LonLimits = [127.37898864551128  127.39415323596059];
geobasemap satellite;
geolimits(LatLimits, LonLimits);
hold on;

% 키보드 입력을 2개를 받아, 첫번째 위도/경도는 초기점 lla0로 저장
% 두번째 위도/경도는 목표점으로 저장하여 NED 좌표계로 변환하기 
[lat, lon] = ginput(2)

lla0 = [lat(1), lon(1), 0]; % 첫번째 클릭한 점 (원점)
lla = [lat(2), lon(2), 0];  % 두번째 클릭한 점

geoscatter(lla0(1), lla0(2), 110, 'w', 'filled');  % 첫번째 클릭한 점 (원점)
geoscatter(lla(1), lla(2), 110, 'r', 'filled'); % 두번째 클릭한 점

% lla0를 원점으로, lla의 ned 좌표를 계산하기 
ned = lla2ned(lla, lla0, 'flat')

% ned를 다시 위도/경도/고도로 변환하여 
% lla = [lat(2), lon(2), 0]이 나오는지 확인하기

lla2 = ned2lla(ned, lla0, 'flat')
lla

lla - lla2