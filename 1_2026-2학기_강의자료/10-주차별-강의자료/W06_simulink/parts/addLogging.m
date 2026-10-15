function addLogging(m, x, y)
% 로깅 — W06_plot.m 이 이 변수들을 읽는다 (변수 이름은 log_<신호>)
%   신호 이름 = Goto 태그 이름. n 만 nprop 태그를 쓴다 (n 은 변수로 쓰기에 흔한 이름이다)
    sig = {'x_n','y_n','psi','psi_ref','x_ref','y_ref','u','v','r','U', ...
           'beta','chi','gate','phase','FL','FR','FB','n','F_err'};
    tag = {'x_n','y_n','psi','psi_ref','x_ref','y_ref','u','v','r','U', ...
           'beta','chi','gate','phase','FL','FR','FB','nprop','Ferr'};
    add_logging_box(m, sig, tag, [x y], 'Ts_ctrl');
end
