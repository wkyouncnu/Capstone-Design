function r = plant(op, varargin)
% PLANT  운동모델 자리 하나 — 오프라인이면 수식, VRX 판이면 Gazebo 토픽 둘
%
%   같은 buildStage<N> 이 오프라인 모델과 VRX 쌍둥이를 **둘 다** 만든다.
%   달라지는 곳은 사슬 끝의 플랜트 하나뿐이다 (스킬 규칙 20 — 예제마다
%   오프라인 먼저, VRX 그다음. 제어기·게인·상자는 글자까지 같다).
%
%     setappdata(0, 'W06_build_vrx', true)   % build_w06_models 가 켰다 끈다
%
%     plant('isvrx')            지금 VRX 판을 만드는 중인가
%     plant('add', m, x, y)     오프라인: MotionModel
%                               VRX    : CmdPublisher (x) + PoseSubscriber (x+450)
%     plant('in')               추력 FL·FR·FB 가 들어가는 블록 이름
%     plant('out')              항법량 아홉 개가 나오는 블록 이름
%     plant('dx')               VRX 판에서 오른쪽으로 더 밀어야 하는 폭 [px]
%     plant('chain', chain)     사슬의 'MotionModel' 을 VRX 판의 두 블록으로 바꿈
%
%   VRX 판에서 보내고 받는 것은 6단(W06_6_vrx)과 같다
%     보냄  /wamv/thrusters/{left,right,bow}/thrust    std_msgs/Float64 [N]
%     받음  /wamv/sensors/position/ground_truth_odometry  nav_msgs/Odometry
%     좌표 변환(ENU -> NED, 선체 y·z 부호, 스폰 원점)은 navCode.m 한 곳에 있다

    vrx = isequal(getappdata(0, 'W06_build_vrx'), true);
    switch op
        case 'isvrx'
            r = vrx;
        case 'add'
            [m, x, y] = varargin{:};
            if ~vrx
                addMotionModel(m, x, y);
            else
                load_system('ros2lib');   % ROS 2 블록은 라이브러리를 열어 두어야 쓴다
                add_cmd_publisher(m, [x y], ...
                    {'/wamv/thrusters/left/thrust', ...
                     '/wamv/thrusters/right/thrust', ...
                     '/wamv/thrusters/bow/thrust'}, 'Ts_ctrl', {'FL','FR','FB'});
                add_pose_subscriber(m, [x+450 y], ...
                    '/wamv/sensors/position/ground_truth_odometry', 'Ts_ctrl', navCode(), ...
                    {'x_n','y_n','psi','u','v','r','beta','chi','U'});
                sl_note(m, 'nvrx', ['VRX 쌍둥이 — 운동모델 자리에 Gazebo 토픽 둘 (나머지는 오프라인판과 같음)' newline ...
                    '보냄 /wamv/thrusters/{left,right,bow}/thrust · 받음 ground_truth_odometry' newline ...
                    '실행: (1) WSL 에서 bash run_vrx_bow.sh  (2) MATLAB 에서 W06_vrx_run(단계 번호)'], ...
                    1000, -160);    % 단계 설명 메모(250, -160) 오른쪽 — 배치가 사슬을 접어도 맨 위에 남는다
            end
            r = [];
        case 'in'
            if vrx, r = 'CmdPublisher'; else, r = 'MotionModel'; end
        case 'out'
            if vrx, r = 'PoseSubscriber'; else, r = 'MotionModel'; end
        case 'dx'
            r = 450 * vrx;
        case 'chain'
            r = varargin{1};
            if vrx
                k = find(strcmp(r, 'MotionModel'));
                r = [r(1:k-1), {'CmdPublisher', 'PoseSubscriber'}, r(k+1:end)];
            end
        otherwise
            error('plant: 모르는 동작 %s', op);
    end
end
