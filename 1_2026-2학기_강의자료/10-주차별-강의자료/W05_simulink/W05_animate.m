function f = W05_animate(x_n, y_n, psi, psi_ref, y_e, u, gate, FL, FR, wp_idx, t)
% W05_ANIMATE  5주차 유도 모델의 실시간 화면 — 한 창에 항적과 유도 지표.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W05_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력
%     x_n, y_n : 북쪽 x · 동쪽 y [m]   (출발점 기준 상대좌표)
%     psi      : 선수각 [rad]          (북 기준 시계방향 +, NED)
%     psi_ref  : 유도부가 낸 목표 선수각 [rad]
%     y_e      : 횡방향 오차 [m]       (경로 왼쪽이 +. 5주차의 핵심 지표)
%     u        : 서지 속도 [m/s]
%     gate     : 주행 허가 0/1         (유도부가 낸 값. 아래 "속도 지령" 참고)
%     FL, FR   : 좌 · 우 추진기 추력 [N]
%     wp_idx   : 지금 달리는 구간의 시작 웨이포인트 번호 (유도부가 기억하는 값)
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 4주차 W04_animate 와 같은 배치. 오른쪽 세 칸의 내용만 5주차 것이다
%     왼쪽 큰 칸   항적 + 웨이포인트 · 수락반경 + 선체 모양과 선수 방향
%                  가로축 y (동쪽), 세로축 x (북쪽) — 위쪽이 북쪽, 해도와 같다
%     오른쪽 (1)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 지령 대비 응답
%     오른쪽 (2)   y_e 와 0 선 — 유도가 되고 있는가를 한 숫자로 말한다
%     오른쪽 (3)   u_ref · u (왼쪽 축) 과 F_L · F_R (오른쪽 축). 범례로 구분한다
%
%   왜 y_e 에 칸 하나를 통째로 주는가
%     5주차가 답해야 하는 질문은 "경로를 따라가고 있는가" 하나다. 그 답이 y_e 다.
%     LOS 는 psi_ref = pi_p - atan(y_e/Delta) 로 y_e 를 직접 0 으로 몰아붙이므로,
%     y_e 곡선이 0 으로 내려오는 모양이 곧 유도 법칙이 일하는 모습이다.
%     항적만 보면 "대충 맞는 것 같다" 에서 멈추고 몇 미터인지 읽을 수 없다.
%
%   속도 지령 — 설정값 u_ref 가 아니라 u_ref × gate 를 그린다
%     내부루프의 Gate 블록이 하는 곱이 그것이다. 마지막 웨이포인트를 지나면
%     gate = 0 이 되어 지령이 0 으로 떨어지고 배가 선다. 설정값 u_ref 를 그대로
%     그리면 완주 뒤에도 1.5 m/s 지령이 남아 있는 것처럼 보인다.
%     곱은 여기서 한다. 모델에서 Gate 출력에 가지를 치면 Simulink 가 본선을
%     5 px 사선으로 다시 그어 배선 검사가 걸린다 (2026-09-24). gate 는 이미
%     태그가 있고 u_ref 는 설정값이므로, 신호를 새로 뽑지 않고도 같은 값이 된다.
%
%   출발점
%     오프라인 모델은 (0,0) 에서 출발한다. VRX 는 Nav 가 스폰 원점을 빼 주므로
%     역시 (0,0) 근처에서 시작한다. Subscribe 블록이 첫 메시지 전에 내는
%     0 으로 채운 버스도 Nav 가 걸러낸다.
%
%   그림이 느리면 W05_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axP axE axU ...
           hTrail hHull hHead hDot hInfo hTgt ...
           hP hPref hE hU hUcmd hFL hFR ...
           trX trY tv Dp De Dm wpx wpy R nwp uRef tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W05_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    R   = evalin('base', 'R_LOS');
    nwp = numel(wpx);
    uRef = evalin('base', 'u_ref');      % 설정값. gate 를 곱해 지령선을 만든다

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W05 실시간 유도 화면 — 항적과 횡방향 오차', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W05_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 항적 + 웨이포인트 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    % 계획 경로와 수락반경 — 항적보다 먼저 그려 아래에 깔리게 한다
    plot(axXY, wpy, wpx, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 72);
    for i = 1:nwp
        plot(axXY, wpy(i)+R*cos(th), wpx(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);

    % 지금 겨누는 웨이포인트를 굵은 초록 원으로 표시한다
    hTgt = plot(axXY, nan, nan, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
                'MarkerSize',20, 'LineWidth',2.0);

    % 웨이포인트 표식과 번호는 항적 위에 그린다
    for i = 1:nwp
        plot(axXY, wpy(i), wpx(i), 's', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
             'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.8);
        text(axXY, wpy(i)+4, wpx(i)+5, sprintf('%d', i), ...
             'FontSize',12, 'Color',[0.75 0.10 0.10], 'FontWeight','bold');
    end

    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.90, ...
                   'EdgeColor',[0.40 0.15 0.05], 'LineWidth',1.2);
    hHead  = plot(axXY, nan, nan, '-', 'Color',[0.40 0.15 0.05], 'LineWidth',1.6);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);

    % 여백을 둔 축 범위 (실행 중에 바뀌지 않게 고정)
    mY = [min(wpy) max(wpy)];  mX = [min(wpx) max(wpx)];
    pad = 0.25*max([diff(mY) diff(mX) 20]);
    axis(axXY, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);

    % 상태 표시는 제목에 둔다. 그림 위에 얹으면 웨이포인트를 가린다
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 헤딩 지령 대비 응답 ----
    axP = subplot(3,2,2, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');
    title(axP, '선수각 — 지령 대비 응답 (ssa 로 접은 값)', 'FontWeight','normal');
    legend(axP, [hPref hP], {'\psi_{ref} (유도 지령)','\psi (응답)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (2) : 횡방향 오차 ----
    %   5주차의 핵심 지표다. 0 선을 함께 그려야 "붙었다" 를 눈으로 판정할 수 있다
    axE = subplot(3,2,4, 'Parent', fig);
    hold(axE,'on'); grid(axE,'on');
    yline(axE, 0, '-', 'Color',[0.40 0.40 0.40], 'LineWidth',1.2);
    hE = plot(axE, nan, nan, '-', 'Color',[0.47 0.25 0.80], 'LineWidth',1.6);
    ylabel(axE,'y_e [m]');
    title(axE, '횡방향 오차 — 0 으로 내려와 붙으면 유도 성공', 'FontWeight','normal');
    legend(axE, hE, {'y_e (경로 왼쪽이 +)'}, 'Location','southeast', 'AutoUpdate','off');

    % ---- 오른쪽 (3) : 속도 지령 대비 응답과 추력 ----
    %   u 는 1.x m/s, 추력은 수백 N 이라 자릿수가 다르다. 한 축에 겹쳐 놓으면
    %   u 가 0 인 직선으로 보인다. 그래서 축을 둘로 나누고 범례로 묶는다.
    axU = subplot(3,2,6, 'Parent', fig);
    yyaxis(axU,'left');
    hold(axU,'on'); grid(axU,'on');
    hUcmd = plot(axU, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hU    = plot(axU, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    ylabel(axU,'u [m/s]');
    yyaxis(axU,'right');
    hold(axU,'on');
    hFL = plot(axU, nan, nan, '-',  'Color',[0.47 0.67 0.19], 'LineWidth',1.3);
    hFR = plot(axU, nan, nan, '--', 'Color',[0.49 0.18 0.56], 'LineWidth',1.3);
    ylabel(axU,'추력 [N]');
    xlabel(axU,'시간 [s]');
    legend(axU, [hUcmd hU hFL hFR], {'u_{ref} (지령)','u (응답)','F_L','F_R'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    %  yyaxis 는 두 축의 색을 제멋대로 칠한다. 범례가 색을 나르므로 축 글자는 검게 둔다
    axU.YAxis(1).Color = [0.15 0.15 0.15];
    axU.YAxis(2).Color = [0.15 0.15 0.15];

    %  오른쪽 세 칸의 y 이름표가 창 오른쪽 테두리에 잘리지 않게 폭을 조금 줄인다
    for a = [axP axE axU]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end

    tv = [];  Dp = zeros(0,2);  De = zeros(0,1);  Dm = zeros(0,4);
    tLast = -inf;
end
tPrev = t;

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
De(end+1,1) = y_e;
Dm(end+1,:) = [uRef*gate, u, FL, FR];    % 지령 = u_ref × gate (InnerLoop 의 Gate)
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    Dp(1:k,:) = [];  De(1:k,:) = [];  Dm(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 항적 · 선체 · 지금 겨누는 웨이포인트 ------------------------
sc = 3;
try, sc = evalin('base','boat_scale'); catch, end
[hX, hY, hdx, hdy] = hull_ned(x_n, y_n, psi, sc);
set(hTrail, 'XData', trY,  'YData', trX);
set(hHull,  'XData', hY,   'YData', hX);
set(hHead,  'XData', hdy,  'YData', hdx);
set(hDot,   'XData', y_n,  'YData', x_n);

%  유도부의 wp_idx 는 **구간의 시작** 번호다. 겨누는 것은 그다음 점이다.
%  wp_idx 가 마지막 번호가 되면 임무가 끝난 것이므로 표식을 지운다.
k = min(max(round(wp_idx), 1), nwp);
if k >= nwp
    set(hTgt, 'XData', nan, 'YData', nan);
    goal = sprintf('임무 완료 (웨이포인트 %d 통과)', nwp);
else
    set(hTgt, 'XData', wpy(k+1), 'YData', wpx(k+1));
    d = hypot(wpx(k+1)-x_n, wpy(k+1)-y_n);
    goal = sprintf('구간 %d\\rightarrow%d    목표까지 %5.1f m    수락반경 %g m', ...
                   k, k+1, d, R);
end

set(hInfo, 'String', { ...
    sprintf('실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수.    %s', goal), ...
    sprintf('t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°    y_e = %6.2f m', ...
            t, x_n, y_n, ssa_deg(psi), y_e) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hE,    'XData', tv, 'YData', De(:,1));
set(hUcmd, 'XData', tv, 'YData', Dm(:,1));
set(hU,    'XData', tv, 'YData', Dm(:,2));
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axP, Dp);
pad_y(axE, De);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 선체 다각형 — 선미는 네모, 선수는 뾰족하다 (W05_matlab/shipModel.m 과 같은 모양)
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
%  t = 0 에서는 값이 전부 같다 (lo == hi). 그때 여백을 비율로만 잡으면 위아래
%  한계가 같은 수가 되어 ylim 이 거부한다. 바닥값을 둔다.
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
