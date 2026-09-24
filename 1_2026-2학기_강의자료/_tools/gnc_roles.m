function role = gnc_roles(mdl)
%GNC_ROLES  모델별 최상위 블록의 역할표. 온 과목의 표가 여기 하나뿐이다.
%
%   role = gnc_roles('W03_4_teleop')
%   paint_roles('W03_4_teleop')            % 인자를 비우면 이 함수를 부른다
%
%   돌려주는 것  N×2 cell — {블록이름, gnc_colour 의 단계 이름}
%   모르는 모델  빈 표. 그래도 paint_roles 가 물려받기와 회색 칠하기는 한다
%
%   WHY ONE TABLE AND NOT ONE PER BUILDER
%
%   전에는 빌더마다 같은 루프를 들고 있었다. W05~W08 만 들고 있었고 W02·W03·
%   W09·W04 은 빠져 있었다 — 2026-09-17 감사에서 48개 모델 전부가 걸렸다.
%   표가 하나면 새 모델을 만들 때 어디에 적어야 할지 헷갈릴 일이 없고,
%   "3주차 Nav 는 무슨 색인가" 를 한 파일에서 답할 수 있다.
%
%   적는 것은 최상위 블록뿐이다. 안쪽 서브시스템은 부모 색을 물려받고,
%   Scope·Display·Goto·From 류는 언제나 회색이다 (paint_roles.m 참조).
%
%   이름이 겹쳐도 된다 — 모델에 없는 이름은 조용히 넘어간다. 그래서 같은 주차의
%   offline · vrx 두 모델이 표 하나를 나눠 쓴다.

[~, m] = fileparts(char(mdl));

%  주차별로 공통인 사슬. 5~7주차가 같은 이름을 쓴다
GNC = {'Guidance','guidance'; 'Mission','mission'; 'InnerLoop','control'; ...
       'Thrusters','thruster'; 'MotionModel','plant'; ...
       'CmdPublisher','ros'; 'PoseSubscriber','ros'; ...
       'Animate','measurement'; 'Logging','measurement'};

switch m
% ---- 2주차 · turtlesim -------------------------------------------------
case 'W02_1_pose_sub'
    role = {'PoseSub','ros'; 'VelSub','ros'; 'Sel','ros'; 'SelVel','ros'; ...
            'Rad2Deg','ros'};
case 'W02_2_goto_offline'
    role = [GNC; {'Control','control'; 'TurtlePlant','plant'}];
case 'W02_3_goto_turtlesim'
    role = [GNC; {'Control','control'}];

% ---- 3주차 · 좌표계 ----------------------------------------------------
%   Nav·FrameConv 는 '신호처리' 여서 ROS 와 같은 연보라다. ENU 를 NED 로
%   바꾸는 것은 계산이지 제어가 아니다
case 'W03_1_frame_check'
    role = [GNC; {'FrameConv','ros'; 'Rad2DegPsi','ros'; 'Rad2DegYaw','ros'}];
case {'W03_2_vrx_nav','W03_3_vrx_drive'}
    role = [GNC; {'SensorSubscriber','ros'; 'Nav','ros'}];
case {'W03_0_offline','W03_4_teleop'}
    %   TeleopPad 가 파랑인 이유 — 유도 자리에 사람이 들어간다. 5주차에서
    %   LOS 가 대신하게 될 그 자리다
    role = [GNC; {'TeleopPad','guidance'; 'OdomNav','ros'}];

% ---- 9주차 · 토픽 조사 -------------------------------------------------
case 'W09_0_offline'
    %   SensorModel 은 1단계 SensorSubscriber 자리를 대신한다 — 같은 연보라
    role = [GNC; {'Command','guidance'; 'SensorModel','ros'; 'RateMeter','ros'}];
case 'W09_1_sensor_rates'
    role = [GNC; {'SensorSubscriber','ros'; 'RateMeter','ros'}];
case 'W09_2_qos_test'
    role = [GNC; {'QosSubscribers','ros'; 'RxCount','ros'}];

% ---- 4주차 · ROS2 연동과 첫 제어기 -------------------------------------
case {'W04_1_straight','W04_2_turn'}
    role = [GNC; {'PubL','ros'; 'PubR','ros'; 'BlankL','ros'; 'BlankR','ros'; ...
                  'AsgL','ros'; 'AsgR','ros'; 'Scenario','guidance'}];
case {'W04_3_heading','W04_4_inner_loop','W04_3_heading_offline', ...
      'W04_4_inner_loop_offline','W04_6_wrap'}
    role = [GNC; {'PubL','ros'; 'PubR','ros'; 'BlankL','ros'; 'BlankR','ros'; ...
                  'AsgL','ros'; 'AsgR','ros'; 'OdomSub','ros'; ...
                  'Quat2Yaw','ros'; 'Sel','ros'; ...
                  'HeadingCtrl','control'; 'PI_u','control'; 'SumU','control'; ...
                  'OpenLoop','control'; 'PortEff','thruster'; ...
                  'Alloc','allocation'}];
case 'W04_5_offline'
    role = [GNC; {'Scenario','guidance'; 'HeadingCtrl','control'; ...
                  'Alloc','allocation'; 'MotorLag','thruster'; ...
                  'EOM','plant'; 'States','plant'; 'Integ','plant'; 'MuxF','plant'}];

% ---- 4주차 · PID 연습 --------------------------------------------------
case {'W04_P0_plant','W04_P0_second_order','W04_P1_pid_step', ...
      'W04_P2_pid_byhand','W04_P3_boat_speed','W04_P4_lowpass'}
    role = [GNC; {'PID','control'; 'PID_lib','control'; 'PID_byhand','control'; ...
                  'PID_u','control'; 'OpenLoop','control'; ...
                  'SumE','control'; 'SumE_hand','control'; 'SumE_lib','control'; ...
                  'Plant','plant'; 'Plant_hand','plant'; 'Plant_lib','plant'; ...
                  'PlantODE','plant'; 'Plant_tf','plant'; 'G2','plant'; ...
                  'EOM','plant'; 'Integ','plant'; 'MotorLag','thruster'; ...
                  'RefScenario','guidance'; 'RefShape','guidance'; ...
                  'LPF','ros'; 'NoiseHF','env'; 'SumIn','env'; ...
                  'Boat','plant'; 'SensorNoise','env'; ...
                  'SumY_hand','env'; 'SumY_lib','env'; 'Dcompare','measurement'}];

% ---- 부록 A1 · SB 드릴 ----------------------------------------------
%   SB 는 GNC 사슬이 아니라 Simulink 블록 자체를 가르친다. 그래서 단계 색을
%   억지로 입히지 않는다. 뜻이 분명한 것만 — 전달함수는 초록, 제어기는 주황,
%   계산용 서브시스템은 연보라(신호처리) — 칠하고 나머지는 흰색으로 둔다
case {'SB2_mfcn_done','SB2_mfcn_todo'}
    role = {'Scale','ros'; 'SumDiff','ros'; 'WrapPi','ros'};
case {'SB3_subsys_done','SB3_subsys_todo'}
    role = {'Calc','ros'};
case {'SB5_pid_done','SB5_pid_todo'}
    role = {'PID','control'; 'Err','control'; 'Ref','command'; 'Plant','plant'; ...
            'Sat','control'};
case {'SB11_enabled_done','SB11_enabled_todo'}
    role = {'EnSub','ros'; 'TrigSub','ros'};
case {'SB12_reuse_done','SB12_reuse_todo'}
    role = {'Lag_fast','plant'; 'Lag_slow','plant'};
case {'SB13_stateflow_done','SB13_stateflow_todo'}
    role = {'Mission','mission'; 'Dist','plant'};

% ---- 5~8주차 · 유도·제어 사슬 ------------------------------------------
case {'W05_0_offline','W05_1_vrx','W06_0_offline','W06_1_vrx', ...
      'W07_0_offline','W07_1_vrx'}
    role = GNC;
case {'W08_0_offline','W08_1_vrx'}
    role = [GNC; {'DPRef','guidance'; 'WaveFilter','ros'; 'DPCtrl','control'; ...
                  'Alloc','allocation'; 'Env','env'}];

otherwise
    role = GNC;     % 이름이 관례를 따르면 그대로 맞는다
end
end
