function [chain, boxes] = buildA3Stage1(m)
% 1단  A3_1_crab — 순수 횡이동. 아지무스 추진기 둘로 옆걸음을 한다
%
%   교수님 질문 (a) 에 수치로 답하는 단이다.
%     "순수 횡이동 중에 선수각이 흔들리지 않고 유지되는가"
%
%   목표는 북쪽 0 m · 동쪽 12 m · 선수각 0 deg 다. 북쪽 성분이 0 이므로 배는
%   옆으로만 간다. 처음부터 목표 선수각으로 서 있다 (psi_init = psi_d) —
%   그래야 횡이동만 떼어 볼 수 있다.
%
%   무엇을 보아야 하는가
%     dL · dR    두 추진기의 방향각. 좌현 +23.4 deg, 우현 -23.4 deg 에 머문다
%     TL · TR    추력. **부호가 반대**다 (한쪽은 앞으로, 한쪽은 뒤로 민다)
%     psi        선수각. 흔들리지 않는다 — 요 모멘트가 **애초에 생기지 않는다**
%
%   왜 흔들리지 않는가 (PID 가 잡아 주는 것이 아니다)
%     추력선 둘이 모두 무게중심을 지나도록 각도가 정해졌기 때문이다. 추진기
%     하나하나의 요 모멘트가 0 이므로, 잡을 모멘트 자체가 없다. 자세한 설명은
%     강의자료 1-4 절.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceConst(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoopA3  (m, 1150, 280);
    addAzAlloc      (m, 1600, 280);
    addMotionModelXYN(m, 2050, 280);

    wireGuid (m, {}, {'x_ref','y_ref','psi_ref','gate'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);
    wireWrench(m, 1840, 290, 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    addStubs(m, {'phase'}, 2050, 760);
    boxes = addBoxesA3(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                           '','v'; '','dL'}, 2510, 60, false);

    sl_note(m, 'n1', ['A3 1단  —  순수 횡이동 (crabbing)' newline ...
        '추진기는 선미 좌·우 둘뿐. 대신 방향을 틀 수 있음 (±45 deg 전제)' newline ...
        '새로 생긴 것 : Alloc 상자 — 요구 X·Y·N 을 (추력, 각도) 둘씩으로 나눔' newline ...
        '볼 것 : dL 이 +23.4 deg, dR 이 -23.4 deg 에 머물고 psi 가 흔들리지 않음' newline ...
        'TL 과 TR 의 부호가 반대임 — 뒤로 미는 추력이 없으면 횡이동이 깨짐' newline ...
        '실행 전: A3_setup (stage = 1)  또는  A3_1_crab_run'], 250, -180);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Alloc','MotionModel'};
end
