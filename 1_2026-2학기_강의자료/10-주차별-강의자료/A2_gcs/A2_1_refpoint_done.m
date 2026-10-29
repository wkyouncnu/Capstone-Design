% A2_1_REFPOINT_DONE  1단 — 기준점 하나와 좌표 변환의 왕복 (완성본)
%
%   지도는 아직 띄우지 않는다. 숫자만 본다.
%   확인할 것 네 가지
%     1. 위경도 1e-5 도가 몇 m 인가
%     2. lla2ned -> ned2lla 왕복에서 값이 돌아오는가
%     3. 'flat' 과 'ellipsoid' 가 거리에 따라 얼마나 벌어지는가
%     4. 기준점 고도 alt0 이 수평 좌표를 바꾸는가
%
%   >> A2_1_refpoint_done

A2_setup;

fprintf('\n=== 1단 · 기준점과 좌표 변환 ===\n\n');
fprintf('기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);

%% 1. 축척 — 1e-5 도가 몇 m 인가
d = lla2ned([lla0(1)+1e-5, lla0(2)+1e-5, 0], lla0, 'flat');
fprintf('\n[1] 축척\n');
fprintf('  1e-5 deg  = 북 %.4f m / 동 %.4f m\n', d(1), d(2));
fprintf('  위도 1 deg = %.1f m\n', d(1)*1e5);
fprintf('  경도 1 deg = %.1f m\n', d(2)*1e5);
fprintf('  -> 위도와 경도의 m 환산값이 다르다. 각도를 거리처럼 쓰면 안 되는 이유다\n');

%% 2. 왕복 — 북 300 m / 동 200 m 지점
ned_in  = [300, 200, 0];
lla_pt  = ned2lla(ned_in, lla0, 'flat');
ned_out = lla2ned(lla_pt, lla0, 'flat');

fprintf('\n[2] 왕복\n');
fprintf('  넣은 NED   : N %8.3f  E %8.3f  D %8.3f\n', ned_in);
fprintf('  위경도     : %.7f , %.7f\n', lla_pt(1), lla_pt(2));
fprintf('  돌아온 NED : N %8.3f  E %8.3f  D %8.3f\n', ned_out);
fprintf('  왕복 오차  : %.3e m\n', norm(ned_out - ned_in));

%% 3. 'flat' 과 'ellipsoid' 의 차 — 거리를 늘려 가며
dist_list = [100 300 500 1000 2000 5000];
fprintf('\n[3] 평면 가정의 오차 (북쪽으로만 이동)\n');
fprintf('  %8s  %12s  %10s  %12s\n', ...
        '거리[m]', '수평차[m]', '상대[ppm]', '수직항[m]');
for L = dist_list
    p  = ned2lla([L, 0, 0], lla0, 'ellipsoid');     % 타원체로 올린 점
    nf = lla2ned(p, lla0, 'flat');                  % 같은 점을 평면으로 내린 것
    gap_h = hypot(nf(1) - L, nf(2));                % 수평 성분의 차
    gap_v = abs(nf(3));                             % 수직 성분 (D)
    fprintf('  %8.0f  %12.4f  %10.1f  %12.4f\n', L, gap_h, gap_h/L*1e6, gap_v);
end
fprintf('  -> 수평차는 5 km 에서도 2 cm 수준. 배가 수평으로만 움직이면 문제 없다\n');
fprintf('  -> 수직항은 L^2/(2R) 로 커진다. 지구 곡률 그 자체다\n');
fprintf('     (''ellipsoid'' 의 NED 는 접평면 직교좌표라, 수평으로 L 만큼 가면\n');
fprintf('      고도가 L^2/(2R) 만큼 올라간 점이 된다. 두 방식의 차는 거의 전부 여기다)\n');

%% 4. 기준점 고도는 수평 좌표를 바꾸는가
n_alt0  = lla2ned(lla_pt, [lla0(1) lla0(2)   0], 'flat');
n_alt50 = lla2ned(lla_pt, [lla0(1) lla0(2)  50], 'flat');
fprintf('\n[4] 기준점 고도 alt0 의 영향 (''flat'')\n');
fprintf('  alt0 =  0 : N %.4f  E %.4f  D %.4f\n', n_alt0);
fprintf('  alt0 = 50 : N %.4f  E %.4f  D %.4f\n', n_alt50);
fprintf('  수평 차   : N %.3e m  E %.3e m\n', ...
        abs(n_alt0(1)-n_alt50(1)), abs(n_alt0(2)-n_alt50(2)));
fprintf('  수직 차   : %.4f m\n', abs(n_alt0(3)-n_alt50(3)));
fprintf('  -> 수평은 전혀 바뀌지 않는다. alt0 은 z(Down) 의 기준면일 뿐이다\n');

fprintf('\n=== 1단 끝 ===\n');
