% A2_4_LIVE_DONE  4단 — 클릭한 웨이포인트로 실시간 주행 (완성본)
%
%   흐름
%     1. `A2_live_setup`      5주차 제어 설정 + 기준점 + 클릭한 웨이포인트
%     2. `A2_build_live_model` 5주차 오프라인 모델에서 `A2_live.slx` 를 파생
%     3. 페이싱을 켜고 실행    1 초에 1 초치를 돈다 (실시간)
%     4. 화면을 보면서 기다린다 위성지도 위에 배와 항적, 오른쪽에 헤딩 명령과 실제 헤딩
%     5. 끝나면 측정값을 표로 출력
%
%   먼저 할 것 — 웨이포인트가 없으면 멈춘다
%     >> A2_3_click_done
%   그 다음
%     >> A2_4_live_done

A2_live_setup;
A2_build_live_model;

SAVE_PNG = true;        % 끝난 화면을 img/ 에 저장할 것인가
PACE     = 1;           % 페이싱 배율. 1 = 실시간
                        %   임무가 길면 실시간 주행도 그만큼 오래 걸린다
                        %   (경로 500 m, 1.5 m/s -> 5 분 이상)
                        %   결과만 빨리 보고 싶을 때 8 정도로 올린다.
                        %   올린 만큼 실제로 빨라지는지는 아래 '실효 배' 로 확인한다
m        = 'A2_live';

here = fileparts(mfilename('fullpath'));
load_system(fullfile(here, [m '.slx']));

%% ====================================================================
%  실시간 페이싱 — 시뮬레이션 1 초를 벽시계 1 초에 맞춘다
%    페이싱을 끄면 수백 배 빨리 돌아 화면을 볼 수 없다.
%    GCS 는 실시간으로 보는 것이 목적이므로 1.0 으로 둔다
% =====================================================================
set_param(m, 'EnablePacing', 'on', 'PacingRate', num2str(PACE));

fprintf('\n=== 4단 · 실시간 주행 ===\n');
fprintf('페이싱 %.1f 배 — 예상 소요 시간 %.0f s\n', PACE, L_total/u_ref/PACE);
fprintf('화면이 열릴 때까지 위성 영상을 받아 오는 동안 몇 초 걸린다\n\n');

t_wall = tic;
out    = sim(m);
wall   = toc(t_wall);

%% ====================================================================
%  측정 — 숫자는 전부 실행 결과다
% =====================================================================
t     = out.log_x_n.Time;
xs    = out.log_x_n.Data;
ys    = out.log_y_n.Data;
ye    = out.log_y_e.Data;
gt    = out.log_gate.Data;
ps    = out.log_psi.Data;
pr    = out.log_psi_ref.Data;
us    = out.log_u.Data;

k_end = find(gt < 0.5, 1);
if isempty(k_end)
    k_end    = numel(t);
    t_finish = NaN;
else
    t_finish = t(k_end);
end
k_ss = min(round(20/Ts_ctrl), k_end);       % 초기 수렴 20 초를 뺀 구간의 시작

e_psi = atan2(sin(pr - ps), cos(pr - ps)) * 180/pi;   % 헤딩 오차 [deg], ssa

fprintf('\n[측정]\n');
fprintf('  실행 시간          : 시뮬 %.1f s / 벽시계 %.1f s  -> 실효 %.3f 배\n', ...
        t(end), wall, t(end)/wall);
if isnan(t_finish)
    fprintf('  완주               : 미완주 (gate 가 끝까지 1)\n');
else
    fprintf('  완주 시각          : %.1f s  (최소 소요 %.1f s 의 %.2f 배)\n', ...
            t_finish, L_total/u_ref, t_finish/(L_total/u_ref));
end
fprintf('  평균 |y_e|         : 전 구간 %.3f m / 초기 20 s 제외 %.3f m\n', ...
        mean(abs(ye(1:k_end))), mean(abs(ye(k_ss:k_end))));
fprintf('  최대 |y_e|         : %.3f m\n', max(abs(ye(1:k_end))));
fprintf('  헤딩 오차 RMS      : 전 구간 %.2f deg / 초기 20 s 제외 %.2f deg\n', ...
        rms(e_psi(1:k_end)), rms(e_psi(k_ss:k_end)));
fprintf('  최대 |헤딩 오차|   : %.2f deg\n', max(abs(e_psi(1:k_end))));
fprintf('  평균 속도          : %.3f m/s  (지령 %.2f m/s)\n', ...
        mean(us(k_ss:k_end)), u_ref);

%% 각 웨이포인트에 얼마나 가까이 갔는가 — 수락반경과 비교할 값
fprintf('\n[웨이포인트 최근접 거리]\n');
fprintf('  %3s  %12s  %12s\n', '#', '최근접[m]', '그때[s]');
d_min = zeros(1, n_wp);
for k = 1:n_wp
    d = hypot(xs(1:k_end) - wp_north(k), ys(1:k_end) - wp_east(k));
    [d_min(k), i_min] = min(d);
    fprintf('  %3d  %12.2f  %12.1f\n', k-1, d_min(k), t(i_min));
end
fprintf('  수락반경 R = %g m —  R 보다 큰 점은 지나치지 않고 돌아 나간 것이다\n', R_LOS);

%% ====================================================================
%  화면 저장
% =====================================================================
if SAVE_PNG
    fg = A2_animate_map();                  % 인자 없이 부르면 그림 핸들
    if ~isempty(fg) && isvalid(fg)
        if ~isfolder(fullfile(here, 'img')), mkdir(fullfile(here, 'img')); end
        png = fullfile(here, 'img', 'a2-4-live.png');
        exportgraphics(fg, png, 'Resolution', 110);
        fprintf('\n화면 저장 : %s\n', png);
    end
end

fprintf('\n=== 4단 끝 ===\n');
