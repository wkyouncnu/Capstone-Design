% W06_PSI_SWEEP  목표 선수각을 네 가지로 바꿔 돌려 선수각 고리의 성질을 본다
%
%   >> W06_psi_sweep
%
%   무엇을 보이는가
%     1단 모델에서 목표 위치는 (hold_north, hold_east) 로 두고 **목표 선수각만**
%     바꾼다. 배는 같은 점으로 가지만 서는 방향이 달라진다.
%       45 deg    출발 때 보고 있던 방향과 가깝다 — 거의 안 돌아도 된다
%      -60 deg    반대쪽으로 105 deg 돌아야 한다
%      100 deg    55 deg 돌면 된다
%      -90 deg    135 deg — 네 가지 중 가장 많이 돈다
%
%   보아야 할 것
%     (1) 많이 돌수록 선수각이 자리 잡는 시각이 늦다 — P-D 한 쌍으로만 도는 고리다
%     (2) 그래도 **끝 자세는 모두 목표에 붙는다**. 위치 고리와 선수각 고리가
%         서로 따로 돌기 때문이다 (선수추진기가 횡방향을 맡아 주는 덕이다)
%     (3) 많이 도는 쪽이 요 모멘트를 더 쓰므로 좌·우 추력 차가 커진다
%
%   W06_setup 을 한 번 부른 뒤 이 파일 안에서 psi_d 만 바꾼다. 끝나면
%   W06_setup 을 다시 돌려 기본값(45 deg)으로 돌아간다.
setappdata(0, 'W06_stage', 1);
setappdata(0, 'W06_skip_run', true);
W06_setup
animate = 0;                       % 네 번 도는 동안 실시간 그림은 끈다
load_system(mdl);

PSI = [45 -60 100 -90];            % 목표 선수각 [deg]
col = lines(numel(PSI));
res = cell(1, numel(PSI));

fprintf('\n===== 목표 선수각 스윕 — 1단, 목표 위치 (%g, %g) m 고정 =====\n', ...
        hold_north, hold_east);
fprintf('%8s %10s %12s %12s %12s %12s\n', ...
        'psi_d[°]', '돌 각도[°]', '2° 안 [s]', '끝오차[°]', '최대|r|[°/s]', '최대|FL-FR|[N]');

for i = 1:numel(PSI)
    psi_d     = deg2rad(PSI(i));           %#ok<NASGU>  모델의 Psi_d 상수가 읽는다
    task_q(3) = deg2rad(PSI(i));           %#ok<NASGU>  그림이 읽는 목표 선수각
    out = sim(mdl);

    t    = out.log_psi.Time;
    psi  = rad2deg(out.log_psi.Data);
    err  = rad2deg(atan2(sin(deg2rad(PSI(i)) - out.log_psi.Data), ...
                         cos(deg2rad(PSI(i)) - out.log_psi.Data)));
    %  마지막으로 2 deg 밖에 있던 표본의 다음 표본이 자리 잡은 시각이다
    k = find(abs(err) > 2, 1, 'last');
    if isempty(k) || k >= numel(t), t_set = NaN; else, t_set = t(k+1); end

    res{i} = struct('t', t, 'psi', psi, 'err', err, ...
                    'x', out.log_x_n.Data, 'y', out.log_y_n.Data);
    fprintf('%8g %10.1f %12s %12.3f %12.3f %12.1f\n', PSI(i), ...
            rad2deg(atan2(sin(deg2rad(PSI(i)) - x0(6)), cos(deg2rad(PSI(i)) - x0(6)))), ...
            num2str(t_set, '%.2f'), err(end), max(abs(rad2deg(out.log_r.Data))), ...
            max(abs(out.log_FL.Data - out.log_FR.Data)));
end

figure('Name', 'W06  목표 선수각 스윕', 'Color', 'w', 'Position', [80 80 1000 440]);
subplot(1,2,1);
hold on; grid on;
for i = 1:numel(PSI)
    plot(res{i}.t, res{i}.psi, '-', 'Color', col(i,:), 'LineWidth', 1.5);
    yline(PSI(i), ':', 'Color', col(i,:));
end
xlim([0 60]);
xlabel('시간 [s]'); ylabel('\psi 선수각 [deg]');
legend(arrayfun(@(p) sprintf('\\psi_d = %g°', p), PSI, 'UniformOutput', false), ...
       'Location', 'best');
title('선수각 — 점선이 목표');

subplot(1,2,2);
hold on; grid on; axis equal;
for i = 1:numel(PSI)
    plot(res{i}.y, res{i}.x, '-', 'Color', col(i,:), 'LineWidth', 1.5);
end
plot(hold_east, hold_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
plot(0, 0, 'ko', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title('궤적 — 서는 방향이 달라도 같은 점에 선다');

%  설정을 기본값으로 되돌린다
setappdata(0, 'W06_stage', 1);
setappdata(0, 'W06_skip_run', true);
W06_setup
