function build_w06_models(stages)
% BUILD_W06_MODELS  6주차 Simulink 모델을 **단계별로** 생성한다.
%
%     >> W06_setup
%     >> build_w06_models            % 여덟 단계 전부
%     >> build_w06_models(1)         % 1단만
%     >> build_w06_models(1:3)       % 1~3단
%
%   쉬운 모델부터 하나씩 쌓는다. 한 단계에 새로 생기는 것은 하나뿐이다.
%
%     1  W06_1_point    위치 고리 + 속도 고리 + 선수각 고리 + 추력배분
%     2  W06_2_sway     선수추진기 on/off 스위치 (순수 횡이동)
%     3  W06_3_thrust   추진기 동역학 (추력<->회전수, 모터 지연, 포화)
%     4  W06_4_stop     도착 판정과 정지 게이트
%     5  W06_5_dock     단계 전이 (접근 -> 선수각 정렬 -> 횡이동 접안)
%     6  W06_6_vrx      Gazebo 연동 (운동모델만 실물로 바뀐다)
%     7  W06_7_front    전진 접안 (bow-first)
%     8  W06_8_ned      NED 좌표계 위치제어 접안
%
%   5주차와 달라진 것 하나 — 추진기가 셋이다 (선수추진기 추가)
%
%     5주차 : 추진기 2개 -> 낼 수 있는 것은 X(전후) 와 N(요) 둘.
%             횡방향으로는 힘을 못 내므로 "경로를 따라간다" 까지만 된다
%     6주차 : 추진기 3개 -> X · Y(횡) · N 셋을 독립으로 낸다. 그래서
%             **정해진 위치에 정해진 선수각으로 서 있기**가 비로소 된다
%
%   한 단계를 어떻게 만드는지는 parts/buildStage<N>.m 에 있다. 블록 좌표와
%   서브시스템 속은 모두 parts/ 안이고, 이 파일은 **무엇을 만드는지**만 보인다.
%
%   모델이 깨졌을 때 이 스크립트를 다시 돌리면 복구된다.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    addpath(fullfile(here, 'parts'));
    cd(here);

    if evalin('base', '~exist(''stage'',''var'')')
        error('먼저 W06_setup 을 실행하십시오.');
    end
    if nargin < 1, stages = 1:8; end

    name = {'W06_1_point','W06_2_sway','W06_3_thrust','W06_4_stop', ...
            'W06_5_dock', 'W06_6_vrx', 'W06_7_front','W06_8_ned'};

    for s = stages(:)'
        m  = name{s};
        bs = str2func(sprintf('buildStage%d', s));
        [chain, boxes] = bs(m);
        n = finishStage(m, chain, boxes);
        fprintf('  %-14s  생성 완료 — check_lines 지적 %d건\n', m, n);
    end

    %  강의노트가 쓰는 서브시스템 도면 (img/Guidance.png 등)
    %    선체고정 사슬(1~7단) 가운데 **가장 높은 단계**의 것을 쓴다 — 그 단계가
    %    모든 블록을 다 가지고 있기 때문이다. 8단은 제어 좌표계가 달라 고리 둘의
    %    속이 아예 다르므로 섞지 않고 OuterLoopNED · InnerLoopNED 로 따로 뽑는다
    %    (8단의 유도부·추진기·운동모델은 5단과 같은 그림이다)
    shots = cell(0,3);
    %    6단은 빼 둔다 — 그 단계의 플랜트가 Gazebo 라 MotionModel 이 없고, 사슬
    %    끝이 CmdPublisher · PoseSubscriber 다. 서브시스템 도면은 선체고정 사슬이
    %    모두 들어 있는 7단에서 뽑는다 (6단의 유도부·고리·추진기는 5단과 같은 그림)
    body  = stages(stages <= 7 & stages ~= 6);
    if ~isempty(body)
        shots = [shots; {name{max(body)}, '', ...
                 {'OuterLoop','InnerLoop','Thrusters','MotionModel'}}];
    end
    %    Guidance 만 5단에서 뽑는다 — 7단의 유도부는 더 큰 것이 아니라 **다른**
    %    것이다 (addGuidanceFront). 5·8단이 쓰는 세 단계 접안 유도부가 강의노트가
    %    설명하는 그림이므로 그것을 쓴다. 5단이 빠진 호출에서는 있는 단계로 뽑는다
    if any(stages == 5)
        shots = [shots; {'W06_5_dock', '', {'Guidance'}}];
    elseif ~isempty(body) && ~any(stages == 7)
        shots = [shots; {name{max(body)}, '', {'Guidance'}}];
    end
    %    7단의 유도부는 GuidanceFront.png 로 따로 뽑는다 — 입력에 속도 u·v 가
    %    더 있고, gate 가 0/1 이 아니라 감속 계수다. 강의노트 E-1 이 쓰는 그림이다
    if any(stages == 7)
        shots = [shots; {'W06_7_front', 'Front', {'Guidance'}}];
    end
    if any(stages == 8)
        shots = [shots; {'W06_8_ned', 'NED', {'OuterLoop','InnerLoop'}}];
    end
    if ~exist(fullfile(here,'img'),'dir'), mkdir(fullfile(here,'img')); end

    for c = 1:size(shots,1)
        top = shots{c,1};   sfx = shots{c,2};
        load_system(top);
        for nm = shots{c,3}
            if isempty(find_system(top, 'SearchDepth',1, 'Name',nm{1})), continue; end
            f = export_diagram(top, '', nm{1});
            movefile(f, fullfile(here, 'img', [nm{1} sfx '.png']), 'f');
        end
        close_system(top, 0);
    end

    fprintf('\n완료. 생성된 모델:\n');
    d = dir('W06_*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
end
