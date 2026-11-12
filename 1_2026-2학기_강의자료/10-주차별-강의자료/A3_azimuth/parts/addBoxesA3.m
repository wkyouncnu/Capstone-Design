function boxes = addBoxesA3(m, pairs, x, y, stopKind)
%  포트 없는 상자들 — 로깅 · 스코프 · 실시간 그림 · 자동정지
%
%  세 단이 이 상자들을 그대로 함께 쓴다. 그래야 단을 올렸을 때 그래프 모양이
%  같아 무엇이 달라졌는지 눈으로 비교된다.
%
%  stopKind — 자동정지 상자를 어느 꼴로 달 것인가
%    | 값        | 무엇을 보는가           | 쓰는 단 |
%    |-----------|------------------------|---------|
%    | 'err'     | 위치·선수각 오차 자체   | 1단     |
%    | 'gate'    | gate 가 0 이 된 뒤의 시간 | 2·3단  |
%    | 'none'    | 달지 않는다 (T_run 까지) | —       |
%    논리값도 받는다 — false = 'none', true = 'gate' (예전 호출 꼴)
    if nargin < 5,            stopKind = 'none';            end
    if islogical(stopKind) || isnumeric(stopKind)
        if stopKind, stopKind = 'gate'; else, stopKind = 'none'; end
    end

    addLogging(m, x, y);
    addCompareScope(m, pairs, x+420, y+1440);
    addAnimateA3(m, x+1340, y+1440);
    boxes = {'Logging','Observe','Animate'};

    switch lower(stopKind)
        case 'gate'
            addAutoStop(m, x+920, y+1440);
            boxes = [boxes {'AutoStop'}];
        case 'err'
            addAutoStopErr(m, x+920, y+1440);
            boxes = [boxes {'AutoStop'}];
        case 'none'
            % 달지 않는다
        otherwise
            error('addBoxesA3:stopKind', ...
                  'stopKind 는 err · gate · none 중 하나다 (받은 값: %s)', stopKind);
    end
end
