% W07_COMPARE  atan2 유도와 LOS 유도를, 조류 유/무로 나누어 한 번에 비교한다.
%
%   과제 7 의 ①번 표를 만드는 스크립트다.
%   >> W07_setup
%   >> W07_compare
%
%   조건을 바꾸려면 아래 CASES 배열만 고치면 된다.

setappdata(0, 'W07_skip_run', true);   % 설정 파일의 자동 실행은 건너뛴다
W07_setup;
animate = 0;                           % 4조건을 연달아 돌리므로 그림은 끈다
load_system('W07_0_offline');

%% 비교할 조건 --------------------------------------------------------
%    이름            유도  조류속도  조류방향
CASES = { ...
    'atan2 / 조류 없음',   1,   0.0,   90; ...
    'LOS   / 조류 없음',   2,   0.0,   90; ...
    'atan2 / 조류 0.5',    1,   0.5,   90; ...
    'LOS   / 조류 0.5',    2,   0.5,   90};

nC = size(CASES,1);
res = struct([]);
traj = cell(nC,1);

for i = 1:nC
    guidance_mode     = CASES{i,2};
    current_speed     = CASES{i,3};
    current_direction = CASES{i,4};
    beta_c            = deg2rad(current_direction);

    o = sim('W07_0_offline','StopTime','700');

    ye = o.log_y_e.Data;  g = o.log_gate.Data;  t = o.log_gate.Time;
    b  = o.log_beta.Data; u = o.log_u.Data;
    k  = find(g < 0.5, 1);
    if isempty(k), tf = NaN; k = numel(t); else, tf = t(k); end
    s  = min(round(60/Ts_ctrl), k);

    res(i).name       = CASES{i,1};
    res(i).mean_ye    = mean(abs(ye(1:k)));
    res(i).mean_ye_ss = mean(abs(ye(s:k)));
    res(i).max_ye     = max(abs(ye(1:k)));
    res(i).t_finish   = tf;
    res(i).mean_beta  = mean(abs(b(s:k)))*180/pi;
    res(i).mean_u     = mean(u(s:k));
    traj{i} = [o.log_pe.Data(1:k), o.log_pn.Data(1:k)];
end

%% 표 ------------------------------------------------------------------
fprintf('\n');
fprintf('%-20s %10s %10s %10s %10s %9s\n', ...
        '조건','mean|ye|','정착후','max|ye|','완주[s]','크랩[deg]');
fprintf('%s\n', repmat('-', 1, 74));
for i = 1:nC
    if isnan(res(i).t_finish), ts = '   미완주'; else, ts = sprintf('%9.1f', res(i).t_finish); end
    fprintf('%-20s %10.3f %10.3f %10.3f %10s %9.2f\n', res(i).name, ...
        res(i).mean_ye, res(i).mean_ye_ss, res(i).max_ye, ts, res(i).mean_beta);
end
fprintf('%s\n', repmat('-', 1, 74));
fprintf('  정착후 = 초기 수렴 60 초를 뺀 평균. 유도법칙 비교에는 이 값을 쓴다\n');
fprintf('  atan2 는 LOS 보다 %.2f 배 (조류 없음), %.2f 배 (조류 있음) 더 벗어난다\n', ...
    res(1).mean_ye_ss / res(2).mean_ye_ss, res(3).mean_ye_ss / res(4).mean_ye_ss);

%% 궤적 겹쳐 그리기 -----------------------------------------------------
figure('Name','W07  유도법칙 비교','Position',[80 60 1000 520],'Color','w');
sty = {'-','-','--','--'};
col = {[0.85 0.33 0.10], [0 0.45 0.74], [0.85 0.33 0.10], [0 0.45 0.74]};

for p = 1:2
    subplot(1,2,p); hold on; grid on; axis equal;
    plot(wp_east, wp_north, 'k--', 'LineWidth',1.2);
    plot(wp_east, wp_north, 'ks', 'MarkerFaceColor','w','MarkerSize',7);
    idx = [1 2] + (p-1)*2;
    for i = idx
        plot(traj{i}(:,1), traj{i}(:,2), sty{i}, 'Color', col{i}, 'LineWidth',1.6);
    end
    xlabel('East [m]'); ylabel('North [m]');
    if p == 1, title('조류 없음'); else, title('조류 0.5 m/s @ 90\circ'); end
    legend([{'계획 경로','웨이포인트'}, res(idx).name], 'Location','best','FontSize',8);
end

%% cross-track error 비교 -----------------------------------------------
figure('Name','W07  cross-track error','Position',[140 120 900 400],'Color','w');
b = bar([res.mean_ye_ss]);
b.FaceColor = 'flat';
b.CData(2,:) = [0 0.45 0.74];  b.CData(4,:) = [0 0.45 0.74];
b.CData(1,:) = [0.85 0.33 0.10]; b.CData(3,:) = [0.85 0.33 0.10];
set(gca, 'XTickLabel', {res.name}); grid on;
ylabel('평균 |y_e| [m]  (정착 후)');
title('유도법칙에 따른 경로 이탈량');
for i = 1:nC
    text(i, res(i).mean_ye_ss, sprintf('%.2f', res(i).mean_ye_ss), ...
         'HorizontalAlignment','center','VerticalAlignment','bottom');
end
