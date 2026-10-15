% W06_3_THRUST_RUN  3단 — 추진기 칸을 끼운 모델을 돌리고 결과를 본다
%
%   >> W06_3_thrust_run
%
%   2단까지는 사슬에 추진기 칸이 없었다. 3단에서 그 칸이 생긴다. 그 칸은
%   Gazebo 추진기 플러그인(gz::sim::systems::Thruster)이 하는 일을 소스와
%   같은 순서로 적은 것이다 — 추력에 포화를 걸고(±2353.5 N), 그 추력을
%   회전수로 바꾸고(n = sign(F) sqrt(|F|/k_prop)), 회전수를 다시 추력으로
%   되돌려(F = k_prop |n| n) 두 식이 서로의 역함수인지 검산한다. 링크에 가는
%   힘은 되돌린 값이 아니라 **포화만 거친 지령**이다 (Thruster.cc:770-773).
%
%   이 단계에서 봐야 할 것
%     먼저 끝 자세가 1단과 **같은지**. 환산을 왕복해도 값이 바뀌지 않으므로
%     같아야 한다 — 다르면 배선이 틀린 것이다. 그다음 왕복 검산 max|F_err| 이
%     0 인지, 회전수가 참고선 n_max = sqrt(F_max/k_prop) 안에 있는지, 플러그인
%     한계(편당 2353.5 N)까지 얼마나 남았는지 읽는다.
setappdata(0, 'W06_stage', 3);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));

%  왕복 검산이 0 인가, 회전수가 참고선 안에 있는가, 끝 자세는 1단과 같은가
n_all = squeeze(out.log_n.Data);
if size(n_all,1) ~= numel(out.log_x_n.Time), n_all = n_all.'; end
fprintf('\n[3단 점검] 끝 오차 %.3f m / %.2f deg,  마지막 10 초 평균 %.3f m / %.2f deg\n', ...
        S.e_final, S.epsi_final, S.e_ss, S.epsi_ss);
fprintf('           왕복 검산 max|F_err| %.2e N  (F -> n -> F, 0 이어야 한다)\n', ...
        S.max_Ferr);
fprintf('           최대 |n| %.2f rad/s  (참고선 %.2f rad/s — 포화 블록이 아니다)\n', ...
        max(max(abs(n_all))), n_max);
fprintf('           최대 추력 FL %.1f / FR %.1f / FB %.1f N  (한계 %g / %g / %g N)\n', ...
        max(abs(out.log_FL.Data)), max(abs(out.log_FR.Data)), max(abs(out.log_FB.Data)), ...
        F_max, F_max, F_bow_max);
fprintf('           1단과 견주려면 W06_1_point_run 을 이어 돌릴 것 — 끝 자세가 같아야 한다\n');
