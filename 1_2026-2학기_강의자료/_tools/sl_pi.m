function sl_pi(sys, name, P, I, lim, x, y, kb)
%SL_PI  PI 제어기 하나 — 연속시간, 출력 포화 + 안티와인드업. 크기는 70 x 60.
%
%   sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', 'F_max', 360, 50)         % 고정 (clamping)
%   sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', 'F_max', 360, 50, 'Kb')   % 역계산
%
%   여덟째 인자 kb
%     주면 **역계산**(back-calculation)이 되고 그 이름이 되감기 이득이 된다.
%     빼면 **고정**(clamping)이다.
%
%   고정과 역계산의 차이
%     고정   출력이 포화에 닿고 오차가 더 밀어붙이는 쪽이면 적분을 멈춘다.
%            멈추기만 하므로 이미 쌓인 적분량은 **그대로 남는다**. 오차의
%            부호가 바뀐 뒤에야 줄어든다.
%     역계산 잘려 나간 만큼 (sat - raw) 을 Kb 배 해서 적분기 입력에 더한다.
%            포화에 닿아 있는 동안 적분량이 **능동적으로 되감긴다**. 포화를
%            벗어나는 순간의 적분량이 작으므로 지나침(overshoot)이 작다.
%
%   Kb 를 얼마로 두는가 — 단위는 1/s 다
%     Kb*(sat - raw) 가 적분기 입력(힘의 시간변화율)에 더해지므로 Kb 의
%     단위는 1/s 이고, 1/Kb 가 적분량이 되감기는 시간상수(Tt)다.
%     Astrom 의 권고는 PI 에서 Tt = Ti = Kp/Ki — 그러면 Kb = Ki/Kp 다.
%     실제 값은 재서 정한다 (W06_awup_compare.m).
%
%   왜 연속시간인가
%     교수 지시 2026-10-01 — 강의 모델의 제어기는 연속시간으로 둔다.
%     이산 블록이 남아 있으면 check_discrete 가 이유를 묻는다.
    add_block('simulink/Continuous/PID Controller', [sys '/' name], ...
              'Position', [x y x+70 y+60]);
    set_param([sys '/' name], 'Controller','PI', 'TimeDomain','Continuous-time', ...
              'P', P, 'I', I, 'LimitOutput','on', ...
              'UpperSaturationLimit', lim, 'LowerSaturationLimit', ['-(' lim ')']);

    if nargin >= 8 && ~isempty(kb)
        set_param([sys '/' name], 'AntiWindupMode','back-calculation', 'Kb', kb);
    else
        set_param([sys '/' name], 'AntiWindupMode','clamping');
    end
end
