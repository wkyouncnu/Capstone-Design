function f = W08_animate(eta, eta_d, eta_raw, Dact, Tact, t)
% W08_ANIMATE  8주차 DP 모델의 실시간 화면 — 한 창에 위치 평면과 DP 지표 셋.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 신호를 어디서 뽑았는지뿐이다 (운동방정식 vs ground truth odometry).
%
%   f = W08_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력
%     eta      : [x_n; y_n; psi]  현재 자세 [m, m, rad] (NED)
%     eta_d    : [x_n; y_n; psi]  **기준모델이 매끈하게 만든** 목표 자세
%     eta_raw  : [x_n; y_n; psi]  **계단 목표** (dp_step 표가 시킨 값)
%     Dact     : [2x1] 추진기 방위각 [rad] (선체계, y 우현이 +)
%     Tact     : [2x1] 추진기 추력   [N]
%     t        : 시뮬레이션 시각 [s]
%
%   화면 배치 — 4~7주차 규약과 같은 네 칸. 오른쪽 세 칸의 내용만 8주차 것이다
%     왼쪽 큰 칸   위치 평면. 목표 자세와 현재 자세, 선체와 선수 방향,
%                  그 위에 **추진기의 방위각·추력 화살표**
%                  가로축 y (동쪽), 세로축 x (북쪽) — 위쪽이 북쪽, 해도와 같다
%     오른쪽 (1)   **위치 오차** e_x · e_y 와 거리 |e|, 그리고 0 선 — DP 의 핵심 지표
%     오른쪽 (2)   psi_ref 와 psi 를 겹쳐서 [deg, ssa 적용] — 지령 대비 응답
%     오른쪽 (3)   추진기 추력 T_i (왼쪽 축) 과 방위각 delta_i (오른쪽 축)
%
%   왜 위치 오차에 칸 하나를 통째로 주는가
%     8주차가 답해야 하는 질문은 "제자리를 지키고 있는가" 하나다. 그 답이
%     위치 오차다. 평면 그림만 보면 "대충 목표 근처" 에서 멈추고 몇 cm 인지
%     읽을 수 없다. 5주차가 y_e 에 칸을 준 것과 같은 이유다.
%
%   추진기는 **두 기**다 — 힘 성분이 넷일 뿐이다
%     VRX 의 WAM-V 는 후방 방위추진기 2기를 단다 (wamv_aft_thrusters.xacro).
%     배분 행렬 T_e 가 4열인 것은 추진기가 넷이어서가 아니라, 한 기의 힘을
%     (F_x, F_y) 두 성분으로 쪼개 두었기 때문이다 — 제어입력 4개, 추진기 2기.
%     그래서 화살표도 둘, 오른쪽 ③ 의 곡선도 추력 둘 · 방위각 둘이다.
%     (W08_setup §1~2 와 같은 이야기. 넷을 그리면 없는 추진기를 그리는 것이다)
%
%   목표가 둘인 이유
%     dp_step 표는 목표를 **계단**으로 옮긴다 (eta_raw). 그대로 좇으면 배가
%     낼 수 없는 가속을 요구하므로 DPRef 의 기준모델이 매끈한 궤적 eta_d 로
%     바꾼다. 평면에는 둘 다 찍는다 — 회색 사각형이 시킨 곳, 초록 원이
%     지금 좇는 곳이다. 오차 칸은 **기준모델 목표 eta_d 기준**으로 잰다.
%
%   그림이 느리면 W08_setup.m 에서 animate = 0 또는 animate_every 를 키운다.

persistent fig axXY axE axP axT ...
           hTrail hHull hHead hDot hTgt hTgtHead hRaw hInfo hArr ...
           hEx hEy hEn hPref hP hT1 hT2 hD1 hD2 ...
           trX trY tv De Dp Dt xt yt Fmax delMax scale tLast tPrev

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W08_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 StopTime 을 길게 주면 무한정 쌓인다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    xt     = evalin('base','thr_x');
    yt     = evalin('base','thr_y');
    Fmax   = evalin('base','F_max');
    delMax = evalin('base','del_max');
    scale  = 2;
    try, scale = evalin('base','boat_scale'); catch, end

    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W08 실시간 DP 화면 — 위치 평면과 오차·지령·추진기', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W08_anim_fig', fig);

    % ---- 왼쪽 큰 칸 : 위치 평면 -------------------------------------
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');

    %  그리는 차례가 곧 위아래 차례다 (나중에 그린 것이 위로 온다).
    %  DP 는 **목표 위에 배가 겹쳐 있는** 것이 정상이므로, 목표 표식을 선체보다
    %  먼저 그리면 성공했을 때 목표가 선체 밑으로 사라진다. 그래서
    %  항적 -> 선체 -> 목표 -> 추진기 화살표 차례로 그린다.
    trX = [];  trY = [];
    hTrail = plot(axXY, nan, nan, '-', 'Color',[0 0.45 0.74], 'LineWidth',1.5);

    hHull = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                  'FaceColor',[0.85 0.92 1.00], 'FaceAlpha',0.55, ...
                  'EdgeColor',[0.10 0.20 0.50], 'LineWidth',1.3);
    hHead = plot(axXY, nan, nan, '-', 'Color',[0.10 0.20 0.50], 'LineWidth',1.6);

    % 계단 목표 — 시킨 곳
    hRaw = plot(axXY, nan, nan, 's', 'MarkerEdgeColor',[0.35 0.35 0.35], ...
                'MarkerFaceColor','none', 'MarkerSize',14, 'LineWidth',1.6);

    % 기준모델 목표 — 지금 좇는 곳. 그 자리의 목표 선수각도 함께 그린다
    hTgtHead = plot(axXY, nan, nan, '--', 'Color',[0.00 0.50 0.00], 'LineWidth',1.6);
    hTgt     = plot(axXY, nan, nan, 'o', 'MarkerEdgeColor',[0.00 0.50 0.00], ...
                    'MarkerSize',18, 'LineWidth',2.0);
    hDot  = plot(axXY, nan, nan, 'k.', 'MarkerSize',10);

    % 추진기 화살표 둘 — 좌현 빨강, 우현 자홍 (오른쪽 ③ 의 범례와 같은 색)
    hArr(1) = plot(axXY, nan, nan, '-', 'Color',[0.85 0.10 0.10], 'LineWidth',2.5);
    hArr(2) = plot(axXY, nan, nan, '-', 'Color',[0.75 0.10 0.75], 'LineWidth',2.5);

    legend(axXY, [hRaw hTgt hTrail hArr(1) hArr(2)], ...
           {'계단 목표 \eta_{raw}','기준모델 목표 \eta_d','항적', ...
            '좌현 추진기','우현 추진기'}, ...
           'Location','southoutside', 'Orientation','horizontal', ...
           'NumColumns',3, 'AutoUpdate','off');

    hInfo = title(axXY, '', 'FontSize',10, 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 위치 오차 -------------------------------------
    %   8주차의 핵심 지표다. 0 선을 함께 그려야 "제자리를 지켰다" 를 눈으로
    %   판정할 수 있다. 거리 |e| 는 굵게 — 한 숫자로 답하는 선이다
    axE = subplot(3,2,2, 'Parent', fig);
    hold(axE,'on'); grid(axE,'on');
    yline(axE, 0, '-', 'Color',[0.40 0.40 0.40], 'LineWidth',1.2);
    hEx = plot(axE, nan, nan, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.3);
    hEy = plot(axE, nan, nan, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.3);
    hEn = plot(axE, nan, nan, '-', 'Color',[0.20 0.20 0.20], 'LineWidth',1.8);
    ylabel(axE,'위치 오차 [m]');
    title(axE, '위치 오차 — 0 으로 내려와 붙으면 DP 성공', 'FontWeight','normal');
    legend(axE, [hEx hEy hEn], {'e_x (북)','e_y (동)','|e| (거리)'}, ...
           'Location','northeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (2) : 선수각 지령 대비 응답 --------------------------
    axP = subplot(3,2,4, 'Parent', fig);
    hold(axP,'on'); grid(axP,'on');
    hPref = plot(axP, nan, nan, '--', 'Color',[0.60 0.60 0.60], 'LineWidth',1.6);
    hP    = plot(axP, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    ylabel(axP,'\psi [deg]');
    title(axP, '선수각 — 지령 대비 응답 (ssa 로 접은 값)', 'FontWeight','normal');
    legend(axP, [hPref hP], {'\psi_{ref} (DP 목표)','\psi (응답)'}, ...
           'Location','southeast', 'Orientation','horizontal', 'AutoUpdate','off');

    % ---- 오른쪽 (3) : 추진기 추력과 방위각 ---------------------------
    %   추력은 수백 N, 방위각은 ±45° 라 자릿수가 다르다. 한 축에 겹쳐 놓으면
    %   방위각이 0 인 직선으로 보인다. 그래서 축을 둘로 나누고 범례로 묶는다.
    axT = subplot(3,2,6, 'Parent', fig);
    yyaxis(axT,'left');
    hold(axT,'on'); grid(axT,'on');
    hT1 = plot(axT, nan, nan, '-', 'Color',[0.85 0.10 0.10], 'LineWidth',1.5);
    hT2 = plot(axT, nan, nan, '-', 'Color',[0.75 0.10 0.75], 'LineWidth',1.5);
    ylabel(axT,'추력 T_i [N]');
    yyaxis(axT,'right');
    hold(axT,'on');
    hD1 = plot(axT, nan, nan, '--', 'Color',[0.85 0.10 0.10], 'LineWidth',1.2);
    hD2 = plot(axT, nan, nan, '--', 'Color',[0.75 0.10 0.75], 'LineWidth',1.2);
    ylabel(axT,'방위각 \delta_i [deg]');
    ylim(axT, [-rad2deg(delMax)*1.25, rad2deg(delMax)*1.25]);   % ±45° 한계가 보이게
    yline(axT,  rad2deg(delMax), ':', 'Color',[0.45 0.45 0.45]);
    yline(axT, -rad2deg(delMax), ':', 'Color',[0.45 0.45 0.45]);
    xlabel(axT,'시간 [s]');
    title(axT, sprintf('방위추진기 2기 — 추력과 방위각 (한계 ±%.0f°)', ...
                       rad2deg(delMax)), 'FontWeight','normal');
    legend(axT, [hT1 hT2 hD1 hD2], {'T_1 (좌현)','T_2 (우현)','\delta_1','\delta_2'}, ...
           'Location','southoutside', 'Orientation','horizontal', 'AutoUpdate','off');
    %  yyaxis 는 두 축의 색을 제멋대로 칠한다. 범례가 색을 나르므로 축 글자는 검게 둔다
    axT.YAxis(1).Color = [0.15 0.15 0.15];
    axT.YAxis(2).Color = [0.15 0.15 0.15];

    %  오른쪽 세 칸의 y 이름표가 창 오른쪽 테두리에 잘리지 않게 폭을 줄인다.
    %  ③ 칸은 **오른쪽에도 축 이름표가 있으므로**(yyaxis) 더 줄인다 —
    %  4~7주차처럼 0.90 으로 두면 '방위각 \delta_i' 가 테두리에 잘린다
    for a = [axE axP axT]
        p = get(a,'Position');  set(a, 'Position', [p(1) p(2) p(3)*0.86 p(4)]);
    end

    tv = [];  De = zeros(0,3);  Dp = zeros(0,2);  Dt = zeros(0,4);
    tLast = -inf;
end
tPrev = t;

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
x_n = eta(1);  y_n = eta(2);  psi = eta(3);
ex  = eta_d(1) - x_n;
ey  = eta_d(2) - y_n;

trX(end+1) = x_n;  trY(end+1) = y_n;
tv(end+1)  = t;
De(end+1,:) = [ex, ey, hypot(ex, ey)];
Dp(end+1,:) = [ssa_deg(eta_d(3)), ssa_deg(psi)];
Dt(end+1,:) = [Tact(1), Tact(2), rad2deg(Dact(1)), rad2deg(Dact(2))];
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    trX(1:k) = [];  trY(1:k) = [];  tv(1:k) = [];
    De(1:k,:) = [];  Dp(1:k,:) = [];  Dt(1:k,:) = [];
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 위치 평면 --------------------------------------------------
L = 4.9*scale/2;  B = 2.44*scale/2;
hull = [ L 0; 0.4*L B; -L B; -L -B; 0.4*L -B ];
R = [cos(psi) -sin(psi); sin(psi) cos(psi)];
hb = (R*hull')';
set(hHull, 'XData', y_n + hb(:,2), 'YData', x_n + hb(:,1));
set(hHead, 'XData', [y_n, y_n + 2.2*L*sin(psi)], ...
           'YData', [x_n, x_n + 2.2*L*cos(psi)]);
set(hDot,  'XData', y_n, 'YData', x_n);
set(hTrail,'XData', trY, 'YData', trX);

% 목표 — 계단 목표(시킨 곳)와 기준모델 목표(지금 좇는 곳), 그리고 목표 선수각
set(hRaw,  'XData', eta_raw(2), 'YData', eta_raw(1));
set(hTgt,  'XData', eta_d(2),   'YData', eta_d(1));
set(hTgtHead, 'XData', [eta_d(2), eta_d(2) + 2.2*L*sin(eta_d(3))], ...
              'YData', [eta_d(1), eta_d(1) + 2.2*L*cos(eta_d(3))]);

% 추진기 화살표 — NED 선체계: 좌현 y = -yt, 우현 y = +yt
%   길이 기준은 선체 반길이 L 의 1.6 배 = 추력 한계 F_max 일 때의 길이다.
%   선체 크기에 매여 있으므로 boat_scale 을 바꿔도 비율이 그대로다.
a1 = arrowPts([xt -yt], Dact(1), Tact(1), Fmax, 1.6*L, R, x_n, y_n);
a2 = arrowPts([xt  yt], Dact(2), Tact(2), Fmax, 1.6*L, R, x_n, y_n);
set(hArr(1), 'XData', a1(:,1), 'YData', a1(:,2));
set(hArr(2), 'XData', a2(:,1), 'YData', a2(:,2));

% 축 범위 — 배·항적·두 목표가 모두 들어오게. 최소 30 m 는 확보한다
allY = [trY, eta_d(2), eta_raw(2)];
allX = [trX, eta_d(1), eta_raw(1)];
span = max([max(allY)-min(allY), max(allX)-min(allX), 30]) * 1.30;
cy = (max(allY)+min(allY))/2;  cx = (max(allX)+min(allX))/2;
axis(axXY, [cy-span/2, cy+span/2, cx-span/2, cx+span/2]);

epsi = ssa_deg(psi - eta_d(3));
set(hInfo, 'String', { ...
    ['실시간 DP — 위쪽이 북쪽, 뾰족한 쪽이 선수.  ' ...
     '화살표 = 방위추진기 2기의 추력 방향 (길이는 \surd(T/F_{max}) 비례)'], ...
    sprintf(['t = %5.1f s    x = %7.2f m    y = %7.2f m    \\psi = %6.1f°    ' ...
             '|e| = %5.2f m    \\Delta\\psi = %5.1f°'], ...
            t, x_n, y_n, ssa_deg(psi), De(end,3), epsi), ...
    sprintf('좌현 %+6.1f N @ %+5.1f°      우현 %+6.1f N @ %+5.1f°', ...
            Tact(1), rad2deg(Dact(1)), Tact(2), rad2deg(Dact(2))) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hEx,   'XData', tv, 'YData', De(:,1));
set(hEy,   'XData', tv, 'YData', De(:,2));
set(hEn,   'XData', tv, 'YData', De(:,3));
set(hPref, 'XData', tv, 'YData', Dp(:,1));
set(hP,    'XData', tv, 'YData', Dp(:,2));
set(hT1,   'XData', tv, 'YData', Dt(:,1));
set(hT2,   'XData', tv, 'YData', Dt(:,2));
set(hD1,   'XData', tv, 'YData', Dt(:,3));
set(hD2,   'XData', tv, 'YData', Dt(:,4));

%  곡선이 그림의 맨 위 테두리에 딱 붙으면 읽기 어렵다. 위아래로 조금 띄운다
pad_y(axE, De);
pad_y(axP, Dp);
yyaxis(axT,'left');   pad_y(axT, Dt(:,1:2));   yyaxis(axT,'right');

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 추진기 화살표 — 추진기 자리에서 추력 방향으로 뻗는다. 선체 좌표계에서
% 만든 뒤 NED 로 돌린다. 추력이 음수면 화살표가 반대로 향한다.
%
%   길이는 sqrt(|T|/F_max) 에 비례시킨다. 길이에 그대로 비례시키면
%   DP 의 정상상태 추력(수십 N)이 한계 500 N 의 몇 %밖에 안 되어 화살표가
%   선체 안에 파묻힌다 — 정작 "외란에 맞서 어느 쪽을 미는가" 를 보여야 하는
%   구간에서 아무것도 안 보인다 (2026-09-25 첫 캡처에서 확인).
%   제곱근을 쓰면 작은 추력도 눈에 보이면서 큰 추력과의 차례는 그대로다.
%   **정확한 크기는 제목 줄의 숫자와 오른쪽 ③ 칸에서 읽는다.**
% =====================================================================
function p = arrowPts(pos, delta, T, Fmax, Lfull, R, x_n, y_n)
len = Lfull * sign(T) * min(sqrt(abs(T)/max(Fmax,1)), 1);
tip = pos + len*[cos(delta) sin(delta)];
hd  = 0.25*abs(len);                                  % 화살촉
a1  = tip - hd*[cos(delta+0.4) sin(delta+0.4)]*sign(len+eps);
a2  = tip - hd*[cos(delta-0.4) sin(delta-0.4)]*sign(len+eps);
body = [pos; tip; a1; tip; a2];
b = (R*body')';
p = [y_n + b(:,2), x_n + b(:,1)];
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
