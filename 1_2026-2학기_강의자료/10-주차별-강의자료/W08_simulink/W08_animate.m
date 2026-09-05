function W08_animate(pn, pe, psi, turns, t)
% W08_ANIMATE  로이터링을 실시간으로 그린다.
%
%   목표 원, 중심점, 배, 항적, 누적 회전수를 함께 보여 준다.
%   선체 모양은 7주차와 같다 — 선수는 세모, 선미는 네모.
%
%   느리면 W08_setup.m 에서
%     animate       = 0     끄기
%     animate_every = 1.0   덜 자주 그리기

persistent fig ax hTrail hHull hHead hInfo trailN trailE tLast tPrev hCircle

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;

if newRun
    cn = evalin('base','center_north');
    ce = evalin('base','center_east');
    rd = evalin('base','r_d');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W08 로이터링', 'NumberTitle','off', ...
                 'Color','w', 'Position',[80 60 780 740]);
    ax  = axes(fig); hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');

    % 목표 원 — 시나리오로 반경이 바뀌면 같이 갱신된다
    th = linspace(0, 2*pi, 200);
    hCircle = plot(ax, ce + rd*cos(th), cn + rd*sin(th), '--', ...
                   'Color',[0.75 0.10 0.10], 'LineWidth',1.6);

    % 중심점
    plot(ax, ce, cn, 'p', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',16, 'LineWidth',1.2);
    text(ax, ce+2, cn-4, '중심', 'FontSize',11, 'Color',[0.75 0.10 0.10]);

    trailN = []; trailE = [];
    hTrail = plot(ax, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',ax, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.9, ...
                   'EdgeColor',[0.4 0.15 0.05], 'LineWidth',1.2);
    hHead  = plot(ax, nan, nan, '-', 'Color',[0.4 0.15 0.05], 'LineWidth',1.6);

    pad = 1.9*rd;
    axis(ax, [ce-pad ce+pad cn-pad cn+pad]);
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

% 선체 — 선미 네모, 선수 세모 (shipModel.m 과 같은 다각형)
try
    sc = evalin('base','boat_scale');
catch
    sc = 3;
end
L = 2.45*sc;   B = 1.03*sc;
bx = L * [ -1   -1    0.5   1     0.5 ];
by = B * [  1   -1   -1     0     1   ];
set(hHull, 'XData', pe + bx*sin(psi) + by*cos(psi), ...
           'YData', pn + bx*cos(psi) - by*sin(psi));
hd = 2.2*L;
set(hHead, 'XData', [pe, pe + hd*sin(psi)], 'YData', [pn, pn + hd*cos(psi)]);

% 중심에서 현재 거리
cn = evalin('base','center_north');
ce = evalin('base','center_east');
rd = evalin('base','r_d');
rr = hypot(pn - cn, pe - ce);

psi_disp = atan2(sin(psi), cos(psi)) * 180/pi;
set(hInfo, 'String', { 'W08 로이터링   (선수 = 세모, 선미 = 네모)', ...
    sprintf('t = %6.1f s     r = %6.2f m  (목표 %g)     psi = %6.1f deg     %.2f 바퀴', ...
            t, rr, rd, psi_disp, turns) });

drawnow limitrate
end
