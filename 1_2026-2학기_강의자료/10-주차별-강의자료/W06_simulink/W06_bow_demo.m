% W06_BOW_DEMO  선수추진기를 끄면 옆으로 못 간다 — 6주차에서 가장 중요한 그림
%
%   >> W06_bow_demo
%
%   무엇을 보이는가
%     2단(순수 횡이동) 모델을 bow_on 만 바꿔 두 번 돌린다.
%       bow_on = 1   선수각을 0 deg 로 묶은 채 동쪽 12 m 를 옆걸음으로 간다
%       bow_on = 0   횡력 지령이 InnerLoop 의 게인에서 끊긴다 — 5주차의 배다
%
%   왜 bow_on = 0 이면 못 가는가
%     추진기가 좌·우 둘뿐이면 낼 수 있는 힘은 전후(X)와 요(N) 두 가지다.
%     횡(Y)은 배분식에서 F_B 하나가 맡는다 — 그 항이 0 이 되면 동쪽 오차를
%     줄일 방법이 없다. 선수각을 묶어 두었으므로 돌아서 갈 수도 없다.
%     (5주차의 배가 접안을 못 하는 까닭이 이것이다)
%
%   이 그림이 6주차의 출발점이다. 추진기 하나가 늘면 무엇이 되는가에 대한
%   대답을 숫자로 보여 준다.
setappdata(0, 'W06_stage', 2);
setappdata(0, 'W06_skip_run', true);
W06_setup
animate = 0;                       % 두 번 도는 동안 실시간 그림은 끈다
load_system(mdl);

BOW = [1 0];
res = cell(1, numel(BOW));

fprintf('\n===== 선수추진기 켬/끔 — 2단, 목표 (%g, %g) m / %g deg =====\n', ...
        sway_north, sway_east, sway_deg);
fprintf('%8s %12s %12s %12s %12s %12s\n', ...
        'bow_on', '끝 동쪽[m]', '남은오차[m]', '최대|v|[m/s]', '최대|F_B|[N]', '선수각벗어남[°]');

for i = 1:numel(BOW)
    bow_on = BOW(i);                       %#ok<NASGU>  InnerLoop 의 BowOn 게인이 읽는다
    out = sim(mdl);

    y_n = out.log_y_n.Data;
    res{i} = struct('t', out.log_y_n.Time, 'x', out.log_x_n.Data, 'y', y_n, ...
                    'v', out.log_v.Data, 'FB', out.log_FB.Data, ...
                    'psi', rad2deg(out.log_psi.Data));
    fprintf('%8d %12.3f %12.3f %12.3f %12.1f %12.3f\n', BOW(i), y_n(end), ...
            hypot(sway_north - out.log_x_n.Data(end), sway_east - y_n(end)), ...
            max(abs(out.log_v.Data)), max(abs(out.log_FB.Data)), ...
            max(abs(rad2deg(out.log_psi.Data) - sway_deg)));
end

figure('Name', 'W06  선수추진기 켬/끔', 'Color', 'w', 'Position', [80 80 1000 760]);

subplot(2,2,1);
plot(res{1}.y, res{1}.x, 'b-', 'LineWidth', 1.8); hold on;
plot(res{2}.y, res{2}.x, 'r-', 'LineWidth', 1.8);
plot(sway_east, sway_north, 'ks', 'MarkerFaceColor', 'w', 'MarkerSize', 9);
plot(0, 0, 'ko', 'MarkerFaceColor', 'g', 'MarkerSize', 8);
axis equal; grid on;
xlabel('y (동쪽) [m]'); ylabel('x (북쪽) [m]');
legend({'bow\_on = 1', 'bow\_on = 0', '목표', '출발'}, 'Location', 'best');
title('궤적 — 끄면 제자리를 못 벗어난다');

subplot(2,2,2);
plot(res{1}.t, sway_east - res{1}.y, 'b-', 'LineWidth', 1.6); hold on;
plot(res{2}.t, sway_east - res{2}.y, 'r-', 'LineWidth', 1.6);
grid on; xlabel('시간 [s]'); ylabel('동쪽 오차 [m]');
title('동쪽 오차 — 끄면 12 m 가 줄지 않는다');

subplot(2,2,3);
plot(res{1}.t, res{1}.v, 'b-', 'LineWidth', 1.6); hold on;
plot(res{2}.t, res{2}.v, 'r-', 'LineWidth', 1.6);
grid on; xlabel('시간 [s]'); ylabel('v 횡방향 속도 [m/s]');
title(sprintf('횡방향 속도 (v\\_max = %g m/s)', v_max));

subplot(2,2,4);
plot(res{1}.t, res{1}.FB, 'b-', 'LineWidth', 1.6); hold on;
plot(res{2}.t, res{2}.FB, 'r-', 'LineWidth', 1.6);
yline( F_bow_max, 'k:');  yline(-F_bow_max, 'k:');
grid on; xlabel('시간 [s]'); ylabel('F_B 선수추진기 [N]');
title('선수 추력 — 끄면 0 이다');

%  설정을 기본값(bow_on = 1)으로 되돌린다
setappdata(0, 'W06_stage', 2);
setappdata(0, 'W06_skip_run', true);
W06_setup
