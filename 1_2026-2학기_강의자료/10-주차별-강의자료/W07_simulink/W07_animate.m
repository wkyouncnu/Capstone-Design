function W07_animate(x_n, y_n, psi, mode, turns, t)
% W07_ANIMATE  웨이포인트 항주와 로이터링을 실시간으로 그린다.
%
%   미션 상태에 따라 배 색이 바뀐다.
%     mode 1  웨이포인트 항주  파랑
%     mode 2  로이터링         주황
%     mode 3  종료             회색
%
%   선체 모양은 5·6주차와 같다 — 선수는 세모, 선미는 네모.

persistent fig ax hTrail hHull hHead hInfo trailX trailY tLast tPrev

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;

if newRun
    wpx = evalin('base','wp_north');
    wpy = evalin('base','wp_east');
    R   = evalin('base','R_LOS');
    lxc = evalin('base','loiter_xc');
    lyc = evalin('base','loiter_yc');
    lrd = evalin('base','loiter_radius');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W07 미션', 'NumberTitle','off', ...
                 'Color','w', 'Position',[70 50 820 760]);
    ax  = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');

    % 계획 경로
    plot(ax, wpy, wpx, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 72);
    for i = 1:numel(wpx)
        plot(ax, wpy(i)+R*cos(th), wpx(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    % 로이터 원
    plot(ax, lyc + lrd*cos(th), lxc + lrd*sin(th), '--', ...
         'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    plot(ax, lyc, lxc, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',15);

    trailX = []; trailY = [];
    hTrail = plot(ax, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.4);

    % 웨이포인트는 항적 위에
    for i = 1:numel(wpx)
        plot(ax, wpy(i), wpx(i), 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
             'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.8);
        text(ax, wpy(i)+4, wpx(i)+5, sprintf('%d', i), ...
             'FontSize',12, 'Color',[0.75 0.10 0.10], 'FontWeight','bold');
    end

    hHull = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                  'FaceColor',[0 0.45 0.74], 'FaceAlpha',0.9, ...
                  'EdgeColor',[0.1 0.1 0.1], 'LineWidth',1.2);
    hHead = plot(ax, nan, nan, '-', 'Color',[0.1 0.1 0.1], 'LineWidth',1.6);

    mY = [min([wpy lyc-lrd]) max([wpy lyc+lrd])];
    mX = [min([wpx lxc-lrd]) max([wpx lxc+lrd])];
    pad = 0.2*max([diff(mY) diff(mX) 20]);
    axis(ax, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);
    xlabel(ax,'y (동쪽) [m]'); ylabel(ax,'x (북쪽) [m]');
    hInfo = title(ax, '', 'FontSize',11, 'FontWeight','normal', 'Interpreter','none');
    tLast = -inf;
end
tPrev = t;

try
    every = evalin('base','animate_every');
catch
    every = 0.25;
end
if t - tLast < every, return; end
tLast = t;

trailX(end+1) = x_n;  %#ok<AGROW>
trailY(end+1) = y_n;  %#ok<AGROW>
set(hTrail, 'XData', trailY, 'YData', trailX);

try
    sc = evalin('base','boat_scale');
catch
    sc = 2;
end
L = 2.45*sc;  B = 1.03*sc;
bx = L * [ -1   -1    0.5   1     0.5 ];
by = B * [  1   -1   -1     0     1   ];
set(hHull, 'XData', y_n + bx*sin(psi) + by*cos(psi), ...
           'YData', x_n + bx*cos(psi) - by*sin(psi));
hd = 2.2*L;
set(hHead, 'XData', [y_n, y_n + hd*sin(psi)], 'YData', [x_n, x_n + hd*cos(psi)]);

% 미션 상태에 따라 색을 바꾼다
if mode > 2.5
    set(hHull,'FaceColor',[0.55 0.55 0.55]);  st = '3 종료';
elseif mode > 1.5
    set(hHull,'FaceColor',[0.95 0.45 0.20]);  st = '2 로이터링';
else
    set(hHull,'FaceColor',[0 0.45 0.74]);     st = '1 웨이포인트';
end

psi_disp = atan2(sin(psi), cos(psi)) * 180/pi;
set(hInfo, 'String', { 'W07 미션   (선수 = 세모, 선미 = 네모)', ...
    sprintf('t = %6.1f s     mode = %s     psi = %6.1f deg     %.2f 바퀴', ...
            t, st, psi_disp, turns) });

drawnow limitrate
end
