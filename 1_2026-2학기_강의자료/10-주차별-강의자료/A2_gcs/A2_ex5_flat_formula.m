function A2_ex5_flat_formula(lla)
%A2_EX5_FLAT_FORMULA  예제 5 — lla2ned(...,'flat') 의 내부 식을 손으로 다시 쓴다
%
%   입력 : lla  Nx3  [위도 경도 고도]  — 생략하면 기준점 둘레의 네 점을 쓴다
%   출력 : 화면 출력만 (손식 결과 · MATLAB 결과 · 둘의 차)
%
%   >> A2_ex5_flat_formula
%   >> A2_ex5_flat_formula([36.3730 127.3940 0])
%
%   MATLAB 이 실제로 쓰는 식 (R2024b, lla2nedFlat.m 을 그대로 옮김)
%
%     e2  = 2f - f^2
%     R_N = a / sqrt(1 - e2 sin^2(lat0))
%     R_M = R_N (1 - e2) / (1 - e2 sin^2(lat0))
%
%     x_n = (lat - lat0) / atan2d(1, R_M)
%     y_n = (lon - lon0) / atan2d(1, R_N cos(lat0))
%     z_n = -(h - h0)
%
%   읽는 법
%     - atan2d(1, R) 은 "R 만큼 간 거리가 몇 도인가" 이다. 거의 (180/pi)/R 과 같다
%     - **곡률반경을 기준점 lat0 한 곳에서만 계산한다.** 이것이 평면 가정의 정체다
%     - 세 식 어디에도 lat 이 다시 들어가지 않는다 -> 멀어질수록 틀린다

    if nargin < 1
        lla0 = A2_ex_lla0();
        lla = [lla0(1)+0.0010, lla0(2),          0
               lla0(1),        lla0(2)+0.0010,   0
               lla0(1)-0.0005, lla0(2)-0.0005,  10
               lla0(1)+0.0100, lla0(2)+0.0100,   0];
    end
    lla0 = A2_ex_lla0();

    a = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;

    fprintf('\n=== 예제 5 · ''flat'' 내부 식 ===\n');
    fprintf('\n[입력]  기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);
    fprintf('        변환할 점 %d 개\n', size(lla,1));

    %% 곡률반경 — 기준점에서 한 번만 계산한다
    R_N = a / sqrt(1 - e2*sind(lla0(1))^2);
    R_M = R_N * (1 - e2) / (1 - e2*sind(lla0(1))^2);

    fprintf('\n[중간값]  기준점에서 한 번만 구한다\n');
    fprintf('  R_N = %.4f m\n', R_N);
    fprintf('  R_M = %.4f m\n', R_M);
    fprintf('  atan2d(1, R_M)            = %.12e deg   (북쪽 1 m 가 몇 도인가)\n', atan2d(1, R_M));
    fprintf('  atan2d(1, R_N cos(lat0))  = %.12e deg   (동쪽 1 m 가 몇 도인가)\n', ...
            atan2d(1, R_N*cosd(lla0(1))));

    %% 손식
    dLat = lla(:,1) - lla0(1);
    dLon = lla(:,2) - lla0(2);

    hand        = zeros(size(lla));
    hand(:,1)   = dLat ./ atan2d(1, R_M);
    hand(:,2)   = dLon ./ atan2d(1, R_N*cosd(lla0(1)));
    hand(:,3)   = -lla(:,3) + lla0(3);

    %% MATLAB
    ml = lla2ned(lla, lla0, 'flat');

    fprintf('\n[출력]  손식 vs lla2ned(...,''flat'')\n');
    fprintf('  %4s  %12s %12s  %12s %12s  %12s\n', ...
            '점', '손 x_n[m]', '손 y_n[m]', 'ML x_n[m]', 'ML y_n[m]', '차[m]');
    for k = 1:size(lla,1)
        fprintf('  %4d  %12.4f %12.4f  %12.4f %12.4f  %12.3e\n', ...
                k, hand(k,1), hand(k,2), ml(k,1), ml(k,2), norm(hand(k,:) - ml(k,:)));
    end
    fprintf('  최대 차 = %.3e m  -> 같은 식임이 확인됐다\n', max(vecnorm(hand - ml, 2, 2)));

    %% atan2d 를 쓰는 것과 1/R 로 어림하는 것의 차
    lin        = zeros(size(lla));
    lin(:,1)   = dLat * (pi/180) * R_M;
    lin(:,2)   = dLon * (pi/180) * R_N*cosd(lla0(1));
    lin(:,3)   = hand(:,3);

    fprintf('\n[곁가지]  atan2d(1,R) 대신 (pi/180)R 로 어림하면\n');
    fprintf('  최대 차 = %.3e m  (사실상 같다. 교재에서는 보통 이쪽으로 쓴다)\n', ...
            max(vecnorm(lin - ml, 2, 2)));

    fprintf('\n[직접 해 볼 것]\n');
    fprintf('  1. 점을 기준점에서 10 km 떨어뜨리면 손식과 MATLAB 이 여전히 같은가\n');
    fprintf('     (같다. 두 쪽 모두 같은 근사를 쓰므로 — 틀리는 것은 ''ellipsoid'' 대비다)\n');
    fprintf('  2. 고도를 10 m 올리면 x_n, y_n 이 바뀌는가\n');

    fprintf('\n=== 예제 5 끝 ===\n');
end
