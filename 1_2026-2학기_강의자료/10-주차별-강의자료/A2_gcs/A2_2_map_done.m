% A2_2_MAP_DONE  2단 — 위성지도를 띄우고 기준점을 찍는다 (완성본)
%
%   확인할 것
%     1. 지도 가운데에 흰 점(기준점) 하나가 보인다
%     2. 요청한 지도 범위와 실제 범위가 다르다 — 종횡비 때문에 넓어진다
%     3. 실제 범위를 m 로 환산해 본다
%
%   >> A2_2_map_done

A2_setup;

fprintf('\n=== 2단 · 위성지도와 기준점 ===\n\n');

%% 1. 지도 축을 만든다
gx = A2_openmap(lla0, map_span_m, basemap_name, ...
                sprintf('2단 — 기준점 (반경 %d m)', map_span_m));

%% 2. 기준점 표시
geoscatter(gx, lla0(1), lla0(2), 110, 'w', 'filled', ...
           'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
text(gx, lla0(1), lla0(2), '  기준점 (0, 0)', ...
     'Color', 'w', 'FontWeight', 'bold', 'FontSize', 11);
drawnow;

%% 3. 요청 범위 vs 실제 범위
sw_req = ned2lla([-map_span_m, -map_span_m, 0], lla0, 'flat');
ne_req = ned2lla([ map_span_m,  map_span_m, 0], lla0, 'flat');
[LA, LO] = geolimits(gx);

fprintf('[1] 지도 범위\n');
fprintf('  요청 위도 : [%.6f  %.6f]\n', sw_req(1), ne_req(1));
fprintf('  실제 위도 : [%.6f  %.6f]\n', LA(1), LA(2));
fprintf('  요청 경도 : [%.6f  %.6f]\n', sw_req(2), ne_req(2));
fprintf('  실제 경도 : [%.6f  %.6f]\n', LO(1), LO(2));
fprintf('  -> geolimits 는 종횡비를 지키려고 요청값보다 넓게 잡는다\n');
fprintf('     검증할 때는 반드시 geolimits(gx) 로 되읽은 값을 쓸 것\n');

%% 4. 실제 범위를 m 로 환산
sw_act = lla2ned([LA(1) LO(1) 0], lla0, 'flat');
ne_act = lla2ned([LA(2) LO(2) 0], lla0, 'flat');
fprintf('\n[2] 실제 범위를 m 로\n');
fprintf('  남서 꼭짓점 : N %8.1f  E %8.1f\n', sw_act(1), sw_act(2));
fprintf('  북동 꼭짓점 : N %8.1f  E %8.1f\n', ne_act(1), ne_act(2));
fprintf('  지도 크기   : 북 %.1f m x 동 %.1f m\n', ...
        ne_act(1)-sw_act(1), ne_act(2)-sw_act(2));

fprintf('\n=== 2단 끝 ===\n');
