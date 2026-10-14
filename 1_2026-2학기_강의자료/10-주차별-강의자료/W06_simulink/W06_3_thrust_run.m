% W06_3_THRUST_RUN  3단 — 추진기 동역학을 끼운 모델을 돌리고 결과를 본다
%
%   >> W06_3_thrust_run
%
%   2단까지 힘은 지령하는 순간 그대로 나왔다. 3단에서 그 사이에 추진기가
%   들어간다 — 힘을 회전수로 바꾸고($n = \sqrt{F/k}$), 모터가 시상수
%   tau_n 만큼 늦게 따라오고, 회전수와 추력이 포화된다.
%
%   이 단계에서 봐야 할 것
%     정상상태는 1단과 같고 **과도만 늦어지는가**. 끝 자세는 1단과 같은
%     목표이므로 끝 오차가 1단과 비슷해야 하고, 회전수가 n_max 를 넘지
%     않아야 한다. 넘으면 추력 포화가 아니라 회전수 포화가 먼저 걸린다.
setappdata(0, 'W06_stage', 3);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));

%  회전수가 한계 안에 있는가, 정상상태는 1단과 같은가
n_all = squeeze(out.log_n.Data);
if size(n_all,1) ~= numel(out.log_x_n.Time), n_all = n_all.'; end
fprintf('\n[3단 점검] 끝 오차 %.3f m / %.2f deg,  마지막 10 초 평균 %.3f m / %.2f deg\n', ...
        S.e_final, S.epsi_final, S.e_ss, S.epsi_ss);
fprintf('           최대 |n| %.2f rad/s  (포화 %.2f rad/s),  모터 시상수 %.2f s\n', ...
        max(max(abs(n_all))), n_max, tau_n);
fprintf('           최대 추력 FL %.1f / FR %.1f / FB %.1f N  (한계 %g / %g / %g N)\n', ...
        max(abs(out.log_FL.Data)), max(abs(out.log_FR.Data)), max(abs(out.log_FB.Data)), ...
        F_max, F_max, F_bow_max);
fprintf('           1단과 견주려면 W06_1_point_run 을 이어 돌릴 것 — 끝 자세는 같고 과도만 늦다\n');
