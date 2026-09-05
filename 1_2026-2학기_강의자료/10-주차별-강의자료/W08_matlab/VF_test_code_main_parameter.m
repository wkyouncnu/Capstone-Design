% =========================================================================
% 원형 궤도 벡터 필드 (식 9) 파라미터(v_d, r_d, p_c) 영향 비교 시뮬레이터
% =========================================================================
clear; clc; close all;

%% 1. 그리드 생성 (NED 좌표계)
[E_grid, N_grid] = meshgrid(-300:30:300, -300:30:300);
R_grid = sqrt(N_grid.^2 + E_grid.^2);
Theta_grid = atan2(E_grid, N_grid); % 북쪽 기준 절대 방위각

% 원점(0,0)에서의 특이점(r=0) 분모 0 나누기 방지
R_grid(R_grid == 0) = 1e-3;

%% 2. 시나리오 설정 [v_d, r_d, p_c, '그래프 제목']
scenarios = {
    25, 150,  0.33, '1) 기본 설정 (r_d=150, p_c=0.33)';
    25,  50,  0.33, '2) 목표 반경 축소 (r_d=50)';
    25, 150,  5.00, '3) 수렴 게인 절댓값 증가 (|p_c|=5.0)';
    25, 150, -0.33, '4) 회전 방향 반전 (p_c=-0.33)'
};

%% 3. 그래프 창 설정
figure('Name', 'Vector Field Parameter Analysis', 'Color', 'w', 'Position', [100, 100, 900, 800]);

%% 4. 각 시나리오별 벡터 필드 연산 및 시각화
for i = 1:4
    % 파라미터 추출
    vd = scenarios{i, 1};
    rd = scenarios{i, 2};
    pc = scenarios{i, 3};
    title_str = scenarios{i, 4};
    
    % 식 (9) 계산: 벡터 필드의 방사(r) 및 접선(theta) 속도 성분
    denominator = sqrt((R_grid - rd).^2 + pc^2 * R_grid.^2);
    r_dot = -vd * (R_grid - rd) ./ denominator;
    r_theta_dot = vd * pc * R_grid ./ denominator;
    
    % 식 (13) 계산: 절대 코스 명령각(chi_d) 유도
    chi_d = Theta_grid + atan2(r_theta_dot, r_dot);
    
    % 화살표를 그리기 위해 극좌표계 속도를 직교좌표계(N, E)로 변환
    U_N = vd * cos(chi_d);
    V_E = vd * sin(chi_d);
    
    % Subplot 그리기 (2행 2열)
    subplot(2, 2, i);
    hold on; grid on; axis equal;
    axis([-350 350 -350 350]);
    
    % 웨이포인트(원점) 표시
    plot(0, 0, 'k^', 'MarkerFaceColor', 'y', 'MarkerSize', 8);
    
    % 목표 원형 궤도 그리기 (빨간색 점선)
    th = linspace(0, 2*pi, 100);
    plot(rd*sin(th), rd*cos(th), 'r--', 'LineWidth', 1.5);
    
    % 벡터 필드 화살표 렌더링
    quiver(E_grid, N_grid, V_E, U_N, 1.2, 'Color', [0 0.4470 0.7410]);
    
    % 꾸미기
    title(title_str, 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('East'); ylabel('North');
end

% 전체 제목
sgtitle('식 (9) 파라미터 변화에 따른 벡터 필드 공간 흐름 비교', 'FontSize', 16, 'FontWeight', 'bold');