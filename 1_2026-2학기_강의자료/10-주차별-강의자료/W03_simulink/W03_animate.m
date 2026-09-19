function W03_animate(x_n, y_n, psi, t)
% W03_ANIMATE  NED 평면에 배와 항적을 실시간으로 그린다.
%
%   Simulink 의 Animate 블록이 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%
%   입력
%     x_n, y_n : 기준점 기준 북쪽 x · 동쪽 y [m]
%     psi      : 선수각 [rad]  (북 기준 시계방향 +, NED)
%     t        : 시뮬레이션 시각 [s]
%
%   화면 규약 — 해도와 같게 그린다
%     가로축 = y (동쪽),  세로축 = x (북쪽).  위쪽이 북쪽이다
%     선체의 뾰족한 쪽이 선수. 검은 선이 선수 방향
%
%   그림이 느리면 W03_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig ax hTrail hHull hHead hDot hInfo trX trY tLast tPrev

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W03 실시간 항적 (NED)', 'NumberTitle','off', ...
                 'Color','w', 'Position',[80 80 680 700]);
    ax = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
    xlabel(ax,'y (동쪽) [m]'); ylabel(ax,'x (북쪽) [m]');

    % 기준점 (LLA 원점)
    plot(ax, 0, 0, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',12, 'LineWidth',1.8);
    text(ax, 0.6, 0.6, '기준점', 'Color',[0.80 0.15 0.15], 'FontSize',10);

    trX = []; trY = [];
    hTrail = plot(ax, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.05 0.30 0.05], 'LineWidth',1.4);
    hHead  = plot(ax, nan, nan, '-', 'Color','k', 'LineWidth',2);
    hDot   = plot(ax, nan, nan, 'k.', 'MarkerSize',12);
    hInfo  = title(ax, '', 'FontWeight','normal');
    tLast  = -inf;
end
tPrev = t;

trX(end+1) = x_n;  trY(end+1) = y_n;
every = evalin('base','animate_every');
if t - tLast < every, return; end
tLast = t;

% 선체는 수학 좌표(반시계)로 그린다. NED 선수각과의 관계: th = pi/2 - psi
[hX, hY, hx, hy] = W03_hull(y_n, x_n, pi/2 - psi);
set(hTrail, 'XData', trY, 'YData', trX);
set(hHull,  'XData', hX,  'YData', hY);
set(hHead,  'XData', hx,  'YData', hy);
set(hDot,   'XData', y_n, 'YData', x_n);

set(hInfo, 'String', { 'W03 실시간 항적 — NED (위쪽이 북쪽, 뾰족한 쪽이 선수)', ...
    sprintf('t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°', ...
            t, x_n, y_n, rad2deg(psi)) });
drawnow limitrate;
end
