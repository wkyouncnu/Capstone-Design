% W06_1_POINT_RUN  1단 — 목표 자세로 가서 서는 모델을 돌리고 결과를 본다
%
%   >> W06_1_point_run
%
%   하는 일은 세 줄이다
%     (1) 1단 설정으로 W06_setup 을 부른다 (stage = 1)
%     (2) W06_1_point.slx 를 돌린다 — 도는 동안 실시간 그림이 함께 뜬다
%     (3) W06_plot 으로 결과 그림 여섯 칸과 성능 지표를 낸다
%
%   Simulink 를 직접 Run 해도 같은 실시간 그림이 뜬다. 다만 Constant 블록들이
%   변수를 찾아야 하므로 W06_setup 을 한 번 돌려 둔 뒤여야 한다. 이 파일은
%   그 두 걸음(설정 -> 실행 -> 그림)을 한 번에 한다.
%
%   이 단계에서 봐야 할 것
%     목표 (hold_north, hold_east) 에 hold_deg 로 서 있는가. 세 고리와 추력
%     배분이 제대로 짜였으면 마지막 10 초 평균 오차가 수 cm 아래로 내려간다.
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 쓰지 않는다.
%   연동은 쌍둥이 W06_<n>_..._vrx 를 Simulink 에서 직접 Run 해서 한다 —
%   그때 이 파일이 남긴 기준 궤적(ref/) 위에 겹쳐 그려 바로 대조한다.
setappdata(0, 'W06_stage', 1);
setappdata(0, 'W06_skip_run', true);    % 설정만 받아 온다 — 실행은 이 파일이 한다
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
W06_ref('save', stage, out, S);     % 쌍둥이가 겹쳐 그릴 기준 궤적 — [[W06_ref]]

%  목표에 정말 갔는가 — 잰 값을 그대로 찍는다
fprintf('\n[1단 점검] 목표  (%7.3f, %7.3f) m / %6.2f deg\n', x_d, y_d, rad2deg(psi_d));
fprintf('           끝    (%7.3f, %7.3f) m / %6.2f deg\n', ...
        out.log_x_n.Data(end), out.log_y_n.Data(end), rad2deg(out.log_psi.Data(end)));
if S.e_ss < 0.05 && S.epsi_ss < 0.5
    fprintf('           마지막 10 초 평균 오차 %.3f m / %.2f deg — 목표 자세로 서 있다\n', ...
            S.e_ss, S.epsi_ss);
else
    fprintf('           마지막 10 초 평균 오차 %.3f m / %.2f deg — 아직 서지 못했다.\n', ...
            S.e_ss, S.epsi_ss);
    fprintf('           T_run 을 늘리거나 Kp_x · Kp_y · Kp_psi 를 다시 볼 것\n');
end
