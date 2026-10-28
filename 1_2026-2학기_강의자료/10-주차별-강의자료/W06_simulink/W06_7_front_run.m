% W06_7_FRONT_RUN  7단 — 전진 접안 모델을 돌리고 결과를 본다
%
%   >> W06_7_front_run
%
%   5단은 선석 방위 그대로 서서 옆으로 붙었다(옆걸음). 7단은 선수를 선석 쪽으로
%   돌려 **앞으로** 들이민다. 바뀌는 것은 유도부가 내보내는 목표 선수각 하나다.
%       접안 선수각 = dock_deg - berth_side * 90 deg
%
%   이 단계에서 봐야 할 것
%     마지막 구간에서 선수추진기 F_B 가 5단보다 적게 쓰인다 — 붙이는 힘을
%     선미 추진기가 내기 때문이다. 대신 선미 추력이 한계(F_max)에 더 가까이
%     붙고, 선수각을 90 deg 돌리는 몫만큼 완료 시각이 달라진다.
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 쓰지 않는다.
%   연동은 쌍둥이 W06_<n>_..._vrx 를 Simulink 에서 직접 Run 해서 한다 —
%   그때 이 파일이 남긴 기준 궤적(ref/) 위에 겹쳐 그려 바로 대조한다.
setappdata(0, 'W06_stage', 7);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
W06_ref('save', stage, out, S);     % 쌍둥이가 겹쳐 그릴 기준 궤적 — [[W06_ref]]

%  전진 접안의 목표 선수각으로 섰는가, 추력은 어디에 쏠렸는가
psi_dock = dock_deg - berth_side*90;

fprintf('\n[7단 점검] 선석 (%7.3f, %7.3f) m,  접안 선수각 %6.2f deg (= %g - %g*90)\n', ...
        dock_north, dock_east, psi_dock, dock_deg, berth_side);
fprintf('           끝    (%7.3f, %7.3f) m / %6.2f deg\n', ...
        out.log_x_n.Data(end), out.log_y_n.Data(end), rad2deg(out.log_psi.Data(end)));
for i = 1:numel(S.t_phase)
    if isnan(S.t_phase(i))
        fprintf('           단계 %d  미도달\n', i);
    else
        fprintf('           단계 %d  %6.2f s 도달\n', i, S.t_phase(i));
    end
end
fprintf('           끝 오차 %.3f m / %.2f deg   (R_stop = %g m)\n', ...
        S.e_final, S.epsi_final, R_stop);
fprintf('           최대 추력 FL %.1f / FR %.1f N (한계 %g),  FB %.1f N (한계 %g)\n', ...
        max(abs(out.log_FL.Data)), max(abs(out.log_FR.Data)), F_max, S.max_FB, F_bow_max);
fprintf('           최대 |v| %.3f m/s — 옆걸음(5단)보다 작아야 전진 접안답다\n', S.max_v);
fprintf('           5단과 숫자를 나란히 보려면 W06_berth_compare\n');
