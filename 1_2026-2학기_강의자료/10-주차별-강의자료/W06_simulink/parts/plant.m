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
%   오프라인 판에서 배는 MATLAB Function 안의 미분방정식이다. VRX 판에서는
%   그 자리에 토픽 둘이 들어간다. 제어기 쪽은 한 글자도 바뀌지 않으므로, 두
%   결과가 다르면 원인은 제어기가 아니라 플랜트(또는 페이싱)다.
%
%     오프라인   ... Thrusters -> MotionModel -> (x_n y_n psi u v r ...)
%     VRX        ... Thrusters -> CmdPublisher -> [ Gazebo ] -> PoseSubscriber
%
%   보내는 것 — 추진기 셋의 추력 [N]
%     /wamv/thrusters/left/thrust    std_msgs/Float64
%     /wamv/thrusters/right/thrust   std_msgs/Float64
%     /wamv/thrusters/bow/thrust     std_msgs/Float64
%
%     5주차와 토픽 **하나**가 다르다. 선수추진기 토픽은 WAM-V 의 기본 구성에
%     없으므로 xacro 에 추진기를 더해 두어야 한다 (강의노트 G-1 절,
%     W06_vrx_lite/make_wamv_bow.sh 가 만든다). 토픽이 없으면 발행은 조용히
%     버려지고 배는 선수각만 겨우 맞춘 채 옆으로 가지 않는다.
%
%   받는 것 — ground truth odometry 하나
%     /wamv/sensors/position/ground_truth_odometry   nav_msgs/Odometry
%
%   좌표계를 두 번 고친다 (Nav 안. 식은 navCode.m 한 곳에 있다)
%     (1) ENU -> NED      Gazebo 는 x 동쪽·y 북쪽, 해양제어는 x 북쪽·y 동쪽
%                         북 = y_ENU,  동 = x_ENU,  psi = pi/2 - yaw_ENU
%     (2) 선체 y·z 부호   Gazebo 의 선체축은 y 가 **좌현**, 해양제어는 우현
%                         u = bx,  v = -by,  r = -wz
%
%     부호를 하나라도 빼먹으면 선수추진기가 반대로 밀고 배는 선석에서
%     멀어진다. 쌍둥이의 그림을 겹쳐 보는 이유가 이것이다.
%
%   스폰 원점을 빼는 까닭
%     VRX 는 배를 월드 좌표 어딘가(이 설치에서는 ENU 로 약 (-532, 200)) 에
%     띄운다. 제어기는 (0,0) 에서 출발하는 상대좌표로 짜여 있으므로 첫
%     샘플의 위치를 origin_north · origin_east 로 빼 준다. 값은 W06_setup 에
%     있고, W06_vrx_run 이 첫 샘플로 덮어쓴다.
%
%   첫 메시지가 오기 전
%     Subscribe 는 0 으로 채운 버스를 낸다. 그대로 변환하면 위치가 스폰
%     원점만큼 튀어 로그 첫 점이 망가진다 — Nav 첫머리의 가드가 막는다.

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
