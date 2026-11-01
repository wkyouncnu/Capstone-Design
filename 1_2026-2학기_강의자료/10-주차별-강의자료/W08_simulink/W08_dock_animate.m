function f = W08_dock_animate(x_n, y_n, psi, mode, turns, psi_ref, u, gate_u, ...
                              FL, FR, idx, phase, v, t)
% W08_DOCK_ANIMATE  실습 E 의 실시간 화면 — 항적 · 상태 타임라인 · 접안.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W08_dock_animate()       인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다
%   W08_dock_animate('init')     창만 **미리** 만들어 둔다. 모델의 InitFcn 이 부른다
%
%   왜 실습 A 의 W08_animate 를 고쳐 쓰지 않는가
%     실습 A 의 창은 미션 상태를 **셋**으로 못박아 두었다 (ylim · yticks ·
%     mode_colour · mode_names 네 곳). 넓히면 실습 A 의 그림이 같이 바뀐다.
%     기존 예제는 건드리지 않는 것이 이 주차의 전제이므로 사본을 둔다.
%
%   입력 — Animate 상자의 태그 순서와 같다 (열셋 + 시각)
%     x_n, y_n : 북쪽 x · 동쪽 y [m]   (출발점 기준 상대좌표)
%     psi      : 선수각 [rad]          (북 기준 시계방향 +, NED)
%     mode     : 미션 상태 1~4         (1 WpFollow · 2 Loiter · 3 Dock · 4 Finish)
%     turns    : 로이터 회전수 [바퀴]
%     psi_ref  : 미션이 고른 목표 선수각 [rad]
%     u        : 서지 속도 [m/s]
%     gate_u   : 전진 속도 지령의 문 0/1 (접안·종료에서 0 이 된다)
%     FL, FR   : 좌 · 우 추진기 추력 [N]
%     idx      : 지금 달리는 구간의 시작 웨이포인트 번호
%     phase    : 접안 단계 0~3         (BerthRef 가 래치한 값)
%     v        : 횡 속도 [m/s]         — 순수 옆걸음이 보이는 유일한 신호다
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 실습 A 와 **같은 네 칸**. 더해진 것만 적는다
%     왼쪽 큰 칸   + ㄷ 자 도킹 스테이션 · 접근점 · 접안 완료 반경
%     오른쪽 (1)   상태 계단이 **넷**이 된다 (Dock 단이 더해진다)
%     오른쪽 (2)   그대로 — psi_ref 와 psi
%     오른쪽 (3)   + 횡 속도 v. 접안 구간에서 u 는 0, v 만 서는 것이 순수 옆걸음이다
%
%   접안 위치 오차는 제목에 적는다
%     접안 중에는 "선석까지 몇 m 남았는가" 하나가 읽고 싶은 수치다. 칸을
%     하나 더 만들면 실습 A 와 배치가 달라지므로, 제목 줄에 거리와 단계를 쓴다.
%
%   그림이 느리면 W08_dock_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axM axP axU ...
           hTrail hHull hHead hDot hInfo hTgt hLoi ...
           hM hP hPref hU hV hUcmd hFL hFR hTrLine ...
           trX trY tv Dp Dm mSeg wpx wpy R nwp uRef reqTurns tMax ...
           lxc lyc lrd dkx dky dpsi dRs apx apy tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig;
    else, f = getappdata(0,'W08_dock_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

%% ---- 창만 미리 만들어 두는 호출 ----------------------------------------
%  왜 필요한가 — 6주차 2026-10-28 VRX 실측에서 재현한 고장
%    창 만들기(축 넷 · 범례 셋 · 부두 패치)에는 여러 초가 걸린다. 그것을
%    **첫 스텝 안에서** 하면 그 동안 모델은 멈춰 있고 Gazebo 는 마지막으로 받은
%    추력 명령을 그대로 지킨다. 모델 시간 0.4 s 사이에 배가 9.4 m 를 갔다.
%    그러므로 창은 **시계가 돌기 전에** 만들어 둔다 — W08_dock_init 이 부른다
init_only = (nargin == 1) && (ischar(x_n) || isstring(x_n));
if init_only
    assert(strcmpi(x_n, 'init'), 'W08_dock_animate:arg', ...
           '인자 하나로 부를 때는 ''init'' 뿐이다');
    [x_n, y_n, psi, turns, psi_ref]  = deal(0);
    [u, gate_u, FL, FR, phase, v, t] = deal(0);
    mode = 1;  idx = 1;                     % 창을 지을 때의 기본 상태 (WpFollow, 1구간)
    fig = [];  tLast = [];                  % 아래에서 새 실행으로 보이게 한다
end

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    wpx = evalin('base','wp_north');
    wpy = evalin('base','wp_east');
    R   = evalin('base','R_LOS');
    lxc = evalin('base','loiter_xc');
    lyc = evalin('base','loiter_yc');
    lrd = evalin('base','loiter_radius');
    nwp = numel(wpx);
    uRef     = evalin('base','u_ref');        % 설정값. 문을 곱해 지령선을 만든다
    reqTurns = evalin('base','loiter_turns');

    %  접안 묶음 — BerthRef 가 받는 q 와 **같은 변수**를 읽는다. 따로 적어 두면
    %  설정을 고쳤을 때 그림과 제어가 조용히 어긋난다
    q = evalin('base','dock_q');
    dkx = q(1);  dky = q(2);  dpsi = q(3);
    La  = q(4);  sd  = q(5);  Rd   = q(6);  dRs = q(7);

    %  접근점 — BerthRef 의 식과 글자 하나까지 같아야 한다
    apx = dkx - sd*La*sin(dpsi);
    apy = dky + sd*La*cos(dpsi);

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W08 실습 E 실시간 화면 — 항적 · 상태 타임라인 · 접안', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W08_dock_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 항적 + 웨이포인트 + 로이터 원 + 도킹 스테이션 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    % 계획 경로와 수락반경 — 항적보다 먼저 그려 아래에 깔리게 한다
    hPlan = plot(axXY, wpy, wpx, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 96);
    for i = 1:nwp
        plot(axXY, wpy(i)+R*cos(th), wpx(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    % 로이터 중심과 반경 원
    plot(axXY, lyc + lrd*cos(th), lxc + lrd*sin(th), '--', ...
         'Color',[0.95 0.45 0.20], 'LineWidth',1.6);
    plot(axXY, lyc, lxc, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',15, 'LineWidth',1.2);
    text(axXY, lyc, lxc - 0.55*lrd, sprintf('로이터 반경 r_d = %g m', lrd), ...
         'FontSize',9.5, 'Color',[0.85 0.33 0.10], 'HorizontalAlignment','center', ...
         'BackgroundColor','w', 'Margin',1.5);

    % ---- ㄷ 자 도킹 스테이션 — 6주차 치수 그대로 ----
    %   세 면이 막혀 있어 항적이 날개 벽을 뚫는지가 실시간으로 보인다
    [qX, qY, ~, ~, pmX, pmY] = W08_dock_patch(dkx, dky, dpsi, sd);
    patch('Parent',axXY, 'XData',qY, 'YData',qX, ...
          'FaceColor',[0.82 0.76 0.66], 'EdgeColor',[0.45 0.33 0.20], ...
          'LineWidth',1.1);

    %  마지막 구간의 계획선 — 접근점에서 **입구 중심선으로** 들어간다.
    %  곧장 선석으로 그으면 날개 벽을 비스듬히 가로지르는 선이 된다
    plot(axXY, [apy pmY dky], [apx pmX dkx], '--', ...
         'Color',[0.00 0.50 0.45], 'LineWidth',1.4);

    %  이름표는 베이 **바깥**으로 뺀다. 둘레는 벽 · 배 · 목표 자세가 몰려 있다
    ab2x = @(aa,bb) dkx + aa*cos(dpsi) - bb*sd*sin(dpsi);
    ab2y = @(aa,bb) dky + aa*sin(dpsi) + bb*sd*cos(dpsi);
    lbX = ab2x(9.5, -3.4);   lbY = ab2y(9.5, -3.4);
    text(axXY, lbY, lbX, 'ㄷ 자 도킹 스테이션', 'FontSize',10, ...
         'Color',[0.35 0.25 0.15], 'HorizontalAlignment','center', ...
         'BackgroundColor','w', 'Margin',1.5);

    %  접안 완료 반경과 선석의 요구 자세
    plot(axXY, dky+dRs*cos(th), dkx+dRs*sin(th), ':', 'Color',[0.00 0.50 0.45]);
    plot(axXY, dky, dkx, 's', 'MarkerEdgeColor',[0.00 0.50 0.45], ...
         'MarkerFaceColor','w', 'MarkerSize',12, 'LineWidth',1.8);
    plot(axXY, [dky dky+3.4*sin(dpsi)], [dkx dkx+3.4*cos(dpsi)], '-', ...
         'Color',[0.00 0.50 0.45], 'LineWidth',1.8);

    %  접근점 — 마지막 웨이포인트와 같은 자리로 두었다 (W08_dock_setup 의 L_app)
    plot(axXY, apy, apx, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
         'MarkerFaceColor','w', 'MarkerSize',10, 'LineWidth',1.8);
    plot(axXY, apy+Rd*cos(th), apx+Rd*sin(th), ':', 'Color',[0.40 0.70 0.40]);
    text(axXY, apy+2.0, apx+3.0, '접근점', 'FontSize',10, 'Color',[0.00 0.40 0.00]);

    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);

    % 지금 겨누는 표적 — 웨이포인트(초록 원) 또는 로이터 중심(주황 원)
    hTgt = plot(axXY, nan, nan, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
                'MarkerSize',20, 'LineWidth',2.0);
    hLoi = plot(axXY, nan, nan, 'o', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
                'MarkerSize',20, 'LineWidth',2.0);

    % 웨이포인트 표식과 번호는 항적 위에 그린다
    for i = 1:nwp
        plot(axXY, wpy(i), wpx(i), 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
             'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.8);
        text(axXY, wpy(i)+4, wpx(i)+5, sprintf('%d', i), ...
             'FontSize',12, 'Color',[0.75 0.10 0.10], 'FontWeight','bold');
    end

    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor', mode_colour(1), 'FaceAlpha',0.90, ...
                   'EdgeColor',[0.15 0.15 0.15], 'LineWidth',1.2);
    hHead  = plot(axXY, nan, nan, '-', 'Color',[0.15 0.15 0.15], 'LineWidth',1.6);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);

    % 상태 이름 범례 — 배 색이 무슨 뜻인지 그림 안에서 읽히게 한다
    hL = gobjects(1,4);
    for i = 1:4
        hL(i) = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                      'FaceColor', mode_colour(i), 'EdgeColor',[0.15 0.15 0.15]);
    end
    legend(axXY, hL, mode_names(), 'Location','southoutside', ...
           'Orientation','horizontal', 'AutoUpdate','off');

    % 여백을 둔 축 범위 — 도킹 스테이션과 이름표까지 들어가게 한다
    sceneX = [wpx, lxc-lrd, lxc+lrd, qX, lbX];
    sceneY = [wpy, lyc-lrd, lyc+lrd, qY, lbY];
    mY = [min(sceneY) max(sceneY)];  mX = [min(sceneX) max(sceneX)];
    pad = 0.12*max([diff(mY) diff(mX) 20]);
    axis(axXY, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);
    uistack(hPlan, 'top');          % 계획선이 벽에 덮이지 않게

    % 상태 표시는 제목에 둔다. 그림 위에 얹으면 웨이포인트를 가린다
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 상태 타임라인 — 이 주차의 핵심 ---------------------
    axM = subplot(3,2,2, 'Parent', fig);
    hold(axM,'on'); grid(axM,'on');
    hM = stairs(axM, nan, nan, '-', 'Color',[0.49 0.18 0.56], 'LineWidth',2.0);
    ylim(axM, [0.6 4.4]);
    yticks(axM, 1:4);  yticklabels(axM, mode_names());
    ylabel(axM,'mode');
    title(axM, '미션 상태 — 계단이 곧 전이 시각', 'FontWeight','normal');

    % ---- 오른쪽 (2) : 헤딩 지령 대비 응답 --------------------------------
    axP = subplot(3,2,4, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');
    title(axP, '선수각 — 지령 대비 응답 (ssa 로 접은 값)', 'FontWeight','normal');
    legend(axP, [hPref hP], {'\psi_{ref} (지령)','\psi (응답)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (3) : 속도 지령 대비 응답과 추력 -------------------------
    %   실습 A 의 칸에 **횡 속도 v 하나**를 더했다. 접안 구간에서 u 는 0 으로
    %   내려앉고 v 만 서는 것 — 그 그림이 순수 옆걸음의 증거다
    axU = subplot(3,2,6, 'Parent', fig);
    yyaxis(axU,'left');
    hold(axU,'on'); grid(axU,'on');
    hUcmd = plot(axU, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hU    = plot(axU, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    hV    = plot(axU, nan, nan, '-',  'Color',[0.00 0.50 0.45], 'LineWidth',1.6);
    ylabel(axU,'속도 [m/s]');
    yyaxis(axU,'right');
    hold(axU,'on');
    hFL = plot(axU, nan, nan, '-',  'Color',[0.47 0.67 0.19], 'LineWidth',1.3);
    hFR = plot(axU, nan, nan, '--', 'Color',[0.49 0.18 0.56], 'LineWidth',1.3);
    ylabel(axU,'추력 [N]');
    xlabel(axU,'시간 [s]');
    legend(axU, [hUcmd hU hV hFL hFR], ...
           {'u_{ref}','u (전후)','v (횡)','F_L','F_R'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    %  yyaxis 는 두 축의 색을 제멋대로 칠한다. 범례가 색을 나르므로 축 글자는 검게 둔다
    axU.YAxis(1).Color = [0.15 0.15 0.15];
    axU.YAxis(2).Color = [0.15 0.15 0.15];

    %  오른쪽 세 칸의 y 이름표가 창 오른쪽 테두리에 잘리지 않게 폭을 조금 줄인다
    for a = [axP axU]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end
    %  상태 타임라인은 눈금이 '1 WpFollow' 처럼 길어 왼쪽 자리를 더 먹는다
    p = get(axM,'Position');  set(axM, 'Position', [p(1)+0.038 p(2) p(3)*0.827 p(4)]);

    tv = [];  Dp = zeros(0,2);  Dm = zeros(0,5);  mSeg = zeros(0,2);
    hTrLine = gobjects(0);  tMax = 0;
    tLast = -inf;
end
tPrev = t;

%  'init' 호출은 창만 만들고 끝낸다. 값은 모으지 않는다 — 첫 스텝이 그린다
if init_only
    tLast = -inf;  tPrev = -inf;
    if nargout > 0, f = fig; end
    return
end

%  같은 시각이 두 번 들어오면 쌓지 않는다 — ode4 는 한 메이저 스텝을 네 단계로
%  나눠 풀고 그 사이 마이너 스텝에서도 이 블록이 불린다. 그대로 쌓으면 900 s
%  실행이 18 000 점이 아니라 72 000 점이 되어 되돌아보기 한계(NMAX)를 넘고
%  **임무의 앞 절반이 잘려 나간 채** 화면에 남는다
%  (2026-11-01 측정 — 항적에 마지막 구간만 보였다). 시간이 나아갔을 때만 모은다
if ~isempty(tv) && t <= tv(end)
    if nargout > 0, f = fig; end
    return
end

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
Dm(end+1,:) = [uRef*gate_u, u, v, FL, FR];   % 지령 = u_ref × gate_u (OuterLoop 의 문)

%  상태 계단은 **바뀐 점만** 모은다. 매 스텝을 다 모아 그리면 화면이 느려진다
mNow = min(max(round(mode), 1), 4);
if isempty(mSeg) || mSeg(end,2) ~= mNow
    mSeg(end+1,:) = [t, mNow];   %#ok<AGROW>
end

%  TurnCount 는 로이터에서 빠져나오면 0 으로 되돌아간다. 최댓값을 쥔다
tMax = max(tMax, turns);

if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    Dp(1:k,:) = [];  Dm(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 항적 · 선체 · 지금 겨누는 표적 ------------------------------
sc = 2;
try, sc = evalin('base','boat_scale'); catch, end
[hX, hY, hdx, hdy] = hull_ned(x_n, y_n, psi, sc);
set(hTrail, 'XData', trY,  'YData', trX);
set(hHull,  'XData', hY,   'YData', hX, 'FaceColor', mode_colour(mNow));
set(hHead,  'XData', hdy,  'YData', hdx);
set(hDot,   'XData', y_n,  'YData', x_n);

names = mode_names();
st = names{mNow};

%  WpManager 의 idx 는 **구간의 시작** 번호다. 겨누는 것은 그다음 점이다
k = min(max(round(idx), 1), nwp);
ph = min(max(round(phase), 0), 3);
if mNow == 2
    set(hTgt, 'XData', nan, 'YData', nan);
    set(hLoi, 'XData', lyc, 'YData', lxc);
    goal = sprintf('로이터 중심 (%g, %g)    반경 %g m    %.2f / %g 바퀴', ...
                   lxc, lyc, lrd, tMax, reqTurns);
elseif mNow >= 3
    %  접안 구간 — 선석까지 남은 거리와 단계를 적는다. 칸을 늘리지 않는다
    set(hTgt, 'XData', nan, 'YData', nan);
    set(hLoi, 'XData', nan, 'YData', nan);
    d = hypot(dkx - x_n, dky - y_n);
    goal = sprintf('접안 — %s    선석까지 %4.1f m    자세 오차 %4.1f°    v = %+5.2f m/s', ...
                   phase_name(ph), d, ssa_deg(dpsi - psi), v);
elseif k >= nwp
    set(hTgt, 'XData', nan, 'YData', nan);
    set(hLoi, 'XData', nan, 'YData', nan);
    goal = sprintf('마지막 웨이포인트 %d 통과 (로이터 %.2f 바퀴)', nwp, tMax);
else
    set(hLoi, 'XData', nan, 'YData', nan);
    set(hTgt, 'XData', wpy(k+1), 'YData', wpx(k+1));
    d = hypot(wpx(k+1)-x_n, wpy(k+1)-y_n);
    goal = sprintf('구간 %d\\rightarrow%d    목표까지 %5.1f m    수락반경 %g m', ...
                   k, k+1, d, R);
end

set(hInfo, 'String', { ...
    sprintf('실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수.    %s', goal), ...
    sprintf(['t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°' ...
             '    상태 = %s    접안 단계 = %d'], ...
            t, x_n, y_n, ssa_deg(psi), st, ph) });

%% ---- 오른쪽 (1) : 상태 계단 -------------------------------------------
[sx, sy] = stair_xy(mSeg, t);
set(hM, 'XData', sx, 'YData', sy);
nTr = size(mSeg,1) - 1;
if nTr > 0
    title(axM, sprintf('미션 상태 — 전이 %d회  (%s s)    접안 단계 %d', ...
          nTr, strjoin(compose('%.1f', mSeg(2:end,1)'), ' \\rightarrow '), ph), ...
          'FontWeight','normal', 'Interpreter','tex');
else
    title(axM, sprintf('미션 상태 — 아직 전이 없음    로이터 %.2f / %g 바퀴', ...
          tMax, reqTurns), 'FontWeight','normal');
end

%  전이 시각에 세로 안내선을 긋는다 — 상태가 바뀐 순간 지령과 추력이 어떻게
%  움직였는지 세 칸을 위아래로 훑어 읽게 한다. 전이는 네 번뿐이라 값이 싸다
for j = (numel(hTrLine)+1) : nTr
    tt = mSeg(j+1,1);
    hTrLine(j) = xline(axP, tt, ':', 'Color',[0.45 0.45 0.45], 'LineWidth',1.1); %#ok<AGROW>
    xline(axU, tt, ':', 'Color',[0.45 0.45 0.45], 'LineWidth',1.1);
end

%  오른쪽 세 칸의 시간축을 맞춘다. 어긋나면 계단과 아래 두 칸을 겹쳐 읽을 수 없다
tEnd = max(t, 1);
xlim(axM, [0 tEnd]);  xlim(axP, [0 tEnd]);  xlim(axU, [0 tEnd]);

%% ---- 오른쪽 (2) · (3) --------------------------------------------------
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hUcmd, 'XData', tv, 'YData', Dm(:,1));
set(hU,    'XData', tv, 'YData', Dm(:,2));
set(hV,    'XData', tv, 'YData', Dm(:,3));
set(hFL,   'XData', tv, 'YData', Dm(:,4));
set(hFR,   'XData', tv, 'YData', Dm(:,5));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axP, Dp);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 상태 색과 이름 — 이 둘이 한 곳에 있어야 범례와 선체 색이 어긋나지 않는다
% =====================================================================
function c = mode_colour(m)
switch min(max(round(m),1),4)
    case 1, c = [0.00 0.45 0.74];    % WpFollow  파랑
    case 2, c = [0.95 0.45 0.20];    % Loiter    주황
    case 3, c = [0.05 0.58 0.53];    % Dock      청록 (판단·접안)
    otherwise, c = [0.55 0.55 0.55]; % Finish    회색
end
end

function n = mode_names()
n = {'1 WpFollow', '2 Loiter', '3 Dock', '4 Finish'};
end

function s = phase_name(ph)
n = {'0 접근점으로', '1 선수각 맞추기', '2 순수 옆걸음', '3 접안 완료'};
s = n{min(max(round(ph),0),3) + 1};
end

% ---- 바뀐 점만 모은 목록을 계단 좌표로 편다 ------------------------------
function [x, y] = stair_xy(seg, tNow)
if isempty(seg), x = nan; y = nan; return, end
n = size(seg,1);
x = zeros(1, 2*n);  y = zeros(1, 2*n);
x(1) = seg(1,1);  y(1) = seg(1,2);
for k = 2:n
    x(2*k-2) = seg(k,1);   y(2*k-2) = seg(k-1,2);   % 수직으로 올라가기 직전
    x(2*k-1) = seg(k,1);   y(2*k-1) = seg(k,2);     % 올라간 뒤
end
x(2*n) = max(tNow, seg(n,1));  y(2*n) = seg(n,2);
end

% =====================================================================
% 선체 다각형 — 선미는 네모, 선수는 뾰족하다 (실습 A 와 같은 모양)
% =====================================================================
function [X, Y, hx, hy] = hull_ned(x, y, psi, sc)
L = 2.45 * sc;  B = 1.03 * sc;                % 반길이 · 반폭 [m] (WAM-V 전장 4.9 m)
bx = L * [ -1   -1    0.5   1    0.5 ];       % 선미 -> 선수
by = B * [  1   -1   -1     0    1   ];
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
hx = [x, x + 2.2*L*c];                        % 선수 방향선
hy = [y, y + 2.2*L*s];
end

% ---- ssa : 최단 부호각으로 접어 deg 로 -----------------------------------
function d = ssa_deg(a)
d = atan2(sin(a), cos(a)) * 180/pi;
end

% ---- y 범위에 여백. 곡선이 테두리에 붙으면 읽히지 않는다 -----------------
function pad_y(ax, D)
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if isempty(lo) || ~isfinite(lo) || ~isfinite(hi), return, end
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
