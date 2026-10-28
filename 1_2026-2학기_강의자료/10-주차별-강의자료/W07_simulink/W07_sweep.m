function T = W07_sweep()
% W07_SWEEP  7주차 C-1 — 파라미터를 하나씩 바꿔 오프라인 모델을 여러 번 돌리고 한 장에 모은다.
%
%   >> T = W07_sweep
%
%   W07_0_offline 만 쓴다 (VRX 불필요).
%   W07_setup 으로 기본값을 올린 뒤 이 함수 안에서만 값을 바꿔 돌린다.
%   끝나면 W07_setup 을 다시 불러 기본값으로 되돌린다.
%
%   모든 실행에 공통
%     required_turns = 0     멈추지 않고 계속 돎 (정지 후 꼬리가 평균을 더럽히지 않게)
%     초기 뱃머리  psi = 0   정북 고정 — 한 번에 하나만 바뀌게
%     정착 구간              원 도달(|r-rd| <= 0.3 rd) 30 s 뒤부터 끝까지
%
%   그림 6장  ->  img/W07_sweep.png
%     1 회전 방향     2 시작 위치(궤적)   3 시작 위치(반경 수렴)
%     4 지령 속도     5 목표 반경         6 |p_c|

here = fileparts(mfilename('fullpath'));  cd(here);
setappdata(0, 'W07_skip_run', true);
evalc('evalin(''base'', ''W07_setup'')');
assignin('base','use_schedule',   0);
assignin('base','animate',        0);
assignin('base','required_turns', 0);
c = onCleanup(@() restore());   %#ok<NASGU>

cn = evalin('base','center_north');
ce = evalin('base','center_east');

%% 실행 목록 ---------------------------------------------------------
%  그룹 | 이름 | p_c | r_d | u_ref | 시작 위치 [북 동] | 정지 시간
C = {
  1, 'p_c = +0.313  (시계방향)',    0.313, 25, 1.5, [0 0],            300
  1, 'p_c = -0.313  (반시계방향)', -0.313, 25, 1.5, [0 0],            300

  2, '중심  r_0 = 0 m',             0.313, 25, 1.5, [cn ce],          300
  2, '원 안  r_0 = 10 m',           0.313, 25, 1.5, [cn+10 ce],       300
  2, '원 위  r_0 = 25 m',           0.313, 25, 1.5, [cn+25 ce],       300
  2, '원 밖  r_0 = 44.7 m (기본)',  0.313, 25, 1.5, [0 0],            300
  3, '원 밖 멀리  r_0 = 84.9 m',    0.313, 25, 1.5, [cn-60 ce-60],    300

  4, 'u_{ref} = 1.0 m/s',           0.313, 25, 1.0, [0 0],            300
  4, 'u_{ref} = 1.5 m/s (기본)',    0.313, 25, 1.5, [0 0],            300
  4, 'u_{ref} = 2.0 m/s',           0.313, 25, 2.0, [0 0],            300

  5, 'r_d = 12 m',                  0.313, 12, 1.5, [0 0],            300
  5, 'r_d = 25 m (기본)',           0.313, 25, 1.5, [0 0],            300
  5, 'r_d = 40 m',                  0.313, 40, 1.5, [0 0],            300

  6, '|p_c| = 0.15',                0.150, 25, 1.5, [0 0],            300
  6, '|p_c| = 0.313 (기본)',        0.313, 25, 1.5, [0 0],            300
  6, '|p_c| = 0.60',                0.600, 25, 1.5, [0 0],            300
  6, '|p_c| = 1.00',                1.000, 25, 1.5, [0 0],            300
};
n = size(C,1);

%% 돌린다 -------------------------------------------------------------
load_system('W07_0_offline');
R = struct('grp',{},'name',{},'t',{},'xn',{},'yn',{},'psi',{},'rr',{}, ...
           'rd',{},'pc',{},'uref',{},'r0',{},'S',{});
fprintf('W07_sweep: %d 회 실행\n', n);
for k = 1:n
    pc = C{k,3};  rd = C{k,4};  ur = C{k,5};  p0 = C{k,6};  Tf = C{k,7};
    assignin('base','p_c',   pc);
    assignin('base','r_d',   rd);
    assignin('base','u_ref', ur);
    assignin('base','x0', [0.1; 0; 0; p0(1); p0(2); 0]);   % 뱃머리 정북 고정
    evalc(sprintf('out = sim(''W07_0_offline'', ''StopTime'', ''%g'');', Tf));

    R(k).grp  = C{k,1};
    R(k).name = C{k,2};
    R(k).t    = out.log_x_n.Time;
    R(k).xn   = out.log_x_n.Data(:);
    R(k).yn   = out.log_y_n.Data(:);
    R(k).psi  = out.log_psi.Data(:);
    R(k).rr   = out.log_r_dist.Data(:);
    R(k).rd   = rd;  R(k).pc = pc;  R(k).uref = ur;
    R(k).r0   = hypot(p0(1)-cn, p0(2)-ce);
    R(k).S    = score(R(k).t, R(k).xn, R(k).yn, out.log_u.Data(:), cn, ce, rd);
    fprintf('  %2d/%d  %-28s  정착반경 %6.2f m  오차 %+5.2f m  %s\n', ...
            k, n, R(k).name, R(k).S.mean_r, R(k).S.bias, R(k).S.dir);
end

%% 그림 ---------------------------------------------------------------
CLR = [0.114 0.306 0.847      % 파랑
       0.051 0.580 0.533      % 청록
       0.863 0.149 0.149      % 빨강
       0.851 0.467 0.024      % 주황
       0.420 0.330 0.720];    % 보라
f = figure('Name','W07 파라미터 바꿔 보기','Color','w','Position',[40 30 1500 900]);

panel(R, 1, [cn ce], CLR, 1, '1) 회전 방향 — p_c 의 부호 (삼각형 = 뱃머리)');
panel(R, 2, [cn ce], CLR, 2, '2) 시작 위치 — 안·위·밖 어디서 출발해도 같은 원');
conv(R, [2 3], CLR, 3, '3) 시작 위치 — 반경이 r_d 로 수렴');
panel(R, 4, [cn ce], CLR, 4, '4) 지령 속도 u_{ref}');
panel(R, 5, [cn ce], CLR, 5, '5) 목표 반경 r_d');
panel(R, 6, [cn ce], CLR, 6, '6) |p_c| — 클수록 원에 덜 끌린다');

if ~exist('img','dir'), mkdir('img'); end
print(f, '-dpng', '-r100', fullfile(pwd,'img','W07_sweep.png'));
fprintf('\n  img/W07_sweep.png 저장\n');

%% 표 -----------------------------------------------------------------
grp = [R.grp]';
nm  = string({R.name})';
r0v = arrayfun(@(s) s.r0, R)';
rdv = arrayfun(@(s) s.rd, R)';
mr  = arrayfun(@(s) s.S.mean_r,  R)';
bi  = arrayfun(@(s) s.S.bias,    R)';
pct = 100*abs(bi)./rdv;
te  = arrayfun(@(s) s.S.t_enter, R)';
mu  = arrayfun(@(s) s.S.mean_u,  R)';
dr  = arrayfun(@(s) s.S.dir,     R)';
T = table(grp, nm, r0v, rdv, mr, bi, pct, te, mu, dr, 'VariableNames', ...
    {'그룹','실행','시작반경_m','목표반경_m','정착반경_m','오차_m', ...
     '오차_rd대비_pct','원도달_s','평균u_mps','방향'});
fprintf('\n');  disp(T);
end

% ===================================================================
function S = score(t, xn, yn, u, cn, ce, rd)
% 지표 정의는 W07_plot 과 같다 — 원 도달 30 s 뒤부터 끝까지를 정착 구간으로 본다
r  = hypot(xn - cn, yn - ce);
th = unwrap(atan2(yn - ce, xn - cn));
k  = find(abs(r - rd) <= 0.3*rd, 1);
if isempty(k)
    S.t_enter = NaN;  k = 1;
else
    S.t_enter = t(k);
end
k0  = min(k + round(30/(t(2)-t(1))), numel(t));
seg = k0:numel(t);
if numel(seg) < 10, seg = k:numel(t); end
S.mean_r = mean(r(seg));
S.bias   = mean(r(seg)) - rd;
S.mean_u = mean(u(seg));
if mean(diff(th(seg))) > 0
    S.dir = "시계방향";
else
    S.dir = "반시계방향";
end
end

% ===================================================================
function panel(R, g, ctr, CLR, idx, ttl)
% 한 그룹의 궤적을 겹쳐 그린다 (가로축 동쪽, 세로축 북쪽)
sel = find([R.grp] == g);
subplot(2,3,idx); hold on; grid on; axis equal; box on;
th = linspace(0, 2*pi, 240);
shown = [];
for j = 1:numel(sel)
    k = sel(j);
    if ~ismember(R(k).rd, shown)                       % 목표 원 (붉은 점선)
        plot(ctr(2) + R(k).rd*cos(th), ctr(1) + R(k).rd*sin(th), '--', ...
             'Color',[0.75 0.1 0.1], 'LineWidth',1.1, 'HandleVisibility','off');
        shown(end+1) = R(k).rd;   %#ok<AGROW>
    end
end
for j = 1:numel(sel)
    k = sel(j);  col = CLR(mod(j-1,5)+1,:);
    plot(R(k).yn, R(k).xn, '-', 'Color',col, 'LineWidth',1.5, 'DisplayName',R(k).name);
    plot(R(k).yn(1), R(k).xn(1), 'o', 'MarkerSize',6, 'MarkerEdgeColor',col, ...
         'MarkerFaceColor','w', 'HandleVisibility','off');
    % 뱃머리 삼각형 — 곡선마다 위상을 어긋나게 찍어 서로 겹치지 않게 한다
    boats(R(k), ctr, col, 6, (j-1)/numel(sel), 0.11*R(k).rd);
end
plot(ctr(2), ctr(1), 'p', 'MarkerEdgeColor',[0.75 0.1 0.1], ...
     'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',14, 'HandleVisibility','off');
ax = vertcat(R(sel).xn);  ay = vertcat(R(sel).yn);  pad = 7;
axis([min(ay)-pad max(ay)+pad min(ax)-pad max(ax)+pad]);
xlabel('y  동쪽 [m]');  ylabel('x  북쪽 [m]');
title(ttl, 'FontSize',11);
legend('Location','southoutside', 'FontSize',8, 'Box','off');
set(gca,'FontSize',10);
end

% ===================================================================
function conv(R, g, CLR, idx, ttl)
% 중심까지의 거리 r(t) — 어느 쪽에서 출발해도 r_d 로 모인다
sel = find(ismember([R.grp], g));
subplot(2,3,idx); hold on; grid on; box on;
rd = R(sel(1)).rd;
plot([0 300], [rd rd], '--', 'Color',[0.75 0.1 0.1], 'LineWidth',1.3, ...
     'HandleVisibility','off');
text(104, rd+4, sprintf('r_d = %g m', rd), 'Color',[0.75 0.1 0.1], 'FontSize',10);
for j = 1:numel(sel)
    k = sel(j);
    plot(R(k).t, R(k).rr, '-', 'Color',CLR(mod(j-1,5)+1,:), 'LineWidth',1.5, ...
         'DisplayName',R(k).name);
end
xlim([0 150]);  ylim([0 95]);
xlabel('시간 [s]');  ylabel('중심까지 거리 r [m]');
title(ttl, 'FontSize',11);
legend('Location','northeast', 'FontSize',8, 'Box','off');
set(gca,'FontSize',10);
end

% ===================================================================
function boats(Rk, ctr, col, nm, phase, L)
% 궤적 위에 뱃머리 삼각형을 찍는다 — 뾰족한 끝이 선수각 psi 방향이다.
% 마지막 한 바퀴를 nm 등분해 찍되, phase 로 곡선마다 어긋나게 한다.
cn = ctr(1);  ce = ctr(2);
xn = Rk.xn;   yn = Rk.yn;   ps = Rk.psi;
th = unwrap(atan2(yn - ce, xn - cn));
s  = sign(th(end) - th(1));
if s == 0, s = 1; end
ix = zeros(1, nm);
if abs(th(end) - th(1)) >= 2*pi
    tgt = th(end) - s*2*pi*(((0:nm-1) + phase)/nm);
    for q = 1:nm
        [~, ix(q)] = min(abs(th - tgt(q)));
    end
else                                   % 한 바퀴를 못 돈 경우 — 뒤쪽 절반을 등분
    ix = round(linspace(numel(th)/2, numel(th), nm));
end
hull = [1.0 0; -0.6 0.5; -0.35 0; -0.6 -0.5];   % [앞뒤 좌우] — 배 모양
for i = ix(:)'
    p  = ps(i);
    nn = (hull(:,1)*cos(p) - hull(:,2)*sin(p))*L + xn(i);   % 북
    ee = (hull(:,1)*sin(p) + hull(:,2)*cos(p))*L + yn(i);   % 동
    patch('XData',ee, 'YData',nn, 'FaceColor',col, 'EdgeColor',col, ...
          'FaceAlpha',0.85, 'LineWidth',0.5, 'HandleVisibility','off');
end
end

% ===================================================================
function restore()
setappdata(0, 'W07_skip_run', true);
evalc('evalin(''base'', ''W07_setup'')');
end
