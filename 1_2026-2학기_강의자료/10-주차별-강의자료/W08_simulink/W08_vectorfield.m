% W08_VECTORFIELD  로이터 벡터필드를 그려 본다.
%
%   배를 돌리기 전에 "필드가 어떻게 생겼는지" 먼저 눈으로 보는 것이 목적이다.
%   공간의 모든 점에 화살표를 하나씩 그린다. 배는 그 화살표를 따라가면 된다.
%
%   >> W08_vectorfield
%
%   원본: UGV_Loitering/Ackermann_Model_YYC/VF_test_code_main_parameter.m
%   식 (9), (13) — Jung, Lim, Lee, Bang

clear; close all; clc;

%% 격자 (NED) --------------------------------------------------------
lim = 60;  step = 6;
[E, N] = meshgrid(-lim:step:lim, -lim:step:lim);

%% 비교할 네 조건  [r_d, p_c, 제목] ------------------------------------
vd = 1.5;                       % WAM-V 속도 [m/s]
CASES = {
    25,  0.313, '1) 기본  r_d = 25,  p_c = +0.313  (시계방향)'
    12,  0.313, '2) 반경 축소  r_d = 12'
    25,  1.500, '3) |p_c| 증가  p_c = 1.5  (원에 덜 끌린다)'
    25, -0.313, '4) 부호 반전  p_c = -0.313  (반시계방향)'
};

figure('Name','W08 로이터 벡터필드','Color','w','Position',[80 60 980 900]);

for i = 1:4
    rd = CASES{i,1};  pc = CASES{i,2};

    r     = sqrt(N.^2 + E.^2);
    r(r == 0) = 1e-3;                       % 중심은 특이점
    theta = atan2(E, N);                    % NED: atan2(East, North)

    % --- 식 (9) : 극좌표 벡터필드 ---
    D       = sqrt((r - rd).^2 + (pc*r).^2);
    r_dot   = -vd * (r - rd) ./ D;          % 반경 방향 — 원에 붙는 성분
    rth_dot =  vd * pc * r   ./ D;          % 접선 방향 — 도는 성분

    % --- 식 (13) : 극좌표 -> NED ---
    vN = r_dot.*cos(theta) - rth_dot.*sin(theta);
    vE = r_dot.*sin(theta) + rth_dot.*cos(theta);

    subplot(2,2,i); hold on; grid on; axis equal;
    axis([-lim-5 lim+5 -lim-5 lim+5]);

    th = linspace(0, 2*pi, 200);
    plot(rd*sin(th), rd*cos(th), '--', 'Color',[0.75 0.1 0.1], 'LineWidth',1.8);
    plot(0, 0, 'p', 'MarkerEdgeColor',[0.75 0.1 0.1], ...
         'MarkerFaceColor',[1 0.85 0.2], 'MarkerSize',14);

    quiver(E, N, vE, vN, 1.1, 'Color',[0 0.45 0.74]);

    xlabel('East [m]'); ylabel('North [m]');
    title(CASES{i,3}, 'FontSize',10);
end

fprintf('\n필드 읽는 법\n');
fprintf('  원 바깥 : 화살표가 중심 쪽으로 기울어 있다\n');
fprintf('  원 위   : 화살표가 원에 접한다\n');
fprintf('  원 안쪽 : 화살표가 바깥으로 기울어 있다\n');
fprintf('  p_c 부호가 도는 방향을, 크기가 "원에 얼마나 끌리는가"를 정한다\n');
