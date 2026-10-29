% A2_LIVE_SETUP  4단 설정 — 세 묶음을 한자리에 모은다
%
%   1. 제어·플랜트 설정 : `W05_setup.m` 을 **그대로 실행**한다
%                         게인을 베껴 적지 않는다. 5주차에서 검증한 값이 곧 여기 값이다
%   2. 지리 설정        : `A2_setup.m` (기준점 lla0, 베이스맵, 저장 파일)
%   3. 임무             : `mission_points.mat` 의 클릭 웨이포인트를 NED 로 내려 덮어쓴다
%
%   >> A2_live_setup
%
%   왜 순서가 이것인가
%     - `W05_setup` 과 `A2_setup` 둘 다 첫머리에서 `clear` 를 한다
%     - 먼저 W05 를 돌려 제어 설정을 깔고, 그 위에 A2 의 지리 설정을 얹는다
%     - 뒤에 오는 `A2_setup` 이 앞의 값을 지우지 않게 `A2_keep_vars` 로 막는다

clear;  clc;

here = fileparts(mfilename('fullpath'));
w05  = fullfile(fileparts(here), 'W05_simulink');
if ~isfolder(w05)
    error('A2:now05', '5주차 폴더를 찾지 못했다 : %s', w05);
end
addpath(here);   addpath(w05);

%% ====================================================================
%  1. 제어·플랜트 설정 — 5주차 것을 그대로
%     W05_setup 은 끝에서 스스로 모델을 돌린다. 아래 한 줄이 그것을 막는다
% =====================================================================
fprintf('\n[1] 5주차 제어 설정을 가져온다 — %s\n', fullfile(w05, 'W05_setup.m'));
setappdata(0, 'W05_skip_run', true);
run(fullfile(w05, 'W05_setup.m'));

%% ====================================================================
%  2. 지리 설정 — 기준점·베이스맵·임무 파일
% =====================================================================
setappdata(0, 'A2_keep_vars', true);    % A2_setup 의 clear 를 막는다
setappdata(0, 'A2_skip_clc',  true);
A2_setup;
setappdata(0, 'A2_keep_vars', false);

%% ====================================================================
%  3. 임무 — 지도에서 클릭한 웨이포인트
% =====================================================================
if ~isfile(mission_file)
    error('A2:nomission', ['웨이포인트 파일이 없다 : %s\n' ...
          '먼저 A2_3_click_done 으로 지도를 클릭할 것'], mission_file);
end
M = load(mission_file, 'wp_lla', 'lla0');

%  저장 당시의 기준점과 지금 기준점이 다르면 경로 전체가 그만큼 밀린다.
%  오류 메시지 없이 틀리는 자리이므로 숫자로 확인한다
d0 = lla2ned(M.lla0, lla0, 'flat');
if norm(d0(1:2)) > 0.01
    warning('A2:refmoved', ...
        '저장 당시 기준점이 현재 기준점과 %.3f m 떨어져 있다 — 경로가 그만큼 밀린다', ...
        norm(d0(1:2)));
end

wp_clicked = lla2ned(M.wp_lla, lla0, 'flat');

%  경로의 첫 점은 **출발점(기준점) 자체**다.
%    5주차 유도부는 "wp(k) -> wp(k+1)" 구간을 따라간다. 클릭한 점만 넣으면
%    1번 점은 지나가는 목표가 아니라 첫 구간의 시작점이 되어 버린다.
%    앞에 (0,0) 을 붙이면 배가 있는 자리에서 경로가 시작하고, 클릭한 점 전부가
%    차례로 지나가는 목표가 된다
wp_north = [0, wp_clicked(:,1).'];
wp_east  = [0, wp_clicked(:,2).'];
n_wp     = numel(wp_north);
wp_lla   = ned2lla([wp_north(:) wp_east(:) zeros(n_wp,1)], lla0, 'flat');

%% ====================================================================
%  4. 임무에 맞춰 다시 계산되는 값
% =====================================================================
%  초기 헤딩 — 1번 목표를 향해 출발한다 (출발점에서 경로가 시작하므로)
psi_init = atan2(wp_east(2) - wp_east(1), wp_north(2) - wp_north(1));
x0       = [0.1; 0; 0; 0; 0; psi_init];     % [u v r N E psi]'

%  실행 길이 — AutoStop 이 먼저 걸린다. 이 값은 그것이 안 걸릴 때의 보험이다
leg_len = hypot(diff(wp_north), diff(wp_east));
L_total = sum(leg_len);
T_run   = max(60, ceil(2.0*L_total/u_ref + 60));

%  지도 범위 — 웨이포인트를 다 담고 여유 40 m
map_span_m = max(60, ceil(max(abs([wp_north wp_east])) + 40));

%  실시간 화면
animate       = 1;
animate_every = 0.2;      % 몇 초마다 다시 그릴 것인가 [시뮬레이션 초]
boat_scale    = 6;        % 지도 위에서는 실제 크기(전장 4.9 m)가 점으로 보인다

%% ====================================================================
%  5. 확인 출력 — 숫자로 본다
% =====================================================================
fprintf('\n[3] 임무 — %s\n', mission_file);
fprintf('  기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);
fprintf('  클릭한 점 %d 개 + 출발점 1 개 = 경로 점 %d 개\n', ...
        size(wp_clicked,1), n_wp);
fprintf('\n  %3s  %12s  %13s  %10s  %10s  %10s\n', ...
        '#', '위도', '경도', 'N[m]', 'E[m]', '구간[m]');
for k = 1:n_wp
    if k == 1
        fprintf('  %3d  %12.7f  %13.7f  %10.2f  %10.2f  %10s   <- 출발점\n', ...
                k-1, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k), '-');
    else
        fprintf('  %3d  %12.7f  %13.7f  %10.2f  %10.2f  %10.2f\n', ...
                k-1, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k), leg_len(k-1));
    end
end
fprintf('\n  총 경로 길이 = %.2f m,  u_ref = %.2f m/s -> 최소 소요 %.1f s\n', ...
        L_total, u_ref, L_total/u_ref);
fprintf('  T_run = %d s (보험),  R_LOS = %g m,  Delta = %g m,  유도 = %s\n', ...
        T_run, R_LOS, Delta, mode_name);
fprintf('  지도 범위 = 기준점 ±%d m,  베이스맵 = %s\n', map_span_m, basemap_name);
fprintf('\n4단 설정 완료\n');
