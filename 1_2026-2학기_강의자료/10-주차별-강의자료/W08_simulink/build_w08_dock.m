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

    %  최상위 배치 — Wrap 4 로 두 모델이 **같은 자리**(InnerLoop → Thrusters)에서
    %  줄을 바꾼다. 그 자리의 연결은 빌더가 FL_cmd·FR_cmd·FB_cmd 태그로 미리
    %  이름 붙여 두었으므로 lay_chain 이 블록 이름 꼴 태그를 새로 만들지 않는다
    lay_chain('W08_2_dock', {'Guidance','Mission','OuterLoop','InnerLoop', ...
                             'Thrusters','MotionModel'}, ...
              'Boxes', {'Animate','Logging'}, 'Wrap', 4);
    lay_chain('W08_3_dock_vrx', {'Guidance','Mission','OuterLoop','InnerLoop', ...
                                 'Thrusters','CmdPublisher','PoseSubscriber'}, ...
              'Boxes', {'Animate','Logging'}, 'Wrap', 4);

    %  색 — 역할표는 _tools/gnc_roles.m 하나뿐이다. 빌더는 부르기만 한다
    %  (이 두 모델은 6주차처럼 위치 고리가 하나 더 있어 역할표에 OuterLoop 이 더해져 있다)
    for mm = {'W08_2_dock','W08_3_dock_vrx'}
        m = mm{1}; load_system(m);
        paint_roles(m);
        check_colour(m);
        mss_style(m);
        snug_tags(m);
        pack_boxes(m, {'Animate','Logging'});
        save_system(m); check_lines(m, false); export_diagram(m);
        close_system(m, 0);
    end

    %  강의노트가 쓰는 서브시스템 도면. 실습 A 의 img/MissionFSM.png 를 덮지 않도록
    %  파일명을 따로 둔다
    load_system('W08_2_dock');
    g = export_diagram('W08_2_dock', '', 'Mission/MissionFSM');
    movefile(g, fullfile(here, 'img', 'MissionFSM_dock.png'), 'f');
    close_system('W08_2_dock', 0);

    fprintf('\n완료. 생성된 모델:\n');
    d = dir('W08_[23]_*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
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
