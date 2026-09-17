function W03_teleop_plot(N, E, psi, u, v, r, t)
% W03_TELEOP_PLOT  키보드 대신 버튼으로 모는 동안, 궤적과 상태를 함께 그린다.
%
%   Simulink 의 Animate 블록이 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%
%   화면 배치
%     왼쪽   NED 평면의 항적 (가로축 East, 세로축 North) — 해도와 같은 방향
%     오른쪽 시간에 따른 psi, u, v, r 네 줄
%
%   입력
%     N, E : 기준점 기준 북쪽·동쪽 [m]
%     psi  : 선수각 [rad]   (북 기준 시계방향 +, NED)
%     u, v : 서지·스웨이 속도 [m/s]  (배에 붙은 축)
%     r    : 요각속도 [rad/s]        (NED)
%     t    : 시뮬레이션 시각 [s]
%
%   왜 이 네 개를 나란히 보는가
%     버튼 하나를 누르면 네 값이 **함께** 움직인다. 좌회전 버튼은 r 을 먼저 만들고,
%     r 이 쌓여 psi 가 돌고, psi 가 돌아야 항적이 휜다. 그 순서가 눈에 보인다.
%     v 는 배가 옆으로 밀리는 양이다. 선회 중에만 0 이 아니다.
%
%   그림이 느리면 W03_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axS hTrail hHull hHead hDot hInfo hL tv Dat trN trE tLast tPrev

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W03 버튼 조종 — 항적과 상태', 'NumberTitle','off', ...
                 'Color','w', 'Position',[60 60 1180 700]);

    % ---- 왼쪽 : 항적 ----
    axXY = subplot(1,2,1,'Parent',fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'East [m]'); ylabel(axXY,'North [m]');
    plot(axXY, 0, 0, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',12, 'LineWidth',1.8);
    text(axXY, 0.8, 0.8, '기준점', 'Color',[0.80 0.15 0.15], 'FontSize',10);
    trN = [];  trE = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.05 0.30 0.05], 'LineWidth',1.4);
    hHead  = plot(axXY, nan, nan, '-', 'Color','k', 'LineWidth',2);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',12);
    hInfo  = title(axXY, '', 'FontWeight','normal');

    % ---- 오른쪽 : 네 상태 ----
    lab = {'\psi [deg]', 'u [m/s]', 'v [m/s]', 'r [deg/s]'};
    col = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19; 0.49 0.18 0.56];
    tv  = [];  Dat = zeros(0,4);  hL = gobjects(1,4);
    for k = 1:4
        axS(k) = subplot(4,2,2*k,'Parent',fig); %#ok<AGROW>
        hold(axS(k),'on'); grid(axS(k),'on');
        hL(k) = plot(axS(k), nan, nan, '-', 'Color',col(k,:), 'LineWidth',1.4);
        ylabel(axS(k), lab{k});
        if k == 4, xlabel(axS(k), '시간 [s]'); end
    end
    title(axS(1), '버튼을 누르면 r 이 먼저 서고, r 이 쌓여 \psi 가 돈다', ...
          'FontWeight','normal');
    tLast = -inf;
end
tPrev = t;

trN(end+1) = N;   trE(end+1) = E;
tv(end+1)  = t;   Dat(end+1,:) = [rad2deg(psi), u, v, rad2deg(r)];

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return, end
tLast = t;

% 선체는 수학 좌표(반시계)로 그린다. NED 선수각과의 관계: th = pi/2 - psi
[hX, hY, hx, hy] = W03_hull(E, N, pi/2 - psi);
set(hTrail, 'XData', trE, 'YData', trN);
set(hHull,  'XData', hX,  'YData', hY);
set(hHead,  'XData', hx,  'YData', hy);
set(hDot,   'XData', E,   'YData', N);
set(hInfo, 'String', sprintf(['버튼 조종 — 위쪽이 북쪽, 뾰족한 쪽이 선수\n' ...
    't = %5.1f s    N = %7.2f m    E = %7.2f m    \\psi = %6.1f°'], ...
    t, N, E, rad2deg(psi)));

for k = 1:4
    set(hL(k), 'XData', tv, 'YData', Dat(:,k));
end
drawnow limitrate;
end
