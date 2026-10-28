% W06_5_DOCK_RUN  5단 — 옆걸음 접안 모델을 돌리고 결과를 본다
%
%   >> W06_5_dock_run
%
%   4단까지 목표는 한 점이었다. 5단에서 유도부(TaskRef)가 들어가 목표를
%   **세 단계로 나눠** 내보낸다.
%     단계 1  접근점 (선석에서 뱃길 쪽으로 L_app 떨어진 점) 까지 전진
%     단계 2  선석 방위로 선수각을 맞춤 (제자리 선회)
%     단계 3  선수각을 묶은 채 옆걸음으로 선석에 붙음  <- 선수추진기가 하는 일
%
%   이 단계에서 봐야 할 것
%     세 단계가 **차례로** 올라가는가(t_phase), 단계 3 에서 선수각이 흔들리지
%     않는가, 옆걸음 구간에서 |v| 가 v_max 근처로 버티는가.
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 쓰지 않는다.
%   연동은 쌍둥이 W06_<n>_..._vrx 를 Simulink 에서 직접 Run 해서 한다 —
%   그때 이 파일이 남긴 기준 궤적(ref/) 위에 겹쳐 그려 바로 대조한다.
setappdata(0, 'W06_stage', 5);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
W06_ref('save', stage, out, S);     % 쌍둥이가 겹쳐 그릴 기준 궤적 — [[W06_ref]]

%  세 단계가 제때 올라갔는가, 선석에 얼마나 붙었는가
t     = out.log_x_n.Time;
phase = out.log_phase.Data;
psi   = rad2deg(out.log_psi.Data);
k3    = find(phase > 2.5, 1);           % 옆걸음이 시작된 표본

fprintf('\n[5단 점검] 선석 (%7.3f, %7.3f) m / %6.2f deg,  접근점 (%7.3f, %7.3f) m\n', ...
        dock_north, dock_east, dock_deg, app_north, app_east);
fprintf('           끝    (%7.3f, %7.3f) m / %6.2f deg\n', ...
        out.log_x_n.Data(end), out.log_y_n.Data(end), psi(end));
for i = 1:numel(S.t_phase)
    if isnan(S.t_phase(i))
        fprintf('           단계 %d  미도달\n', i);
    else
        fprintf('           단계 %d  %6.2f s 도달\n', i, S.t_phase(i));
    end
end
fprintf('           끝 오차 %.3f m / %.2f deg   (R_stop = %g m 안에서 gate 가 닫힌다)\n', ...
        S.e_final, S.epsi_final, R_stop);
if isempty(k3)
    fprintf('           옆걸음 구간에 못 들어갔다 — T_run 을 늘릴 것\n');
else
    fprintf('           옆걸음 구간 선수각 벗어남 최대 %.3f deg,  최대 |v| %.3f m/s (한계 %g)\n', ...
            max(abs(psi(k3:end) - dock_deg)), max(abs(out.log_v.Data(k3:end))), v_max);
end
fprintf('           최대 |F_B| %.1f N (한계 %g N) — 이 힘이 옆걸음을 만든다\n', S.max_FB, F_bow_max);
fprintf('           전진 접안과 견주려면 W06_7_front_run, NED 제어와는 W06_8_ned_run\n');
