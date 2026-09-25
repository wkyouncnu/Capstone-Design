function f = W07_animate(x_n, y_n, psi, mode, turns, psi_ref, u, gate, FL, FR, idx, t)
% W07_ANIMATE  7주차 미션 모델의 실시간 화면 — 한 창에 항적과 상태기계.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W07_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력
%     x_n, y_n : 북쪽 x · 동쪽 y [m]   (출발점 기준 상대좌표)
%     psi      : 선수각 [rad]          (북 기준 시계방향 +, NED)
%     mode     : 미션 상태 1/2/3       (1 WpFollow · 2 Loiter · 3 Finish)
%     turns    : 로이터 회전수 [바퀴]
%     psi_ref  : 미션이 고른 목표 선수각 [rad] (모드에 따라 LOS 또는 벡터필드)
%     u        : 서지 속도 [m/s]
%     gate     : 주행 허가 0/1         (Finish 에서 0 이 되어 배가 선다)
%     FL, FR   : 좌 · 우 추진기 추력 [N]
%     idx      : 지금 달리는 구간의 시작 웨이포인트 번호 (WpManager 가 기억하는 값)
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 4·5·6주차와 같은 네 칸. 오른쪽 세 칸의 내용만 7주차 것이다
%     왼쪽 큰 칸   항적 + 웨이포인트 · 수락반경 + 로이터 중심과 반경 원
%                  + 선체 모양과 선수 방향. 선체 색이 곧 지금 상태다
%                  가로축 y (동쪽), 세로축 x (북쪽) — 위쪽이 북쪽, 해도와 같다
%     오른쪽 (1)   **상태 타임라인** — mode 가 시간에 따라 어떻게 바뀌는지 계단으로
%     오른쪽 (2)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 지령 대비 응답
%     오른쪽 (3)   u_ref · u (왼쪽 축) 과 F_L · F_R (오른쪽 축)
%
%   왜 상태 타임라인에 칸 하나를 통째로 주는가
%     7주차가 답해야 하는 질문은 "지금 무엇을 할 차례인가, 그리고 언제 바뀌었는가"
%     하나다. 그 답이 mode 계단이다. 배 색만 보면 "지금" 은 알아도 "언제" 를
%     읽을 수 없다. 미션 모델에서 가장 중요한 수치는 궤적 오차가 아니라
%     **전이 시각**이므로, 그 시각을 화면에서 바로 읽게 한다.
%     계단은 mode 가 바뀐 점만 모아 그린다 — 매 스텝을 다 그리면 느려진다.
%
%   오른쪽 (2) 의 지령선은 모드에 따라 **다른 유도법칙이 낸 값**이다
%     mode 1 이면 WpManager 의 LOS, mode 2 면 LoiterVF 의 벡터필드다.
%     ModeSwitch 가 고른 뒤의 psi_ref 태그를 받으므로 이 한 선에 둘이 섞여 있다.
%     전이 순간에 지령선이 툭 튀는 것이 정상이다 — 법칙이 갈린 지점이다.
%
%   속도 지령 — 설정값 u_ref 가 아니라 u_ref × gate 를 그린다
%     내부루프의 Gate 블록이 하는 곱이 그것이다. Finish 로 들어가면 gate = 0 이
%     되어 지령이 0 으로 떨어지고 배가 선다. 설정값을 그대로 그리면 임무가
%     끝난 뒤에도 1.5 m/s 지령이 남아 있는 것처럼 보인다. 곱은 여기서 한다 —
%     모델에서 Gate 출력에 가지를 치면 Simulink 가 본선을 사선으로 다시 그어
%     배선 검사가 걸린다 (5주차 2026-09-24). gate 는 이미 태그가 있다.
%
%   출발점
%     오프라인 모델은 (0,0) 에서 출발한다. VRX 는 Nav 가 스폰 원점을 빼 주므로
%     역시 (0,0) 근처에서 시작한다. Subscribe 블록이 첫 메시지 전에 내는
%     0 으로 채운 버스도 Nav 가 걸러낸다.
%
%   그림이 느리면 W07_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axM axP axU ...
           hTrail hHull hHead hDot hInfo hTgt hLoi ...
           hM hP hPref hU hUcmd hFL hFR hTrLine ...
           trX trY tv Dp Dm mSeg wpx wpy R nwp uRef reqTurns tMax ...
           lxc lyc lrd tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W07_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime inf 라 무한정 쌓일 수 있다

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
    uRef     = evalin('base','u_ref');        % 설정값. gate 를 곱해 지령선을 만든다
    reqTurns = evalin('base','loiter_turns');

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W07 실시간 미션 화면 — 항적과 상태 타임라인', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W07_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 항적 + 웨이포인트 + 로이터 원 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    % 계획 경로와 수락반경 — 항적보다 먼저 그려 아래에 깔리게 한다
    plot(axXY, wpy, wpx, '--', 'Color',[0.35 0.35 0.35], 'LineWidth',1.3);
    th = linspace(0, 2*pi, 96);
    for i = 1:nwp
        plot(axXY, wpy(i)+R*cos(th), wpx(i)+R*sin(th), ':', 'Color',[0.6 0.6 0.6]);
    end

    % 로이터 중심과 반경 원 — 7주차에서 새로 생긴 것이라 굵은 주황으로 둔다
    plot(axXY, lyc + lrd*cos(th), lxc + lrd*sin(th), '--', ...
         'Color',[0.95 0.45 0.20], 'LineWidth',1.6);
    plot(axXY, lyc, lxc, 'p', 'MarkerEdgeColor',[0.85 0.33 0.10], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',15, 'LineWidth',1.2);
    %  글자가 항적 위에 얹히면 읽히지 않는다. 흰 바탕을 깔아 둔다
    text(axXY, lyc, lxc - 0.55*lrd, sprintf('로이터 반경 r_d = %g m', lrd), ...
         'FontSize',9.5, 'Color',[0.85 0.33 0.10], 'HorizontalAlignment','center', ...
         'BackgroundColor','w', 'Margin',1.5);

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

    % 상태 이름 범례 — 배 색이 무슨 뜻인지 그림 안에서 읽히게 한다.
    %   보이지 않는 자리에 색 견본 셋을 만들어 범례만 가져간다
    hL = gobjects(1,3);
    for i = 1:3
        hL(i) = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                      'FaceColor', mode_colour(i), 'EdgeColor',[0.15 0.15 0.15]);
    end
    legend(axXY, hL, mode_names(), 'Location','southoutside', ...
           'Orientation','horizontal', 'AutoUpdate','off');

    % 여백을 둔 축 범위 (실행 중에 바뀌지 않게 고정)
    mY = [min([wpy, lyc-lrd]) max([wpy, lyc+lrd])];
    mX = [min([wpx, lxc-lrd]) max([wpx, lxc+lrd])];
    pad = 0.20*max([diff(mY) diff(mX) 20]);
    axis(axXY, [mY(1)-pad mY(2)+pad mX(1)-pad mX(2)+pad]);

    % 상태 표시는 제목에 둔다. 그림 위에 얹으면 웨이포인트를 가린다
    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 상태 타임라인 — 7주차의 핵심 -----------------------
    axM = subplot(3,2,2, 'Parent', fig);
    hold(axM,'on'); grid(axM,'on');
    hM = stairs(axM, nan, nan, '-', 'Color',[0.49 0.18 0.56], 'LineWidth',2.0);
    ylim(axM, [0.6 3.4]);
    yticks(axM, 1:3);  yticklabels(axM, mode_names());
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
    for a = [axP axU]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);
    end
    %  상태 타임라인은 눈금이 '1 WpFollow' 처럼 길어 왼쪽 자리를 더 먹는다.
    %  오른쪽으로 밀고 폭을 더 줄여야 세 칸의 **시간축 오른쪽 끝**이 맞는다
    p = get(axM,'Position');  set(axM, 'Position', [p(1)+0.038 p(2) p(3)*0.827 p(4)]);

    tv = [];  Dp = zeros(0,2);  Dm = zeros(0,4);  mSeg = zeros(0,2);
    hTrLine = gobjects(0);  tMax = 0;
    tLast = -inf;
end
tPrev = t;

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
Dp(end+1,:) = [ssa_deg(psi_ref), ssa_deg(psi)];
Dm(end+1,:) = [uRef*gate, u, FL, FR];    % 지령 = u_ref × gate (InnerLoop 의 Gate)

%  상태 계단은 **바뀐 점만** 모은다. 매 스텝을 다 모아 그리면 300 초에 6000 점이고
%  그 점을 0.25 초마다 다시 그리게 되어 화면이 느려진다. 전이는 서너 번뿐이다
mNow = min(max(round(mode), 1), 3);
if isempty(mSeg) || mSeg(end,2) ~= mNow
    mSeg(end+1,:) = [t, mNow];   %#ok<AGROW>
end

%  TurnCount 는 로이터에서 빠져나오면 0 으로 되돌아간다. 그대로 쓰면 캡처한
%  화면에 "0.00 바퀴" 가 남아, 몇 바퀴를 돌고 나왔는지 읽을 수 없다. 최댓값을 쥔다
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
if mNow == 2
    set(hTgt, 'XData', nan, 'YData', nan);
    set(hLoi, 'XData', lyc, 'YData', lxc);
    goal = sprintf('로이터 중심 (%g, %g)    반경 %g m    %.2f / %g 바퀴', ...
                   lxc, lyc, lrd, tMax, reqTurns);
elseif mNow >= 3 || k >= nwp
    set(hTgt, 'XData', nan, 'YData', nan);
    set(hLoi, 'XData', nan, 'YData', nan);
    goal = sprintf('임무 완료 (웨이포인트 %d 통과, 로이터 %.2f 바퀴)', nwp, tMax);
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
             '    상태 = %s    로이터 %.2f / %g 바퀴'], ...
            t, x_n, y_n, ssa_deg(psi), st, tMax, reqTurns) });

%% ---- 오른쪽 (1) : 상태 계단 -------------------------------------------
[sx, sy] = stair_xy(mSeg, t);
set(hM, 'XData', sx, 'YData', sy);
nTr = size(mSeg,1) - 1;
if nTr > 0
    title(axM, sprintf('미션 상태 — 전이 %d회  (%s s)    로이터 %.2f / %g 바퀴', ...
          nTr, strjoin(compose('%.1f', mSeg(2:end,1)'), ' \\rightarrow '), ...
          tMax, reqTurns), 'FontWeight','normal', 'Interpreter','tex');
else
    title(axM, sprintf('미션 상태 — 아직 전이 없음    로이터 %.2f / %g 바퀴', ...
          tMax, reqTurns), 'FontWeight','normal');
end

%  전이 시각에 세로 안내선을 긋는다 — 상태가 바뀐 순간 지령과 추력이 어떻게
%  움직였는지 세 칸을 위아래로 훑어 읽게 한다. 전이는 서너 번뿐이라 값이 싸다
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
set(hFL,   'XData', tv, 'YData', Dm(:,3));
set(hFR,   'XData', tv, 'YData', Dm(:,4));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axP, Dp);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 상태 색과 이름 — 이 둘이 한 곳에 있어야 범례와 선체 색이 어긋나지 않는다
% =====================================================================
function c = mode_colour(m)
switch min(max(round(m),1),3)
    case 1, c = [0.00 0.45 0.74];    % WpFollow  파랑
    case 2, c = [0.95 0.45 0.20];    % Loiter    주황
    otherwise, c = [0.55 0.55 0.55]; % Finish    회색
end
end

function n = mode_names()
n = {'1 WpFollow', '2 Loiter', '3 Finish'};
end

% ---- 바뀐 점만 모은 목록을 계단 좌표로 편다 ------------------------------
%   seg = [t_k, mode_k] (mode 가 바뀐 시각만). 마지막 칸은 지금 시각까지 끈다
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
