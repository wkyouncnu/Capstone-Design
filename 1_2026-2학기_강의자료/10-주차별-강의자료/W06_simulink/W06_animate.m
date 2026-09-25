function f = W06_animate(x_n, y_n, psi, psi_ref, r_dist, turns, u, u_cmd, gate, FL, FR, t)
% W06_ANIMATE  6주차 로이터링 모델의 실시간 화면 — 한 창에 항적과 로이터 지표.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W06_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력  (빌더 build_w06_models.m 의 addAnimate 가 거는 태그 순서와 같다)
%     x_n, y_n : 북쪽 x · 동쪽 y [m]   (출발점 기준 상대좌표)
%     psi      : 선수각 [rad]          (북 기준 시계방향 +, NED)
%     psi_ref  : 벡터필드가 낸 목표 선수각 [rad]
%                crab_comp = 0 이면 이것이 곧 목표 침로 chi_d 다 (LoiterVF 의 식 13)
%     r_dist   : 로이터 중심까지의 실제 거리 [m]  (LoiterVF 가 내는 r. 6주차의 핵심 지표)
%     turns    : 지금까지 돈 바퀴 수    (TurnCount 가 세는 값)
%     u        : 서지 속도 [m/s]
%     u_cmd    : 시나리오가 정한 목표 속도 [m/s]  (Schedule 의 vd)
%     gate     : 주행 허가 0/1          (바퀴를 다 돌면 0 이 되어 배가 선다)
%     FL, FR   : 좌 · 우 추진기 추력 [N]
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 4 · 5주차 화면과 같은 네 칸. 오른쪽 세 칸의 내용만 6주차 것이다
%     왼쪽 큰 칸   항적 + **로이터 중심과 목표 반경 원** + 선체 모양과 선수 방향
%                  + 지나온 바퀴 수. 가로축 y (동쪽), 세로축 x (북쪽) — 위쪽이 북쪽
%     오른쪽 (1)   r 과 r_d 를 겹쳐서 [m] — **6주차의 핵심 지표**
%     오른쪽 (2)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 지령 대비 응답
%     오른쪽 (3)   u_ref · u (왼쪽 축) 과 F_L · F_R (오른쪽 축). 범례로 구분한다
%
%   왜 반경에 칸 하나를 통째로 주는가
%     6주차가 답해야 하는 질문은 "한 점을 중심으로 돌고 있는가" 하나다. 그 답이
%     중심까지의 거리 r 이다. 벡터필드는 식 (9) 의 지름 성분으로 r 을 r_d 로
%     몰아붙이므로, r 곡선이 r_d 선에 붙는 모양이 곧 유도 법칙이 일하는 모습이다.
%     항적만 보면 "대충 원 같다" 에서 멈추고 몇 미터 어긋났는지 읽을 수 없다.
%     **r 은 r_d 에 딱 붙지 않고 일정한 간격을 남긴다.** 그 간격이 p_c 에 비례하는
%     정상상태 오차이며 (6주차 1-8 절), 두 선을 겹쳐 그려야 그것이 보인다.
%
%   목표 반경 r_d 를 왜 태그로 받지 않는가
%     r_d 는 Guidance 안 Schedule 블록의 3번 출력이다. 거기에 가지를 쳐서 태그를
%     걸면 Simulink 가 본선을 몇 px 사선으로 다시 그어 배선 검사가 걸린다
%     (5주차에서 Gate 출력에 가지를 치다 실제로 밟았다 — W05_animate 주석).
%     Schedule 은 시각 t 만 보는 순수 함수이므로, 같은 규칙을 여기서 다시 계산한다
%     (아래 sched_rd). 모델을 건드리지 않고 같은 값을 얻는다.
%
%   속도 지령 — u_cmd 가 아니라 u_cmd x gate 를 그린다
%     내부루프의 Gate 블록이 하는 곱이 그것이다. 바퀴를 다 돌면 gate = 0 이 되어
%     지령이 0 으로 떨어지고 배가 선다. u_cmd 를 그대로 그리면 임무가 끝난 뒤에도
%     1.5 m/s 지령이 남아 있는 것처럼 보인다. gate 는 이미 태그가 있으므로
%     신호를 새로 뽑지 않고도 같은 값이 된다.
%
%   출발점
%     오프라인 모델은 (0,0) 에서 출발한다. VRX 는 Nav 가 스폰 원점을 빼 주므로
%     역시 (0,0) 근처에서 시작한다. Subscribe 블록이 첫 메시지 전에 내는
%     0 으로 채운 버스도 Nav 가 걸러낸다.
%
%   그림이 느리면 W06_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axR axP axU ...
           hTrail hHull hHead hDot hInfo hSpoke hCircle ...
           hR hRd hP hPref hU hUcmd hFL hFR ...
           trX trY tv Dr Dp Dm cn ce rd0 useSch tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W06_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    cn     = evalin('base', 'center_north');
    ce     = evalin('base', 'center_east');
    rd0    = evalin('base', 'r_d');
    useSch = evalin('base', 'use_schedule');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W06 실시간 로이터링 화면 — 항적과 반경', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W06_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 항적 + 목표 원 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    % 목표 원 — 항적보다 먼저 그려 아래에 깔리게 한다.
    % 시나리오로 반경이 바뀌면 아래에서 XData/YData 를 다시 쓴다
    hCircle = plot(axXY, nan, nan, '--', 'Color',[0.75 0.10 0.10], 'LineWidth',1.6);

    % 중심에서 배까지의 살 — 이것의 길이가 오른쪽 (1) 의 r 이다
    hSpoke = plot(axXY, nan, nan, '-', 'Color',[0.70 0.70 0.70], 'LineWidth',1.0);

    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);

    % 중심점 — 별표. 항적 위에 오도록 뒤에 그린다
    plot(axXY, ce, cn, 'p', 'MarkerEdgeColor',[0.75 0.10 0.10], ...
         'MarkerFaceColor',[1 0.85 0.20], 'MarkerSize',18, 'LineWidth',1.2);
    text(axXY, ce+2.5, cn-4.5, '중심', 'FontSize',11, 'Color',[0.75 0.10 0.10]);

    hHull = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                  'FaceColor',[0.95 0.45 0.20], 'FaceAlpha',0.90, ...
                  'EdgeColor',[0.40 0.15 0.05], 'LineWidth',1.2);
    hHead = plot(axXY, nan, nan, '-', 'Color',[0.40 0.15 0.05], 'LineWidth',1.6);
    hDot  = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);

    % 축 범위는 실행 중에 바뀌지 않게 고정한다. 출발점 (0,0) 과 가장 큰 원이
    % 모두 들어가야 한다 — 시나리오는 반경을 줄이기만 하므로 rd0 로 잡으면 된다
    pad = 1.9*rd0;
    axis(axXY, [min(ce-pad,-5) max(ce+pad,5) min(cn-pad,-5) max(cn+pad,5)]);

    % 상태 표시는 제목에 둔다. 그림 위에 얹으면 목표 원을 가린다
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 반경 — 6주차의 핵심 지표 ----
    %   차이만 그리면 "몇 m 짜리 원에서 몇 m 어긋났나" 가 안 보인다. 두 선을
    %   겹쳐 그려야 간격이 일정하게 남는 모습(정상상태 오차)이 한눈에 읽힌다
    axR = subplot(3,2,2, 'Parent', fig);
    hold(axR,'on'); grid(axR,'on');
    hRd = plot(axR, nan, nan, '--', 'Color',[0.75 0.10 0.10], 'LineWidth',1.6);
    hR  = plot(axR, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    ylabel(axR,'반경 [m]');
    title(axR, '중심까지의 거리 — r 이 r_d 에 붙으면 로이터 성공', 'FontWeight','normal');
    legend(axR, [hRd hR], {'r_d (목표 반경)','r (실제 거리)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (2) : 헤딩 지령 대비 응답 ----
    axP = subplot(3,2,4, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');
    title(axP, '선수각 — 지령 대비 응답 (ssa 로 접은 값)', 'FontWeight','normal');
    legend(axP, [hPref hP], {'\psi_{ref} (= 벡터필드 침로 \chi_d)','\psi (응답)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

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
    for a = [axR axP axU]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end

    tv = [];  Dr = zeros(0,2);  Dp = zeros(0,2);  Dm = zeros(0,4);
    tLast = -inf;
end
tPrev = t;

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
rd = sched_rd(t, rd0, useSch);          % 지금 시각의 목표 반경

trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
Dr(end+1,:) = [rd, r_dist];
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
Dm(end+1,:) = [u_cmd*gate, u, FL, FR];   % 지령 = u_cmd x gate (InnerLoop 의 Gate)
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    Dr(1:k,:) = [];  Dp(1:k,:) = [];  Dm(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 목표 원 · 항적 · 선체 · 중심까지의 살 ----------------------
th = linspace(0, 2*pi, 200);
set(hCircle, 'XData', ce + rd*cos(th), 'YData', cn + rd*sin(th));

sc = 1.5;
try, sc = evalin('base','boat_scale'); catch, end
[hX, hY, hdx, hdy] = hull_ned(x_n, y_n, psi, sc);
set(hTrail,  'XData', trY,       'YData', trX);
set(hHull,   'XData', hY,        'YData', hX);
set(hHead,   'XData', hdy,       'YData', hdx);
set(hDot,    'XData', y_n,       'YData', x_n);
set(hSpoke,  'XData', [ce y_n],  'YData', [cn x_n]);

e = r_dist - rd;                         % 반경 오차. + 는 원 바깥
if gate < 0.5
    goal = sprintf('임무 완료 (%.2f 바퀴)', turns);
else
    goal = sprintf('%.2f 바퀴째    반경오차 %+.2f m', turns, e);
end

set(hInfo, 'String', { ...
    sprintf('실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수.    %s', goal), ...
    sprintf('t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°    r = %6.2f m  (r_d = %g m)', ...
            t, x_n, y_n, ssa_deg(psi), r_dist, rd) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hRd,   'XData', tv, 'YData', Dr(:,1));
set(hR,    'XData', tv, 'YData', Dr(:,2));
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hUcmd, 'XData', tv, 'YData', Dm(:,1));
set(hU,    'XData', tv, 'YData', Dm(:,2));
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axR, Dr);
pad_y(axP, Dp);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 목표 반경 — Guidance 안 Schedule 블록과 **같은 규칙**이다
%   Schedule 은 시각 t 만 보는 순수 함수라 여기서 그대로 다시 계산할 수 있다.
%   모델 쪽 규칙을 고치면 이 함수도 같이 고친다 (build_w06_models.m 의 Schedule).
%   방향(pc)과 속도(vd)는 태그가 이미 있으므로 (u_cmd) 여기서 다루지 않는다.
% =====================================================================
function rd = sched_rd(t, rd0, use)
if use < 0.5 || t < 450
    rd = rd0;
else
    rd = rd0 * 0.6;        % 450 s 이후 — 더 작은 원
end
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
