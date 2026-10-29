function A2_ex4_curvature()
%A2_EX4_CURVATURE  예제 4 — 1 도가 몇 m 인가를 곡률반경으로 설명한다
%
%   입력 : 없음
%   출력 : 화면 출력만 (위도별 R_N · R_M, 그리고 1 도의 남북·동서 길이)
%
%   >> A2_ex4_curvature
%
%   무엇을 보는가
%     예제의 1-1 절에서 "위도 1 도와 경도 1 도의 m 환산이 다르다" 고 했다.
%     그 두 숫자가 **어디서 나오는지** 식으로 확인한다
%
%   쓰는 식
%     R_N = a / sqrt(1 - e^2 sin^2(lat))                   묘유선 (동서 방향)
%     R_M = R_N (1 - e^2) / (1 - e^2 sin^2(lat))           자오선 (남북 방향)
%
%     북쪽 1 도의 길이 = R_M * (pi/180)
%     동쪽 1 도의 길이 = R_N * cos(lat) * (pi/180)
%
%   R_M 과 R_N 은 **반지름이 아니라 곡률반경**이다.
%   그 자리에서 지표가 휘어진 정도를 원으로 바꿔 놓은 값이라, R_N 은 극에서
%   지구 반지름보다 커진다

    a = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;
    lla0 = A2_ex_lla0();

    fprintf('\n=== 예제 4 · 곡률반경과 1 도의 길이 ===\n');
    fprintf('\n[입력]  위도 몇 곳 (기준점 %.4f 도 포함)\n', lla0(1));

    lat_list = [0 15 30 lla0(1) 45 60 75];

    fprintf('\n[출력 1]  곡률반경\n');
    fprintf('  %10s  %14s  %14s  %12s\n', '위도[deg]', 'R_N[m]', 'R_M[m]', 'R_N-R_M[m]');
    for lat = lat_list
        R_N = a / sqrt(1 - e2*sind(lat)^2);
        R_M = R_N * (1 - e2) / (1 - e2*sind(lat)^2);
        fprintf('  %10.4f  %14.2f  %14.2f  %12.2f\n', lat, R_N, R_M, R_N - R_M);
    end

    fprintf('\n[출력 2]  1 도가 몇 m 인가\n');
    fprintf('  %10s  %16s  %16s  %10s\n', '위도[deg]', '위도 1도[m]', '경도 1도[m]', '비[동/북]');
    for lat = lat_list
        R_N = a / sqrt(1 - e2*sind(lat)^2);
        R_M = R_N * (1 - e2) / (1 - e2*sind(lat)^2);
        m_lat = R_M * pi/180;
        m_lon = R_N * cosd(lat) * pi/180;
        fprintf('  %10.4f  %16.1f  %16.1f  %10.4f\n', lat, m_lat, m_lon, m_lon/m_lat);
    end

    %% MATLAB 함수와 대조 — 같은 숫자가 나와야 한다
    R_N0 = a / sqrt(1 - e2*sind(lla0(1))^2);
    R_M0 = R_N0 * (1 - e2) / (1 - e2*sind(lla0(1))^2);

    d = lla2ned([lla0(1)+1e-5, lla0(2)+1e-5, 0], lla0, 'flat');

    fprintf('\n[대조]  기준점에서 1e-5 도를 움직여 본다\n');
    fprintf('  손식   : 북 %.6f m / 동 %.6f m\n', ...
            R_M0*pi/180*1e-5, R_N0*cosd(lla0(1))*pi/180*1e-5);
    fprintf('  lla2ned: 북 %.6f m / 동 %.6f m\n', d(1), d(2));
    fprintf('  차     : 북 %.3e m / 동 %.3e m\n', ...
            abs(R_M0*pi/180*1e-5 - d(1)), abs(R_N0*cosd(lla0(1))*pi/180*1e-5 - d(2)));

    fprintf('\n[읽는 법]\n');
    fprintf('  - 북쪽 1 도는 위도가 올라갈수록 **조금 길어진다** (극 쪽이 더 납작해 덜 휘므로)\n');
    fprintf('  - 동쪽 1 도는 cos(위도) 때문에 **빠르게 짧아진다**. 극에서는 0 이다\n');
    fprintf('  - 기준점(위도 %.2f 도)에서 둘의 비는 약 %.3f 이다\n', ...
            lla0(1), (R_N0*cosd(lla0(1)))/R_M0);
    fprintf('  - 이것이 "각도를 그냥 빼서 거리로 쓰면 안 되는" 이유의 전부다\n');

    fprintf('\n[직접 해 볼 것]\n');
    fprintf('  1. 위도 0 도와 60 도에서 경도 1 도의 길이 비가 왜 2 배쯤 되는가\n');
    fprintf('  2. e2 = 0 (구) 으로 두면 R_N 과 R_M 이 어떻게 되는가\n');

    fprintf('\n=== 예제 4 끝 ===\n');
end
