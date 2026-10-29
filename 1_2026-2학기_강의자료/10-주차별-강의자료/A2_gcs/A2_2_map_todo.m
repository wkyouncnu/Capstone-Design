% A2_2_MAP_TODO  2단 — 위성지도를 띄우고 기준점을 찍는다 (학생용)
%
%   TODO 두 군데. A2_openmap 을 쓰지 않고 직접 축을 만들어 본다
%
%   >> A2_2_map_todo

A2_setup;

fprintf('\n=== 2단 · 위성지도와 기준점 ===\n\n');

%% 1. 지도 범위를 좌표 변환으로 구한다
% TODO 1 ------------------------------------------------------------
%   기준점에서 남서로 map_span_m, 북동으로 map_span_m 떨어진
%   두 꼭짓점의 위경도를 구할 것
%   힌트 : ned2lla([-map_span_m -map_span_m 0], lla0, 'flat')
sw = [];                                 % <-- 채운다 (1x3)
ne = [];                                 % <-- 채운다 (1x3)
% -------------------------------------------------------------------
if isempty(sw) || isempty(ne), error('A2:todo', 'TODO 1 을 먼저 채울 것'); end

f  = figure('Name', '2단 — 기준점', 'NumberTitle', 'off', 'Color', 'w');
gx = geoaxes(f);
geolimits(gx, [sw(1) ne(1)], [sw(2) ne(2)]);
geobasemap(gx, basemap_name);        % 인터넷이 없으면 A2_setup 에서 darkwater 로
hold(gx, 'on');
drawnow;

%% 2. 기준점 표시
% TODO 2 ------------------------------------------------------------
%   기준점 위치에 흰 점을 하나 찍을 것
%   힌트 : geoscatter(gx, 위도, 경도, 110, 'w', 'filled')
%   주의 : geoscatter 는 (위도, 경도) 순서다. (x, y) 가 아니다
% -------------------------------------------------------------------
drawnow;

%% 3. 요청 범위 vs 실제 범위 — 되읽어 본다
[LA, LO] = geolimits(gx);
fprintf('[1] 지도 범위\n');
fprintf('  요청 위도 : [%.6f  %.6f]\n', sw(1), ne(1));
fprintf('  실제 위도 : [%.6f  %.6f]\n', LA(1), LA(2));
fprintf('  요청 경도 : [%.6f  %.6f]\n', sw(2), ne(2));
fprintf('  실제 경도 : [%.6f  %.6f]\n', LO(1), LO(2));
fprintf('  -> 두 값이 다르면 정상이다. 왜 그런지 문서에서 확인할 것\n');

fprintf('\n=== 2단 끝 ===\n');
