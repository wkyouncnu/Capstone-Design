% =====================================================================
% 사슬 4 · 3단에서 생김  Thrusters — Gazebo 추진기 플러그인을 옮겨 적은 칸
% =====================================================================
%   5주차와 같은 자리이고 축만 둘에서 셋으로 늘었다.
%
%   VRX 추진기 토픽 /wamv/thrusters/*/thrust (std_msgs/Float64) 가 받는 것은
%   **뉴턴**이다. 역 프로펠러 법칙은 제어기가 아니라 플러그인 **안**에 있다.
%   이 칸은 그 플러그인이 하는 일을 소스와 같은 순서로 다시 적는다
%   (2026-10-15 에 소스를 직접 열어 확인했다).
%
%   계수가 적힌 자리
%     vrx/vrx_urdf/wamv_gazebo/urdf/thruster_layouts/
%                                    wamv_gazebo_thruster_config.xacro:10-24
%     펼친 결과  bow_wamv/bow_wamv_target.urdf:462-473 (left) · :484-495
%                (right) · :506-517 (middle = 선수추진기). 세 추진기가 같은
%                계수를 쓴다 — Ct = 0.004422, rho = 1000, D = 0.2
%   플러그인 소스  gz-sim7  src/systems/thruster/Thruster.cc
%     :520-521  OnCmdThrust         clamp(cmd, cmdMin, cmdMax)  <- 포화는 추력에
%     :562-584  ThrustToAngularVec  omega = sign(F*Ct)*sqrt(|F|/(rho*Ct*D^4))
%     :593-599  AngularVelToThrust  F = rho*Ct*D^4*|omega|*omega
%     :740-756  velocity_control    구한 omega 를 JointVelocityCmd 로 바로 쓴다
%     :770-773  AddWorldWrench      링크에 주는 힘은 **포화만 거친 지령**이다
%
%   세 번째 식은 플러그인에서 회전수 지령 모드에만 쓰인다. 여기서는 두 번째를
%   되돌려 맞는지 보는 **검산**으로 두고, 그 차이를 F_err 로 내보내 로깅한다.
%   두 식이 서로의 역함수이므로 0 이 나와야 한다.
function addThrusters(m, x, y)
    ss = add_subsys(m, 'Thrusters', [x y x+190 y+190], ...
                    {'FL_cmd','FR_cmd','FB_cmd'}, {'FL','FR','FB','n','F_err'}, ...
                    gnc_colour('thruster'));

    %  블록 하나에 네 토막을 다 적는다. 통과선에서 가지를 치지 않는 이유 —
    %  가지를 치면 Inport 하나에 선이 둘 달리고, square_lines 는 Inport 를
    %  **잎 블록**으로 보아 한쪽 포트 높이로 끌어간다. 그러면 다른 한쪽이 꺾이고
    %  세로 토막이 겹친다 (2026-10-15 5주차에서 측정, 겹침 75 px). 포트를 늘려
    %  한 블록으로 받으면 선이 모두 직선이다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Plugin'], ...
              'Position', [250 60 450 320]);          % 포트 5개 — 52*4+40 = 248 이상
    sl_fcn(ss, 'Plugin', strjoin({
      'function [FL, FR, FB, n, F_err] = Plugin(FL_cmd, FR_cmd, FB_cmd, k, F_lim)'
      '%#codegen'
      '%  Gazebo 추진기 플러그인이 하는 일을 소스와 같은 순서로 적는다.'
      '%    gz-sim7  src/systems/thruster/Thruster.cc'
      ''
      '%  1) 포화 — 플러그인은 **추력에** 건다 (OnCmdThrust, :520-521)'
      '%       thrust = clamp(cmd, cmdMin, cmdMax),  cmdMax = max_thrust_cmd'
      'F = [FL_cmd; FR_cmd; FB_cmd];'
      'F = max(-F_lim, min(F_lim, F));'
      ''
      '%  2) 추력 -> 회전수 (ThrustToAngularVec, :562-584). 이 값이 조인트'
      '%     속도 지령이 된다 — velocity_control = true (:740-756)'
      '%       omega = sign(F*Ct)*sqrt(|F|/(rho*Ct*D^4)),  k = rho*Ct*D^4'
      '%     Ct > 0 이므로 sign(F*Ct) = sign(F) 다'
      'n = sign(F) .* sqrt(abs(F)/k);'
      ''
      '%  3) 회전수 -> 추력 (AngularVelToThrust, :593-599). 플러그인에서는'
      '%     회전수 지령 모드에만 쓰인다. 여기서는 2) 를 되돌려 맞는지 보는'
      '%     **검산**이다 — 두 식이 서로의 역함수이므로 0 이 나와야 한다'
      '%       F = rho*Ct*D^4 * |omega| * omega'
      'F_chk = k * abs(n) .* n;'
      'F_err = F_chk - F;'
      ''
      '%  4) 링크에 가는 힘은 되돌린 값이 아니라 포화만 거친 지령이다'
      '%     (AddWorldWrench 가 desiredThrust 를 그대로 쓴다, :770-773)'
      'FL = F(1);'
      'FR = F(2);'
      'FB = F(3);'
      }, newline));
    sl_const(ss, 'Kp',   'k_prop',       60, 340);
    sl_const(ss, 'Flim', 'F_plugin_max', 60, 400);
    row_feed(ss, 'Plugin', {'FL_cmd','FR_cmd','FB_cmd','Kp','Flim'});

    %  다섯 잎 블록을 각자의 포트 높이에 맞춘다 — 다섯 선이 모두 직선이 된다
    outs = {'FL','FR','FB','n','F_err'};
    for k = 1:numel(outs)
        p = port_xy(ss, 'Plugin', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [580 p(2)-10 615 p(2)+10]);
        add_line(ss, sprintf('Plugin/%d',k), [outs{k} '/1']);
    end

    sl_note(ss, 'n_t', [ ...
        'Gazebo 추진기 플러그인(gz::sim::systems::Thruster)을 그 순서대로 적은 칸' newline ...
        '1) 포화를 추력에 건다  2) 추력 -> 회전수  3) 되돌려 검산  4) 힘은 1) 의 값' newline ...
        '회전수는 조인트 속도 지령이 되는 값이다 — velocity_control = true' newline ...
        '세 추진기가 같은 계수를 쓴다. 플러그인 한계는 편당 2353.5 N (URDF)' newline ...
        'F_err = 되돌린 추력 - 포화한 추력. 두 식이 서로의 역함수이므로 0 이어야 한다'], 250, 460);
end
