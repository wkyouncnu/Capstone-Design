% A2_3_CLICK_DONE  3단 — 지도를 클릭해 웨이포인트를 만든다 (완성본)
%
%   흐름
%     1. 지도를 띄운다
%     2. ginput 으로 N_WP 번 클릭받는다 — 지리축에서는 (위도, 경도) 순으로 돌아온다
%     3. lla2ned 로 NED 로 내린다
%     4. mission_points.mat 에 저장한다 — 뒤 단계가 이 파일을 읽는다
%
%   USE_SAVED = true 로 두면 클릭하지 않고 저장된 점을 다시 쓴다.
%   매번 클릭하면 실험 조건이 달라져 결과를 비교할 수 없다.
%
%   >> A2_3_click_done

A2_setup;

N_WP      = 3;
USE_SAVED = false;        % 한 번 찍은 뒤에는 true 로 두고 쓴다

fprintf('\n=== 3단 · 지도를 클릭해 웨이포인트 만들기 ===\n\n');

if USE_SAVED && isfile(mission_file)
    S      = load(mission_file, 'wp_lla');  %#ok<UNRCH>  % USE_SAVED 가 상수라 분석기가 '도달 불가' 로 본다
    wp_lla = S.wp_lla;
    fprintf('저장된 웨이포인트 %d 개를 다시 쓴다 (%s)\n', ...
            size(wp_lla,1), mission_file);
    gx = A2_openmap(lla0, map_span_m, basemap_name, '3단 — 저장된 웨이포인트');
else
    gx = A2_openmap(lla0, map_span_m, basemap_name, ...
                    sprintf('3단 — 웨이포인트 %d 개를 클릭할 것', N_WP));
    geoscatter(gx, lla0(1), lla0(2), 110, 'w', 'filled', ...
               'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
    drawnow;

    fprintf('지도 위에서 웨이포인트 %d 개를 차례로 클릭할 것\n', N_WP);
    fprintf('  (클릭할 때까지 MATLAB 은 기다린다 — ginput 은 블로킹이다)\n\n');

    wp_lla = zeros(N_WP, 3);
    for k = 1:N_WP
        [lat, lon] = ginput(1);          % 지리축: 첫째가 위도, 둘째가 경도
        wp_lla(k,:) = [lat, lon, 0];
        geoscatter(gx, lat, lon, 80, 'r', 'filled');
        text(gx, lat, lon, sprintf('  %d', k), ...
             'Color', 'r', 'FontWeight', 'bold', 'FontSize', 12);
        drawnow;
        fprintf('  %d 번째 클릭 : %.7f , %.7f\n', k, lat, lon);
    end

    save(mission_file, 'wp_lla', 'lla0');
    fprintf('\n저장함 : %s\n', mission_file);
end

%% 위경도를 NED 로 내린다
wp_ned   = lla2ned(wp_lla, lla0, 'flat');
wp_north = wp_ned(:,1).';                % W05 모델이 쓰는 이름 그대로
wp_east  = wp_ned(:,2).';

%% 경로를 지도에 그린다
geoplot(gx, wp_lla(:,1), wp_lla(:,2), 'r-', 'LineWidth', 1.6);
drawnow;

%% 표로 출력
fprintf('\n[웨이포인트]\n');
fprintf('  %3s  %12s  %13s  %10s  %10s\n', '#', '위도', '경도', 'N[m]', 'E[m]');
for k = 1:size(wp_lla,1)
    fprintf('  %3d  %12.7f  %13.7f  %10.2f  %10.2f\n', ...
            k, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k));
end

%% 구간 거리 — 숫자로 확인한다
fprintf('\n[구간 거리]\n');
for k = 1:numel(wp_north)-1
    L = hypot(wp_north(k+1)-wp_north(k), wp_east(k+1)-wp_east(k));
    fprintf('  %d -> %d : %7.2f m\n', k, k+1, L);
end
fprintf('  기준점 -> 1 : %7.2f m\n', hypot(wp_north(1), wp_east(1)));

fprintf('\n=== 3단 끝 ===\n');
