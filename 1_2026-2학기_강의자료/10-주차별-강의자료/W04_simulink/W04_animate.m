function f = W04_animate(x_n, y_n, psi, u, v, r, FL, FR, u_ref, psi_ref, t)
% W04_ANIMATE  4주차 제어 모델의 실시간 화면 — 한 창에 궤적과 지령 대비 응답.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W04_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력
%     x_n, y_n : 북쪽 x · 동쪽 y [m]   (출발점 기준. 아래 "출발점" 참고)
%     psi      : 선수각 [rad]          (북 기준 시계방향 +, NED)
%     u, v     : 서지 · 스웨이 속도 [m/s] (배에 붙은 축)
%     r        : 요각속도 [rad/s]       (NED)
%     FL, FR   : 좌 · 우 추진기 추력 [N]
%     u_ref    : 속도 지령 [m/s].  **지령이 없는 모델은 NaN** 을 준다
%     psi_ref  : 선수각 지령 [rad]. **지령이 없는 모델은 NaN** 을 준다
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 3주차 규약과 같게, 해도와 같은 방향으로 그린다
%     왼쪽 큰 칸   궤적 + 선체 모양과 선수 방향. 가로축 y (동쪽), 세로축 x (북쪽)
%     오른쪽 (1)   u_ref 와 u 를 겹쳐서 — 속도 지령 대비 응답
%     오른쪽 (2)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 헤딩 지령 대비 응답
%     오른쪽 (3)   v · r (왼쪽 축) 과 F_L · F_R (오른쪽 축). 범례로 구분한다
%
%   왜 지령을 함께 그리는가
%     3주차까지는 "추력을 주면 배가 어떻게 가는가" 만 보면 됐다. 4주차부터는
%     **제어**를 하므로 화면이 답해야 하는 질문이 하나 늘었다 — 시킨 대로
%     따라갔는가. 지령선과 응답선이 한 칸에 겹쳐 있어야 오버슈트 · 정정시간 ·
%     남는 오차가 눈으로 읽힌다. 두 칸으로 나누면 눈이 두 번 왕복해야 한다.
%
%   지령이 없는 모델
%     W04_1_straight · W04_2_turn · W04_5_offline 은 추력을 직접 준다 (개루프).
%     W04_3_heading 계열은 헤딩만 돌린다 — 속도 지령이 없다.
%     그 칸은 응답만 그리고 "지령 없음 (개루프)" 라고 적는다. 빈 칸으로 두면
%     학생은 그림이 고장난 줄 안다.
%
%   출발점
%     VRX 의 ground truth odometry 는 Gazebo 월드 원점 기준이라 스폰 위치만큼
%     (수백 m) 떨어진 값이 들어온다. 또 Subscribe 블록은 첫 메시지 전에 0 으로
%     채운 버스를 내므로 (CLAUDE.md §11) 맨 앞 몇 샘플이 (0, 0) 이다.
%     그래서 **0 이 아닌 첫 샘플을 출발점으로 잡고** 거기서부터 상대좌표로 그린다.
%     오프라인 모델은 애초에 0 에서 출발하므로 아무 일도 일어나지 않는다.
%
%   그림이 느리면 W04_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axU axP axM ...
           hTrail hHull hHead hDot hInfo ...
           hU hUref hP hPref hV hR hFL hFR ...
           trX trY tv Du Dp Dm x0 y0 haveOrigin tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W04_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W04 실시간 제어 화면 — 궤적과 지령 대비 응답', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W04_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 궤적 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');
    plot(axXY, 0, 0, '+', 'Color',[0.80 0.15 0.15], 'MarkerSize',12, 'LineWidth',1.8);
    text(axXY, 0.8, 0.8, '출발점', 'Color',[0.80 0.15 0.15], 'FontSize',10);
    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);
    hHull  = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                   'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.85, ...
                   'EdgeColor',[0.05 0.30 0.05], 'LineWidth',1.4);
    hHead  = plot(axXY, nan, nan, '-', 'Color','k', 'LineWidth',2);
    hDot   = plot(axXY, nan, nan, 'k.', 'MarkerSize',12);
    hInfo  = title(axXY, '', 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 속도 지령 대비 응답 ----
    axU = subplot(3,2,2, 'Parent', fig);
    hold(axU,'on'); grid(axU,'on');
    hUref = plot(axU, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hU    = plot(axU, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    ylabel(axU,'u [m/s]');

    % ---- 오른쪽 (2) : 헤딩 지령 대비 응답 ----
    axP = subplot(3,2,4, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');

    % ---- 오른쪽 (3) : 나머지 상태와 추력 ----
    %   v · r 은 m/s · deg/s, 추력은 N 이라 자릿수가 다르다. 한 축에 겹쳐 놓으면
    %   v 가 0 인 직선으로 보인다. 그래서 축을 둘로 나누고 범례로 묶는다.
    axM = subplot(3,2,6, 'Parent', fig);
    yyaxis(axM,'left');
    hold(axM,'on'); grid(axM,'on');
    hV = plot(axM, nan, nan, '-',  'Color',[0.47 0.67 0.19], 'LineWidth',1.4);
    hR = plot(axM, nan, nan, '-',  'Color',[0.49 0.18 0.56], 'LineWidth',1.4);
    ylabel(axM,'v [m/s] · r [deg/s]');
    yyaxis(axM,'right');
    hold(axM,'on');
    hFL = plot(axM, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.3);
    hFR = plot(axM, nan, nan, '--', 'Color',[0.85 0.33 0.10], 'LineWidth',1.3);
    ylabel(axM,'추력 [N]');
    xlabel(axM,'시간 [s]');
    legend(axM, [hV hR hFL hFR], {'v','r','F_L','F_R'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    %  yyaxis 는 두 축의 색을 제멋대로 칠한다. 범례가 색을 나르므로 축 글자는 검게 둔다
    axM.YAxis(1).Color = [0.15 0.15 0.15];
    axM.YAxis(2).Color = [0.15 0.15 0.15];

    %  오른쪽 세 칸의 y 이름표가 창 오른쪽 테두리에 잘리지 않게 폭을 조금 줄인다
    for a = [axU axP axM]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end

    tv = [];  Du = zeros(0,2);  Dp = zeros(0,2);  Dm = zeros(0,4);
    x0 = 0;  y0 = 0;  haveOrigin = false;
    tLast = -inf;
end
tPrev = t;

%% ---- 출발점 잡기 — 0 으로 채운 첫 버스를 버린다 -------------------------
%  첫 쓸모 있는 샘플에서 제목과 범례를 정한다. 지령이 있는지 없는지는 한 실행
%  안에서 바뀌지 않으므로 (NaN 은 빌더가 고정으로 넣는다) 한 번만 정하면 된다.
if ~haveOrigin
    if x_n ~= 0 || y_n ~= 0
        x0 = x_n;  y0 = y_n;  haveOrigin = true;
        label_panel(axU, hUref, hU, isnan(u_ref),   '속도',  'u');
        label_panel(axP, hPref, hP, isnan(psi_ref), '선수각 (ssa 로 접은 값)', '\psi');
    else
        return                    % 아직 첫 메시지가 오지 않았다. 그리지 않는다
    end
end

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
dx = x_n - x0;   dy = y_n - y0;
trX(end+1) = dx;  trY(end+1) = dy;
tv(end+1)  = t;
Du(end+1,:) = [u_ref, u];
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
Dm(end+1,:) = [v, r*180/pi, FL, FR];
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    Du(1:k,:) = [];  Dp(1:k,:) = [];  Dm(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 궤적과 선체 ------------------------------------------------
[hX, hY, hdx, hdy] = hull_ned(dx, dy, psi);
set(hTrail, 'XData', trY,  'YData', trX);
set(hHull,  'XData', hY,   'YData', hX);
set(hHead,  'XData', hdy,  'YData', hdx);
set(hDot,   'XData', dy,   'YData', dx);
set(hInfo,  'String', { '실시간 항적 — 위쪽이 북쪽, 뾰족한 쪽이 선수', ...
    sprintf('t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°    u = %5.2f m/s', ...
            t, dx, dy, ssa_deg(psi), u) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hU,    'XData', tv, 'YData', Du(:,2));
set(hUref, 'XData', tv, 'YData', Du(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hV,    'XData', tv, 'YData', Dm(:,1));
set(hR,    'XData', tv, 'YData', Dm(:,2));
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));

%  지령선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axU, Du);
pad_y(axP, Dp);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 선체 다각형 — 선미는 네모, 선수는 뾰족하다 (3주차 W03_hull 과 같은 모양)
%   여기서는 **NED 그대로** 계산한다. 3주차 것은 수학 좌표를 받으므로
%   부르는 쪽이 th = pi/2 - psi 를 계산해야 했다. 그 한 줄을 안으로 넣었다.
%
%     N = x + bx cos(psi) - by sin(psi)
%     E = y + bx sin(psi) + by cos(psi)
% =====================================================================
function [X, Y, hx, hy] = hull_ned(x, y, psi)
L = 3.0;  B = 0.45*L;                            % 반길이 · 반폭 [m] (WAM-V 전장 약 4.9 m)
bx = L * [ -1   -1    0.35   1    0.35  -1 ];    % 선미 -> 선수 -> 선미 (닫힌 도형)
by = B * [  1   -1   -1      0    1      1 ];
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
hx = [x, x + 2.2*L*c];                           % 선수 방향선
hy = [y, y + 2.2*L*s];
end

% ---- ssa : 최단 부호각으로 접어 deg 로 (NaN 은 NaN 그대로 통과) ----------
function d = ssa_deg(a)
d = atan2(sin(a), cos(a)) * 180/pi;
end

% =====================================================================
% 지령 칸의 제목과 범례 — 지령이 있는 모델인지 첫 샘플에서 한 번만 정한다
%
%   "지령 없음" 을 그림 안에 글자로 얹으면 응답선과 겹친다 (응답선은 대개
%   왼쪽 위를 지난다). 그래서 제목에 적고, 없는 신호는 범례에서도 뺀다.
%   그리지도 않는 선을 범례에 남겨 두면 학생은 그 선을 찾아 헤맨다.
% =====================================================================
function label_panel(ax, hRef, hRes, none, what, sym)
if none
    title(ax, sprintf('%s — 지령 없음 (개루프). 응답만 그린다', what), 'FontWeight','normal');
    legend(ax, hRes, {sprintf('%s (응답)', sym)}, ...
           'Location','southeast', 'AutoUpdate','off');
else
    title(ax, sprintf('%s — 지령 대비 응답', what), 'FontWeight','normal');
    legend(ax, [hRef hRes], {sprintf('%s_{ref} (지령)', sym), sprintf('%s (응답)', sym)}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');
end
end

% ---- y 범위에 5 % 여백. 지령선이 테두리에 붙으면 읽히지 않는다 -----------
function pad_y(ax, D)
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if isempty(lo) || ~isfinite(lo) || ~isfinite(hi), return, end
%  t = 0 에서는 값이 전부 같다 (lo == hi). 그때 여백을 비율로만 잡으면 위아래
%  한계가 같은 수가 되어 ylim 이 거부한다. 바닥값을 둔다.
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
