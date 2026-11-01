function build_w08_dock()
% BUILD_W08_DOCK  8주차 실습 E — 미션 + 접안(위치제어) 모델 2개를 생성한다.
%
%     W08_2_dock.slx       오프라인 — Gazebo 없이 돈다
%     W08_3_dock_vrx.slx   VRX 연동
%
%   임무:  웨이포인트 → 로이터링 → 웨이포인트 → **접안(위치제어)** → 종료
%   앞의 세 상태는 실습 A 와 같다. 마지막에 상태 하나가 더 붙는다.
%
%   구조
%     WpManager  ─┐
%     LoiterVF   ─┼→ ModeSwitch → OuterLoop → InnerLoop → Thrusters → 운동모델
%     TurnCount  ─┤                (위치 P)   (속도 PI·선수각 P–D·추력배분)
%     BerthRef   ─┤
%     MissionFSM ─┘   (Stateflow, 4상태)
%
%   왜 생성 스크립트가 따로인가
%     실습 A~D 의 build_w08_models.m · W08_0_offline.slx · W08_1_vrx.slx 를
%     **한 바이트도 건드리지 않기** 위해서다. 교수님 지시 — "기존 예제는 좋으니까
%     건드리지 말고 마지막 예제를 추가해 줘".
%
%   어디서 가져왔는가
%     유도부·미션·추진기·운동모델 골격   8주차 build_w08_models.m
%     OuterLoop(위치 P) · InnerLoop(속도 PI 둘 + 선수각 P–D) · 추력배분 Alloc
%                                        6주차 W06_simulink/parts/ 의 같은 이름 함수
%                                        — 게인도 구조도 새로 설계하지 않았다
%     접안 3단계 기준점 BerthRef         6주차 TaskRef 의 도킹 가지를 상태기계에 맞게 옮긴 것
%
%   실습 A 와 달라진 곳 (문서에 적는 것과 같다)
%     1. Stateflow 에 Dock 상태가 끼어들어 Finish 가 mode 3 → **4** 가 된다
%     2. InnerLoop 이 6주차 것으로 바뀐다 — 선수추진기와 횡 속도 PI 가 생긴다
%     3. 운동모델이 횡력 Y 와 선수추진기 모멘트 l_bow*FB 를 받는다
%     4. 추진기가 2채널 → 3채널
%
%   실행 전에 반드시 >> W08_dock_setup 을 먼저 실행할 것.
%   모델만 다시 만들 때는
%       >> setappdata(0,'W08_dock_skip_run',true); W08_dock_setup; build_w08_dock

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    cd(here);

    if evalin('base', '~exist(''dock_q'',''var'')')
        error('먼저 W08_dock_setup 을 실행하십시오.');
    end

    build_offline();
    build_vrx();

    %  최상위 배치와 마무리 — 6주차 parts/finishStage.m 과 같은 차례다.
    %  차례 자체가 뜻을 가진다
    %    (1) mss_style 은 lay_chain 뒤 · 선 손질 앞 — 뒤로 밀면 게인 이름이 -K- 로 돌아간다
    %    (2) nudge_labels 는 모델을 **닫은 뒤** 부른다 (스스로 열고 저장한다)
    %
    %  실습 A 의 build_w08_models.m 은 settle_links 를 부르지 않는다. 실습 E 는
    %  문이 둘(gate_p·gate_u) 늘고 추진기가 셋이라 선이 세 군데 걸렸으므로
    %  5·6·9주차처럼 부른다 — 블록을 옮기지 않고 선만 다시 긋는 도구다
    chains = { 'W08_2_dock',     {'Guidance','Mission','OuterLoop','InnerLoop', ...
                                  'Thrusters','MotionModel'};
               'W08_3_dock_vrx', {'Guidance','Mission','OuterLoop','InnerLoop', ...
                                  'Thrusters','CmdPublisher','PoseSubscriber'} };
    boxes = {'Animate','Logging'};

    for k = 1:size(chains,1)
        m = chains{k,1};  chain = chains{k,2};

        %  Wrap 4 로 두 모델이 **같은 자리**(InnerLoop -> Thrusters)에서 줄을 바꾼다.
        %  그 자리의 연결은 빌더가 FL_cmd·FR_cmd·FB_cmd 태그로 미리 이름 붙여 두었다
        lay_chain(m, chain, 'Boxes', boxes, 'Wrap', 4);

        load_system(m);
        straighten_chain(m, chain);   % 이웃 포트 높이를 맞춰 바로 잇는 선을 직선으로
        flatten_lines(m);             % 높이가 같아졌는데 아직 돌아가는 선을 곧게 다시

        %  색 — 역할표는 _tools/gnc_roles.m 하나뿐이다. 빌더는 부르기만 한다
        %  (이 두 모델은 6주차처럼 위치 고리가 있어 역할표에 OuterLoop 이 더해져 있다)
        paint_roles(m);
        check_colour(m);
        mss_style(m);
        save_system(m);  close_system(m, 0);

        %  중간 지적 수는 찍지 않는다 — 태그를 당겨 붙이기 전의 숫자라
        %  다 끝난 뒤에도 빌드 기록이 불합격처럼 보인다. 합격은 아래 check_lines 가 말한다
        evalc('settle_links(m)');

        load_system(m);
        snug_tags(m);
        pack_boxes(m, boxes);
        scope_legend(m);
        W08_dock_set_callbacks(m);    %  InitFcn · StopFcn — 두 번 눌러 열고 Run 만 눌러도 돈다
        save_system(m);  close_system(m, 0);

        evalc('nudge_labels(m)');     % 이름표 위를 지나는 선을 비킨다 (닫은 뒤에 부른다)

        load_system(m);
        check_lines(m, false);
        export_diagram(m);
        close_system(m, 0);
    end

    %  강의노트가 쓰는 서브시스템 도면. 실습 A 의 img/MissionFSM.png 를 덮지 않도록
    %  파일명을 따로 둔다
    load_system('W08_2_dock');
    g = export_diagram('W08_2_dock', '', 'Mission/MissionFSM');
    movefile(g, fullfile(here, 'img', 'MissionFSM_dock.png'), 'f');
    close_system('W08_2_dock', 0);

    fprintf('\n완료. 생성된 모델:\n');
    for k = 1:size(chains,1), fprintf('  %s.slx\n', chains{k,1}); end
end

% =====================================================================
% 되풀이되는 잔손질 — build_w08_models.m 의 같은 이름 지역함수와 같다
% =====================================================================
function fresh(m)
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end

function setFcn(sys, path, code)
    S  = sfroot;
    fpos = get_param([sys '/' path], 'Position');   % 포트가 생기며 블록이 멋대로 자란다
    ch = S.find('-isa','Stateflow.EMChart','Path',[sys '/' path]);
    ch.Script = code;
    set_param([sys '/' path], 'Position', fpos);    % 다시 놓아야 포트 위치가 저장 뒤와 같아진다 (사선 방지)
end

function C(m, name, value, x, y)
    add_block('simulink/Sources/Constant', [m '/' name], ...
              'Position', [x y x+95 y+30], 'Value', value);
end

function nm = F(m, tag, x, y)
    nm = from_name(m, tag);
    add_block('simulink/Signal Routing/From', [m '/' nm], ...
              'Position', [x y x+70 y+25], 'GotoTag', tag);
end

function G(m, tag, x, y)
    add_block('simulink/Signal Routing/Goto', [m '/Go_' tag], ...
              'Position', [x y x+80 y+25], 'GotoTag', tag, 'TagVisibility','global');
end

function note(m, tag, txt, x, y)
    add_block('built-in/Note', [m '/' tag], 'Position',[x y x y], 'Text', txt);
end

% ---------------------------------------------------------------------
% 추력 배분 본문 — 6주차 parts/allocFcn.m 의 사본.
% 8주차가 6주차 폴더에 의존하지 않고 혼자 돌게 하려고 사본을 둔다
% (tidy_layout.m 을 주차 폴더마다 두는 것과 같은 이유)
% ---------------------------------------------------------------------
function src = allocFcn()
    src = strjoin({
      'function [FL, FR, FB] = Alloc(X, Y, N, p)'
      '%#codegen'
      '%  추력 배분 — 요구 힘·모멘트를 세 추진기로 나눈다.'
      '%'
      '%    X = FL + FR                      전후력 [N]'
      '%    Y = FB                           횡력 [N]  — 선수추진기만 낸다'
      '%    N = (FL - FR)*b + l3*FB          요 모멘트 [N m]'
      '%'
      '%  p = [b; l3; Fmax; Fbmax]'
      '%    b     half_beam   좌·우 추진기까지의 반폭 [m]'
      '%    l3    l_bow       무게중심에서 선수추진기까지 [m]'
      '%    Fmax  선미 추진기 추력 한계 [N],  Fbmax 선수추진기 추력 한계 [N]'
      '%'
      '%  선수추진기가 횡력을 내면 요 모멘트 l3*FB 가 딸려 온다. 그것을 좌·우'
      '%  추진기가 되받아 빼야 선수각이 돌아가지 않는다 — 아래 N - l3*FB 가 그것이다.'
      'b = p(1);  l3 = p(2);  Fmax = p(3);  Fbmax = p(4);'
      'FB = Y;'
      'if FB >  Fbmax, FB =  Fbmax; end'
      'if FB < -Fbmax, FB = -Fbmax; end'
      '%  포화된 뒤의 FB 로 모멘트를 센다 — 실제로 딸려 온 만큼만 되받는다'
      'M  = N - l3*FB;'
      'FL = X/2 + M/(2*b);'
      'FR = X/2 - M/(2*b);'
      'if FL >  Fmax, FL =  Fmax; end'
      'if FL < -Fmax, FL = -Fmax; end'
      'if FR >  Fmax, FR =  Fmax; end'
      'if FR < -Fmax, FR = -Fmax; end'
      }, newline);
end

% =====================================================================
% 1단 · GUIDANCE — 유도 셋(웨이포인트·로이터·접안)을 한 상자에
% =====================================================================
function addGuidance(m, x, y)
% 1단 · GUIDANCE — 웨이포인트 유도 · 로이터 유도 · 접안 기준점을 한 상자에.
%
%   포트   x_n, y_n, beta, mode, psi, u
%          -> psi_los, psi_lo, at_loiter, at_end, turns, psi_dock, gate_d
%
%   유도법칙 셋이 **동시에** 돈다. 어느 쪽을 쓸지는 미션 상자가 고른다.
%   유도는 셋 다 계산해 내놓기만 하고, 판단은 하지 않는다 — 실습 A 와 같은 원칙이다.
%
%   안에 들어가는 것
%     WpManager  웨이포인트 관리 + LOS   (5주차)
%     LoiterVF   원 궤도 벡터필드        (7주차)
%     TurnCount  몇 바퀴 돌았는지
%     BerthRef   접안 기준점 3단계       (6주차 TaskRef 의 도킹 가지)
%
%   x_ref·y_ref 는 **출력 포트가 아니라 태그**로 나간다. 사슬 두 칸 뒤의
%   OuterLoop 로 가는데, 포트로 내면 Mission 상자를 건너뛰는 선이 생긴다
%   (y_e·idx·r_lo 를 태그로 내는 것과 같은 까닭)
    ss = add_subsys(m, 'Guidance', [x y x+190 y+200], ...
                    {'x_n','y_n','beta','mode','psi','u'}, ...
                    {'psi_los','psi_lo','at_loiter','at_end','turns','psi_dock','gate_d'}, ...
                    gnc_colour('guidance'));

    % ---- 웨이포인트 관리 + LOS (실습 A 와 글자까지 같다) ----
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/WpManager'], 'Position', [520 50 760 550]);
    setFcn(ss, 'WpManager', [ ...
'function [psi_los, y_e, idx, at_loiter, at_end] = WpManager( ...'            newline ...
'         x_n, y_n, wp_x, wp_y, Delta, R, loiter_wp, mode, idx_prev)'         newline ...
'%#codegen'                                                                   newline ...
'% Waypoint bookkeeping plus LOS guidance (week 7).'                          newline ...
'%   idx = index of the leg START. The leg runs wp(idx) -> wp(idx+1).'        newline ...
'%   The index only advances while the mission is in waypoint mode,'          newline ...
'%   so a loiter never makes the boat skip a leg.'                            newline ...
''                                                                            newline ...
'n = numel(wp_x);'                                                            newline ...
'k = min(max(idx_prev, 1), n-1);'                                             newline ...
''                                                                            newline ...
'xk  = wp_x(k);    yk  = wp_y(k);'                                            newline ...
'xk1 = wp_x(k+1);  yk1 = wp_y(k+1);'                                          newline ...
''                                                                            newline ...
'pi_p = atan2(yk1 - yk, xk1 - xk);'                                           newline ...
'y_e  = -(x_n - xk)*sin(pi_p) + (y_n - yk)*cos(pi_p);'                        newline ...
'psi_los = pi_p - atan(y_e / Delta);'                                         newline ...
''                                                                            newline ...
'd_next  = sqrt((xk1 - x_n)^2 + (yk1 - y_n)^2);'                              newline ...
'reached = d_next <= R;'                                                      newline ...
''                                                                            newline ...
'% arriving at the loiter waypoint, and arriving at the last one'             newline ...
'if reached && ((k+1) == loiter_wp)'                                          newline ...
'    at_loiter = 1;'                                                          newline ...
'else'                                                                        newline ...
'    at_loiter = 0;'                                                          newline ...
'end'                                                                         newline ...
'if reached && (k == n-1)'                                                    newline ...
'    at_end = 1;'                                                             newline ...
'else'                                                                        newline ...
'    at_end = 0;'                                                             newline ...
'end'                                                                         newline ...
''                                                                            newline ...
'% advance only in waypoint mode'                                             newline ...
'if (mode < 1.5) && reached && (k < n-1)'                                     newline ...
'    idx = k + 1;'                                                            newline ...
'else'                                                                        newline ...
'    idx = k;'                                                                newline ...
'end']);

    % 웨이포인트 인덱스는 유도부 안의 기억이다. 태그로 자기에게 되돌린다
    drop_tag(ss, 'WpManager', 3, 'wp_idx', 150);
    q = port_xy(ss, 'WpManager', 'Inport', 9);
    add_block('simulink/Discrete/Unit Delay', [ss '/IdxDly'], ...
              'Position', [x+60 q(2)-20 x+135 q(2)+20], ...
              'InitialCondition','1', 'SampleTime','Ts_ctrl');
    set_param([ss '/IdxDly'], 'Description', ...
        '대수 루프 차단 + 사건 계수기 — 웨이포인트 번호는 정수이고, 유도부가 낸 값이 유도부로 되돌아온다. 미분방정식의 상태가 아니다.');
    add_block('simulink/Signal Routing/From', [ss '/Fr_wp_idx'], ...
              'Position', [x-60 q(2)-11 x+10 q(2)+11], 'GotoTag','wp_idx');
    add_line(ss, 'Fr_wp_idx/1', 'IdxDly/1');
    add_line(ss, 'IdxDly/1', 'WpManager/9');

    % ---- 로이터 벡터필드 (실습 A 와 글자까지 같다) ----
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/LoiterVF'], 'Position', [520 750 760 1250]);
    setFcn(ss, 'LoiterVF', [ ...
'function [psi_lo, r, theta] = LoiterVF(x_n, y_n, x_c, y_c, rd, vd, pc, beta, kcrab)' newline ...
'%#codegen'                                                                   newline ...
'% Circular-orbit vector field guidance.'                                     newline ...
'%   Jung, Lim, Lee, Bang, "Unmanned Aircraft Vector Field Path Following'    newline ...
'%   with Arrival Angle Control", eq. (9) and (13).'                          newline ...
'%   pc > 0 clockwise, pc < 0 counter-clockwise.'                             newline ...
''                                                                            newline ...
'dx = x_n - x_c;'                                                             newline ...
'dy = y_n - y_c;'                                                             newline ...
'r     = sqrt(dx*dx + dy*dy);'                                                newline ...
'theta = atan2(dy, dx);'                                                      newline ...
'if r < 1e-6, r = 1e-6; end'                                                  newline ...
''                                                                            newline ...
'N = sqrt((r - rd)^2 + (pc*r)^2);'                                            newline ...
'if N < 1e-9, N = 1e-9; end'                                                  newline ...
'r_dot   = -vd * (r - rd) / N;'                                               newline ...
'rth_dot =  vd * pc * r   / N;'                                               newline ...
''                                                                            newline ...
'vf_x = r_dot*cos(theta) - rth_dot*sin(theta);'                               newline ...
'vf_y = r_dot*sin(theta) + rth_dot*cos(theta);'                               newline ...
''                                                                            newline ...
'chi_d  = atan2(vf_y, vf_x);'                                                 newline ...
'p      = chi_d - kcrab*beta;'                                                newline ...
'psi_lo = atan2(sin(p), cos(p));']);

    % ---- 회전수 (모드가 로이터일 때만 센다) ----
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/TurnCount'], 'Position', [520 1520 760 1880]);
    setFcn(ss, 'TurnCount', [ ...
'function [turns, th_out, acc_out, armed] = TurnCount( ...'                   newline ...
'         theta, r, rd, mode, th_prev, acc_prev, armed_prev)'                  newline ...
'%#codegen'                                                                   newline ...
'% Count laps, but only while the mission is loitering (mode 2).'             newline ...
'% Leaving loiter mode resets the counter, so a second loiter later'          newline ...
'% starts from zero again.'                                                   newline ...
''                                                                            newline ...
'th_out = theta;'                                                             newline ...
''                                                                            newline ...
'if mode < 1.5 || mode > 2.5'                                                 newline ...
'    turns = 0; acc_out = 0; armed = 0;'                                      newline ...
'    return'                                                                  newline ...
'end'                                                                         newline ...
''                                                                            newline ...
'tol = 0.3*rd;'                                                               newline ...
'if armed_prev < 0.5'                                                         newline ...
'    acc_out = 0;'                                                            newline ...
'    if abs(r - rd) <= tol'                                                   newline ...
'        armed = 1;'                                                          newline ...
'    else'                                                                    newline ...
'        armed = 0;'                                                          newline ...
'    end'                                                                     newline ...
'else'                                                                        newline ...
'    armed = 1;'                                                              newline ...
'    d = theta - th_prev;'                                                    newline ...
'    d = atan2(sin(d), cos(d));'                                              newline ...
'    acc_out = acc_prev + d;'                                                 newline ...
'end'                                                                         newline ...
'turns = abs(acc_out) / (2*pi);']);

    % TurnCount 의 기억 셋은 자기에게 돌아온다. 태그로 건넌다
    dn  = {'ThDly','AccDly','ArmDly'};
    tg  = {'th_prev','acc_prev','armed_prev'};
    for k = 1:3
        drop_tag(ss, 'TurnCount', k+1, tg{k}, 160 + 60*k);
        q = port_xy(ss, 'TurnCount', 'Inport', k+4);
        add_block('simulink/Discrete/Unit Delay', [ss '/' dn{k}], ...
                  'Position', [x+300 q(2)-20 x+375 q(2)+20], ...
                  'InitialCondition','0', 'SampleTime','Ts_ctrl');
        set_param([ss '/' dn{k}], 'Description', ...
            '바퀴 수 계수기 — 표본 사이의 각 변화를 모아 감으므로 바로 앞 표본이 있어야 한다. 또한 TurnCount 가 낸 값이 TurnCount 로 되돌아와 대수 루프가 된다.');
        add_block('simulink/Signal Routing/From', [ss '/Fr_' tg{k}], ...
                  'Position', [x+180 q(2)-11 x+250 q(2)+11], 'GotoTag', tg{k});
        add_line(ss, ['Fr_' tg{k} '/1'], [dn{k} '/1']);
        add_line(ss, [dn{k} '/1'], sprintf('TurnCount/%d', k+4));
    end

    % ---- 접안 기준점 3단계 (6주차 TaskRef 의 도킹 가지) ----
    %   1단계 접근점으로 간다 -> 2단계 선수각을 부두와 맞춘다 -> 3단계 순수 옆걸음
    %   단계는 **한 번 올라가면 내려오지 않는다**(걸쇠). 경계에서 떨리면 지령이
    %   튀기 때문이다. 그 기억이 PhaseDly 다
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/BerthRef'], 'Position', [520 2050 760 2650]);
    setFcn(ss, 'BerthRef', [ ...
'function [x_ref, y_ref, psi_dock, gate_d, phase] = BerthRef( ...'            newline ...
'         x_n, y_n, psi, u, mode, q, ph_prev)'                                newline ...
'%#codegen'                                                                   newline ...
'% 접안 기준점 — 위치제어(OuterLoop)가 따라갈 점 하나와 선수각 하나를 낸다.'  newline ...
'%'                                                                           newline ...
'%   q = [dx; dy; dpsi; La; sd; Rd; Rs]'                                      newline ...
'%     dx,dy  접안 완료점(베이 안) [m, NED]'                                   newline ...
'%     dpsi   접안 자세 — 부두와 나란한 선수각 [rad]'                          newline ...
'%     La     접근점까지의 거리 [m],  sd 접안하는 쪽 (+1 우현 / -1 좌현)'      newline ...
'%     Rd     접근점 도착 반경 [m],   Rs 접안 완료 반경 [m]'                   newline ...
'%'                                                                           newline ...
'%   단계 phase'                                                              newline ...
'%     0  접근점으로 — 선수각은 접근점을 바라본다'                             newline ...
'%     1  선수각 맞추기 — 접근점에 묶어 두고 부두와 나란해지며 멈출 때까지'   newline ...
'%     2  순수 옆걸음 — 기준점만 베이 안으로 옮긴다. 선수각은 그대로'          newline ...
'%     3  접안 완료 — 기준점을 선석에 두고 위치제어로 자리를 지킨다'          newline ...
'dx = q(1);  dy = q(2);  dpsi = q(3);  La = q(4);'                            newline ...
'sd = q(5);  Rd = q(6);  Rs   = q(7);'                                        newline ...
''                                                                            newline ...
'%  접근점 — 접안점에서 부두 바깥으로 La 만큼 떨어진 점'                       newline ...
'ax = dx - sd*La*sin(dpsi);'                                                  newline ...
'ay = dy + sd*La*cos(dpsi);'                                                  newline ...
''                                                                            newline ...
'ph = ph_prev;'                                                               newline ...
'if mode < 2.5'                                                               newline ...
'    %  아직 도킹 차례가 아니다. 단계를 0 으로 되돌리고 기준점은 제자리에 둔다' newline ...
'    %  (위치 오차 0 — OuterLoop 이 돌고 있어도 지령을 내지 않는다)'           newline ...
'    ph = 0;  x_ref = x_n;  y_ref = y_n;  psi_dock = dpsi;'                   newline ...
'elseif ph < 0.5'                                                             newline ...
'    x_ref = ax;  y_ref = ay;  psi_dock = atan2(ay - y_n, ax - x_n);'         newline ...
'    if sqrt((ax - x_n)^2 + (ay - y_n)^2) < Rd, ph = 1; end'                  newline ...
'elseif ph < 1.5'                                                             newline ...
'    x_ref = ax;  y_ref = ay;  psi_dock = dpsi;'                              newline ...
'    e = atan2(sin(dpsi - psi), cos(dpsi - psi));'                            newline ...
'    %  옆걸음은 **배가 멈춘 뒤** 시작한다. 전후 속력이 남아 있으면'          newline ...
'    %  앞으로 미끄러지며 옆으로 가 궤적이 비스듬해진다 — 순수 옆걸음이 아니다' newline ...
'    if abs(e) < 5*pi/180 && abs(u) < 0.20, ph = 2; end'                      newline ...
'else'                                                                        newline ...
'    x_ref = dx;  y_ref = dy;  psi_dock = dpsi;'                              newline ...
'    if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs, ph = 3; end'                  newline ...
'end'                                                                         newline ...
''                                                                            newline ...
'phase  = ph;'                                                                newline ...
''                                                                            newline ...
'%  gate_d — 위치제어 문. 접안 차례가 되면 열고 **접안 뒤에도 닫지 않는다**.' newline ...
'%  2026-11-01 측정에서 드러난 것 — ph = 3 에서 문을 닫으면 횡 PI 적분기가'   newline ...
'%  마지막 값(약 96 N)에 얼어붙은 채 남아 선수추진기가 계속 밀고, 배는 선석을' newline ...
'%  지나 베이 뒤 벽을 뚫는다 (10 s 에 6.0 m). **오차를 끊는 문은 적분기를 0 으로' newline ...
'%  되돌리지 않는다.** 멈추려면 오차를 끊지 말고 받아야 한다 — 선석에 가까워질수록' newline ...
'%  위치 오차가 줄어 횡 속도 지령이 스스로 0 이 되고, 그것이 제동이다'        newline ...
'gate_d = double(mode > 2.5);']);

    % 단계는 유도부 안의 기억이다. 태그로 자기에게 되돌린다
    drop_tag(ss, 'BerthRef', 5, 'ph_prev', 240);
    q = port_xy(ss, 'BerthRef', 'Inport', 7);
    add_block('simulink/Discrete/Unit Delay', [ss '/PhaseDly'], ...
              'Position', [x+60 q(2)-20 x+135 q(2)+20], ...
              'InitialCondition','0', 'SampleTime','Ts_ctrl');
    set_param([ss '/PhaseDly'], 'Description', ...
        '대수 루프 차단 + 단계 걸쇠 — 접안 단계는 정수이고, 한 번 올라간 단계는 내려오지 않는다. 미분방정식의 상태가 아니다.');
    add_block('simulink/Signal Routing/From', [ss '/Fr_ph_prev'], ...
              'Position', [x-60 q(2)-11 x+10 q(2)+11], 'GotoTag','ph_prev');
    add_line(ss, 'Fr_ph_prev/1', 'PhaseDly/1');
    add_line(ss, 'PhaseDly/1', 'BerthRef/7');

    % 입력은 상자 안에서 **태그로 나눠 쓴다.** x_n·y_n·mode 를 세 함수가 함께 쓰는데,
    % 포트에서 선을 여러 갈래로 끌면 그 선이 설정 상수 열을 가로지른다
    ipt = {'x_n','y_n','beta','mode','psi','u'};
    for k = 1:numel(ipt)
        add_block('simulink/Signal Routing/Goto', [ss '/Go_i_' ipt{k}], ...
                  'Position', [160 196+(k-1)*60 240 218+(k-1)*60], ...
                  'GotoTag', ['i_' ipt{k}], 'TagVisibility','local');
        add_line(ss, [ipt{k} '/1'], ['Go_i_' ipt{k} '/1'], 'autorouting','on');
    end

    % --- 설정값 — 신호가 아니다. 상자 안에 둔다 --------------------------
    cfg = {'WPN','wp_north'; 'WPE','wp_east'; 'Dlt','Delta'; 'Rsw','R_LOS'; ...
           'LWP','loiter_wp'; 'LCN','loiter_xc'; 'LCE','loiter_yc'; ...
           'LRD','loiter_radius'; 'LRD2','loiter_radius'; ...
           'URf','u_ref'; 'Pc','p_c'; 'Kcr','crab_comp'; 'DQ','dock_q'};
    for k = 1:size(cfg,1)
        add_block('simulink/Sources/Constant', [ss '/' cfg{k,1}], ...
                  'Position', [330 100+(k-1)*60 405 130+(k-1)*60], 'Value', cfg{k,2});
    end
    fr = {'x_n_1','i_x_n'; 'y_n_1','i_y_n'; 'mode_1','i_mode'; ...
          'x_n_2','i_x_n'; 'y_n_2','i_y_n'; 'beta_1','i_beta'; 'mode_2','i_mode'; ...
          'x_n_3','i_x_n'; 'y_n_3','i_y_n'; 'psi_1','i_psi'; 'mode_3','i_mode'; 'u_1','i_u'};
    for k = 1:size(fr,1)
        add_block('simulink/Signal Routing/From', [ss '/Fr_' fr{k,1}], ...
                  'Position', [330 900+(k-1)*60 400 922+(k-1)*60], 'GotoTag', fr{k,2});
    end

    % --- 배선 -----------------------------------------------------------
    wp = {'Fr_x_n_1','Fr_y_n_1','WPN','WPE','Dlt','Rsw','LWP','Fr_mode_1'};
    for k = 1:numel(wp)
        add_line(ss, [wp{k} '/1'], sprintf('WpManager/%d',k), 'autorouting','on');
    end
    lv = {'Fr_x_n_2','Fr_y_n_2','LCN','LCE','LRD','URf','Pc','Fr_beta_1','Kcr'};
    for k = 1:numel(lv)
        add_line(ss, [lv{k} '/1'], sprintf('LoiterVF/%d',k), 'autorouting','on');
    end
    br = {'Fr_x_n_3','Fr_y_n_3','Fr_psi_1','Fr_u_1','Fr_mode_3','DQ'};
    for k = 1:numel(br)
        add_line(ss, [br{k} '/1'], sprintf('BerthRef/%d',k), 'autorouting','on');
    end
    add_line(ss,'LoiterVF/3','TurnCount/1','autorouting','on');    % theta
    add_line(ss,'LoiterVF/2','TurnCount/2','autorouting','on');    % r
    add_line(ss,'LRD2/1',    'TurnCount/3','autorouting','on');
    add_line(ss,'Fr_mode_2/1','TurnCount/4','autorouting','on');

    % --- 출력 포트 : 순서를 미션 상자의 입력 순서와 **같게** 맞춘다 --------
    ot = {'psi_los','WpManager',1; 'psi_lo','LoiterVF',1; ...
          'at_loiter','WpManager',4; 'at_end','WpManager',5; 'turns','TurnCount',1; ...
          'psi_dock','BerthRef',3; 'gate_d','BerthRef',4};
    for k = 1:size(ot,1)
        add_line(ss, sprintf('%s/%d', ot{k,2}, ot{k,3}), [ot{k,1} '/1'], 'autorouting','on');
    end

    % --- 태그로 내보내는 것 ----------------------------------------------
    %   y_e·idx·r_lo·turns  로깅·애니메이션용
    %   x_ref·y_ref         사슬 두 칸 뒤의 OuterLoop 로
    %   phase               미션 상태기계(Dock -> Finish 조건) · 로깅 · 애니메이션
    lt = {'WpManager',2,'y_e'; 'WpManager',3,'idx'; ...
          'LoiterVF',2,'r_lo'; 'TurnCount',1,'turns'; ...
          'BerthRef',1,'x_ref'; 'BerthRef',2,'y_ref'; 'BerthRef',5,'phase'};
    for k = 1:size(lt,1)
        add_block('simulink/Signal Routing/Goto', [ss '/Go_' lt{k,3}], ...
                  'Position', [1000 200+(k-1)*60 1080 222+(k-1)*60], ...
                  'GotoTag', lt{k,3}, 'TagVisibility','global');
        add_line(ss, sprintf('%s/%d', lt{k,1}, lt{k,2}), ['Go_' lt{k,3} '/1'], ...
                 'autorouting','on');
    end

    Simulink.BlockDiagram.arrangeSystem(ss);
end

% =====================================================================
% 2단 · MISSION — 상태기계 4상태. 어느 유도를 쓸지 고른다
% =====================================================================
function addMissionFSM(m, x, y)
% 2단 · MISSION — Stateflow 상태기계와 모드 선택기.
%
%   포트   psi_los, psi_lo, at_loiter, at_end, turns, psi_dock, gate_d
%          -> gate_p, gate_u
%
%   실습 A 와 달라진 곳은 **상태 하나**다
%
%     실습 A   WpFollow(1) -> Loiter(2) -> WpFollow(1) -> Finish(3)
%     실습 E   WpFollow(1) -> Loiter(2) -> WpFollow(1) -> **Dock(3)** -> Finish(4)
%
%   앞의 세 상태와 전이 조건은 글자 하나까지 같다. Dock 이 끼어들었으므로
%   Finish 의 번호만 3 -> 4 로 밀린다. 실습 A 의 차트는 손대지 않는다.
%
%   psi_ref 는 **포트가 아니라 태그**로 나간다. 받는 쪽 InnerLoop 이 사슬에서
%   두 칸 뒤(OuterLoop 다음)이기 때문이다 — 포트로 내면 OuterLoop 상자를
%   건너뛰는 선이 생긴다
    ss = add_subsys(m, 'Mission', [x y x+190 y+170], ...
                    {'psi_los','psi_lo','at_loiter','at_end','turns','psi_dock','gate_d'}, ...
                    {'gate_p','gate_u'}, gnc_colour('mission'));

    % ---- Stateflow 차트 -------------------------------------------------
    add_block('sflib/Chart', [ss '/MissionFSM'], 'Position', [x y x+220 y+180]);
    S  = sfroot;
    ch = S.find('-isa','Stateflow.Chart','Path',[ss '/MissionFSM']);
    ch.ActionLanguage = 'MATLAB';     % C 가 아니라 MATLAB 문법으로 쓴다
    ch.ChartUpdate    = 'DISCRETE';   % 제어 주기마다 한 번씩만 깨어난다
    ch.SampleTime     = 'Ts_ctrl';

    ins = {'at_loiter','turns','req_turns','at_end','phase'};
    for k = 1:numel(ins)
        d = Stateflow.Data(ch);
        d.Name  = ins{k};
        d.Scope = 'Input';
        d.Port  = k;
    end
    d = Stateflow.Data(ch);  d.Name = 'mode';  d.Scope = 'Output';  d.Port = 1;

    s1 = Stateflow.State(ch);
    s1.Name = 'WpFollow';
    s1.LabelString = ['WpFollow' newline 'en: mode = 1;'];
    s1.Position = [70 90 210 70];

    s2 = Stateflow.State(ch);
    s2.Name = 'Loiter';
    s2.LabelString = ['Loiter' newline 'en: mode = 2;'];
    s2.Position = [70 310 210 70];

    %  실습 A 의 Finish 자리에 Dock 이 들어온다. 전이 조건이 [at_end > 0.5] 로
    %  같으므로 앞의 세 상태에서 보면 달라진 것이 없다
    s3 = Stateflow.State(ch);
    s3.Name = 'Dock';
    s3.LabelString = ['Dock' newline 'en: mode = 3;'];
    s3.Position = [430 90 210 70];

    s4 = Stateflow.State(ch);
    s4.Name = 'Finish';
    s4.LabelString = ['Finish' newline 'en: mode = 4;'];
    s4.Position = [790 90 210 70];

    td = Stateflow.Transition(ch);              % 처음 들어가는 상태
    td.Destination        = s1;
    td.DestinationOClock  = 0;
    td.SourceEndPoint     = [175 35];
    td.MidPoint           = [175 62];

    %  만드는 순서가 곧 **우선순위**다. 실습 A 와 같은 순서로 만든다
    t1 = Stateflow.Transition(ch);              % 로이터 웨이포인트에 닿았다
    t1.Source = s1;  t1.SourceOClock = 6;
    t1.Destination = s2;  t1.DestinationOClock = 0;
    t1.LabelString = '[at_loiter > 0.5]';
    t1.MidPoint = [120 240];

    t2 = Stateflow.Transition(ch);              % 정해진 바퀴를 다 돌았다
    t2.Source = s2;  t2.SourceOClock = 3;
    t2.Destination = s1;  t2.DestinationOClock = 3;
    t2.LabelString = '[turns >= req_turns]';
    t2.MidPoint = [350 245];

    t3 = Stateflow.Transition(ch);              % 마지막 웨이포인트에 닿았다
    t3.Source = s1;  t3.SourceOClock = 3;
    t3.Destination = s3;  t3.DestinationOClock = 9;
    t3.LabelString = '[at_end > 0.5]';
    t3.MidPoint = [355 125];

    t4 = Stateflow.Transition(ch);              % 접안 3단계까지 끝났다
    t4.Source = s3;  t4.SourceOClock = 3;
    t4.Destination = s4;  t4.DestinationOClock = 9;
    t4.LabelString = '[phase > 2.5]';
    t4.MidPoint = [715 125];

    % ---- 모드 선택기 ----------------------------------------------------
    %   유도부가 낸 선수각 **셋** 가운데 하나를 고르고, 속도 지령의 출처를 고른다.
    %   gate_u  전진 속도를 u_ref 로 둘 것인가 (항로 추종·로이터)
    %   gate_p  전진·횡 속도를 위치제어가 낼 것인가 (접안)
    %   둘은 **동시에 1 이 되지 않는다.** 그래서 OuterLoop 에서 둘을 더하면
    %   그것이 곧 모드 선택이 된다 — 새 함수가 필요하지 않다
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/ModeSwitch'], 'Position', [x y x+180 y+150]);
    setFcn(ss, 'ModeSwitch', [ ...
'function [psi_ref, gate_p, gate_u] = ModeSwitch(mode, psi_los, psi_lo, psi_dock, gate_d)' newline ...
'%#codegen'                                                                   newline ...
'%  상태 번호를 받아 **쓸 지령**을 고른다. 판단은 상태기계가 이미 끝냈다.'    newline ...
'%'                                                                           newline ...
'%    mode 1 WpFollow   LOS 선수각,        전진 속도 u_ref'                   newline ...
'%    mode 2 Loiter     벡터필드 선수각,   전진 속도 u_ref'                   newline ...
'%    mode 3 Dock       부두 선수각,       전진·횡 속도는 위치제어가 낸다'     newline ...
'%    mode 4 Finish     부두 선수각,       위치제어로 선석을 지킨다'          newline ...
'%'                                                                           newline ...
'%  선수각 고리는 어느 모드에서도 **끊지 않는다.** Finish 에서도 선수각은'     newline ...
'%  부두와 나란히 붙잡아야 접안 자세가 풀리지 않는다'                          newline ...
'if mode > 3.5'                                                               newline ...
'    psi_ref = psi_dock;   gate_p = gate_d;   gate_u = 0;'                    newline ...
'elseif mode > 2.5'                                                           newline ...
'    psi_ref = psi_dock;   gate_p = gate_d;   gate_u = 0;'                    newline ...
'elseif mode > 1.5'                                                           newline ...
'    psi_ref = psi_lo;     gate_p = 0;        gate_u = 1;'                    newline ...
'else'                                                                        newline ...
'    psi_ref = psi_los;    gate_p = 0;        gate_u = 1;'                    newline ...
'end']);

    %  요구 바퀴 수는 설정값이다. 신호가 아니므로 상자 안에 둔다
    add_block('simulink/Sources/Constant', [ss '/Req'], ...
              'Position', [x-160 y+260 x-70 y+290], 'Value', 'loiter_turns');

    %  접안 단계는 유도부가 낸다. 사슬에서 한 칸 앞이지만 **포트를 늘리지 않는다**
    %  — 상태기계만 쓰는 신호를 상자 테두리까지 끌어올 까닭이 없다
    add_block('simulink/Signal Routing/From', [ss '/Fr_phase'], ...
              'Position', [x-160 y+330 x-90 y+352], 'GotoTag','phase');

    % --- 배선 -----------------------------------------------------------
    add_line(ss, 'at_loiter/1','MissionFSM/1','autorouting','on');
    add_line(ss, 'turns/1',    'MissionFSM/2','autorouting','on');
    add_line(ss, 'Req/1',      'MissionFSM/3','autorouting','on');
    add_line(ss, 'at_end/1',   'MissionFSM/4','autorouting','on');
    add_line(ss, 'Fr_phase/1', 'MissionFSM/5','autorouting','on');

    add_line(ss, 'MissionFSM/1','ModeSwitch/1','autorouting','on');
    add_line(ss, 'psi_los/1',   'ModeSwitch/2','autorouting','on');
    add_line(ss, 'psi_lo/1',    'ModeSwitch/3','autorouting','on');
    add_line(ss, 'psi_dock/1',  'ModeSwitch/4','autorouting','on');
    add_line(ss, 'gate_d/1',    'ModeSwitch/5','autorouting','on');

    add_line(ss, 'ModeSwitch/2','gate_p/1','autorouting','on');
    add_line(ss, 'ModeSwitch/3','gate_u/1','autorouting','on');

    %  상태기계가 낸 mode 는 유도부(WpManager·TurnCount·BerthRef)로 돌아간다.
    %  그대로 되돌리면 대수 루프가 되므로 한 스텝 지연을 끼운다
    add_block('simulink/Discrete/Unit Delay', [ss '/ModeDly'], ...
              'Position', [x+380 y+300 x+455 y+340], ...
              'InitialCondition','1', 'SampleTime','Ts_ctrl');
    set_param([ss '/ModeDly'], 'Description', ...
        '대수 루프 차단 — 상태기계가 낸 mode 가 유도부로 돌아가고, 유도부가 낸 at_loiter·at_end·turns·phase 가 다시 상태기계로 들어온다. 고리 어딘가에 한 스텝 지연이 있어야 한다.');
    add_line(ss, 'MissionFSM/1','ModeDly/1','autorouting','on');
    add_block('simulink/Signal Routing/Goto', [ss '/Go_mode'], ...
              'Position', [x+520 y+310 x+600 y+332], ...
              'GotoTag','mode', 'TagVisibility','global');
    add_line(ss, 'ModeDly/1','Go_mode/1','autorouting','on');

    %  태그로 내보내는 것 — psi_ref 는 사슬 두 칸 뒤의 InnerLoop 로,
    %  gate_p 는 InnerLoop 의 횡 속도 고리로, gate_u 는 로깅·애니메이션으로
    lt = {'ModeSwitch',1,'psi_ref'; 'ModeSwitch',2,'gate_p'; 'ModeSwitch',3,'gate_u'};
    for k = 1:size(lt,1)
        add_block('simulink/Signal Routing/Goto', [ss '/Go_' lt{k,3}], ...
                  'Position', [x+520 y+400+(k-1)*45 x+600 y+422+(k-1)*45], ...
                  'GotoTag', lt{k,3}, 'TagVisibility','global');
        add_line(ss, sprintf('%s/%d', lt{k,1}, lt{k,2}), ['Go_' lt{k,3} '/1'], ...
                 'autorouting','on');
    end

    Simulink.BlockDiagram.arrangeSystem(ss);

    sl_note(ss, 'n_ms', [ ...
        '상태 넷 — WpFollow(1) -> Loiter(2) -> WpFollow(1) -> Dock(3) -> Finish(4)' newline ...
        '실습 A 와 앞의 세 상태·전이 조건이 같다. Dock 이 끼어들어 Finish 가 4 가 됨' newline ...
        'Dock -> Finish 조건은 [phase > 2.5] — 접안 3단계가 끝났다는 뜻임' newline ...
        'gate_u 와 gate_p 는 동시에 1 이 되지 않음. 그 배타성이 곧 모드 선택임'], ...
        x, y+520);
end

% =====================================================================
% 3단 · OUTER LOOP — 위치 오차를 속도 지령으로 (6주차에서 가져온 것)
% =====================================================================
function addOuterLoop(m, x, y)
% 3단 · OUTER LOOP — 위치 오차 -> 선체고정 오차 -> 비례 제어 -> 속도 포화.
%
%   포트   x_ref, y_ref, x_n, y_n, psi, gate_p, gate_u  ->  u_cmd, v_cmd
%
%   6주차 W06_simulink/parts/addOuterLoop.m 과 **구조도 게인도 같다.**
%   새로 설계한 것이 없다. 달라진 곳은 둘뿐이다
%
%     1. gate 가 gate_p 로 이름이 바뀐다 (문 둘을 구별하려고)
%     2. 전진 속도 지령에 u_ref 가지가 붙는다 — gate_u 가 그 문이다
%
%   왜 더하기 하나로 모드가 갈리는가
%     gate_u 와 gate_p 는 **동시에 1 이 되지 않는다** (Mission/ModeSwitch 가 보장).
%     그래서 두 가지를 더하면 늘 한쪽만 살아 남는다
%
%       항로 추종·로이터   u_cmd = 0 + u_ref*1   = u_ref     (실습 A 와 같다)
%       접안·접안 완료     u_cmd = Kp_x*e_x + 0  = 위치제어
%                          접안이 끝나도 문은 닫지 않는다. 기준점이 선석에
%                          그대로 있어 위치 오차가 0 에 가까워지며 지령이 사라진다
%
%     모드를 고르는 if 문을 또 만들지 않는다. 판단은 Mission 한 곳에만 있어야 한다
    ss = add_subsys(m, 'OuterLoop', [x y x+190 y+190], ...
                    {'x_ref','y_ref','x_n','y_n','psi','gate_p','gate_u'}, ...
                    {'u_cmd','v_cmd'}, gnc_colour('control'));

    %  --- 위치 오차 (NED) ---
    add_sum(ss, 'ErrN', '+-', [250  90]);
    add_sum(ss, 'ErrE', '+-', [250 250]);
    add_line(ss, 'x_ref/1', 'ErrN/1');  add_line(ss, 'x_n/1', 'ErrN/2');
    add_line(ss, 'y_ref/1', 'ErrE/1');  add_line(ss, 'y_n/1', 'ErrE/2');

    %  --- 선체고정 좌표로 돌린다 ---
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Rotate'], ...
              'Position', [350 60 500 300]);
    sl_fcn(ss, 'Rotate', strjoin({
      'function [e_x, e_y] = Rotate(e_N, e_E, psi)'
      '%#codegen'
      '%  NED 위치 오차를 선체고정 오차로 돌린다. e_x 앞쪽, e_y 우현쪽 [m]'
      'e_x =  cos(psi)*e_N + sin(psi)*e_E;'
      'e_y = -sin(psi)*e_N + cos(psi)*e_E;'
      }, newline));
    add_line(ss, 'ErrN/1', 'Rotate/1');
    add_line(ss, 'ErrE/1', 'Rotate/2');
    add_line(ss, 'psi/1',  'Rotate/3');

    %  --- 비례 제어 + 속도 포화 ---
    sl_gain(ss, 'Kp_x', 'Kp_x', 560,  80);
    sl_gain(ss, 'Kp_y', 'Kp_y', 560, 220);
    sl_sat(ss, 'SatU', 'u_max', 660,  80);
    sl_sat(ss, 'SatV', 'v_max', 660, 220);
    add_block('simulink/Math Operations/Product', [ss '/GateU'], ...
              'Position', [780 70 810 110]);
    add_block('simulink/Math Operations/Product', [ss '/GateV'], ...
              'Position', [780 210 810 250]);
    add_line(ss, 'Rotate/1','Kp_x/1');  add_line(ss, 'Kp_x/1','SatU/1');
    add_line(ss, 'Rotate/2','Kp_y/1');  add_line(ss, 'Kp_y/1','SatV/1');
    add_line(ss, 'SatU/1','GateU/1');   add_line(ss, 'gate_p/1','GateU/2');
    add_line(ss, 'SatV/1','GateV/1');   add_line(ss, 'gate_p/1','GateV/2');

    %  --- 항로 추종·로이터의 전진 속도 지령 ---
    sl_const(ss, 'URf', 'u_ref', 640, 420);
    add_block('simulink/Math Operations/Product', [ss '/GateFwd'], ...
              'Position', [780 410 810 450]);
    add_line(ss, 'URf/1',    'GateFwd/1');
    add_line(ss, 'gate_u/1', 'GateFwd/2');

    add_sum(ss, 'SumCmd', '++', [900 90]);
    add_line(ss, 'GateU/1',  'SumCmd/1');
    add_line(ss, 'GateFwd/1','SumCmd/2');
    add_line(ss, 'SumCmd/1', 'u_cmd/1');
    add_line(ss, 'GateV/1',  'v_cmd/1');

    Simulink.BlockDiagram.arrangeSystem(ss);

    sl_note(ss, 'n_o', [ ...
        '위치 오차 -> 선체고정 오차 -> 비례 제어 -> 속도 포화 -> 문(gate_p)' newline ...
        'u_max 1.5 m/s · v_max 0.6 m/s — 접근 속도를 추력이 아니라 속도로 묶음' newline ...
        '그래서 멀리 있어도 안쪽 적분기가 포화에 눌려 쌓이지 않음' newline ...
        'gate_u 가지는 항로 추종·로이터의 u_ref. 둘은 배타적이라 더하면 곧 모드 선택임'], ...
        250, 560);
end

% =====================================================================
% 4단 · INNER LOOP — 속도 PI 둘 + 선수각 P–D + 추력 배분 (6주차에서)
% =====================================================================
function addInnerLoop(m, x, y)
% 4단 · INNER LOOP — 전후·횡 속도 PI 둘, 선수각 P–D 하나, 그리고 추력 배분.
%
%   포트   u_cmd, u, v_cmd, v, psi_ref, psi, r, gate_p  ->  FL, FR, FB
%
%   6주차 W06_simulink/parts/addInnerLoop.m 의 bow = true 판과 **구조도 게인도
%   같다.** 실습 A~D 의 InnerLoop 과 다른 점은
%
%     실습 A~D   전후 속도 PI 하나 + 선수각 P–D 하나 -> 추진기 둘
%     실습 E     전후·횡 속도 PI **둘** + 선수각 P–D 하나 -> 추진기 **셋**
%
%   횡 속도 고리가 생기는 것이 접안의 전부다. 선수추진기가 횡력을 내므로
%   배가 **돌지 않고 옆으로** 움직인다 — 순수 옆걸음(pure sway).
%
%   실습 A~D 에 없던 문 하나 — GateSway
%     접안이 아닌 동안 v_cmd 는 0 이다. 그런데 6주차 것을 그대로 쓰면 횡 PI 가
%     "횡속도를 0 으로 만들라" 는 지령으로 읽고 선수추진기 250 N 을 쓴다.
%     7주차에서 가르친 **크랩 각(beta)** 이 그만큼 지워져 로이터 궤적이 달라진다.
%     그래서 접안 모드가 아니면 횡 **오차**를 끊는다
%
%       오차를 끊는다  : PI 적분기가 0 에 머문다 -> 접안이 시작될 때 추력이 안 튄다
%       출력을 끊었다면: 적분기가 ±F_bow_max 로 포화된 채 기다린다 -> 문이 열리는
%                        순간 선수추진기가 최대로 튄다
%
%     다만 이 문은 **접안이 끝난 뒤에도 닫지 않는다.** 오차를 끊는 것은 적분기를
%     0 으로 되돌리는 것이 아니라 **그 자리에 얼리는 것**이다. 아직 감기지 않은
%     적분기라면 0 에 머물지만, 접안으로 한 번 감긴 뒤라면 그 값에 멈춘다.
%     2026-11-01 측정 — 접안 완료와 함께 문을 닫자 적분기가 96 N 에 얼어붙어
%     선수추진기가 계속 밀고, 배는 10 s 에 6.0 m 를 더 가 베이 뒤 벽을 뚫었다.
%     완료 뒤에도 열어 두면 위치 오차가 줄며 횡 지령이 스스로 사라진다 — 그것이 제동이다
%
%   선수각 고리는 **문을 달지 않는다.** 어느 모드에서도 선수각은 붙잡는다
    ss = add_subsys(m, 'InnerLoop', [x y x+190 y+190], ...
                    {'u_cmd','u','v_cmd','v','psi_ref','psi','r','gate_p'}, ...
                    {'FL','FR','FB'}, gnc_colour('control'));

    %  되먹임 입력은 오른쪽으로 물려 둔다 — 지령과 되먹임이 한 줄에서 만나야
    %  합산점이 읽힌다 (6주차와 같다)
    for nm = {'u','v','psi'}
        p = get_param([ss '/' nm{1}], 'Position');
        set_param([ss '/' nm{1}], 'Position', p + [120 0 120 0]);
    end

    %  --- 속도 오차 ---
    add_sum(ss, 'SumU', '+-', [250  90]);
    add_sum(ss, 'SumV', '+-', [250 210]);
    add_line(ss, 'u_cmd/1','SumU/1');  add_line(ss, 'u/1','SumU/2');
    add_line(ss, 'v_cmd/1','SumV/1');  add_line(ss, 'v/1','SumV/2');

    %  --- 횡 오차의 문 : 접안 모드가 아니면 끊는다 ---
    add_block('simulink/Math Operations/Product', [ss '/GateSway'], ...
              'Position', [300 190 330 230]);
    add_line(ss, 'SumV/1',  'GateSway/1');
    add_line(ss, 'gate_p/1','GateSway/2');

    %  --- 속도 PI 둘. 역계산 반포화 (6주차 게인 그대로) ---
    sl_pi(ss, 'PI_u', 'Kp_u', 'Ki_u', '2*F_max',   420,  60, 'Kb');
    sl_pi(ss, 'PI_v', 'Kp_v', 'Ki_v', 'F_bow_max', 420, 180, 'Kb');
    add_line(ss, 'SumU/1',    'PI_u/1');
    add_line(ss, 'GateSway/1','PI_v/1');

    %  --- 선수각 P–D. 문을 달지 않는다 ---
    add_ssa(ss, 'ErrPsi', 'Ssa', [250 330], 70);
    add_line(ss, 'psi_ref/1','ErrPsi/1');  add_line(ss, 'psi/1','ErrPsi/2');
    sl_gain(ss, 'Kp_psi',  'Kp_psi', 450, 310);
    sl_gain(ss, 'Kd_rate', 'Kd_psi', 450, 440);
    add_line(ss, 'Ssa/1','Kp_psi/1');
    add_line(ss, 'r/1',  'Kd_rate/1');
    add_sum(ss, 'SumN', '+-', [580 330]);          % 마이너스는 여기에 있다
    add_line(ss, 'Kp_psi/1', 'SumN/1');
    add_line(ss, 'Kd_rate/1','SumN/2');
    sl_sat(ss, 'SatN', '2*F_max*half_beam + F_bow_max*l_bow', 650, 310);
    add_line(ss, 'SumN/1','SatN/1');

    %  --- 추력 배분 ---
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Alloc'], ...
              'Position', [830 60 1010 460]);
    sl_fcn(ss, 'Alloc', allocFcn());
    add_line(ss, 'PI_u/1','Alloc/1');
    sl_gain(ss, 'BowOn', 'bow_on', 700, 180);      % 학생이 끌 수 있는 스위치
    add_line(ss, 'PI_v/1','BowOn/1');
    add_line(ss, 'BowOn/1','Alloc/2');
    add_line(ss, 'SatN/1','Alloc/3');
    sl_const(ss, 'PRM', 'alloc_prm', 640, 425);
    add_line(ss, 'PRM/1','Alloc/4');

    outs = {'FL','FR','FB'};
    for k = 1:3
        p = port_xy(ss, 'Alloc', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [1090 p(2)-10 1120 p(2)+10]);
        add_line(ss, sprintf('Alloc/%d',k), [outs{k} '/1']);
    end

    sl_note(ss, 'n_i', [ ...
        '속도 PI 둘(전후·횡) + 선수각 P-D 하나 -> 추력 배분' newline ...
        '선수추진기가 횡력을 내면 요 모멘트가 딸려 오므로 좌·우 추진기가 그만큼 되받음' newline ...
        'PI 는 역계산(back-calculation) — 잘려 나간 만큼을 Kb 배 해서 적분기로 되감음' newline ...
        'GateSway — 접안 모드가 아니면 횡 오차를 끊음. 접안이 끝난 뒤에는 닫지 않음' newline ...
        'BowOn 게인 — bow_on = 0 이면 횡력 지령이 끊김 (선수추진기 없는 배)'], 250, 560);
end

% =====================================================================
% 5단 · THRUSTERS — 추진기 **셋**. 실습 A~D 의 둘에서 선수추진기가 하나 늘었다
% =====================================================================
function addThrusters(m, x, y)
% 추력 지령 -> 회전수 -> 모터 1차 지연 -> 실제 추력.
%
%   실습 A~D 와 **구조가 같다.** 채널이 둘에서 셋으로 늘어난 것이 전부다
%
%     F2n       역프로펠러 법칙. 회전수 상한만 채널마다 다르다
%               좌·우 n_max, 선수추진기 n_bow_max
%     MotorLag  dn/dt = (n_cmd - n)/tau_n. A = -I/tau_n 이 3x3 으로 커졌다
%     n2F       프로펠러 법칙으로 되돌린다
%
%   대각 행렬이므로 세 축이 서로 섞이지 않는다. 시상수 tau_n 은 그대로다
    ss = [m '/Thrusters'];
    add_block('built-in/Subsystem', ss, 'Position', [x y x+170 y+150]);

    in = {'FL_cmd','FR_cmd','FB_cmd'};
    for k = 1:3
        add_block('simulink/Sources/In1', [ss '/' in{k}], ...
                  'Position', [40 60+(k-1)*80 75 60+(k-1)*80+30], 'Port', num2str(k));
    end

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/F2n'], 'Position', [170 70 320 318]);   % 포트 5개 — 52 px 간격
    setFcn(ss, 'F2n', [ ...
'function n_cmd = F2n(FL, FR, FB, k, lim)'                            newline ...
'%#codegen'                                                           newline ...
'% Inverse propeller law:  F = k*n*|n|  ->  n = sign(F)*sqrt(|F|/k)'  newline ...
'% lim 은 채널별 회전수 상한 — 선수추진기는 좌·우보다 작다'           newline ...
'F = [FL; FR; FB];'                                                   newline ...
'n_cmd = zeros(3,1);'                                                 newline ...
'for i = 1:3'                                                         newline ...
'    ni = sign(F(i)) * sqrt(abs(F(i))/k);'                            newline ...
'    if ni >  lim(i), ni =  lim(i); end'                              newline ...
'    if ni < -lim(i), ni = -lim(i); end'                              newline ...
'    n_cmd(i) = ni;'                                                  newline ...
'end']);

    add_block('simulink/Sources/Constant', [ss '/Kp'], ...
              'Position',[40 320 130 350], 'Value','k_prop');
    add_block('simulink/Sources/Constant', [ss '/Nm'], ...
              'Position',[40 370 130 400], 'Value','[n_max; n_max; n_bow_max]');

    %  n2F 가 쓰는 k 는 **같은 k_prop 이다.** 그런데 상수 하나에서 가지를 치면
    %  선이 F2n 과 MotorLag 위를 되돌아가며 세 번 꺾인다 (배선 검사 불합격).
    %  상수를 받는 자리 옆에 하나 더 두면 두 선이 모두 직선 한 토막이다
    add_block('simulink/Sources/Constant', [ss '/Kp_n'], ...
              'Position',[430 320 520 350], 'Value','k_prop');

    %  모터 1차 지연 — **연속 시간**이다 (교수 지시 2026-10-01).
    %  Transfer Fcn 블록은 벡터 입력을 받지 않으므로 같은 1차 지연을 상태공간
    %  한 블록으로 적는다. A = -I/tau_n, B = I/tau_n, C = I, D = 0 이 곧
    %
    %      dn/dt = (n_cmd - n) / tau_n
    %
    %  이고, 대각이므로 좌·우·선수 세 축이 서로 섞이지 않는다
    add_block('simulink/Continuous/State-Space', [ss '/MotorLag'], ...
              'Position',[380 85 500 145]);
    set_param([ss '/MotorLag'], 'A','-eye(3)/tau_n', 'B','eye(3)/tau_n', ...
              'C','eye(3)', 'D','zeros(3)', 'X0','zeros(3,1)');

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/n2F'], 'Position', [560 70 700 190]);
    setFcn(ss, 'n2F', [ ...
'function [FL, FR, FB] = n2F(n, k)'                              newline ...
'%#codegen'                                                      newline ...
'FL = k * n(1) * abs(n(1));'                                     newline ...
'FR = k * n(2) * abs(n(2));'                                     newline ...
'FB = k * n(3) * abs(n(3));']);

    %  회전수 n 은 이 주차의 로깅·화면 어디에도 없다. 내보내면 받는 From 이 없는
    %  태그만 남으므로(check_tags) 포트를 두지 않는다
    out = {'FL','FR','FB'};
    for k = 1:3
        add_block('simulink/Sinks/Out1', [ss '/' out{k}], ...
                  'Position',[780 70+(k-1)*60 815 100+(k-1)*60], 'Port', num2str(k));
    end

    for k = 1:3
        add_line(ss, [in{k} '/1'], sprintf('F2n/%d',k), 'autorouting','on');
    end
    add_line(ss,'Kp/1','F2n/4','autorouting','on');
    add_line(ss,'Nm/1','F2n/5','autorouting','on');
    add_line(ss,'F2n/1','MotorLag/1','autorouting','on');
    add_line(ss,'MotorLag/1','n2F/1','autorouting','on');
    add_line(ss,'Kp_n/1','n2F/2','autorouting','on');
    for k = 1:3
        add_line(ss, sprintf('n2F/%d',k), [out{k} '/1'], 'autorouting','on');
    end

    Simulink.BlockDiagram.arrangeSystem(ss);

    %  설정 상수와 입력을 받는 포트 높이에 맞춘다 — 그러면 잇는 선이 직선 한
    %  토막이다. arrangeSystem 은 선 길이만 보지 높이를 맞춰 주지는 않는다
    align_to(ss, 'FL_cmd', 'Outport', port_xy(ss, 'F2n', 'Inport', 1));
    align_to(ss, 'FR_cmd', 'Outport', port_xy(ss, 'F2n', 'Inport', 2));
    align_to(ss, 'FB_cmd', 'Outport', port_xy(ss, 'F2n', 'Inport', 3));
    align_to(ss, 'Kp',     'Outport', port_xy(ss, 'F2n', 'Inport', 4));
    align_to(ss, 'Nm',     'Outport', port_xy(ss, 'F2n', 'Inport', 5));
    align_to(ss, 'Kp_n',   'Outport', port_xy(ss, 'n2F', 'Inport', 2));
end

% =====================================================================
% 6단 · MOTION MODEL — 횡력이 들어오고 횡속도가 나온다
% =====================================================================
function addMotionModel(m, x, y)
% 3자유도 WAM-V 운동방정식. 실습 A~D 와 **식이 같다.**
%
%   달라진 곳은 둘뿐이다
%
%     Y = FB                             실습 A~D 는 횡력이 0 이었다
%     N = (FL - FR)*b_half + l3*FB       선수추진기가 요 모멘트도 만든다
%
%   그래서 dv 식의 Y 가 살아나고, States 가 v 를 하나 더 낸다. 계수는 그대로다
    ss = [m '/MotionModel'];
    add_block('built-in/Subsystem', ss, 'Position', [x y x+210 y+230]);

    in = {'FL','FR','FB','p'};   % 앞의 셋만 신호. p 는 설정이라 상자 안에 둔다
    for k = 1:3
        add_block('simulink/Sources/In1', [ss '/' in{k}], ...
                  'Position', [40 60+(k-1)*70 75 60+(k-1)*70+30], 'Port', num2str(k));
    end

    % 선체 계수는 신호가 아니라 설정이다. 상자 안에 둔다
    add_block('simulink/Sources/Constant', [ss '/p'], ...
              'Position', [40 290 130 320], ...
              'Value', '[m_usv; Izz; Xu; Xuu; Yv; Yvv; Nr; Nrr; half_beam; l_bow]');

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/EOM'], 'Position', [200 60 380 280]);
    setFcn(ss, 'EOM', [ ...
'function xdot = EOM(s, FL, FR, FB, p)'                                  newline ...
'%#codegen'                                                              newline ...
'% 3-DOF WAM-V equations of motion, NED.'                                newline ...
'% Coefficients come straight from the Gazebo VRX plugins.'              newline ...
'u = s(1); v = s(2); r = s(3); psi = s(6);'                              newline ...
'm=p(1); Izz=p(2); Xu=p(3); Xuu=p(4); Yv=p(5); Yvv=p(6);'                newline ...
'Nr=p(7); Nrr=p(8); b_half=p(9); l3=p(10);'                              newline ...
''                                                                       newline ...
'% 선수추진기는 **횡력**과 **요 모멘트**를 동시에 만든다 (l3 만큼 앞에 있다)'  newline ...
'X = FL + FR;'                                                           newline ...
'Y = FB;'                                                                newline ...
'N = (FL - FR)*b_half + l3*FB;'                                          newline ...
'Dx = (Xu + Xuu*abs(u))*u;'                                              newline ...
'Dy = (Yv + Yvv*abs(v))*v;'                                              newline ...
'Dn = (Nr + Nrr*abs(r))*r;'                                              newline ...
''                                                                       newline ...
'du = (X - Dx)/m + v*r;'                                                 newline ...
'dv = (Y - Dy)/m - u*r;'                                                 newline ...
'dr = (N - Dn)/Izz;'                                                     newline ...
''                                                                       newline ...
'xdot = [du; dv; dr;'                                                    newline ...
'        u*cos(psi) - v*sin(psi);'                                       newline ...
'        u*sin(psi) + v*cos(psi);'                                       newline ...
'        r];']);

    add_block('simulink/Continuous/Integrator', [ss '/Integ'], ...
              'Position', [450 130 500 180], 'InitialCondition','x0');

    add_block('simulink/User-Defined Functions/MATLAB Function', ...
              [ss '/States'], 'Position', [570 60 720 300]);
    setFcn(ss, 'States', [ ...
'function [x_n, y_n, psi, u, v, r, beta] = States(s)'         newline ...
'%#codegen'                                                 newline ...
'% v (횡속도) 를 하나 더 낸다 — 접안이 횡속도 고리로 돌아가므로'      newline ...
'% 제어기도 화면도 v 를 읽는다. 실습 A~D 는 쓰지 않아 내보내지 않았다.' newline ...
'% chi (침로) 와 U (대지속력) 는 이 주차가 쓰지 않는다 (check_tags).'  newline ...
'u = s(1); v = s(2); r = s(3);'                             newline ...
'x_n = s(4); y_n = s(5); psi = s(6);'                         newline ...
'beta = atan2(v, u);']);

    % --- 배치 : 한 줄에 EOM -> 1/s -> States. 포트 높이를 읽어서 맞춘다 ----
    ROW = 340;
    set_param([ss '/EOM'],    'Position', [280 140 460 600]);
    set_param([ss '/Integ'],  'Position', [560 ROW-15 590 ROW+15]);
    set_param([ss '/States'], 'Position', [680 100 840 640]);

    % 2~5번 입력(추력 셋 + 계수)을 각자 포트 높이로 옮겨 직선으로 잇는다
    row_feed(ss, 'EOM', [{''}, in]);

    add_line(ss, 'EOM/1',   'Integ/1');
    add_line(ss, 'Integ/1', 'States/1');

    % 상태 되먹임 — 화면을 가로지르는 대신 태그로 건너뛴다
    drop_tag(ss, 'Integ', 1, 'x_state', 280);
    b = port_xy(ss, 'EOM', 'Inport', 1);
    add_block('simulink/Signal Routing/From', [ss '/Fr_x_state'], ...
              'Position', [180 b(2)-11 250 b(2)+11], 'GotoTag','x_state');
    add_line(ss, 'Fr_x_state/1', 'EOM/1');

    % 출력 포트를 States 의 포트 높이에 맞춘다 -> 일곱 선이 전부 직선
    out = {'x_n','y_n','psi','u','v','r','beta'};
    for k = 1:numel(out)
        q = port_xy(ss, 'States', 'Outport', k);
        add_block('simulink/Sinks/Out1', [ss '/' out{k}], ...
                  'Position', [940 q(2)-7 970 q(2)+7], 'Port', num2str(k));
        add_line(ss, sprintf('States/%d',k), [out{k} '/1']);
    end
end

% =====================================================================
% 7단 · ANIMATE
% =====================================================================
function addAnimate(m, x, y)
% 실시간 그림 — 포트 없는 서브시스템 하나로 묶는다.
%
%   태그 순서가 곧 W08_dock_animate 의 인자 순서다 (뒤에 t, en 이 붙는다).
%   하나라도 빠뜨리면 그 자리부터 인자가 한 칸씩 밀려 t 가 비고, 모델을 돌리는
%   순간 "입력 인수가 부족합니다" 로 멈춘다 (2026-09-17 확인).
%
%   열한 개는 실습 A 와 같고 **둘이 늘었다** — phase (접안 단계) 와 v (횡속도).
%   gate 는 gate_u 로 이름이 바뀌었다. 열셋이 전부 **이미 있던 전역 태그**다.
%   새로 가지를 치지 않는다 — Gate 출력에 가지를 치면 Simulink 가 본선을
%   사선으로 다시 그어 check_lines 가 걸린다 (5주차 2026-09-24).
%     x_n y_n psi u v    MotionModel (VRX 는 PoseSubscriber)
%     mode psi_ref gate_u  Mission    turns idx phase  Guidance    FL FR  Thrusters
    add_animate_box(m, {'x_n','y_n','psi','mode','turns', ...
                        'psi_ref','u','gate_u','FL','FR','idx','phase','v'}, ...
                    'W08_dock_animate', '', [x y], 'Ts_ctrl');
end

% =====================================================================
% 앞단 배선 (두 모델 공통)
%   설정값은 각 상자 안에 있다. 최상위에 남는 것은 되먹임뿐이다.
% =====================================================================
function wireFront(m)
    fx = F(m,'x_n',   40,  65);
    fy = F(m,'y_n',   40, 110);
    fb = F(m,'beta',  40, 155);
    fm = F(m,'mode',  40, 200);
    f1 = F(m,'psi',   40, 245);
    fu0 = F(m,'u',    40, 290);   % 접안 단계 걸쇠가 "멈췄는가"를 본다 (BerthRef)

    add_line(m,[fx '/1'],'Guidance/1','autorouting','on');
    add_line(m,[fy '/1'],'Guidance/2','autorouting','on');
    add_line(m,[fb '/1'],'Guidance/3','autorouting','on');
    add_line(m,[fm '/1'],'Guidance/4','autorouting','on');
    add_line(m,[f1 '/1'],'Guidance/5','autorouting','on');
    add_line(m,[fu0 '/1'],'Guidance/6','autorouting','on');

    % 유도 -> 미션 : 일곱 줄이 그대로 넘어간다
    % 유도 출력과 미션 입력의 **순서가 같다**. 일곱 선이 전부 직선이 된다
    for k = 1:7
        add_line(m, sprintf('Guidance/%d',k), sprintf('Mission/%d',k), 'autorouting','on');
    end

    % 외부루프 입력 : 미션이 낸 문 둘 + 목표 위치 + 위치·자세 되먹임
    %   x_ref · y_ref 는 유도부(BerthRef)가 낸 태그다. 사슬에서 두 칸 앞이라
    %   선으로 이으면 Mission 상자를 건너뛴다
    fxr = F(m,'x_ref', 1180, 480);
    fyr = F(m,'y_ref', 1180, 520);
    fx2 = F(m,'x_n',   1180, 560);
    fy2 = F(m,'y_n',   1180, 600);
    fp2 = F(m,'psi',   1180, 640);
    add_line(m,[fxr '/1'],'OuterLoop/1','autorouting','on');
    add_line(m,[fyr '/1'],'OuterLoop/2','autorouting','on');
    add_line(m,[fx2 '/1'],'OuterLoop/3','autorouting','on');
    add_line(m,[fy2 '/1'],'OuterLoop/4','autorouting','on');
    add_line(m,[fp2 '/1'],'OuterLoop/5','autorouting','on');
    %  Mission 과 OuterLoop 은 사슬에서 나란하다 — 선으로 잇는다
    add_line(m,'Mission/1','OuterLoop/6','autorouting','on');   % gate_p
    add_line(m,'Mission/2','OuterLoop/7','autorouting','on');   % gate_u

    % 내부루프 입력 : 외부루프가 낸 속도 지령 둘 + 속도·자세 되먹임 + 문 하나
    fu  = F(m,'u',      1680, 700);
    fv  = F(m,'v',      1680, 740);
    fpr = F(m,'psi_ref',1680, 780);
    fp3 = F(m,'psi',    1680, 820);
    fr  = F(m,'r',      1680, 860);
    fg  = F(m,'gate_p', 1680, 900);
    %  OuterLoop 과 InnerLoop 도 같은 줄에 있다 — 옆 단계로 가는 본선에 태그를
    %  쓰지 않는다 (SKILL.md §2 규칙 5.1 "가까우면 선으로 잇는다")
    add_line(m,'OuterLoop/1','InnerLoop/1','autorouting','on');   % u_cmd
    add_line(m,[fu  '/1'],   'InnerLoop/2','autorouting','on');
    add_line(m,'OuterLoop/2','InnerLoop/3','autorouting','on');   % v_cmd
    add_line(m,[fv  '/1'],   'InnerLoop/4','autorouting','on');
    add_line(m,[fpr '/1'],   'InnerLoop/5','autorouting','on');
    add_line(m,[fp3 '/1'],   'InnerLoop/6','autorouting','on');
    add_line(m,[fr  '/1'],   'InnerLoop/7','autorouting','on');
    add_line(m,[fg  '/1'],   'InnerLoop/8','autorouting','on');
end

% =====================================================================
% 내부루프 -> 추진기 : 사슬이 줄을 바꾸는 자리 (두 모델 공통)
%
%   lay_chain 은 줄이 바뀌는 자리의 연결을 Goto/From 한 쌍으로 바꾼다 — 선으로
%   두면 오른쪽 끝에서 왼쪽 끝으로 거슬러 올라가 도면을 가로지르기 때문이다.
%   그런데 lay_chain 은 **신호 이름을 모른다.** 그래서 `InnerLoop_1` 처럼 블록
%   이름에서 딴 태그를 만들고 check_tags 가 그것을 잡는다 (0 이 합격선).
%
%   그래서 빌더가 미리 이름을 붙여 둔다. 추력 **지령**이므로 추진기 입력 포트
%   이름 그대로 FL_cmd · FR_cmd · FB_cmd 다 — 추진기 **출력**의 FL · FR · FB
%   (모터 지연을 지난 실제 추력) 과 구별된다.
% =====================================================================
function wireAllocToThrusters(m, x, y)
    nm = {'FL_cmd','FR_cmd','FB_cmd'};
    for k = 1:3
        G(m, nm{k}, x, y+(k-1)*45);
        add_line(m, sprintf('InnerLoop/%d',k), ['Go_' nm{k} '/1'], 'autorouting','on');
        f = F(m, nm{k}, x+130, y+(k-1)*45);
        add_line(m, [f '/1'], sprintf('Thrusters/%d',k), 'autorouting','on');
    end
end

% =====================================================================
% 로깅
% =====================================================================
function addLogging(m, x, y)
% 로깅 — 포트 없는 서브시스템 하나로 묶는다. W08_dock_plot.m 이 이것을 읽는다.
%
%   실습 A 의 열넷에 여섯이 늘었다 — gate 가 gate_u 로 갈라지고 gate_p 가
%   생기고, 접안을 읽으려면 phase · v · x_ref · y_ref · FB 가 있어야 한다
    sig = {'x_n','y_n','psi','psi_ref','y_e','idx','mode','turns', ...
           'gate_u','gate_p','phase','u','v','beta','r_lo', ...
           'FL','FR','FB','x_ref','y_ref'};
    add_logging_box(m, sig, sig, [x y], 'Ts_ctrl');
end

% =====================================================================
% 오프라인 모델 — W08_2_dock
% =====================================================================
function build_offline()
    m = 'W08_2_dock'; fresh(m);
    %  정지 시간 — 실습 A 의 700 s 에 접안 구간을 더해 900 s 로 둔다.
    %  Finish 에 들어가면 배는 위치제어로 선석을 지킨 채 남은 시간을 보낸다
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime','900', 'SimulationMode','normal');

    addGuidance(m, 300, 60);
    addMissionFSM(m, 800, 620);    % Mission 상자 — ModeSwitch·ModeDly 까지 안에 있다
    addOuterLoop(m, 1350, 560);    % 6주차 위치제어 — 접안 구간에서만 문이 열린다
    addInnerLoop(m, 1900, 560);
    wireFront(m);
    addThrusters(m, 2250, 570);
    addMotionModel(m, 2550, 560);

    %  줄이 바뀌는 자리 (첫 줄 끝 InnerLoop -> 둘째 줄 머리 Thrusters)
    wireAllocToThrusters(m, 2150, 420);

    for k = 1:3
        add_line(m, sprintf('Thrusters/%d',k), sprintf('MotionModel/%d',k), ...
                 'autorouting','on');
    end

    thr = {'FL','FR','FB'};
    for k = 1:3
        G(m, thr{k}, 2450, 800+(k-1)*40);
        add_line(m, sprintf('Thrusters/%d',k), ['Go_' thr{k} '/1'], 'autorouting','on');
    end

    tags = {'x_n','y_n','psi','u','v','r','beta'};
    for k = 1:numel(tags)
        G(m, tags{k}, 2820, 560+(k-1)*40);
        add_line(m, sprintf('MotionModel/%d',k), ['Go_' tags{k} '/1'], 'autorouting','on');
    end

    addAnimate(m, 2820, 980);
    addLogging(m, 3280, 60);

    note(m,'n1', ['W08 실습 E  —  웨이포인트 + 로이터링 + 접안 (Gazebo 불필요)' newline ...
        'MissionFSM 이 상태 넷을 고른다 — WpFollow -> Loiter -> WpFollow -> Dock -> Finish' newline ...
        '앞의 세 상태는 실습 A 와 같다. 마지막 Dock 에서 유도를 끊고 위치제어가 받는다' newline ...
        '접안은 순수 옆걸음 — 선수각을 부두와 나란히 붙잡은 채 선수추진기로 옆으로 민다' newline ...
        '실행 전 >> W08_dock_setup'], 300, -140);

    save_system(m); close_system(m);
    fprintf('  W08_2_dock       생성\n');
end

% =====================================================================
% VRX 연동 모델 — W08_3_dock_vrx
% =====================================================================
function build_vrx()
    m = 'W08_3_dock_vrx'; fresh(m);
    load_system('ros2lib');
    set_param(m, 'SolverType','Fixed-step', 'SolverName','ode4', ...
                 'FixedStep','Ts_ctrl', 'StopTime','inf', 'SimulationMode','normal');

    addGuidance(m, 300, 60);
    addMissionFSM(m, 800, 620);
    addOuterLoop(m, 1350, 560);
    addInnerLoop(m, 1900, 560);
    wireFront(m);
    addThrusters(m, 2250, 570);

    % --- 6단 · 추력 발행 (운동모델 = Gazebo) -----------------------------
    %  토픽이 **셋**이다. 선수추진기 토픽은 WAM-V 기본 구성에 없으므로 xacro 에
    %  추진기를 더해 두어야 한다 (W06_vrx_lite/make_wamv_bow.sh). 토픽이 없으면
    %  발행은 **조용히 버려지고** 배는 선수각만 겨우 맞춘 채 옆으로 가지 않는다
    add_cmd_publisher(m, [2550 470], ...
        {'/wamv/thrusters/left/thrust', ...
         '/wamv/thrusters/right/thrust', ...
         '/wamv/thrusters/bow/thrust'}, 'Ts_ctrl', {'FL','FR','FB'});

    %  줄이 바뀌는 자리 (오프라인 쌍둥이와 같은 자리)
    wireAllocToThrusters(m, 2150, 420);
    for k = 1:3
        add_line(m, sprintf('Thrusters/%d',k), sprintf('CmdPublisher/%d',k), ...
                 'autorouting','on');
    end

    thr = {'FL','FR','FB'};
    for k = 1:3
        G(m, thr{k}, 2450, 860+(k-1)*40);
        add_line(m, sprintf('Thrusters/%d',k), ['Go_' thr{k} '/1'], 'autorouting','on');
    end

    % --- 7단 · 항법 (ENU -> NED 변환) -----------------------------------
    navCode = [ ...
'function [x_n, y_n, psi, u, v, r, beta] = Nav(ex, ey, qx, qy, qz, qw, bx, by, wz, org_x, org_y)' newline ...
'%#codegen'                                                                 newline ...
'% Gazebo/ROS uses ENU with a body frame of x-forward, y-LEFT, z-UP.'       newline ...
'% Marine control uses NED with x-forward, y-STARBOARD, z-DOWN.'            newline ...
'% 부호를 하나라도 빼먹으면 선수추진기가 **반대로** 밀어 배가 선석에서'     newline ...
'% 멀어진다. 쌍둥이의 그림을 겹쳐 보는 이유가 이것이다.'                    newline ...
'% 첫 메시지가 도착하기 전에는 Subscribe 가 0 으로 채운 버스를 낸다.'       newline ...
'% 그대로 쓰면 위치가 스폰 원점만큼(약 568 m) 튀어 로그 첫 점이 망가진다.'  newline ...
'if ex == 0 && ey == 0'                                                     newline ...
'    x_n = 0; y_n = 0; psi = 0; u = 0; v = 0; r = 0; beta = 0;'             newline ...
'    return'                                                                newline ...
'end'                                                                       newline ...
'x_n = ey - org_x;'                                                         newline ...
'y_n = ex - org_y;'                                                         newline ...
'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'                newline ...
'p   = pi/2 - yaw_enu;'                                                     newline ...
'psi = atan2(sin(p), cos(p));'                                              newline ...
'u = bx;  v = -by;  r = -wz;'                                               newline ...
'beta = atan2(v, u);'];

    %  오프라인 쌍둥이의 States 와 출력이 **똑같아야 한다** — 일곱 개다.
    %  chi (침로) 와 U (대지속력) 는 이 주차가 쓰지 않는다 (check_tags)
    add_pose_subscriber(m, [2910 970], ...
        '/wamv/sensors/position/ground_truth_odometry', 'Ts_ctrl', navCode, ...
        {'x_n','y_n','psi','u','v','r','beta'});

    tags = {'x_n','y_n','psi','u','v','r','beta'};
    for k = 1:numel(tags)
        G(m, tags{k}, 3150, 970+(k-1)*45);
        add_line(m, sprintf('PoseSubscriber/%d',k), ['Go_' tags{k} '/1'], ...
                 'autorouting','on');
    end

    addAnimate(m, 3150, 1340);
    addLogging(m, 3600, 60);

    note(m,'n1', ['W08 실습 E-VRX  —  접안까지 VRX 로 (Gazebo 필요)' newline ...
        'Guidance -> Mission -> Outer Loop -> Inner Loop -> Thrusters -> Gazebo -> Navigation' newline ...
        '유도부·미션·위치제어·게인은 W08_2_dock 과 완전히 같다. 운동모델만 Gazebo 로 바뀐다' newline ...
        '선수추진기 토픽이 있어야 한다 — WSL 에서 bash W06_vrx_lite/make_wamv_bow.sh' newline ...
        '실행 전: (1) W08_dock_setup  (2) VRX 기동  (3) 페이싱을 실측 RTF 에 맞출 것'], ...
        300, -140);

    save_system(m); close_system(m);
    fprintf('  W08_3_dock_vrx   생성\n');
end
