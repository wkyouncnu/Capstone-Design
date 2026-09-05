% === 초기 설정 ===
time = simout.tout;

% USV 선박 형상 정의 (Local 기준)
L = 5;  % Length (m)
B = 2;  % Beam (m)
vehx = L * [0.5, 1, 0.5, -1, -1, 0.5]';
vehy = B * [1, 0, -1, -1, 1, 1]';

% 플롯 핸들 초기화
prev_usv_plot = [];
prev_heading_plot = [];
prev_heading_cmd_plot = [];

% 방향선 길이 스케일 설정
scale_factor = 20;  % meter

% === 비디오 저장 설정 ===
video_filename = 'usv_heading_tracking.mp4';
v = VideoWriter(video_filename, 'MPEG-4');
v.FrameRate = 10;
open(v);

% === 지도 figure 생성 ===
% figure;
% geobasemap satellite;
% hold on;

% === 실시간 루프 ===
for t_idx = 1:length(time)
    if mod(time(t_idx), 1) == 0
        % === 현재 선박 상태 ===
        x = simout.y_out(t_idx, 4);     % x (North)
        y = simout.y_out(t_idx, 5);     % y (East)
        psi = simout.y_out(t_idx, 6);   % 현재 heading (rad)
        psi_cmd = simout.psi_cmd(t_idx);  % 목표 heading (rad)

        % === 선박 형상 회전 및 이동 ===
        posx = x + vehx * cos(psi) - vehy * sin(psi);
        posy = y + vehx * sin(psi) + vehy * cos(psi);
        xyzNED = [posx, posy, zeros(length(posx), 1)];

        % === 현재 위치의 중심점 (NED → LLA) ===
        lla_current = ned2lla([x, y, 0], origin, 'flat');
        lat = lla_current(1);
        lon = lla_current(2);

        % === 현재 heading의 목표 위치 계산 (NED → LLA) ===
        x_heading = x + scale_factor * cos(psi);
        y_heading = y + scale_factor * sin(psi);
        lla_heading = ned2lla([x_heading, y_heading, 0], origin, 'flat');
        lat_heading = lla_heading(1);
        lon_heading = lla_heading(2);

        % === 목표 heading 방향 계산 ===
        x_cmd = x + scale_factor * cos(psi_cmd);
        y_cmd = y + scale_factor * sin(psi_cmd);
        lla_cmd = ned2lla([x_cmd, y_cmd, 0], origin, 'flat');
        lat_cmd = lla_cmd(1);
        lon_cmd = lla_cmd(2);

        % === 기존 플롯 제거 ===
        if ~isempty(prev_usv_plot)
            delete(prev_usv_plot);
        end
        if ~isempty(prev_heading_plot)
            delete(prev_heading_plot);
        end
        if ~isempty(prev_heading_cmd_plot)
            delete(prev_heading_cmd_plot);
        end

        % === 선박 형상 변환 (NED → LLA) ===
        lla_shape = ned2lla(xyzNED, origin, 'flat');
        Lat = lla_shape(:,1);
        Lon = lla_shape(:,2);
        prev_usv_plot = geoplot(Lat, Lon, 'w-', 'LineWidth', 1.5);

        % === 현재 heading 표시 (녹색 선) ===
        prev_heading_plot = geoplot([lat, lat_heading], [lon, lon_heading], ...
                                     'g-', 'LineWidth', 2);

        % === 목표 heading 표시 (빨간 점선) ===
        prev_heading_cmd_plot = geoplot([lat, lat_cmd], [lon, lon_cmd], ...
                                         'r--', 'LineWidth', 2);

        % === 비디오 프레임 저장 ===
        drawnow;
        frame = getframe(gcf);
        writeVideo(v, frame);
    end
end

% === 비디오 저장 종료 ===
close(v);
