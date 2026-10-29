function A2_ex2_lla2ecef(lla)
%A2_EX2_LLA2ECEF  예제 2 — 위경도·고도를 지구중심 직교좌표(ECEF)로 바꾼다
%
%   입력 : lla  1x3  [위도(deg) 경도(deg) 고도(m)]  — 생략하면 기준점을 쓴다
%   출력 : 화면 출력만 (손으로 쓴 식의 결과와, 있으면 lla2ecef 와의 대조)
%
%   >> A2_ex2_lla2ecef                       % 기준점
%   >> A2_ex2_lla2ecef([0 0 0])              % 적도-본초자오선
%   >> A2_ex2_lla2ecef([90 0 0])             % 북극
%   >> A2_ex2_lla2ecef([36.3719625 127.3927656 100])
%
%   무엇을 보는가
%     위도·경도·고도 (각도 2개 + 길이 1개) 는 **지구 중심에서 본 한 점**이다.
%     그 점을 x-y-z 세 길이로 적은 것이 ECEF(Earth-Centered Earth-Fixed) 다.
%     NED 로 가는 길은 전부 이 ECEF 를 거쳐 간다
%
%   쓰는 식
%     R_N = a / sqrt(1 - e^2 sin^2(lat))        % 묘유선 곡률반경
%     x = (R_N + h) cos(lat) cos(lon)
%     y = (R_N + h) cos(lat) sin(lon)
%     z = (R_N (1 - e^2) + h) sin(lat)
%
%   z 식에만 (1 - e^2) 가 붙는 이유는 예제 3 에서 본다

    if nargin < 1, lla = A2_ex_lla0(); end

    a  = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;

    lat = lla(1);  lon = lla(2);  h = lla(3);

    fprintf('\n=== 예제 2 · 위경도 -> ECEF ===\n');
    fprintf('\n[입력]\n');
    fprintf('  위도 lat = %.7f deg\n', lat);
    fprintf('  경도 lon = %.7f deg\n', lon);
    fprintf('  고도 h   = %.3f m\n',   h);

    %% 손으로 쓴 식
    R_N = a / sqrt(1 - e2*sind(lat)^2);

    x = (R_N + h) * cosd(lat) * cosd(lon);
    y = (R_N + h) * cosd(lat) * sind(lon);
    z = (R_N*(1 - e2) + h) * sind(lat);

    fprintf('\n[중간값]\n');
    fprintf('  R_N (묘유선 곡률반경) = %.4f m\n', R_N);
    fprintf('    - 적도에서 a = %.0f m 와 같고, 극으로 갈수록 커진다\n', a);

    fprintf('\n[출력]  ECEF 좌표\n');
    fprintf('  x = %+15.4f m\n', x);
    fprintf('  y = %+15.4f m\n', y);
    fprintf('  z = %+15.4f m\n', z);
    fprintf('  |r| = %.4f m   (지구 중심에서 이 점까지의 직선거리)\n', norm([x y z]));

    %% MATLAB 함수와 대조 — Aerospace Toolbox 가 있을 때만
    if exist('lla2ecef', 'file') == 2
        m = lla2ecef([lat lon h]);
        fprintf('\n[대조]  MATLAB lla2ecef\n');
        fprintf('  x = %+15.4f m\n', m(1));
        fprintf('  y = %+15.4f m\n', m(2));
        fprintf('  z = %+15.4f m\n', m(3));
        fprintf('  손식과의 차 = %.3e m  -> 같은 식이다\n', norm(m - [x y z]));
    else
        fprintf('\n[대조]  lla2ecef 가 없다 (Aerospace Toolbox 미설치) — 건너뜀\n');
        fprintf('  손식만으로도 예제 6 에서 lla2ned 와 맞춰 볼 수 있다\n');
    end

    %% 읽는 법
    fprintf('\n[읽는 법]\n');
    fprintf('  - x 축은 적도면 위, 경도 0 도 방향 (본초자오선)\n');
    fprintf('  - y 축은 적도면 위, 동경 90 도 방향\n');
    fprintf('  - z 축은 북극 방향\n');
    fprintf('  - 세 축 모두 지구에 **붙어서 같이 돈다**. 그래서 Earth-Fixed 다\n');
    fprintf('  - 고도 h 를 1 m 올리면 |r| 이 정확히 1 m 늘어난다. 직접 바꿔 볼 것\n');

    fprintf('\n=== 예제 2 끝 ===\n');
end
