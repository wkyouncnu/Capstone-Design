function fig = A2_5_gui_done()
%A2_5_GUI_DONE  5단 — 버튼 달린 GCS 화면 (완성본)
%
%   >> A2_5_gui_done
%
%   4단과 무엇이 다른가
%     4단은 **찍고 나서 돌렸다.** 클릭(`ginput`)과 주행이 순서대로 일어난다
%     5단은 **돌면서 찍는다.** 배가 가는 중에 점을 더 찍으면 그리로 간다
%
%   | 항목        | 4단                      | 5단                        |
%   |-------------|--------------------------|----------------------------|
%   | 클릭 받기   | `ginput` (막는 함수)     | 창의 `WindowButtonDownFcn` |
%   | 실행        | `sim()` 한 번            | '출발' 버튼                |
%   | 임무 변경   | 못 한다                  | 실행 중에 점 추가·삭제     |
%   | 정지        | AutoStop 이 알아서       | '정지' 버튼                |
%
%   왜 `ginput` 을 버리는가
%     `ginput` 은 클릭을 기다리는 동안 MATLAB 전체를 **막는다**.
%     시뮬레이션이 돌아가는 중에는 쓸 수 없다. 실제 GCS 가 버튼과 콜백으로
%     만들어지는 이유가 이것이다
%
%   쓰는 순서
%     1. '웨이포인트 찍기' 를 누른다 (눌린 상태로 둔다)
%     2. 위성지도를 눌러 점을 찍는다 (최대 WP_MAX 개)
%     3. '출발' — 배가 1 번 점을 향해 떠난다
%     4. 가는 중에 지도를 더 눌러 본다 — 경로가 늘어나고 배가 따라간다
%     5. '정지' — 멈추고 측정값이 명령창에 표로 나온다
%
%   이 파일이 맡은 것 — 수업의 요점 세 가지
%     1. 클릭한 위경도를 NED 로 내려 **고정 길이 버퍼**에 넣는다
%     2. 바뀐 값을 **실행 중인 모델에 반영**한다 (`assignin` + `update`)
%     3. 버튼을 **모델 명령**으로 옮긴다 (`SimulationCommand`)
%   창·축·버튼을 만드는 일은 `A2_gui_panel` 이 맡는다

here = fileparts(mfilename('fullpath'));
addpath(here);

%% ====================================================================
%  1. 설정 — **베이스 워크스페이스**에 깔아야 한다
%     Constant 블록은 베이스 워크스페이스의 변수를 읽는다.
%     이 파일은 함수이므로 그냥 부르면 함수 안에만 생긴다 -> evalin 으로 베이스에서 돌린다
% =====================================================================
evalin('base', 'A2_gui_setup');

%% ====================================================================
%  2. 모델 — 5주차 모델에서 파생시킨다
% =====================================================================
A2_build_gui_model();

m = 'A2_gui';
load_system(fullfile(here, [m '.slx']));

%  실시간 페이싱 — 시뮬레이션 1 초를 벽시계 1 초에 맞춘다.
%  끄면 수백 배 빨리 돌아 클릭할 틈이 없다
set_param(m, 'EnablePacing', 'on', 'PacingRate', '1');

%  버튼으로 돌리면 `sim()` 처럼 결과를 돌려받을 자리가 없다.
%  멈출 때 베이스 워크스페이스에 `out` 으로 로그를 내려 달라고 걸어 둔다
set_param(m, 'ReturnWorkspaceOutputs', 'on', ...
             'ReturnWorkspaceOutputsName', 'out');

%% ====================================================================
%  3. 창 — 버튼과 클릭은 모두 아래의 on_action 으로 들어온다
% =====================================================================
fig = A2_gui_panel(@on_action);

fprintf('\n=== 5단 · 버튼 GCS ===\n');
fprintf('  1) "웨이포인트 찍기" 를 누른 뒤 위성지도를 눌러 점을 찍는다\n');
fprintf('  2) "출발" 을 누른다 — 1 초에 1 초치를 돈다 (실시간)\n');
fprintf('  3) 가는 중에 지도를 더 눌러 본다. 경로가 늘어나고 배가 따라간다\n');
fprintf('  4) "정지" 를 누르면 측정값이 표로 나온다\n\n');
end

% =====================================================================
function on_action(fig, what, varargin)
%ON_ACTION  창에서 올라온 모든 사건을 한자리에서 받는다
%
%   버튼 하나마다 함수를 두지 않는다. 어느 동작이 어느 모델 명령으로
%   가는지 한 화면에서 보이는 것이 읽기에 낫다

    switch what
        case 'click'
            add_point(fig, varargin{1}, varargin{2});
        case 'undo'
            drop_point(fig);
        case 'clear'
            clear_points(fig);
        case 'start'
            start_run(fig);
        case 'pause'
            toggle_pause(fig);
        case 'stop'
            stop_run(fig);
        otherwise
            warning('A2:action', '모르는 동작 : %s', what);
    end
end

% =====================================================================
function add_point(fig, lat, lon)
%ADD_POINT  지도에서 누른 한 점을 임무에 더한다  ← 요점 1
    S = getappdata(fig, 'S');

    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    n   = double(evalin('base', 'n_wp'));

    if n >= S.WP_MAX
        A2_gui_panel(fig, 'say', sprintf( ...
            '자리가 찼다 (WP_MAX = %d). 지우고 다시 찍을 것', S.WP_MAX));
        return
    end

    %  위경도를 기준점 기준의 NED 로 내린다.
    %  세 번째 인자 'flat' 은 생략할 수 없다 (접평면 근사를 쓰라는 뜻)
    d = lla2ned([lat lon 0], S.lla0, 'flat');

    %  **고정 길이 버퍼의 빈 칸을 채운다.** 배열을 늘리지 않는다 —
    %  실행 중에 길이가 바뀌면 Simulink 가 거부한다
    wpx(n+1) = d(1);
    wpy(n+1) = d(2);

    push_mission(fig, wpx, wpy, n+1);

    A2_gui_panel(fig, 'say', sprintf( ...
        '%d 번 점 : %.6f, %.6f  ->  N %+.1f m, E %+.1f m   (점 %d 개)', ...
        n, lat, lon, d(1), d(2), n+1));
end

% =====================================================================
function drop_point(fig)
%DROP_POINT  마지막 점을 지운다
    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    n   = double(evalin('base', 'n_wp'));
    if n < 2
        A2_gui_panel(fig, 'say', '지울 점이 없다 (출발점만 남았다)');
        return
    end
    %  뒤 칸의 값은 지우지 않아도 된다 — 유도부는 앞 n_wp 개만 읽는다
    push_mission(fig, wpx, wpy, n-1);
    A2_gui_panel(fig, 'say', sprintf('마지막 점을 지웠다 (점 %d 개)', n-1));
end

% =====================================================================
function clear_points(fig)
%CLEAR_POINTS  출발점만 남긴다
    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    push_mission(fig, wpx, wpy, 1);
    A2_gui_panel(fig, 'say', '전부 지웠다 — 다시 찍을 것');
end

% =====================================================================
function push_mission(fig, wpx, wpy, n)
%PUSH_MISSION  바뀐 임무를 모델에 밀어 넣는다  ← 요점 2
%
%   베이스 워크스페이스의 세 변수가 임무의 **유일한 원본**이다.
%   창은 그것을 비추기만 한다 (같은 값을 두 군데에 두지 않는다)

    S = getappdata(fig, 'S');

    assignin('base', 'wp_north', wpx);
    assignin('base', 'wp_east',  wpy);
    assignin('base', 'n_wp',     n);

    %  **이 한 줄이 5단의 심장이다.**
    %  베이스 워크스페이스를 고쳐도 돌아가는 모델은 **옛 값을 계속 쓴다.**
    %  'update' 를 보내야 Constant 블록이 새 값을 다시 읽는다.
    %  빼먹으면 오류 메시지 없이 배가 옛 점으로 간다
    if is_running(S.model)
        set_param(S.model, 'SimulationCommand', 'update');
    end

    A2_gui_panel(fig, 'mission');       % 계획 경로를 다시 그린다
end

% =====================================================================
function start_run(fig)
%START_RUN  출발  ← 요점 3
    S = getappdata(fig, 'S');
    if is_running(S.model)
        A2_gui_panel(fig, 'say', '이미 돌아가는 중이다');
        return
    end

    A2_animate_gui('reset');            % 항적과 그래프 버퍼를 비운다
    set_param(S.model, 'SimulationCommand', 'start');

    %  start 는 **기다리지 않고 돌아온다.** 그래서 버튼을 눌러도 MATLAB 이 멈추지 않는다.
    %  상태가 바뀔 때까지 잠깐 기다린 뒤 버튼 상태를 맞춘다
    wait_status(S.model, 'stopped', false, 5);
    A2_gui_panel(fig, 'mission');
    A2_gui_panel(fig, 'say', '출발 — 가는 중에 지도를 더 눌러 점을 더할 수 있다');
end

% =====================================================================
function toggle_pause(fig)
%TOGGLE_PAUSE  일시정지 / 계속
    S = getappdata(fig, 'S');
    if ~is_running(S.model)
        A2_gui_panel(fig, 'say', '돌아가는 중이 아니다');
        return
    end
    if strcmp(get_param(S.model, 'SimulationStatus'), 'paused')
        set_param(S.model, 'SimulationCommand', 'continue');
        set(S.bPause, 'String', '일시정지');
        A2_gui_panel(fig, 'say', '계속');
    else
        set_param(S.model, 'SimulationCommand', 'pause');
        set(S.bPause, 'String', '계속');
        A2_gui_panel(fig, 'say', '일시정지 — 멈춘 동안에도 점을 찍어 둘 수 있다');
    end
end

% =====================================================================
function stop_run(fig)
%STOP_RUN  정지하고 측정값을 낸다
    S = getappdata(fig, 'S');
    if is_running(S.model)
        set_param(S.model, 'SimulationCommand', 'stop');
        wait_status(S.model, 'stopped', true, 10);
    end
    set(S.bPause, 'String', '일시정지');
    A2_gui_panel(fig, 'mission');
    A2_gui_panel(fig, 'say', '정지 — 측정값은 명령창에 있다');
    A2_gui_report();
end

% =====================================================================
function tf = is_running(m)
%IS_RUNNING  모델이 돌아가는 중인가 (일시정지도 '돌아가는 중' 으로 본다)
    tf = false;
    try
        tf = bdIsLoaded(m) && ~strcmp(get_param(m, 'SimulationStatus'), 'stopped');
    catch
    end
end

% =====================================================================
function wait_status(m, st, want, t_max)
%WAIT_STATUS  상태가 `st` 와 같아질(want=true) 또는 달라질(want=false) 때까지 기다린다
%
%   SimulationCommand 는 명령을 걸어 두고 바로 돌아온다. 그래서 바로 뒤에서
%   상태를 읽으면 아직 옛 상태다. 무한정 기다리지 않도록 상한을 둔다
    t0 = tic;
    while toc(t0) < t_max
        now = strcmp(get_param(m, 'SimulationStatus'), st);
        if now == want, return; end
        pause(0.05);
    end
    warning('A2:wait', '%.0f s 안에 상태가 바뀌지 않았다 (지금 : %s)', ...
            t_max, get_param(m, 'SimulationStatus'));
end
