function boxes = addBoxesA3(m, pairs, x, y, withStop)
%  포트 없는 상자들 — 로깅 · 스코프 · 자동정지
%
%  세 단이 이 상자들을 그대로 함께 쓴다. 그래야 단을 올렸을 때 그래프 모양이
%  같아 무엇이 달라졌는지 눈으로 비교된다.
%  withStop 이 false 면 AutoStop 을 달지 않는다 (1단은 끝까지 돌려 본다).
    addLogging(m, x, y);
    addCompareScope(m, pairs, x+420, y+1440);
    boxes = {'Logging','Observe'};
    if withStop
        addAutoStop(m, x+920, y+1440);
        boxes = [boxes {'AutoStop'}];
    end
end
