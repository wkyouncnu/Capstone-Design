function [chain, boxes] = buildA3Stage2(m)
% 2단  A3_2_pose — 위치와 선수각을 함께 맞춰 서기
%
%   교수님 질문 (b) 에 답하는 단이다.
%     "6주차처럼 (x, y, psi) 위치제어가 되는가"
%
%   1단에서 새로 생긴 것
%     유도부가 상수에서 **판정**으로 바뀐다 (addGuidanceStop)
%       - 거리 R_stop · 선수각 5 deg · 속력 U_stop 을 모두 만족하면 phase 를 1 로 올린다
%       - gate 는 도착 표시일 뿐이다. 위치 고리는 끊기지 않고 그 자리를 계속 잡는다
%     AutoStop 상자가 붙는다 — gate 가 0 인 채로 stop_hold 초가 지나면 시뮬레이션 종료
%
%   목표는 북쪽 30 m · 동쪽 20 m · 선수각 45 deg 다 (6주차 1단과 같은 목표).
%   배는 목표점을 향해 서서 출발하므로, 전후·횡·선수각을 **동시에** 요구받는다.
%   이때 각도가 ±45 deg 를 넘는 구간이 생기는지가 이 단의 관심사다 (log_dL, log_dR).
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceStop (m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoopA3  (m, 1150, 280);
    addAzAlloc      (m, 1600, 280);
    addMotionModelXYN(m, 2050, 280);

    wireGuid (m, {'x_n','y_n','psi'}, ...
                 {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);
    wireAlloc(m, 1840, 290, 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    %  NotYet 상자가 없다 — 로깅·그림이 쓰는 태그를 이제 전부 모델이 낸다
    boxes = addBoxesA3(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                           '','v'; '','dL'}, 2510, 60, true);

    sl_note(m, 'n2', ['A3 2단  —  위치와 선수각을 함께 맞춰 서기' newline ...
        '새로 생긴 것 : 도착 판정(거리·선수각·속력) + phase 래치 + AutoStop' newline ...
        '전후·횡·선수각을 동시에 요구받음 — 각도가 ±45 deg 에 붙는 구간이 생기는지 볼 것' newline ...
        '볼 것 : log_dL · log_dR 이 한계에 붙는 시간, log_X_a 가 log_X_c 에서 벌어지는 구간' newline ...
        '실행 전: A3_setup (stage = 2)  또는  A3_2_pose_run'], 250, -180);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Alloc','MotionModel'};
end
