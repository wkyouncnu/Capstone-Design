% W06_2_SWAY_RUN  2단 — 순수 횡이동(pure sway) 모델을 돌리고 결과를 본다
%
%   >> W06_2_sway_run
%
%   1단과 다른 것은 `bow_on` 스위치 하나다 (InnerLoop 안). 1 이면 선수추진기가
%   살아 옆으로 12 m 가고, 0 이면 횡방향 힘을 낼 수 없어 제자리에 머문다.
%   스위치를 바꿔 두 번 돌려 보려면 W06_bow_demo 를 쓴다.
%
%   이 단계에서 봐야 할 것
%     선수각이 묶여 있는가 — 옆으로 가는 동안 psi 가 sway_deg 에서 거의
%     벗어나지 않아야 한다. 선수가 돌면 횡이동이 아니라 선회가 된다.
setappdata(0, 'W06_stage', 2);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s (bow_on = %d)', stage, stage_name{stage}, bow_on));

%  횡이동이 되었는가, 선수각은 묶여 있었는가
fprintf('\n[2단 점검] bow_on = %d,  목표 (%.3f, %.3f) m / %.2f deg\n', ...
        bow_on, x_d, y_d, rad2deg(psi_d));
fprintf('           끝  (%7.3f, %7.3f) m / %6.2f deg\n', ...
        out.log_x_n.Data(end), out.log_y_n.Data(end), rad2deg(out.log_psi.Data(end)));
fprintf('           선수각 최대 벗어남 %.3f deg,  최대 |u| %.3f m/s,  최대 |v| %.3f m/s\n', ...
        max(abs(rad2deg(out.log_psi.Data) - rad2deg(psi_d))), ...
        max(abs(out.log_u.Data)), S.max_v);
fprintf('           최대 |F_B| %.1f N  (한계 %g N)\n', S.max_FB, F_bow_max);
