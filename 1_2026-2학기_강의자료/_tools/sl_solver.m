function sl_solver(m, stopTime)
%SL_SOLVER  고정 간격 ode4 로 풀게 한다.
%
%   sl_solver(m, 'T_run')
%
%     stopTime   작업공간 변수 이름 또는 숫자 문자열. inf 를 쓰지 않는다 —
%                끝나는 때를 학생이 손으로 눌러 정하게 두지 않는다
%
%   간격은 Ts_ctrl 이다. 제어 주기와 적분 간격을 같게 두면 "이산 제어기를
%   연속 플랜트에 물렸다" 는 사실이 시간 축에서 그대로 보인다.
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime',stopTime, 'SimulationMode','normal');
end
