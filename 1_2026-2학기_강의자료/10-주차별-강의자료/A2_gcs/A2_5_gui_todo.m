function fig = A2_5_gui_todo()
%A2_5_GUI_TODO  5단 — 버튼 달린 GCS 화면 (빈칸본)
%
%   >> A2_5_gui_todo
%
%   빈칸 세 군데를 채우면 돌아간다. 채우기 전에 돌리면 어디가 비었는지 알려 준다
%
%   | 빈칸 | 어느 함수 | 무엇을 쓰는가 |
%   |------|-----------|---------------|
%   | 1    | `add_point`    | 클릭한 위경도 -> NED, 고정 길이 버퍼의 빈 칸에 넣기 |
%   | 2    | `push_mission` | 바뀐 값을 실행 중인 모델에 반영 |
%   | 3    | `start_run` 외 | 버튼 -> `SimulationCommand` |
%
%   막히면 `A2_5_gui_done.m` 을 열어 본다. 베끼기 전에 **왜 그 줄이 필요한지**
%   먼저 읽을 것 — 세 빈칸은 전부 "빼먹어도 오류가 안 나는" 자리다
%
%   쓰는 순서
%     1. '웨이포인트 찍기' 를 누른다 (눌린 상태로 둔다)
%     2. 위성지도를 눌러 점을 찍는다 (최대 WP_MAX 개)
%     3. '출발' — 배가 1 번 점을 향해 떠난다
%     4. 가는 중에 지도를 더 눌러 본다 — 경로가 늘어나고 배가 따라간다
%     5. '정지' — 멈추고 측정값이 명령창에 표로 나온다

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

%  실시간 페이싱 — 시뮬레이션 1 초를 벽시계 1 초에 맞춘다
set_param(m, 'EnablePacing', 'on', 'PacingRate', '1');

%  멈출 때 베이스 워크스페이스에 `out` 으로 로그를 내려 달라고 걸어 둔다
set_param(m, 'ReturnWorkspaceOutputs', 'on', ...
             'ReturnWorkspaceOutputsName', 'out');

%% ====================================================================
%  3. 창 — 버튼과 클릭은 모두 아래의 on_action 으로 들어온다
% =====================================================================
fig = A2_gui_panel(@on_action);

fprintf('\n=== 5단 · 버튼 GCS (빈칸본) ===\n');
fprintf('  빈칸 3 군데를 채운 뒤 다시 돌릴 것\n\n');
end

% =====================================================================
function on_action(fig, what, varargin)
%ON_ACTION  창에서 올라온 모든 사건을 한자리에서 받는다
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
%ADD_POINT  지도에서 누른 한 점을 임무에 더한다
    S = getappdata(fig, 'S');

    wpx = evalin('base', 'wp_north');
    wpy = evalin('base', 'wp_east');
    n   = double(evalin('base', 'n_wp'));

    if n >= S.WP_MAX
        A2_gui_panel(fig, 'say', sprintf( ...
            '자리가 찼다 (WP_MAX = %d). 지우고 다시 찍을 것', S.WP_MAX));
        return
    end

    % ================= 빈칸 1 =================
    %  누른 자리의 위경도(lat, lon)를 기준점 S.lla0 기준의 NED 로 내리고,
    %  고정 길이 버퍼 wpx·wpy 의 **n+1 번째 칸**에 북·동 값을 넣을 것
    %
    %  힌트
    %    - 변환은 `lla2ned([위도 경도 고도], 기준점, 'flat')`.
    %      세 번째 인자 'flat' 은 생략할 수 없다. 고도는 0 을 쓴다
    %    - 돌려받는 d 는 1x3 = [북 동 아래]. 필요한 것은 d(1), d(2)
    %    - **배열을 늘리지 않는다.** `wpx(end+1) = ...` 로 쓰면 길이가 바뀌고,
    %      실행 중이면 Simulink 가 거부한다 (`Simulink:Parameters:InvParamSetting`)
    %
    %  아래 error 줄을 지우고 세 줄을 쓸 것 (d = ... / wpx(...) = ... / wpy(...) = ...)
    error('A2:todo', ['빈칸 1 — add_point : 위경도를 NED 로 내려 버퍼 %d 번 칸에 ' ...
                      '넣는 코드를 쓸 것'], n+1);
    % ==========================================

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
%PUSH_MISSION  바뀐 임무를 모델에 밀어 넣는다
%
%   베이스 워크스페이스의 세 변수가 임무의 **유일한 원본**이다.
%   창은 그것을 비추기만 한다 (같은 값을 두 군데에 두지 않는다)

    S = getappdata(fig, 'S');

    assignin('base', 'wp_north', wpx);
    assignin('base', 'wp_east',  wpy);
    assignin('base', 'n_wp',     n);

    % ================= 빈칸 2 =================
    %  위의 assignin 세 줄은 **베이스 워크스페이스**만 고친다.
    %  돌아가는 모델은 그것을 다시 읽지 않으므로 **옛 웨이포인트로 계속 간다.**
    %  모델이 Constant 블록 값을 다시 읽게 만드는 한 줄을 쓸 것
    %
    %  힌트
    %    - `set_param(모델이름, 'SimulationCommand', '....')`
    %    - 모델 이름은 S.model 에 있다
    %    - 명령 이름은 '값을 갱신하라' 는 뜻의 영어 한 단어
    %    - 돌아가는 중이 아닐 때 보내면 오류가 난다 -> `if is_running(S.model)` 안에 둔다
    %
    %  이 빈칸은 **빼먹어도 오류가 나지 않는다.** 그래서 틀린 것을 알아채기 어렵다.
    %  채우기 전에 한 번 돌려 보면 배가 옛 점으로 가는 것을 눈으로 볼 수 있다
    warning('A2:todo', '빈칸 2 — push_mission : 모델에 값 갱신을 알리는 한 줄이 비었다');
    % ==========================================

    A2_gui_panel(fig, 'mission');       % 계획 경로를 다시 그린다
end

% =====================================================================
function start_run(fig)
%START_RUN  출발
    S = getappdata(fig, 'S');
    if is_running(S.model)
        A2_gui_panel(fig, 'say', '이미 돌아가는 중이다');
        return
    end

    A2_animate_gui('reset');            % 항적과 그래프 버퍼를 비운다

    % ================= 빈칸 3-1 =================
    %  모델을 **기다리지 않고** 출발시킬 것
    %
    %  힌트
    %    - `sim()` 을 쓰면 끝날 때까지 MATLAB 이 막혀 버튼을 누를 수 없다
    %    - `set_param(S.model, 'SimulationCommand', '....')` 는 명령만 걸고 바로 돌아온다
    %    - 명령 이름은 '시작' 을 뜻하는 영어 한 단어
    error('A2:todo', '빈칸 3-1 — start_run : 모델을 출발시키는 한 줄을 쓸 것');
    % ============================================

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

    % ================= 빈칸 3-2 =================
    %  지금 상태를 보고 '일시정지' 와 '계속' 을 번갈아 보낼 것.
    %  버튼의 글자(S.bPause 의 'String')도 같이 바꿔 준다
    %
    %  힌트
    %    - 지금 멈춘 상태인가 : `strcmp(get_param(S.model,'SimulationStatus'), 'paused')`
    %    - 보낼 명령은 각각 영어 한 단어 ('멈춤' / '이어서')
    %    - 글자 바꾸기 : `set(S.bPause, 'String', '계속')`
    error('A2:todo', '빈칸 3-2 — toggle_pause : 일시정지와 계속을 번갈아 보낼 것');
    % ============================================
end

% =====================================================================
function stop_run(fig)
%STOP_RUN  정지하고 측정값을 낸다
    S = getappdata(fig, 'S');
    if is_running(S.model)

        % ================= 빈칸 3-3 =================
        %  모델을 멈출 것. 멈춘 **뒤에** 로그(`out`)가 베이스 워크스페이스에 생기므로,
        %  바로 측정하지 않고 `wait_status(S.model, 'stopped', true, 10)` 로 기다린 뒤
        %  아래로 내려가게 한다
        %
        %  힌트 : 보낼 명령은 '정지' 를 뜻하는 영어 한 단어
        error('A2:todo', '빈칸 3-3 — stop_run : 모델을 멈추고 stopped 를 기다릴 것');
        % ============================================

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
