function f = W06_animate(x_n, y_n, psi, psi_ref, x_ref, y_ref, u, v, r, ...
                         gate, FL, FR, FB, phase, t)
% W06_ANIMATE  6주차 위치제어·접안 모델의 실시간 화면 — 한 창에 항적과 오차.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W06_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력 — Animate 상자의 태그 순서와 같다
%     x_n, y_n        북쪽 x · 동쪽 y [m]   (출발점 기준 상대좌표)
%     psi             선수각 [rad]          (북 기준 시계방향 +, NED)
%     psi_ref         과업이 요구하는 선수각 [rad]
%     x_ref, y_ref    과업이 요구하는 위치 [m]
%     u, v, r         서지 · 횡이동 속도 [m/s] 와 요 각속도 [rad/s]
%     gate            주행 허가 0/1         (1 이면 속도 지령을 낸다)
%     FL, FR, FB      좌 · 우 · 선수 추진기 추력 [N]
%     phase           과업 진행 단계 (래치된 값. 0 에서 시작한다)
%     t               시뮬레이션 시각 [s]
%
%   화면 배치 — 5주차 W05_animate 와 같은 배치. 오른쪽 세 칸의 내용만 6주차 것이다
%     왼쪽 큰 칸   항적 + 목표 자세 · 접근점 · 부두 + 선체 모양과 선수 방향
%                  가로축 y (동쪽), 세로축 x (북쪽) — 위쪽이 북쪽, 해도와 같다
%     오른쪽 (1)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 선수각 지령 대비 응답
%     오른쪽 (2)   북 오차 · 동 오차 · 목표까지 거리 [m] 와 R_stop 띠
%     오른쪽 (3)   u · v (왼쪽 축) 과 F_L · F_R · F_B (오른쪽 축)
%
%   왜 오차 칸에 거리와 성분을 함께 그리는가
%     6주차가 답해야 하는 질문은 "요구한 한 점·한 선수각에 섰는가" 다. 거리 하나면
%     섰는지는 알지만 어느 쪽으로 남았는지를 모른다. 북·동 성분을 함께 그려야
%     "동쪽으로 1.2 m 남았다" 처럼 읽을 수 있고, 그것이 선수추진기가 할 일이다.
%     R_stop 띠(점선 두 줄)를 깔아 두면 임무 완료 판정선이 눈에 보인다.
%
%   선체 그림은 4·5주차와 같은 다각형이다 (hull_ned). 접안에서는 배가 옆으로도
%   가므로 선수 방향선을 길게 두어 선수각이 지켜지는지를 바로 볼 수 있게 했다.
%
%   그림이 느리면 W06_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axP axE axM ...
           hTrail hHull hHead hDot hInfo ...
           hPref hP hEN hEE hED hU hV hFL hFR hFB ...
           trX trY tv Dp De Dm mode gx gy gpsi Rs tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if \psisempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W06_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || \psisvalid(fig) || t < tPrev;
if newRun
    q    = evalin('base', 'task_q');
    mode = evalin('base', 'task_mode');

    Rd = q(10);  La = q(11);  sd = q(12);  Rs = q(13);
    dx = q(7);   dy = q(8);   dpsi = q(9);
    switch mode
        case 1,    gx = q(1);  gy = q(2);  gpsi = q(3);
        case 2,    gx = q(4);  gy = q(5);  gpsi = q(6);
        otherwise, gx = dx;    gy = dy;    gpsi = dpsi;
    end
    %  접근점 — 선석에서 부두 반대쪽(= 우현쪽, sd = +1)으로 L_app 만큼 떨어진 점.
    %  TaskRef 가 쓰는 식과 글자 하나까지 같아야 그림과 제어가 어긋나지 않는다
    apx = dx - sd*La*sin(dpsi);
    apy = dy + sd*La*cos(dpsi);

    if \psisempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W06 실시간 위치제어 화면 — 항적과 위치·선수각 오차', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W06_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 항적 + 목표 자세 + 부두 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    th = linspace(0, 2*pi, 72);
    if mode == 3
        px = [0 apx dx];  py = [0 apy dy];        % 계획선은 접근점을 거친다
    else
        px = [0 gx];      py = [0 gy];
    end
    plot(axXY, py, px, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    plot(axXY, gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.60 0.60 0.60]);

    sceneX = [0 gx];  sceneY = [0 gy];
    if mode == 3
        %  부두 — 접안 선수각과 나란한 띠. 선석에서 부두쪽(좌현쪽, sd = +1)으로 비켜 둔다
        dq = 1.6;  Lq = 12;
        qcx = dx + dq*sd*sin(dpsi);   qcy = dy - dq*sd*cos(dpsi);
        qx = qcx + Lq*[-1 1]*cos(dpsi);
        qy = qcy + Lq*[-1 1]*sin(dpsi);
        plot(axXY, qy, qx, '-', 'Color',[0.45 0.33 0.20], 'LineWidth',7);
        text(axXY, qcy, qcx, ' 부두', 'FontSize',11, 'Color',[0.35 0.25 0.15]);

        plot(axXY, apy, apx, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
             'MarkerFaceColor','w', 'MarkerSize',10, 'LineWidth',1.8);
        plot(axXY, apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
        text(axXY, apy+1.5, apx+2.5, '접근점', 'FontSize',11, 'Color',[0.00 0.40 0.00]);
        sceneX = [sceneX apx qx];  sceneY = [sceneY apy qy];
    end

    %  목표 자세 — 네모로 위치를, 짧은 막대로 요구 선수각을 나타낸다
    plot(axXY, gy, gx, 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
         'MarkerFaceColor','w', 'MarkerSize',13, 'LineWidth',1.8);
    Lg = 6;
    plot(axXY, [gy gy+Lg*sin(gpsi)], [gx gx+Lg*cos(gpsi)], '-', ...
         'Color',[0.75 0.10 0.10], 'LineWidth',1.8);
    text(axXY, gy+1.5, gx-3.0, '목표 자세', 'FontSize',11, 'Color',[0.75 0.10 0.10]);
    plot(axXY, 0, 0, 'x', 'Color',[0.25 0.25 0.25], 'MarkerSize',12, 'LineWidth',1.6);

    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.90, ...
                   'EdgeColor',[0.40 0.15 0.05], 'LineWidth',1.2);
    hHead  = plot(axXY, nan, nan, '-', 'Color',[0.40 0.15 0.05], 'LineWidth',1.6);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);

    %  여백을 둔 축 범위 (실행 중에 바뀌지 않게 고정)
    mY = [min(sceneY) max(sceneY)];  mX = [min(sceneX) max(sceneX)];
    pad = 0.25*max([diff(mY) diff(mX) 20]);
    axis(axXY, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);

    %  상태 표시는 제목에 둔다. 그림 위에 얹으면 목표 표식을 가린다
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 선수각 지령 대비 응답 ----
    axP = subplot(3,2,2, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');
    title(axP, '선수각 — 지령 대비 응답 (ssa 로 접은 값)', 'FontWeight','normal');
    legend(axP, [hPref hP], {'\psi_{ref} (과업 지령)','\psi (응답)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (2) : 위치 오차 ----
    %   6주차의 핵심 지표다. 성분과 거리를 함께 그려야 어느 쪽으로 남았는지 읽힌다
    axE = subplot(3,2,4, 'Parent', fig);
    hold(axE,'on'); grid(axE,'on');
    yline(axE, 0, '-', 'Color',[0.40 0.40 0.40], 'LineWidth',1.2);
    yline(axE,  Rs, ':', 'Color',[0.60 0.60 0.60], 'LineWidth',1.2);
    yline(axE, -Rs, ':', 'Color',[0.60 0.60 0.60], 'LineWidth',1.2);
    hEN = plot(axE, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    hEE = plot(axE, nan, nan, '-',  'Color',[0.47 0.25 0.80], 'LineWidth',1.6);
    hED = plot(axE, nan, nan, '-.', 'Color',[0.20 0.20 0.20], 'LineWidth',1.3);
    ylabel(axE,'오차 [m]');
    title(axE, sprintf('위치 오차 — 거리가 R_{stop} = %g m 안으로 들면 완료', Rs), ...
          'FontWeight','normal');
    legend(axE, [hEN hEE hED], {'북 오차','동 오차','목표까지 거리'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (3) : 속도와 세 추진기 추력 ----
    %   u, v 는 1.x m/s, 추력은 수백 N 이라 자릿수가 다르다. 한 축에 겹쳐 놓으면
    %   속도가 0 인 직선으로 보인다. 그래서 축을 둘로 나누고 범례로 묶는다.
    axM = subplot(3,2,6, 'Parent', fig);
    yyaxis(axM,'left');
    hold(axM,'on'); grid(axM,'on');
    hU = plot(axM, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    hV = plot(axM, nan, nan, '--', 'Color',[0.47 0.25 0.80], 'LineWidth',1.6);
    ylabel(axM,'속도 [m/s]');
    yyaxis(axM,'right');
    hold(axM,'on');
    hFL = plot(axM, nan, nan, '-',  'Color',[0.47 0.67 0.19], 'LineWidth',1.2);
    hFR = plot(axM, nan, nan, '--', 'Color',[0.49 0.18 0.56], 'LineWidth',1.2);
    hFB = plot(axM, nan, nan, '-',  'Color',[0.93 0.69 0.13], 'LineWidth',1.6);
    ylabel(axM,'추력 [N]');
    xlabel(axM,'시간 [s]');
    legend(axM, [hU hV hFL hFR hFB], {'u (서지)','v (횡이동)','F_L','F_R','F_B (선수)'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    %  yyaxis 는 두 축의 색을 제멋대로 칠한다. 범례가 색을 나르므로 축 글자는 검게 둔다
    axM.YAxis(1).Color = [0.15 0.15 0.15];
    axM.YAxis(2).Color = [0.15 0.15 0.15];

    %  오른쪽 세 칸의 y 이름표가 창 오른쪽 테두리에 잘리지 않게 폭을 조금 줄인다
    for a = [axP axE axM]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end

    tv = [];  Dp = zeros(0,2);  De = zeros(0,3);  Dm = zeros(0,5);
    tLast = -inf;
end
tPrev = t;

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
eN = x_ref - x_n;
eE = y_ref - y_n;
d  = hypot(eN, eE);

trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
De(end+1,:) = [eN, eE, d];
Dm(end+1,:) = [u, v, FL, FR, FB];
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    Dp(1:k,:) = [];  De(1:k,:) = [];  Dm(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 항적 · 선체 ------------------------------------------------
sc = 3;
try, sc = evalin('base','boat_scale'); catch, end
[hX, hY, hdx, hdy] = hull_ned(x_n, y_n, psi, sc);
set(hTrail, 'XData', trY,  'YData', trX);
set(hHull,  'XData', hY,   'YData', hX);
set(hHead,  'XData', hdy,  'YData', hdx);
set(hDot,   'XData', y_n,  'YData', x_n);

set(hInfo, 'String', { ...
    sprintf('실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수.    단계: %s    gate = %d', ...
            phase_name(mode, phase), round(gate)), ...
    %  제목의 해석기가 'tex' 이므로 \psi 가 ψ 로 그려진다. sprintf 가 백슬래시를
    %  먹지 않도록 \\psi 로 적는다 (\p 는 sprintf 의 이스케이프가 아니라 경고가 난다)
    sprintf(['t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°' ...
             '    목표까지 %5.2f m    \\psi 오차 %5.1f°    r = %5.1f °/s'], ...
            t, x_n, y_n, ssa_deg(psi), d, ssa_deg(psi_ref - psi), r*180/pi) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hEN,   'XData', tv, 'YData', De(:,1));
set(hEE,   'XData', tv, 'YData', De(:,2));
set(hED,   'XData', tv, 'YData', De(:,3));
set(hU,    'XData', tv, 'YData', Dm(:,1));
set(hV,    'XData', tv, 'YData', Dm(:,2));
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));
set(hFB,   'XData', tv, 'YData', Dm(:,5));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axP, Dp);
pad_y(axE, [De; Rs -Rs 0]);     % R_stop 띠가 늘 보이게 범위에 함께 넣는다

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 선체 다각형 — 선미는 네모, 선수는 뾰족하다 (4·5주차 애니메이션과 같은 모양)
%   NED 그대로 계산한다.
%     N = x + bx cos(psi) - by sin(psi)
%     E = y + bx sin(psi) + by cos(psi)
% =====================================================================
function [X, Y, hx, hy] = hull_ned(x, y, psi, sc)
L = 2.45 * sc;  B = 1.03 * sc;                % 반길이 · 반폭 [m] (WAM-V 전장 4.9 m)
bx = L * [ -1   -1    0.5   1    0.5 ];       % 선미 -> 선수
by = B * [  1   -1   -1     0    1   ];
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
hx = [x, x + 2.6*L*c];                        % 선수 방향선 (접안에서는 길게 둔다)
hy = [y, y + 2.6*L*s];
end

% ---- 단계 이름 — 숫자 phase 를 사람 말로 ---------------------------------
%   phase 는 래치된 값이고 0 에서 시작한다. 위치유지·횡이동은 0/1, 접안은 0~3 이다
function s = phase_name(mode, ph)
if mode == 1
    nm = {'목표 자세로 이동', '도착 — 정지'};
elseif mode == 2
    nm = {'목표 자세로 옆걸음', '도착 — 정지'};
else
    nm = {'1단계 접근점으로', '2단계 선수각 정렬', '3단계 접안 (옆걸음)', '접안 완료 — 정지'};
end
k = min(max(round(ph) + 1, 1), numel(nm));
s = nm{k};
end

% ---- ssa : 최단 부호각으로 접어 deg 로 -----------------------------------
function d = ssa_deg(a)
d = atan2(sin(a), cos(a)) * 180/pi;
end

% ---- y 범위에 여백. 곡선이 테두리에 붙으면 읽히지 않는다 -----------------
function pad_y(ax, D)
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if isempty(lo) || \psisfinite(lo) || \psisfinite(hi), return, end
%  t = 0 에서는 값이 전부 같다 (lo == hi). 그때 여백을 비율로만 잡으면 위아래
%  한계가 같은 수가 되어 ylim 이 거부한다. 바닥값을 둔다.
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
