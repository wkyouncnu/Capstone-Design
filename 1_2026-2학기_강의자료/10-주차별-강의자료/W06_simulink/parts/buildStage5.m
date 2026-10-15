function [chain, boxes] = buildStage5(m)
% 5단  W06_5_dock — 단계 전이로 접안한다, 즉 "목표가 하나가 아니다"
%
%   이번에 새로 생긴 것 : 유도부가 한 점이 아니라 **단계마다 다른 목표**를 낸다
%                         (addGuidanceStop -> addGuidance)
%
%   4단까지 목표는 처음부터 끝까지 한 점이었다. 접안은 그렇게 못 한다.
%   선석에 바로 돌진하면 비스듬히 부딪는다. 사람이 배를 대는 순서가 있다.
%
%     1단계  접근점으로 간다 — 선수각은 가는 방향으로 둔다 (저항이 작다)
%     2단계  접근점에 머물며 선수각만 접안 선수각으로 돌린다
%     3단계  선수각을 지킨 채 옆걸음으로 선석에 붙인다
%
%   접근점이 어디인가
%     선석에서 부두 반대쪽으로 L_app 만큼 떨어진 점이다. 접안 선수각 dpsi 로
%     들어가려면 그 뒤쪽에 서 있어야 한다.
%
%         ax = dx - berth_side * L_app * sin(dpsi)
%         ay = dy + berth_side * L_app * cos(dpsi)
%
%     berth_side = +1 이면 부두가 좌현쪽이고 접근점은 우현쪽에 생긴다.
%
%   단계가 올라가는 조건 (내려오지 않는다 — 4단의 래치와 같다)
%     0 -> 1   접근점까지 거리 < R_dock
%     1 -> 2   선수각 오차 < 5 deg
%     2 -> 3   선석까지 거리 < R_stop    이때 gate 가 닫히고 배가 선다
%
%   왜 3단계가 옆걸음인가
%     선수각을 dpsi 로 묶어 둔 채 목표만 선석으로 바꾸면, 바깥 고리가 선체
%     좌표로 돌린 오차가 거의 횡방향(e_y)으로만 남는다 — 2단에서 본 순수
%     횡이동이 여기서 쓰인다. 선수추진기가 없으면 이 단계가 되지 않는다.
%
%   모델에서 달라지는 것은 유도부 하나뿐이다. 바깥 고리·안쪽 고리·추진기·
%   운동모델·상자는 4단 그대로다. 사다리의 값어치가 여기서 드러난다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidance    (m,  250,  60);
    addOuterLoop   (m,  700,  60);
    addInnerLoop   (m, 1150, 280, true);    % true = BowOn 스위치 (2단에서 생긴 뒤 계속 붙어 있다)
    addThrusters   (m, 1600, 280);
    addMotionModel (m, 2050, 280);

    wireGuid(m, {'x_n','y_n','psi'}, ...
                {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);

    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Thrusters/%d',k), ...
                 'autorouting','on');
    end

    wireThrusterGotos(m, 1840, 290);
    feedForces(m, 'MotionModel', 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2510, 60, true);

    sl_note(m, 'n5', ['W06 5단  —  단계 전이로 접안 (목표가 하나가 아니다)' newline ...
        '새로 생긴 것 : 유도부가 task_mode 로 과업을 고르고 단계마다 목표를 바꿈' newline ...
        '접안 1단계 접근점 -> 2단계 선수각 정렬 -> 3단계 옆걸음으로 선석에' newline ...
        '접근점 = 선석에서 부두 반대쪽으로 L_app, 전환은 R_dock 안에 들면' newline ...
        'phase 가 3 이 되면 gate 가 닫히고 AutoStop 이 stop_hold 초 뒤 멈춤' newline ...
        '실행 전: W06_setup (stage = 5)'], 250, -190);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
