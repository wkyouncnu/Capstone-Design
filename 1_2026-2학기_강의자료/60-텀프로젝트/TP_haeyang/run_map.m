%% run_map.m — 위성지도 위에 미션 지점 네 곳을 찍는다 (해양누리공원)
%
%   >> cd 1_2026-2학기_강의자료/60-텀프로젝트/TP_haeyang
%   >> run_map
%
%   하는 일 세 가지
%     1) haeyang_points.m 의 네 지점을 명령창에 표로 찍는다 (위도·경도·NED m)
%     2) 3·15 해양누리공원 앞 수역 위성지도를 띄우고 네 지점을 ①~④ 로 표시한다
%     3) 각 지점에 **위도·경도**와 **NED 북·동 [m]** 을 함께 적는다
%        map_points.png 로 저장한다
%
%   NED 표기 규약 (이 과목 공통)
%     수식에서는 북 = x, 동 = y. 코드에서는 x_n(북) · y_n(동).
%     N 은 요 모멘트에만 쓴다. 지도 위 글자는 읽는 사람을 위해 '북 / 동' 으로 적는다.
%
%   위성지도가 안 뜰 때
%     geobasemap 'satellite' 는 Esri 타일을 내려받으므로 **인터넷이 필요**하다.
%     못 받으면 아래 for 문이 다음 바탕지도로 넘어가고, 다 안 되면
%     바탕 없이 점만 찍는다 (좌표는 그대로 맞다).
%
%   같은 좌표를 쓰는 것 :  goto.sh (가제보 순간이동) · haeyang_points.m (숫자의 원본)

clear; close all; clc

P = haeyang_points();
U = P.Properties.UserData;

%% 1. 명령창에 표로
fprintf('\n해양누리공원 월드 (%s) — 미션 지점 네 곳\n', U.world);
fprintf('월드 원점 : 위도 %.7f · 경도 %.7f   (ENU 동 0 · 북 0)\n', U.lat0, U.lon0);
fprintf('환산      : 북 1 m = %.4e deg 위도,  동 1 m = %.4e deg 경도\n\n', ...
        U.degPerM_lat, U.degPerM_lon);

fprintf('  %-2s %-6s %12s %12s %8s %8s  %s\n', ...
        '#', '이름', '위도', '경도', '북[m]', '동[m]', '설명');
fprintf('  %s\n', repmat('-', 1, 104));
for k = 1:height(P)
    fprintf('  %-2d %-6s %12.7f %12.7f %8.1f %8.1f  %s\n', ...
            k, P.name{k}, P.lat(k), P.lon(k), P.n_m(k), P.e_m(k), P.desc{k});
end
fprintf('\n');

%% 2. 위성지도
figure('Name', '해양누리공원 미션 지점', 'Color', 'w', 'Position', [100 100 980 760]);
gx = geoaxes;
hold(gx, 'on')

basemaps = {'satellite', 'topographic', 'streets-light', 'none'};
for b = 1:numel(basemaps)
    try
        geobasemap(gx, basemaps{b});
        drawnow                                  % 타일을 실제로 받아 본다
        fprintf('바탕지도 : %s\n', basemaps{b});
        break
    catch
        if b == numel(basemaps)
            fprintf('바탕지도를 못 받았다 — 점만 찍는다 (좌표는 그대로 맞다)\n');
        end
    end
end

%  미션 순서대로 이은 선 — ① 출발 → ② WP1 → ③ WP2 → ④ 종료
geoplot(gx, P.lat, P.lon, '--', 'Color', [1 1 1]*0.95, 'LineWidth', 1.5, ...
        'DisplayName', '미션 순서');

%  월드 원점
geoplot(gx, U.lat0, U.lon0, 'x', 'Color', [1 0.85 0.2], ...
        'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', '월드 원점 (0, 0)');

%  네 지점
col = [0.10 0.80 0.25;    % ① 출발점   초록
       0.20 0.55 1.00;    % ② WP1      파랑
       1.00 0.55 0.10;    % ③ WP2      주황
       1.00 0.25 0.25];   % ④ 종료점   빨강
num = {'①', '②', '③', '④'};

for k = 1:height(P)
    geoplot(gx, P.lat(k), P.lon(k), 'o', ...
            'MarkerSize', 11, 'LineWidth', 2.2, ...
            'Color', col(k, :), 'MarkerFaceColor', 'w', ...
            'DisplayName', sprintf('%s %s', num{k}, P.name{k}));

    txt = sprintf('%s %s\n%.7f, %.7f\n북 %+.1f m · 동 %+.1f m', ...
                  num{k}, P.name{k}, P.lat(k), P.lon(k), P.n_m(k), P.e_m(k));

    %  글자를 점 오른쪽 8 m 에 둔다
    dlon = 8*U.degPerM_lon;
    text(gx, P.lat(k), P.lon(k) + dlon, txt, ...
         'FontSize', 9, 'FontWeight', 'bold', ...
         'Color', 'k', 'BackgroundColor', [1 1 1 0.78], ...
         'EdgeColor', col(k, :), 'Margin', 3, ...
         'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
end

%  보이는 범위 — 글자가 점 오른쪽에 붙으므로 **동쪽을 더 넓게** 둔다
geolimits(gx, [min(P.lat) - 50*U.degPerM_lat, max(P.lat) + 50*U.degPerM_lat], ...
              [min(P.lon) - 40*U.degPerM_lon, max(P.lon) + 115*U.degPerM_lon]);

legend(gx, 'Location', 'southeast', 'TextColor', 'k', 'Color', [1 1 1 0.85]);
title(gx, '3·15 해양누리공원 앞 수역 — 텀프로젝트 미션 지점 네 곳');

%% 3. 그림 저장
pngPath = fullfile(fileparts(mfilename('fullpath')), 'map_points.png');
try
    exportgraphics(gcf, pngPath, 'Resolution', 150);
    fprintf('그림 저장 : %s\n\n', pngPath);
catch
    print(gcf, pngPath, '-dpng', '-r150');
    fprintf('그림 저장 : %s  (print 로)\n\n', pngPath);
end
