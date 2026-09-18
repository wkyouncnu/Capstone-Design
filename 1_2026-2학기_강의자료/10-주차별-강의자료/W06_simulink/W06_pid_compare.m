function T = W06_pid_compare(kind)
% W06_PID_COMPARE  게인이나 옵션을 바꿔 가며 여러 번 돌리고 한 그림에 겹쳐 그린다.
%
%   W06_pid_compare('Kp')     P 만 키운다                 (W06_P1_pid_step)
%   W06_pid_compare('Kd')     P 는 두고 D 를 더한다        (W06_P1_pid_step)
%   W06_pid_compare('Ki')     PD 에 I 를 더한다            (W06_P1_pid_step)
%   W06_pid_compare('hand')   직접 만든 PID vs 라이브러리   (W06_P2_pid_byhand)
%   W06_pid_compare('D')      미분 필터 Nf 를 푼다         (W06_P2_pid_byhand)
%   W06_pid_compare('AW')     안티와인드업 유무            (W06_P2_pid_byhand)
%   W06_pid_compare('boat')   배에서 안티와인드업 유무      (W06_P3_boat_speed)
%
%   반환값 T 는 측정값 표다. 과제에 그대로 옮겨 적으면 된다.
%
%   base workspace 의 변수는 건드리지 않는다.
%   (Simulink.SimulationInput 으로 그 실행에만 값을 밀어 넣는다)

if nargin < 1, kind = 'Kp'; end
evalin('base', 'W06_pid_setup');   % 기본값을 base 에 확보한다. sim 은 base 를 본다

switch lower(kind)
    case 'kp',   T = sweepP1('Kp', [2 10 50],  struct('Ki',0,'Kd',0),  'P 게인');
    case 'kd',   T = sweepP1('Kd', [0 2 6],    struct('Kp',10,'Ki',0), 'D 게인');
    case 'ki',   T = sweepP1('Ki', [0 4 12],   struct('Kp',10,'Kd',4), 'I 게인');
    case 'hand', T = compareHand();
    case 'd',    T = sweepFilter();
    case 'aw',   T = sweepAW();
    case 'boat', T = sweepBoat();
    otherwise,   error('kind 는 Kp, Kd, Ki, hand, D, AW, boat 중 하나여야 한다.');
end
end

% =====================================================================
% P1 — 게인 하나만 바꿔 가며 스텝응답 비교
% =====================================================================
function T = sweepP1(name, values, fixed, label)
mdl = 'W06_P1_pid_step'; load_system(mdl);
fn  = fieldnames(fixed);

[ax1, ax2] = twoPanel(['W06 PID - ' label]);
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

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P2 — 직접 만든 PID 가 라이브러리 블록과 같은가
% =====================================================================
function T = compareHand()
mdl = 'W06_P2_pid_byhand'; load_system(mdl);
out = sim(Simulink.SimulationInput(mdl));

t  = out.log_y_lib.Time;
yl = squeeze(out.log_y_lib.Data);   ul = squeeze(out.log_tau_lib.Data);
yh = squeeze(out.log_y_hand.Data);  uh = squeeze(out.log_tau_hand.Data);

[ax1, ax2] = twoPanel('W06 PID - 직접 만든 것 vs 라이브러리');
plot(ax1, t, yl, 'LineWidth',2.4, 'DisplayName','라이브러리 PID 블록');
plot(ax1, t, yh, '--', 'LineWidth',1.6, 'DisplayName','직접 만든 PID');
plot(ax2, t, ul, 'LineWidth',2.4, 'DisplayName','라이브러리 PID 블록');
plot(ax2, t, uh, '--', 'LineWidth',1.6, 'DisplayName','직접 만든 PID');
finishPanel(ax1, ax2, '두 곡선이 겹치면 블록 안의 것과 같다', '출력 y', '제어입력 τ');

T = table(max(abs(yl-yh)), max(abs(ul-uh)), ...
    'VariableNames', {'y_max_abs_diff','tau_max_abs_diff'});
disp(T);
end

% =====================================================================
% P2 — 미분 필터 계수를 풀면 제어입력이 어떻게 되는가
% =====================================================================
function T = sweepFilter()
mdl = 'W06_P2_pid_byhand'; load_system(mdl);
Nlist = [5 20 200];

[ax1, ax2] = twoPanel('W06 PID - 미분 필터');
rows = cell(numel(Nlist),1);
for k = 1:numel(Nlist)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Nf2', Nlist(k));
    out = sim(in);
    t = out.log_y_hand.Time;
    y = squeeze(out.log_y_hand.Data);  u = squeeze(out.log_tau_hand.Data);

    tag = sprintf('Nf = %g', Nlist(k));
    plot(ax1, t, y, 'LineWidth',1.4, 'DisplayName',tag);
    plot(ax2, t, u, 'LineWidth',1.0, 'DisplayName',tag);

    mk = metrics(t, y, evalin('base','r_step'), tag);
    mk = addvars(mk, max(abs(diff(u))), 'NewVariableNames', {'dtau_max'});
    mk = addvars(mk, std(u(t > t(end)*0.5)), 'NewVariableNames', {'tau_std'});
    rows{k} = mk;
end
finishPanel(ax1, ax2, '미분 필터 계수 Nf — 클수록 순수 미분에 가깝다', ...
            '출력 y', '제어입력 τ');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P2 — 포화에 걸렸을 때 안티와인드업 유무 (되감기 이득 Kb)
% =====================================================================
function T = sweepAW()
mdl = 'W06_P2_pid_byhand'; load_system(mdl);
Kbs  = [0 2];
name = {'Kb = 0  (안티와인드업 없음)','Kb = 2  (되감기 켬)'};

[ax1, ax2] = twoPanel('W06 PID - 안티와인드업');
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

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% P3 — 배에서 안티와인드업 유무
% =====================================================================
function T = sweepBoat()
mdl = 'W06_P3_boat_speed'; load_system(mdl);
Kbs  = [0 2];
name = {'Kb_u = 0  (안티와인드업 없음)','Kb_u = 2  (되감기 켬)'};

[ax1, ax2] = twoPanel('W06 PID - 배 속도 제어');
rows = cell(numel(Kbs),1);
for k = 1:numel(Kbs)
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('Kb_u', Kbs(k));
    out = sim(in);

    t = out.log_u.Time;
    u = squeeze(out.log_u.Data);
    X = squeeze(out.log_X.Data);

    plot(ax1, t, u, 'LineWidth',1.6, 'DisplayName',name{k});
    plot(ax2, t, X, 'LineWidth',1.6, 'DisplayName',name{k});

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

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% 공통
% =====================================================================
function [ax1, ax2] = twoPanel(name)
figure('Name',name,'Color','w');
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
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
