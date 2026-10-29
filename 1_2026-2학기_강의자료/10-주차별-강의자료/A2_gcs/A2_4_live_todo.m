% A2_4_LIVE_TODO  4단 — 클릭한 웨이포인트로 실시간 주행 (학생용)
%
%   TODO 세 군데를 채우면 완성본과 같은 출력이 나온다.
%   막히면 A2_4_live_done.m 과 비교할 것. 먼저 열어 보지 말 것
%
%   먼저 할 것 — 웨이포인트가 없으면 멈춘다
%     >> A2_3_click_done
%   그 다음
%     >> A2_4_live_todo

A2_live_setup;
A2_build_live_model;

m    = 'A2_live';
here = fileparts(mfilename('fullpath'));
load_system(fullfile(here, [m '.slx']));

%% 1. 실시간 페이싱
% TODO 1 ----------------------------------------------------------------
%   시뮬레이션 1 초를 벽시계 1 초에 맞출 것 (실시간)
%   힌트 : set_param(m, 'EnablePacing', ..., 'PacingRate', ...)
%          PacingRate 는 **문자열**로 준다
PACE = 1;
% <-- 여기에 set_param 한 줄을 쓴다
% -----------------------------------------------------------------------
if ~strcmp(get_param(m, 'EnablePacing'), 'on')
    error('A2:todo', 'TODO 1 을 먼저 채울 것 — 페이싱이 꺼져 있다');
end

fprintf('\n=== 4단 · 실시간 주행 ===\n');
fprintf('페이싱 %.1f 배 — 예상 소요 시간 %.0f s\n\n', PACE, L_total/u_ref/PACE);

t_wall = tic;
out    = sim(m);
wall   = toc(t_wall);

%% 2. 측정
t     = out.log_x_n.Time;
xs    = out.log_x_n.Data;      ys = out.log_y_n.Data;
ye    = out.log_y_e.Data;      gt = out.log_gate.Data;
ps    = out.log_psi.Data;      pr = out.log_psi_ref.Data;
us    = out.log_u.Data;

k_end = find(gt < 0.5, 1);
if isempty(k_end), k_end = numel(t);  t_finish = NaN;
else,              t_finish = t(k_end);
end
k_ss = min(round(20/Ts_ctrl), k_end);       % 초기 수렴 20 초를 뺀 구간의 시작

% TODO 2 ----------------------------------------------------------------
%   헤딩 오차를 deg 로 구할 것. 명령 pr 에서 실제 ps 를 뺀 값이다
%   >>> 그냥 (pr - ps) 로 쓰면 안 된다 <<<
%       각은 360 도에서 되감기므로 179 도와 -179 도의 차가 358 도로 나온다
%   힌트 : atan2(sin(a), cos(a)) 가 각을 (-180, 180] 로 접는다
e_psi = [];                              % <-- 채운다 (t 와 같은 길이, 단위 deg)
% -----------------------------------------------------------------------
if isempty(e_psi), error('A2:todo', 'TODO 2 를 먼저 채울 것'); end

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
fprintf('  평균 속도          : %.3f m/s  (지령 %.2f m/s)\n', ...
        mean(us(k_ss:k_end)), u_ref);

%% 3. 각 웨이포인트에 얼마나 가까이 갔는가
fprintf('\n[웨이포인트 최근접 거리]\n');
fprintf('  %3s  %12s  %12s\n', '#', '최근접[m]', '그때[s]');
for k = 1:n_wp
    % TODO 3 ------------------------------------------------------------
    %   k 번 웨이포인트까지의 거리를 전 구간에 대해 구하고 최솟값을 찾을 것
    %   힌트 : hypot(xs(1:k_end) - wp_north(k), ...)
    d = [];                              % <-- 채운다 (k_end x 1)
    % -------------------------------------------------------------------
    if isempty(d), error('A2:todo', 'TODO 3 을 먼저 채울 것'); end
    [d_min, i_min] = min(d);
    fprintf('  %3d  %12.2f  %12.1f\n', k-1, d_min, t(i_min));
end
fprintf('  수락반경 R = %g m\n', R_LOS);

fprintf('\n=== 4단 끝 ===\n');
