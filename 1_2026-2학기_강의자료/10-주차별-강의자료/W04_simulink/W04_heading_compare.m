function T = W04_heading_compare(kind)
% W04_HEADING_COMPARE  헤딩 축(3단계)을 조건을 바꿔 가며 돌리고 표와 그림을 낸다.
%
%   W04_heading_compare('open')   개루프 — 계단 모멘트 -> 일정 선회율, 선수각은 안 멈춘다
%   W04_heading_compare('Kp')     P 게인 스윕
%   W04_heading_compare('Kd')     D 게인 스윕 (음수가 브레이크다)
%   W04_heading_compare('Ki')     한쪽 추진기가 약할 때(port_eff) I 가 오차를 지운다
%   W04_heading_compare('wrap')   +-180 deg 이음매 — ssa 를 켜고 끈다 (W04_6_wrap)
%
%   반환값 T 는 측정값 표다. 강의노트와 과제에 그대로 옮겨 적으면 된다.
%   base workspace 의 변수는 건드리지 않는다
%   (Simulink.SimulationInput 으로 그 실행에만 값을 밀어 넣는다).

if nargin < 1, kind = 'open'; end
evalin('base', 'W04_setup');            % 기본값을 base 에 확보한다. sim 은 base 를 본다

switch lower(kind)
    case 'open',  T = sweepOpen();
    case 'kp',    T = sweepGain('Kp_psi', [200 800 2000], struct('Kd_psi',-400), 'Kp_psi');
    case 'kd',    T = sweepGain('Kd_psi', [0 -400 -1000], struct('Kp_psi',800),  'Kd_psi');
    case 'ki',    T = sweepKi();
    case 'wrap',  T = sweepWrap();
    otherwise, error('kind 는 open, Kp, Kd, Ki, wrap 중 하나여야 한다.');
end
end

% =====================================================================
% 개루프 — 제어기를 빼고 계단 모멘트를 준다
%   ① 일정 선회율 r_ss  ② 요 시상수 T_r  ③ 선수각은 멈추지 않는다
% =====================================================================
function T = sweepOpen()
mdl = 'W04_3_heading_offline'; load_system(mdl);
Ns  = [100 300 500];                    % 요 모멘트 [N m]
Iz  = 653; Nr = 800; Nrr = 800;

[ax1, ax2] = twoPanel('W04 헤딩 - 개루프');
rows = cell(numel(Ns),1);
for k = 1:numel(Ns)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('head_open', 1);
    in = in.setVariable('N_open',   Ns(k));
    in = in.setVariable('X_head',   0);   % 전진 추력 0 — 모멘트만 본다
    in = in.setVariable('port_eff', 1);
    out = sim(in);

    t   = out.log_r.Time;
    r   = squeeze(out.log_r.Data);
    psi = rad2deg(unwrap(squeeze(out.log_psi.Data)));
    rss = mean(r(t > t(end)-5));
    i63 = find(abs(r) >= 0.632*abs(rss), 1);
    if isempty(i63), Tr = NaN; else, Tr = t(i63); end

    %  손계산 — dr/dt = 0 이면 (Nr + Nrr|r|) r = N, 그리고 T_r = Iz/(Nr + 2 Nrr |r|)
    rHand = (-Nr + sqrt(Nr^2 + 4*Nrr*Ns(k)))/(2*Nrr);
    THand = Iz/(Nr + 2*Nrr*abs(rHand));

    tag = sprintf('N = %g N·m', Ns(k));
    plot(ax1, t, rad2deg(r), 'LineWidth',1.6, 'DisplayName',tag);
    plot(ax2, t, psi,        'LineWidth',1.6, 'DisplayName',tag);

    rows{k} = table(string(tag), rad2deg(rss), rad2deg(rHand), Tr, THand, ...
                    psi(end)-psi(1), rad2deg(rss)*t(end), ...
        'VariableNames', {'cond','r_ss_degps','r_ss_hand_degps','T_r_s', ...
                          'T_r_hand_s','psi_travel_deg','psi_travel_hand_deg'});
end
finishPanel(ax1, ax2, '제어기 없이 계단 모멘트만 (전진 추력 0)', ...
            '선회율 r [deg/s]', '선수각 psi [deg] — 멈추지 않는다');
saveImg(ax1, 'W04_heading_open.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% 게인 하나만 바꿔 가며 계단응답 — 초기 32.7 deg 에서 psi_ref_deg 로
% =====================================================================
function T = sweepGain(name, values, fixed, label)
mdl = 'W04_3_heading_offline'; load_system(mdl);
fn  = fieldnames(fixed);

[ax1, ax2] = twoPanel(['W04 헤딩 - ' label]);
rows = cell(numel(values),1);
for k = 1:numel(values)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('head_open', 0);
    in = in.setVariable('port_eff',  1);
    in = in.setVariable('Ki_psi',    0);
    for j = 1:numel(fn), in = in.setVariable(fn{j}, fixed.(fn{j})); end
    in = in.setVariable(name, values(k));
    out = sim(in);

    tag = sprintf('%s = %g', name, values(k));
    rows{k} = headingMetrics(out, tag, ax1, ax2);
end
ref = evalin('base','psi_ref_deg');
plot(ax1, [0 40], [ref ref], 'k--', 'DisplayName','목표값');
finishPanel(ax1, ax2, sprintf('%s 만 바꿨을 때 (초기 32.7 deg -> %g deg)', label, ref), ...
            '선수각 psi [deg]', '요 모멘트 N [N·m]');
saveImg(ax1, sprintf('W04_heading_%s.png', label));

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% 한쪽 추진기가 약할 때 — PD 가 남기는 오차를 I 가 지운다
% =====================================================================
function T = sweepKi()
mdl = 'W04_3_heading_offline'; load_system(mdl);
cases = { 1.0,   0, 'port_eff = 1.0, Ki = 0   (정상)'; ...
          0.7,   0, 'port_eff = 0.7, Ki = 0   (PD 만)'; ...
          0.7,  50, 'port_eff = 0.7, Ki = 50'; ...
          0.7, 200, 'port_eff = 0.7, Ki = 200'};

[ax1, ax2] = twoPanel('W04 헤딩 - 약한 추진기와 I');
rows = cell(size(cases,1),1);
for k = 1:size(cases,1)
    in = Simulink.SimulationInput(mdl);
    in = in.setVariable('head_open', 0);
    in = in.setVariable('port_eff', cases{k,1});
    in = in.setVariable('Ki_psi',   cases{k,2});
    in = in.setModelParameter('StopTime', '60');
    out = sim(in);
    rows{k} = headingMetrics(out, cases{k,3}, ax1, ax2);
end
ref = evalin('base','psi_ref_deg');
plot(ax1, [0 60], [ref ref], 'k--', 'DisplayName','목표값');
finishPanel(ax1, ax2, '좌현 추진기를 30 % 약하게 만들면 PD 는 목표를 못 맞춘다', ...
            '선수각 psi [deg]', '요 모멘트 N [N·m]');
saveImg(ax1, 'W04_heading_porteff.png');

T = vertcat(rows{:});  disp(T);
end

% =====================================================================
% +-180 deg 이음매 — ssa 를 켜고 끈다
% =====================================================================
function T = sweepWrap()
mdl = 'W04_6_wrap'; load_system(mdl);
name = {'use_ssa = 1  (최단 방향)','use_ssa = 0  (그냥 빼기)'};

[ax1, ax2] = twoPanel('W04 헤딩 - +-180 deg 이음매');
rows = cell(2,1);
for k = 1:2
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('use_ssa', 2-k);
    out = sim(in);

    t   = out.log_psi.Time;
    psi = rad2deg(unwrap(squeeze(out.log_psi.Data)));
    N   = squeeze(out.log_N.Data);
    r   = rad2deg(squeeze(out.log_r.Data));

    plot(ax1, t, psi, 'LineWidth',1.6, 'DisplayName',name{k});
    plot(ax2, t, N,   'LineWidth',1.6, 'DisplayName',name{k});

    travel = psi(end) - psi(1);
    tgt    = psi(1) + travel;                   % 어느 쪽으로 갔든 도착점
    band   = 0.02*abs(travel);
    idx    = find(abs(psi - tgt) > band, 1, 'last');
    if isempty(idx), ts = 0; else, ts = t(min(idx+1, numel(t))); end

    rows{k} = table(string(name{k}), psi(1), psi(end), travel, ts, max(abs(r)), ...
        'VariableNames', {'cond','psi0_deg','psi_end_deg','travel_deg', ...
                          'Ts2pct_s','r_max_degps'});
end
finishPanel(ax1, ax2, '170 deg 에서 -170 deg 로 — 최단 거리는 20 deg 다', ...
            '선수각 psi [deg] (unwrap)', '요 모멘트 N [N·m]');
saveImg(ax1, 'W04_heading_wrap.png');

T = vertcat(rows{:});  disp(T);
T.ratio = T.travel_deg ./ T.travel_deg(1);
end

% =====================================================================
% 공통
% =====================================================================
function T = headingMetrics(out, tag, ax1, ax2)
t   = out.log_psi.Time;
psi = rad2deg(unwrap(squeeze(out.log_psi.Data)));
N   = squeeze(out.log_N.Data);
ref = evalin('base','psi_ref_deg');

plot(ax1, t, psi, 'LineWidth',1.6, 'DisplayName',tag);
plot(ax2, t, N,   'LineWidth',1.6, 'DisplayName',tag);

psi0 = psi(1);  step = ref - psi0;
os   = 100*max(max((psi - psi0)/step) - 1, 0);
band = 0.02*abs(step);
idx  = find(abs(psi - ref) > band, 1, 'last');
if isempty(idx), ts = 0; else, ts = t(min(idx+1, numel(t))); end
i10 = find((psi-psi0)/step >= 0.1, 1);  i90 = find((psi-psi0)/step >= 0.9, 1);
if isempty(i10) || isempty(i90), tr = NaN; else, tr = t(i90) - t(i10); end

T = table(string(tag), step, os, tr, ts, mean(psi(t > t(end)-5)), ...
          ref - mean(psi(t > t(end)-5)), max(abs(N)), ...
    'VariableNames', {'cond','step_deg','OS_pct','Tr_s','Ts2pct_s', ...
                      'psi_end_deg','e_ss_deg','N_max_Nm'});
end

function [ax1, ax2] = twoPanel(name)
figure('Name',name,'Color','w');
ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
end

function finishPanel(ax1, ax2, ttl, y1, y2)
title(ax1, ttl, 'FontWeight','normal');
ylabel(ax1, y1); legend(ax1,'Location','southeast');
ylabel(ax2, y2); xlabel(ax2,'시간 [s]'); legend(ax2,'Location','northeast');
end

function saveImg(ax, fname)
f = ancestor(ax, 'figure');
exportgraphics(f, fullfile(fileparts(mfilename('fullpath')), 'img', fname), 'Resolution', 110);
fprintf('그림: img/%s\n', fname);
end
