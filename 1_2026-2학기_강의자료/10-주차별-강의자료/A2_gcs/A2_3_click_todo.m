% A2_3_CLICK_TODO  3단 — 지도를 클릭해 웨이포인트를 만든다 (학생용)
%
%   TODO 세 군데
%
%   >> A2_3_click_todo

A2_setup;

N_WP = 3;

fprintf('\n=== 3단 · 지도를 클릭해 웨이포인트 만들기 ===\n\n');

gx = A2_openmap(lla0, map_span_m, basemap_name, ...
                sprintf('3단 — 웨이포인트 %d 개를 클릭할 것', N_WP));
geoscatter(gx, lla0(1), lla0(2), 110, 'w', 'filled', ...
           'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
drawnow;

fprintf('지도 위에서 웨이포인트 %d 개를 차례로 클릭할 것\n\n', N_WP);

wp_lla = zeros(N_WP, 3);
for k = 1:N_WP
    % TODO 1 --------------------------------------------------------
    %   클릭 한 번을 받아 lat, lon 에 담을 것
    %   힌트 : [lat, lon] = ginput(1)
    %   주의 : 지리축에서는 첫 번째 출력이 위도다. x 가 아니다
    lat = NaN;  lon = NaN;               % <-- 채운다
    % ---------------------------------------------------------------
    if isnan(lat) || isnan(lon), error('A2:todo', 'TODO 1 을 먼저 채울 것'); end

    wp_lla(k,:) = [lat, lon, 0];
    geoscatter(gx, lat, lon, 80, 'r', 'filled');
    text(gx, lat, lon, sprintf('  %d', k), ...
         'Color', 'r', 'FontWeight', 'bold', 'FontSize', 12);
    drawnow;
    fprintf('  %d 번째 클릭 : %.7f , %.7f\n', k, lat, lon);
end

%% 위경도를 NED 로 내린다
% TODO 2 ------------------------------------------------------------
%   wp_lla (N x 3) 를 한 번에 NED 로 내릴 것. 반복문을 쓰지 않는다
%   힌트 : lla2ned 는 N x 3 입력을 그대로 받는다
wp_ned = [];                             % <-- 채운다 (N x 3)
% -------------------------------------------------------------------
if isempty(wp_ned), error('A2:todo', 'TODO 2 를 먼저 채울 것'); end

wp_north = wp_ned(:,1).';
wp_east  = wp_ned(:,2).';

%% 저장 — 뒤 단계가 이 파일을 읽는다
% TODO 3 ------------------------------------------------------------
%   wp_lla 와 lla0 을 mission_file 에 저장할 것
%   힌트 : save(mission_file, 'wp_lla', 'lla0')
% -------------------------------------------------------------------

geoplot(gx, wp_lla(:,1), wp_lla(:,2), 'r-', 'LineWidth', 1.6);
drawnow;

fprintf('\n[웨이포인트]\n');
fprintf('  %3s  %12s  %13s  %10s  %10s\n', '#', '위도', '경도', 'N[m]', 'E[m]');
for k = 1:N_WP
    fprintf('  %3d  %12.7f  %13.7f  %10.2f  %10.2f\n', ...
            k, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k));
end

fprintf('\n=== 3단 끝 ===\n');
