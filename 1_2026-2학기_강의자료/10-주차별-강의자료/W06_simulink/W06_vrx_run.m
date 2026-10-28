function R = W06_vrx_run(st, refresh)
% W06_VRX_RUN  VRX 쌍둥이를 '직접 Run' 할 준비를 하고 모델을 열어 준다
%
%   >> W06_vrx_run(5)          5단의 쌍둥이 W06_5_dock_vrx 를 열어 둔다
%   >> W06_vrx_run(5, true)    오프라인 5단을 먼저 다시 돌려 기준을 새로 만든 뒤 연다
%
%   2026-10-28 부터 이 함수는 **Gazebo 를 돌리지 않는다.**
%   연동 실행은 열린 Simulink 창에서 사람이 Run 을 누르는 것으로 한다.
%     Run 을 누르면 모델의 InitFcn  -> W06_vrx_prep   (도메인·토픽·스폰원점·페이싱)
%     끝나면          모델의 StopFcn -> W06_vrx_report (결과 네 칸 · 기준 대조 여섯 칸)
%
%   하는 일 세 가지
%     1. 기준 궤적이 ref/ 에 있는지 본다. 없거나 refresh 면 **오프라인 모델을 돌려** 만든다
%     2. 쌍둥이 모델을 연다 (설정은 건드리지 않는다 — 쌍둥이의 InitFcn 이 깐다)
%     3. VRX 를 띄우는 순서와 Run 이후에 무엇이 나오는지 찍어 준다
%
%   왜 바뀌었는가
%     예전에는 이 함수가 Gazebo 연동 실행과 오프라인 실행을 한 번에 했다. 한 번에
%     두 모델이 도는 셈이어서 어느 그래프가 무엇인지 헷갈렸다. 이제 m 파일은
%     오프라인 전용이고, Gazebo 는 쌍둥이를 직접 Run 하는 길 하나만 남았다.
%
%   끝낼 때 반드시 정리한다 — 남은 gz sim 이 수십 GB 까지 자란다
%     ros2 run vrx_llm_dock cleanup

if nargin < 1 || isempty(st),      st = 5;          end
if nargin < 2 || isempty(refresh), refresh = false; end

nm = W06_stage_of();
assert(st >= 1 && st <= numel(nm) && ~isempty(nm{st}), ...
       'W06_vrx_run:stage', 'st 는 1~%d 중 하나여야 한다 (받은 값 %g)', numel(nm), st);

twin = nm{st};
if ~endsWith(twin, '_vrx'), twin = [twin '_vrx']; end
[~, ~, off] = W06_stage_of(twin);
ost = W06_stage_of(off);                      % 오프라인 쪽 단 번호 (6단 -> 5단)
rst = st;  if rst == 6, rst = 5; end          % img · ref 파일 이름에 쓰는 번호

%% 1. 기준 궤적 — m 파일이 남긴 오프라인 결과
R = W06_ref('load', st);
if refresh || isempty(R)
    if refresh
        fprintf('\n기준 궤적을 새로 만든다 — 오프라인 %s 를 돌린다\n', off);
    else
        fprintf('\n기준 궤적이 없다 — 오프라인 %s 를 먼저 돌린다\n', off);
    end
    setappdata(0, 'W06_stage', ost);
    setappdata(0, 'W06_skip_run', true);      % 설정만. 실행은 이 함수가 한다
    evalin('base', 'W06_setup');
    load_system(off);
    o  = sim(off);
    sn = evalin('base', 'stage_name');
    S  = W06_plot(o, sprintf('%d단 — %s', ost, sn{ost}));
    W06_ref('save', ost, o, S);
    R  = W06_ref('load', st);
end
fprintf('\n기준 궤적 — ref/W06_%d_offline.mat  (%s, T_run %g s, %s)\n', ...
        rst, R.mdl, R.T_run, char(R.when, 'yyyy-MM-dd HH:mm'));
fprintf('   끝 위치 (%.3f, %.3f) m,  끝 선수각 %.2f deg\n', ...
        R.x(end), R.y(end), rad2deg(R.psi(end)));

%% 2. 쌍둥이를 연다 — 설정은 InitFcn 이 깐다
open_system(twin);

%% 3. 다음에 무엇을 하는가
fprintf('\n%s 를 열었다. 아래 순서로 한다\n', twin);
fprintf('  1. WSL 에서 **선수추진기를 단** VRX 를 띄운다 (실험마다 새로)\n');
fprintf('       cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W06_vrx_lite\n');
fprintf('       bash ../W03_vrx_lite/stop_vrx.sh && bash run_vrx_bow.sh\n');
fprintf('  2. 열린 Simulink 창에서 **Run** 을 누른다\n');
fprintf('       InitFcn 이 도메인·토픽 확인 -> RTF 20 초 실측 -> 스폰 원점 측정 -> 페이싱까지 한다\n');
fprintf('  3. 도는 동안 실시간 그림이 함께 뜬다 (W06_animate)\n');
fprintf('  4. 끝나면 결과 네 칸과 기준 대조 여섯 칸이 뜨고 img/ 에 저장된다\n');
fprintf('       img/W06_%d_vrx_result.png,  img/W06_%d_vrx_vs_offline.png\n', rst, rst);
fprintf('  5. 끝낼 때 정리 — ros2 run vrx_llm_dock cleanup\n');
end
