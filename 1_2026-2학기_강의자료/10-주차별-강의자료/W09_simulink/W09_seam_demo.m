function R = W09_seam_demo()
% W09_SEAM_DEMO  "명령의 나이" 가 왜 안전장치인가 — 가제보 없이 20 초짜리 장면으로 본다.
%
%   >> W09_seam_demo
%
%   장면 — 회피 중(3 s 부터)에 **파이썬 노드가 5 s 에 죽는다.**
%     Subscribe 블록은 마지막 값을 들고 있으므로 oa_flag = 1, psi_oa = -30 도가 그대로 남는다.
%   같은 장면을 이음새 둘에 넣어 견준다
%     A  감시 없음 (깃발만 본다)            -> 낡은 -30 도를 영원히 따라간다
%     B  감시 있음 (깃발 AND Age < 0.5 s)   -> 0.55 s 뒤 LOS 로 되돌아간다
%
%   하는 일 — 모델이 없으면 만들고(build_w09_seam_demo), 돌리고, Scope 를 띄우고,
%   같은 내용을 한글 그림으로 그려 img/W09_seam_demo.png 로 저장한다.
%   ROS · 가제보 · W09_setup 어느 것도 필요 없다.

here = fileparts(mfilename('fullpath'));
m = 'W09_0_seam_demo';
if ~isfile(fullfile(here, [m '.slx'])), build_w09_seam_demo; end
load_system(fullfile(here, [m '.slx']));
out = sim(m);
open_system([m '/Scope']);            % Simulink Scope — 세 칸

sg = out.seam_sig;  ps = out.seam_psi;  yy = out.seam_y;
t  = sg.Time;
isnew = sg.Data(:,1); flag = sg.Data(:,2); age = sg.Data(:,3); oa = sg.Data(:,4);
los = ps.Data(:,1);   refA = ps.Data(:,2); refB = ps.Data(:,3);
yA  = yy.Data(:,1);   yB   = yy.Data(:,2);

R.t_dead   = t(find(isnew < 0.5, 1));              % 메시지가 끊긴 시각
R.t_back   = t(find(t > R.t_dead & oa < 0.5, 1));  % B 가 LOS 로 되돌아간 시각
R.delay    = R.t_back - R.t_dead;                  % = oa_timeout + 한 스텝
R.yA_end   = yA(end);   R.yB_end = yB(end);
R.yB_peak  = min(yB);
R.refA_end = refA(end); R.refB_end = refB(end);

fig = figure('Name','W09 이음새 안전장치', 'Position',[80 60 900 780], 'Color','w');
tl = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');

nexttile; hold on; grid on;
shade(R.t_dead, t(end));
stairs(t, isnew, '-', 'LineWidth',1.6);
stairs(t, flag,  '--', 'LineWidth',1.6);
plot(t, age, '-', 'LineWidth',1.6);
stairs(t, oa, 'k-', 'LineWidth',2.0);
yline(0.5, ':', 'oa\_timeout = 0.5 s');
ylim([-0.1 1.6]); ylabel('값');
legend({'파이썬이 죽은 뒤', 'IsNew (메시지가 오는가)', 'oa\_flag (남은 값)', ...
        'Age [s] — 마지막 명령 뒤 흐른 시간', 'oa = oa\_flag AND (Age < 0.5)'}, ...
       'Location','northwest');
title(sprintf('신호 — %.2f s 에 메시지가 끊기고, %.2f s 뒤(%.2f s)에 oa 가 0 으로 내려간다', ...
      R.t_dead, R.delay, R.t_back));

nexttile; hold on; grid on;
shade(R.t_dead, t(end));
plot(t, los, 'b--', 'LineWidth',1.4);
stairs(t, refA, '-', 'LineWidth',2.0, 'Color',[0.85 0.33 0.10]);
stairs(t, refB, 'k-', 'LineWidth',2.0);
ylim([-40 10]); ylabel('헤딩 명령 [deg]');
legend({'파이썬이 죽은 뒤', 'psi\_los (LOS, 살아 있는 유도)', ...
        'A 감시 없음 — 낡은 -30 도를 계속 쓴다', 'B 감시 있음 — LOS 로 되돌아간다'}, ...
       'Location','southwest');
title('제어기에 들어가는 헤딩 명령 psi\_ref');

nexttile; hold on; grid on;
shade(R.t_dead, t(end));
plot(t, yA, '-', 'LineWidth',2.0, 'Color',[0.85 0.33 0.10]);
plot(t, yB, 'k-', 'LineWidth',2.0);
ylim([1.15*min(yA) 1]);
xlabel('시간 [s]'); ylabel('경로에서 옆으로 밀린 거리 y [m]');
legend({'파이썬이 죽은 뒤', sprintf('A 감시 없음 — %.0f s 에 %.1f m, 계속 멀어진다', t(end), R.yA_end), ...
        sprintf('B 감시 있음 — %.1f m 에서 멈춘다', R.yB_end)}, 'Location','southwest');
title('그래서 배는 어디로 갔는가 (헤딩 1차 지연 T = 2 s, 속력 1.5 m/s)');
title(tl, '명령의 나이(Age)가 없으면 — 죽은 노드의 마지막 명령을 영원히 따라간다');

d = fullfile(here, 'img');  if ~isfolder(d), mkdir(d); end
exportgraphics(fig, fullfile(d, 'W09_seam_demo.png'), 'Resolution', 130);

fprintf('\n  === 이음새 안전장치 — 5 s 에 파이썬이 죽는 장면 ===\n');
fprintf('  메시지가 끊긴 시각          %5.2f s\n', R.t_dead);
fprintf('  B 가 LOS 로 되돌아간 시각   %5.2f s   (끊긴 지 %.2f s = oa_timeout 0.5 s + 한 스텝)\n', R.t_back, R.delay);
fprintf('  끝의 헤딩 명령              A %6.1f deg   B %6.1f deg   (LOS 는 0 deg)\n', R.refA_end, R.refB_end);
fprintf('  끝(%2.0f s)의 옆밀림 y       A %6.2f m     B %6.2f m\n', t(end), R.yA_end, R.yB_end);
fprintf('  그림 저장: img/W09_seam_demo.png\n');
end

function shade(t0, t1)
patch([t0 t1 t1 t0], [-1e3 -1e3 1e3 1e3], [1 0.85 0.85], 'EdgeColor','none', 'FaceAlpha',0.5);
end
