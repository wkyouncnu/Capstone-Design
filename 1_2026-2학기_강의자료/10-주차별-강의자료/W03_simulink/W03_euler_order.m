% W03_EULER_ORDER  오일러각은 "세 숫자" 가 아니라 "세 숫자와 순서" 다 — 눈으로 확인한다.
%
%   >> W03_euler_order
%
%   무엇을 보이는가
%     1) 같은 세 각 (psi, theta, phi) 을 두 순서로 돌리면 배가 다른 자세가 된다
%          선박 규약  R = Rz(psi) Ry(theta) Rx(phi)     (z-y-x, Fossen · MSS Rzyx)
%          다른 순서  R = Rx(phi) Ry(theta) Rz(psi)     (x-y-z)
%     2) 선박 규약을 두 가지로 읽어도 같은 행렬이 나온다
%          움직이는 축  요 -> (돌아간 y) 피치 -> (돌아간 x) 롤     = 3주차 본문의 읽는 법
%          고정된 축    롤 -> 피치 -> 요 (NED 축 그대로)
%
%   좌표 — NED 몸체축 (x 선수, y 우현, z 아래). 그림은 비스듬히 위에서 본다 (D 가 아래).

psi_d = 90;  theta_d = 30;  phi_d = 30;          % [deg] 세 각
psi = deg2rad(psi_d);  th = deg2rad(theta_d);  ph = deg2rad(phi_d);

Rx = @(a) [1 0 0; 0 cos(a) -sin(a); 0 sin(a) cos(a)];
Ry = @(a) [cos(a) 0 sin(a); 0 1 0; -sin(a) 0 cos(a)];
Rz = @(a) [cos(a) -sin(a) 0; sin(a) cos(a) 0; 0 0 1];

R_zyx = Rz(psi)*Ry(th)*Rx(ph);                    % 선박 규약
R_xyz = Rx(ph)*Ry(th)*Rz(psi);                    % 순서만 바꾼 것

%% 1. 같은 세 숫자, 다른 자세 -------------------------------------------
fprintf('\n세 각  psi = %g deg,  theta = %g deg,  phi = %g deg\n', psi_d, theta_d, phi_d);
fprintf('\n선수(x_b)가 가리키는 방향 [N  E  D]\n');
fprintf('  z-y-x (선박 규약) : [%7.3f %7.3f %7.3f]\n', R_zyx(:,1));
fprintf('  x-y-z (순서 바꿈) : [%7.3f %7.3f %7.3f]\n', R_xyz(:,1));
fprintf('  두 선수 방향 사이의 각 : %.1f deg\n', ...
        acosd(max(-1, min(1, dot(R_zyx(:,1), R_xyz(:,1))))));

% MSS 가 있으면 그것과도 맞춰 본다
if exist('Rzyx', 'file') == 2
    fprintf('  MSS Rzyx 와의 차이   : %.2e\n', max(abs(Rzyx(ph,th,psi) - R_zyx), [], 'all'));
end

%% 2. 두 가지 읽는 법은 같은 행렬이다 ------------------------------------
%  움직이는 축 — 매번 "지금의 몸체축" 둘레로 돌리면 오른쪽에 곱해진다
R_moving = eye(3);
R_moving = R_moving * Rz(psi);    % (1) 요  : z 둘레
R_moving = R_moving * Ry(th);     % (2) 피치: 요로 돌아간 y 둘레
R_moving = R_moving * Rx(ph);     % (3) 롤  : 요·피치로 돌아간 x 둘레
%  고정된 축 — 매번 NED 축 둘레로 돌리면 왼쪽에 곱해진다
R_fixed = eye(3);
R_fixed = Rx(ph) * R_fixed;       % (1) 롤  : 고정 x 둘레
R_fixed = Ry(th) * R_fixed;       % (2) 피치: 고정 y 둘레
R_fixed = Rz(psi) * R_fixed;      % (3) 요  : 고정 z 둘레
fprintf('\n선박 규약을 읽는 두 방법\n');
fprintf('  움직이는 축 (요 -> 피치 -> 롤) 과 식의 차이 : %.2e\n', max(abs(R_moving - R_zyx), [], 'all'));
fprintf('  고정된 축   (롤 -> 피치 -> 요) 과 식의 차이 : %.2e\n', max(abs(R_fixed  - R_zyx), [], 'all'));

%% 3. 그림 ------------------------------------------------------------
% 선체 — 갑판 오각형 + 선수 표시
hull = [ 2.0  0.0 0;  1.0  0.6 0; -1.5  0.6 0; -1.5 -0.6 0;  1.0 -0.6 0]';
h = figure('Name','W03 오일러각 순서','Position',[80 80 1000 520],'Color','w');
cases = {R_zyx, 'z-y-x  (선박 규약)'; R_xyz, 'x-y-z  (순서만 바꿈)'};
for k = 1:2
    subplot(1,2,k); hold on; axis equal; axis off;
    R = cases{k,1};
    % NED 기준축
    quiver3(0,0,0, 2.6,0,0, 0, 'k', 'LineWidth',0.8); text(2.8,0,0,'N','FontSize',11);
    quiver3(0,0,0, 0,2.6,0, 0, 'k', 'LineWidth',0.8); text(0,2.8,0,'E','FontSize',11);
    quiver3(0,0,0, 0,0,2.0, 0, 'k', 'LineWidth',0.8); text(0,0,2.2,'D','FontSize',11);
    % 돌리기 전의 선체 (회색)
    fill3(hull(1,:), hull(2,:), hull(3,:), [0.85 0.85 0.85], 'FaceAlpha',0.4, 'EdgeColor',[0.6 0.6 0.6]);
    % 돌린 선체
    P = R*hull;
    fill3(P(1,:), P(2,:), P(3,:), [1.00 0.88 0.72], 'FaceAlpha',0.55, 'EdgeColor','k', 'LineWidth',1.2);
    % 몸체축
    c = {[0.85 0.33 0.10], [0.00 0.45 0.74], [0.47 0.67 0.19]};
    lab = {'x_b (선수)','y_b (우현)','z_b (아래)'};
    for j = 1:3
        quiver3(0,0,0, 2.2*R(1,j), 2.2*R(2,j), 2.2*R(3,j), 0, 'Color', c{j}, 'LineWidth', 2);
        text(2.45*R(1,j), 2.45*R(2,j), 2.45*R(3,j), lab{j}, 'Color', c{j}, 'FontSize', 10);
    end
    set(gca, 'ZDir','reverse', 'YDir','normal');
    view([-40 22]); axis tight; camzoom(1.25);
    title(sprintf('%s\n\\psi=%g°, \\theta=%g°, \\phi=%g°', cases{k,2}, psi_d, theta_d, phi_d));
end
d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, 'W03_euler_order.png'), 'Resolution', 110);
fprintf('\n그림: img/W03_euler_order.png\n');
