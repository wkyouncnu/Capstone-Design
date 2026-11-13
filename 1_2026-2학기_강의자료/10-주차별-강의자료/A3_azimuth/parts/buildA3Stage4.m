function [chain, boxes] = buildA3Stage4(m)
% 4단  A3_4_vrx — 가제보(VRX) 연동. **모델은 이 하나뿐이다**
%
%   2단(A3_2_pose) 의 쌍둥이다. 바뀐 것은 운동모델 자리 하나다
%     오프라인   Alloc -> MotionModel -> (항법량)
%     VRX        Alloc -> PosSign -> CmdPublisher -> 가제보 -> PoseSubscriber
%   유도·제어·배분은 **글자 하나까지 같다.** 그래야 오프라인과 가제보의 차이가
%   모델 차이가 아니라 환경 차이임을 말할 수 있다.
%
%   왜 과업마다 모델을 만들지 않는가
%     순수 횡이동 · 접안 · 위치 유지는 전부 **목표점 하나(x_d, y_d, psi_d)** 로
%     표현된다. 배가 어떻게 가는가는 제어기가 정하고, 사람이 정하는 것은 목표뿐이다.
%       1 횡이동   현재 선수각을 그대로 두고 옆으로만 목표를 옮긴다
%       2 유지     목표점을 향해 서서 가 그 자리를 계속 잡는다
%                  (gate 가 1 이 되어도 위치 고리는 살아 있다)
%       3 접안     목표점을 부두 앞에 두고 선수각을 부두와 맞춘다
%     그래서 모델은 하나이고, 목표 셋은 A3_setup 의 vrx_target 으로 고른다.
%     실행은 A3_4_vrx_run(과업) 한 줄이다.
%
%   사슬
%     Guidance -> OuterLoop -> InnerLoop -> Alloc -> PosSign -> CmdPublisher
%                                                              PoseSubscriber
%
%   보내는 것 · 받는 것 (A3_setup 의 vrx_*_topic — 문자열을 도면에 박지 않는다)
%     보냄  /wamv/thrusters/{left,right}/thrust   추력 [N]
%           /wamv/thrusters/{left,right}/pos      조인트 각도 [rad], pos = -delta
%     받음  /wamv/sensors/position/ground_truth_odometry
%
%   ±45 deg 는 두 곳이 지킨다
%     Alloc 안의 AzAlloc    배분 단계에서 각도를 깎는다 (설계 전제)
%     PosSign              변화율 + 1 차 지연으로 **조인트가** 한계를 넘지 않게 한다
%     둘째가 없으면 가제보 서보가 울렁거려 ±45 deg 를 넘는다 — 5단에서 실측했다
%
%   실행
%     (1) WSL   W03_vrx_lite 에서  bash run_vrx.sh lite      (선수추진기 없는 판)
%     (2) MATLAB  >> A3_5_tilt_run      먼저 서보가 도는지 확인
%     (3) MATLAB  >> A3_4_vrx_run(1)    1 = 순수 횡이동 · 2 = 위치 유지 · 3 = 접안
    sl_fresh(m);
    sl_solver(m, 'T_run');

    load_system('ros2lib');          % ROS 2 블록은 라이브러리를 열어 두어야 쓴다

    addGuidanceStop (m,  250,  60);
    addOuterLoop    (m,  700,  60);
    addInnerLoopA3  (m, 1150, 280);
    addAzAlloc      (m, 1600, 280);
    addPosSign      (m, 2050, 280);

    %  토픽 넷 — 순서가 곧 입력 이름 순서다 (추력 좌 · 각도 좌 · 추력 우 · 각도 우)
    tp = {evalin('base','vrx_thr_topic{1}'), evalin('base','vrx_pos_topic{1}'), ...
          evalin('base','vrx_thr_topic{2}'), evalin('base','vrx_pos_topic{2}')};
    add_cmd_publisher(m, [2500 280], tp, 'Ts_ctrl', {'TL','dL','TR','dR'});

    add_pose_subscriber(m, [2950 280], evalin('base','vrx_odom_topic'), 'Ts_ctrl', ...
                        navCode(), ...
                        {'x_n','y_n','psi','u','v','r','beta','chi','U'});

    wireGuid    (m, {'x_n','y_n','psi'}, ...
                    {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops   (m, 620, 200, 1020, 60);
    wireAllocVrx(m, 1840, 290, 2400, 300);
    wireNavGotos(m, 'PoseSubscriber', 3400, 280, ...
                 {'x_n','y_n','psi','u','v','r','beta','chi','U'});

    %  실제 렌치 셋(X_a·Y_a·N_a) 은 운동모델이 내던 것이다. 그 자리에 가제보가
    %  들어섰으므로 상자로 떼어 계산한다 — 로깅·그림이 쓰는 태그를 모두 채운다
    addWrenchBox(m, 3700, 280);

    boxes = addBoxesA3(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                           '','v'; '','dL'}, 3950, 60, true);
    boxes = [boxes {'Wrench'}];

    sl_note(m, 'n4', ['A3 4단  —  가제보(VRX) 연동. **모델은 이 하나뿐이다**' newline ...
        '2단의 쌍둥이 — 운동모델 자리에 토픽 넷과 ground truth 가 들어섰음' newline ...
        '과업 셋(횡이동 · 접안 · 위치 유지) 은 목표점만 바뀐다 — A3_setup 의 vrx_target' newline ...
        '±45 deg : Alloc 이 지령을, PosSign 이 조인트를 지킨다 (5단 실측)' newline ...
        '가제보를 먼저 띄울 것 — W03_vrx_lite 의 run_vrx.sh lite (선수추진기 없음)' newline ...
        '실행: >> A3_4_vrx_run(1)   1 = 횡이동 · 2 = 위치 유지 · 3 = 접안'], 250, -180);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Alloc','PosSign', ...
             'CmdPublisher','PoseSubscriber'};
end
