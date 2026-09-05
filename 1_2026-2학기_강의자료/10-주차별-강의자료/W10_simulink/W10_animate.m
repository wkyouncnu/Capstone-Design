function W10_animate(eta, eta_d, Dact, Tact, t)
% W10_ANIMATE  DP 주행을 실시간으로 그린다.
%
%   선체는 7~9주차와 같은 모양 — 선수는 세모, 선미는 네모.
%   여기에 추진기 두 기의 **방위각과 추력**을 화살표로 덧그린다.
%   각 화살표가 어디를 향하는지 보면 배분이 무슨 일을 하는지 알 수 있다.
%
%   모델 안의 Animate 블록이 부른다. 직접 부를 일은 없다.

persistent hFig hAx hHull hArrL hArrR hTrail hTgt hTxt trail tPrev

every = evalin('base','animate_every');
scale = evalin('base','boat_scale');
xt    = evalin('base','thr_x');
yt    = evalin('base','thr_y');
Fmax  = evalin('base','F_max');

if isempty(hFig) || ~isvalid(hFig) || t < tPrev
    hFig = figure('Name','W10 DP 실시간','Color','w','Position',[80 80 720 640]);
    hAx  = axes('Parent',hFig); hold(hAx,'on'); grid(hAx,'on');
    axis(hAx,'equal');
    xlabel(hAx,'East [m]'); ylabel(hAx,'North [m]');
    hTgt   = plot(hAx, nan, nan, 'k+', 'MarkerSize',14,'LineWidth',1.4);
    hTrail = plot(hAx, nan, nan, 'Color',[0.4 0.6 0.9], 'LineWidth',1.0);
    hHull  = patch('Parent',hAx,'XData',nan,'YData',nan, ...
                   'FaceColor',[0.85 0.92 1.0],'EdgeColor',[0.1 0.2 0.5],'LineWidth',1.2);
    hArrL  = plot(hAx, nan, nan, 'r-', 'LineWidth',2.5);
    hArrR  = plot(hAx, nan, nan, 'm-', 'LineWidth',2.5);
    hTxt   = title(hAx,'');
    trail  = zeros(0,2);
    tPrev  = -inf;
end
if t - tPrev < every, return; end
tPrev = t;

N = eta(1); E = eta(2); psi = eta(3);
trail(end+1,:) = [E N];
if size(trail,1) > 4000, trail(1,:) = []; end

% --- 선체 (선수 세모, 선미 네모) ---
L = 4.9*scale/2; B = 2.44*scale/2;
hull = [ L 0; 0.4*L  B; -L  B; -L -B; 0.4*L -B ];
R = [cos(psi) -sin(psi); sin(psi) cos(psi)];
hb = (R*hull')';
set(hHull,'XData', E + hb(:,2), 'YData', N + hb(:,1));

% --- 추진기 화살표 ---
aL = arrowPts([xt  yt], Dact(1), Tact(1), Fmax, scale, R, N, E);
aR = arrowPts([xt -yt], Dact(2), Tact(2), Fmax, scale, R, N, E);
set(hArrL,'XData',aL(:,1),'YData',aL(:,2));
set(hArrR,'XData',aR(:,1),'YData',aR(:,2));

set(hTrail,'XData',trail(:,1),'YData',trail(:,2));
set(hTgt,  'XData',eta_d(2),  'YData',eta_d(1));

e = hypot(N-eta_d(1), E-eta_d(2));
set(hTxt,'String', sprintf(['t = %5.1f s    오차 %.2f m / %.1f°    ' ...
    '좌 %+5.0f N @ %+5.1f°   우 %+5.0f N @ %+5.1f°'], ...
    t, e, rad2deg(atan2(sin(psi-eta_d(3)),cos(psi-eta_d(3)))), ...
    Tact(1), rad2deg(Dact(1)), Tact(2), rad2deg(Dact(2))));

c = [E N];
axis(hAx, [c(1)-25 c(1)+25 c(2)-25 c(2)+25]);
drawnow limitrate;
end

% ---------------------------------------------------------------
function p = arrowPts(pos, delta, T, Fmax, scale, R, N, E)
% 추진기 위치에서 추력 방향으로 뻗는 화살표를 선체 좌표계에서 만든 뒤
% NED 로 돌린다. 추력이 음수면 화살표가 반대로 향한다.
len = 8 * scale * T / max(Fmax,1);
tip = pos + len*[cos(delta) sin(delta)];
% 화살촉
hd  = 0.25*abs(len);
a1  = tip - hd*[cos(delta+0.4) sin(delta+0.4)]*sign(len+eps);
a2  = tip - hd*[cos(delta-0.4) sin(delta-0.4)]*sign(len+eps);
body = [pos; tip; a1; tip; a2];
b = (R*body')';
p = [E + b(:,2), N + b(:,1)];
end
