function [chain, boxes] = buildStage4(m)
% 4단  W06_4_stop — 도착 판정과 정지 게이트, 즉 "멈추는 법"
%
%   이번에 새로 생긴 것 : 유도부가 상수에서 판정으로 바뀌고 (addGuidanceStop),
%                         AutoStop 상자가 붙는다
%
%   3단까지는 gate 가 늘 1 이었다. 배는 목표에 닿아도 속도 지령을 계속 받아
%   그 자리를 잡고 있었다 — 멈춘 것이 아니라 "버티고" 있었던 것이다.
%
%     도착 = 거리가 R_stop 안이고 선수각 오차가 5 deg 안
%     도착하면 phase 가 0 -> 1 로 올라가고 gate 가 1 -> 0 으로 닫힌다
%     gate = 0 이면 바깥 고리가 속도 지령을 0 으로 내려 배가 선다
%
%   래치가 왜 필요한가
%     gate 가 닫히면 배가 관성으로 조금 더 간다. 그러면 거리가 R_stop 을 다시
%     넘어 gate 가 열리고, 또 닫히고 — 깜빡인다. 한 번 도착했으면 끝이라고
%     기억해야 한다. phase 는 한 번 올라가면 내려오지 않는다.
%
%   Unit Delay 가 왜 끼는가
%     phase 는 자기 자신의 입력이다. 그대로 되먹이면 대수 루프가 되어 Simulink
%     가 풀지 못한다. 한 스텝 전 값을 쓰면 끊어진다. 이 모델에서 이산 블록은
%     이것 하나이며, 표본 간격이 고정 스텝(Ts_ctrl)과 같으므로 솔버와 어긋나지
%     않는다.
%
%   AutoStop
%     gate 가 0 이 된 뒤 stop_hold 초를 더 돌고 시뮬레이션이 스스로 멈춘다.
%     T_run 까지 끌지 않으므로 표본 수가 단계마다 다르다 — 대조할 때는 짧은
%     쪽의 표본 수만큼만 맞댄다.
%
%   이 단계부터 phase 가 진짜 값을 갖는다. 2·3단에서 0 으로 채워 두었던
%   NotYet 상자가 이제 필요 없어 사라진다.
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addGuidanceStop(m,  250,  60);
    addOuterLoop   (m,  700,  60);
    addInnerLoop   (m, 1150, 280, true);    % true = BowOn 스위치 (2단에서 생긴 뒤 계속 붙어 있다)
    addThrusters   (m, 1600, 280);
    addMotionModel (m, 2050, 280);

    wireGuid(m, {'x_n','y_n','psi'}, ...
                {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);

    %  안쪽 고리의 추력 지령 셋을 추진기로 바로 잇는다 (3단과 같다)
    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Thrusters/%d',k), ...
                 'autorouting','on');
    end

    wireThrusterGotos(m, 1840, 290);
    feedForces(m, 'MotionModel', 1980, 300);
    wireNavGotos(m, 'MotionModel', 2410, 280);

    %  NotYet 상자가 없다 — 로깅·그림이 쓰는 태그를 이제 전부 모델이 낸다
    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 2510, 60, true);

    sl_note(m, 'n4', ['W06 4단  —  도착 판정과 정지 게이트 (멈추는 법)' newline ...
        '새로 생긴 것 : 유도부의 도착 판정(phase 래치) + AutoStop 상자' newline ...
        '도착 = 거리 < R_stop 이고 선수각 오차 < 5 deg -> phase 1, gate 0' newline ...
        'gate = 0 이면 속도 지령이 0 — 배가 버티는 것이 아니라 선다' newline ...
        'AutoStop 이 gate = 0 뒤 stop_hold 초에 시뮬레이션을 멈춤 (표본 수가 줄어듦)' newline ...
        '실행 전: W06_setup (stage = 4)'], 250, -160);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters','MotionModel'};
end
