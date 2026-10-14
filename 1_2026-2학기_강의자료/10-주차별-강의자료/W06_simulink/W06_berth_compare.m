function W06_berth_compare()
% W06_BERTH_COMPARE  접안 세 가지를 같은 선석에 붙여 보고 숫자로 견준다
%
%   >> W06_berth_compare
%
%   무엇을 견주는가 — 선석도 접근점도 같고, 마지막에 붙이는 방법만 다르다
%     5단  옆걸음 접안   선석 방위로 선 채 옆으로 붙는다   (선체고정 위치제어)
%     7단  전진 접안     선수를 선석으로 돌려 앞으로 민다  (선체고정 위치제어)
%     8단  NED 접안      붙이는 방법은 5단과 같고, 위치제어를 북·동 축에서 한다
%
%   표의 열
%     완료[s]     gate 가 0 으로 떨어진 시각 (AutoStop 이 센다)
%     끝오차[m]   마지막 표본의 목표 자세까지 거리 — R_stop 안이어야 한다
%     최대|v|     옆으로 낸 속도. 옆걸음(5·8)이 전진(7)보다 커야 앞뒤가 맞는다
%     최대|F_B|   선수추진기가 쓴 힘 — 전진 접안에서 작아야 한다
%     최대|F_L,R| 선미 추진기. 전진 접안이 한계(F_max)에 더 가까이 붙는다
%     간거리[m]   실제로 지나온 길이. 돌아가는 몫이 여기 드러난다
%
%   W06_setup 이 base 를 비우므로 함수로 둔다 (W06_ladder · W06_shots 과 같다).

here = fileparts(mfilename('fullpath'));
cd(here);

ST  = [5 7 8];
nm  = {'5단 옆걸음', '7단 전진', '8단 NED'};
col = [0 0.45 0.74; 0.85 0.33 0.10; 0.47 0.67 0.19];
R   = cell(1, numel(ST));

fprintf('\n===== 접안 세 가지 비교 =====\n');
fprintf('%-12s %9s %10s %11s %11s %12s %11s\n', ...
        '전략', '완료[s]', '끝오차[m]', '최대|v|', '최대|F_B|', '최대|F_L,R|', '간거리[m]');

for k = 1:numel(ST)
    setappdata(0, 'W06_stage', ST(k));
    setappdata(0, 'W06_skip_run', true);
    evalc('evalin(''base'', ''W06_setup'')');
    assignin('base', 'animate', 0);
    mdl = evalin('base', 'mdl');
    if ~exist([mdl '.slx'], 'file')
        fprintf('%-12s  %s.slx 가 없다 — build_w06_models 를 먼저 돌릴 것\n', nm{k}, mdl);
        continue
    end

    out = sim(mdl);
    S   = evalc_plot(out, nm{k});

    x_n = out.log_x_n.Data;   y_n = out.log_y_n.Data;
    R{k} = struct('x', x_n, 'y', y_n, 't', out.log_x_n.Time, ...
                  'v', out.log_v.Data, 'FB', out.log_FB.Data);
    fprintf('%-12s %9s %10.3f %11.3f %11.1f %12.1f %11.2f\n', nm{k}, ...
            num2str(S.t_done, '%.2f'), S.e_final, S.max_v, S.max_FB, ...
            max([abs(out.log_FL.Data); abs(out.log_FR.Data)]), ...
            sum(hypot(diff(x_n), diff(y_n))));
end

%  세 궤적을 한 그림에 겹친다 — 선석과 접근점은 세 단계가 모두 같다
dock_north = evalin('base', 'dock_north');   dock_east = evalin('base', 'dock_east');
app_north  = evalin('base', 'app_north');    app_east  = evalin('base', 'app_east');
R_stop     = evalin('base', 'R_stop');

fig = figure('Name', 'W06  접안 세 가지', 'Color', 'w', 'Position', [60 80 1340 430]);
subplot(1,3,1); hold on; grid on; axis equal;
for k = 1:numel(ST)
    if isempty(R{k}), continue; end
    plot(R{k}.y, R{k}.x, '-', 'Color', col(k,:), 'LineWidth', 1.6);
end
th = linspace(0, 2*pi, 90);
plot(dock_east + R_stop*cos(th), dock_north + R_stop*sin(th), 'k:');
plot(dock_east, dock_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
plot(app_east,  app_north,  'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
plot(0, 0, 'ko', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend([nm, {'R_{stop}', '선석', '접근점', '출발'}], 'Location', 'southeast', 'FontSize', 7.5);
title('접안 궤적 — 선석도 접근점도 같다');

%  차이는 마지막 L_app 구간에만 있다 — 그 자리를 따로 크게 본다
subplot(1,3,2); hold on; grid on; axis equal;
for k = 1:numel(ST)
    if isempty(R{k}), continue; end
    plot(R{k}.y, R{k}.x, '-', 'Color', col(k,:), 'LineWidth', 1.6);
end
plot(dock_east + R_stop*cos(th), dock_north + R_stop*sin(th), 'k:');
plot(dock_east, dock_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
plot(app_east,  app_north,  'ko', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
L_app = evalin('base', 'L_app');
xlim(dock_east  + [-0.35 1.25]*L_app);
ylim(dock_north + [-0.8  0.8 ]*L_app);
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title('선석 부근 — 붙이는 방법이 갈린다');

subplot(1,3,3); hold on; grid on;
for k = 1:numel(ST)
    if isempty(R{k}), continue; end
    plot(R{k}.t, R{k}.FB, '-', 'Color', col(k,:), 'LineWidth', 1.6);
end
xlabel('시간 [s]'); ylabel('F_B 선수추진기 [N]');
legend(nm, 'Location', 'best', 'FontSize', 8);
title('선수 추력 — 전진 접안이 가장 적게 쓴다');

if ~isfolder(fullfile(here, 'img')), mkdir(fullfile(here, 'img')); end
print(fig, '-dpng', '-r110', fullfile(here, 'img', 'W06_berth_compare.png'));
fprintf('\n  그림 저장: img/W06_berth_compare.png\n');
end

% =====================================================================
function S = evalc_plot(out, ttl)
%  W06_plot 은 지표를 스스로 찍는다. 표를 가리지 않도록 그 출력만 삼킨다
evalc('S = W06_plot(out, ttl);');
close(S.fig);
end
