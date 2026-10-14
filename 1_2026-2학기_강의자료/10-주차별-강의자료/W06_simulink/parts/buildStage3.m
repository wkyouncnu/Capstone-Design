function [chain, boxes] = buildStage3(m)
% 3단  W06_3_thrust — 추진기 동역학, 즉 "지령한 추력이 곧바로 나지 않는다"
%
%   이번에 새로 생긴 것 : Thrusters 서브시스템 하나 (사슬 4번째 자리)
%
%   1·2단에서는 안쪽 고리가 낸 추력 지령이 **그대로** 운동모델에 들어갔다.
%   실물은 그렇지 않다. 지령은 회전수로 바뀌고, 모터가 그 회전수에 이르는 데
%   시간이 걸리며, 회전수에는 한계가 있다. 그 셋을 끼워 넣는 단계다.
%
%     FL_cmd -> [F2n] -> [MotorLag] -> [n2F] -> FL
%       F2n       역 프로펠러 법칙 n = sign(F) sqrt(|F|/k_prop), 그리고 n_max 포화
%       MotorLag  1차 지연 셋 (시정수 tau_n) — 회전수가 지령 회전수를 따라간다
%       n2F       프로펠러 법칙 F = k_prop * n * |n|
%
%   무엇이 달라지는가
%     두 법칙은 서로의 역이므로 **정상상태에서는 FL = FL_cmd 다**. 달라지는
%     것은 과도구간뿐이다. 추력이 tau_n 만큼 늦게 서고, 지령이 n_max 를
%     넘어서면 F2n 의 포화에서 잘려 나간다. 1·2단과 같은 목표로 돌려 추력
%     그래프를 겹쳐 보면 늦는 폭이 눈에 보인다.
%
%   왜 한 단계를 차지하는가
%     실기(6단 Gazebo)에서는 추진기 지령이 회전수로 나간다. 추력으로만
%     생각하던 고리를 회전수까지 내려 보는 연습이 여기서 끝나 있어야 한다.
%     회전수 n 은 Thrusters 의 4번째 출력이며, 2단까지 0 으로 채워 두었던
%     nprop 태그가 이 단계에서 진짜 값을 받는다 — 그래서 NotYet 상자에서
%     nprop 이 빠진다.
%
%   태그 이름이 같은 덕
%     힘 태그 FL·FR·FB 를 내는 자리만 wireForceGotos 에서 wireThrusterGotos
%     로 바뀐다. 운동모델·로깅·그림 쪽은 한 줄도 고치지 않는다.
%
%   목표는 1단과 같다 (W06_setup 3절의 hold_*). 추진기 동역학만 떼어 보기
%   위해 다른 것은 하나도 건드리지 않는다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceConst(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoop    (m, 1150, 280);
    addThrusters    (m, 1600, 280);
    addMotionModel  (m, 2050, 280);

    wireGuid(m, {}, {'x_ref','y_ref','psi_ref','gate'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);

    %  안쪽 고리의 추력 지령 셋을 추진기로 바로 잇는다. 사슬에서 이웃한
    %  블록이고 포트 수가 3 대 3 이라 태그를 쓸 까닭이 없다 — 직선 셋이다
    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Thrusters/%d',k), ...
                 'autorouting','on');
    end

    wireThrusterGotos(m, 1840, 290);
    feedForces(m, 'MotionModel', 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    addStubs(m, {'phase'}, 2050, 760);
    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2510, 60, false);

    sl_note(m, 'n3', ['W06 3단  —  추진기 동역학 (지령한 추력이 곧바로 나지 않음)' newline ...
        '새로 생긴 것 : Thrusters 하나 — 추력<->회전수 변환 · 모터 1차 지연 · 회전수 포화' newline ...
        '정상상태에서는 1단과 같음 (두 법칙이 서로의 역임). 과도구간만 tau_n 만큼 늦음' newline ...
        '회전수 n 이 이 단계에서 처음 생김 — NotYet 상자에서 nprop 이 빠짐' newline ...
        '1단 결과와 추력·회전수 그래프를 겹쳐 볼 것 — W06_3_thrust_m 이 한 번에 함' newline ...
        '실행 전: W06_setup (stage = 3)'], 250, -160);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
