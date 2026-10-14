function sl_pi(sys, name, P, I, lim, x, y)
%SL_PI  PI 제어기 하나 — 연속시간, 출력 포화 + clamping. 크기는 70 x 60.
%
%   sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', 'F_max', 360, 50)
%
%   왜 clamping 인가
%     출력이 포화에 닿으면 적분을 멈춘다. 그래야 목표에서 멀 때 적분기가
%     쌓였다가 다 왔을 때 지나쳐 버리는 일(wind-up)이 없다.
%
%   왜 연속시간인가
%     교수 지시 2026-10-01 — 강의 모델의 제어기는 연속시간으로 둔다.
%     이산 블록이 남아 있으면 check_discrete 가 이유를 묻는다.
    add_block('simulink/Continuous/PID Controller', [sys '/' name], ...
              'Position', [x y x+70 y+60]);
    set_param([sys '/' name], 'Controller','PI', 'TimeDomain','Continuous-time', ...
              'P', P, 'I', I, 'LimitOutput','on', ...
              'UpperSaturationLimit', lim, 'LowerSaturationLimit', ['-(' lim ')'], ...
              'AntiWindupMode','clamping');
end
