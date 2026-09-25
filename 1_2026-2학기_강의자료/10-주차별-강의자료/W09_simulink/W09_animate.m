function f = W09_animate(lat, lon, qz, qw, wz, hz_gps, hz_imu, x_true, y_true, r_true, t)
% W09_ANIMATE  9주차 센서 조사 모델의 실시간 화면 — 센서가 무엇을 얼마나 자주 주는가.
%
%   Simulink 의 Animate 상자가 매 스텝 이 함수를 부른다. 직접 부를 일은 없다.
%   **오프라인 모델과 VRX 쌍둥이가 이 함수 하나를 같이 쓴다.** 바뀌는 것은
%   들어오는 값을 어디서 뽑았는지뿐이다 (센서 모델 vs VRX 토픽).
%
%   f = W09_animate()        인자 없이 부르면 지금 열려 있는 창의 핸들을 돌려준다.
%                            캡처할 때 쓴다 — gcf 를 쓰면 안 된다 (창이 여럿이다)
%
%   입력 — 전부 **모델이 이미 내고 있는 신호**다. 새 가지를 치지 않았다
%     lat, lon   : GPS 가 준 위도 · 경도 [deg]     (태그 lat · lon)
%     qz, qw     : IMU 자세 쿼터니언의 z · w        (태그 qz · qw, ENU)
%     wz         : 자이로 z 각속도 [rad/s]          (태그 wz, ENU. 잡음 + 바이어스 포함)
%     hz_gps     : RateMeter 가 센 GPS 수신 주기 [Hz]
%     hz_imu     : RateMeter 가 센 IMU 수신 주기 [Hz]
%     x_true, y_true, r_true : 운동모델의 참값 [m, m, rad/s]. **VRX 에는 없다 -> NaN**
%     t          : 시뮬레이션 시각 [s]
%
%   화면 배치 — 4·5주차 규약과 같은 네 칸, 내용만 이 주차의 것이다
%     왼쪽 큰 칸   참값 항적 + **GPS 로 본 위치 점** + 선체와 선수 방향
%                  가로축 y (동쪽), 세로축 x (북쪽)
%     오른쪽 (1)   수신 주기 — hz_gps · hz_imu 와 설계값 20 · 100 Hz (점선)
%     오른쪽 (2)   센서 대 참값 — 자이로가 준 r 과 참값 r 을 겹쳐서
%     오른쪽 (3)   GPS 안테나 레버암 — GPS 점과 참값 원점의 차이 (참값이 있을 때)
%                  참값이 없으면(VRX) **설계값 대비 못 받은 건수**를 그린다
%
%   왜 이 네 칸인가
%     9주차는 제어 주차가 아니다. 화면이 답해야 하는 질문은 "시킨 대로 갔는가"
%     가 아니라 **"센서가 제대로 오고 있는가"** 다. 그래서 지령 대비 응답 대신
%     ① 얼마나 자주 오는가 ② 오는 값이 참값과 얼마나 다른가 ③ 센서가 달린
%     자리 때문에 얼마나 어긋나는가 — 1-5 절과 2-8-0 절이 재는 바로 그 세 가지를
%     칸에 그대로 앉혔다.
%
%   왜 오른쪽 ③ 이 모델마다 다른가
%     VRX 에는 참값이 없다. `W09_1_sensor_rates` 는 센서 토픽 세 개만 구독하고
%     ground truth 는 구독하지 않는다 — 그것이 이 모델의 목적이기 때문이다.
%     참값이 없으면 레버암 차이를 잴 수 없으므로 그 칸은 이 주차의 또 다른
%     측정값인 **설계값 대비 못 받은 건수**(누적)로 바뀐다. 2-8-1 의 비율
%     0.75 가 몇 건인지를 눈으로 보는 칸이다.
%
%   선체를 어디에 그리는가
%     GPS 점은 **안테나 자리**다. 선체 원점이 아니다 (1-3 절). 그래서 IMU 선수각으로
%     레버암을 되돌린 자리에 선체를 그리고, 날것의 GPS 점은 따로 찍는다.
%     두 점이 떨어져 보이는 것이 이 주차가 가르치려는 그림이다.
%
%   출발점
%     첫 쓸모 있는 GPS 점을 원점으로 잡고 거기서부터 상대좌표로 그린다.
%     참값에도 **같은** 원점을 빼므로 둘 사이의 차이는 그대로 남는다.
%     VRX 의 위경도는 기준점에서 수백 m 떨어져 있고, Subscribe 블록은 첫 메시지
%     전에 0 으로 채운 버스를 내므로 (CLAUDE.md §11) 맨 앞 몇 샘플을 버려야 한다.
%
%   그림이 느리면 W09_setup.m 에서 animate = 0 또는 animate_every 를 키운다.
%   **수신 주기를 재는 실행에서는 화면을 끈다** — 그리는 일이 벽시계를 먹는다
%   (W09_rates_run 이 알아서 끄고 되돌린다).

persistent fig axXY axHz axR axD ...
           hTrue hGps hHull hHead hDot hInfo ...
           hHzG hHzI hDesG hDesI hRm hRt hD1 hD2 hD3 ...
           tX tY gX gY tv Dhz Dr Dd x0 y0 haveOrigin hasTruth tLast tPrev ...
           latRef lonRef Rm_ Rn_ bx_ by_ hzDg hzDi

%% ---- 인자 없이 부르면 창 핸들만 돌려준다 (캡처용) ----------------------
if nargin == 0
    if ~isempty(fig) && isvalid(fig), f = fig; else, f = getappdata(0,'W09_anim_fig'); end
    return
end

NMAX = 40000;        % 되돌아보기 한계. VRX 는 길게 돌 수 있다

%% ---- 새 실행이면 창을 다시 만든다 --------------------------------------
newRun = isempty(tLast) || isempty(fig) || ~isvalid(fig) || t < tPrev;
if newRun
    if ~isempty(fig) && isvalid(fig), close(fig); end
    fig = figure('Name','W09 실시간 센서 화면 — 얼마나 자주, 얼마나 정확히 오는가', ...
                 'NumberTitle','off', 'Color','w', 'Position',[50 50 1240 800]);
    setappdata(0, 'W09_anim_fig', fig);

    %  설계값과 기준점은 W09_setup 이 base workspace 에 올려 둔 것을 읽는다.
    %  화면 함수가 제 값을 따로 들고 있으면 setup 과 어긋난다
    latRef = bw('lat0', 0);         lonRef = bw('lon0', 0);
    bx_    = bw('gps_x', 0);        by_    = bw('gps_y', 0);
    hzDg   = bw('hz_design_gps',  20);
    hzDi   = bw('hz_design_imu', 100);
    a  = 6378137.0;  e2 = 6.69437999014e-3;  s2 = sind(latRef)^2;
    Rm_ = a*(1-e2)/(1-e2*s2)^1.5;              % 자오선 곡률반경
    Rn_ = a/sqrt(1-e2*s2)*cosd(latRef);        % 묘유선 곡률반경 x cos(lat)

    % ---- 왼쪽 큰 칸 : 참값 항적 + GPS 점 + 선체 ----
    axXY = subplot(3,2,[1 3 5], 'Parent', fig);
    hold(axXY,'on'); grid(axXY,'on'); axis(axXY,'equal');
    xlabel(axXY,'y (동쪽) [m]');  ylabel(axXY,'x (북쪽) [m]');
    %  선체를 **맨 아래에, 비치게** 깐다. 이 주차의 기본 시나리오는 제자리
    %  선회라 항적이 선체보다 작다 — 불투명하게 그리면 GPS 점이 가려진다
    hHull = patch('Parent',axXY, 'XData',nan, 'YData',nan, ...
                  'FaceColor',[0.13 0.55 0.13], 'FaceAlpha',0.25, ...
                  'EdgeColor',[0.13 0.45 0.13], 'LineWidth',1.0);
    hHead = plot(axXY, nan, nan, '-', 'Color',[0.35 0.35 0.35], 'LineWidth',1.6);
    hTrue = plot(axXY, nan, nan, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.8, ...
                 'Marker','o', 'MarkerSize',5, 'MarkerIndices',1, ...
                 'MarkerFaceColor',[0.00 0.45 0.74]);
    hGps  = plot(axXY, nan, nan, '.', 'Color',[0.85 0.33 0.10], 'MarkerSize',9);
    hDot  = plot(axXY, nan, nan, 'k.', 'MarkerSize',14);
    hInfo = title(axXY, '', 'FontWeight','normal', 'Interpreter','tex');

    % ---- 오른쪽 (1) : 수신 주기 ----
    %  누적 평균이라 t 가 아주 작을 때는 값이 크게 튄다. 아래에서 y 한계를 묶는다
    axHz = subplot(3,2,2, 'Parent', fig);
    hold(axHz,'on'); grid(axHz,'on');
    hDesG = plot(axHz, nan, nan, '--', 'Color',[0.75 0.55 0.45], 'LineWidth',1.2);
    hDesI = plot(axHz, nan, nan, '--', 'Color',[0.45 0.60 0.75], 'LineWidth',1.2);
    hHzG  = plot(axHz, nan, nan, '-',  'Color',[0.85 0.33 0.10], 'LineWidth',1.6);
    hHzI  = plot(axHz, nan, nan, '-',  'Color',[0.00 0.45 0.74], 'LineWidth',1.6);
    ylabel(axHz,'수신 주기 [Hz]');
    title(axHz,'수신 주기 — 실측과 설계값(점선)', 'FontWeight','normal');
    legend(axHz, [hHzG hHzI hDesG hDesI], ...
           {'GPS 실측','IMU 실측', sprintf('GPS 설계 %g Hz', hzDg), ...
            sprintf('IMU 설계 %g Hz', hzDi)}, ...
           'Location','southoutside', 'NumColumns',2, 'AutoUpdate','off');

    % ---- 오른쪽 (2) : 센서 대 참값 ----
    axR = subplot(3,2,4, 'Parent', fig);
    hold(axR,'on'); grid(axR,'on');
    hRt = plot(axR, nan, nan, '-', 'Color',[0.45 0.45 0.45], 'LineWidth',3.2);
    hRm = plot(axR, nan, nan, '-', 'Color',[0.49 0.18 0.56], 'LineWidth',1.1);
    ylabel(axR,'r [deg/s]');

    % ---- 오른쪽 (3) : 레버암 차이 또는 못 받은 건수 ----
    axD = subplot(3,2,6, 'Parent', fig);
    hold(axD,'on'); grid(axD,'on');
    hD1 = plot(axD, nan, nan, '-', 'Color',[0.85 0.33 0.10], 'LineWidth',1.3);
    hD2 = plot(axD, nan, nan, '-', 'Color',[0.00 0.45 0.74], 'LineWidth',1.3);
    hD3 = plot(axD, nan, nan, '-', 'Color',[0.15 0.15 0.15], 'LineWidth',1.8);
    xlabel(axD,'시간 [s]');

    %  오른쪽 세 칸 — y 이름표가 창 테두리에 잘리지 않게 폭을 줄이고,
    %  범례를 칸 **아래**에 두므로 위 두 칸은 높이도 줄여 자리를 비운다.
    %  줄이지 않으면 범례가 아래 칸의 제목 위에 얹힌다 (2026-09-25 첫 캡처)
    for ax = [axHz axR]
        p = get(ax,'Position');
        set(ax, 'Position', [p(1) p(2)+0.26*p(4) p(3)*0.90 p(4)*0.74]);
    end
    p = get(axD,'Position');  set(axD, 'Position', [p(1) p(2) p(3)*0.90 p(4)]);

    tX = [];  tY = [];  gX = [];  gY = [];  tv = [];
    Dhz = zeros(0,2);  Dr = zeros(0,2);  Dd = zeros(0,3);
    x0 = 0;  y0 = 0;  haveOrigin = false;  hasTruth = false;
    tLast = -inf;
end
tPrev = t;

%% ---- 출발점 잡기 — 0 으로 채운 첫 버스를 버린다 -------------------------
%  참값이 있는 모델인지(오프라인) 없는 모델인지(VRX)도 여기서 한 번만 정한다.
%  빌더가 NaN 을 고정으로 넣으므로 한 실행 안에서 바뀌지 않는다.
if ~haveOrigin
    if lat ~= 0 || lon ~= 0
        [x0, y0]   = ll2ned(lat, lon, latRef, lonRef, Rm_, Rn_);
        haveOrigin = true;
        hasTruth   = ~isnan(x_true) && ~isnan(r_true);
        label_panels(axXY, axR, axD, hTrue, hGps, hRt, hRm, hD1, hD2, hD3, ...
                     hasTruth, hypot(bx_, by_), hzDg, hzDi);
    else
        return                    % 아직 첫 메시지가 오지 않았다. 그리지 않는다
    end
end

%% ---- 값 모으기 (그리기는 animate_every 마다) ---------------------------
[xg, yg] = ll2ned(lat, lon, latRef, lonRef, Rm_, Rn_);
xg = xg - x0;   yg = yg - y0;
psi = pi/2 - 2*atan2(qz, qw);       % ENU yaw -> NED 선수각 (롤·피치는 작다고 본다)

gX(end+1) = xg;   gY(end+1) = yg;
tv(end+1) = t;
Dhz(end+1,:) = [hz_gps, hz_imu];
Dr(end+1,:)  = [-wz*180/pi, r_true*180/pi];    % r_ENU = -r_NED (1-5 절)
if hasTruth
    xt = x_true - x0;   yt = y_true - y0;
    tX(end+1) = xt;     tY(end+1) = yt;
    Dd(end+1,:) = [xg - xt, yg - yt, hypot(xg - xt, yg - yt)];
else
    %  참값이 없다 -> 설계값 대비 못 받은 건수. RateMeter 의 정의상 n = hz * t 다
    Dd(end+1,:) = [hzDg*t - hz_gps*t, hzDi*t - hz_imu*t, NaN];
end
if numel(tv) > NMAX
    k = numel(tv) - NMAX + 1;
    gX(1:k) = [];  gY(1:k) = [];  tv(1:k) = [];
    Dhz(1:k,:) = [];  Dr(1:k,:) = [];  Dd(1:k,:) = [];
    if hasTruth, tX(1:k) = [];  tY(1:k) = []; end
end

every = 0.25;
try, every = evalin('base','animate_every'); catch, end
if t - tLast < every, return; end
tLast = t;

%% ---- 왼쪽 : 항적과 선체 ------------------------------------------------
%  GPS 점은 안테나 자리다. IMU 선수각으로 레버암을 되돌려 선체 원점을 찾는다
xh = xg - bx_*cos(psi) + by_*sin(psi);
yh = yg - bx_*sin(psi) - by_*cos(psi);
[hX, hY, hdx, hdy] = hull_ned(xh, yh, psi);
set(hTrue, 'XData', tY,  'YData', tX);
set(hGps,  'XData', gY,  'YData', gX);
set(hHull, 'XData', hY,  'YData', hX);
set(hHead, 'XData', hdy, 'YData', hdx);
set(hDot,  'XData', yg,  'YData', xg);
set(hInfo, 'String', { '항적 — 위쪽이 북쪽. 주황 점이 GPS, 초록이 IMU 자세로 되돌린 선체', ...
    sprintf(['t = %5.1f s    GPS %5.2f Hz    IMU %6.2f Hz    ' ...
             '\\psi_{IMU} = %6.1f°    r_{자이로} = %6.2f °/s'], ...
            t, hz_gps, hz_imu, ssa_deg(psi), -wz*180/pi) });

%% ---- 오른쪽 세 칸 ------------------------------------------------------
set(hHzG,  'XData', tv, 'YData', Dhz(:,1));
set(hHzI,  'XData', tv, 'YData', Dhz(:,2));
set(hDesG, 'XData', [tv(1) tv(end)], 'YData', [hzDg hzDg]);
set(hDesI, 'XData', [tv(1) tv(end)], 'YData', [hzDi hzDi]);
set(hRm,   'XData', tv, 'YData', Dr(:,1));
set(hRt,   'XData', tv, 'YData', Dr(:,2));
set(hD1,   'XData', tv, 'YData', Dd(:,1));
set(hD2,   'XData', tv, 'YData', Dd(:,2));
set(hD3,   'XData', tv, 'YData', Dd(:,3));

%  수신 주기는 누적 평균이라 t 가 0 에 가까울 때 수백 Hz 로 튄다. 설계값이
%  보이는 자리로 y 한계를 묶지 않으면 그림이 첫 몇 스텝에 잡아먹힌다
ylim(axHz, [0, 1.35*max([hzDg, hzDi])]);
pad_y(axR, Dr);
pad_y(axD, Dd);

drawnow limitrate
if nargout > 0, f = fig; end
end

% =====================================================================
% 위경도 -> 기준점 기준 북 · 동 [m]  (1-5 절 식, W09_offline_run 과 같은 식)
% =====================================================================
function [xn, yn] = ll2ned(lat, lon, lat0, lon0, Rm, Rn)
xn = deg2rad(lat - lat0)*Rm;
yn = deg2rad(lon - lon0)*Rn;
end

% =====================================================================
% 선체 다각형 — 선미는 네모, 선수는 뾰족하다 (4주차 W04_animate 와 같은 모양)
%     N = x + bx cos(psi) - by sin(psi)
%     E = y + bx sin(psi) + by cos(psi)
% =====================================================================
function [X, Y, hx, hy] = hull_ned(x, y, psi)
L = 1.6;  B = 0.45*L;                            % 반길이 · 반폭 [m]
bx = L * [ -1   -1    0.35   1    0.35  -1 ];    % 선미 -> 선수 -> 선미 (닫힌 도형)
by = B * [  1   -1   -1      0    1      1 ];
c = cos(psi);  s = sin(psi);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;
hx = [x, x + 2.2*L*c];                           % 선수 방향선
hy = [y, y + 2.2*L*s];
end

% ---- ssa : 최단 부호각으로 접어 deg 로 -----------------------------------
function d = ssa_deg(a)
d = atan2(sin(a), cos(a)) * 180/pi;
end

% ---- base workspace 값 읽기. 없으면 기본값 (W09_setup 을 안 돌린 경우) ----
function v = bw(name, dflt)
v = dflt;
try, v = evalin('base', name); catch, end
end

% =====================================================================
% 아래 두 칸의 제목과 범례 — 참값이 있는 모델인지 첫 샘플에서 한 번만 정한다
%
%   빈 칸으로 두거나 그리지 않는 선을 범례에 남기면 학생은 그림이 고장난 줄
%   안다 (4주차 W04_animate 와 같은 이유). 무엇이 없는지 제목에 적는다.
% =====================================================================
function label_panels(axXY, axR, axD, hTrue, hGps, hRt, hRm, hD1, hD2, hD3, ...
                      hasTruth, dDesign, hzDg, hzDi)
if hasTruth
    legend(axXY, [hTrue hGps], {'참값 항적','GPS 위치 점'}, ...
           'Location','best', 'AutoUpdate','off');
    title(axR, '센서 대 참값 — 자이로가 준 r 과 참값 r', 'FontWeight','normal');
    legend(axR, [hRt hRm], {'r 참값','r 자이로 (잡음 + 바이어스)'}, ...
           'Location','southoutside', 'NumColumns',2, 'AutoUpdate','off');
    title(axD, sprintf('GPS 안테나 레버암 — 설계 %.2f m', dDesign), 'FontWeight','normal');
    ylabel(axD, 'GPS - 참값 [m]');
    legend(axD, [hD1 hD2 hD3], {'북쪽 차이','동쪽 차이','거리'}, ...
           'Location','southoutside', 'NumColumns',3, 'AutoUpdate','off');
else
    legend(axXY, hGps, {'GPS 위치 점 (참값 없음 — VRX)'}, ...
           'Location','best', 'AutoUpdate','off');
    title(axR, '센서 값 — 자이로가 준 r (참값 없음 — VRX)', 'FontWeight','normal');
    legend(axR, hRm, {'r 자이로'}, 'Location','southoutside', 'AutoUpdate','off');
    title(axD, sprintf('못 받은 건수 — 설계 %g · %g Hz 로 왔어야 할 수와의 차', hzDg, hzDi), ...
          'FontWeight','normal');
    ylabel(axD, '못 받은 건수 (누적)');
    legend(axD, [hD1 hD2], {'GPS','IMU'}, ...
           'Location','southoutside', 'NumColumns',2, 'AutoUpdate','off');
end
end

% ---- y 범위에 여백. 선이 테두리에 붙으면 읽히지 않는다 -------------------
function pad_y(ax, D)
lo = min(D(:), [], 'omitnan');  hi = max(D(:), [], 'omitnan');
if isempty(lo) || ~isfinite(lo) || ~isfinite(hi), return, end
%  t = 0 에서는 값이 전부 같다 (lo == hi). 그때 여백을 비율로만 잡으면 위아래
%  한계가 같은 수가 되어 ylim 이 거부한다. 바닥값을 둔다.
d = max((hi - lo)*0.08, max(abs([lo hi]))*0.05 + 1e-3);
ylim(ax, [lo-d, hi+d]);
end
