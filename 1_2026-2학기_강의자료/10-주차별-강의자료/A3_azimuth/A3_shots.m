function A3_shots()
% A3_SHOTS  강의노트에 붙는 결과 그림을 img/ 에 찍는다
%
%     >> A3_shots
%
%   만드는 것
%     img/A3_r1_crab.png     1단 순수 횡이동 (기준)
%     img/A3_r1_cur.png      1단 + 조류 0.6 m/s · 45 deg
%     img/A3_r2_pose.png     2단 위치·선수각 유지
%     img/A3_r3_dock.png     3단 단계 전이 접안
%     img/A3_r3_direct.png   3단 단계를 나누지 않음 (dock_on = 0) — 깨지는 경우
%     img/A3_r4_norev.png    1단 + 추력 반전 금지        — 깨지는 경우
%     img/A3_r4_d15.png      1단 + 각도 한계 ±15 deg     — 깨지는 경우
%     img/A3_env.png         ±45 deg 도달 가능 집합 (세 칸)
%
%   그림의 속은 A3_plot · A3_envelope 이 그린다. 이 파일이 하는 일은 설정을
%   깔고 돌려 그 그림을 파일로 내리는 것뿐이다 — 노트에 붙는 그림과 학생이
%   직접 돌려 보는 그림이 **같은 코드**에서 나와야 숫자가 어긋나지 않는다.
%
%   함수인 까닭 — A3_setup 은 스크립트다. 함수 안에서 부르면 설정이 함수
%   워크스페이스에 갇히므로, 모델이 읽는 base 워크스페이스에 깔리게
%   evalin('base', ...) 으로 부른다.
here = fileparts(mfilename('fullpath'));
cd(here);
if ~exist(fullfile(here,'img'), 'dir'), mkdir(fullfile(here,'img')); end

%  이름, 단, 덮어쓸 값, 그림 제목
C = { ...
 'r1_crab',   1, struct(), ...
              '1단 · 순수 횡이동 (기준)';
 'r1_cur',    1, struct('current_speed',0.6, 'current_direction',45, ...
                        'crab_east',20, 'T_run',150), ...
              '1단 · 순수 횡이동 + 조류 0.6 m/s · 45 deg';
 'r2_pose',   2, struct(), ...
              '2단 · 위치·선수각 유지 (30, 20) m · 45 deg';
 'r3_dock',   3, struct(), ...
              '3단 · 단계 전이 접안';
 'r3_direct', 3, struct('dock_on',0), ...
              '3단 · 단계를 나누지 않음 (dock_on = 0)';
 'r4_norev',  1, struct('rev_on',0), ...
              '1단 · 추력 반전 금지 (rev_on = 0)';
 'r4_d15',    1, struct('d_max_deg',15), ...
              '1단 · 각도 한계 ±15 deg' };

fprintf('A3 결과 그림 — img/\n');
for k = 1:size(C,1)
    setappdata(0, 'A3_stage',    C{k,2});
    setappdata(0, 'A3_skip_run', true);
    setappdata(0, 'A3_override', C{k,3});
    evalc('evalin(''base'', ''A3_setup'')');      % 설정 출력은 삼킨다
    mdl = evalin('base', 'mdl');

    out = sim(mdl);
    S   = A3_plot(out, C{k,4});
    f   = fullfile(here, 'img', ['A3_' C{k,1} '.png']);
    print(S.fig, '-dpng', '-r110', f);
    close(S.fig);
    d = dir(f);
    fprintf('  %-22s  %6.1f KB\n', ['A3_' C{k,1} '.png'], d.bytes/1024);
end
setappdata(0, 'A3_override', []);       % **반드시 비운다**
setappdata(0, 'A3_stage',    []);

%% ---- 도달 가능 집합 — 그림 셋 ----
%   덮어쓰기를 지운 설정으로 **다시 깔고** 부른다. 바로 부르면 마지막 경우가
%   남긴 d_max_deg = 15 를 읽어 그림이 설계 전제와 어긋난다
setappdata(0, 'A3_stage', 1);
setappdata(0, 'A3_skip_run', true);
evalc('evalin(''base'', ''A3_setup'')');
E = A3_envelope();
f = fullfile(here, 'img', 'A3_env.png');
print(E.fig, '-dpng', '-r110', f);
close(E.fig);
d = dir(f);
fprintf('  %-22s  %6.1f KB\n', 'A3_env.png', d.bytes/1024);
end
