function [chain, boxes] = buildStage1(m)
% 1단  W06_1_point — 목표 (x, y, psi) 로 가서 그 자세로 선다
%
%   이번에 새로 생긴 것 : 전부. 사다리의 첫 칸이다
%
%   Guidance(상수) -> OuterLoop(위치 P) -> InnerLoop(속도 PI + 선수각 P-D
%                  + 추력배분) -> 운동모델
%
%   추진기 동역학이 없다. 안쪽 고리가 낸 추력 지령이 **그대로** 운동모델에
%   들어간다. 도착 판정도 없다 — gate 가 늘 1 이므로 배는 목표 자세를 계속 잡는다.
%   블록이 적어 고리가 한눈에 보이는 것이 이 단계의 쓸모다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceConst(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoop    (m, 1150, 280);
    addMotionModel  (m, 1600, 280);

    wireGuid(m, {}, {'x_ref','y_ref','psi_ref','gate'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);
    wireForceGotos(m, 1390, 290);
    feedForces(m, 'MotionModel', 1530, 300);
    wireNavGotos(m, 'MotionModel', 1960, 280);

    addStubs(m, {'nprop','Ferr','phase'}, 1600, 760);
    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2060, 60, false);

    sl_note(m, 'n1', ['W06 1단  —  목표 자세로 가서 선다  (가장 단순한 모델)' newline ...
        '새로 생긴 것 : 위치 고리 하나 + 속도 고리 둘 + 선수각 고리 하나 + 추력 배분' newline ...
        '추진기가 셋이라 X · Y · N 을 독립으로 낼 수 있음 — 그래서 위치와 선수각을' newline ...
        '함께 잡음. 추진기가 둘이면 못 하는 일임' newline ...
        '없는 것 : 추진기 동역학 · 도착 판정 · 단계 전이 (2단부터 하나씩 생김)' newline ...
        '실행 전: W06_setup (stage = 1)'], 250, -160);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','MotionModel'};
end
