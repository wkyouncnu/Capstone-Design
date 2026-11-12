function addLogging(m, x, y)
% 로깅 — A3_plot.m 이 이 변수들을 읽는다 (변수 이름은 log_<신호>)
%   신호 이름 = Goto 태그 이름이다.
%
%   6주차 목록과 다른 곳이 둘이다
%     빠진 것  FL · FR · FB · n · F_err   (추진기가 둘이고 회전수 모델이 없다)
%     생긴 것  X_c·Y_c·N_c  요구한 힘·모멘트
%              X_a·Y_a·N_a  실제로 난 힘·모멘트  — 요구와의 차이가 곧 한계의 몫
%              TL·TR        추진기 추력 [N]      — 음수면 뒤로 밀고 있다는 뜻
%              dL·dR        추진기 방향각 [rad]  — ±45 deg 에 붙었는지 본다
%              kscl         추력 포화 축소 배율  — 1 보다 작으면 요구를 못 냈다
    sig = {'x_n','y_n','psi','psi_ref','x_ref','y_ref','u','v','r','U', ...
           'beta','chi','gate','phase', ...
           'X_c','Y_c','N_c','X_a','Y_a','N_a','TL','TR','dL','dR','kscl'};
    add_logging_box(m, sig, sig, [x y], 'Ts_ctrl');
end
