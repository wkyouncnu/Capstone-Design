function n = settle_links(mdl, tries)
%SETTLE_LINKS  지적이 0 이 될 때까지 선만 다시 긋는다. 블록은 옮기지 않는다.
%
%   n = settle_links('W07_0_offline')
%
%   lay_chain 으로 배치를 잡아 둔 모델에 쓴다. tidy_model 은 arrangeSystem 으로
%   배치부터 다시 잡으므로 lay_chain 이 접어 둔 모양을 무너뜨린다. 이 함수는
%   lay_links 만 반복해서 부르므로 배치는 그대로 두고 선만 푼다.
%
%   왜 필요한가
%
%   서브시스템에 포트를 하나 더 달면 출력이 아래로 밀리고, 그 선이 전에는
%   비어 있던 자리를 지나간다. 2026-09-17 에 W07 의 Guidance 에 x_e 출력을
%   더했더니 gate 선이 From 두 개를 가로질렀다 — 블록관통 2건.
%   배치를 다시 잡을 일은 아니고, 선 하나만 다른 통로로 보내면 되는 일이다.
%
%   신호 기록 표시는 챙겼다가 되돌린다. lay_links 는 선을 지웠다 다시 긋고,
%   DataLogging 은 출력 포트에 붙어 있어 선과 함께 사라진다 (keep_signals.m).

if nargin < 2 || isempty(tries), tries = 4; end

s = keep_signals(mdl);
n = check_lines(mdl, false);
for it = 1:tries
    if n == 0, break, end
    load_system(mdl);
    lay_links(mdl);
    save_system(mdl);
    close_system(mdl, 0);
    n = check_lines(mdl, false);
end
keep_signals(mdl, s);
load_system(mdl); save_system(mdl); close_system(mdl, 0);
n = check_lines(mdl, false);
end
