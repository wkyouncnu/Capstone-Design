function S = W03_offline_run(T_end)
% W03_OFFLINE_RUN  3단계(W03_3_vrx_drive)와 같은 추력을 운동방정식으로 먼저 돌린다.
%
%   >> W03_setup                 % scenario = 1 (직진) 또는 2 (좌선회)
%   >> S = W03_offline_run       % VRX 없이 W03_0_offline 을 T_end 초
%   >> S = W03_offline_run(60)
%
%   무엇을 하는가
%     W03_0_offline 의 버튼 네 개는 Constant 의 Value 에 묶여 있다 (3주차 3-2 절).
%     이 스크립트는 버튼을 누르는 대신 그 Value 를 직접 넣는다.
%       전진 값 = (좌 + 우) / 2F,   우선회 값 = (좌 - 우) / 2F,   F = teleop_thrust
%     그러면 Mix 가 내는 추력이 W03_setup 의 thrust_left, thrust_right 와 같아진다.
%     끝나면 버튼 값을 0 으로 되돌려 놓는다.
%
%   반환값 S — W03_plot 과 같은 항목 (VRX 결과와 한 줄씩 대조하기 위함)
%     dist, speed, dpsi_deg, r_mean, t_valid, out
%     u_end, r_end_deg : 마지막 시각의 서지 속도 [m/s], 요각속도 [deg/s]

if nargin < 1 || isempty(T_end), T_end = evalin('base','T_end'); end

model = 'W03_0_offline';
tl = evalin('base','thrust_left');
tr = evalin('base','thrust_right');
F  = evalin('base','teleop_thrust');
if max(abs([tl tr])) > F
    warning('추력 %g / %g N 이 teleop_thrust (%g N) 를 넘는다. Mix 가 %g N 으로 자른다.', ...
            tl, tr, F, F);
end

load_system(model);
pad = [model '/TeleopPad'];
set_param([pad '/c_fwd'],   'Value', num2str((tl + tr)/(2*F), 17));
set_param([pad '/c_right'], 'Value', num2str((tl - tr)/(2*F), 17));
set_param(model, 'EnablePacing','off', 'StopTime', num2str(T_end));
c = onCleanup(@() restore(model, pad));

fprintf('W03_0_offline 실행 — 좌 %+.0f N / 우 %+.0f N, %g 초 (VRX 없음)\n', tl, tr, T_end);
out = sim(model);

sc = evalin('base','scenario');
if sc == 1, name = '직진'; else, name = '좌선회'; end
S = W03_plot(out, sprintf('%s / %s', model, name));
S.out = out;
S.u_end     = out.log_u.Data(end);
S.r_end_deg = rad2deg(out.log_r.Data(end));
fprintf(['  이동 거리 %.2f m, 평균 속력 %.3f m/s, 선수각 변화 %+.1f deg, ' ...
         '평균 r %+.4f rad/s\n  마지막 u %.3f m/s, 마지막 r %+.2f deg/s\n'], ...
        S.dist, S.speed, S.dpsi_deg, S.r_mean, S.u_end, S.r_end_deg);
end

% ---------------------------------------------------------------------
function restore(model, pad)
% 버튼 값과 실행 설정을 모델을 만들 때의 상태로 되돌린다
set_param([pad '/c_fwd'],   'Value', '0');
set_param([pad '/c_right'], 'Value', '0');
set_param(model, 'EnablePacing','on', 'StopTime','T_end_teleop');
end
