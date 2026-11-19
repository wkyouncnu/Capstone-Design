function R = TP_manual_check(what)
%TP_MANUAL_CHECK  수동 조종 모델의 확인 주행 — 사람 대신 스크립트가 버튼을 누른다
%
%   TP_manual_check('buttons')   버튼 여섯을 하나씩 20 초 누른 결과표 (오프라인, 화면 없이)
%   TP_manual_check('offline')   출발선 → WP1 → WP2 를 오프라인 모델로 (GCS 창을 띄운다)
%   TP_manual_check('vrx')       같은 주행을 가제보에서. 먼저 WSL 에서 월드를 띄우고 배를 풀 것
%
%   왜 스크립트가 누르는가
%     사람이 누른 주행은 다시 해도 같은 숫자가 안 나온다. 문서에 싣는 표는 누가 돌려도
%     같아야 하므로, 정해진 규칙으로 버튼을 누르는 **가상 조종사**를 쓴다.
%     가상 조종사는 사람과 같은 길로 들어온다 — appdata 'TP_pilot' → TP_gcs_keys → ManualPad.
%     즉 유도·제어 블록을 따로 넣은 것이 아니다. 버튼 여섯을 켜고 끌 뿐이다.
%
%   가는 길 — 출발선 → 게이트 여섯의 중심 → WP1 (멈춤) → 돌아가는 점 → WP2 (멈춤)
%     출발선에서 WP1 로 **곧장 가면 둘째 게이트의 초록 부표에 걸린다** (동 −1.9 · 북 −20.5).
%     2026-11-19 첫 VRX 주행이 실제로 그 부표에 얹혀 120 초를 밀고만 있었다.
%     WP1 → WP2 직선도 여섯째 게이트의 초록 부표(동 −7.1 · 북 1.5)를 지난다. 그래서 돌아간다.
%
%   가상 조종사의 규칙 (목표점마다)
%     1) 목표 방위와 선수각의 차가 8° 를 넘으면 그쪽 선회 버튼을 누른다
%     2) 그 차가 30° 안이고 속도가 1.0 m/s 아래면 전진 버튼을 누른다
%     3) 지나가는 점은 2 m 안에 들면 다음 점으로 넘어간다
%     4) 멈추는 점은 3.5 m 안에 들면 전진을 떼고, 아직 가고 있으면 후진 버튼으로 세운다
%        링 안에서 14 초를 머물면 다음 점으로 넘어간다

if nargin < 1, what = 'buttons'; end
here = fileparts(mfilename('fullpath'));
addpath(here);
B = @(v) evalin('base', v);

switch lower(what)
% ---------------------------------------------------------------------
case 'buttons'
    m = 'TP_manual_offline';   load_system(m);
    name = {'전진 (W)', '후진 (S)', '좌선회 (A)', '우선회 (D)', '좌현 횡 (Q)', '우현 횡 (E)'};
    T = 20;
    fprintf('\n버튼 하나를 정지 상태에서 %d 초 누른 뒤의 값 (오프라인 운동모델)\n', T);
    fprintf('  %-12s %7s %7s %7s | %7s %7s %8s | %7s %7s %9s | %8s %8s\n', '버튼', ...
            'F_L[N]', 'F_R[N]', 'F_B[N]', 'X[N]', 'Y[N]', 'N[Nm]', 'u[m/s]', 'v[m/s]', 'r[deg/s]', '북[m]', '동[m]');
    R = zeros(6, 11);
    for k = 1:6
        key = zeros(6, 1);   key(k) = 1;
        setappdata(0, 'TP_pilot', @(t, s) key);
        evalin('base', 'TP_manual_setup');   assignin('base', 'animate', 0);
        setappdata(0, 'TP_skip_setup', true);
        si  = Simulink.SimulationInput(m);
        si  = si.setModelParameter('EnablePacing', 'off', 'StopTime', num2str(T));
        out = sim(si);
        d   = out.log_tp.Data(end, :);
        x0  = B('x0_tp');
        R(k, :) = [d(7:9), d(10:12), d(4), d(5), d(6)*180/pi, d(1) - x0(4), d(2) - x0(5)];
        fprintf('  %-12s %7.1f %7.1f %7.1f | %7.0f %7.0f %8.0f | %+7.3f %+7.3f %+9.2f | %+8.2f %+8.2f\n', ...
                name{k}, R(k, :));
    end
    cleanup();

% ---------------------------------------------------------------------
case {'offline', 'vrx'}
    is_vrx = strcmpi(what, 'vrx');
    m = ['TP_manual_' lower(what)];   load_system(m);
    P = haeyang_points_safe(here);
    wp = [P(2, :); P(3, :)];                         % WP1 · WP2 (북, 동)
    %  [북 동 멈춤]  — 게이트 중심은 make_haeyang_world.py 의 GATES 를 옮겨 적은 것
    route = [-26.0  0.0 0;  -20.5  2.6 0;  -15.0  2.6 0;  -9.5  0.0 0;  -4.0 -2.6 0;  1.5 -2.6 0
             wp(1, :) 1
               8.0 -14.0 0                           % 여섯째 게이트의 초록 부표를 돌아가는 점
             wp(2, :) 1];
    pilot('reset', route);
    setappdata(0, 'TP_pilot', @pilot);
    evalin('base', 'TP_manual_setup');
    Tend = 120;   if is_vrx, Tend = 160; end
    assignin('base', 'gcs_window', Tend);            % 캡처 한 장에 전 구간이 보이게
    setappdata(0, 'TP_skip_setup', true);
    si = Simulink.SimulationInput(m);
    if is_vrx
        si = si.setModelParameter('StopTime', num2str(Tend));    % 페이싱은 InitFcn 이 RTF 로 맞춘다
    else
        si = si.setModelParameter('EnablePacing', 'off', 'StopTime', num2str(Tend));
    end
    w = tic;   out = sim(si);   wall = toc(w);
    S = TP_gcs('result');
    f = TP_gcs();
    if ~isempty(f)
        png = fullfile(here, 'img', ['TP_gcs_' lower(what) '.png']);
        exportgraphics(f, png, 'Resolution', 110);
        fprintf('  GCS 화면 저장 : %s\n', png);
    end
    R = S;   R.wall = wall;   R.log = out.log_tp;
    for k = 1:2
        i = find(hypot(S.x_true - wp(k, 1), S.y_true - wp(k, 2)) <= 5, 1);
        if ~isempty(i), fprintf('  WP%d 링(5 m) 진입 : t = %.1f s\n', k, S.t(i)); end
    end
    cleanup();
otherwise
    error('TP_manual_check:what', '''buttons'' · ''offline'' · ''vrx'' 가운데 하나를 줄 것');
end
end

% =====================================================================
function cleanup()
if isappdata(0, 'TP_pilot'),      rmappdata(0, 'TP_pilot');      end
if isappdata(0, 'TP_skip_setup'), rmappdata(0, 'TP_skip_setup'); end
end

function P = haeyang_points_safe(here)
try
    addpath(fullfile(fileparts(here), 'TP_haeyang'));
    T = haeyang_points();   P = [T.n_m, T.e_m];
catch
    P = [-32 0; 10 0; -14 -20; -39 -70];
end
end

% =====================================================================
function k = pilot(t, s)
%PILOT  가상 조종사 — 버튼 여섯을 규칙대로 켜고 끈다
%   s = [t x_n y_n psi u v r FL FR FB X Y N x_true y_true valid]
persistent wp i tIn
if ischar(t)                                    % pilot('reset', route)
    wp = s;   i = 1;   tIn = NaN;
    return
end
k = zeros(6, 1);
if isempty(wp) || i > size(wp, 1) || numel(s) < 16 || s(16) < 0.5, return; end

x = s(2);  y = s(3);  psi = s(4);  u = s(5);
dx = wp(i, 1) - x;   dy = wp(i, 2) - y;
d  = hypot(dx, dy);
b  = atan2(dy, dx);                             % 목표 방위 (북에서 시계방향)
e  = atan2(sin(b - psi), cos(b - psi));         % 목표 방위 − 선수각
stop_here = wp(i, 3) > 0.5;

if ~stop_here
    if d < 2.0, i = i + 1;  return; end         % 지나가는 점
    k = steer(k, e, u);
else
    if d > 3.5
        k = steer(k, e, u);
    else
        if u >  0.15, k(2) = 1; end             % 가고 있으면 후진으로 세운다
        if u < -0.15, k(1) = 1; end
    end
    if d <= 5
        if isnan(tIn), tIn = t; end
        if t - tIn >= 14, i = i + 1;  tIn = NaN; end
    else
        tIn = NaN;
    end
end
end

function k = steer(k, e, u)
if e >  8*pi/180, k(4) = 1; end                 % 우선회
if e < -8*pi/180, k(3) = 1; end                 % 좌선회
if abs(e) < 30*pi/180 && u < 1.0, k(1) = 1; end % 전진 (1.0 m/s 를 넘으면 뗀다)
end
