function boxes = addBoxes(m, pairs, x, y, withStop)
%  포트 없는 상자 넷 — 그림 · 로깅 · 스코프 · 자동정지
%
%  여덟 단계가 이 상자들을 그대로 함께 쓴다. 그래야 단계를 올렸을 때
%  그래프 모양이 같아 무엇이 달라졌는지 눈으로 비교된다.
%  withStop 이 false 면 AutoStop 을 달지 않는다 (4단에서 생긴다).
    addAnimate(m, x, y+700);
    addLogging(m, x+420, y);
    addCompareScope(m, pairs, x+820, y+1440);
    boxes = {'Animate','Logging','Observe'};
    if withStop
        addAutoStop(m, x+1320, y+1440);
        boxes = [boxes {'AutoStop'}];
    end
end
