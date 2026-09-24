function W08_alloc_demo()
% W08_ALLOC_DEMO  추력 배분을 그림으로 이해한다.
%
%   >> W08_setup
%   >> W08_alloc_demo
%
%   그림 세 장 (img/ 에 저장)
%     (1) 도달가능 제어집합 (ACS) — 고정 추진기 vs 틸팅 추진기
%         연한 초록 = N 을 따지지 않은 (X,Y) 투영, 진한 초록 = N = 0 을 지키는 단면
%     (2) 요구 방위각 -> 실제 인가되는 각도·추력 (±45° 매핑)
%     (3) 네 가지 기본 기동에서 두 추진기가 어떻게 배치되는가
%
%   근거: Fossen (2011) 12.3.4 절, 연구실 자산 WAMV_USV_Control_Allocation.m

xt   = evalin('base','thr_x');
yt   = evalin('base','thr_y');
Te   = evalin('base','T_e');
Tp   = evalin('base','T_pinv');
Fmax = evalin('base','F_max');
dmax = evalin('base','del_max');

%% ---------- (1) 도달가능 제어집합 --------------------------------
NT = 25;                                   % 추력·각도 격자 (25^4 = 39만 점)
Tr = linspace(-Fmax, Fmax, NT);
Dr = linspace(-dmax, dmax, NT);
[a, da, b, db] = ndgrid(Tr, Dr, Tr, Dr);
F4 = [a(:).*cos(da(:)), a(:).*sin(da(:)), b(:).*cos(db(:)), b(:).*sin(db(:))]';
tau = Te*F4;
X = tau(1,:);  Y = tau(2,:);  Nm = tau(3,:);

% 고정 추진기(5~7주차): delta = 0 만 가능
Xf = []; Yf = [];
for a = Tr, for b = Tr
    Xf(end+1) = a + b;  Yf(end+1) = 0; %#ok<AGROW>
end, end

figure('Name','도달가능 제어집합','Color','w','Position',[80 80 720 560]);
k = convhull(X, Y);
fill(X(k), Y(k), [0.85 0.95 0.85], 'EdgeColor',[0.2 0.6 0.2], 'LineWidth',1.2); hold on;
% N = 0 단면 — 요 모멘트를 내지 않으면서 낼 수 있는 (X,Y). 격자라 |N| < 20 N·m 로 근사
z  = abs(Nm) < 20;
k0 = convhull(X(z), Y(z));
Xz = X(z); Yz = Y(z);
fill(Xz(k0), Yz(k0), [0.45 0.75 0.45], 'EdgeColor',[0.1 0.45 0.1], 'LineWidth',1.6);
plot([min(Xf) max(Xf)], [0 0], 'r-', 'LineWidth',3);
plot(0,0,'k+','MarkerSize',12,'LineWidth',1.5);
axis equal; grid on;
xlabel('전후 추력 X [N]'); ylabel('횡 추력 Y [N]');
legend({'틸팅 ±45°, N 무관 (투영)','틸팅 ±45°, N = 0','고정 추진기 (5~7주차)','원점'}, 'Location','best');
% 순수 횡이동의 한계는 격자가 아니라 식으로 — 1-9절의 배분 비율 750:944 (T_e^+ 해)
f1 = Tp*[0; 1; 0];  Ymax = Fmax/hypot(f1(1), f1(2));
plot([0 0], [-Ymax Ymax], 'k:', 'LineWidth',1.2, 'DisplayName','순수 횡이동 (X = N = 0)');
plot(0, [Ymax -Ymax], 'kd', 'MarkerFaceColor','y', 'MarkerSize',8, 'HandleVisibility','off');
title(sprintf('도달가능 제어집합 — 순수 횡이동 한계 %.0f N (투영으로는 %.0f N)', Ymax, 2*Fmax*sin(dmax)));
saveImg(gcf, 'W08_acs.png');

%% ---------- (2) ±45° 매핑 ----------------------------------------
dreq = linspace(-180, 180, 721);
Treq = 1.2*Fmax;                 % 한계를 넘는 요구
d1v = zeros(size(dreq)); T1v = zeros(size(dreq));
d2v = zeros(size(dreq)); T2v = zeros(size(dreq));
for i = 1:numel(dreq)
    [T1v(i), a] = mapDemand(Treq, deg2rad(dreq(i)), Fmax, dmax, 1);
    [T2v(i), b] = mapDemand(Treq, deg2rad(dreq(i)), Fmax, dmax, 2);
    d1v(i) = rad2deg(a);  d2v(i) = rad2deg(b);
end

figure('Name','±45° 매핑','Color','w','Position',[820 80 720 560]);
subplot(2,1,1);
plot(dreq, d1v, 'b', 'LineWidth',2); grid on; hold on;
plot(dreq, d2v, 'r--', 'LineWidth',1.6);
for v = [-135 -45 45 135], xline(v,'k--'); end
xlim([-180 180]); ylim([-60 60]); set(gca,'XTick',-180:45:180);
ylabel('실제 인가 각도 [deg]');
legend({'모드 1 (불감대)','모드 2 (경계 클램프)'},'Location','best');
title('요구 방위각 → 실제 인가 각도 (역추진 · 불감대 · 클램프)');

subplot(2,1,2);
plot(dreq, T1v, 'b', 'LineWidth',2); grid on; hold on;
plot(dreq, T2v, 'r--', 'LineWidth',1.6);
for v = [-135 -45 45 135], xline(v,'k--'); end
yline( Fmax,'k:'); yline(-Fmax,'k:');
xlim([-180 180]); set(gca,'XTick',-180:45:180);
xlabel('요구 방위각 [deg]'); ylabel('실제 인가 추력 [N]');
legend({'모드 1','모드 2'},'Location','best');
title(sprintf('추력 포화 (요구 %.0f N, 한계 %.0f N)', Treq, Fmax));
saveImg(gcf, 'W08_map45.png');

%% ---------- (3) 네 가지 기본 기동 ---------------------------------
cases = { '전진  \tau = [300, 0, 0]',   [300;   0;    0];
          '횡이동 \tau = [0, 200, 0]',   [  0; 200;    0];
          '제자리 선회 \tau = [0, 0, 400]',[ 0;   0;  400];
          '전진+횡  \tau = [200,150,0]', [200; 150;    0] };

figure('Name','기본 기동별 추진기 배치','Color','w','Position',[300 60 860 700]);
for i = 1:4
    tau = cases{i,2};
    f   = Tp*tau;
    [T1,d1] = mapDemand(hypot(f(1),f(2)), atan2(f(2),f(1)), Fmax, dmax);
    [T2,d2] = mapDemand(hypot(f(3),f(4)), atan2(f(4),f(3)), Fmax, dmax);
    tau_a = Te*[T1*cos(d1); T1*sin(d1); T2*cos(d2); T2*sin(d2)];

    subplot(2,2,i);
    rectangle('Position',[-2.6 -1.3 4.4 2.6],'Curvature',0.25, ...
              'EdgeColor',[0.6 0.6 0.6],'LineWidth',1.4); hold on;
    plot(0,0,'kx','MarkerSize',10,'LineWidth',1.5);
    sc = 1.4/max([abs(T1) abs(T2) 1]);
    % NED 선체계: y 양수가 우현. 좌현 추진기는 y = -yt 에 있다.
    quiver(xt, -yt, T1*cos(d1)*sc, T1*sin(d1)*sc, 0, 'r','LineWidth',2.5,'MaxHeadSize',0.6);
    quiver(xt,  yt, T2*cos(d2)*sc, T2*sin(d2)*sc, 0, 'b','LineWidth',2.5,'MaxHeadSize',0.6);
    plot(xt,-yt,'ro','MarkerFaceColor','r');
    plot(xt, yt,'bo','MarkerFaceColor','b');
    axis equal; grid on; xlim([-4 3]); ylim([-2.5 2.5]);
    set(gca, 'YDir','reverse');   % 위에서 내려다본 모습: 선수가 오른쪽이면 우현은 아래
    xlabel('x_b [m] (선수 +)'); ylabel('y_b [m] (우현 +, 아래로)');
    title(sprintf('%s\n좌 %+.0f N @ %+.0f°,  우 %+.0f N @ %+.0f°\n실현 \\tau = [%.0f %.0f %.0f]', ...
        cases{i,1}, T1, rad2deg(d1), T2, rad2deg(d2), tau_a(1), tau_a(2), tau_a(3)), ...
        'FontSize', 9);
end

saveImg(gcf, 'W08_maneuvers.png');
fprintf('\n배분 검산 — 요구 tau 와 실현 tau 가 같아야 한다 (포화가 없다면)\n');
end

function saveImg(h, name)
d = fullfile(fileparts(mfilename('fullpath')), 'img');
exportgraphics(h, fullfile(d, name), 'Resolution', 110);
fprintf('   그림 저장: img/%s\n', name);
end

% ---------------------------------------------------------------
function [To, Do] = mapDemand(Ti, di, Fmax, dmax, mode)
% ±dmax 섹터 밖의 요구를 역추진으로 접어 넣고, 크기를 포화시킨다.
%   mode 1 = 불감대,  mode 2 = 섹터 경계로 클램프
if nargin < 5, mode = evalin('base','alloc_mode'); end
ad = abs(di);
if ad <= dmax
    To = Ti;  Do = di;
elseif ad >= pi - dmax
    To = -Ti; Do = di - sign(di)*pi;
elseif mode < 1.5
    To = 0;   Do = 0;
else
    if ad <= pi/2
        Do = sign(di)*dmax;         To =  Ti*cos(ad - dmax);
    else
        Do = -sign(di)*dmax;        To = -Ti*cos(pi - dmax - ad);
        Do = atan2(sin(Do), cos(Do));
    end
end
if To >  Fmax, To =  Fmax; end
if To < -Fmax, To = -Fmax; end
end
