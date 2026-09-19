function W07_sweep(part)
% W07_SWEEP  7주차 1-7 · 1-8 절의 표를 다시 잰다 (오프라인, VRX 불필요).
%
%   >> W07_sweep          % 전부 (약 1~2 분)
%   >> W07_sweep('A')     % 1-7 표 — Delta 스윕, 조류 없음 / 0.4 m/s 동쪽
%   >> W07_sweep('B')     % 1-8 표 — 전환 판정 두 가지 x R x 조류
%   >> W07_sweep('C')     % 1-8 본문 — 조류 방향 여덟 개 (R = 2, 0.8 m/s)
%   >> W07_sweep('D')     % 1-8 R 표 — 수락반경과 모서리 컷
%
%   표의 열
%     수렴      경로 이탈 |y_e| 가 처음으로 1 m 안에 들어온 시각 (첫 전환 전)
%     평균|ye|  초기 60 초를 뺀 평균 |y_e| — W07_plot 의 S.mean_ye_ss 와 같은 값
%     평균|r|   같은 구간의 평균 |요각속도| [deg/s] — 요 모멘트를 얼마나 쓰는가
%     가로지름  같은 구간에서 y_e 의 부호가 바뀐 횟수 — 지그재그
%     전환수    웨이포인트를 넘긴 횟수 (x_e 가 한 번에 5 m 넘게 줄어든 곳)
%
%   W07_setup 의 설정을 base 에 올린 뒤 이 함수 안에서만 조건을 바꾼다.
%   끝나면 W07_setup 을 다시 실행해 기본값으로 돌아간다.

if nargin < 1, part = 'ABCD'; end
here = fileparts(mfilename('fullpath'));  cd(here);
setappdata(0, 'W07_skip_run', true);            % W07_setup 이 시뮬레이션을 돌리지 않게
evalc('evalin(''base'', ''W07_setup'')');
assignin('base','animate',0);
m = 'W07_0_offline';  load_system(m);
c = onCleanup(@() restore());

if any(part == 'A')
    for cs = [0.0 0.4]
        if cs == 0, ttl = '조류 없음'; else, ttl = sprintf('조류 %.1f m/s 동쪽(90°)', cs); end
        fprintf('\n===== A. Delta 스윕 — %s =====\n', ttl);
        fprintf('%6s %10s %10s %12s %10s %10s\n','Delta','수렴[s]','평균|ye|','평균|r|[°/s]','가로지름','완주[s]');
        for d = [2 3 5 10 20 30]
            cfg(cs, 90, d, 5, 1);
            S = run1(m);
            fprintf('%6g %10s %10.3f %12.3f %10d %10s\n', d, num2str(S.t_1m,'%.1f'), ...
                    S.mean_ye_ss, S.mean_r, S.ncross, fin(S));
        end
    end
end

if any(part == 'B')
    fprintf('\n===== B. 전환 판정 (Delta = 10) — 조류 동쪽(90°).  sw 1 = 경로 방향, 2 = 수락 원 =====\n');
    fprintf('%6s %6s %8s %10s %10s %8s\n','R','sw','조류','평균|ye|','완주[s]','전환수');
    for rr = [5 2]
        for cs = [0.0 0.4 0.8]
            for sw = [1 2]
                cfg(cs, 90, 10, rr, sw);
                S = run1(m);
                fprintf('%6g %6d %8.1f %10.3f %10s %8d\n', rr, sw, cs, S.mean_ye_ss, fin(S), S.nsw);
            end
        end
    end
end

if any(part == 'D')
    fprintf('\n===== D. 수락반경 R (Delta = 10, 조류 없음) — 모서리 컷 =====\n');
    fprintf('%6s %14s %20s %10s\n','R','모서리컷[m]','WP2 / WP3 / WP4','완주[s]');
    wpx = evalin('base','wp_north');  wpy = evalin('base','wp_east');
    for rr = [2 5 10 20]
        cfg(0, 90, 10, rr, 1);
        evalc('out = sim(m);');
        xn = out.log_x_n.Data(:);  yn = out.log_y_n.Data(:);
        g  = out.log_gate.Data(:);  t = out.log_gate.Time;
        k  = find(g < 0.5, 1);  if isempty(k), k = numel(t); end
        dmin = zeros(1,3);
        for w = 2:4                               % 모서리 세 개 (출발·도착점 제외)
            dmin(w-1) = min(hypot(xn(1:k) - wpx(w), yn(1:k) - wpy(w)));
        end
        fprintf('%6g %14.2f   %4.2f / %4.2f / %4.2f %10.1f\n', rr, max(dmin), dmin, t(k));   % 셋 중 가장 크게 자른 모서리
    end
end

if any(part == 'C')
    fprintf('\n===== C. 조류 방향 여덟 개 (R = 2 m, 0.8 m/s, Delta = 10) =====\n');
    fprintf('%8s %6s %10s %10s %8s\n','방향[°]','sw','평균|ye|','완주[s]','전환수');
    for dirn = [0 45 90 135 180 225 270 315]
        for sw = [1 2]
            cfg(0.8, dirn, 10, 2, sw);
            S = run1(m);
            fprintf('%8g %6d %10.3f %10s %8d\n', dirn, sw, S.mean_ye_ss, fin(S), S.nsw);
        end
    end
end
end

% ---------------------------------------------------------------------
function cfg(cs, dirn, Delta, R, sw)
assignin('base','current_speed', cs);
assignin('base','current_direction', dirn);
assignin('base','beta_c', deg2rad(dirn));          % 모델이 읽는 것은 이쪽이다
assignin('base','Delta', Delta);
assignin('base','R_LOS', R);
assignin('base','sw_mode', sw);
end

function s = fin(S)
if isnan(S.t_finish), s = '미완주'; else, s = sprintf('%.1f', S.t_finish); end
end

function S = run1(m)
evalc('out = sim(m);');
Ts = evalin('base','Ts_ctrl');
t  = out.log_x_n.Time;  ye = out.log_y_e.Data;  r = out.log_r.Data;
gate = out.log_gate.Data;  xe = out.log_x_e.Data;
k = find(gate < 0.5, 1);
if isempty(k), k = numel(t); S.t_finish = NaN; else, S.t_finish = t(k); end
s = min(round(60/Ts), k);
S.mean_ye_ss = mean(abs(ye(s:k)));
S.mean_r     = mean(abs(r(s:k))) * 180/pi;
sw = find(diff(xe(1:k)) < -5) + 1;  S.nsw = numel(sw);
last1 = k; if ~isempty(sw), last1 = sw(1); end
i1 = find(abs(ye(1:last1)) < 1.0, 1);
if isempty(i1), S.t_1m = NaN; else, S.t_1m = t(i1); end
y = ye(s:k); S.ncross = sum(sign(y(1:end-1)) ~= sign(y(2:end)));
end

function restore()
% 스윕이 바꾼 조건을 W07_setup 기본값으로 되돌린다
setappdata(0, 'W07_skip_run', true);
evalc('evalin(''base'', ''W07_setup'')');
end
