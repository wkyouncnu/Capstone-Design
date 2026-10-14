function [chain, boxes] = buildStage8(m)
% 8단  W06_8_ned — NED 좌표계 위치제어 접안, 즉 "제어기가 도는 좌표계를 바꾼다"
%
%   이번에 새로 생긴 것 : 위치·속도 제어가 선체고정이 아니라 **NED 축**에서 돈다
%                         (addOuterLoop -> addOuterLoopNED,
%                          addInnerLoop -> addInnerLoopNED)
%
%   8단도 6단(Gazebo) 위가 아니라 **5단 위에** 쌓는다. 과업은 5단과 똑같다 —
%   같은 선석, 같은 접근점, 같은 세 단계의 옆걸음 접안(addGuidance)이다.
%   달라지는 것은 제어기가 오차를 세는 좌표계 하나뿐이다. 그래서 두 결과를
%   그대로 견줄 수 있다 (실험실 논문 Bang et al. 2025 그림 8 과 그림 9).
%
%   회전행렬이 어디에 앉는가 — 이것이 두 전략의 전부다
%
%     선체고정 (5단)   위치오차 -> [R] -> 속도지령 -> 속도PI -> 힘 -> 배분
%     NED      (8단)   위치오차 ------> 속도지령 -> 속도PI -> [R] -> 힘 -> 배분
%                                          측정속도 -> [R] -> 되먹임
%
%     선체고정은 회전행렬이 하나, NED 는 둘이다. NED 쪽이 하나 더 드는 까닭은
%     제어기가 NED 에서 도는데 센서도 구동기도 선체고정이기 때문이다 —
%     들어올 때 한 번, 나갈 때 한 번 돌려야 한다.
%
%   어느 쪽이 나은가 (논문 3.3.2 절)
%     NED        오차를 지도 위에서 바로 센다. 선수각이 돌아도 목표점으로
%                가는 직선이 변하지 않아 경로가 곧다.
%     선체고정   오차를 배가 느끼는 방향으로 센다. 전후 1.5 m/s · 횡 0.6 m/s
%                처럼 **축마다 다른 한계**를 그대로 걸 수 있고, 임무 제어의
%                전후 속도 제어기를 다시 쓸 수 있다.
%
%     WAM-V 처럼 전후와 횡의 힘이 크게 다른 배(선미 500 N 둘 · 선수 250 N
%     하나)에서는 축마다 다르게 묶을 수 있는 쪽이 유리하다. 8단의 측정값이
%     그것을 보인다 — W06_8_ned_m.m 이 두 전략을 나란히 돌려 찍는다.
%
%   유도부·추진기·운동모델·상자는 5단 그대로다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidance     (m,  250,  60);
    addOuterLoopNED (m,  700,  60);
    addInnerLoopNED (m, 1150, 280);
    addThrusters    (m, 1600, 280);
    addMotionModel  (m, 2050, 280);

    wireGuid(m, {'x_n','y_n','psi'}, ...
                {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoopsNED(m, 620, 200, 1020, 60);

    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Thrusters/%d',k), ...
                 'autorouting','on');
    end

    wireThrusterGotos(m, 1840, 290);
    feedForces(m, 'MotionModel', 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2510, 60, true);

    sl_note(m, 'n8', ['W06 8단  —  NED 좌표계 위치제어 접안 (제어 좌표계를 바꾼다)' newline ...
        '새로 생긴 것 : 위치 오차를 돌리지 않고 북·동 축에서 바로 제어' newline ...
        '회전행렬은 안쪽 고리로 옮겨 감 — 되먹임을 들일 때와 힘을 낼 때 두 번' newline ...
        '과업은 5단과 똑같음 (같은 선석·접근점·세 단계) — 달라지는 것은 좌표계 하나' newline ...
        '속도 지령은 축마다가 아니라 벡터 크기로 V_ned_max 에 묶임' newline ...
        '실행 전: W06_setup (stage = 8)'], 250, -190);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
