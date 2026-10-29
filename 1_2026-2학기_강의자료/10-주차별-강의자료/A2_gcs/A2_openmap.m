function gx = A2_openmap(lla0, span_m, basemap_name, fig_title, parent)
%A2_OPENMAP  기준점을 가운데 둔 지도 축을 하나 만든다
%
%   gx = A2_OPENMAP(lla0, span_m, basemap_name, fig_title)
%   gx = A2_OPENMAP(lla0, span_m, basemap_name, fig_title, parent)
%
%   입력
%     lla0         : [위도 경도 고도] — 지도 중심이자 NED 원점
%     span_m       : 기준점에서 지도 테두리까지의 거리 [m]
%     basemap_name : 'satellite' 또는 'darkwater'
%     fig_title    : 그림 제목 (생략 가능)
%     parent       : 지도 축을 넣을 그림 (생략하면 새 그림을 만든다)
%                    4단 실시간 화면은 지도와 그래프를 한 그림에 넣으므로 이것을 쓴다
%
%   출력
%     gx : geoaxes 핸들. 뒤 단계가 이 축에 더 그린다
%
%   거리를 각도로 손으로 나누지 않는 것이 요점이다.
%   span_m 를 ned2lla 에 넣어 테두리의 위경도를 얻는다.

    if nargin < 4, fig_title = '지도'; end
    if nargin < 5, parent    = [];     end

    % 1) 남서 / 북동 두 꼭짓점을 좌표 변환으로 구한다
    sw = ned2lla([-span_m, -span_m, 0], lla0, 'flat');
    ne = ned2lla([ span_m,  span_m, 0], lla0, 'flat');

    if isempty(parent)
        parent = figure('Name', fig_title, 'NumberTitle', 'off', 'Color', 'w');
    end
    gx = geoaxes(parent);
    geolimits(gx, [sw(1) ne(1)], [sw(2) ne(2)]);

    % 2) 베이스맵
    %    'darkwater' 만 MATLAB 에 들어 있다. 위성 영상은 매번 인터넷에서 받아 온다
    try
        geobasemap(gx, basemap_name);
        drawnow;
    catch err
        warning('A2:basemap', ...
            '베이스맵 ''%s'' 를 불러오지 못했다 (%s). ''darkwater'' 로 대체한다.', ...
            basemap_name, err.identifier);
        geobasemap(gx, 'darkwater');
        drawnow;
    end

    hold(gx, 'on');
    title(gx, fig_title);
end
