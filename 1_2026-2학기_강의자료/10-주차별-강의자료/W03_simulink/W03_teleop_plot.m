function W03_teleop_plot(x_n, y_n, psi, u, v, r, FL, FR, t)
% W03_TELEOP_PLOT  버튼으로 모는 동안, 추력 · 궤적 · 상태를 함께 그린다.
%
%   Simulink 의 Animate 블록이 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   0단계(W03_0_offline)와 4단계(W03_4_teleop)가 같은 함수를 쓴다.
%
%   화면 배치
%     왼쪽   NED 평면의 항적 (가로축 y 동쪽, 세로축 x 북쪽) — 해도와 같은 방향
%     오른쪽 위에서부터  좌·우 추력 F_L, F_R (한 그림, 범례)  ·  psi · u · v · r
%
%   입력
%     x_n, y_n : 기준점 기준 북쪽 x · 동쪽 y [m]
%     psi      : 선수각 [rad]   (북 기준 시계방향 +, NED)
%     u, v     : 서지·스웨이 속도 [m/s]  (배에 붙은 축)
%     r        : 요각속도 [rad/s]        (NED)
%     FL, FR   : 좌·우 추진기 추력 명령 [N]  (TeleopPad 의 Mix 출력)
%     t        : 시뮬레이션 시각 [s]
%
%   왜 이 순서로 나란히 보는가
%     버튼 하나가 먼저 **추력 두 개**를 바꾼다. 좌회전 버튼이면 F_L 이 음, F_R 이 양이 되어
%     요 모멘트 N = b (F_L - F_R) 가 음수가 되고, r 이 먼저 서고, r 이 쌓여 psi 가 돌고,
%     psi 가 돌아야 항적이 휜다. 그 순서가 위에서 아래로 눈에 보인다.
%     v 는 배가 옆으로 밀리는 양이다. 전진하면서 선회할 때만 0 이 아니다.
%
%   그림이 느리면 W03_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axS hTrail hHull hHead hDot hInfo hL hF tv Dat Fd trX trY tLast tPrev

newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W03 버튼 조종 — 추력 · 항적 · 상태', 'NumberTitle','off', ...
                 'Color','w', 'Position',[60 40 1180 820]);

    % ---- 왼쪽 : 항적 ----
    axXY = subplot(1,2,1,'Parent',fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]'); ylabel(axXY,'x (북쪽) [m]');
    plot(axXY, 0, 0, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',12, 'LineWidth',1.8);
    text(axXY, 0.8, 0.8, '기준점', 'Color',[0.80 0.15 0.15], 'FontSize',10);
    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.05 0.30 0.05], 'LineWidth',1.4);
    hHead  = plot(axXY, nan, nan, '-', 'Color','k', 'LineWidth',2);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',12);
    hInfo  = title(axXY, '', 'FontWeight','normal');

    % ---- 오른쪽 맨 위 : 좌·우 추력을 한 그림에 ----
    axS = gobjects(1,5);
    axS(1) = subplot(5,2,2,'Parent',fig);
    hold(axS(1),'on'); grid(axS(1),'on');
    hF(1) = plot(axS(1), nan, nan, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    hF(2) = plot(axS(1), nan, nan, '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axS(1), '추력 [N]');
    Fm = 200;
    try, Fm = evalin('base','teleop_thrust'); catch, end
    ylim(axS(1), [-1.5 1.5]*Fm);          % 위쪽 여백은 범례 자리
    legend(axS(1), {'F_L (좌현)','F_R (우현)'}, 'Location','north', 'Orientation','horizontal');
    title(axS(1), '버튼 → 추력 두 개 → r 이 먼저 서고 → r 이 쌓여 \psi 가 돈다', ...
          'FontWeight','normal');
    Fd = zeros(0,2);

    % ---- 그 아래 : 네 상태 ----
    lab = {'\psi [deg]', 'u [m/s]', 'v [m/s]', 'r [deg/s]'};
    col = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19; 0.49 0.18 0.56];
    tv  = [];  Dat = zeros(0,4);  hL = gobjects(1,4);
    for k = 1:4
        axS(k+1) = subplot(5,2,2*(k+1),'Parent',fig);
        hold(axS(k+1),'on'); grid(axS(k+1),'on');
        hL(k) = plot(axS(k+1), nan, nan, '-', 'Color',col(k,:), 'LineWidth',1.4);
        ylabel(axS(k+1), lab{k});
        if k == 4, xlabel(axS(k+1), '시간 [s]'); end
    end
    tLast = -inf;
end
tPrev = t;

trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;    Dat(end+1,:) = [rad2deg(psi), u, v, rad2deg(r)];
Fd(end+1,:) = [FL, FR];

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return, end
tLast = t;

% 선체는 수학 좌표(반시계)로 그린다. NED 선수각과의 관계: th = pi/2 - psi
[hX, hY, hx, hy] = W03_hull(y_n, x_n, pi/2 - psi);
set(hTrail, 'XData', trY, 'YData', trX);
set(hHull,  'XData', hX,  'YData', hY);
set(hHead,  'XData', hx,  'YData', hy);
set(hDot,   'XData', y_n, 'YData', x_n);
set(hInfo, 'String', sprintf(['버튼 조종 — 위쪽이 북쪽, 뾰족한 쪽이 선수\n' ...
    't = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°'], ...
    t, x_n, y_n, rad2deg(psi)));

set(hF(1), 'XData', tv, 'YData', Fd(:,1));
set(hF(2), 'XData', tv, 'YData', Fd(:,2));
for k = 1:4
    set(hL(k), 'XData', tv, 'YData', Dat(:,k));
end
drawnow limitrate;
end
