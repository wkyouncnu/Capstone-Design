function [chain, boxes] = buildStage7(m)
% 7단  W06_7_front — 전진 접안 (bow-first), 즉 "선수를 선석으로 들이댄다"
%
%   이번에 새로 생긴 것 : 접안 선수각이 선석 방위에 **수직**이다
%                         (addGuidance -> addGuidanceFront)
%
%   7단은 6단(Gazebo 연동) 위가 아니라 **5단 위에** 쌓는다. 6단은 운동모델을
%   실물로 바꾸는 갈림길이고, 7·8단은 오프라인에서 제어 전략을 바꾸는 길이다.
%
%   5단과 무엇이 다른가
%     5단은 선석과 나란히 서서 옆걸음으로 붙였다 (lateral approach). 7단은
%     같은 접근점에서 선수를 부두로 돌려 전진으로 붙인다 (bow-first).
%
%       5단  psi_f = psi_t                3단계가 횡이동 — 횡추력으로 붙임
%       7단  psi_f = psi_t - side*pi/2    3단계가 전진 — 전후추력으로 붙임
%
%     접근점은 두 전략이 같은 점이다 (addGuidanceFront 머리글의 전개 참조).
%     선수각만 90 deg 틀면 바깥 고리가 선체좌표로 돌린 오차가 e_y 에서 e_x 로
%     옮겨 앉는다. 제어기는 한 줄도 바꾸지 않았다 — 사다리의 값어치가 여기서
%     또 한 번 드러난다.
%
%   어느 전략을 쓰는가 (실험실 논문 Bang et al. 2025, 표 1·3.2 절)
%     전진 접안   구현이 가장 단순하다. 다만 이탈할 때 후진해야 하므로 선회
%                 공간이 더 필요하고, 빠른 축(전후)으로 들어가므로 관성으로
%                 더 밀린다 — 측정값은 선석을 1.81 m 지나쳤다.
%     옆걸음      접안 정밀도가 높고 이탈이 쉽다. 횡추력이 나는 배여야 한다
%                 (fully actuated).
%
%   이 모델의 7단은 선수추진기를 여전히 쓴다
%     논문이 전진 접안을 "선수추진기 없이도 된다" 고 적는 것은 3단계를 위치
%     제어가 아니라 전후 속도 + 선수각 제어로 하기 때문이다. 이 모델은 3단계도
%     위치제어로 두어 5단과 제어기를 공유한다 — 그래서 2단계에서 돌아설 때 생긴
%     횡방향 오차를 지우려면 횡추력이 있어야 한다. 선수추진기를 끄고 돌리면
%     그 오차 2.32 m 가 끝까지 남아 붙지 못한다 (W06_7_front_m.m 셋째 벌).
%
%   모델에서 달라지는 것은 유도부 하나뿐이다. 바깥 고리·안쪽 고리·추진기·
%   운동모델·상자는 5단 그대로다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceFront(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoop    (m, 1150, 280);
    addThrusters    (m, 1600, 280);
    addMotionModel  (m, 2050, 280);

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

    sl_note(m, 'n7', ['W06 7단  —  전진 접안 (선수를 선석으로 들이댄다)' newline ...
        '새로 생긴 것 : 접안 선수각이 선석 방위에 수직 (psi_f = psi_t - side*90 deg)' newline ...
        '1단계 접근점 -> 2단계 선수각 정렬 -> 3단계 전진으로 선석에' newline ...
        '접근점은 5단과 같은 점 — 선수각만 90 deg 틀어 옆걸음이 전진으로 바뀜' newline ...
        '3단계가 전진이므로 선체좌표 오차가 e_x 로 남음 — 횡추력이 거의 들지 않음' newline ...
        '실행 전: W06_setup (stage = 7)'], 250, -190);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
