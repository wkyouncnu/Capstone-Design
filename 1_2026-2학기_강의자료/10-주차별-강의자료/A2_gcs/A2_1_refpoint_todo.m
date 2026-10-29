% A2_1_REFPOINT_TODO  1단 — 기준점 하나와 좌표 변환의 왕복 (학생용)
%
%   TODO 세 군데를 채우면 완성본과 같은 출력이 나온다.
%   막히면 A2_1_refpoint_done.m 과 비교할 것. 먼저 열어 보지 말 것
%
%   >> A2_1_refpoint_todo

A2_setup;

fprintf('\n=== 1단 · 기준점과 좌표 변환 ===\n\n');
fprintf('기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);

%% 1. 축척 — 1e-5 도가 몇 m 인가
% TODO 1 ------------------------------------------------------------
%   기준점에서 위도와 경도를 각각 1e-5 도만 올린 점의 NED 좌표를 구할 것
%   힌트 : lla2ned(lla, lla0, 'flat') / lla 는 [위도 경도 고도]
d = [];                                  % <-- 채운다 (1x3)
% -------------------------------------------------------------------
if isempty(d), error('A2:todo', 'TODO 1 을 먼저 채울 것'); end

fprintf('\n[1] 축척\n');
fprintf('  1e-5 deg  = 북 %.4f m / 동 %.4f m\n', d(1), d(2));
fprintf('  위도 1 deg = %.1f m\n', d(1)*1e5);
fprintf('  경도 1 deg = %.1f m\n', d(2)*1e5);

%% 2. 왕복 — 북 300 m / 동 200 m 지점
ned_in = [300, 200, 0];
% TODO 2 ------------------------------------------------------------
%   ned_in 을 위경도로 올리고(lla_pt), 다시 NED 로 내릴 것(ned_out)
%   힌트 : ned2lla / lla2ned 를 쓴다. 세 번째 인자는 'flat'
lla_pt  = [];                            % <-- 채운다 (1x3)
ned_out = [];                            % <-- 채운다 (1x3)
% -------------------------------------------------------------------
if isempty(lla_pt) || isempty(ned_out), error('A2:todo', 'TODO 2 를 먼저 채울 것'); end

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
    % TODO 3 --------------------------------------------------------
    %   같은 한 점을 'ellipsoid' 로 올린 뒤 'flat' 으로 내릴 것
    %   힌트 : p = ned2lla([L 0 0], lla0, 'ellipsoid');
    %          nf = lla2ned(p, lla0, 'flat');
    nf = [];                             % <-- 채운다 (1x3)
    % ---------------------------------------------------------------
    if isempty(nf), error('A2:todo', 'TODO 3 을 먼저 채울 것'); end
    gap_h = hypot(nf(1) - L, nf(2));     % 수평 성분의 차
    gap_v = abs(nf(3));                  % 수직 성분 — 어디서 나온 값인지 생각해 볼 것
    fprintf('  %8.0f  %12.4f  %10.1f  %12.4f\n', L, gap_h, gap_h/L*1e6, gap_v);
end

%% 4. 기준점 고도는 수평 좌표를 바꾸는가 — 완성본과 같다
n_alt0  = lla2ned(lla_pt, [lla0(1) lla0(2)   0], 'flat');
n_alt50 = lla2ned(lla_pt, [lla0(1) lla0(2)  50], 'flat');
fprintf('\n[4] 기준점 고도 alt0 의 영향 (''flat'')\n');
fprintf('  수평 차 : N %.3e m  E %.3e m\n', ...
        abs(n_alt0(1)-n_alt50(1)), abs(n_alt0(2)-n_alt50(2)));
fprintf('  수직 차 : %.4f m\n', abs(n_alt0(3)-n_alt50(3)));

fprintf('\n=== 1단 끝 ===\n');
