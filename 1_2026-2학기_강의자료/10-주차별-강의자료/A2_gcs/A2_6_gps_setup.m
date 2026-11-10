% A2_6_GPS_SETUP  6단 설정 — 가제보 월드가 보내는 **실제 GPS** 로 주행한다
%
%   1~5단은 위경도를 사람이 지도에서 클릭해 만들었다. 6단은 그 위경도를
%   **센서가 보내 준다**. 1부에서 손으로 유도한 변환식이 그때 비로소 배의
%   제어 입력이 된다.
%
%   >> A2_6_gps_setup
%
%   네 묶음을 한자리에 모은다 (4단 A2_live_setup 과 같은 순서)
%     1. 제어·플랜트 설정 : `W05_setup.m` 을 그대로 실행한다
%     2. 지리 설정        : `A2_setup.m` 뒤에 기준점만 월드 값으로 바꾼다
%     3. 임무             : 안전 수역 안에서 미리 고른 웨이포인트 세 개
%     4. 안전 점검        : 고정 물체·수역 경계까지의 여유를 숫자로 찍는다
%
%   왜 클릭이 아니라 미리 고른 점인가
%     가제보 월드의 해안선은 위성지도에서 눈으로 가리기 어렵다. 육지에 얹히면
%     실습이 거기서 끝나므로, 5주차에서 주행으로 확인된 안전 수역 안에서
%     고른 점을 쓴다. 클릭으로 바꾸고 싶으면 아래 wp_north·wp_east 를
%     A2_3_click_done 의 결과로 갈아 끼우면 된다 — 4단과 같은 방식이다

clear;  clc;

here = fileparts(mfilename('fullpath'));
w05  = fullfile(fileparts(here), 'W05_simulink');
if ~isfolder(w05)
    error('A2:now05', '5주차 폴더를 찾지 못했다 : %s', w05);
end
addpath(here);   addpath(w05);

%% ====================================================================
%  1. 제어·플랜트 설정 — 5주차 것을 그대로
%     게인 하나 베껴 적지 않는다. 6단에서 바뀌는 것은
%     **위치를 어디서 받는가** 한 가지뿐이다
% =====================================================================
fprintf('\n[1] 5주차 제어 설정을 가져온다 — %s\n', fullfile(w05, 'W05_setup.m'));
setappdata(0, 'W05_skip_run', true);
run(fullfile(w05, 'W05_setup.m'));

%% ====================================================================
%  2. 지리 설정 — 기준점을 **월드의 기준점**으로 바꾼다
% =====================================================================
setappdata(0, 'A2_keep_vars', true);    % A2_setup 의 clear 를 막는다
setappdata(0, 'A2_skip_clc',  true);
A2_setup;
setappdata(0, 'A2_keep_vars', false);

%  --- 월드가 선언한 기준점 ------------------------------------------
%  가제보 월드 파일이 "이 월드의 (0,0,0) 은 지구 어디인가" 를 직접 적어 둔다.
%    ~/vrx_ws/src/vrx/vrx_gz/worlds/sydney_regatta.sdf : 321~328 행
%      <spherical_coordinates>
%        <surface_model>EARTH_WGS84</surface_model>
%        <world_frame_orientation>ENU</world_frame_orientation>
%        <latitude_deg>-33.724223</latitude_deg>
%        <longitude_deg>150.679736</longitude_deg>
%        <elevation>0.0</elevation>
%        <heading_deg>0</heading_deg>
%      </spherical_coordinates>
%  GPS 플러그인은 이 값을 원점으로 삼아 위경도를 만든다. 그러므로 이 값이
%  곧 "추측하지 않아도 되는" 기준점이다 — A2_1 에서 손으로 찍던 그 자리
lla0_world = [-33.724223  150.679736  0];

%  --- 실습이 쓰는 기준점 = 경로 원점 --------------------------------
%  월드 기준점을 그대로 쓰면 배가 (북 200, 동 -532) 쯤에 있게 된다. 숫자가
%  커지면 읽기 어렵고, 5주차 웨이포인트(경로 원점 기준)와 단위가 달라진다.
%  그래서 5주차가 월드에 고정해 둔 경로 원점 (path_north0, path_east0) 의
%  위경도를 한 번 구해 그것을 기준점으로 삼는다. 이렇게 하면
%    - GPS 가 준 위경도 -> 이 기준점 기준 평면좌표 = 5주차와 **같은 좌표계**
%    - 유도·제어·추진기 블록은 한 군데도 바뀌지 않는다
lla0 = ned2lla([path_north0 path_east0 0], lla0_world, 'flat');

%  토픽 — 터미널에서 이름을 직접 확인한 값이다 (MD 2-7 절)
gps_topic   = '/wamv/sensors/gps/gps/fix';
truth_topic = '/wamv/sensors/position/ground_truth_odometry';

%% ====================================================================
%  3. 임무 — 안전 수역 안의 웨이포인트
%     좌표는 경로 원점 기준 [북, 동] — 5주차와 같은 뜻이다
% =====================================================================
wp_north = [0   30   30   -5];
wp_east  = [0   15   60   35];
n_wp     = numel(wp_north);
wp_lla   = ned2lla([wp_north(:) wp_east(:) zeros(n_wp,1)], lla0, 'flat');

%  초기 헤딩 — 1번 목표를 향해. VRX 에서는 가제보가 정하므로 이 값은
%  오프라인 대조와 실시간 창의 첫 그림에만 쓰인다
psi_init = atan2(wp_east(2) - wp_east(1), wp_north(2) - wp_north(1));
x0       = [0.1; 0; 0; 0; 0; psi_init];     % [u v r N E psi]'

leg_len = hypot(diff(wp_north), diff(wp_east));
L_total = sum(leg_len);
T_run   = max(60, ceil(2.0*L_total/u_ref + 60));

%  실시간 화면 — 4단 것을 그대로 쓴다 (A2_animate_map). 창 제목도 4단으로
%  나온다. 바뀐 자리를 한 군데(위치를 받는 곳)로 좁히는 것이 더 중요하다
animate       = 1;

%  실시간 창을 다시 그리는 간격 [s] — 이 값이 동기 점검 k 를 좌우한다
%  (2026-11-10 실측). 한 번 다시 그리는 데 약 24 ms 가 든다. 걸음은 0.05 s
%  이므로 0.5 s 간격이면 걸음마다 약 2.4 ms, 1.0 s 간격이면 약 1.2 ms 가
%  얹힌다. 페이싱(EnablePacing)은 모델을 **늦출 수만** 있으므로 이 얹힘은
%  지워지지 않고 그대로 가제보와의 시계 차이가 된다.
%    0.5 -> k 1.10~1.12 (판정 밖),  1.0 -> k 1.02~1.03,  2.0 -> k 1.018
%  장비가 느려 k 가 1.08 을 넘으면 이 값을 2.0 까지 올린다 (그림만 뜸해진다)
animate_every = 1.0;
boat_scale    = 6;
map_span_m    = max(60, ceil(max(abs([wp_north wp_east])) + 40));

%% ====================================================================
%  4. 확인 출력
% =====================================================================
fprintf('\n[2] 기준점\n');
fprintf('  월드 선언값 (sydney_regatta.sdf:321-328)\n');
fprintf('    lat0 = %.6f,  lon0 = %.6f,  elev = %.1f m,  ENU, heading 0\n', lla0_world);
fprintf('  경로 원점 (북 %g, 동 %g) 의 위경도 = 이 실습의 기준점\n', ...
        path_north0, path_east0);
fprintf('    lla0 = [%.7f  %.7f  %.1f]\n', lla0);

fprintf('\n[3] 임무 — 웨이포인트 %d 개 (0 번은 출발점)\n', n_wp);
fprintf('  %3s  %12s  %13s  %9s  %9s  %9s\n', ...
        '#', '위도', '경도', 'N[m]', 'E[m]', '구간[m]');
for k = 1:n_wp
    if k == 1
        fprintf('  %3d  %12.7f  %13.7f  %9.2f  %9.2f  %9s   <- 출발점\n', ...
                k-1, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k), '-');
    else
        fprintf('  %3d  %12.7f  %13.7f  %9.2f  %9.2f  %9.2f\n', ...
                k-1, wp_lla(k,1), wp_lla(k,2), wp_north(k), wp_east(k), leg_len(k-1));
    end
end
fprintf('\n  총 경로 길이 = %.2f m,  u_ref = %.2f m/s -> 최소 소요 %.1f s\n', ...
        L_total, u_ref, L_total/u_ref);
fprintf('  T_run = %d s (보험 — AutoStop 이 먼저 걸린다),  R_LOS = %g m,  Delta = %g m\n', ...
        T_run, R_LOS, Delta);

%% ====================================================================
%  5. 안전 점검 — 육지에 닿지 않는가
%     고정 물체의 자리는 추측하지 않는다. 월드가 돌고 있을 때
%       $ gz model -m post_0
%     로 읽은 값이다 (월드 ENU). 경로 원점 기준으로 내려 적는다
% =====================================================================
%          이름                ENU x(동)   ENU y(북)
obs = { '부이 6개 중 최북',    -528.000,   191.000
        '부이 6개 중 최남',    -528.000,   186.000
        'post_0',              -535.917,   154.363
        'post_1',              -527.490,   153.855
        'post_2',              -544.833,   156.672
        'antenna',             -531.064,   147.669
        'ground_station_0',    -540.796,   146.494
        'ground_station_1',    -537.623,   145.828
        'ground_station_2',    -534.551,   144.910 };

on = cell2mat(obs(:,3)) - path_north0;      % 북
oe = cell2mat(obs(:,2)) - path_east0;       % 동

%  5주차가 주행으로 확인한 안전 수역 (W05_setup.m:25-27)
box_n = [-28 60];   box_e = [-18 100];

fprintf('\n[4] 안전 점검 — 안전 수역 N [%g %g], E [%g %g] (W05_setup.m:25-27)\n', ...
        box_n, box_e);
fprintf('  %3s  %8s  %8s  %13s  %10s  %s\n', ...
        '#', 'N[m]', 'E[m]', '수역경계[m]', '물체[m]', '가장 가까운 고정 물체');
ok = true;
for k = 1:n_wp
    d_box = min([wp_north(k)-box_n(1), box_n(2)-wp_north(k), ...
                 wp_east(k)-box_e(1),  box_e(2)-wp_east(k)]);
    d_obs = hypot(on - wp_north(k), oe - wp_east(k));
    [d_min, i_min] = min(d_obs);
    fprintf('  %3d  %8.2f  %8.2f  %13.2f  %10.2f  %s\n', ...
            k-1, wp_north(k), wp_east(k), d_box, d_min, obs{i_min,1});
    if d_box < 0, ok = false; end
end

%  구간(선분)까지의 여유도 본다 — 점만 보면 중간에 스치는 것을 놓친다
fprintf('\n  구간별 고정 물체 최소 여유\n');
for k = 1:n_wp-1
    p1 = [wp_north(k)   wp_east(k)];
    p2 = [wp_north(k+1) wp_east(k+1)];
    v  = p2 - p1;   Lk = norm(v);
    tt = max(0, min(1, ((on-p1(1))*v(1) + (oe-p1(2))*v(2)) / Lk^2));
    dd = hypot(p1(1) + tt*v(1) - on, p1(2) + tt*v(2) - oe);
    [d_min, i_min] = min(dd);
    fprintf('    %d -> %d  : %6.2f m  (%s)\n', k-1, k, d_min, obs{i_min,1});
end
if ~ok
    error('A2:unsafe', '웨이포인트가 안전 수역을 벗어났다');
end
fprintf('\n  0 번은 스폰 자리 자체다 — 부이까지의 거리가 가장 짧게 나오지만\n');
fprintf('  배는 1 번을 향해 북동으로 떠나므로 그 거리는 계속 멀어진다\n');

fprintf('\n[5] 토픽\n');
fprintf('  GPS      : %s  (sensor_msgs/NavSatFix, 약 20 Hz)\n', gps_topic);
fprintf('  지상참값 : %s  (nav_msgs/Odometry, 약 10 Hz)\n', truth_topic);

fprintf('\n6단 설정 완료 — 다음은  >> A2_6_gps_done\n');
