function W09_animate(pn, pe, psi, mode, turns, t)
% W09_ANIMATE  웨이포인트 항주와 로이터링을 실시간으로 그린다.
%
%   미션 상태에 따라 배 색이 바뀐다.
%     mode 1  웨이포인트 항주  파랑
%     mode 2  로이터링         주황
%     mode 3  종료             회색
%
%   선체 모양은 7·8주차와 같다 — 선수는 세모, 선미는 네모.

persistent fig ax hTrail hHull hHead hInfo trailN trailE tLast tPrev

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;

if newRun
    wpn = evalin('base','wp_north');
    wpe = evalin('base','wp_east');
    R   = evalin('base','R_LOS');
    lcn = evalin('base','loiter_cn');
    lce = evalin('base','loiter_ce');
    lrd = evalin('base','loiter_radius');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W09 미션', 'NumberTitle','off', ...
                 'Color','w', 'Position',[70 50 820 760]);
    ax  = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');

    % 계획 경로
    plot(ax, wpe, wpn, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 72);
    for i = 1:numel(wpn)
        plot(ax, wpe(i)+R*cos(th), wpn(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    % 로이터 원
    plot(ax, lce + lrd*cos(th), lcn + lrd*sin(th), '--', ...
         'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    plot(ax, lce, lcn, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',15);

    trailN = []; trailE = [];
    hTrail = plot(ax, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.4);

    % 웨이포인트는 항적 위에
    for i = 1:numel(wpn)
        plot(ax, wpe(i), wpn(i), 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
             'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.8);
        text(ax, wpe(i)+4, wpn(i)+5, sprintf('%d', i), ...
             'FontSize',12, 'Color',[0.75 0.10 0.10], 'FontWeight','bold');
    end

    hHull = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                  'FaceColor',[0 0.45 0.74], 'FaceAlpha',0.9, ...
                  'EdgeColor',[0.1 0.1 0.1], 'LineWidth',1.2);
    hHead = plot(ax, nan, nan, '-', 'Color',[0.1 0.1 0.1], 'LineWidth',1.6);

    mE = [min([wpe lce-lrd]) max([wpe lce+lrd])];
    mN = [min([wpn lcn-lrd]) max([wpn lcn+lrd])];
    pad = 0.2*max([diff(mE) diff(mN) 20]);
    axis(ax, [mE(1)-pad mE(2)+pad mN(1)-pad mN(2)+pad]);
    xlabel(ax,'East [m]'); ylabel(ax,'North [m]');
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

trailN(end+1) = pn;  %#ok<AGROW>
trailE(end+1) = pe;  %#ok<AGROW>
set(hTrail, 'XData', trailE, 'YData', trailN);

try
    sc = evalin('base','boat_scale');
catch
    sc = 2;
end
L = 2.45*sc;  B = 1.03*sc;
bx = L * [ -1   -1    0.5   1     0.5 ];
by = B * [  1   -1   -1     0     1   ];
set(hHull, 'XData', pe + bx*sin(psi) + by*cos(psi), ...
           'YData', pn + bx*cos(psi) - by*sin(psi));
hd = 2.2*L;
set(hHead, 'XData', [pe, pe + hd*sin(psi)], 'YData', [pn, pn + hd*cos(psi)]);

% 미션 상태에 따라 색을 바꾼다
if mode > 2.5
    set(hHull,'FaceColor',[0.55 0.55 0.55]);  st = '3 종료';
elseif mode > 1.5
    set(hHull,'FaceColor',[0.95 0.45 0.20]);  st = '2 로이터링';
else
    set(hHull,'FaceColor',[0 0.45 0.74]);     st = '1 웨이포인트';
end

psi_disp = atan2(sin(psi), cos(psi)) * 180/pi;
set(hInfo, 'String', { 'W09 미션   (선수 = 세모, 선미 = 네모)', ...
    sprintf('t = %6.1f s     mode = %s     psi = %6.1f deg     %.2f 바퀴', ...
            t, st, psi_disp, turns) });

drawnow limitrate
end
