function dst = A2_build_gui_model(force)
%A2_BUILD_GUI_MODEL  5단 모델 `A2_gui.slx` 를 5주차 모델에서 파생시킨다
%
%   dst = A2_BUILD_GUI_MODEL        % 없으면 만든다
%   dst = A2_BUILD_GUI_MODEL(true)  % 있어도 다시 만든다
%
%   4단 모델(`A2_live.slx`) 과 무엇이 다른가
%     4단은 화면만 바꿨다. 5단은 **실행 중에 임무가 바뀐다.** 그래서 세 군데를 고친다
%
%       1. 그림 함수      `W05_animate` -> `A2_animate_gui`
%                         (GUI 창에 이미 있는 축에 그린다. 창을 스스로 만들지 않는다)
%       2. 웨이포인트 개수 `GuidanceLaw` 에 열째 입력 `n_wp` 를 더한다
%                         배열 길이가 아니라 이 값이 "유효한 점이 몇 개인가" 를 말한다
%       3. 자동 정지      `AutoStop` 을 주석 처리해 끈다
%                         임무가 끝나도 창이 살아 있어야 점을 더 찍을 수 있다
%
%   왜 열째 입력이 필요한가 — 실측으로 확인한 제약
%     Simulink 는 실행 중에 Constant 블록의 **값**은 바꿔 주지만
%     **배열 길이**는 바꿔 주지 않는다. 길이를 바꾸면 이렇게 거부한다
%
%       Simulink:Parameters:InvParamSetting
%       'A2_gui/Guidance/wp_x'에서 파라미터 'Value'에 대한 설정이 유효하지 않습니다
%
%     그래서 웨이포인트 배열은 **고정 길이 WP_MAX** 로 두고, 그중 몇 개가 쓸모
%     있는 점인지를 `n_wp` 라는 스칼라로 따로 넘긴다. 점을 하나 찍으면 배열의
%     내용과 `n_wp` 가 바뀌고, 길이는 그대로다 — 그래서 실행 중에 반영된다
%
%   5주차 원본 파일은 건드리지 않는다. 되돌리려면 지우고 다시 부른다
%     >> A2_build_gui_model(true)

    if nargin < 1, force = false; end

    here = fileparts(mfilename('fullpath'));
    src  = fullfile(fileparts(here), 'W05_simulink', 'W05_0_offline.slx');
    dst  = fullfile(here, 'A2_gui.slx');

    if ~isfile(src)
        error('A2:nosrc', '5주차 모델을 찾지 못했다 : %s', src);
    end

    if isfile(dst) && ~force
        fprintf('A2_gui.slx 이미 있음 — 다시 만들려면 A2_build_gui_model(true)\n');
        return
    end

    SRC = 'W05_0_offline';
    DST = 'A2_gui';

    % --- 열려 있는 모델 정리 -----------------------------------------
    %  저장하지 않은 변경을 말없이 버리지 않는다
    for nm = {DST, SRC}
        if bdIsLoaded(nm{1})
            if strcmp(get_param(nm{1}, 'Dirty'), 'on')
                error('A2:dirty', ...
                      '%s 에 저장하지 않은 변경이 있다. 먼저 저장하거나 닫을 것', nm{1});
            end
            close_system(nm{1}, 0);
        end
    end

    % --- 1. 올리고 이름만 바꿔 저장 ----------------------------------
    fprintf('5주차 모델을 올린다 : %s\n', src);
    load_system(src);
    save_system(SRC, dst);          % 원본 .slx 파일은 그대로 남는다

    %  save_system 뒤 메모리에 남은 이름은 MATLAB 판본에 따라 다르다.
    %  둘 중 올라와 있는 것을 쓴다 (추측하지 않는다)
    if bdIsLoaded(DST), m = DST; else, m = SRC; end

    % --- 2. 그림 함수 교체 -------------------------------------------
    hit = swap_chart_fcn([m '/Animate'], 'W05_animate', 'A2_animate_gui');
    if hit ~= 1
        error('A2:animate', ...
              'Animate 블록의 그림 함수를 %d 군데 바꿨다 (1 이어야 한다)', hit);
    end

    % --- 3. GuidanceLaw 에 열째 입력 n_wp 를 더한다 -------------------
    add_nwp_input(m);

    % --- 4. AutoStop 을 끈다 -----------------------------------------
    %  임무가 끝나면 gate 가 0 이 되어 배는 멈춘다. 거기서 모델까지 멈추면
    %  창이 닫히고 점을 더 찍을 수 없다. GCS 는 임무가 끝나도 계속 떠 있다
    set_param([m '/AutoStop'], 'Commented', 'on');
    fprintf('AutoStop 을 껐다 — 임무가 끝나도 모델은 계속 돈다 (정지는 버튼으로)\n');

    % --- 5. 설명 메모도 같이 고친다 — 학생이 모델을 열고 읽는 글이다 --
    nt = find_system(m, 'SearchDepth', 2, 'FindAll', 'on', 'type', 'annotation');
    for k = 1:numel(nt)
        txt = get_param(nt(k), 'Text');
        if contains(txt, 'W05_animate')
            set_param(nt(k), 'Text', strrep(txt, 'W05_animate', 'A2_animate_gui'));
        end
    end

    % --- 6. 저장하고 닫는다 ------------------------------------------
    save_system(m, dst);
    close_system(m, 0);

    fprintf('만들었다 : %s\n', dst);
end

% =====================================================================
function hit = swap_chart_fcn(under, oldName, newName)
%SWAP_CHART_FCN  `under` 아래의 MATLAB Function 블록에서 함수 이름을 바꾼다
%   바꾼 자리의 개수를 돌려준다. 1 이 아니면 부른 쪽에서 오류를 낸다
    charts = sfroot().find('-isa', 'Stateflow.EMChart');
    hit    = 0;
    for k = 1:numel(charts)
        p = charts(k).Path;
        if contains(p, under)
            s = charts(k).Script;
            if contains(s, oldName)
                charts(k).Script = strrep(s, oldName, newName);
                hit = hit + 1;
                fprintf('그림 함수 교체 : %s\n', p);
            end
        end
    end
end

% =====================================================================
function add_nwp_input(m)
%ADD_NWP_INPUT  GuidanceLaw 에 열째 입력 `n_wp` 를 더하고 Constant 를 붙인다
%
%   5주차 유도 코드를 **베껴 쓰지 않는다.** 올라와 있는 코드를 읽어
%   두 군데만 바꾼다. 바뀐 자리가 두 줄로 좁혀지므로 5주차에서 검증한
%   유도 법칙이 그대로 살아 있음을 눈으로 확인할 수 있다

    g    = [m '/Guidance'];
    blk  = [g '/GuidanceLaw'];

    charts = sfroot().find('-isa', 'Stateflow.EMChart');
    ch     = [];
    for k = 1:numel(charts)
        if strcmp(charts(k).Path, blk), ch = charts(k); break; end
    end
    if isempty(ch)
        error('A2:noguidance', '유도 블록을 찾지 못했다 : %s', blk);
    end

    s = ch.Script;

    % --- (1) 함수 머리에 인자 하나를 더한다 ---------------------------
    oldSig = 'sw_mode, idx_prev)';
    newSig = 'sw_mode, idx_prev, n_wp)';
    if count(s, oldSig) ~= 1
        error('A2:sig', '유도 함수 머리를 %d 군데 찾았다 (1 이어야 한다)', count(s, oldSig));
    end
    s = strrep(s, oldSig, newSig);

    % --- (2) 유효 개수를 배열 길이가 아니라 n_wp 에서 읽는다 ----------
    oldN = sprintf('n = numel(wp_x);');
    if count(s, oldN) ~= 1
        error('A2:nline', '유효 개수 줄을 %d 군데 찾았다 (1 이어야 한다)', count(s, oldN));
    end
    newN = strjoin({ ...
        '% A2 5단 : 배열은 고정 길이(WP_MAX)이고, 그중 앞 n_wp 개만 유효하다.'
        '% 실행 중에 Simulink 가 바꿔 주는 것은 값뿐이고 길이는 바꿔 주지 않으므로,'
        '% "점이 몇 개인가" 는 배열 길이가 아니라 별도의 스칼라로 들어온다.'
        'n = min(double(n_wp), numel(wp_x));'
        ''
        'if n < 2'
        '    % 아직 갈 구간이 없다 (출발점 하나뿐). k = n-1 = 0 이 되어 색인이'
        '    % 0 이 되는 것을 막는다. 배는 제자리에 선다 (gate = 0)'
        '    psi_ref = 0;  y_e = 0;  x_e = 0;  wp_idx = 1;  gate = 0;'
        '    return'
        'end'}, newline);
    s = strrep(s, oldN, newN);

    ch.Script = s;

    % --- (3) 열째 입력 포트에 Constant 를 붙인다 ----------------------
    %  Script 를 고치면 블록의 포트 수가 따라서 늘어난다
    ph = get_param(blk, 'PortHandles');
    if numel(ph.Inport) ~= 10
        error('A2:ports', '유도 블록 입력이 %d 개다 (10 이어야 한다)', numel(ph.Inport));
    end
    p = get_param(ph.Inport(10), 'Position');      % [x y] — 포트의 자리

    c = [g '/n_wp_c'];
    add_block('simulink/Sources/Constant', c, 'Value', 'n_wp', ...
              'Position', [p(1)-200 p(2)-15 p(1)-130 p(2)+15]);
    set_param(c, 'Description', ...
        ['유효한 웨이포인트 개수. 배열 길이가 아니다 — 실행 중에 Simulink 가 ' ...
         '배열 길이는 바꿔 주지 않으므로, 점을 더 찍으면 이 값이 늘어난다.']);

    %  Constant 의 출력 포트 높이가 입력 포트 높이와 같으므로 선은 직선 한 토막이다
    add_line(g, 'n_wp_c/1', 'GuidanceLaw/10');

    fprintf('유도 블록에 열째 입력 n_wp 를 더했다 (Constant : %s)\n', c);
end
