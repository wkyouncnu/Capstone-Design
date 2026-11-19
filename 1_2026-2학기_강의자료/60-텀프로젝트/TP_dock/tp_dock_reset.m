function p = tp_dock_reset(psi_deg, ne)
%TP_DOCK_RESET  배를 주어진 자리·선수각으로 세우고 **멈춘 채로** 넘긴다 — 실험 간 초기화
%
%   p = tp_dock_reset                      WP1 (북 10, 동 0) · 선수각 0 deg
%   p = tp_dock_reset(-88)                 선수각을 주어 세운다
%   p = tp_dock_reset(-88, [16.7 -8.75])   자리까지 주어 세운다 (북, 동)
%     - 자리를 주는 것은 **진단용임.** 진입 성적을 잴 때는 WP1 에서 출발한다
%
%   왜 필요한가
%     - 칸 1·2·3 을 차례로 들어가 보려면 **같은 자리에서 출발**해야 비교가 된다
%       앞 시도가 끝난 자리(칸 안)에서 다음 시도를 시작하면 측정값을 견줄 수 없다
%     - 볼트 규칙 "실험 간 초기화" 를 그대로 따른 것임
%
%   순서 — 이 순서여야 한다
%     1. 추력·방향각을 0 으로 내린다
%     2. 세계를 **돌린 채** 몇 초 둔다 — 물의 저항이 남은 속도를 빼 간다
%     3. 세계를 **멈춘다**
%     4. 멈춘 세계에 자세를 써 넣는다
%     5. 멈춘 세계에서 되읽어 확인한다 (gz model -p 는 멈춰도 읽힌다)
%     6. 멈춘 채로 넘긴다 — TP_dock_run 이 [0] 에서 다시 돌린다
%
%   왜 '멈춘 뒤에' 써 넣는가 — 2026-11-20 실측
%     돌아가는 세계에 써 넣으면 되읽을 때까지 배가 흐른다. 되읽기 자체가
%     구독을 새로 만드는 일이라 4~6 초가 걸리고, 그 사이 1 m/s 로 흐른다
%       실측: (북 16.74, 동 -8.75) · -88.1 deg 로 **다섯 번** 써 넣었는데
%             매번 (북 12.4, 동 -4.7) · -69 deg · 속력 1.05 m/s 로 읽혔다
%             — 6 m 흐르고 19 deg 돌아간 자리에서 진단을 시작한 셈이다
%       실측: 멈춘 세계에 써 넣으면 2 초 뒤에도 (-8.750, 16.740) 그대로다
%     되풀이해 써 넣는 것으로는 못 고친다. 흐름이 **되읽기 시간**에서 오므로
%     써 넣는 횟수를 늘려도 마지막 한 번의 흐름이 그대로 남는다
%
%   왜 먼저 속도를 빼는가
%     vrx_set_pose 는 **자세만** 쓴다. 속도는 그대로 남아 다시 돌릴 때 되살아난다
%     멈춘 세계에 써 넣어도 속도는 얼어 있을 뿐 사라지지 않는다
%     그래서 추력을 0 으로 내리고 몇 초 흘려 **물로 속도를 뺀 뒤** 멈춘다
%
%   z 를 ROS 오도메트리에서 가져오지 않는 까닭
%     같은 순간에 gz 는 z 0.071, ROS 오도메트리는 z -0.17 을 냈다 (실측)
%     기준면이 다르다. vrx_set_pose 는 **gz 자세**를 쓰므로 gz 가 읽은 z 를 준다
%
%   유의 사항
%     - 끝나면 **세계가 멈춘 상태다.** 바로 odom 을 읽으면 timeout 이 난다
%     - 되읽은 잔차를 찍는다. 값을 보고 판단할 것

    if nargin < 1 || isempty(psi_deg), psi_deg = 0;      end
    if nargin < 2 || isempty(ne),      ne      = [10 0]; end

    DOMAIN  = 7;  PART = 'dockA';  WORLD = 'haeyangnuri';  MODEL = 'wamv';
    ODOM    = '/wamv/sensors/position/ground_truth_odometry';
    Z_HOLD  = 0.07;         % 평시 흘수 (gz 기준) 실측값 [m]
    T_COAST = 10;           % 추력 0 으로 흘려 속도를 빼는 시간 [s]
    V_OK    = 0.20;         % 이 아래면 '멈췄다' 로 본다 [m/s]

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    setenv('ROS_DOMAIN_ID', num2str(DOMAIN));

    node = ros2node(sprintf('/tp_dock_reset_%d', randi(9999)), DOMAIN);
    thp  = {ros2publisher(node, '/wamv/thrusters/left/thrust',  'std_msgs/Float64'), ...
            ros2publisher(node, '/wamv/thrusters/right/thrust', 'std_msgs/Float64')};
    azp  = {ros2publisher(node, '/wamv/thrusters/left/pos',  'std_msgs/Float64'), ...
            ros2publisher(node, '/wamv/thrusters/right/pos', 'std_msgs/Float64')};

    %% 1~2. 추력을 내리고, 돌아가는 세계에서 속도를 뺀다
    vrx_play(PART, WORLD);
    sb = ros2subscriber(node, ODOM, 'nav_msgs/Odometry');
    pause(1.0);
    v0 = odom_speed(sb);
    fprintf('[초기화] 속도를 뺀다 — 지금 %.2f m/s · 추력 0 으로 %d 초 흘린다\n', v0, T_COAST);
    t0 = tic;  v = v0;
    while toc(t0) < T_COAST
        for i = 1:2
            send(thp{i}, struct('data', 0));
            send(azp{i}, struct('data', 0));
        end
        pause(0.2);
        if toc(t0) > 3
            v = odom_speed(sb);
            if v < V_OK, break, end
        end
    end
    fprintf('      %.1f 초 뒤 %.2f m/s%s\n', toc(t0), v, ...
            ternary(v < V_OK, '', ' — 아직 남았다. 그래도 멈추고 써 넣는다'));

    %% 3~4. 멈추고 써 넣는다
    world_pause(PART, WORLD);
    [~, ~, zg] = gz_pose(PART, MODEL);
    if isnan(zg) || zg < -0.1 || zg > 0.3
        fprintf('      gz z %.3f 가 평시와 다르다 — %.2f 로 써 넣는다\n', zg, Z_HOLD);
        zg = Z_HOLD;
    end
    %% 4~5. 써 넣고 되읽어 확인한다 — 들을 때까지 다시 부른다
    %
    %   되부르는 까닭 — 2026-11-20 실측
    %     gz service 가 이따금 'Service call timed out' 을 낸다 (자세는 안 바뀜)
    %     세계가 **멈춰 있으므로** 다시 부르는 것이 공짜다 — 흐르지 않는다
    %     한 번 놓친 것을 모르고 넘어가면 엉뚱한 자리에서 실험이 시작된다
    for k = 1:3
        vrx_set_pose(deg2rad(psi_deg), [ne(2) ne(1) zg], PART, WORLD);
        pause(1.0);
        [p, psi] = gz_pose(PART, MODEL);
        dp = hypot(p(1) - ne(1), p(2) - ne(2));
        da = rad2deg(ssa(psi - deg2rad(psi_deg)));
        if dp < 0.10 && abs(da) < 1.0, break, end
        fprintf('      %d 번째 — 아직 자리 %.2f m · 선수각 %+.1f deg 어긋났다. 다시 부른다\n', ...
                k, dp, da);
    end
    fprintf(['[초기화] 끝 — (북 %.2f, 동 %.2f) · 선수각 %.1f deg · 세계 멈춤\n' ...
             '      요구와의 차 — 자리 %.2f m · 선수각 %+.1f deg\n'], ...
            p(1), p(2), rad2deg(psi), dp, da);
    clear sb node
end

% ---------------------------------------------------------------------------
function v = odom_speed(sb)
%ODOM_SPEED  선체 속력 [m/s] — 받은 것이 없으면 NaN
    try
        m = receive(sb, 5);
        v = hypot(m.twist.twist.linear.x, m.twist.twist.linear.y);
    catch
        v = NaN;
    end
end

function [p, psi, z] = gz_pose(partition, model)
%GZ_POSE  가제보에서 자세를 직접 읽는다 — **멈춘 세계에서도 읽힌다**
%   ROS 오도메트리는 멈추면 끊긴다. 그래서 되읽기는 gz 로 한다
%   출력  p = (북, 동) [m] · psi = NED 선수각 [rad] · z = gz 기준 높이 [m]
    sh = ['export GZ_PARTITION=' partition '; timeout 25 gz model -m ' model ' -p'];
    [~, out] = system(['wsl.exe -d Ubuntu-22.04 -e bash -lc "' sh '"']);
    %  'Pose [ XYZ (m) ] [ RPY (rad) ]:' 아래로 숫자 세 개짜리 대괄호가 둘 나온다
    %  경고 줄의 대괄호(`[Utils.cc:132]`)는 이 꼴에 걸리지 않는다
    t = regexp(out, '\[\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s*\]', 'tokens');
    if numel(t) < 2
        p = [NaN NaN];  psi = NaN;  z = NaN;
        fprintf('      (gz 자세를 읽지 못했다)\n');
        return
    end
    xyz = str2double(t{1});          % ENU (동, 북, 높이)
    rpy = str2double(t{2});          % roll pitch yaw (ENU)
    p   = [xyz(2), xyz(1)];          % (북, 동)
    z   = xyz(3);
    psi = ssa(pi/2 - rpy(3));        % ENU yaw -> NED 선수각
end

function world_pause(partition, world)
%WORLD_PAUSE  가제보 세계를 멈춘다 — vrx_play 의 반대
%   가제보 내부 통신은 ROS_DOMAIN_ID 가 아니라 GZ_PARTITION 으로 갈린다
    sh = ['export GZ_PARTITION=' partition '; ' ...
          'gz service -s /world/' world '/control' ...
          ' --reqtype gz.msgs.WorldControl --reptype gz.msgs.Boolean' ...
          ' --timeout 3000 --req ''pause: true'' > /dev/null 2>&1'];
    system(['wsl.exe -d Ubuntu-22.04 -e bash -lc "' sh '"']);
end

function a = ssa(a)
%SSA  각을 (-pi, pi] 로 접는다
    a = mod(a + pi, 2*pi) - pi;
end

function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
