function A2_ex6_ellipsoid_formula(lla)
%A2_EX6_ELLIPSOID_FORMULA  예제 6 — lla2ned(...,'ellipsoid') 의 내부 식을 손으로 다시 쓴다
%
%   입력 : lla  Nx3  [위도 경도 고도]  — 생략하면 기준점 둘레의 네 점을 쓴다
%   출력 : 화면 출력만 (ECEF 를 거쳐 간 손식 결과와 MATLAB 결과의 차)
%
%   >> A2_ex6_ellipsoid_formula
%
%   MATLAB 이 실제로 쓰는 길 (R2024b, fusion.internal.frames.* 를 그대로 옮김)
%
%     1) 점과 기준점을 각각 ECEF 로 올린다            (예제 2 의 식)
%     2) 두 ECEF 를 뺀다                              dr = r - r0
%     3) 기준점의 위경도로 만든 회전행렬을 곱한다      ned = R * dr
%
%     R(lat0, lon0) =
%       [ -sin(lat0)cos(lon0)   -sin(lat0)sin(lon0)    cos(lat0)
%              -sin(lon0)             cos(lon0)            0
%         -cos(lat0)cos(lon0)   -cos(lat0)sin(lon0)   -sin(lat0) ]
%
%   읽는 법
%     - 1 행이 North, 2 행이 East, 3 행이 Down 이다
%     - 3 행은 타원체면 **법선의 반대 방향** — 지구 중심을 가리키는 것이 아니다
%     - 'flat' 과 달리 근사가 없다. 대신 기준점에서 멀어지면 접평면이라 z 가 떠오른다

    if nargin < 1
        lla0 = A2_ex_lla0();
        lla = [lla0(1)+0.0010, lla0(2),          0
               lla0(1),        lla0(2)+0.0010,   0
               lla0(1)-0.0005, lla0(2)-0.0005,  10
               lla0(1)+0.0100, lla0(2)+0.0100,   0];
    end
    lla0 = A2_ex_lla0();

    fprintf('\n=== 예제 6 · ''ellipsoid'' 내부 식 ===\n');
    fprintf('\n[입력]  기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);
    fprintf('        변환할 점 %d 개\n', size(lla,1));

    %% 1) ECEF 로 올린다
    r  = local_lla2ecef(lla);
    r0 = local_lla2ecef(lla0);

    fprintf('\n[중간값 1]  기준점의 ECEF\n');
    fprintf('  r0 = [%+.3f  %+.3f  %+.3f] m\n', r0);

    %% 2) 뺀다
    dr = r - r0;

    %% 3) 회전
    cl = cosd(lla0(1));  sl = sind(lla0(1));      % lat0
    cn = cosd(lla0(2));  sn = sind(lla0(2));      % lon0

    R = [ -sl*cn   -sl*sn    cl
             -sn       cn     0
          -cl*cn   -cl*sn   -sl ];

    fprintf('\n[중간값 2]  ECEF -> NED 회전행렬 R\n');
    for k = 1:3
        fprintf('  [ %+9.6f  %+9.6f  %+9.6f ]\n', R(k,:));
    end
    fprintf('  det(R) = %+.12f   (회전행렬이므로 +1 이어야 한다)\n', det(R));
    fprintf('  R*R'' - I 의 최대값 = %.3e   (직교행렬인지 확인)\n', max(abs(R*R' - eye(3)), [], 'all'));

    hand = (R * dr.').';

    %% MATLAB
    ml = lla2ned(lla, lla0, 'ellipsoid');

    fprintf('\n[출력]  손식 vs lla2ned(...,''ellipsoid'')\n');
    fprintf('  %4s  %12s %12s %10s  %12s\n', '점', '손 x_n[m]', '손 y_n[m]', '손 z_n[m]', '차[m]');
    for k = 1:size(lla,1)
        fprintf('  %4d  %12.4f %12.4f %10.4f  %12.3e\n', ...
                k, hand(k,1), hand(k,2), hand(k,3), norm(hand(k,:) - ml(k,:)));
    end
    fprintf('  최대 차 = %.3e m  -> 같은 식임이 확인됐다\n', max(vecnorm(hand - ml, 2, 2)));

    fprintf('\n[직접 해 볼 것]\n');
    fprintf('  1. R 의 3 행에 -1 을 곱하면 무엇이 되는가 (답: ENU 의 Up)\n');
    fprintf('  2. 같은 점을 ''flat'' 으로도 바꿔 z_n 을 비교할 것 — 차가 곧 곡률이다\n');

    fprintf('\n=== 예제 6 끝 ===\n');
end

% ---------------------------------------------------------------------
function r = local_lla2ecef(lla)
%  예제 2 와 같은 식. 툴박스에 기대지 않으려고 여기에 다시 적는다
    a = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;

    lat = lla(:,1);  lon = lla(:,2);  h = lla(:,3);
    R_N = a ./ sqrt(1 - e2*sind(lat).^2);

    r = [ (R_N + h) .* cosd(lat) .* cosd(lon), ...
          (R_N + h) .* cosd(lat) .* sind(lon), ...
          (R_N*(1 - e2) + h) .* sind(lat) ];
end
