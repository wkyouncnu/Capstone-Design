function [chain, boxes] = buildA3Stage3(m)
% 3단  A3_3_dock — 단계 전이 접안 (6주차 5단과 같은 과업)
%
%   2단에서 새로 생긴 것
%     유도부가 **단계 전이**로 바뀐다 (addGuidance)
%       1단계 접근  선석 옆 L_app 만큼 떨어진 접근점으로 간다
%       2단계 접안  선석을 향해 옆걸음으로 붙는다 (여기서 아지무스가 일한다)
%       3단계 정지  R_stop 안에서 속도가 U_berth 아래로 떨어지면 끝
%
%   6주차와 **같은 선석·같은 게인·같은 유도부**를 쓴다. 다른 것은 추진기뿐이다.
%   따라서 두 그림을 겹쳐 놓으면 "추진기 셋 vs 아지무스 둘" 의 차이만 남는다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidance     (m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoopA3  (m, 1150, 280);
    addAzAlloc      (m, 1600, 280);
    addMotionModelXYN(m, 2050, 280);

    wireGuid (m, {'x_n','y_n','psi'}, ...
                 {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);
    wireAlloc(m, 1840, 290, 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    boxes = addBoxesA3(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                           '','v'; '','dL'}, 2510, 60, true);

    sl_note(m, 'n3', ['A3 3단  —  단계 전이 접안' newline ...
        '새로 생긴 것 : 접근 -> 접안 -> 정지 단계 전이 유도부 (phase 1·2·3)' newline ...
        '6주차 5단과 같은 선석·같은 게인·같은 유도부. 다른 것은 추진기뿐임' newline ...
        '볼 것 : 접안 구간(phase 2) 에서 dL·dR 이 23.4 deg 부근에 모임' newline ...
        '실행 전: A3_setup (stage = 3)  또는  A3_3_dock_run'], 250, -180);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Alloc','MotionModel'};
end
