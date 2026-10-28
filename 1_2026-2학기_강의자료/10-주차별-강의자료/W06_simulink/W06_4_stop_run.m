% W06_4_STOP_RUN  4단 — 도착 판정과 자동 정지 모델을 돌리고 결과를 본다
%
%   >> W06_4_stop_run
%
%   3단까지는 T_run 이 다 찰 때까지 돌았다. 4단에서 AutoStop 상자가 들어간다 —
%   목표점에서 R_stop 안으로 들어오면 gate 가 1 에서 0 으로 떨어지고, 거기서
%   stop_hold 초를 더 돌다가 시뮬레이션이 스스로 멈춘다.
%
%   이 단계에서 봐야 할 것
%     끝 오차가 1단보다 **크게** 나온다. 틀린 것이 아니다 — gate 가 닫히는
%     순간 지령이 끊기므로 그때 남아 있던 속도만큼 배가 더 미끄러진다.
%     그 관성 거리를 재는 것이 이 단계의 목적이다. 1단처럼 cm 까지 붙이려면
%     gate 를 닫지 말고 끝까지 제어해야 한다 (= 1단).
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 쓰지 않는다.
%   연동은 쌍둥이 W06_<n>_..._vrx 를 Simulink 에서 직접 Run 해서 한다 —
%   그때 이 파일이 남긴 기준 궤적(ref/) 위에 겹쳐 그려 바로 대조한다.
setappdata(0, 'W06_stage', 4);
setappdata(0, 'W06_skip_run', true);
W06_setup

load_system(mdl);
out = sim(mdl);
S   = W06_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));
W06_ref('save', stage, out, S);     % 쌍둥이가 겹쳐 그릴 기준 궤적 — [[W06_ref]]

%  gate 가 닫힌 뒤 배가 얼마나 더 갔는가 — 그것이 관성 거리다
t     = out.log_x_n.Time;
x_n   = out.log_x_n.Data;   y_n = out.log_y_n.Data;
gate  = out.log_gate.Data;
k     = find(gate <= 0, 1);

fprintf('\n[4단 점검] 목표  (%7.3f, %7.3f) m / %6.2f deg,  R_stop = %g m\n', ...
        x_d, y_d, rad2deg(psi_d), R_stop);
fprintf('           끝    (%7.3f, %7.3f) m / %6.2f deg\n', ...
        x_n(end), y_n(end), rad2deg(out.log_psi.Data(end)));
if isempty(k)
    fprintf('           gate 가 끝까지 1 — R_stop 안으로 못 들어왔다.\n');
    fprintf('           T_run 을 늘리거나 R_stop 을 넓힐 것\n');
else
    fprintf('           gate 닫힌 시각   %6.2f s   그때 위치 (%7.3f, %7.3f) m,  오차 %.3f m\n', ...
            t(k), x_n(k), y_n(k), hypot(x_d - x_n(k), y_d - y_n(k)));
    fprintf('           그 뒤 미끄러진 거리 %.3f m   (끝 오차 %.3f m)\n', ...
            hypot(x_n(end) - x_n(k), y_n(end) - y_n(k)), S.e_final);
    fprintf('           정지 유예 stop_hold = %g s,  총 실행 %.2f s\n', stop_hold, t(end));
end
fprintf('           비교: 1단은 gate 를 안 닫아 끝까지 제어한다 — W06_1_point_run\n');
