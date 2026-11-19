function R = TP_mission(what, rec_dir)
%TP_MISSION  전 구간을 버튼만으로 — 출발선에서 종료 게이트까지 가상 조종사가 몬다
%
%   R = TP_mission('offline')            오프라인 운동모델로 (경로를 먼저 확인할 때)
%   R = TP_mission('vrx')                가제보에서. 먼저 WSL 에서 월드를 띄우고 배를 풀 것
%   R = TP_mission('vrx', 'C:\tmp\rec')  GCS 창을 2 초(모델 시간)마다 그 폴더에 남긴다 (녹화용)
%
%   가는 길 (요구조건 1 장의 임무 사슬 그대로)
%     ① 출발 → 게이트 여섯 → ② WP1 위치유지 → ③ 도킹 (가운데 베이, **옆걸음**으로 들어갔다 나옴)
%     → ④ 탐색 (빨강 부표를 **우현선회**로 한 바퀴) → ⑤ WP2 위치유지
%     → ⑥ 장애물 구간 (차단벽 넷 사이를 북 → 남 → 북 → 남) → ⑦ 종료 게이트
%
%   **제어기가 아니다.** 사람이 누르는 버튼 여섯(W S A D Q E)을 규칙대로 켜고 끌 뿐이다.
%   들어가는 길도 사람과 같다 — appdata 'TP_pilot' → TP_gcs_keys → ManualPad.
%   그래서 이 주행은 "버튼만으로 이 코스를 물리적으로 지나갈 수 있는가" 의 답이다.
%
%   남기는 것
%     img/TP_mission_<what>.png   끝났을 때의 GCS 화면
%     TP_mission_<what>.csv       항적  t, x_n(북), y_n(동), psi[rad]  (가제보는 참값 위치)
%                                 → python3 ../TP_haeyang/passable.py --track 이 선체 여유를 잰다
%
%   경로의 한 줄 = [북 동 종류 값1 값2]
%     종류 0  지나가는 점      값1 = 이 거리 안에 들면 다음 점 [m],  값2 = 속도 상한 [m/s]
%     종류 1  멈추는 점        값1 = 머무는 시간 [s],                값2 = 속도 상한
%     종류 3  제자리 선회      값1 = 맞출 선수각 [deg]
%     종류 2  옆걸음 (횡이동)  값1 = 지킬 선수각 [deg],              값2 = 도착 뒤 머무는 시간 [s]

if nargin < 1, what = 'offline'; end
if nargin < 2, rec_dir = ''; end
here = fileparts(mfilename('fullpath'));
addpath(here);
is_vrx = strcmpi(what, 'vrx');
m = ['TP_manual_' lower(what)];   load_system(m);

route = mission_route();
mpilot('reset', route, m);
setappdata(0, 'TP_pilot', @mpilot);
evalin('base', 'TP_manual_setup');
Tend = 900;
assignin('base', 'gcs_window', 900);                 % 캡처 한 장에 전 구간이 보이게
assignin('base', 'animate_every', 1.0);              % 긴 주행 — 다시 그리는 간격을 넓혀 모델이 뒤처지지 않게
setappdata(0, 'TP_skip_setup', true);
if ~isempty(rec_dir)
    if ~isfolder(rec_dir), mkdir(rec_dir); end
    setappdata(0, 'TP_rec', struct('dir', rec_dir, 'every', 2.0));
end
si = Simulink.SimulationInput(m);
if is_vrx
    si = si.setModelParameter('StopTime', num2str(Tend));    % 페이싱은 InitFcn 이 RTF 로 맞춘다
else
    si = si.setModelParameter('EnablePacing', 'off', 'StopTime', num2str(Tend));
end
out = sim(si); %#ok<NASGU>
S = TP_gcs('result');
f = TP_gcs();
if ~isempty(f)
    png = fullfile(here, 'img', ['TP_mission_' lower(what) '.png']);
    exportgraphics(f, png, 'Resolution', 110);
    fprintf('  GCS 화면 저장 : %s\n', png);
end
csv = fullfile(here, ['TP_mission_' lower(what) '.csv']);
fid = fopen(csv, 'w');   fprintf(fid, 't,x_n,y_n,psi\n');
fprintf(fid, '%.2f,%.3f,%.3f,%.4f\n', [S.t, S.x_true, S.y_true, S.psi].');
fclose(fid);
fprintf('  항적 저장     : %s  (%d 점)\n', csv, S.n);

R = S;   R.route = route;   R.leg = mpilot('legs');

%% 구간별 시각 — 가상 조종사가 경로의 각 줄을 끝낸 모델 시각
name = {'게이트 6 통과', 'WP1 에서 출발', '도크 앞 정지', '베이 안 도착', '베이에서 나옴', ...
        '빨강 부표 한 바퀴', 'WP2 에서 출발', '장애물 진입 게이트', '종료 게이트 통과·정지'};
idx  = [6, 7, 9, 11, 12, 23, 24, 27, size(route, 1)];
fprintf('\n  구간별 시각 (모델 시간)\n');
for k = 1:numel(idx)
    if idx(k) <= numel(R.leg) && ~isnan(R.leg(idx(k)))
        fprintf('    %-24s t = %6.1f s\n', name{k}, R.leg(idx(k)));
    else
        fprintf('    %-24s (도달하지 못함)\n', name{k});
    end
end

%% 옆걸음 구간의 자세오차와 전후 속도 (요구조건 3-3 절의 문턱 : 자세오차 5 deg, |u| 0.25 m/s)
if numel(R.leg) >= 12 && ~isnan(R.leg(12))
    k = S.t > R.leg(10) & S.t < R.leg(12) - 0.2;
    eh = atan2(sin(S.psi(k) + pi/2), cos(S.psi(k) + pi/2))*180/pi;      % 지킬 선수각 -90 deg (서)
    fprintf('  옆걸음 구간 (t = %.1f ~ %.1f s) : 자세오차 최대 %.1f deg · RMS %.1f deg,  |u| 최대 %.2f m/s\n', ...
            R.leg(10), R.leg(12), max(abs(eh)), sqrt(mean(eh.^2)), max(abs(S.u(k))));
    R.sway = struct('eh_max', max(abs(eh)), 'eh_rms', sqrt(mean(eh.^2)), 'u_max', max(abs(S.u(k))));
end
for a = {'TP_pilot', 'TP_skip_setup', 'TP_rec'}
    if isappdata(0, a{1}), rmappdata(0, a{1}); end
end
end

% =====================================================================
function route = mission_route()
%MISSION_ROUTE  경로표 [북 동 종류 값1 값2].  좌표의 출처는 TP_haeyang/make_haeyang_world.py
%   정지 지점을 위치유지 지점의 **한가운데로 잡지 않는다** — 그 자리에 주황 부표(반지름 0.5 m)가
%   떠 있어 선수가 닿는다. 링(5 m) 안이면서 부표에서 3.5 m 넘게 떨어진 점에 세운다.
gate = [-26.0 0.0; -20.5 2.6; -15.0 2.6; -9.5 0.0; -4.0 -2.6; 1.5 -2.6];
r1 = [gate, zeros(6, 1), 2.0*ones(6, 1), 1.0*ones(6, 1)];                 %  1~6  게이트 여섯
r2 = [  7.5  -2.0  1 14  1.0                                              %  7    WP1 링 안에서 정지
       12.0  -4.5  0  1.5 0.8                                             %  8    WP1 부표를 돌아가는 점
       17.0   0.0  1  1   0.7                                             %  9    도크 앞에서 정지
       17.0   0.0  3 -90  0                                               % 10    서쪽을 보게 돌림
       25.5   0.0  2 -90  5                                               % 11    우현 옆걸음으로 베이 안으로
       17.0   0.0  2 -90  1                                               % 12    좌현 옆걸음으로 나옴
       18.0 -16.0  0  2.0 0.9];                                           % 13    도크 서쪽 모서리를 돌아감
%  빨강 부표 (북 28 · 동 -31) 를 반경 6.5 m 로 우현선회 — 방위가 커지는 쪽(시계방향)으로 돈다
b  = [135 180 225 270 315 0 45 90 135 180].';                             % 14~23
r3 = [28 + 6.5*cosd(b), -31 + 6.5*sind(b), zeros(10, 1), 1.8*ones(10, 1), 0.8*ones(10, 1)];
r4 = [-12.5 -23.5  1 14  0.9];                                            % 24    WP2 링 안에서 정지
%  장애물 구간 — passable.py --path 가 낸 길을 3 m 마다 옮겨 적은 것 (동, 북)
p = [-25.59 -15.00; -28.59 -15.00; -31.42 -15.40; -34.02 -16.37; -36.61 -17.36; -38.57 -19.40
     -39.27 -22.11; -39.22 -25.06; -39.11 -28.02; -39.10 -31.01; -39.42 -33.88; -41.11 -36.15
     -43.68 -37.17; -46.46 -36.68; -48.50 -34.74; -49.26 -32.05; -49.24 -29.10; -49.19 -26.12
     -49.12 -23.15; -49.38 -20.27; -50.98 -17.95; -53.52 -16.84; -56.32 -17.25; -58.42 -19.13
     -59.26 -21.78; -59.25 -24.74; -59.19 -27.72; -59.05 -30.66; -59.23 -33.54; -60.73 -35.92
     -63.22 -37.13; -65.95 -37.80; -68.51 -38.85; -71.45 -39.00];
r5 = [p(:, 2), p(:, 1), zeros(size(p, 1), 1), 1.5*ones(size(p, 1), 1), 0.8*ones(size(p, 1), 1)];   % 25~58
r6 = [-39.0 -74.5  1  3  0.6];                                            % 59    종료 게이트를 지나 정지
route = [r1; r2; r3; r4; r5; r6];
end

% =====================================================================
function k = mpilot(t, s, mdl)
%MPILOT  가상 조종사 — 버튼 여섯을 규칙대로 켜고 끈다
%   s = [t x_n y_n psi u v r FL FR FB X Y N x_true y_true valid]
persistent R i tIn leg model
if ischar(t)
    switch t
        case 'reset', R = s;  i = 1;  tIn = NaN;  leg = nan(size(s, 1), 1);  model = mdl;
        case 'legs',  k = leg;
    end
    return
end
k = zeros(6, 1);
if isempty(R) || numel(s) < 16 || s(16) < 0.5, return; end
if i > size(R, 1)                                % 다 갔다 — 모델을 세운다
    if ~isempty(model)
        try, set_param(model, 'SimulationCommand', 'stop'); catch, end
        model = '';
    end
    return
end

x = s(2);  y = s(3);  psi = s(4);  u = s(5);  v = s(6);  r = s(7);
row = R(i, :);
dx = row(1) - x;   dy = row(2) - y;   d = hypot(dx, dy);
e  = wrap(atan2(dy, dx) - psi);                  % 목표 방위 − 선수각
done = false;

switch row(3)
    case 0                                       % 지나가는 점
        if d < row(4), done = true; else, k = steer(k, e, u, row(5)); end

    case 1                                       % 멈추는 점
        if d > 1.0 && isnan(tIn)
            k = steer(k, e, u, min(row(5), 0.20 + 0.12*d));   % 가까워질수록 천천히
        else
            %  한 번 들어오면 다시 쫓아가지 않는다. 가고 있으면 반대 버튼으로 세우고, 그 뒤로는 둔다
            if u >  0.10, k(2) = 1; end
            if u < -0.10, k(1) = 1; end
            if isnan(tIn), tIn = t; end
            done = t - tIn >= row(4);
        end

    case 3                                       % 제자리 선회 — 선수각을 값1 로
        eh = wrap(row(4)*pi/180 - psi);
        if eh >  4*pi/180 && r <  0.20, k(4) = 1; end
        if eh < -4*pi/180 && r > -0.20, k(3) = 1; end
        if u >  0.06, k(2) = 1; elseif u < -0.06, k(1) = 1; end
        if abs(eh) < 5*pi/180 && abs(r) < 0.05 && abs(u) < 0.10
            if isnan(tIn), tIn = t; end
            done = t - tIn >= 1.0;
        else
            tIn = NaN;
        end

    case 2                                       % 옆걸음 — 선수각을 지킨 채 횡이동
        eh = wrap(row(4)*pi/180 - psi);
        ex =  dx*cos(psi) + dy*sin(psi);         % 목표까지 — 선수 방향 [m]
        ey = -dx*sin(psi) + dy*cos(psi);         % 목표까지 — 우현 방향 [m]
        if eh >  3*pi/180 && r <  0.10, k(4) = 1; end
        if eh < -3*pi/180 && r > -0.10, k(3) = 1; end
        vmax = min(0.5, 0.12 + 0.15*abs(ey));    % 가까워질수록 천천히
        if abs(ey) > 0.5
            if ey > 0 && v <  vmax, k(6) = 1; end
            if ey < 0 && v > -vmax, k(5) = 1; end
        else
            if v >  0.10, k(5) = 1; elseif v < -0.10, k(6) = 1; end
        end
        if     ex >  0.4 && u <  0.12, k(1) = 1;     % 베이 한가운데로 — 앞뒤로 0.4 m 넘게 어긋나면 고친다
        elseif ex < -0.4 && u > -0.12, k(2) = 1;
        elseif u >  0.08, k(2) = 1;
        elseif u < -0.08, k(1) = 1;
        end
        if abs(ey) < 0.8 && abs(ex) < 1.5 && hypot(u, v) < 0.15
            if isnan(tIn), tIn = t; end
            done = t - tIn >= row(5);
        else
            tIn = NaN;
        end
end
if done
    leg(i) = t;   i = i + 1;   tIn = NaN;
end
end

function k = steer(k, e, u, umax)
if e >  8*pi/180, k(4) = 1; end                  % 우선회
if e < -8*pi/180, k(3) = 1; end                  % 좌선회
if abs(e) < 30*pi/180 && u < umax, k(1) = 1; end % 전진 (속도 상한을 넘으면 뗀다)
if abs(e) > 60*pi/180 && u > 0.3, k(2) = 1; end  % 크게 돌아야 하면 먼저 속도를 죽인다
end

function a = wrap(a)
a = atan2(sin(a), cos(a));
end
