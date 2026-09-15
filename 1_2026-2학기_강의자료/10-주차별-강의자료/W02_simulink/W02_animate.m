function W02_animate(x, y, th, t)
% W02_ANIMATE  시뮬레이션이 도는 동안 선체·항적·목표 자세를 실시간으로 그린다.
%
%   Simulink 의 Animate 블록이 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   2단계(오프라인)와 3단계(turtlesim) 모델이 같은 함수를 쓴다.
%
%   입력
%     x, y : 위치 (turtlesim 좌표, 0 ~ 11.09)
%     th   : 선수각 [rad]  (+x 축 기준 반시계 +)
%     t    : 시뮬레이션 시각 [s]
%
%   그림 읽는 법
%     초록 선체 — 현재 자세.  뾰족한 쪽이 선수(heading)
%     검은 선   — 선수 방향선
%     빨간 점선 선체 — 목표 자세
%     제목      — 시각 · 위치 · 선수각 · 목표까지 거리
%
%   그림이 느리면 W02_setup.m 에서  animate = 0  또는  animate_every 를 키운다.

persistent fig ax hTrail hHull hHead hDot hInfo trX trY tLast tPrev

% 첫 메시지가 오기 전(0,0 으로 채운 샘플)은 그리지 않는다
if x == 0 && y == 0, return; end

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    xg  = evalin('base','x_goal');
    yg  = evalin('base','y_goal');
    thg = evalin('base','theta_goal');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W02 실시간 항적', 'NumberTitle','off', ...
                 'Color','w', 'Position',[80 80 680 720]);
    ax = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
    xlim(ax,[0 11.09]); ylim(ax,[0 11.09]);
    xlabel(ax,'x'); ylabel(ax,'y');

    % 목표 자세 — 빨간 점선 선체
    [gX, gY, ghx, ghy] = W02_hull(xg, yg, thg, 0.55);   % 전체 화면(11.09)에서 잘 보이게 크게
    plot(ax, gX, gY, '--', 'Color',[0.80 0.15 0.15], 'LineWidth',1.8);
    plot(ax, ghx, ghy, '--', 'Color',[0.80 0.15 0.15], 'LineWidth',1.4);
    plot(ax, xg, yg, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',10, 'LineWidth',1.8);

    trX = []; trY = [];
    hTrail = plot(ax, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.05 0.30 0.05], 'LineWidth',1.4);
    hHead  = plot(ax, nan, nan, '-', 'Color','k', 'LineWidth',2);
    hDot   = plot(ax, nan, nan, 'k.', 'MarkerSize',14);
    hInfo  = title(ax, '', 'FontWeight','normal');
    tLast  = -inf;
end
tPrev = t;

trX(end+1) = x;  trY(end+1) = y;
every = evalin('base','animate_every');
if t - tLast < every, return; end
tLast = t;

[hX, hY, hx, hy] = W02_hull(x, y, th, 0.55);
set(hTrail, 'XData', trX, 'YData', trY);
set(hHull,  'XData', hX,  'YData', hY);
set(hHead,  'XData', hx,  'YData', hy);
set(hDot,   'XData', x,   'YData', y);

d = hypot(evalin('base','x_goal') - x, evalin('base','y_goal') - y);
set(hInfo, 'String', { 'W02 실시간 항적   (뾰족한 쪽 = 선수)', ...
    sprintf('t = %5.1f s    x = %5.2f    y = %5.2f    \\theta = %6.1f°    거리 = %4.2f', ...
            t, x, y, rad2deg(th), d) });
drawnow limitrate;
end
