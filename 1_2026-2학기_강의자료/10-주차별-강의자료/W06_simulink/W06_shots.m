function W06_shots(stages)
% W06_SHOTS  단계별 결과 그림을 img/ 에 찍는다 — 강의노트가 쓰는 그림이다.
%
%     >> W06_shots            % 1~5·7·8 단
%     >> W06_shots(8)         % 8단만
%
%   만드는 것
%     img/W06_r1_point.png  …  img/W06_r8_ned.png    단계별 결과 여섯 칸
%     img/W06_r5_vs_8.png                            선체고정 대 NED 겹쳐 보기
%
%   그림의 속은 W06_plot 이 그린다. 이 스크립트가 하는 일은 단계를 돌려
%   그 그림을 파일로 내리는 것뿐이다 — 노트에 붙는 그림과 학생이 직접
%   돌려 보는 그림이 **같은 코드**에서 나와야 숫자가 어긋나지 않는다.
%
%   함수인 까닭은 W06_ladder 와 같다 (W06_setup 이 base 를 비운다).

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', '_tools'));
cd(here);
if ~exist(fullfile(here,'img'), 'dir'), mkdir(fullfile(here,'img')); end

if nargin < 1, stages = [1 2 3 4 5 7 8]; end

nm  = {'1_point','2_sway','3_thrust','4_stop','5_dock','6_vrx','7_front','8_ned'};
ttl = {'1단 · 목표 자세로 가서 선다', '2단 · 순수 횡이동', ...
       '3단 · 추진기 동역학',         '4단 · 도착 판정과 정지', ...
       '5단 · 접안 (옆걸음)',         '6단 · Gazebo 연동', ...
       '7단 · 전진 접안',             '8단 · NED 좌표계 접안'};

C = cell(1,8);
for k = 1:numel(stages)
    s = stages(k);
    setappdata(0, 'W06_stage', s);
    setappdata(0, 'W06_skip_run', true);
    evalin('base', 'W06_setup');
    mdl = evalin('base', 'mdl');
    if ~exist([mdl '.slx'], 'file'), continue; end

    out = sim(mdl);
    S   = W06_plot(out, ttl{s});
    f   = fullfile(here, 'img', ['W06_r' nm{s} '.png']);
    print(S.fig, '-dpng', '-r110', f);
    close(S.fig);
    d = dir(f);
    fprintf('  %-24s  %6.1f KB\n', ['W06_r' nm{s} '.png'], d.bytes/1024);

    %  5·8 단은 뒤에서 겹쳐 그리므로 신호를 남겨 둔다
    C{s} = struct('t', out.log_x_n.Time, 'x', out.log_x_n.Data, ...
                  'y', out.log_y_n.Data, 'u', out.log_u.Data, ...
                  'v', out.log_v.Data,   'FB', out.log_FB.Data, ...
                  'FL', out.log_FL.Data, 'FR', out.log_FR.Data);
end

%% ====================================================================
%  선체고정(5단) 대 NED(8단) — 같은 과업, 제어 좌표계만 다르다
if isempty(C{5}) || isempty(C{8}), return; end
A = C{5};  B = C{8};
q = evalin('base','task_q');

fig = figure('Name','W06  선체고정 대 NED', 'Position',[80 60 1250 460], 'Color','w');

subplot(1,3,1);
plot(A.y, A.x, 'b-', 'LineWidth',1.6); hold on;
plot(B.y, B.x, 'r-', 'LineWidth',1.6);
plot(q(8), q(7), 'ks', 'MarkerFaceColor','w', 'MarkerSize',11, 'LineWidth',1.6);
axis equal; grid on; xlabel('동쪽 y_n [m]'); ylabel('북쪽 x_n [m]');
legend({'5단 선체고정','8단 NED','선석'}, 'Location','southeast', 'FontSize',8);
title('궤적 — NED 쪽이 더 곧다');

subplot(1,3,2);
plot(A.t, hypot(A.u, A.v), 'b-', 'LineWidth',1.4); hold on;
plot(B.t, hypot(B.u, B.v), 'r-', 'LineWidth',1.4);
grid on; xlabel('시간 [s]'); ylabel('빠르기 |U| [m/s]');
legend({'5단 선체고정','8단 NED'}, 'Location','northeast', 'FontSize',8);
title('빠르기 — NED 는 벡터 크기로 묶임');

subplot(1,3,3);
plot(A.t, abs(A.FB), 'b-', 'LineWidth',1.4); hold on;
plot(B.t, abs(B.FB), 'r-', 'LineWidth',1.4);
grid on; xlabel('시간 [s]'); ylabel('|F_B| [N]');
legend({'5단 선체고정','8단 NED'}, 'Location','northeast', 'FontSize',8);
title('선수추진기 힘');

f = fullfile(here, 'img', 'W06_r5_vs_8.png');
print(fig, '-dpng', '-r110', f);
close(fig);
d = dir(f);
fprintf('  %-24s  %6.1f KB\n', 'W06_r5_vs_8.png', d.bytes/1024);

%  겹쳐 보기에서 재는 값 — 노트에 싣는 숫자다
fprintf('\n  5단 끝 %6.2f s  |U|max %5.3f m/s  간거리 %6.2f m\n', ...
        A.t(end), max(hypot(A.u,A.v)), sum(hypot(diff(A.x), diff(A.y))));
fprintf('  8단 끝 %6.2f s  |U|max %5.3f m/s  간거리 %6.2f m\n', ...
        B.t(end), max(hypot(B.u,B.v)), sum(hypot(diff(B.x), diff(B.y))));
end
