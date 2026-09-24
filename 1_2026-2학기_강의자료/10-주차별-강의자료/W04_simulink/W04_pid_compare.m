function T = W04_pid_compare(kind)
% W04_PID_COMPARE  게인이나 옵션을 바꿔 가며 여러 번 돌리고 한 그림에 겹쳐 그린다.
%
%   1단계 · 플랜트
%   W04_pid_compare('plant')  미분방정식 줄 vs 전달함수 줄  (W04_P0_plant)
%   W04_pid_compare('zeta')   감쇠비 스윕                  (W04_P0_second_order)
%   W04_pid_compare('wn')     고유진동수 스윕              (W04_P0_second_order)
%
%   1단계 · PID
%   W04_pid_compare('Kp')     P 만 키운다                 (W04_P1_pid_step)
%   W04_pid_compare('Kd')     P 는 두고 D 를 더한다        (W04_P1_pid_step)
%   W04_pid_compare('Ki')     PD 에 I 를 더한다            (W04_P1_pid_step)
%   W04_pid_compare('hand')   직접 만든 PID vs 라이브러리   (W04_P2_pid_byhand)
%   W04_pid_compare('D')      미분 필터 Nf 를 푼다         (W04_P2_pid_byhand)
%   W04_pid_compare('AW')     안티와인드업 유무            (W04_P2_pid_byhand)
%   W04_pid_compare('kick')   계단 모서리의 미분 킥        (W04_P2_pid_byhand)
%   W04_pid_compare('tune')   게인을 정하는 순서 (단계별)   (W04_P2_pid_byhand)
%
%   2단계 · 배
%   W04_pid_compare('boat_open')  개루프 — u_ss · T_u · 속도 천장 (W04_P3_boat_speed)
%   W04_pid_compare('boat_Kp')    속도축 P 게인 스윕            (W04_P3_boat_speed)
%   W04_pid_compare('boat_Kd')    속도축 D 는 해롭다            (W04_P3_boat_speed)
%   W04_pid_compare('boat')       배에서 안티와인드업 유무      (W04_P3_boat_speed)
%
%   부록 A1
%   W04_pid_compare('lowpass')    저역통과 필터 통과율         (W04_P4_lowpass)
%
%   반환값 T 는 측정값 표다. 과제에 그대로 옮겨 적으면 된다.
%   그림은 img/ 에 저장된다.
%
%   base workspace 의 변수는 건드리지 않는다.
%   (Simulink.SimulationInput 으로 그 실행에만 값을 밀어 넣는다)

if nargin < 1, kind = 'Kp'; end
evalin('base', 'W04_setup');   % 기본값을 base 에 확보한다. sim 은 base 를 본다

switch lower(kind)
    case 'plant',     T = comparePlant();
    case 'zeta',      T = sweepP0('zeta', [0.2 0.5 0.7071 1.0], 'zeta');
    case 'wn',        T = sweepP0('wn',   [0.7071 1.4142 2.8284], 'wn');
    case 'kp',   T = sweepP1('Kp', [2 10 50],  struct('Ki',0,'Kd',0),  'P 게인');
    case 'kd',   T = sweepP1('Kd', [0 2 6],    struct('Kp',10,'Ki',0), 'D 게인');
    case 'ki',   T = sweepP1('Ki', [0 4 12],   struct('Kp',10,'Kd',4), 'I 게인');
    case 'hand', T = compareHand();
    case 'd',    T = sweepFilter();
    case 'aw',   T = sweepAW();
    case 'kick',      T = sweepKick();
    case 'tune',      T = sweepTune();
    case 'boat', T = sweepBoat();
    case 'boat_open', T = sweepBoatOpen();
    %  P 만 볼 때는 Kb_u 도 0 으로 둔다. 되감기(back-calculation)는 Ki 가 0 이어도
    %  포화 중에 적분기를 **음수로** 끌어내려 P 항을 갉아먹는다 (2026-09-24 실측)
    case 'boat_kp',   T = sweepBoatGain('Kp_u', [100 300 1000], ...
                                        struct('Ki_u',0,'Kd_u',0,'Kb_u',0), 'Kp_u');
    case 'boat_kd',   T = sweepBoatGain('Kd_u', [0 50 200], struct('Kp_u',300,'Ki_u',300), 'Kd_u');
    case 'lowpass',   T = sweepLowpass();
    otherwise,   error(['kind 는 plant, zeta, wn, Kp, Kd, Ki, hand, D, AW, kick, tune, ' ...
                        'boat, boat_open, boat_Kp, boat_Kd, lowpass 중 하나여야 한다.']);
end
end

% =====================================================================
% P0 — 같은 플랜트를 두 가지로 적으면 정말 같은가
% =====================================================================
function T = comparePlant()
mdl = 'W04_P0_plant'; load_system(mdl);
out = sim(Simulink.SimulationInput(mdl));

t  = out.log_y_ode.Time;
yo = squeeze(out.log_y_ode.Data);
yt = squeeze(out.log_y_tf.Data);

[ax1, ax2] = twoPanel('W04 플랜트 - 미분방정식 vs 전달함수');
plot(ax1, t, yo, 'LineWidth',2.4, 'DisplayName','PlantODE (적분기 조립)');
plot(ax1, t, yt, '--', 'LineWidth',1.6, 'DisplayName','Plant\_tf (전달함수)');
plot(ax2, t, yo-yt, 'LineWidth',1.4, 'DisplayName','차이');
finishPanel(ax1, ax2, '두 곡선이 겹치면 같은 것을 두 가지로 적은 것이다', ...
            '변위 y [m]', '차이 [m]');
%  블록도 PNG 와 이름이 겹치면 안 된다 — export_diagram 이 img/W04_P0_plant.png 를 쓴다
saveImg(ax1, 'W04_P0_plant_two_ways.png');

k = evalin('base','msd_k');  f = evalin('base','f_step');
T = table(max(abs(yo-yt)), yo(end), yt(end), f/k, ...
    'VariableNames', {'y_max_abs_diff','y_ss_ode','y_ss_tf','y_ss_hand'});
disp(T);
end

% =====================================================================
% P0-2 — 표준 2차계의 두 다이얼
% =====================================================================
function T = sweepP0(name, values, label)
mdl = 'W04_P0_second_order'; load_system(mdl);

[ax1, ax2] = twoPanel(['W04 2차계 - ' label]);
rows = cell(numel(values),1);
for k = 1:numel(values)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable(name, values(k));
    out = sim(in);
    t = out.log_y2.Time;  y = squeeze(out.log_y2.Data);
    tag = sprintf('%s = %.4g', name, values(k));
    plot(ax1, t, y, 'LineWidth',1.6, 'DisplayName',tag);
    plot(ax2, t, squeeze(out.log_ref2.Data), 'LineWidth',1.0, 'DisplayName',tag);

    mk = metrics(t, y, 1, tag);
    %  손계산 — Mp = exp(-pi*zeta/sqrt(1-zeta^2)) [%], ts = 4/(zeta*wn)
    if strcmp(name,'zeta'), z = values(k); w = evalin('base','wn');
    else,                   w = values(k); z = evalin('base','zeta'); end
    if z < 1, mpH = 100*exp(-pi*z/sqrt(1-z^2)); else, mpH = 0; end
    mk = addvars(mk, mpH, 4/(z*w), 'NewVariableNames', {'OS_hand_pct','Ts_hand_s'});
    rows{k} = mk;
end
plot(ax1, [0 15], [1 1], 'k--', 'DisplayName','목표값');
finishPanel(ax1, ax2, sprintf('%s 만 바꿨을 때 — 표준 2차계', label), ...
            '출력 y', '목표값');
saveImg(ax1, sprintf('W04_P0_%s.png', label));

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P1 — 게인 하나만 바꿔 가며 스텝응답 비교
% =====================================================================
function T = sweepP1(name, values, fixed, label)
mdl = 'W04_P1_pid_step'; load_system(mdl);
fn  = fieldnames(fixed);

[ax1, ax2] = twoPanel(['W04 PID - ' label]);
rows = cell(numel(values),1);
for k = 1:numel(values)
    in = Simulink.SimulationInput(mdl);
    for j = 1:numel(fn), in = in.setVariable(fn{j}, fixed.(fn{j})); end
    in = in.setVariable(name, values(k));
    out = sim(in);

    t = out.log_y.Time;  y = squeeze(out.log_y.Data);  u = squeeze(out.log_tau.Data);
    tag = sprintf('%s = %g', name, values(k));
    plot(ax1, t, y, 'LineWidth',1.6, 'DisplayName',tag);
    plot(ax2, t, u, 'LineWidth',1.6, 'DisplayName',tag);
    rows{k} = metrics(t, y, 1, tag);
end
plot(ax1, [0 10], [1 1], 'k--', 'DisplayName','목표값');
finishPanel(ax1, ax2, sprintf('%s 만 바꿨을 때 (플랜트 1/(s^2+2s+2))', label), ...
            '출력 y', '제어입력 τ');
%  갈래마다 한 장씩 저장한다. 강의노트가 P · D · I 를 각각 다른 절에서 쓴다
saveImg(ax1, sprintf('W04_P1_%s.png', name));

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P2 — 직접 만든 PID 가 라이브러리 블록과 같은가
% =====================================================================
function T = compareHand()
mdl = 'W04_P2_pid_byhand'; load_system(mdl);
out = sim(Simulink.SimulationInput(mdl));

t  = out.log_y_lib.Time;
yl = squeeze(out.log_y_lib.Data);   ul = squeeze(out.log_tau_lib.Data);
yh = squeeze(out.log_y_hand.Data);  uh = squeeze(out.log_tau_hand.Data);

[ax1, ax2] = twoPanel('W04 PID - 직접 만든 것 vs 라이브러리');
plot(ax1, t, yl, 'LineWidth',2.4, 'DisplayName','라이브러리 PID 블록');
plot(ax1, t, yh, '--', 'LineWidth',1.6, 'DisplayName','직접 만든 PID');
plot(ax2, t, ul, 'LineWidth',2.4, 'DisplayName','라이브러리 PID 블록');
plot(ax2, t, uh, '--', 'LineWidth',1.6, 'DisplayName','직접 만든 PID');
finishPanel(ax1, ax2, '두 곡선이 겹치면 블록 안의 것과 같다', '출력 y', '제어입력 τ');
saveImg(ax1, 'W04_P2_hand_vs_lib.png');

T = table(max(abs(yl-yh)), max(abs(ul-uh)), ...
    'VariableNames', {'y_max_abs_diff','tau_max_abs_diff'});
disp(T);
end

% =====================================================================
% P2 — 미분 필터 계수를 풀면 제어입력이 어떻게 되는가
% =====================================================================
function T = sweepFilter()
mdl = 'W04_P2_pid_byhand'; load_system(mdl);
Nlist = [200 20 5];      % 가장 요란한 200 을 먼저 그려 뒤에 깐다 — 5 · 20 이 가려지지 않게
col   = [0.75 0.75 0.75; 0.85 0.33 0.10; 0.00 0.45 0.74];

[ax1, ax2] = twoPanel('W04 PID - 미분 필터');
rows = cell(numel(Nlist),1);
for k = 1:numel(Nlist)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Nf2', Nlist(k));
    out = sim(in);
    t = out.log_y_hand.Time;
    y = squeeze(out.log_y_hand.Data);  u = squeeze(out.log_tau_hand.Data);

    tag = sprintf('Nf = %g', Nlist(k));
    plot(ax1, t, y, 'Color',col(k,:), 'LineWidth',1.4, 'DisplayName',tag);
    plot(ax2, t, u, 'Color',col(k,:), 'LineWidth',1.0, 'DisplayName',tag);

    mk = metrics(t, y, evalin('base','r_step'), tag);
    mk = addvars(mk, max(abs(diff(u))), 'NewVariableNames', {'dtau_max'});
    mk = addvars(mk, std(u(t > t(end)*0.5)), 'NewVariableNames', {'tau_std'});
    rows{k} = mk;
end
finishPanel(ax1, ax2, '미분 필터 계수 Nf — 클수록 순수 미분에 가깝다', ...
            '출력 y', '제어입력 τ');
saveImg(ax1, 'W04_P2_derivative.png');

T = vertcat(rows{end:-1:1});  disp(T);     % 표는 Nf 작은 것부터
end

% =====================================================================
% P2 — 포화에 걸렸을 때 안티와인드업 유무 (되감기 이득 Kb)
% =====================================================================
function T = sweepAW()
mdl = 'W04_P2_pid_byhand'; load_system(mdl);
Kbs  = [0 2];
name = {'Kb = 0  (안티와인드업 없음)','Kb = 2  (되감기 켬)'};

[ax1, ax2] = twoPanel('W04 PID - 안티와인드업');
rows = cell(numel(Kbs),1);
for k = 1:numel(Kbs)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Kb', Kbs(k));
    in  = in.setVariable('noise_var', 0);       % 잡음은 끄고 적분기만 본다
    out = sim(in);
    t = out.log_y_hand.Time;
    y = squeeze(out.log_y_hand.Data);  u = squeeze(out.log_tau_hand.Data);

    plot(ax1, t, y, 'LineWidth',1.6, 'DisplayName',name{k});
    plot(ax2, t, u, 'LineWidth',1.6, 'DisplayName',name{k});
    rows{k} = metrics(t, y, evalin('base','r_step'), name{k});
end
plot(ax1, [0 20], [1 1], 'k--', 'DisplayName','목표값');
plot(ax2, [0 20], evalin('base','u_max')*[1 1], 'k--', 'DisplayName','제어입력 한계');
finishPanel(ax1, ax2, '올라가는 동안 제어입력이 한계에 붙는 경우', '출력 y', '제어입력 τ');
saveImg(ax1, 'W04_P2_antiwindup.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P3 — 배에서 안티와인드업 유무
% =====================================================================
function T = sweepBoat()
mdl = 'W04_P3_boat_speed'; load_system(mdl);
Kbs  = [0 2];
name = {'Kb_u = 0  (안티와인드업 없음)','Kb_u = 2  (되감기 켬)'};
col  = [0.85 0.33 0.10; 0.00 0.45 0.74];    % 두 패널에서 같은 조건은 같은 색

[ax1, ax2] = twoPanel('W04 PID - 배 속도 제어');
rows = cell(numel(Kbs),1);
for k = 1:numel(Kbs)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Kb_u', Kbs(k));
    out = sim(in);

    t = out.log_u.Time;
    u = squeeze(out.log_u.Data);
    X = squeeze(out.log_X.Data);

    plot(ax1, t, u, 'Color',col(k,:), 'LineWidth',1.6, 'DisplayName',name{k});
    plot(ax2, t, X, 'Color',col(k,:), 'LineWidth',1.6, 'DisplayName',name{k});

    seg = t >= 30;                       % 목표가 1.0 m/s 로 내려온 뒤
    rows{k} = table(string(name{k}), max(u(seg)), settle(t(seg), u(seg), 1.0, 0.02), ...
                    u(end), ...
        'VariableNames', {'cond','u_max_late','Ts_late_s','u_end'});
end
plot(ax1, [0 60], [2.5 2.5], 'k:',  'DisplayName','도달 불가 목표 2.5');
plot(ax1, [0 60], [1.0 1.0], 'k--', 'DisplayName','도달 가능 목표 1.0');
plot(ax2, [0 60], evalin('base','X_max')*[1 1], 'k--', 'DisplayName','추력 한계');
finishPanel(ax1, ax2, '도달할 수 없는 목표 뒤에 도달할 수 있는 목표', ...
            '선속도 u [m/s]', '전체 추력 X [N]');
saveImg(ax1, 'W04_P3_boat.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P2 — 계단 모서리에서 제어입력이 튄다 (미분 킥)
%      목표값을 1/(T_ref s + 1) 로 한 번 거치면 사라진다
% =====================================================================
function T = sweepKick()
mdl = 'W04_P2_pid_byhand'; load_system(mdl);
name = {'ref\_smooth = 0  (계단 그대로)','ref\_smooth = 1  (평활)'};

[ax1, ax2] = twoPanel('W04 PID - 미분 킥');
rows = cell(2,1);
for k = 1:2
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('ref_smooth', k-1);
    in  = in.setVariable('noise_var', 0);      % 잡음은 끄고 계단 모서리만 본다
    %  포화 한계를 풀어 둔다. u_max = 2.5 로는 킥이 잘려 보이지 않는다
    %  (킥의 크기가 Kd*Nf*계단 = 80 이라 한계에 그대로 붙어 버린다)
    in  = in.setVariable('u_max', 100);
    out = sim(in);
    t = out.log_y_hand.Time;
    y = squeeze(out.log_y_hand.Data);  u = squeeze(out.log_tau_hand.Data);

    plot(ax1, t, y, 'LineWidth',1.6, 'DisplayName',name{k});
    plot(ax2, t, u, 'LineWidth',1.6, 'DisplayName',name{k});

    %  계단은 t = 1 s 에 들어간다. 그 직후 0.5 초 안의 최대 제어입력이 킥이다
    seg  = t >= 1 & t <= 1.5;
    kick = max(u(seg));
    Kd2 = evalin('base','Kd2'); Nf2 = evalin('base','Nf2'); rs = evalin('base','r_step');
    rows{k} = table(string(name{k}), kick, Kd2*Nf2*rs, max(u), ...
                    mean(u(t > t(end)-2)), ...
        'VariableNames', {'cond','tau_kick','tau_kick_hand','tau_max','tau_ss'});
end
finishPanel(ax1, ax2, '계단 모서리에서 D 항이 한 번 크게 튄다 (Kd*Nf*계단 = 킥)', ...
            '출력 y', '제어입력 τ  (포화 한계를 100 으로 풀어 둠)');
saveImg(ax1, 'W04_P2_kick.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P2 — 게인을 정하는 순서를 그대로 따라가며 단계마다 잰다
%      ① Kp ② Kd ③ Ki ④ 포화를 보고 Kb
% =====================================================================
function T = sweepTune()
mdl = 'W04_P2_pid_byhand'; load_system(mdl);
%   {Kp,  Ki, Kd, Kb, 설명}
steps = { 4, 0, 0, 0, '① Kp = 4    작게 시작'; ...
         10, 0, 0, 0, '① Kp = 10   출렁이기 직전까지'; ...
         10, 0, 4, 0, '② Kd = 4    출렁임을 깎는다'; ...
         10, 8, 4, 0, '③ Ki = 8    남는 오차를 지운다'; ...
         10, 8, 4, 2, '④ Kb = 2    포화를 보고 되감기'};

[ax1, ax2] = twoPanel('W04 PID - 튜닝 순서');
rows = cell(size(steps,1),1);
for k = 1:size(steps,1)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Kp2', steps{k,1});
    in  = in.setVariable('Ki2', steps{k,2});
    in  = in.setVariable('Kd2', steps{k,3});
    in  = in.setVariable('Kb',  steps{k,4});
    in  = in.setVariable('noise_var', 0);
    out = sim(in);
    t = out.log_y_hand.Time;
    y = squeeze(out.log_y_hand.Data);  u = squeeze(out.log_tau_hand.Data);

    plot(ax1, t, y, 'LineWidth',1.4, 'DisplayName',steps{k,5});
    plot(ax2, t, u, 'LineWidth',1.0, 'DisplayName',steps{k,5});

    mk  = metrics(t, y, evalin('base','r_step'), steps{k,5});
    sat = 100*mean(abs(u) >= evalin('base','u_max')*0.999);
    rows{k} = addvars(mk, sat, 'NewVariableNames', {'sat_pct'});
end
plot(ax1, [0 20], [1 1], 'k--', 'DisplayName','목표값');
finishPanel(ax1, ax2, '한 번에 하나씩 — 무엇을 재서 이 값을 정했는가', ...
            '출력 y', '제어입력 τ');
saveImg(ax1, 'W04_P2_tune.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P3 — 개루프. 제어기를 빼고 계단 추력만 준다
%      ① 정상상태 속도 u_ss  ② 시상수 T_u  ③ 추력 한계의 최고속
% =====================================================================
function T = sweepBoatOpen()
mdl = 'W04_P3_boat_speed'; load_system(mdl);
Xs  = [200 400 500];
mb  = evalin('base','m_boat');  Xu = evalin('base','Xu');  Xuu = evalin('base','Xuu');

[ax1, ax2] = twoPanel('W04 배 - 개루프');
rows = cell(numel(Xs),1);
for k = 1:numel(Xs)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('boat_open', 1);
    in  = in.setVariable('X_open',    Xs(k));
    out = sim(in);

    t = out.log_u.Time;  u = squeeze(out.log_u.Data);  X = squeeze(out.log_X.Data);
    uss = mean(u(t > t(end)-5));
    i63 = find(u >= 0.632*uss, 1);
    if isempty(i63), Tu = NaN; else, Tu = t(i63); end

    %  손계산 — du/dt = 0 이면 (Xu + Xuu u) u = X,  T_u = m/(Xu + 2 Xuu u)
    uH = (-Xu + sqrt(Xu^2 + 4*Xuu*Xs(k)))/(2*Xuu);
    TH = mb/(Xu + 2*Xuu*uH);

    tag = sprintf('X = %g N', Xs(k));
    plot(ax1, t, u, 'LineWidth',1.6, 'DisplayName',tag);
    plot(ax2, t, X, 'LineWidth',1.6, 'DisplayName',tag);
    rows{k} = table(string(tag), uss, uH, Tu, TH, ...
        'VariableNames', {'cond','u_ss_meas','u_ss_hand','T_u_meas_s','T_u_hand_s'});
end
finishPanel(ax1, ax2, '제어기 없이 계단 추력만 — 이 세 숫자가 게인의 근거다', ...
            '선속도 u [m/s]', '전체 추력 X [N]');
saveImg(ax1, 'W04_P3_open.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P3 — 속도축 게인 스윕. 30 s 이후(목표 1.0 m/s) 구간에서 잰다
% =====================================================================
function T = sweepBoatGain(name, values, fixed, label)
mdl = 'W04_P3_boat_speed'; load_system(mdl);
fn  = fieldnames(fixed);

[ax1, ax2] = twoPanel(['W04 배 - ' label]);
rows = cell(numel(values),1);
for k = 1:numel(values)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('boat_open', 0);
    for j = 1:numel(fn), in = in.setVariable(fn{j}, fixed.(fn{j})); end
    in = in.setVariable(name, values(k));
    out = sim(in);

    t = out.log_u.Time;  u = squeeze(out.log_u.Data);  X = squeeze(out.log_X.Data);
    tag = sprintf('%s = %g', name, values(k));
    plot(ax1, t, u, 'LineWidth',1.6, 'DisplayName',tag);
    plot(ax2, t, X, 'LineWidth',1.6, 'DisplayName',tag);

    %  30 s 에 목표가 2.5 -> 1.0 m/s 로 **내려온다.** 그 계단만 잘라서 잰다.
    %  올라가는 계단이 아니므로 오버슈트 대신 **밑으로 얼마나 내려갔나**를 잰다
    seg = t >= 30;
    tt  = t(seg) - 30;  uu = u(seg);  XX = X(seg);
    uf  = mean(uu(tt > tt(end)-5));
    idx = find(abs(uu - uf) > 0.02*abs(uf), 1, 'last');   % 제자리(uf)에 드는 시각
    if isempty(idx), ts = 0; else, ts = tt(min(idx+1, numel(tt))); end

    %  손계산 — P 만이면 (Xu + Xuu u) u = Kp (u_d - u). Ki 가 있으면 오차가 0 이다
    Ki = fieldOr(fixed, 'Ki_u', evalin('base','Ki_u'));
    if strcmp(name,'Ki_u'), Ki = values(k); end
    if Ki == 0
        Kp  = fieldOr(fixed, 'Kp_u', evalin('base','Kp_u'));
        if strcmp(name,'Kp_u'), Kp = values(k); end
        Xu  = evalin('base','Xu');  Xuu = evalin('base','Xuu');
        uH  = (-(Xu+Kp) + sqrt((Xu+Kp)^2 + 4*Xuu*Kp*1.0))/(2*Xuu);
        eH  = 1.0 - uH;
    else
        eH = 0;
    end

    rows{k} = table(string(tag), uf, 1.0 - uf, eH, min(uu), ts, max(abs(diff(XX))), ...
        'VariableNames', {'cond','u_ss','e_ss','e_ss_hand','u_min','Ts2pct_s','dX_max'});
end
plot(ax1, [0 60], [1 1], 'k--', 'DisplayName','목표 1.0 m/s (30 s 이후)');
finishPanel(ax1, ax2, sprintf('%s 만 바꿨을 때 (30 s 이후 구간에서 측정)', label), ...
            '선속도 u [m/s]', '전체 추력 X [N]');
saveImg(ax1, sprintf('W04_P3_%s.png', label));

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P4 — 저역통과 필터. 느린 것은 지나가고 빠른 것은 깎인다 (부록 A1)
% =====================================================================
function T = sweepLowpass()
mdl = 'W04_P4_lowpass'; load_system(mdl);
out = sim(Simulink.SimulationInput(mdl));

t  = out.log_sig.Time;
s  = squeeze(out.log_sig.Data);
yr = squeeze(out.log_y_raw.Data);
yl = squeeze(out.log_y_lp.Data);

[ax1, ax2] = twoPanel('W04 저역통과 필터');
plot(ax1, t, yr, 'Color',[.75 .75 .75], 'LineWidth',1.0, 'DisplayName','필터 전 (신호+잡음)');
plot(ax1, t, yl, 'LineWidth',1.8, 'DisplayName','필터 후');
plot(ax1, t, s,  'k--', 'LineWidth',1.0, 'DisplayName','참값 (느린 신호)');
plot(ax2, t, yr-s, 'Color',[.75 .75 .75], 'DisplayName','필터 전 잡음');
plot(ax2, t, yl-s, 'LineWidth',1.4, 'DisplayName','필터 후 잡음');
finishPanel(ax1, ax2, '느린 것은 지나가고 빠른 것은 깎인다', '신호', '잡음만');
saveImg(ax1, 'W04_P4_lowpass_pass.png');   % 블록도 PNG 와 이름을 겹치지 않게

wc = evalin('base','lp_wc');
ws = evalin('base','lp_w_sig');  wn2 = evalin('base','lp_w_noise');

%  통과율은 **그 주파수 성분의 진폭비**로 잰다 (록인 검파). 최대-최소로 재면
%  남은 잡음이 신호 진폭에 섞여 1 을 넘는 값이 나온다
late = t > 5;                                  % 과도응답을 버린다
amp  = @(z, w) abs(2*trapz(t(late), z(late).*exp(-1j*w*t(late)))/(t(end)-5));
gm   = [amp(yl,ws)/amp(yr,ws); amp(yl,wn2)/amp(yr,wn2)];
gh   = [wc/sqrt(wc^2+ws^2);    wc/sqrt(wc^2+wn2^2)];

T = table([ws; wn2], gh, gm, 20*log10(gm), ...
    'VariableNames', {'w_radps','gain_hand','gain_meas','gain_dB'});
T.Properties.RowNames = {'신호(느림)','잡음(빠름)'};
disp(T);
end

% =====================================================================
% 공통
% =====================================================================
function v = fieldOr(s, name, dflt)
if isfield(s, name), v = s.(name); else, v = dflt; end
end

function [ax1, ax2] = twoPanel(name)
figure('Name',name,'Color','w');
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
end

function saveImg(ax, fname)
% 강의노트 그림을 img/ 에 다시 저장한다. gcf 가 아니라 이 패널의 창을 저장한다
f = ancestor(ax, 'figure');
exportgraphics(f, fullfile(fileparts(mfilename('fullpath')), 'img', fname), 'Resolution', 110);
fprintf('그림: img/%s\n', fname);
end

function finishPanel(ax1, ax2, ttl, y1, y2)
title(ax1, ttl);
ylabel(ax1, y1); legend(ax1,'Location','southeast');
ylabel(ax2, y2); xlabel(ax2,'시간 [s]'); legend(ax2,'Location','northeast');
end

function T = metrics(t, y, r, label)
% 스텝이 t = 1 s 에 들어가므로 그 지점부터 잘라서 잰다.
i0  = find(t >= 1, 1);
tt  = t(i0:end) - t(i0);
yy  = y(i0:end);
yf  = yy(end);
S   = stepinfo(yy, tt, yf);
T = table(string(label), yf, max(yy), (max(yy)-yf)/abs(yf)*100, ...
          S.RiseTime, S.SettlingTime, r - yf, ...
    'VariableNames', {'cond','y_ss','y_max','OS_pct','Tr_s','Ts_s','e_ss'});
end

function ts = settle(t, y, target, tol)
% 마지막으로 허용오차 밖에 있던 시각. 구간 시작 시각을 뺀 값을 돌려준다.
idx = find(abs(y - target) > tol*abs(target), 1, 'last');
if isempty(idx), ts = 0; else, ts = t(idx) - t(1); end
end
