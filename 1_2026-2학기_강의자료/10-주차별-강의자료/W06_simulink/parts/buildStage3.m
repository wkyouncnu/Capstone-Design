function [chain, boxes] = buildStage3(m)
% 3단  W06_3_thrust — 추진기 자리, 즉 "Gazebo 플러그인이 하는 일"
%
%   이번에 새로 생긴 것 : Thrusters 서브시스템 하나 (사슬 4번째 자리)
%
%   1·2단에서는 안쪽 고리가 낸 추력 지령이 운동모델로 바로 들어갔다. 사슬에
%   추진기 칸이 없었다. 실물에서 그 칸에 해당하는 것은 Gazebo 플러그인이고,
%   역 프로펠러 법칙은 바로 그 안에 있다. 이 칸은 그것을 소스와 같은 순서로
%   다시 적는다 (2026-10-15 에 소스를 직접 열어 확인했다).
%
%     FL_cmd ┐                                  ┌-> FL     포화만 거친 지령
%     FR_cmd ┤-> [Plugin] 1) clamp(F, ±2353.5)  ├-> FR
%     FB_cmd ┘             2) F -> n            ├-> FB
%                          3) n -> F (검산)     ├-> n      조인트 속도 지령
%                          4) 힘은 1) 의 값     └-> F_err  3) - 1), 0 이어야 함
%
%       n = sign(F) sqrt(|F|/k),  F = k|n|n,   k = rho*Ct*D^4 = k_prop
%
%   어디에 있는 식인가  (gz-sim7  src/systems/thruster/Thruster.cc)
%     :520-521  OnCmdThrust         포화를 **추력에** 건다
%     :562-584  ThrustToAngularVec  추력 -> 회전수
%     :593-599  AngularVelToThrust  회전수 -> 추력
%     :740-756  velocity_control    구한 회전수를 조인트에 바로 쓴다
%     :770-773  AddWorldWrench      링크에 주는 힘은 포화만 거친 지령이다
%   계수는 URDF 에 있다 — wamv_gazebo_thruster_config.xacro:10-24, 펼친 결과는
%   bow_wamv_target.urdf:462-517. Ct = 0.004422, rho = 1000, D = 0.2
%
%   왜 되돌리는 식까지 두는가
%     셋째 식은 플러그인에서 회전수 지령 모드에만 쓰인다. 신호 경로에 넣으면
%     F -> n -> F 가 항등 사상이어서 아무 일도 하지 않는다. 그래서 **검산**으로
%     둔다 — 되돌린 값과 포화한 값의 차이를 F_err 로 내보내 0 인지 눈으로 본다.
%     쓰지 않는 식을 지우지 않고 남기는 까닭은, 모터 회전수가 추력이 되는 그
%     법칙이 제어 배분(Alloc)의 바로 다음 칸이라는 것을 보여야 하기 때문이다.
%     전에 두었던 모터 1차 지연과 회전수 포화는 Gazebo 에 대응하는 것이 없어
%     지웠다 (velocity_control = true 라 지연 없이 조인트에 쓴다).
%
%   그러면 이 단계에서 무엇을 보는가
%     추력이 아니라 **회전수**다. 1단과 궤적·추력이 같게 나오는 것을 먼저
%     확인하고 (환산을 왕복해도 값이 바뀌지 않으므로), 그다음 회전수가
%     n_max = sqrt(F_max/k_prop) 참고선 안에 있는지, 플러그인 한계 2353.5 N
%     까지 얼마나 남았는지 읽는다. 추력은 회전수의 제곱이라 F 를 반으로 줄여도
%     n 은 1/sqrt(2) 배로만 줄어든다 — 그 비선형을 눈으로 보는 자리다.
%
%   왜 한 단계를 차지하는가
%     실기(6단 Gazebo)에서 추진기 토픽을 붙이는 자리가 이 칸이다. 회전수 n 은
%     Thrusters 의 4번째 출력이며, 2단까지 0 으로 채워 두었던 nprop·Ferr 태그가
%     이 단계에서 진짜 값을 받는다 — 그래서 NotYet 상자에서 둘이 빠진다.
%
%   태그 이름이 같은 덕
%     힘 태그 FL·FR·FB 를 내는 자리만 wireForceGotos 에서 wireThrusterGotos
%     로 바뀐다. 운동모델·로깅·그림 쪽은 한 줄도 고치지 않는다.
%
%   목표는 1단과 같다 (W06_setup 3절의 hold_*). 추진기 칸만 떼어 보기
%   위해 다른 것은 하나도 건드리지 않는다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceConst(m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoop    (m, 1150, 280, true);   % true = BowOn 스위치 (2단에서 생긴 뒤 계속 붙어 있다)
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

    sl_note(m, 'n3', ['W06 3단  —  추진기 자리 (Gazebo 플러그인이 하는 일)' newline ...
        '새로 생긴 것 : Thrusters 하나 — 역 프로펠러 법칙을 플러그인 소스 순서대로 적음' newline ...
        '  1) 추력에 포화 (±2353.5 N)  2) n = sign(F)sqrt(|F|/k)  3) F = k|n|n 는 검산' newline ...
        '  링크에 가는 힘은 되돌린 값이 아니라 포화만 거친 지령임 (Thruster.cc:770-773)' newline ...
        '회전수 n 과 검산값 F_err 가 이 단계에서 처음 생김 — NotYet 에서 nprop·Ferr 가 빠짐' newline ...
        '1단과 궤적·추력이 같은지 먼저 보고, 그다음 회전수를 n_max 참고선과 견줄 것' newline ...
        '실행 전: W06_setup (stage = 3)'], 250, -160);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
