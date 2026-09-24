% W07_LOOKAHEAD_DEMO  lookahead distance Δ 하나만 바꿔 경로 복귀를 비교한다.
%
%   >> W07_setup
%   >> W07_lookahead_demo
%
%   무엇을 보이는가
%     배는 네 번 모두 **같은 자리에서 같은 만큼 벗어난 채** 출발한다.
%     Δ 만 다르다. Δ 가 짧을수록 경로로 급하게 꺾어 들어오고, 그 대가로
%     경로를 넘어가 반대쪽으로 튀었다가 다시 돌아온다(지그재그).
%     Δ 가 길수록 완만하게 다가오고, 대신 늦게 붙는다.
%
%   왜 첫 구간만 보는가
%     Δ 의 성격은 "벗어난 상태에서 경로로 어떻게 돌아오는가" 에서 가장 뚜렷하다.
%     구간이 바뀌면 웨이포인트 전환과 선회가 섞여 그림이 읽기 어려워진다.
%     그래서 첫 구간(북쪽 80 m)만 잘라서 그린다.
%
%   §1-7 의 표와 같은 조건이다. 조류를 켜고 다시 돌리면 최적 Δ 가 옮겨 간다.

setappdata(0, 'W07_skip_run', true);   % 설정 파일의 자동 실행은 건너뛴다
W07_setup;
animate = 0;                           % 여러 번 연달아 돌리므로 그림은 끈다
load_system('W07_0_offline');

DELTAS = [2 5 10 30];                  % 비교할 lookahead distance [m]
COL    = lines(numel(DELTAS));

%% 네 번 돌린다 — Δ 말고는 아무것도 바꾸지 않는다 ---------------------
sw_mode = 1;                           %#ok<NASGU>  전환 판정은 고정
R_LOS   = 5;                           %#ok<NASGU>
res = struct([]);

for i = 1:numel(DELTAS)
    Delta = DELTAS(i);                 %#ok<NASGU>
    out = sim('W07_0_offline');

    t  = out.log_x_n.Time;
    x_n = out.log_x_n.Data;   y_n = out.log_y_n.Data;
    ye = out.log_y_e.Data;  xe = out.log_x_e.Data;

    %  첫 구간이 끝나는 순간 — 구간이 바뀌면 x_e 가 새 원점에서 다시 시작한다
    k = find(diff(xe) < -5, 1);
    if isempty(k), k = numel(t); end

    res(i).D  = DELTAS(i);
    res(i).t  = t(1:k);
    res(i).x_n = x_n(1:k);   res(i).y_n = y_n(1:k);
    res(i).ye = ye(1:k);

    %  성능 — 첫 구간에서만 잰다
    j = find(abs(ye(1:k)) < 1.0, 1);                 % 처음 1 m 안에 든 시각
    if isempty(j), res(i).t1m = NaN; else, res(i).t1m = t(j); end
    z = find(sign(ye(1:k-1)) ~= sign(ye(2:k)), 1);   % 처음 경로를 가로지른 시각
    if isempty(z)
        res(i).over = 0;                             % 한 번도 넘지 않았다
    else
        res(i).over = max(abs(ye(z:k)));             % 넘어간 뒤의 최대 이탈
    end
    res(i).ncross = sum(sign(ye(1:k-1)) ~= sign(ye(2:k)));
end

%% 그림 --------------------------------------------------------------
h = figure('Name','W07  lookahead distance 비교', ...
           'Position',[80 80 1180 560], 'Color','w');

% ---- 왼쪽: 첫 구간 궤적 ---------------------------------------------
subplot(1,2,1); hold on; grid on; box on;
plot([wp_east(1) wp_east(2)], [wp_north(1) wp_north(2)], 'k--', 'LineWidth', 1.2);
for i = 1:numel(DELTAS)
    plot(res(i).y_n, res(i).x_n, 'LineWidth', 1.6, 'Color', COL(i,:));
end
plot(0, 0, 'ko', 'MarkerFaceColor','w', 'MarkerSize', 7);
text(1.5, -1.5, '출발 (경로에서 20 m)', 'FontSize', 9);
axis equal; ylim([-6 60]); xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
title('첫 구간 궤적 — \Delta 만 다르다');
legend([{'계획 경로'}, arrayfun(@(d) sprintf('\\Delta = %g m', d), DELTAS, ...
        'UniformOutput', false)], 'Location','southeast');

% ---- 오른쪽: 이탈량 ---------------------------------------------------
subplot(1,2,2); hold on; grid on; box on;
yline(0, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
for i = 1:numel(DELTAS)
    plot(res(i).t, res(i).ye, 'LineWidth', 1.6, 'Color', COL(i,:));
end
xlabel('시간 [s]'); ylabel('경로 이탈량  y_e  [m]');
title('짧은 \Delta 는 급하게 붙고 넘어간다');
legend(arrayfun(@(d) sprintf('\\Delta = %g m', d), DELTAS, ...
       'UniformOutput', false), 'Location','northeast');

d = fullfile(fileparts(mfilename('fullpath')), 'img');
if ~isfolder(d), mkdir(d); end
exportgraphics(h, fullfile(d, 'W07_lookahead_demo.png'), 'Resolution', 130);

%% 표 ----------------------------------------------------------------
fprintf('\n===== 첫 구간에서의 경로 복귀 (조류 %g m/s) =====\n', current_speed);
fprintf('%8s %12s %12s %10s\n', 'Delta[m]', '1m 진입[s]', '오버슈트[m]', '가로지름');
for i = 1:numel(DELTAS)
    if isnan(res(i).t1m), s = '미진입'; else, s = sprintf('%.1f', res(i).t1m); end
    fprintf('%8g %12s %12.3f %10d\n', res(i).D, s, res(i).over, res(i).ncross);
end
fprintf('\n짧은 Delta 일수록 빨리 붙지만 더 크게 넘어가고 더 자주 가로지른다.\n');
fprintf('그림: img/W07_lookahead_demo.png\n');
