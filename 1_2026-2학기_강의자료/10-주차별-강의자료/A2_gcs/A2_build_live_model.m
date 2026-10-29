function dst = A2_build_live_model(force)
%A2_BUILD_LIVE_MODEL  4단 모델 `A2_live.slx` 를 5주차 모델에서 파생시킨다
%
%   dst = A2_BUILD_LIVE_MODEL        % 없으면 만든다
%   dst = A2_BUILD_LIVE_MODEL(true)  % 있어도 다시 만든다
%
%   무엇을 하는가
%     1. `W05_simulink/W05_0_offline.slx` 를 메모리로 올린다
%     2. 이름만 바꿔 `A2_gcs/A2_live.slx` 로 저장한다 (원본 파일은 건드리지 않는다)
%     3. Animate 블록이 부르는 그림 함수를 `W05_animate` -> `A2_animate_map` 으로 바꾼다
%
%   왜 모델을 새로 그리지 않는가
%     - 유도·제어·추진기·운동모델은 5주차에서 이미 검증한 것이다
%     - 4단에서 달라지는 것은 **화면**뿐이다. 블록 하나 게인 하나 바뀌지 않는다
%     - 그래서 제어 성능을 다시 의심할 필요가 없다. 바뀐 자리가 한 군데로 좁혀진다
%
%   되돌리는 법
%     파일을 지우고 다시 부르면 된다. 학생이 모델을 마음껏 고쳐 봐도
%     `>> A2_build_live_model(true)` 한 줄로 처음 상태가 된다

    if nargin < 1, force = false; end

    here = fileparts(mfilename('fullpath'));
    src  = fullfile(fileparts(here), 'W05_simulink', 'W05_0_offline.slx');
    dst  = fullfile(here, 'A2_live.slx');

    if ~isfile(src)
        error('A2:nosrc', '5주차 모델을 찾지 못했다 : %s', src);
    end

    if isfile(dst) && ~force
        fprintf('A2_live.slx 이미 있음 — 다시 만들려면 A2_build_live_model(true)\n');
        return
    end

    SRC = 'W05_0_offline';
    DST = 'A2_live';

    % --- 열려 있는 모델 정리 -----------------------------------------
    %  저장하지 않은 변경을 말없이 버리지 않는다
    if bdIsLoaded(DST)
        if strcmp(get_param(DST, 'Dirty'), 'on')
            error('A2:dirty', '%s 에 저장하지 않은 변경이 있다. 먼저 저장하거나 닫을 것', DST);
        end
        close_system(DST, 0);
    end
    if bdIsLoaded(SRC)
        if strcmp(get_param(SRC, 'Dirty'), 'on')
            error('A2:dirty', '%s 에 저장하지 않은 변경이 있다. 먼저 저장하거나 닫을 것', SRC);
        end
        close_system(SRC, 0);
    end

    % --- 1. 올리고 이름만 바꿔 저장 ----------------------------------
    fprintf('5주차 모델을 올린다 : %s\n', src);
    load_system(src);
    save_system(SRC, dst);          % 원본 .slx 파일은 그대로 남는다

    %  save_system 뒤 메모리에 남은 이름은 MATLAB 판본에 따라 다르다.
    %  둘 중 올라와 있는 것을 쓴다 (추측하지 않는다)
    if bdIsLoaded(DST)
        m = DST;
    else
        m = SRC;
    end

    % --- 2. 그림 함수 교체 -------------------------------------------
    %  Animate 서브시스템 안의 MATLAB Function 블록이 `coder.extrinsic` 으로
    %  선언한 함수 이름을 바꾼다. 포트도 신호도 그대로다
    charts = sfroot().find('-isa', 'Stateflow.EMChart');
    hit    = 0;
    for k = 1:numel(charts)
        p = charts(k).Path;
        if contains(p, [m '/Animate'])
            s = charts(k).Script;
            if contains(s, 'W05_animate')
                charts(k).Script = strrep(s, 'W05_animate', 'A2_animate_map');
                hit = hit + 1;
                fprintf('그림 함수 교체 : %s\n', p);
            end
        end
    end
    if hit ~= 1
        error('A2:animate', ...
              'Animate 블록의 그림 함수를 %d 군데 바꿨다 (1 이어야 한다)', hit);
    end

    %  설명 메모도 같이 고친다 — 학생이 모델을 열고 읽는 글이다
    nt = find_system(m, 'SearchDepth', 2, 'FindAll', 'on', ...
                     'type', 'annotation');
    for k = 1:numel(nt)
        txt = get_param(nt(k), 'Text');
        if contains(txt, 'W05_animate')
            set_param(nt(k), 'Text', strrep(txt, 'W05_animate', 'A2_animate_map'));
        end
    end

    % --- 3. 저장하고 닫는다 ------------------------------------------
    save_system(m, dst);
    close_system(m, 0);

    fprintf('만들었다 : %s\n', dst);
end
