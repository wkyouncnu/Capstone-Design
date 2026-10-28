% W06_8_NED_RUN  8단 — NED 좌표계 위치제어 접안 모델을 돌리고 결과를 본다
%
%   >> W06_8_ned_run
%
%   5단까지 위치 오차는 **선체 고정 좌표**로 돌려 서지·스웨이 지령을 만들었다.
%   8단은 북·동 축에서 바로 속도 지령을 만들고, 회전행렬이 안쪽 고리로 내려가
%   그 NED 속도를 선체 속도로 바꾼다. 제어 결과는 비슷하지만 **구조**가 다르다.
%     5단  (오차)-회전행렬->(선체 오차)-P->(u_d, v_d)-PI->힘
%     8단  (오차)-P->(V_N, V_E)-회전행렬->(u_d, v_d)-PI->힘
%
%   이 단계에서 봐야 할 것
%     끝 자세는 5단과 거의 같게 나오는가(같아야 한다 — 게인을 맞춰 두었다),
%     대신 완료 시각이 길어지는가. NED 속도 지령은 **크기**를 V_ned_max 로
%     묶으므로 북·동 어느 쪽도 u_max 까지 못 올라간다.
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 쓰지 않는다.
%   연동은 쌍둥이 W06_<n>_..._vrx 를 Simulink 에서 직접 Run 해서 한다 —
%   그때 이 파일이 남긴 기준 궤적(ref/) 위에 겹쳐 그려 바로 대조한다.
setappdata(0, 'W06_stage', 8);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
W06_ref('save', stage, out, S);     % 쌍둥이가 겹쳐 그릴 기준 궤적 — [[W06_ref]]

%  NED 속도 지령의 크기가 한계 안에 있었는가, 끝 자세는 5단과 같은가
fprintf('\n[8단 점검] 선석 (%7.3f, %7.3f) m / %6.2f deg,  제어 좌표계 NED\n', ...
        dock_north, dock_east, dock_deg);
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
fprintf('           게인 Kp_ned = %g,  속도 PI %g / %g,  크기 한계 %g m/s\n', ...
        Kp_ned, Kp_vn, Ki_vn, V_ned_max);
fprintf('           최대 |u| %.3f m/s (u_max = %g — 여기까지 못 올라간다),  최대 |v| %.3f m/s\n', ...
        max(abs(out.log_u.Data)), u_max, S.max_v);
fprintf('           5단과 숫자를 나란히 보려면 W06_berth_compare\n');
