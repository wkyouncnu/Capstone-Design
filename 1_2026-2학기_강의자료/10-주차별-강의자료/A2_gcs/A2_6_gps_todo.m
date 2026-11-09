% A2_6_GPS_TODO  6단 — 월드가 보내는 실제 GPS 로 주행한다 (학생용)
%
%   TODO 세 군데를 채우면 완성본과 같은 출력이 나온다.
%   막히면 A2_6_gps_done.m 과 비교할 것. 먼저 열어 보지 말 것
%
%   먼저 WSL 에서 VRX 가 떠 있어야 한다. 이미 떠 있으면 다시 띄우지 않는다
%     $ ros2 topic list | grep gps
%   없으면 — 3주차에 만든 띄우기 스크립트를 쓴다 (5주차와 같은 방법)
%     $ cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite
%     $ bash run_vrx.sh
%   이 스크립트가 실제로 거는 명령은 한 줄이다
%     ros2 launch vrx_gz competition.launch.py world:=sydney_regatta \
%       urdf:=<...>/W03_vrx_lite/wamv_lite.urdf "extra_gz_args:=--render-engine-gui ogre"
%   wamv_lite.urdf 에 GPS (navsat, 20 Hz) 와 지상참값 (OdometryPublisher, 10 Hz) 이
%   모두 들어 있다 — 6단에서 따로 켤 것이 없다
%
%   그 다음
%     >> A2_6_gps_todo
%
%   끝나면 반드시
%     $ ros2 run vrx_llm_dock cleanup

A2_6_gps_setup;
A2_build_gps_model;

here = fileparts(mfilename('fullpath'));
[out, V] = A2_6_run(T_run);

%% 로그 꺼내기
t  = out.log_x_n.Time;
xg = out.log_x_n.Data;      yg = out.log_y_n.Data;     % GPS 로 복원한 위치
xt = out.log_x_true.Data;   yt = out.log_y_true.Data;  % 가제보 지상참값
ye = out.log_y_e.Data;      gt = out.log_gate.Data;
ps = out.log_psi.Data;      pr = out.log_psi_ref.Data;
us = out.log_u.Data;

%  첫 메시지 전의 샘플은 두 구독이 모두 0 을 낸다 — 지표에서 뺀다
k0 = find(abs(xt) > 1e-9 & abs(xg) > 1e-9, 1);
if isempty(k0), error('A2:nodata', '구독이 끝까지 0 이다 — 토픽이 오지 않았다'); end

k_end = find(gt(k0:end) < 0.5, 1);
if isempty(k_end), k_end = numel(t);  t_finish = NaN;
else,              k_end = k0 + k_end - 1;  t_finish = t(k_end);
end
kk   = k0:k_end;
k_ss = min(k0 + round(20/Ts_ctrl), k_end);

e_psi = atan2(sin(pr - ps), cos(pr - ps)) * 180/pi;

%% 1. 받은 위경도를 손으로 변환해 본다
% TODO 1 ----------------------------------------------------------------
%   A2_6_run 이 받아 둔 GPS 한 샘플 (V.gps_lat, V.gps_lon) 을 기준점 lla0
%   기준 평면좌표로 바꿀 것. 1부 예제 5 (A2_ex5_flat_formula.m) 의 식이다
%
%   순서
%     1) 곡률반경 두 개를 기준점 **위도에서 한 번** 구한다
%          R_N = a / sqrt(1 - e2*sind(lat0)^2)            % 묘유선 (동-서)
%          R_M = R_N*(1 - e2) / (1 - e2*sind(lat0)^2)     % 자오선 (남-북)
%     2) 각도 차를 그 곡률반경으로 나눈다
%          북 = (lat - lat0) / atan2d(1, R_M)
%          동 = (lon - lon0) / atan2d(1, R_N*cosd(lat0))
%   왜 atan2d(1, R) 인가 : "1 m 가 몇 도인가" 다. 거리를 도로 나누면 m 이 된다
a  = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;
R_N = [];       % <-- 채운다
R_M = [];       % <-- 채운다
hand_n = [];    % <-- 채운다 (북 [m])
hand_e = [];    % <-- 채운다 (동 [m])
% -----------------------------------------------------------------------
if isempty(hand_n) || isempty(hand_e)
    error('A2:todo', 'TODO 1 을 먼저 채울 것');
end

fprintf('\n[1] 변환식 확인\n');
fprintf('  받은 위경도      : %.8f, %.8f\n', V.gps_lat, V.gps_lon);
fprintf('  손으로 변환      : 북 %.4f,  동 %.4f m\n', hand_n, hand_e);
fprintf('  lla2ned(''flat'') : 북 %.4f,  동 %.4f m\n', V.gps_n, V.gps_e);
fprintf('  차이             : %.2e m,  %.2e m  (같은 식이므로 0 이어야 한다)\n', ...
        abs(hand_n - V.gps_n), abs(hand_e - V.gps_e));

%% 2. GPS 로 복원한 위치는 참값과 얼마나 다른가
% TODO 2 ----------------------------------------------------------------
%   성분별로 오차를 구할 것. 거리 하나로 합치면 "어느 쪽으로 치우쳤는가" 가
%   사라진다 — 6단에서 보려는 것이 바로 그 치우침이다
%     dn : 북 오차 = GPS 북 - 참값 북   (구간 kk 만)
%     de : 동 오차 = GPS 동 - 참값 동
dn = [];        % <-- 채운다
de = [];        % <-- 채운다
% -----------------------------------------------------------------------
if isempty(dn) || isempty(de), error('A2:todo', 'TODO 2 를 먼저 채울 것'); end
dr = hypot(dn, de);

fprintf('\n[2] GPS 복원 위치 대 지상참값 (%d 샘플)\n', numel(kk));
fprintf('  %-10s %10s %10s %10s %10s\n', '', '평균', '절대 평균', '최대', '표준편차');
fprintf('  %-10s %10.3f %10.3f %10.3f %10.3f\n', '북 [m]', ...
        mean(dn), mean(abs(dn)), max(abs(dn)), std(dn));
fprintf('  %-10s %10.3f %10.3f %10.3f %10.3f\n', '동 [m]', ...
        mean(de), mean(abs(de)), max(abs(de)), std(de));
fprintf('  %-10s %10s %10.3f %10.3f %10.3f\n', '거리 [m]', '-', ...
        mean(dr), max(dr), std(dr));
fprintf('\n  생각해 볼 것 1 — 평균이 0 이 아니다. 변환식이 틀린 것인가?\n');
fprintf('  WSL 에서 지금 띄운 모델 파일을 열어 GPS 가 선체 어디에 달려 있는지 볼 것\n');
fprintf('    W03_vrx_lite/wamv_lite.urdf 의 550 행  wamv/gps_wamv_joint\n');
fprintf('    $ grep -n -A4 gps_wamv_joint W03_vrx_lite/wamv_lite.urdf\n');
fprintf('  생각해 볼 것 2 — 북·동으로 본 치우침은 선체 좌표로 돌려 본 것보다\n');
fprintf('  작다. 배가 돌면 치우침도 같이 돌아 평균에서 지워지기 때문이다.\n');
fprintf('  아래 두 줄로 직접 확인할 것 (psi 로 회전한다)\n');
fprintf('    fore = dn.*cos(ps(kk)) + de.*sin(ps(kk));   %% 앞이 +\n');
fprintf('    stbd = -dn.*sin(ps(kk)) + de.*cos(ps(kk));  %% 오른쪽이 +\n');

%% 3. 주행
fprintf('\n[3] 주행\n');
fprintf('  실행 시간        : 시뮬 %.1f s / 벽시계 %.1f s  (RTF %.3f)\n', ...
        t(end), V.wall, V.RTF);
if isnan(t_finish)
    fprintf('  완주             : 미완주 (gate 가 끝까지 1)\n');
else
    fprintf('  완주 시각        : %.1f s  (최소 소요 %.1f s 의 %.2f 배)\n', ...
            t_finish, L_total/u_ref, t_finish/(L_total/u_ref));
end
fprintf('  평균 |y_e|       : 전 구간 %.3f m / 초기 20 s 제외 %.3f m\n', ...
        mean(abs(ye(kk))), mean(abs(ye(k_ss:k_end))));
fprintf('  헤딩 오차 RMS    : %.2f deg\n', rms(e_psi(k_ss:k_end)));
fprintf('  평균 속도        : %.3f m/s  (지령 %.2f m/s)\n', ...
        mean(us(k_ss:k_end)), u_ref);

%% 4. 웨이포인트를 실제로 지났는가
%   통과 판정을 거리로 하지 않는 까닭 — 5주차 유도의 전환 조건은 경로 방향으로
%   남은 거리다 (d - x_e < R). 목표를 정면으로 찍기 전에 넘어가므로 최근접
%   거리가 R 보다 조금 클 수 있다. 실제로 넘어갔는지는 wp_idx 가 말해 준다
wi = out.log_wp_idx.Data;
fprintf('\n[4] 웨이포인트 통과 (수락반경 R = %g m, 전환 조건 d - x_e < R)\n', R_LOS);
fprintf('  %3s  %10s  %10s  %8s  %10s\n', '#', 'GPS[m]', '최근접[s]', '통과', '전환[s]');
for k = 1:n_wp
    % TODO 3 ------------------------------------------------------------
    %   k 번 웨이포인트까지의 거리를 구간 kk 전체에 대해 구할 것.
    %   유도가 본 위치는 GPS 다 — 최근접 거리도 GPS 로 잰다
    %   힌트 : hypot(xg(kk) - wp_north(k), ...)
    dg = [];                             % <-- 채운다
    % -------------------------------------------------------------------
    if isempty(dg), error('A2:todo', 'TODO 3 을 먼저 채울 것'); end
    [dg_min, i_min] = min(dg);
    if k == 1
        pass = '출발';  t_sw = NaN;
    else
        i_sw = find(wi(kk) >= k, 1);
        if isempty(i_sw), pass = 'X';  t_sw = NaN;
        else,             pass = 'O';  t_sw = t(kk(i_sw));
        end
    end
    fprintf('  %3d  %10.2f  %10.1f  %8s  %10.1f\n', ...
            k-1, dg_min, t(kk(i_min)), pass, t_sw);
end

fprintf('\n=== 6단 끝 — WSL 에서  ros2 run vrx_llm_dock cleanup  을 잊지 말 것 ===\n');
