function T = W04_ssa_test()
% W04_SSA_TEST  ssa 함수 하나만 시험한다 — 배도 제어기도 없다.
%
%   >> W04_ssa_test
%
%   W04_7_ssa_test 를 한 번 돌려 그림 한 장과 표 세 개를 낸다.
%     ① 쓸어보기   d = psi_ref - psi 를 -540 ~ +540 deg 로 훑는다
%                  ssa 를 거친 값은 **톱니**, 그대로 뺀 값은 **직선**
%     ② 한 점      psi = 170 deg 인 배에 psi_ref = -170 deg (곧 d = -340 deg)
%                  ssa 켜면 +20 deg, 끄면 -340 deg
%     ③ 경계       +-180 deg 에서 정확히 어떻게 접히는가
%
%   왜 함수부터 보는가
%     2-11 의 W04_6_wrap 은 **배가 도는 것**을 본다. 거기에는 게인도 관성도
%     포화도 끼어 있어서, 340 deg 를 도는 것이 ssa 때문인지 다른 것 때문인지
%     한눈에 가려지지 않는다. 이 모델에는 루프가 없다 — 각도를 넣으면 오차가
%     나오고 그것이 전부다.
%
%   만드는 것: img/W04_ssa_sweep.png
%   반환값 T 는 경계 동작 표다.

mdl = 'W04_7_ssa_test';
here = fileparts(mfilename('fullpath'));
evalin('base', 'W04_setup');
load_system(mdl);
out = sim(mdl);

d  = squeeze(out.log_d.Data);        % 차이 [deg]
es = squeeze(out.log_e_ssa.Data);    % ssa 를 거친 오차 [deg]
er = squeeze(out.log_e_raw.Data);    % 그대로 뺀 오차 [deg]

% =====================================================================
% 그림 — 위는 전체, 아래는 +-180 deg 부근 확대
% =====================================================================
f = figure('Name','W04 ssa - 함수만 시험','Color','w','Position',[100 100 900 760]);

ax1 = subplot(2,1,1); hold(ax1,'on'); grid(ax1,'on');
plot(ax1, d, er, 'LineWidth',1.4, 'Color',[0.85 0.33 0.10], ...
     'DisplayName','use\_ssa = 0  (그대로 뺌)');
plot(ax1, d, es, 'LineWidth',1.8, 'Color',[0.00 0.45 0.74], ...
     'DisplayName','use\_ssa = 1  (ssa)');
plot(ax1, [-340 -340], [-360 360], 'k:', 'HandleVisibility','off');
[~, iPt] = min(abs(d + 340));
plot(ax1, d(iPt), es(iPt), 'ko', 'MarkerFaceColor','k', 'HandleVisibility','off');
text(ax1, d(iPt)+15, es(iPt)+40, sprintf('한 점 확인\nd = -340°  ->  %+.0f°', es(iPt)));
xlabel(ax1, '두 각의 차이  d = \psi_{ref} - \psi   [deg]');
ylabel(ax1, '오차 e   [deg]');
title(ax1, 'ssa 는 톱니, 그대로 빼면 직선 — 접히는 자리가 \pm180°');
xlim(ax1, [-540 540]);  ylim(ax1, [-560 560]);
set(ax1, 'XTick', -540:180:540, 'YTick', -540:180:540);
legend(ax1, 'Location','northwest');

ax2 = subplot(2,1,2); hold(ax2,'on'); grid(ax2,'on');
plot(ax2, d, er, 'LineWidth',1.4, 'Color',[0.85 0.33 0.10]);
plot(ax2, d, es, 'LineWidth',1.8, 'Color',[0.00 0.45 0.74]);
xlabel(ax2, '두 각의 차이  d   [deg]  (\pm180° 부근 확대)');
ylabel(ax2, '오차 e   [deg]');
title(ax2, '접히는 순간 — 179.95° 에서 -179.95° 로 359.9° 를 건너뛴다');
xlim(ax2, [170 190]);  ylim(ax2, [-200 200]);
set(ax2, 'XTick', 170:5:190, 'YTick', -180:90:180);

exportgraphics(f, fullfile(here, 'img', 'W04_ssa_sweep.png'), 'Resolution', 110);
fprintf('그림: img/W04_ssa_sweep.png\n');

% =====================================================================
% 표 ① — 한 점 확인. 모델의 Display 두 개에 뜨는 그 숫자다
% =====================================================================
fprintf('\n===== 한 점 확인 — psi = 170 deg 인 배에 psi_ref = -170 deg =====\n');
fprintf('  %-22s %10s\n', '', '오차 [deg]');
fprintf('  %-22s %10.4f\n', 'use_ssa = 1  (ssa)',    es(iPt));
fprintf('  %-22s %10.4f\n', 'use_ssa = 0  (그대로)', er(iPt));
fprintf('  두 값의 차이는 정확히 360 deg 다 (%.4f).\n', es(iPt) - er(iPt));
fprintf('  같은 자리를 가리키지만, 20 deg 를 오른쪽으로 갈 것을\n');
fprintf('  340 deg 왼쪽으로 가라는 말로 바뀐다.\n');

% =====================================================================
% 표 ② — 경계 동작. 정확히 +-180 deg 에서 어느 쪽으로 접히는가
% =====================================================================
pick = [-360 -181 -180.05 -180 -179.95 -90 0 90 179.95 180 180.05 181 360];
nm   = cell(numel(pick),1);  ss = zeros(numel(pick),1);  rr = ss;  dd = ss;
for k = 1:numel(pick)
    [~, i] = min(abs(d - pick(k)));
    dd(k) = d(i);  ss(k) = es(i);  rr(k) = er(i);
    nm{k} = sprintf('%.2f', dd(k));
end
T = table(dd, ss, rr, 'VariableNames', {'d_deg','e_ssa_deg','e_raw_deg'});

fprintf('\n===== 경계 동작 — +-180 deg 에서 어떻게 접히는가 =====\n');
fprintf('  %10s %12s %12s   %s\n', 'd [deg]', 'ssa [deg]', '그대로 [deg]', '');
for k = 1:numel(pick)
    switch nm{k}
        case '180.00',  cmt = '<- 딱 +180. **양수**로 나온다';
        case '-180.00', cmt = '<- 딱 -180. **음수**로 나온다';
        case '180.05',  cmt = '<- 넘는 순간 아래로 접힘';
        case '-180.05', cmt = '<- 넘는 순간 위로 접힘';
        otherwise,      cmt = '';
    end
    fprintf('  %10.2f %12.4f %12.4f   %s\n', dd(k), ss(k), rr(k), cmt);
end

fprintf('\n  읽는 법\n');
fprintf('    |d| < 180 이면 ssa 는 아무것도 하지 않는다 — 두 열이 같다.\n');
fprintf('    |d| > 180 이면 360 을 더하거나 빼서 짧은 쪽으로 돌린다.\n');
fprintf('    딱 +-180 에서는 두 방향의 거리가 같아 어느 쪽이든 맞다.\n');
fprintf('    실제로 나오는 부호는 sin(d) 의 부호가 정한다 —\n');
fprintf('      atan2(sin(+pi), cos(+pi)) = +pi,  atan2(sin(-pi), cos(-pi)) = -pi.\n');
fprintf('    그래서 "(-180, 180] 로 접는다" 고 못 박아 적을 수는 없다.\n');
fprintf('    크기가 180 으로 같으므로 제어에는 차이가 없다.\n');

fprintf('\n배가 실제로 도는 것은 >> W04_wrap_run   (W04_6_wrap)\n');
end
