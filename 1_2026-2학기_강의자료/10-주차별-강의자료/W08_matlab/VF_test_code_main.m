% =========================================================================
% Unmanned Aircraft Vector Field Path Following (Equation 9 & 13)
% =========================================================================
clear; clc; close all;

%% 1. 파라미터 및 환경 설정 (Parameters)
vd = 25;       % 목표 비행 속도 (m/s)
rd = 150;      % 목표 원형 궤도 반경 (m)
pc = 0.33;     % 원형 궤도 진입 게인 (양수: 반시계 방향 회전)

% 웨이포인트(원점) 위치 (North, East)
WP_N = 0; 
WP_E = 0; 

%% 2. 2D 공간 격자 생성 (NED 좌표계: X=North, Y=East)
[E_grid, N_grid] = meshgrid(-300:25:300, -300:25:300);

% 결과 저장을 위한 행렬 초기화
U_N = zeros(size(N_grid)); % North 방향 속도 성분
V_E = zeros(size(E_grid)); % East 방향 속도 성분

%% 3. 공간 전체의 벡터 필드 연산 (식 9, 식 13)
for i = 1:numel(N_grid)
    % 1) 원점으로부터의 상대 변위
    dN = N_grid(i) - WP_N;
    dE = E_grid(i) - WP_E;
    
    % 2) 극좌표계 변환: 거리(r) 및 절대 방위각(theta)
    r = sqrt(dN^2 + dE^2);
    
    % 원점(r=0)에서의 특이점 방지
    if r < 1e-3
        continue; 
    end
    
    % theta 계산 (NED 기준: atan2(East, North))
    theta = atan2(dE, dN); 
    
    % 3) 벡터 필드 속도 성분 계산 (식 9)
    denominator = sqrt((r - rd)^2 + pc^2 * r^2);
    r_dot = -vd * (r - rd) / denominator;           % 방사 속도 (멀어지거나 가까워짐)
    r_theta_dot = vd * pc * r / denominator;        % 접선 속도 (회전함)
    
    % 4) 조향 명령각 연산 (식 13)
    relative_angle = atan2(r_theta_dot, r_dot);     % 반경선 기준 상대 조향각
    chi_d = theta + relative_angle;                 % 절대 코스 명령각
    
    % 5) 화살표(Quiver) Plot을 위한 직교 좌표계 속도 변환
    U_N(i) = vd * cos(chi_d);
    V_E(i) = vd * sin(chi_d);
end

%% 4. 벡터 필드 시각화 (Plotting)
figure('Color', 'w', 'Position', [100, 100, 700, 700]);
hold on; grid on; axis equal;

% 목표 궤도 (반경 rd) 그리기
theta_circle = linspace(0, 2*pi, 100);
plot(WP_E + rd*sin(theta_circle), WP_N + rd*cos(theta_circle), 'r--', 'LineWidth', 2);

% 벡터 필드 화살표 그리기 (방향성 확인)
q = quiver(E_grid, N_grid, V_E, U_N, 1.2, 'b');
q.Color = [0 0.4470 0.7410];

% 원점(Waypoint) 표시
plot(WP_E, WP_N, 'k^', 'MarkerFaceColor', 'y', 'MarkerSize', 12);

xlabel('East (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('North (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('Vector Field for Loitering Circle (Eq. 9)', 'FontSize', 14);
legend('Desired Orbit (r_d = 150m)', 'Guidance Vector Field', 'Waypoint', 'Location', 'best');
set(gca, 'FontSize', 11);

%% 5. 특정 시나리오에서의 각도 검증 (Console Output)
disp('======================================================');
disp('   특정 위치에서의 식(13) 각도 산출 검증 시나리오');
disp('======================================================');

% 테스트할 무인기 위치 [North, East]
test_cases = [
    0, 150;   % Case 1: 궤도 위 정동쪽 (목표 궤도 안착 상태)
    300, 0;   % Case 2: 궤도 밖 정북쪽 (멀리서 접근 중)
    0, -50    % Case 3: 궤도 안 정서쪽 (내부에서 바깥으로 팽창 중)
];

for k = 1:size(test_cases, 1)
    N = test_cases(k, 1);
    E = test_cases(k, 2);
    
    r = sqrt(N^2 + E^2);
    theta = atan2(E, N);
    
    denominator = sqrt((r - rd)^2 + pc^2 * r^2);
    r_dot = -vd * (r - rd) / denominator;
    r_theta_dot = vd * pc * r / denominator;
    
    relative_angle = atan2(r_theta_dot, r_dot);
    chi_d = theta + relative_angle;
    
    % Wrap chi_d to [-pi, pi] for cleaner display
    chi_d = atan2(sin(chi_d), cos(chi_d)); 
    
    fprintf('\n[시나리오 %d] 무인기 위치: North = %d, East = %d (r = %.1f)\n', k, N, E, r);
    fprintf('  1) 절대 방위각 (theta) : %.1f 도\n', rad2deg(theta));
    fprintf('  2) r_dot (방사 속도)   : %.2f m/s\n', r_dot);
    fprintf('  3) r_theta_dot (회전)  : %.2f m/s\n', r_theta_dot);
    fprintf('  4) 상대 조향각 (atan2) : %.1f 도 (반경선 기준 꺾는 각도)\n', rad2deg(relative_angle));
    fprintf('  => 최종 명령각 (chi_d) : %.1f 도\n', rad2deg(chi_d));
end
disp('======================================================');