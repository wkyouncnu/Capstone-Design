function [chain, boxes] = buildStage6(m)
% 6단  W06_6_vrx — Gazebo 연동, 즉 "운동모델만 실물로 바뀐다"
%
%   이번에 새로 생긴 것 : 플랜트가 수식이 아니라 **Gazebo** 다
%                         (addMotionModel -> CmdPublisher + PoseSubscriber)
%
%   5단까지 배는 MATLAB Function 안의 미분방정식이었다. 6단에서 그 자리에
%   토픽 둘이 들어간다. 제어기 쪽은 한 글자도 바뀌지 않는다 — 유도부·바깥
%   고리·안쪽 고리·추진기·게인이 5단 그대로다. 그래서 두 결과가 다르면
%   원인은 제어기가 아니라 플랜트(또는 페이싱)다.
%
%     5단   ... Thrusters -> MotionModel -> (x_n y_n psi u v r ...)
%     6단   ... Thrusters -> CmdPublisher -> [ Gazebo ] -> PoseSubscriber
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
%   좌표계를 두 번 고친다 (Nav 안)
%     (1) ENU -> NED      Gazebo 는 x 동쪽·y 북쪽, 해양제어는 x 북쪽·y 동쪽
%                         북 = y_ENU,  동 = x_ENU,  psi = pi/2 - yaw_ENU
%     (2) 선체 y·z 부호   Gazebo 의 선체축은 y 가 **좌현**, 해양제어는 우현
%                         u = bx,  v = -by,  r = -wz
%
%     부호를 하나라도 빼먹으면 선수추진기가 반대로 밀고 배는 선석에서
%     멀어진다. 5단과 6단의 그림을 겹쳐 보는 이유가 이것이다.
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
%
%   페이싱 — 이 단계에서만 생기는 문제
%     Gazebo 는 컴퓨터에 따라 실시간보다 느리게 돈다. Simulink 를 벽시계에
%     맞춰 돌리면 배는 그만큼 적은 시뮬레이션 시간을 산다. W06_vrx_run 이
%     RTF 를 재서 페이싱에 그 값을 넣는다 (강의노트 G-5 절).
%
%   상자 넷(그림·로깅·스코프·자동정지)은 5단 그대로다. 같은 그래프를 보고
%   견주려면 같은 상자여야 한다.
    sl_fresh(m);
    sl_solver(m, 'T_run');
    load_system('ros2lib');     % ROS 2 블록은 라이브러리를 열어 두어야 쓴다

    addGuidance  (m,  250,  60);
    addOuterLoop (m,  700,  60);
    addInnerLoop (m, 1150, 280);
    addThrusters (m, 1600, 280);

    %  운동모델이 있던 자리 — 추력을 토픽으로 보내고, 자세를 토픽으로 받는다
    add_cmd_publisher(m, [2050 280], ...
        {'/wamv/thrusters/left/thrust', ...
         '/wamv/thrusters/right/thrust', ...
         '/wamv/thrusters/bow/thrust'}, 'Ts_ctrl', {'FL','FR','FB'});

    add_pose_subscriber(m, [2500 280], ...
        '/wamv/sensors/position/ground_truth_odometry', 'Ts_ctrl', navCode(), ...
        {'x_n','y_n','psi','u','v','r','beta','chi','U'});

    wireGuid(m, {'x_n','y_n','psi'}, ...
                {'x_ref','y_ref','psi_ref','gate','phase'}, 520, 60);
    wireLoops(m, 620, 200, 1020, 60);

    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Thrusters/%d',k), ...
                 'autorouting','on');
    end

    wireThrusterGotos(m, 1840, 290);
    feedForces(m, 'CmdPublisher', 1980, 300);
    wireNavGotos(m, 'PoseSubscriber', 2900, 280);

    boxes = addBoxes(m, {'psi_ref','psi'; 'x_ref','x_n'; 'y_ref','y_n'; ...
                         '','u'; '','v'}, 3000, 60, true);

    sl_note(m, 'n6', ['W06 6단  —  Gazebo 연동 (운동모델만 실물로 바뀐다)' newline ...
        '새로 생긴 것 : 플랜트가 수식이 아니라 Gazebo — 토픽 셋을 보내고 하나를 받음' newline ...
        '제어기는 5단과 한 글자도 다르지 않음 — 다르면 원인은 플랜트나 페이싱임' newline ...
        '선수추진기 토픽(/wamv/thrusters/bow/thrust)은 xacro 에 추진기를 더해야 생김' newline ...
        'Nav 가 ENU->NED 와 선체 y·z 부호를 고치고 스폰 원점을 뺌' newline ...
        '실행 전: (1) W06_setup (stage = 6)  (2) VRX 기동  (3) W06_vrx_run'], 250, -190);

    save_system(m);  close_system(m);
    chain = {'Guidance','OuterLoop','InnerLoop','Thrusters', ...
             'CmdPublisher','PoseSubscriber'};
end

% ---------------------------------------------------------------------
function code = navCode()
%  Gazebo 의 odometry(ENU) 를 해양제어의 항법량(NED) 으로 바꾼다.
%  출력 순서는 addMotionModel 의 States 와 **같다** — 그래야 wireNavGotos 가
%  같은 태그 아홉 개를 내고, 로깅·그림·스코프가 5단과 똑같이 읽는다.
code = strjoin({
  'function [x_n, y_n, psi, u, v, r, beta, chi, U] = Nav(ex, ey, qx, qy, qz, qw, bx, by, wz, org_x, org_y)'
  '%#codegen'
  '%  Gazebo/ROS 는 ENU 에 선체축 x 앞 · y 좌현 · z 위.'
  '%  해양제어는 NED 에 선체축 x 앞 · y 우현 · z 아래.'
  '%'
  '%    위치   : 북 = y_ENU,  동 = x_ENU   (스폰 원점을 뺀다)'
  '%    선수각 : psi = pi/2 - yaw_ENU'
  '%    선체속도: u = bx,  v = -by,  r = -wz   (y·z 부호가 바뀐다)'
  ''
  '%  첫 메시지가 오기 전 Subscribe 는 0 으로 채운 버스를 낸다. 그대로 쓰면'
  '%  위치가 스폰 원점만큼(약 568 m) 튀어 로그 첫 점이 망가진다.'
  'if ex == 0 && ey == 0'
  '    x_n = 0; y_n = 0; psi = 0; u = 0; v = 0; r = 0; beta = 0; chi = 0; U = 0;'
  '    return'
  'end'
  'x_n = ey - org_x;    % north, 스폰 기준 상대좌표'
  'y_n = ex - org_y;    % east'
  ''
  'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'
  'p   = pi/2 - yaw_enu;'
  'psi = atan2(sin(p), cos(p));'
  ''
  'u = bx;'
  'v = -by;'
  'r = -wz;'
  ''
  'U    = sqrt(u*u + v*v);'
  'beta = atan2(v, u);          % 크랩각'
  'c    = psi + beta;'
  'chi  = atan2(sin(c), cos(c));'
  }, newline);
end
