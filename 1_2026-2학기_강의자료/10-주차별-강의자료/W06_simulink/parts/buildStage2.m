function [chain, boxes] = buildStage2(m)
% 2단  W06_2_sway — 순수 횡이동, 그리고 선수추진기를 꺼 보는 스위치
%
%   이번에 새로 생긴 것 : BowOn 게인 하나 (InnerLoop 안, bow_on 을 곱한다)
%
%   1단과 블록이 똑같다. 달라진 것은 횡력 지령 Y 가 추력 배분으로 가기 전에
%   bow_on 을 한 번 지난다는 것뿐이다.
%
%     bow_on = 1   선수추진기를 쓴다 — 선수각을 0 deg 로 묶은 채 동쪽으로 간다
%     bow_on = 0   횡력 지령이 끊긴다 — 추진기 둘뿐인 5주차의 배가 된다
%
%   왜 이 한 줄이 한 단계를 차지하는가
%     "추진기가 셋이면 횡이동이 된다" 는 말은 끄고 켜 보아야 몸에 남는다.
%     bow_on = 0 으로 두면 동쪽 12 m 가 끝까지 줄지 않는다 — 옆으로 밀 힘이
%     없기 때문이다. 선수각은 그대로 0 deg 로 잡힌다 (요 모멘트는 좌·우
%     추진기로 내므로 선수추진기가 없어도 잡힌다). 위치와 선수각 가운데
%     **선수각만** 잡히는 모습이 추진기 둘의 한계다.
%
%   목표는 W06_setup 3절의 sway_north · sway_east · sway_deg 다. 북쪽 성분을
%   0 으로 두었으므로 배는 옆으로만 간다. 처음부터 목표 선수각으로 서 있다
%   (psi_init = psi_d) — 그래야 횡이동만 떼어 볼 수 있다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceConst(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoop    (m, 1150, 280, true);      % true = BowOn 스위치를 단다
    plant('add', m, 1600, 280);   % 오프라인: MotionModel / VRX 판: Gazebo 토픽 (plant.m)

    wireGuid(m, {}, {'x_ref','y_ref','psi_ref','gate'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);
    wireForceGotos(m, 1390, 290);
    feedForces(m, plant('in'), 1530, 300);
    wireNavGotos(m, plant('out'), 1960 + plant('dx'), 280);

    addStubs(m, {'nprop','Ferr','phase'}, 1600, 760);
    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2060 + plant('dx'), 60, false);

    sl_note(m, 'n2', ['W06 2단  —  순수 횡이동과 선수추진기 스위치' newline ...
        '새로 생긴 것 : InnerLoop 안의 BowOn 게인 하나 (bow_on 을 곱함)' newline ...
        'bow_on = 1 -> 선수각 0 deg 를 지킨 채 동쪽 12 m 를 옆걸음으로 감' newline ...
        'bow_on = 0 -> 횡력 지령이 끊김. 동쪽 오차가 줄지 않음 (추진기 둘의 한계)' newline ...
        '두 값으로 각각 돌려 그림을 겹쳐 볼 것 — W06_2_sway_m 이 한 번에 함' newline ...
        '실행 전: W06_setup (stage = 2)'], 250, -160);

    save_system(m);  close_system(m);
    chain = plant('chain', {'Guidance','OuterLoop','InnerLoop','MotionModel'});
end
