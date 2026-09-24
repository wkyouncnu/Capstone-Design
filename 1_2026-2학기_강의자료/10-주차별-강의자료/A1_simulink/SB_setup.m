% SB_SETUP  실습 F 파라미터 — 모델을 열기 전에 이것부터 실행한다.
%
%   SB6_param_done / SB6_param_todo 의 블록에는 숫자가 아니라
%   변수 이름이 적혀 있다. 그 값을 여기서 만든다.
%
%   >> SB_setup
%   >> out = sim('SB6_param_done');
%   >> SB_plot(out)

A_sig  = 1;      % Sine 진폭
K_gain = 2;      % Gain 값        <- 2 와 5 로 바꿔 가며 비교해 볼 것
Ts     = 0.05;   % 샘플 타임 [s]

fprintf('SB_setup 완료:  A_sig = %g,  K_gain = %g,  Ts = %g\n', A_sig, K_gain, Ts);
