function S = A3_4_vrx_run(task, rec, T)
%A3_4_VRX_RUN  4단 — 가제보(VRX) 에서 **같은 모델 하나로** 세 과업을 돌린다
%
%   >> A3_4_vrx_run(1)        순수 횡이동 (crabbing)
%   >> A3_4_vrx_run(2)        위치·선수각 유지
%   >> A3_4_vrx_run(3)        접안 목표점
%   >> A3_4_vrx_run(1, 0)     녹화 없이 (빠르다)
%   >> A3_4_vrx_run(2, 1, 120) 돌 시간을 120 초로 (기본은 과업마다 다르다)
%
%   모델은 A3_4_vrx.slx **하나뿐이다**
%     세 과업의 차이는 목표점 (x_d, y_d, psi_d) 하나다. 배가 어떻게 가는가는
%     제어기가 정하므로, 과업마다 모델을 따로 만들 이유가 없다. 이 스크립트가
%     A3_setup 의 vrx_target 을 덮어써서 목표만 바꾼다.
%
%   하는 일 — 순서가 곧 **틀리기 쉬운 것의 순서**다
%     [0] 도메인 맞추기      환경변수. 틀리면 토픽이 아예 보이지 않는다
%     [1] 설정·토픽 확인     A3_setup (stage 4) → ros2 topic list 대조
%     [2] 일시정지 풀기      멈춘 세계는 **오류 없이** 각도만 0 으로 준다
%     [3] 스폰 원점 측정     ground truth 첫 샘플. 설치마다 다르다
%     [4] RTF 측정·페이싱    실측값 그대로. 더 높이면 오히려 느려진다
%     [5] 화면 떠내기 시작   가제보 드론뷰를 WSL 쪽에서 따로 받는다
%     [6] 실행 → 중립 복귀   플러그인은 **마지막 명령을 계속 쓴다**
%     [7] 그림·지표·분할영상
%
%   먼저 할 것 — 가제보를 띄운다 (경량 모델, 선수추진기 없음)
%     WSL 터미널에서
%       export ROS_DOMAIN_ID=7
%       export GZ_PARTITION=a3
%       cd ~/Capstone-Design/1_2026-2학기_강의자료/10-주차별-강의자료/W03_vrx_lite
%       bash run_vrx.sh lite
%
%   과업마다 **VRX 를 다시 띄운다.** 앞 실험이 끝난 자리(배가 옮겨 간 자리)에서
%   시작하면 목표까지의 거리가 달라져 결과를 견줄 수 없다.
%
%   끝낼 때 — 띄운 터미널에서 Ctrl+C. 남은 gz sim 이 메모리를 수십 GB 까지
%   먹는다. 다른 세션의 가제보가 함께 돌고 있으면 stop_vrx.sh 를 쓰지 않는다
%   (프로세스 이름으로 끄므로 남의 것까지 끈다).

    if nargin < 1 || isempty(task), task = 1; end
    if nargin < 2 || isempty(rec),  rec  = 1; end
    assert(ismember(task, [1 2 3]), 'A3_4_vrx_run:task', ...
           '과업은 1(횡이동) · 2(위치 유지) · 3(접안) 가운데 하나다');
    %  돌 시간 — 과업마다 다르다. 도착 판정(stop_on)이 걸리면 이보다 먼저 멈춘다.
    %  실시간 페이싱이므로 **벽시계로는 T/RTF 초**가 걸린다 (RTF 0.8 이면 1.25 배)
    T_DEF = [80 110 140];
    if nargin < 3 || isempty(T), T = T_DEF(task); end

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));  addpath(here);  cd(here);

    TAG    = {'1_crab', '2_hold', '3_dock'};
    TNAME  = {'순수 횡이동', '위치·선수각 유지', '접안 목표점'};
    DOMAIN = 7;                  % 가제보를 띄운 터미널의 ROS_DOMAIN_ID
    ODOM   = '/wamv/sensors/position/ground_truth_odometry';

    %% [0] 도메인 — Simulink 블록은 ROS 네트워크 프로필, ros2* 함수는 환경변수
    setenv('ROS_DOMAIN_ID', num2str(DOMAIN));
    fprintf('\n[0] ROS_DOMAIN_ID = %s · 과업 %d (%s)\n', ...
            getenv('ROS_DOMAIN_ID'), task, TNAME{task});

    %% [1] 설정 — 목표만 덮어쓴다
    %    animate_every 를 0.5 로 넓힌다. 0.25 로 두면 Simulink 가 그리는 데
    %    시간을 다 쓰고 가제보를 못 따라간다 (6주차 실측). rec_fps = 2 이므로
    %    1/animate_every 와 같아 **실시간 속도로 재생**된다
    anim_mp4 = fullfile(here, 'img', sprintf('A3_4_vrx_%s_anim.mp4', TAG{task}));
    ov = struct('vrx_target', task, 'T_run', T, ...
                'animate', 1, 'animate_every', 0.5, ...
                'rec_on', double(rec > 0), 'rec_fps', 2, 'rec_name', anim_mp4);
    setappdata(0, 'A3_stage', 4);
    setappdata(0, 'A3_skip_run', true);
    setappdata(0, 'A3_override', ov);
    evalin('base', 'A3_setup');

    B      = @(v) evalin('base', v);
    mdl    = B('mdl');

    %  "설정은 이미 깔려 있다" 고 표시해 둔다 — 이 표시가 없으면 모델의 InitFcn
    %  (A3_model_init) 이 A3_setup 을 **다시** 불러 아래에서 측정한 스폰 원점을
    %  0 으로 되돌린다. 오류는 나지 않는다 — 배가 스폰 원점만큼 어긋난 채 출발한다
    setappdata(0, 'A3_cfg_for', mdl);
    T_run  = B('T_run');
    part   = B('vrx_partition');
    world  = B('vrx_world');
    want   = [B('vrx_thr_topic'), B('vrx_pos_topic'), {B('vrx_odom_topic')}];

    tl   = ros2('topic', 'list');
    miss = want(~ismember(want, tl));
    if ~isempty(miss)
        setappdata(0, 'A3_override', []);
        fprintf(2, '\n보이지 않는 토픽\n');  fprintf(2, '  %s\n', miss{:});
        error('A3_4_vrx_run:notopic', ...
              ['가제보가 떠 있지 않거나 도메인이 다릅니다.\n' ...
               '  - WSL 에서 run_vrx.sh lite 가 돌고 있는지\n' ...
               '  - 그 터미널의 ROS_DOMAIN_ID 가 %d 인지'], DOMAIN);
    end
    fprintf('[1] 토픽 %d 개 확인 · 모델 %s\n', numel(want), mdl);

    %% [2] 일시정지를 푼다 — 멈춘 세계는 오류를 내지 않는다
    vrx_play(part, world);

    %% [3] 출발 상태 맞추기 — **위치와 선수각을 오프라인 초기값에 맞춘다**
    %    (1) 선수각 — competition.launch.py 는 WAM-V 를 ENU yaw 1.0 rad 로 놓는다
    %          Model('wamv', 'wam-v', [-532, 200, 0, 0, 0, 1])
    %        NED 로는 32.70 deg 다. 오프라인 모델은 psi_init 을 적분기 초기값으로
    %        넣으므로 선수각 오차 0 에서 출발한다. 맞추지 않고 비교하면 **환경
    %        차이가 아니라 출발 자세 차이**를 재게 된다
    %          1단(순수 횡이동) 은 psi_d = 0 이라 배가 먼저 32.7 deg 를 돌아야
    %          한다. 도는 동안 횡력이 북쪽 성분을 가져 x 가 부풀었다가
    %          되돌아온다 — "순수 횡이동" 이 아니게 된다
    %          2026-11-13 실측 · 맞추기 전 선수각 오차 최대 47.09 · RMS 12.41 deg
    %                            맞춘 뒤                  9.29 ·      2.38 deg
    %    (2) 위치 — 앞 과업이 끝난 자리에서 다음 과업이 출발하면 안 된다.
    %        1단이 12 m 동쪽으로 간 자리에서 2단을 시작하면 서로 견줄 수 없다.
    %        매 실행 전에 **스폰 지점으로 되돌린다** ("실험 간 초기화")
    %    월드 파일은 3주차 자료가 같이 쓰는 상류 파일이므로 고치지 않는다.
    %    실행 직전에 /world/<세계>/set_pose 로 맞춘다
    HOME_ENU = [-532 200];       % launch.py 의 Model('wamv', ...) 스폰 지점
    node  = ros2node(sprintf('/a3_vrx_probe_%d', randi(9999)), DOMAIN);
    sb    = ros2subscriber(node, ODOM, 'nav_msgs/Odometry');
    mi    = receive(sb, 15);
    psi_i = B('psi_init');
    psi_0 = spawn_psi(mi);
    p0    = mi.pose.pose.position;
    fprintf('[3] 지금 상태 — ENU (%.2f, %.2f) · 선수각 %.2f deg\n', ...
            p0.x, p0.y, rad2deg(psi_0));
    fprintf('    맞출 값   — ENU (%.2f, %.2f) · 선수각 %.2f deg\n', ...
            HOME_ENU(1), HOME_ENU(2), rad2deg(psi_i));
    if hypot(p0.x - HOME_ENU(1), p0.y - HOME_ENU(2)) > 0.5 || ...
       abs(ssa_local(psi_0 - psi_i)) > deg2rad(0.5)
        if ~vrx_set_pose(psi_i, [HOME_ENU p0.z], part, world)
            error('A3_4_vrx_run:setpose', ...
                  '출발 상태를 맞추지 못했습니다 — 위 응답을 볼 것');
        end
        %  되읽기는 **새 구독으로** 한다. receive 는 쌓인 옛 메시지부터 꺼내고,
        %  오도메트리는 100 Hz 로 들어와 수백 개가 밀려 있다. 옛 구독으로
        %  읽으면 옮기기 전의 자세를 보고 "안 움직였다" 고 오해한다
        clear sb;  pause(0.5);
        sb = ros2subscriber(node, ODOM, 'nav_msgs/Odometry');
        mi = receive(sb, 15);
        pf = mi.pose.pose.position;
        fprintf('    맞춘 뒤   — ENU (%.2f, %.2f) · 선수각 %.2f deg\n', ...
                pf.x, pf.y, rad2deg(spawn_psi(mi)));
        if hypot(pf.x - HOME_ENU(1), pf.y - HOME_ENU(2)) > 1.0
            error('A3_4_vrx_run:setpose', ...
                  '옮겼다는데 자리가 그대로입니다 — set_pose 요청을 볼 것');
        end
    else
        fprintf('    이미 맞아 있습니다 — 그대로 갑니다\n');
    end

    %  속도가 가라앉기를 기다린다 — set_pose 는 **속도를 0 으로 되돌리지 않고**,
    %  앞 실험의 잔류 속도와 물결이 남아 있다. 남은 채로 출발하면 초반 과도가
    %  실행마다 달라져 오프라인과 견줄 수 없다 (실측: 같은 조건에서 선수각
    %  오차 RMS 가 2.4 ~ 7.2 deg 로 흔들렸다)
    for k = 1:40
        mv = receive(sb, 10);
        lv = mv.twist.twist.linear;  av = mv.twist.twist.angular;
        spd = hypot(lv.x, lv.y);
        if spd < 0.03 && abs(av.z) < deg2rad(1), break; end
        pause(1);
    end
    fprintf('    가라앉힘 %d 초 뒤 — 속도 %.3f m/s · 각속도 %.2f deg/s\n', ...
            k, spd, rad2deg(av.z));

    %% [3-2]·[4] 스폰 원점과 RTF — 한 구독으로 둘을 같이 잰다
    fprintf('[3-2] 스폰 원점과 RTF 측정 (12 초, 그대로 기다릴 것)\n');
    m0   = receive(sb, 15);   w = tic;
    t0   = double(m0.header.stamp.sec) + double(m0.header.stamp.nanosec)*1e-9;
    pause(12);
    m1   = receive(sb, 15);   tw = toc(w);
    t1   = double(m1.header.stamp.sec) + double(m1.header.stamp.nanosec)*1e-9;
    RTF  = (t1 - t0) / tw;

    on = m0.pose.pose.position.y;      % ENU y -> 북
    oe = m0.pose.pose.position.x;      % ENU x -> 동
    assignin('base', 'origin_north', on);
    assignin('base', 'origin_east',  oe);
    fprintf('    스폰 원점 (N, E) = (%.2f, %.2f) m — 이 점을 원점으로 쓴다\n', on, oe);
    fprintf('[4] RTF = %.3f — 페이싱 비율을 이 값 그대로 둔다\n', RTF);
    if RTF < 0.2
        warning('A3_4_vrx_run:rtf', ...
                'RTF 가 %.3f 이다 — 가제보가 거의 안 돌고 있다. 창을 확인할 것', RTF);
    end

    load_system(mdl);
    set_param(mdl, 'EnablePacing', 'on', 'PacingRate', num2str(RTF));

    %% [5] 가제보 화면 떠내기 — sim() 이 도는 동안 MATLAB 은 묶여 있다
    %    카메라는 **고정 탑다운**이다. follow 로 선박에 매달면 배가 늘 화면
    %    한가운데 머물러 **얼마나 갔는지가 보이지 않는다.** 배경을 멈춰 둔다
    %    중심은 출발점과 목표점의 중점, 고도는 둘이 다 들어올 만큼
    %    (보이는 폭 약 1.155 * 고도 [m])
    cap = [];
    if rec > 0
        q   = B('stop_q');                      % [북; 동; 선수각]
        cen = [oe + q(2)/2, on + q(1)/2];       % 중점을 ENU (동, 북) 으로
        alt = max(25, 0.9*(hypot(q(1), q(2)) + 16));
        cap = gz_shot_capture(T_run/RTF + 20, 0.4, part, cen, alt);
    end

    %% [6] 실행
    fprintf('[5] 실행 — 최대 %g 초 (실시간 약 %.0f 초)\n', T_run, T_run/RTF);
    out = sim(mdl);
    try, A3_animate('close'); catch, end         % mp4 는 닫아야 재생된다

    %  초반 과도 구간을 들여다볼 때 쓰는 묶음 — 베이스의 out 은 건드리지 않는다
    assignin('base', 'A3_dbg', struct( ...
        't',   out.log_psi.Time,      'psi', out.log_psi.Data, ...
        'pref',out.log_psi_ref.Data,  'xn',  out.log_x_n.Data, ...
        'yn',  out.log_y_n.Data,      'r',   out.log_r.Data, ...
        'dL',  out.log_dL.Data,       'dR',  out.log_dR.Data, ...
        'TL',  out.log_TL.Data,       'TR',  out.log_TR.Data));

    %  중립으로 돌려 둔다 — 플러그인은 **마지막 명령을 계속 쓴다**.
    %  두고 나가면 다음 실험이 돌아간 추진기 위에서 시작한다
    pz = B('vrx_pos_topic');  tz = B('vrx_thr_topic');
    for k = 1:2
        p = ros2publisher(node, pz{k}, 'std_msgs/Float64');
        t = ros2publisher(node, tz{k}, 'std_msgs/Float64');
        send(p, ros2message('std_msgs/Float64'));
        send(t, ros2message('std_msgs/Float64'));
    end
    pause(0.5);
    clear sb node

    %% [7] 그림·지표
    S = A3_plot(out, sprintf('4단 VRX — %s', TNAME{task}));
    S.RTF = RTF;  S.origin = [on oe];  S.task = task;

    fprintf('\n[4단 VRX 점검] %s\n', TNAME{task});
    fprintf('    목표          (%.1f, %.1f) m · %.1f deg\n', ...
            B('x_d'), B('y_d'), rad2deg(B('psi_d')));
    if isnan(S.t_done)
        fprintf('    도착          미완료 — %.0f 초 동안 서지 못했다\n', S.t_end);
    else
        fprintf('    도착          %.1f s\n', S.t_done);
    end
    fprintf('    마지막 오차   위치 %.3f m · 선수각 %.3f deg\n', S.e_final, S.epsi_final);
    fprintf('    마지막 10 초  위치 %.3f m · 선수각 %.3f deg\n', S.e_ss, S.epsi_ss);
    fprintf('    최대 |v|      %.3f m/s  (횡이동 속도)\n', S.v_pk);
    fprintf('    방향각        최대 %.2f deg / 한계 %.0f deg · 포화 %.1f %%\n', ...
            S.d_pk, B('d_max_deg'), S.f_dsat);
    fprintf('    추력          최대 %.1f N / 한계 %.0f N · 포화 %.1f %%\n', ...
            S.T_pk, B('F_max'), S.f_tsat);

    %% [7-2] 분할 영상 — 왼쪽 가제보 드론뷰 · 오른쪽 Simulink 실시간 화면
    if rec > 0 && ~isempty(cap)
        try
            S.video = gz_split_video(anim_mp4, cap, ...
                fullfile(here, 'video', sprintf('A3_4_vrx_%s.mp4', TAG{task})), ...
                {'가제보 — 위에서 본 WAM-V', ...
                 sprintf('Simulink 실시간 화면 — %s', TNAME{task})});
        catch ME
            warning('A3_4_vrx_run:video', '분할 영상 만들기 실패 — %s', ME.message);
        end
    end

    setappdata(0, 'A3_override', []);            % **반드시 비운다**
    assignin('base', 'S', S);
end

% ======================================================================
function psi = spawn_psi(msg)
%SPAWN_PSI  오도메트리 한 건에서 NED 선수각을 꺼낸다 [rad]
%   ENU yaw 를 쿼터니언에서 뽑고 psi = ssa(pi/2 - yaw) 로 돌린다
    q   = msg.pose.pose.orientation;
    yaw = atan2(2*(q.w*q.z + q.x*q.y), 1 - 2*(q.y^2 + q.z^2));
    psi = ssa_local(pi/2 - yaw);
end

% ======================================================================
function a = ssa_local(a)
%SSA_LOCAL  각도를 (-pi, pi] 로 접는다
    a = atan2(sin(a), cos(a));
end
