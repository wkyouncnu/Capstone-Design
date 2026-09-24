function S = W09_offline_run(T_end)
% W09_OFFLINE_RUN  운동모델 + 센서 모델(W09_0_offline)로 수신 주기와 센서 값을 먼저 본다.
%
%   >> W09_setup
%   >> S = W09_offline_run          % VRX 없이 T_end 초 (기본 W09_setup 의 20 초)
%
%   무엇을 보는가 (9주차 1-5 절, 2-8-0)
%     1) 수신 주기 — 센서 모델은 시뮬레이션 시간으로 정확히 20 Hz · 100 Hz 를 낸다.
%        VRX 에서 같은 RateMeter 로 잰 값(2-8-1)은 여기에 RTF 가 곱해진다
%     2) 자이로 잡음 — wz 에서 참값 -r 과 바이어스를 빼고 표준편차를 잰다
%     3) 안테나 위치 — 제자리 선회에서 GPS 위치가 선체 원점 둘레로 그리는 원의 반경
%
%   반환값 S
%     hz_gps, hz_imu   : 마지막 시각의 수신 주기 [Hz]
%     gyro_std         : 자이로 잡음 표준편차 추정 [rad/s]
%     gps_radius       : GPS 안테나가 그린 원의 평균 반경 [m]
%     out              : sim 출력

if nargin < 1 || isempty(T_end), T_end = evalin('base','T_end'); end
model = 'W09_0_offline';
load_system(model);
set_param(model, 'StopTime', num2str(T_end));
fprintf('W09_0_offline 실행 — 좌 %+.0f N / 우 %+.0f N, %g 초 (VRX 없음)\n', ...
        evalin('base','thrust_left'), evalin('base','thrust_right'), T_end);
out = sim(model);

S.out    = out;
S.hz_gps = out.log_hz_gps.Data(end);
S.hz_imu = out.log_hz_imu.Data(end);

% 자이로 — IMU 가 새 값을 낸 스텝만 골라 참값과 비교한다
Ts   = evalin('base','Ts');
nI   = round(1/(evalin('base','hz_design_imu')*Ts));
wz   = squeeze(out.log_wz.Data);
rt   = squeeze(out.log_r_true.Data);
k    = 1:nI:numel(wz);
err  = wz(k) + rt(k) - evalin('base','imu_gyro_bias');
S.gyro_std = std(err(2:end));

% GPS — 위경도를 기준점 기준 m 로 되돌려 원점과의 거리를 잰다
lat  = squeeze(out.log_lat.Data);   lon = squeeze(out.log_lon.Data);
lat0 = evalin('base','lat0');       lon0 = evalin('base','lon0');
a = 6378137.0;  e2 = 6.69437999014e-3;  s2 = sind(lat0)^2;
Rm = a*(1-e2)/(1-e2*s2)^1.5;        Rn = a/sqrt(1-e2*s2);
xg = deg2rad(lat - lat0)*Rm;        yg = deg2rad(lon - lon0)*Rn*cosd(lat0);
xt = squeeze(out.log_x_n_true.Data);  yt = squeeze(out.log_y_n_true.Data);
t  = out.log_lat.Time;
sel = t > 5;
S.gps_radius = mean(hypot(xg(sel) - xt(sel), yg(sel) - yt(sel)));

fprintf('  수신 주기   GPS %.2f Hz, IMU %.2f Hz   (설계 %g / %g Hz)\n', ...
        S.hz_gps, S.hz_imu, evalin('base','hz_design_gps'), evalin('base','hz_design_imu'));
fprintf('  자이로 잡음 표준편차 %.4f rad/s   (설정 %.4f)\n', S.gyro_std, evalin('base','imu_gyro_std'));
fprintf('  GPS 안테나 - 선체 원점 거리 %.3f m   (설정 |gps_x| = %.2f m)\n', ...
        S.gps_radius, hypot(evalin('base','gps_x'), evalin('base','gps_y')));
end
