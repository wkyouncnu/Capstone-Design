function P = haeyang_points()
%HAEYANG_POINTS  해양누리공원 월드의 미션 지점 네 곳 — ENU · NED · 위도 · 경도
%
%   P = haeyang_points();      % table 로 돌려받는다
%   disp(P)
%
%   돌려주는 열
%     name   짧은 이름 (goto.sh 의 지점 이름과 같다)
%     desc   설명
%     x_e    Gazebo ENU 동쪽 [m]   (월드 원점 기준)
%     y_n    Gazebo ENU 북쪽 [m]
%     n_m    NED 북쪽 [m]  = y_n        ← 교과서 표기로는 x
%     e_m    NED 동쪽 [m]  = x_e        ← 교과서 표기로는 y
%     lat    위도 [deg]            lon  경도 [deg]
%
%   좌표의 출처
%     월드 원점과 지점의 ENU 좌표는 모두
%     60-텀프로젝트/TP_haeyang/make_haeyang_world.py 가 원본이다.
%     이 파일은 그 숫자를 **옮겨 적기만** 하고, 위도·경도는 아래 공식으로 계산한다.
%     값을 바꿀 일이 생기면 py 를 고치고 이 파일의 ENU 숫자를 맞춘다.
%
%   위도·경도 환산 (Gazebo SphericalCoordinates 와 같은 WGS84 국소 접평면)
%     자오선 곡률반경  M = a(1-e^2) / (1-e^2 sin^2 phi)^{3/2}
%     묘유선 곡률반경  N = a / (1-e^2 sin^2 phi)^{1/2}
%     위도 1 m  = 180/(pi M) deg,   경도 1 m = 180/(pi N cos phi) deg
%     원점 위도에서 위도 1 m = 9.0136e-06 deg, 경도 1 m = 1.0979e-05 deg
%     (= 위도 1 deg 110 944 m, 경도 1 deg 91 081 m)
%
%   실측 GPS 와의 차이
%     /wamv/sensors/gps/gps/fix 를 출발선에서 읽으면 이 표보다 1~2 m 어긋난다.
%     까닭 두 가지 — (1) GPS 안테나가 base_link 뒤 0.85 m · 위 1.3 m 에 있다
%     (2) 배를 풀어 두면 파도에 1~2 m 밀린다. 표는 **월드 좌표**의 정답이다.
%
%   함께 보는 것 :  run_map.m (위성지도에 찍는 예제) · goto.sh (같은 지점으로 순간이동)

%  월드 원점 — make_haeyang_world.py 의 LAT0 / LON0
lat0 = 35.1862095;
lon0 = 128.5665903;

%  지점 — make_haeyang_world.py 의 START · WP1 · WP2 · GATE_OUT 중앙
name = {'start'; 'wp1'; 'wp2'; 'goal'};
desc = { ...
    '출발점 — 빨강·초록 첫 게이트 사이 시작선 (선수 북)'; ...
    'WP1 — 게이트 통과 후 도킹 스테이션 앞 위치유지점'; ...
    'WP2 — 탐색 선회를 마치고 충돌회피 진입 전 DP 위치유지점'; ...
    '종료점 — 충돌회피를 마치고 나오는 종료 게이트 중앙'};
x_e = [  0.0;   0.0; -20.0; -70.0];      % ENU 동쪽 [m]
y_n = [-32.0;  10.0; -14.0; -39.0];      % ENU 북쪽 [m]

%  WGS84 곡률반경
a  = 6378137.0;                  % 장반경 [m]
f  = 1/298.257223563;            % 편평률
e2 = f*(2-f);
phi = deg2rad(lat0);
W  = 1 - e2*sin(phi)^2;
M  = a*(1-e2)/W^1.5;             % 자오선 곡률반경 [m]
N  = a/sqrt(W);                  % 묘유선 곡률반경 [m]

degPerM_lat = rad2deg(1/M);
degPerM_lon = rad2deg(1/(N*cos(phi)));

%  NED — 북이 앞, 동이 오른쪽. ENU 와 축 이름만 바뀐다 (원점은 같다)
n_m = y_n;
e_m = x_e;

lat = lat0 + n_m*degPerM_lat;
lon = lon0 + e_m*degPerM_lon;

P = table(name, x_e, y_n, n_m, e_m, lat, lon, desc);
P.Properties.VariableUnits = {'', 'm', 'm', 'm', 'm', 'deg', 'deg', ''};
P.Properties.UserData = struct('lat0', lat0, 'lon0', lon0, ...
                               'degPerM_lat', degPerM_lat, ...
                               'degPerM_lon', degPerM_lon, ...
                               'world', 'haeyangnuri');
end
