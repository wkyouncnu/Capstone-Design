function T = W06_ladder(stages)
% W06_LADDER  사다리 전체를 한 번에 돌려 **측정표 하나**를 낸다.
%
%     >> W06_ladder            % 1~5·7·8 단 (6단은 Gazebo 가 있어야 돌아감)
%     >> W06_ladder([5 8])     % 두 단계만
%
%   강의노트에 싣는 숫자는 모두 이 스크립트가 찍은 것이다. 손으로 옮긴 값이
%   없도록 한 자리에서 전부 재고 표로 찍는다.
%
%   재는 것
%     완료 시각      gate 가 1 -> 0 으로 떨어진 순간 (정지 게이트가 닫힌 때)
%     단계 전이      phase 래치가 1·2·3 으로 올라간 시각 (접안 단계만 셋)
%     끝 오차        마지막 순간의 위치·선수각 오차. 기준은 **마지막 기준신호**
%                    (log_x_ref·log_y_ref·log_psi_ref 의 끝값) 이다 — 단계마다
%                    목표가 다른데 이 값은 어느 단계에서나 그 단계의 목표다
%     마지막 10 초   같은 오차의 평균 (정상상태로 들어갔는지 본다)
%     빠르기         |u| · |v| · |r| 의 최대
%     추력·회전수    FL · FR · FB 의 최대, |n| 의 최대
%     간 거리        궤적의 길이. 직선거리와 견주면 경로가 얼마나 돌았는지 나온다
%
%   왜 함수인가
%     W06_setup 이 첫 줄에서 base 작업공간을 비운다. 스크립트로 쓰면 단계를
%     도는 루프 변수까지 함께 지워진다. 함수 안에서 evalin('base','W06_setup')
%     으로 부르면 비워지는 것은 base 뿐이고 루프는 살아 있다.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', '_tools'));
cd(here);

if nargin < 1, stages = [1 2 3 4 5 7 8]; end

T = struct([]);
for k = 1:numel(stages)
    s = stages(k);

    %  단계를 고르고, setup 이 끝에서 멋대로 시뮬레이션하지 않게 막는다
    setappdata(0, 'W06_stage', s);
    setappdata(0, 'W06_skip_run', true);
    evalin('base', 'W06_setup');
    mdl = evalin('base', 'mdl');

    if ~exist([mdl '.slx'], 'file')
        T(k).stage = s;  T(k).mdl = mdl;  T(k).ok = false;
        continue;
    end
    out = sim(mdl);

    t    = out.log_x_n.Time;
    x_n  = out.log_x_n.Data;      y_n   = out.log_y_n.Data;
    psi  = out.log_psi.Data;      pref  = out.log_psi_ref.Data;
    xref = out.log_x_ref.Data;    yref  = out.log_y_ref.Data;
    u    = out.log_u.Data;        v     = out.log_v.Data;
    r    = out.log_r.Data;
    gate = out.log_gate.Data;     phase = out.log_phase.Data;
    FL   = out.log_FL.Data;       FR    = out.log_FR.Data;
    FB   = out.log_FB.Data;
    n    = squeeze(out.log_n.Data);
    if size(n,1) ~= numel(t), n = n.'; end

    %  목표는 **마지막 기준신호**다 — 단계마다 다른 목표를 한 식으로 센다
    gx = xref(end);  gy = yref(end);  gpsi = pref(end);
    d    = hypot(gx - x_n, gy - y_n);
    epsi = atan2(sin(gpsi - psi), cos(gpsi - psi)) * 180/pi;
    ss   = find(t >= t(end) - 10, 1);

    j = find(gate < 0.5, 1);
    T(k).stage = s;
    T(k).mdl   = mdl;
    T(k).ok    = true;
    T(k).nsmp  = numel(t);
    if isempty(j), T(k).t_done = NaN; else, T(k).t_done = t(j); end

    T(k).t_phase = nan(1,3);
    for i = 1:3
        jj = find(phase >= i, 1);
        if ~isempty(jj), T(k).t_phase(i) = t(jj); end
    end

    T(k).goal      = [gx gy rad2deg(gpsi)];
    T(k).pose_end  = [x_n(end) y_n(end) rad2deg(psi(end))];
    T(k).e_final   = d(end);
    T(k).epsi_final= epsi(end);
    T(k).e_ss      = mean(d(ss:end));
    T(k).epsi_ss   = mean(abs(epsi(ss:end)));
    T(k).max_u     = max(abs(u));
    T(k).max_v     = max(abs(v));
    T(k).max_r     = max(abs(r)) * 180/pi;
    T(k).max_F     = [max(abs(FL)) max(abs(FR)) max(abs(FB))];
    T(k).max_n     = max(max(abs(n)));
    T(k).s_path    = sum(hypot(diff(x_n), diff(y_n)));
    T(k).s_line    = hypot(gx - x_n(1), gy - y_n(1));
end

%% ====================================================================
%  표 1 — 임무가 어떻게 끝났는가
fprintf('\n================ W06 사다리 측정표 1 · 임무 ================\n');
fprintf('%-14s %7s %7s %7s %7s %9s %9s %9s %9s\n', ...
        '모델','완료[s]','전이1','전이2','전이3','끝오차[m]','끝각[deg]', ...
        '10s[m]','10s[deg]');
for k = 1:numel(T)
    if ~T(k).ok
        fprintf('%-14s   (모델 파일이 없음 — 아직 만들지 않은 단계)\n', T(k).mdl);
        continue;
    end
    fprintf('%-14s %7.2f %7.2f %7.2f %7.2f %9.3f %9.3f %9.3f %9.3f\n', ...
            T(k).mdl, T(k).t_done, T(k).t_phase(1), T(k).t_phase(2), ...
            T(k).t_phase(3), T(k).e_final, T(k).epsi_final, ...
            T(k).e_ss, T(k).epsi_ss);
end

%% ====================================================================
%  표 2 — 배가 무엇을 했는가 (빠르기 · 추력 · 간 거리)
fprintf('\n================ W06 사다리 측정표 2 · 구동 ================\n');
fprintf('%-14s %8s %8s %9s %8s %8s %8s %9s %8s %8s\n', ...
        '모델','|u|max','|v|max','|r|max[°/s]','FL[N]','FR[N]','FB[N]', ...
        '|n|max','간거리[m]','직선[m]');
for k = 1:numel(T)
    if ~T(k).ok, continue; end
    fprintf('%-14s %8.3f %8.3f %9.2f %8.1f %8.1f %8.1f %9.2f %8.2f %8.2f\n', ...
            T(k).mdl, T(k).max_u, T(k).max_v, T(k).max_r, ...
            T(k).max_F(1), T(k).max_F(2), T(k).max_F(3), T(k).max_n, ...
            T(k).s_path, T(k).s_line);
end

%% ====================================================================
%  표 3 — 목표와 끝 자세 (목표를 지켰는지 좌표로 본다)
fprintf('\n================ W06 사다리 측정표 3 · 자세 ================\n');
fprintf('%-14s %26s %26s %7s\n', '모델','목표 (N,E,psi)','끝 (N,E,psi)','표본');
for k = 1:numel(T)
    if ~T(k).ok, continue; end
    fprintf('%-14s %8.3f %8.3f %8.2f   %8.3f %8.3f %8.2f %7d\n', ...
            T(k).mdl, T(k).goal(1), T(k).goal(2), T(k).goal(3), ...
            T(k).pose_end(1), T(k).pose_end(2), T(k).pose_end(3), T(k).nsmp);
end
fprintf('\n');
end
