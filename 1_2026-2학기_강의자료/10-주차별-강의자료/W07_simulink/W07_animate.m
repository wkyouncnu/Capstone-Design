function W07_animate(pn, pe, psi, t)
% W07_ANIMATE  시뮬레이션이 도는 동안 배와 웨이포인트를 실시간으로 그린다.
%
%   Simulink 의 Animate 블록이 매 스텝 이 함수를 부른다.
%   직접 부를 일은 없지만, 그림이 마음에 안 들면 이 파일을 고치면 된다.
%
%   입력
%     pn, pe : NED 위치 [m]   (출발점 기준 상대좌표)
%     psi    : 선수각 [rad]   (북 기준, 시계방향 +)
%     t      : 시뮬레이션 시각 [s]
%
%   선체 모양은 W07_matlab/shipModel.m 과 같다.
%     선수(앞) = 세모,  선미(뒤) = 네모  ->  화살표처럼 보인다
%
%   그림이 느리면 W07_setup.m 에서
%     animate       = 0     아예 끄기
%     animate_every = 1.0   덜 자주 그리기 [s]

persistent fig ax hTrail hHull hHead hInfo trailN trailE tLast tPrev

%% ---- 새 실행이면 초기화 ------------------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;

if newRun
    wpn = evalin('base', 'wp_north');
    wpe = evalin('base', 'wp_east');
    R   = evalin('base', 'R_LOS');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W07 실시간 항적', 'NumberTitle','off', ...
                 'Color','w', 'Position',[80 80 780 720]);
    ax  = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');

    % 계획 경로
    plot(ax, wpe, wpn, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 72);
    for i = 1:numel(wpn)
        plot(ax, wpe(i)+R*cos(th), wpn(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    % 항적 — 웨이포인트보다 먼저 만들어 아래에 깔리게 한다
    trailN = []; trailE = [];
    hTrail = plot(ax, nan, nan, '-',  'Color',[0 0.45 0.74], 'LineWidth',1.5);

    % 웨이포인트는 항적 위에 그린다
    for i = 1:numel(wpn)
        plot(ax, wpe(i), wpn(i), 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
             'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.8);
        text(ax, wpe(i)+4, wpn(i)+5, sprintf('%d', i), ...
             'FontSize',12, 'Color',[0.75 0.10 0.10], 'FontWeight','bold');
    end

    % 선체 · 선수 방향선
    hHull  = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.9, ...
                   'EdgeColor',[0.4 0.15 0.05], 'LineWidth',1.2);
    hHead  = plot(ax, nan, nan, '-', 'Color',[0.4 0.15 0.05], 'LineWidth',1.6);

    % 여백을 둔 축 범위 (실행 중에 바뀌지 않게 고정)
    mE = [min(wpe) max(wpe)];  mN = [min(wpn) max(wpn)];
    pad = 0.25*max([diff(mE) diff(mN) 20]);
    axis(ax, [mE(1)-pad mE(2)+pad mN(1)-pad mN(2)+pad]);

    xlabel(ax, 'East [m]');  ylabel(ax, 'North [m]');
    % 상태 표시는 제목에 둔다. 그림 위에 얹으면 웨이포인트를 가린다
    % FontName 을 지정하면 한글이 깨진다. 기본 폰트를 그대로 쓴다
    hInfo = title(ax, '', 'FontSize',11, 'FontWeight','normal', ...
                  'Interpreter','none');
    tLast = -inf;
end
tPrev = t;

%% ---- 너무 자주 그리면 느려진다 -----------------------------------------
try
    every = evalin('base', 'animate_every');
catch
    every = 0.25;
end
if t - tLast < every, return; end
tLast = t;

%% ---- 항적 ------------------------------------------------------------
trailN(end+1) = pn;  %#ok<AGROW>
trailE(end+1) = pe;  %#ok<AGROW>
set(hTrail, 'XData', trailE, 'YData', trailN);

%% ---- 선체 형상 --------------------------------------------------------
% shipModel.m 과 같은 다각형. 선체 기준 좌표 (bx = 전후, by = 좌우)
%   뒤쪽은 네모, 앞쪽은 세모로 모아진다
try
    sc = evalin('base', 'boat_scale');
catch
    sc = 3;
end
L = 2.45 * sc;      % 반길이 [m]  (WAM-V 전장 4.9 m)
B = 1.03 * sc;      % 반폭   [m]

bx = L * [ -1   -1    0.5   1     0.5 ];    % 선미 -> 선수
by = B * [  1   -1   -1     0     1   ];

% NED 회전:  N = pn + bx*cos(psi) - by*sin(psi)
%            E = pe + bx*sin(psi) + by*cos(psi)
hullN = pn + bx*cos(psi) - by*sin(psi);
hullE = pe + bx*sin(psi) + by*cos(psi);
set(hHull, 'XData', hullE, 'YData', hullN);

% 선수 방향선
hd = 2.2 * L;
set(hHead, 'XData', [pe, pe + hd*sin(psi)], ...
           'YData', [pn, pn + hd*cos(psi)]);

%% ---- 상태 표시 --------------------------------------------------------
psi_disp = atan2(sin(psi), cos(psi)) * 180/pi;    % -180 ~ 180 으로 정리
set(hInfo, 'String', { 'W07 실시간 항적   (선수 = 세모, 선미 = 네모)', ...
    sprintf('t = %6.1f s     N = %7.2f m     E = %7.2f m     psi = %6.1f deg', ...
            t, pn, pe, psi_disp) });

drawnow limitrate
end
