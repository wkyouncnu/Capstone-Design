% A2_6_GPS_DONE  6단 — 월드가 보내는 실제 GPS 로 주행한다 (완성본)
%
%   흐름
%     1. `A2_6_gps_setup`       5주차 제어 설정 + 월드 기준점 + 안전 점검
%     2. `A2_build_gps_model`   5주차 VRX 모델에서 `A2_gps.slx` 를 파생
%     3. `A2_6_run`             토픽 확인 -> GPS 한 번 받아 보기 -> RTF 측정 -> 실행
%     4. 측정                   GPS 로 복원한 위치와 지상참값을 숫자로 견준다
%
%   먼저 WSL 에서 VRX 가 떠 있어야 한다. 이미 떠 있으면 다시 띄우지 않는다
%     $ ros2 topic list | grep gps          # 떠 있는지 확인
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
%     >> A2_6_gps_done
%
%   끝나면 반드시
%     $ source ~/vrx_ws/install/setup.bash
%     $ ros2 run vrx_llm_dock cleanup

A2_6_gps_setup;
A2_build_gps_model;

here = fileparts(mfilename('fullpath'));
[out, V] = A2_6_run(T_run);

%% ====================================================================
%  로그 꺼내기
%    log_x_n  · log_y_n     GPS 로 복원한 위치 — **유도·제어가 쓴 값**
%    log_x_true · log_y_true 가제보 지상참값 — 견주기용
% =====================================================================
t  = out.log_x_n.Time;
xg = out.log_x_n.Data;      yg = out.log_y_n.Data;     % GPS
xt = out.log_x_true.Data;   yt = out.log_y_true.Data;  % 참값
ye = out.log_y_e.Data;      gt = out.log_gate.Data;
ps = out.log_psi.Data;      pr = out.log_psi_ref.Data;
us = out.log_u.Data;

%  첫 메시지 전의 샘플은 두 구독이 모두 0 을 낸다. 그 구간을 지표에 넣으면
%  "원점에 있다" 고 읽혀 오차가 수백 m 로 나온다. 둘 다 0 이 아닌 첫 샘플부터 본다
k0 = find(abs(xt) > 1e-9 & abs(xg) > 1e-9, 1);
if isempty(k0), error('A2:nodata', '구독이 끝까지 0 이다 — 토픽이 오지 않았다'); end

k_end = find(gt(k0:end) < 0.5, 1);
if isempty(k_end)
    k_end    = numel(t);
    t_finish = NaN;
else
    k_end    = k0 + k_end - 1;
    t_finish = t(k_end);
end
kk = k0:k_end;                                  % 지표를 보는 구간
k_ss = min(k0 + round(20/Ts_ctrl), k_end);      % 초기 수렴 20 s 제외

e_psi = atan2(sin(pr - ps), cos(pr - ps)) * 180/pi;     % 헤딩 오차 [deg]

%% ====================================================================
%  1. 손으로 한 변환이 모델 안의 변환과 같은가
%     A2_6_run 이 받아 둔 GPS 한 샘플을 1부 예제 5 의 식으로 직접 변환해
%     모델이 낸 값과 견준다. 같아야 한다 — 같은 식이다
% =====================================================================
a  = 6378137;  f = 1/298.257223563;  e2 = 2*f - f^2;
s2 = sind(lla0(1))^2;
R_N = a / sqrt(1 - e2*s2);
R_M = R_N * (1 - e2) / (1 - e2*s2);
hand_n = (V.gps_lat - lla0(1)) / atan2d(1, R_M);
hand_e = (V.gps_lon - lla0(2)) / atan2d(1, R_N*cosd(lla0(1)));

fprintf('\n[1] 변환식 확인 — 1부 예제 5 (A2_ex5_flat_formula) 의 식 그대로\n');
fprintf('  받은 위경도        : %.8f, %.8f\n', V.gps_lat, V.gps_lon);
fprintf('  손으로 변환        : 북 %.4f,  동 %.4f m\n', hand_n, hand_e);
fprintf('  lla2ned(''flat'')   : 북 %.4f,  동 %.4f m\n', V.gps_n, V.gps_e);
fprintf('  차이               : %.2e m,  %.2e m  (같은 식이므로 0 이어야 한다)\n', ...
        abs(hand_n - V.gps_n), abs(hand_e - V.gps_e));

%% ====================================================================
%  2. GPS 로 복원한 위치 대 지상참값 — 6단의 핵심 숫자
%     평균(치우침)과 흔들림을 따로 본다. 치우침은 센서가 뱃머리 쪽에
%     달려 있기 때문이고, 흔들림은 변환식과 수신 지연 때문이다
% =====================================================================
dn = xg(kk) - xt(kk);       % 북 오차
de = yg(kk) - yt(kk);       % 동 오차
dr = hypot(dn, de);

fprintf('\n[2] GPS 복원 위치 대 지상참값 (%d 샘플, %.1f ~ %.1f s)\n', ...
        numel(kk), t(k0), t(k_end));
fprintf('  %-10s %10s %10s %10s %10s\n', '', '평균', '절대 평균', '최대', '표준편차');
fprintf('  %-10s %10.3f %10.3f %10.3f %10.3f\n', '북 [m]', ...
        mean(dn), mean(abs(dn)), max(abs(dn)), std(dn));
fprintf('  %-10s %10.3f %10.3f %10.3f %10.3f\n', '동 [m]', ...
        mean(de), mean(abs(de)), max(abs(de)), std(de));
fprintf('  %-10s %10s %10.3f %10.3f %10.3f\n', '거리 [m]', '-', ...
        mean(dr), max(dr), std(dr));
fprintf('  치우침을 뺀 뒤의 흔들림 (RMS) : 북 %.3f m, 동 %.3f m\n', ...
        rms(dn - mean(dn)), rms(de - mean(de)));

%  --- 같은 오차를 선체 좌표로 돌려 본다 -------------------------------
%  북·동으로 보면 치우침이 작아 보인다. 배가 돌면 치우침도 같이 돌아
%  평균에서 서로 지워지기 때문이다. 오차의 원인이 선체에 붙어 있다면
%  선체 좌표에서 봐야 보인다
fore = dn.*cos(ps(kk)) + de.*sin(ps(kk));       % 앞이 +
stbd = -dn.*sin(ps(kk)) + de.*cos(ps(kk));      % 오른쪽이 +
fprintf('\n  같은 오차를 선체 좌표로 (psi 로 회전)\n');
fprintf('  %-12s %10s %10s\n', '', '평균', '흔들림 RMS');
fprintf('  %-12s %10.3f %10.3f\n', '앞-뒤 [m]', mean(fore), rms(fore - mean(fore)));
fprintf('  %-12s %10.3f %10.3f\n', '좌-우 [m]', mean(stbd), rms(stbd - mean(stbd)));
fprintf('  앞-뒤 평균이 음수다 = GPS 가 선체 중심보다 **뒤**에 있다.\n');
fprintf('  wamv/gps_wamv_joint 의 xyz = "-0.85 0 1.3" (m, 선체 좌표) —\n');
fprintf('  x 가 -0.85 이므로 중심보다 0.85 m 뒤, 1.3 m 위다.\n');
fprintf('  그래서 평균 오차가 0 이 아닌 것이 정상이다. 변환식의 잘못이 아니다\n');
fprintf('  (고도로 복원한 z_n 평균 %.3f m — 아래가 + 이므로 안테나가 수면 위 %.2f m)\n', ...
        mean(out.log_z_n.Data(kk)), -mean(out.log_z_n.Data(kk)));

%% ====================================================================
%  3. 주행 품질 — 5주차와 같은 형식
% =====================================================================
fprintf('\n[3] 주행\n');
fprintf('  실행 시간          : 시뮬 %.1f s / 벽시계 %.1f s  -> 실효 %.3f 배 (RTF %.3f)\n', ...
        t(end), V.wall, t(end)/V.wall, V.RTF);
if isnan(t_finish)
    fprintf('  완주               : 미완주 (gate 가 끝까지 1)\n');
else
    fprintf('  완주 시각          : %.1f s  (최소 소요 %.1f s 의 %.2f 배)\n', ...
            t_finish, L_total/u_ref, t_finish/(L_total/u_ref));
end
fprintf('  평균 |y_e|         : 전 구간 %.3f m / 초기 20 s 제외 %.3f m\n', ...
        mean(abs(ye(kk))), mean(abs(ye(k_ss:k_end))));
fprintf('  최대 |y_e|         : %.3f m\n', max(abs(ye(kk))));
fprintf('  헤딩 오차 RMS      : 전 구간 %.2f deg / 초기 20 s 제외 %.2f deg\n', ...
        rms(e_psi(kk)), rms(e_psi(k_ss:k_end)));
fprintf('  평균 속도          : %.3f m/s  (지령 %.2f m/s)\n', ...
        mean(us(k_ss:k_end)), u_ref);

%  동기 점검 — Simulink 가 VRX 를 따라갔는가 (참값으로 잰다)
s_path = sum(hypot(diff(xt(kk)), diff(yt(kk))));
s_int  = trapz(t(kk), abs(us(kk)));
k_sync = s_path / max(s_int, eps);
fprintf('  동기 점검 k        : 지나간 거리 %.1f m / 속도 적분 %.1f m = %.3f', ...
        s_path, s_int, k_sync);
if k_sync > 1.08
    fprintf('  <- Simulink 가 VRX 를 못 따라갔다. 이 결과는 쓰지 말 것\n');
elseif k_sync < 0.9
    fprintf('  <- 명령만큼 배가 가지 않았다 (Gazebo 가 멈춤). 이 결과는 쓰지 말 것\n');
else
    fprintf('  (0.9 ~ 1.08 — 정상)\n');
end

%% ====================================================================
%  4. 웨이포인트를 실제로 지났는가
%     통과 판정은 거리로 하지 않는다. 5주차 유도가 쓰는 전환 조건은
%     **경로 방향**으로 남은 거리다 (d - x_e < R) — 목표를 정면으로 찍기
%     전에, 그 점을 지나치는 순간 다음 구간으로 넘어간다. 그래서 최근접
%     거리가 R 보다 조금 클 수 있다. 실제로 넘어갔는지는 wp_idx 가 말해 준다
% =====================================================================
wi = out.log_wp_idx.Data;
fprintf('\n[4] 웨이포인트 통과 (수락반경 R = %g m, 전환 조건 d - x_e < R)\n', R_LOS);
fprintf('  %3s  %10s  %10s  %10s  %8s  %10s\n', ...
        '#', 'GPS[m]', '참값[m]', '최근접[s]', '통과', '전환[s]');
for k = 1:n_wp
    dg = hypot(xg(kk) - wp_north(k), yg(kk) - wp_east(k));
    dt = hypot(xt(kk) - wp_north(k), yt(kk) - wp_east(k));
    [dg_min, i_min] = min(dg);
    if k == 1
        pass = '출발';   t_sw = NaN;
    else
        i_sw = find(wi(kk) >= k, 1);        % wp_idx 가 k 가 된 순간 = k 번 수락
        if isempty(i_sw), pass = 'X';  t_sw = NaN;
        else,             pass = 'O';  t_sw = t(kk(i_sw));
        end
    end
    fprintf('  %3d  %10.2f  %10.2f  %10.1f  %8s  %10.1f\n', ...
            k-1, dg_min, min(dt), t(kk(i_min)), pass, t_sw);
end
fprintf('  0 번은 출발점이다 — 배가 그 자리에서 떠나므로 0 에 가깝게 나온다\n');
fprintf('  전환 시각이 최근접 시각보다 **이르다** — 경로 방향 판정이기 때문이다\n');

%% ====================================================================
%  5. 화면 저장 + GPS 대 참값 겹쳐 그리기
% =====================================================================
if ~isfolder(fullfile(here, 'img')), mkdir(fullfile(here, 'img')); end

fg = A2_animate_map();                  % 인자 없이 부르면 그림 핸들
if ~isempty(fg) && isvalid(fg)
    exportgraphics(fg, fullfile(here, 'img', 'a2-6-gps-live.png'), 'Resolution', 110);
    fprintf('\n화면 저장 : img/a2-6-gps-live.png\n');
end

f2 = figure('Name', '6단 — GPS 대 지상참값', 'Color', 'w', ...
            'Position', [80 80 1020 440]);
subplot(1,2,1);
plot(wp_east, wp_north, 'ks--', 'MarkerFaceColor', 'w', 'LineWidth', 1.0); hold on;
plot(yt(kk), xt(kk), 'b-', 'LineWidth', 1.6);
plot(yg(kk), xg(kk), 'r-', 'LineWidth', 1.2);
plot(yg(k0), xg(k0), 'ko', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({'웨이포인트', '지상참값', 'GPS 복원', '출발'}, 'Location', 'best');
title(sprintf('궤적 — 평균 이격 %.2f m', mean(dr)));

subplot(1,2,2);
plot(t(kk), dn, 'LineWidth', 1.3); hold on;
plot(t(kk), de, 'LineWidth', 1.3);
yline(mean(dn), '--');  yline(mean(de), ':');
grid on; xlabel('시간 [s]'); ylabel('GPS - 참값 [m]');
legend({'북', '동', '북 평균', '동 평균'}, 'Location', 'best');
title(sprintf('성분별 오차 (북 평균 %.3f, 동 평균 %.3f m)', mean(dn), mean(de)));
exportgraphics(f2, fullfile(here, 'img', 'a2-6-gps-vs-truth.png'), 'Resolution', 130);
fprintf('그림 저장 : img/a2-6-gps-vs-truth.png\n');

fprintf('\n=== 6단 끝 — WSL 에서 정리를 잊지 말 것 ===\n');
fprintf('    $ source ~/vrx_ws/install/setup.bash\n');
fprintf('    $ ros2 run vrx_llm_dock cleanup\n');
fprintf('  첫 줄을 빼면 Package ''vrx_llm_dock'' not found 가 난다\n');
