function n = tidy_model(m, verbose)
%TIDY_MODEL  모델 하나를 배치 규칙대로 정리하고 저장한다. 합격선은 지적 0건.
%
%   tidy_model('W03_1_frame_check')
%   n = tidy_model('SB7_signal_done', true)
%
%   순서 / the order, and why
%     1) mss_style        블록 크기를 먼저 정한다. 나중에 키우면 배치가 어긋난다
%     2) arrangeSystem    Simulink 의 층 배치. 앞뒤 순서를 잡는 데는 이만한 것이 없다
%     3) lay_feedback     되돌아가는 선을 블록 아래 통로로 돌린다
%     4) tag_feedback     그래도 세 번 꺾이면 Goto/From 한 쌍으로 바꾼다
%     5) lay_sinks        갈라져 나온 종착 블록을 아래 한 열로 내린다
%     6) lay_links        남은 지저분한 선만 통로 하나로 다시 긋는다
%
%   왜 두 번 해 보는가 / why it tries twice
%       lay_sinks 는 "이미 깨끗한 선은 두고 본다" 와 "종착 블록은 전부 내린다"
%       두 가지로 돌 수 있다. 어느 쪽이 나은지는 모델마다 다르다 — W02·W04 는
%       전부 내려야 0 이 되고, W03 은 두고 봐야 0 이 된다 (2026-09-17 측정).
%       그래서 둘 다 해 보고 지적이 적은 쪽을 저장한다.
%
%   왜 몇 바퀴 도는가 / why it repeats
%       한 가닥을 옮기면 다음 가닥이 쓸 통로가 비므로, 한 바퀴로는 끝나지 않는
%       모델이 있다 (SB11 이 그렇다). 나빠지면 되돌리므로 더 돌아도 손해가 없다.
%
%   되돌리려면 build_wXX_models 를 다시 실행하면 된다.
%
%   돌려주는 값은 저장한 쪽의 지적 수다.

if nargin < 2, verbose = false; end

%  신호에 붙은 기록 표시를 먼저 챙긴다. 배치 도구는 선을 지웠다 다시 긋는데,
%  표시는 선과 함께 지워지므로 그대로 두면 결과 파일에서 신호가 조용히 빠진다.
sig = keep_signals(m);

n = inf;
for round = 1:4
    prev = n;
    n = one_round(m);
    if n == 0 || n >= prev, break, end
end

load_system(m);
keep_signals(m, sig);
save_system(m);
close_system(m, 0);

n = check_lines(m, verbose);
close_system(m, 0);
end

% -------------------------------------------------------------------------
function n = one_round(m)
%  손대기 전 성적과 파일 사본을 챙긴다. 정리가 오히려 나쁘게 나오면 되돌린다.
%  이미 정리된 모델에 다시 돌리면 다른 배치가 나오는데, 그것이 더 나을 이유는
%  없다 (2026-09-17 SB11 에서 0 -> 1 로 뒷걸음질).
load_system(m);
mfile = get_param(m, 'FileName');
[~, n0] = evalc('check_lines(m, false)');
ok0 = compiles(m);
close_system(m, 0);
keepFile = [tempname '.slx'];
copyfile(mfile, keepFile);

best = inf;  bestAll = false;
for allSinks = [false true]
    run_once(m, allSinks);
    %  견주어 보는 중일 뿐이므로 중간 성적표는 삼킨다. 저장한 쪽만 보고한다.
    [~, k] = evalc('check_lines(m, false)');
    close_system(m, 0);                 % 저장하지 않는다 — 어느 쪽이 나은지 재 볼 뿐
    if k < best, best = k;  bestAll = allSinks; end
    if best == 0, break, end
end

run_once(m, bestAll);
save_system(m);
close_system(m, 0);

%  다 옮기고도 나빠졌다면 손대기 전 파일로 돌아간다. 이미 정리된 모델에 다시
%  돌리면 다른 배치가 나오는데, 그것이 더 나을 이유는 없다.
%
%  **컴파일되던 모델이 컴파일되지 않게 되면 무조건 되돌린다.** 도면을 예쁘게
%  만들자고 모델을 망가뜨릴 수는 없다. 배선 검사만으로는 부족하다 — 매달린 선은
%  겹치지도 블록을 뚫지도 않으므로 검사를 통과한다 (2026-09-17 W02_2).
load_system(m);
[~, n] = evalc('check_lines(m, false)');
ok1 = compiles(m);
close_system(m, 0);
if n > n0 || (ok0 && ~ok1)
    copyfile(keepFile, mfile);
    if ok0 && ~ok1
        fprintf('  %-26s 되돌림 — 정리하면 컴파일되지 않는다\n', m);
    else
        fprintf('  %-26s 배치는 그대로 둔다 (다시 놓으면 %d -> %d)\n', m, n0, n);
    end
end
delete(keepFile);

%  저장할 때 Simulink 가 선을 한 번 더 그린다. 그래서 방금 손댄 결과와 파일에
%  들어앉은 결과가 다를 수 있다 — SB1 에서 네 번 꺾인 선 하나가 그렇게 남았다
%  (2026-09-17). 블록은 두고 **선만** 더 나아지지 않을 때까지 손질한다.
for t = 1:6
    load_system(m);
    [~, before] = evalc('check_lines(m, false)');
    if before == 0, close_system(m, 0); break, end
    sys = [{m}; find_system(m, 'LookUnderMasks','all', 'BlockType','SubSystem')];
    %  한 번 돌려 잠깐 나빠졌다가 다음 번에 풀리는 경우가 있다. 한 가닥을 옮기면
    %  다음 가닥이 쓸 통로가 비기 때문이다 (W06_4 에서 2 -> 3 -> 0).
    %  그래서 몇 번 더 돌려 보고, **나아졌을 때만** 저장한다.
    gain = false;
    for k = 1:4
        for s = 1:numel(sys)
            try, lay_links(sys{s}); catch, end
        end
        [~, cur] = evalc('check_lines(m, false)');
        if cur < before, gain = true; break, end
    end
    if gain && ok0 && ~compiles(m), gain = false; end   % 망가뜨리면서 줄이지 않는다
    if gain, save_system(m); end
    close_system(m, 0);
    if ~gain, break, end
end

[~, n] = evalc('check_lines(m, false)');
close_system(m, 0);
end

% -------------------------------------------------------------------------
function tf = compiles(m)
%COMPILES  다이어그램 갱신이 통과하는가. 모델이 온전한지 재는 가장 싼 방법이다.
%   ROS 블록이 있어도 네트워크는 필요 없다 — 차원·자료형만 따진다.
try
    evalc('set_param(m, ''SimulationCommand'', ''update'')');
    tf = true;
catch
    tf = false;
end
try, set_param(m, 'SimulationCommand', 'stop'); catch, end
end

% -------------------------------------------------------------------------
function run_once(m, allSinks)
%  반드시 파일에서 다시 읽는다. 앞선 시도의 배치가 남아 있으면 두 방식을
%  견주는 것이 아니라 한쪽 위에 다른 쪽을 덧칠하게 된다.
if bdIsLoaded(m), close_system(m, 0); end
load_system(m);
try, mss_style(m); catch, end
sys = [{m}; find_system(m, 'LookUnderMasks','all', 'BlockType','SubSystem')];
for s = 1:numel(sys)
    try, Simulink.BlockDiagram.arrangeSystem(sys{s}); catch, end
end
for s = 1:numel(sys)
    try, lay_feedback(sys{s});              catch, end
    try, tag_feedback(sys{s});              catch, end
    try, lay_sinks(sys{s}, 'All', allSinks); catch, end
    try, lay_links(sys{s});                 catch, end
    try, lay_links(sys{s});                 catch, end
end
end
