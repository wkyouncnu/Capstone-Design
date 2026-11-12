function f = A3_animate(x_n, y_n, psi, psi_ref, x_ref, y_ref, u, v, r, ...
                        gate, phase, TL, dL, TR, dR, kscl, X_c, Y_c, N_c, t)
% A3_ANIMATE  부록 A3 의 실시간 화면 — 항적 · 두 추진기의 방향과 크기 · 포화 감시
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%
%   f = A3_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다
%   A3_animate('init')      창만 **미리** 만들어 둔다. 모델의 InitFcn 이 부른다
%
%   입력 — Animate 상자의 태그 순서와 같다
%     x_n, y_n        북쪽 x · 동쪽 y [m]
%     psi             선수각 [rad]              (북 기준 시계방향 +, NED)
%     psi_ref         과업이 요구하는 선수각 [rad]
%     x_ref, y_ref    과업이 요구하는 위치 [m]
%     u, v, r         서지 · 횡이동 속도 [m/s] 와 요 각속도 [rad/s]
%     gate            주행 허가 (0 이면 멈춤)
%     phase           과업 진행 단계 (래치된 값, 0 에서 시작)
%     TL, TR          좌 · 우 추진기 추력 [N]   (음수 = 뒤로 민다)
%     dL, dR          좌 · 우 추진기 방향각 [rad]
%     kscl            추력 포화로 걸린 축소 계수 (1 = 축소 없음)
%     X_c, Y_c, N_c   제어기가 **요구한** 힘·모멘트 [N, N, N m]
%     t               시뮬레이션 시각 [s]
%
%   화면 배치 — 일곱 칸
%     왼쪽 큰 칸     항적 + 목표 자세 + 선체 + **추진기 화살표 둘** (NED)
%     가운데 위      추진기 게이지 — 선체 고정 시점의 방향각과 ±45 deg 쐐기
%     가운데 아래    요구한 힘·모멘트와 실제로 난 힘·모멘트의 **차이**
%     오른쪽 1       방향각 delta_L · delta_R 과 ±45 deg 띠
%     오른쪽 2       추력 T_L · T_R 과 ±F_max 띠
%     오른쪽 3       목표까지 거리와 선수각 오차
%     오른쪽 4       속도 u · v
%
%   추진기 게이지를 따로 둔 까닭
%     - 항적 칸의 화살표는 **지구에 고정된** 방향이라 배가 돌면 같이 돈다
%     - 각도 한계 ±45 deg 는 **선체에 고정된** 양이다 — 선체 기준으로 봐야 읽힌다
%     - 쐐기를 앞뒤로 둘 그려 둔다. 뒤쪽 쐐기는 추력을 **음수**로 줄 때 닿는
%       방향이다. 순수 횡이동에서 한쪽이 뒤쪽 쐐기로 넘어가는 것이 곧
%       "추력 반전이 구조적으로 필수" 라는 뜻이다
%
%   요구 대비 실제 칸을 둔 까닭 (이 화면의 판정 칸이다)
%     - 제어기가 요구한 (X_c, Y_c, N_c) 와 추진기 둘이 실제로 만든 (X_a, Y_a, N_a)
%       는 **같아야 한다.** 배분식은 등식이므로 한계가 걸리지 않는 동안은 정확히 같다
%     - 차이가 0 에서 떨어지는 순간이 곧 **각도 한계 또는 추력 한계가 물린 순간**이다
%     - 이 칸이 없으면 "왜 따라가지 못하는가" 를 제어 게인 탓으로 오해하게 된다.
%       오류 메시지는 뜨지 않는다
%     - 실제 값은 추진기 상태에서 **다시 계산**한다 (모델의 Wrench 블록과 같은 식)
%         X_a = T_L cos d_L + T_R cos d_R
%         Y_a = T_L sin d_L + T_R sin d_R
%         N_a = b (F_xL - F_xR) - L (F_yL + F_yR)
%
%   그림이 느리면 A3_setup.m 에서 animate = 0 또는 animate_every 를 키운다

persistent fig axXY axG axW axE axD axT axV ...
           hTrail hHull hHead hDot hInfo hAL hAR hALh hARh ...
           hgL hgR hgLh hgRh hgRes hgResh hgTxL hgTxR hVer hgTtl ...
           hWX hWY hWN hBand hED hEP hDL hDR hTLp hTRp hU hV ...
           trX trY tv De Dd Dt Dv Dw mode gx gy gpsi Rs Fm dmx dsw bb LL ...
           tLast tPrev scFix dpkv nsat nall wpk

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'A3_anim_fig'); end
    return
end

NMAX = 40000;

%% ---- 창만 미리 만들어 두는 호출 ----------------------------------------
%   창 만들기를 첫 스텝 안에서 하면 그 동안 모델은 멈춰 있다. VRX 연동에서는
%   그 사이 시뮬레이터가 혼자 달린다 (6주차 실측에서 모델 0.4 s 에 9.4 m).
%   그러므로 창은 시계가 돌기 전에 만든다 — A3_model_init 이 'init' 로 부른다
init_only = (nargin == 1) && (ischar(x_n) || isstring(x_n));
if init_only
    assert(strcmpi(x_n, 'init'), 'A3_animate:arg', ...
           '인자 하나로 부를 때는 init 뿐이다');
    [x_n, y_n, psi, psi_ref, x_ref, y_ref]            = deal(0);
    [u, v, r, gate, phase, TL, dL, TR, dR, t]         = deal(0);
    [X_c, Y_c, N_c]                                   = deal(0);
    kscl = 1;
    fig = [];  tLast = [];
end

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    q    = evalin('base', 'task_q');
    mode = evalin('base', 'task_mode');
    Fm   = evalin('base', 'F_max');
    dmx  = evalin('base', 'd_max') * 180/pi;
    dsw  = evalin('base', 'd_sway') * 180/pi;
    bb   = evalin('base', 'half_beam');
    LL   = evalin('base', 'l_thr');

    Rd = q(10);  La = q(11);  sd = q(12);  Rs = q(13);
    dx = q(7);   dy = q(8);   dpsi = q(9);
    switch mode
        case 1,    gx = q(1);  gy = q(2);  gpsi = q(3);
        case 2,    gx = q(4);  gy = q(5);  gpsi = q(6);
        otherwise, gx = dx;    gy = dy;    gpsi = dpsi;
    end
    apx = dx - sd*La*sin(dpsi);
    apy = dy + sd*La*cos(dpsi);

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = A3_fig('A3_anim', ...
                 'A3 실시간 화면 — 항적 · 추진기 방향과 크기 · 포화 감시', ...
                 [30 30 1460 900]);
    setappdata(0, 'A3_anim_fig', fig);

    % ================= 왼쪽 큰 칸 : 항적 =================
    axXY = subplot(4,3,[1 4 7 10], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    th = linspace(0, 2*pi, 72);
    sceneX = [0 gx];  sceneY = [0 gy];
    if mode == 3
        [qX, qY, ~, ~, pmX, pmY] = A3_dock_patch(dx, dy, dpsi, sd);
        hPlan = plot(axXY, [0 apy pmY dy], [0 apx pmX dx], '--', ...
                     'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
        patch('Parent',axXY, 'XData',qY, 'YData',qX, ...
              'FaceColor',[0.82 0.76 0.66], 'EdgeColor',[0.45 0.33 0.20], ...
              'LineWidth',1.1);
        plot(axXY, apy, apx, 'o', 'MarkerEdgeColor',[0 0.5 0], ...
             'MarkerFaceColor','w', 'MarkerSize',9, 'LineWidth',1.6);
        plot(axXY, apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
        text(axXY, apy+1.5, apx+2.5, '접근점', 'FontSize',10, 'Color',[0 0.4 0]);
        sceneX = [sceneX apx qX];  sceneY = [sceneY apy qY];
        uistack(hPlan, 'top');
    else
        plot(axXY, [0 gy], [0 gx], '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    end
    plot(axXY, gy+Rs*cos(th), gx+Rs*sin(th), ':', 'Color',[0.60 0.60 0.60]);
    plot(axXY, gy, gx, 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
         'MarkerFaceColor','w', 'MarkerSize',12, 'LineWidth',1.7);
    plot(axXY, 0, 0, 'x', 'Color',[0.25 0.25 0.25], 'MarkerSize',12, 'LineWidth',1.6);

    mY = [min(sceneY) max(sceneY)];  mX = [min(sceneX) max(sceneX)];
    pad = 0.28*max([diff(mY) diff(mX) 20]);
    axis(axXY, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);

    %  선체 배율 — 축 넓이의 1/6 을 넘지 않게 눌러 둔다. 접안은 실척
    sc0 = 3;
    try, sc0 = evalin('base','boat_scale'); catch, end
    if mode == 3
        scFix = 1;
    else
        scFix = min(sc0, max(0.6, 0.17*max(diff(mY), diff(mX)) / 4.9));
    end

    Lg = max(3, 0.12*max([diff(mX) diff(mY) 20]));
    if mode == 3, Lg = 3.4; end
    plot(axXY, [gy gy+Lg*sin(gpsi)], [gx gx+Lg*cos(gpsi)], '-', ...
         'Color',[0.75 0.10 0.10], 'LineWidth',1.7);
    [tgX, tgY] = hull_ned(gx, gy, gpsi, scFix);
    plot(axXY, [tgY tgY(1)], [tgX tgX(1)], '--', ...
         'Color',[0.75 0.10 0.10], 'LineWidth',1.2);

    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.40 0.15 0.05], 'LineWidth',1.2);
    hHead  = plot(axXY, nan, nan, '-', 'Color',[0.40 0.15 0.05], 'LineWidth',1.5);
    hAL  = plot(axXY, nan, nan, '-', 'Color',[0 0.40 0.85], 'LineWidth',2.6);
    hALh = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                 'FaceColor',[0 0.40 0.85], 'EdgeColor','none');
    hAR  = plot(axXY, nan, nan, '-', 'Color',[0 0.40 0.85], 'LineWidth',2.6);
    hARh = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                 'FaceColor',[0 0.40 0.85], 'EdgeColor','none');
    hDot = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ================= 가운데 위 : 추진기 게이지 =================
    axG = subplot(4,3,[2 5], 'Parent', fig);
    hold(axG,'on'); grid(axG,'off'); axis(axG,'equal');
    set(axG, 'XTick', [], 'YTick', []);
    Rg = 2.2;
    pgx = [-LL -LL];  pgy = [-bb +bb];          % 좌(-y) · 우(+y) 추진기 위치
    [hbx, hby] = hull_body(1);
    patch('Parent',axG, 'XData',hby, 'YData',hbx, ...
          'FaceColor',[0.94 0.94 0.96], 'EdgeColor',[0.45 0.45 0.50], 'LineWidth',1.2);
    for i_t = 1:2
        %  뒤쪽 쐐기 — 추력을 음수로 줄 때 닿는 방향
        aa = linspace(pi - dmx*pi/180, pi + dmx*pi/180, 40);
        patch('Parent',axG, ...
              'XData',[pgy(i_t) pgy(i_t)+Rg*sin(aa)], ...
              'YData',[pgx(i_t) pgx(i_t)+Rg*cos(aa)], ...
              'FaceColor',[0.99 0.90 0.90], 'EdgeColor',[0.85 0.55 0.55], ...
              'LineStyle','--', 'LineWidth',0.8);
        %  앞쪽 쐐기 — 추력이 양수일 때 닿는 방향
        aa = linspace(-dmx*pi/180, dmx*pi/180, 40);
        patch('Parent',axG, ...
              'XData',[pgy(i_t) pgy(i_t)+Rg*sin(aa)], ...
              'YData',[pgx(i_t) pgx(i_t)+Rg*cos(aa)], ...
              'FaceColor',[0.90 0.95 1.00], 'EdgeColor',[0.35 0.55 0.85], ...
              'LineWidth',1.0);
        for sg = [-1 1]
            a = sg*dmx*pi/180;
            plot(axG, [pgy(i_t) pgy(i_t)+Rg*sin(a)], [pgx(i_t) pgx(i_t)+Rg*cos(a)], ...
                 '-', 'Color',[0.80 0.10 0.10], 'LineWidth',1.4);
            a = sg*dsw*pi/180;
            plot(axG, [pgy(i_t) pgy(i_t)+0.85*Rg*sin(a)], ...
                      [pgx(i_t) pgx(i_t)+0.85*Rg*cos(a)], ...
                 ':', 'Color',[0.45 0.45 0.45], 'LineWidth',1.2);
        end
        plot(axG, pgy(i_t), pgx(i_t), 'ko', 'MarkerFaceColor',[0.3 0.3 0.3], ...
             'MarkerSize',6);
    end
    hgL  = plot(axG, nan, nan, '-', 'Color',[0 0.40 0.85], 'LineWidth',3.0);
    hgLh = patch('Parent',axG, 'XData',nan, 'YData',nan, ...
                 'FaceColor',[0 0.40 0.85], 'EdgeColor','none');
    hgR  = plot(axG, nan, nan, '-', 'Color',[0 0.40 0.85], 'LineWidth',3.0);
    hgRh = patch('Parent',axG, 'XData',nan, 'YData',nan, ...
                 'FaceColor',[0 0.40 0.85], 'EdgeColor','none');
    hgRes  = plot(axG, nan, nan, '-', 'Color',[0.10 0.60 0.30], 'LineWidth',2.2);
    hgResh = patch('Parent',axG, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.10 0.60 0.30], 'EdgeColor','none');
    hgTxL = text(axG, pgy(1)-0.1, pgx(1)-1.05, '', 'FontSize',9, ...
                 'Color',[0.1 0.2 0.5], 'HorizontalAlignment','center');
    hgTxR = text(axG, pgy(2)+0.1, pgx(2)-1.05, '', 'FontSize',9, ...
                 'Color',[0.1 0.2 0.5], 'HorizontalAlignment','center');
    hVer  = text(axG, 0, 3.3, '', 'FontSize',11, 'FontWeight','bold', ...
                 'HorizontalAlignment','center');
    hgTtl = title(axG, '', 'FontSize',9.5, 'FontWeight','normal', 'Interpreter','tex');
    axis(axG, [-bb-Rg-0.6, bb+Rg+0.6, -LL-Rg-0.9, 3.9]);
    text(axG, 0, -LL-Rg-0.55, '파랑 = 앞으로 미는 추력,  빨강 = 뒤로 미는 추력', ...
         'FontSize',8.5, 'Color',[0.35 0.35 0.35], 'HorizontalAlignment','center');

    % ================= 가운데 아래 : 요구 대비 실제 =================
    axW = subplot(4,3,[8 11], 'Parent', fig);
    yyaxis(axW,'left');  hold(axW,'on'); grid(axW,'on');
    yline(axW, 0, '-', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    hWX = plot(axW, nan, nan, '-',  'Color',[0 0.45 0.74], 'LineWidth',1.6);
    hWY = plot(axW, nan, nan, '-',  'Color',[0.47 0.25 0.80], 'LineWidth',1.6);
    ylabel(axW,'힘 차이 [N]');
    yyaxis(axW,'right');  hold(axW,'on');
    hWN = plot(axW, nan, nan, '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axW,'모멘트 차이 [N m]');
    xlabel(axW,'시간 [s]');
    legend(axW, [hWX hWY hWN], ...
           {'X_a - X_c', 'Y_a - Y_c', 'N_a - N_c'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    axW.YAxis(1).Color = [0.15 0.15 0.15];
    axW.YAxis(2).Color = [0.15 0.15 0.15];

    % ================= 오른쪽 1 : 방향각과 ±45 deg =================
    axD = subplot(4,3,3, 'Parent', fig);
    hold(axD,'on'); grid(axD,'on');
    hBand = patch('Parent',axD, 'XData',[0 1 1 0], 'YData',[-dmx -dmx dmx dmx], ...
                  'FaceColor',[0.91 0.97 0.91], 'EdgeColor','none');
    yline(axD,  dmx, '-', 'Color',[0.80 0.10 0.10], 'LineWidth',1.5);
    yline(axD, -dmx, '-', 'Color',[0.80 0.10 0.10], 'LineWidth',1.5);
    yline(axD,  dsw, ':', 'Color',[0.45 0.45 0.45]);
    yline(axD, -dsw, ':', 'Color',[0.45 0.45 0.45]);
    yline(axD, 0, '-', 'Color',[0.55 0.55 0.55]);
    hDL = plot(axD, nan, nan, '-',  'Color',[0 0.40 0.85], 'LineWidth',1.6);
    hDR = plot(axD, nan, nan, '--', 'Color',[0.49 0.18 0.56], 'LineWidth',1.6);
    ylabel(axD,'\delta [deg]');  ylim(axD, [-1.25*dmx 1.25*dmx]);
    legend(axD, [hDL hDR], {'\delta_L','\delta_R'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ================= 오른쪽 2 : 추력과 한계 =================
    axT = subplot(4,3,6, 'Parent', fig);
    hold(axT,'on'); grid(axT,'on');
    yline(axT,  Fm, '-', 'Color',[0.80 0.10 0.10], 'LineWidth',1.3);
    yline(axT, -Fm, '-', 'Color',[0.80 0.10 0.10], 'LineWidth',1.3);
    yline(axT, 0, '-', 'Color',[0.55 0.55 0.55]);
    hTLp = plot(axT, nan, nan, '-',  'Color',[0 0.40 0.85], 'LineWidth',1.6);
    hTRp = plot(axT, nan, nan, '--', 'Color',[0.49 0.18 0.56], 'LineWidth',1.6);
    ylabel(axT,'추력 [N]');  ylim(axT, [-1.15*Fm 1.15*Fm]);
    legend(axT, [hTLp hTRp], {'T_L','T_R'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ================= 오른쪽 3 : 오차 =================
    axE = subplot(4,3,9, 'Parent', fig);
    yyaxis(axE,'left');  hold(axE,'on'); grid(axE,'on');
    hED = plot(axE, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    yline(axE, Rs, ':', 'Color',[0.60 0.60 0.60]);
    ylabel(axE,'거리 [m]');
    yyaxis(axE,'right');  hold(axE,'on');
    hEP = plot(axE, nan, nan, '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.5);
    ylabel(axE,'\psi 오차 [deg]');
    title(axE, sprintf('목표까지 거리 (R_{stop} = %g m) 와 선수각 오차', Rs), ...
          'FontWeight','normal', 'FontSize',9);
    axE.YAxis(1).Color = [0.15 0.15 0.15];
    axE.YAxis(2).Color = [0.15 0.15 0.15];

    % ================= 오른쪽 4 : 속도 =================
    axV = subplot(4,3,12, 'Parent', fig);
    hold(axV,'on'); grid(axV,'on');
    yline(axV, 0, '-', 'Color',[0.55 0.55 0.55]);
    hU = plot(axV, nan, nan, '-',  'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hV = plot(axV, nan, nan, '--', 'Color',[0.47 0.25 0.80], 'LineWidth',1.5);
    ylabel(axV,'속도 [m/s]');  xlabel(axV,'시간 [s]');
    legend(axV, [hU hV], {'u (서지)','v (횡이동)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    for a = [axD axT axE axV axW]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.92 p(4)]);
    end

    tv = [];  De = zeros(0,2);  Dd = zeros(0,2);  Dt = zeros(0,2);
    Dv = zeros(0,2);  Dw = zeros(0,3);
    tLast = -inf;  dpkv = 0;  nsat = 0;  nall = 0;  wpk = [0 0 0];
end
tPrev = t;

if init_only
    tLast = -inf;  tPrev = -inf;
    if nargout > 0, f = fig; end
    return
end

%% ---- 값 모으기 ---------------------------------------------------------
dLd = dL*180/pi;  dRd = dR*180/pi;
dpk = max(abs(dLd), abs(dRd));
dpkv = max(dpkv, dpk);
nall = nall + 1;
if dpk > dmx - 0.05, nsat = nsat + 1; end
fsat = 100 * nsat / max(nall, 1);          % 한계에 붙어 있던 시간 비율 [%]

%  실제로 난 힘·모멘트 — 추진기 상태에서 다시 계산한다 (Wrench 블록과 같은 식)
FxL = TL*cos(dL);  FyL = TL*sin(dL);
FxR = TR*cos(dR);  FyR = TR*sin(dR);
Xb  = FxL + FxR;
Yb  = FyL + FyR;
Nb  = bb*(FxL - FxR) - LL*(FyL + FyR);
dW  = [Xb - X_c, Yb - Y_c, Nb - N_c];
wpk = max(wpk, abs(dW));

d    = hypot(x_ref - x_n, y_ref - y_n);
epsi = atan2(sin(psi_ref - psi), cos(psi_ref - psi)) * 180/pi;

trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
De(end+1,:) = [d, epsi];
Dd(end+1,:) = [dLd, dRd];
Dt(end+1,:) = [TL, TR];
Dv(end+1,:) = [u, v];
Dw(end+1,:) = dW;
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    De(1:k,:) = [];  Dd(1:k,:) = [];  Dt(1:k,:) = [];
    Dv(1:k,:) = [];  Dw(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 항적 · 선체 · 추진기 화살표 -------------------------------
[hX, hY, hdx, hdy] = hull_ned(x_n, y_n, psi, scFix);
set(hTrail, 'XData', trY, 'YData', trX);
set(hHull,  'XData', hY,  'YData', hX);
set(hHead,  'XData', hdy, 'YData', hdx);
set(hDot,   'XData', y_n, 'YData', x_n);

%  화살표 길이 — 축 넓이의 18 % 를 최대 추력에 맞춘다
axl = axis(axXY);
aLen = 0.18 * max(axl(2)-axl(1), axl(4)-axl(3));
for i_t = 1:2
    if i_t == 1
        Ti = TL;  di = dL;  byi = -bb;
    else
        Ti = TR;  di = dR;  byi = +bb;
    end
    bxi = -LL;
    pX  = x_n + scFix*(bxi*cos(psi) - byi*sin(psi));
    pY  = y_n + scFix*(bxi*sin(psi) + byi*cos(psi));
    ang = psi + di;                            % NED 기준 추력 방향
    if Ti < 0, ang = ang + pi; end
    len = max(aLen * abs(Ti) / Fm, 1e-6);
    [lx, ly, hxa, hya] = arrow_ned(pX, pY, ang, len);
    if Ti >= 0, col = [0 0.40 0.85]; else, col = [0.85 0.15 0.15]; end
    if i_t == 1
        set(hAL,  'XData',lx,  'YData',ly,  'Color',col);
        set(hALh, 'XData',hxa, 'YData',hya, 'FaceColor',col);
    else
        set(hAR,  'XData',lx,  'YData',ly,  'Color',col);
        set(hARh, 'XData',hxa, 'YData',hya, 'FaceColor',col);
    end
end

set(hInfo, 'String', { ...
    '실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수', ...
    sprintf('단계: %s     gate = %.2f', phase_name(mode, phase), gate), ...
    sprintf('t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°', ...
            t, x_n, y_n, ssa_deg(psi)), ...
    sprintf('목표까지 %5.2f m     \\psi 오차 %5.1f°     v = %5.2f m/s', ...
            d, epsi, v) });

%% ---- 가운데 위 : 추진기 게이지 (선체 고정) -----------------------------
Rg = 2.2;
for i_t = 1:2
    if i_t == 1
        Ti = TL;  di = dL;  byi = -bb;
    else
        Ti = TR;  di = dR;  byi = +bb;
    end
    ang = di;
    if Ti < 0, ang = ang + pi; end
    len = max(Rg * abs(Ti) / Fm, 1e-6);
    [lx, ly, hxa, hya] = arrow_body(-LL, byi, ang, len);
    if Ti >= 0, col = [0 0.40 0.85]; else, col = [0.85 0.15 0.15]; end
    if i_t == 1
        set(hgL,  'XData',lx,  'YData',ly,  'Color',col);
        set(hgLh, 'XData',hxa, 'YData',hya, 'FaceColor',col);
        set(hgTxL, 'String', sprintf('좌  \\delta = %+5.1f°\nT = %+6.1f N', dLd, TL));
    else
        set(hgR,  'XData',lx,  'YData',ly,  'Color',col);
        set(hgRh, 'XData',hxa, 'YData',hya, 'FaceColor',col);
        set(hgTxR, 'String', sprintf('우  \\delta = %+5.1f°\nT = %+6.1f N', dRd, TR));
    end
end
%  합력 — 두 추진기가 만든 선체 기준 힘 (초록)
lenR = max(1.7*Rg * hypot(Xb, Yb) / (2*Fm), 1e-6);
[lx, ly, hxa, hya] = arrow_body(0, 0, atan2(Yb, Xb), lenR);
set(hgRes,  'XData',lx,  'YData',ly);
set(hgResh, 'XData',hxa, 'YData',hya);
set(hgTtl, 'String', { ...
    '추진기 게이지 — 선체 고정 시점 (위쪽이 선수)', ...
    sprintf(['합력  X = %+6.1f N   Y = %+6.1f N   N = %+7.1f N m' ...
             '    축소 k = %.3f'], Xb, Yb, Nb, kscl) });
%  판정 셋 — **한계에 붙어 있는 것**은 합격이 아니다. 각도를 더 주고 싶은데
%  못 주고 있다는 뜻이므로, 그 동안 요구한 힘을 그대로 내지 못한다
if dpkv > dmx + 0.05
    set(hVer, 'String', sprintf('±%.0f° 벗어남 — 최대 %.1f°', dmx, dpkv), ...
              'Color',[0.80 0 0]);
elseif fsat > 1
    set(hVer, 'String', sprintf('±%.0f° 안이지만 한계에 붙었다 — %.0f %% 구간', ...
                                dmx, fsat), 'Color',[0.85 0.45 0]);
else
    set(hVer, 'String', sprintf('±%.0f° 안 — 최대 %.1f°', dmx, dpkv), ...
              'Color',[0 0.50 0.10]);
end

%% ---- 나머지 칸 --------------------------------------------------------
set(hDL, 'XData',tv, 'YData',Dd(:,1));
set(hDR, 'XData',tv, 'YData',Dd(:,2));
set(hTLp,'XData',tv, 'YData',Dt(:,1));
set(hTRp,'XData',tv, 'YData',Dt(:,2));
set(hU,  'XData',tv, 'YData',Dv(:,1));
set(hV,  'XData',tv, 'YData',Dv(:,2));
set(hED, 'XData',tv, 'YData',De(:,1));
set(hEP, 'XData',tv, 'YData',De(:,2));
set(hWX, 'XData',tv, 'YData',Dw(:,1));
set(hWY, 'XData',tv, 'YData',Dw(:,2));
set(hWN, 'XData',tv, 'YData',Dw(:,3));

%  y 범위에 **바닥**을 둔다 — 차이가 1e-14 일 때 축이 그 노이즈를 꽉 채워
%  그리면 "안 맞는다" 로 잘못 읽힌다. 바닥을 두면 0 에 붙은 직선으로 보인다
yyaxis(axW,'left');   pad_y_min(axW, Dw(:,1:2), 1.0);
yyaxis(axW,'right');  pad_y_min(axW, Dw(:,3),   1.0);
yyaxis(axE,'left');   pad_y(axE, De(:,1));
yyaxis(axE,'right');  pad_y_min(axE, De(:,2),   0.5);

%  방향각 칸 제목이 판정을 그대로 나른다
if dpkv > dmx + 0.05
    cc = [0.80 0 0];
elseif fsat > 1
    cc = [0.85 0.45 0];
else
    cc = [0 0.40 0.10];
end
title(axD, sprintf('방향각 — 한계 ±%.0f° · 최대 %.1f° · 한계 접촉 %.1f %%', ...
                   dmx, dpkv, fsat), 'FontWeight','normal', 'FontSize',9, 'Color',cc);
title(axT, sprintf('추력 — 한계 ±%.0f N · 최대 %.1f N · 축소 k = %.3f', ...
                   Fm, max(max(abs(Dt(:,1))), max(abs(Dt(:,2)))), kscl), ...
      'FontWeight','normal', 'FontSize',9);
%  요구 대비 실제 — 0 에 붙어 있어야 정상. 떨어지면 한계가 물린 것이다
if max(wpk(1:2)) > 0.5 || wpk(3) > 0.5
    set(axW.Title, 'Color', [0.80 0 0]);
    ws = sprintf('요구를 못 낸 최대폭  X %.1f N · Y %.1f N · N %.1f N m — 한계가 물렸다', ...
                 wpk(1), wpk(2), wpk(3));
else
    set(axW.Title, 'Color', [0 0.40 0.10]);
    ws = sprintf('요구 = 실제  (최대 차이 %.2f N / %.2f N m) — 한계가 물리지 않았다', ...
                 max(wpk(1:2)), wpk(3));
end
title(axW, {'요구한 힘·모멘트 대비 실제로 난 값의 차이', ws}, ...
      'FontWeight','normal', 'FontSize',9);

%  ±45 deg 띠 패치를 시간축만큼 늘린다 (창을 만들 때는 0~1 로 두었다)
t1 = tv(1);  t2 = max(tv(end), t1 + 1e-3);
set(hBand, 'XData', [t1 t2 t2 t1]);

pad_y(axV, Dv);
drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
%  선체 다각형 — NED. 선미는 네모, 선수는 뾰족하다
% =====================================================================
function [X, Y, hx, hy] = hull_ned(x, y, psi, sc)
[bx, by] = hull_body(sc);
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
L = 2.45*sc;
hx = [x, x + 2.6*L*c];
hy = [y, y + 2.6*L*s];
end

% ---- 몸체 고정 선체 다각형 (x 앞, y 우현) --------------------------------
function [bx, by] = hull_body(sc)
L = 2.45 * sc;  B = 1.03 * sc;                % WAM-V 전장 4.9 m
bx = L * [ -1   -1    0.5   1    0.5 ];
by = B * [  1   -1   -1     0    1   ];
end

% =====================================================================
%  화살표 — 선 좌표와 머리 삼각형 좌표를 따로 돌려준다
%    arrow_ned   NED 평면. 각 ang 는 북 기준 시계방향
%    arrow_body  선체 고정. 각 ang 는 선수 기준, +y(우현) 쪽이 +
%  두 함수 모두 **그림의 가로축이 y** 이므로 좌표를 맞바꿔 돌려준다
% =====================================================================
function [lx, ly, hx, hy] = arrow_ned(px, py, ang, len)
[lx, ly, hx, hy] = arrow_core(px, py, ang, len, 0.16, 0.30);
end

function [lx, ly, hx, hy] = arrow_body(bx, by, ang, len)
[lx, ly, hx, hy] = arrow_core(bx, by, ang, len, 0.17, 0.32);
end

function [lx, ly, hx, hy] = arrow_core(ax1, ay1, ang, len, fw, fl)
tx = ax1 + len*cos(ang);   ty = ay1 + len*sin(ang);
lx = [ay1 ty];  ly = [ax1 tx];
hw = fw*len;    hl = fl*len;
qx = ax1 + (len-hl)*cos(ang);  qy = ay1 + (len-hl)*sin(ang);
nx = -sin(ang);  ny = cos(ang);
hx = [ty, qy+hw*ny, qy-hw*ny];
hy = [tx, qx+hw*nx, qx-hw*nx];
end

% ---- 단계 이름 -----------------------------------------------------------
function s = phase_name(mode, ph)
if mode == 1
    nm = {'목표 자세로 이동', '도착 — 정지'};
elseif mode == 2
    nm = {'순수 횡이동 (옆걸음)', '도착 — 정지'};
else
    nm = {'1단계 접근점으로', '2단계 선수각 정렬', ...
          '3단계 접안 (옆걸음)', '접안 완료 — 정지'};
end
k = min(max(round(ph) + 1, 1), numel(nm));
s = nm{k};
end

% ---- ssa : 최단 부호각으로 접어 deg 로 -----------------------------------
function d = ssa_deg(a)
d = atan2(sin(a), cos(a)) * 180/pi;
end

% ---- y 범위에 여백 + **바닥** -------------------------------------------
%   fl 보다 좁은 범위로는 줄이지 않는다. 0 에 붙어 있는 값을 확대해 보여
%   주지 않기 위한 장치다 (요구 대비 실제 차이가 1e-14 일 때)
function pad_y_min(ax, D, fl)
hi = max(abs(D(:)), [], 'omitnan');
if isempty(hi) || ~isfinite(hi), return, end
lim = max(hi*1.15, fl);
ylim(ax, [-lim, lim]);
end

% ---- y 범위에 여백 -------------------------------------------------------
function pad_y(ax, D)
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if isempty(lo) || ~isfinite(lo) || ~isfinite(hi), return, end
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
