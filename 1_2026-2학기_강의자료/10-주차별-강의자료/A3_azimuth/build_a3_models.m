function build_a3_models(stages)
% BUILD_A3_MODELS  부록 A3 Simulink 모델을 **단에 따라** 생성한다.
%
%     >> A3_setup
%     >> build_a3_models          % 세 단 전부
%     >> build_a3_models(1)       % 1단만
%     >> build_a3_models(1:2)     % 1~2단
%
%   모델을 손으로 그리지 않는다. 학생이 마음껏 만져 보고 이 한 줄로 되돌린다.
%
%     1  A3_1_crab    순수 횡이동 — 아지무스 배분 + 각도·추력 한계
%     2  A3_2_pose    도착 판정과 정지 게이트 (위치·선수각 유지)
%     3  A3_3_dock    단계 전이 접안 (6주차 5단과 같은 과업)
%
%   가제보 쌍둥이는 **아직 만들지 않는다.** 오프라인 결과를 먼저 확인한 뒤의
%   다음 단계다 (강의자료 3부).
%
%   6주차와 공유하는 것 · 새로 만든 것
%     그대로 가져온 것  바깥 고리 · 유도부 셋 · 로깅/스코프/자동정지 상자
%     힘 입구만 바꾼 것 운동모델 (FL·FR·FB -> X·Y·N)
%     새로 만든 것      안쪽 고리의 출구 (요구 힘·모멘트) + **Alloc 상자 하나**
%
%   한 단을 어떻게 만드는지는 parts/buildA3Stage<N>.m 에 있다.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', '..', '_tools'));
    addpath(fullfile(here, 'parts'));
    addpath(here);
    cd(here);

    if evalin('base', '~exist(''stage'',''var'')')
        error('먼저 A3_setup 을 실행하십시오.');
    end
    if nargin < 1, stages = 1:3; end

    name = {'A3_1_crab','A3_2_pose','A3_3_dock'};

    for s = stages(:)'
        m  = name{s};
        bs = str2func(sprintf('buildA3Stage%d', s));
        [chain, boxes] = bs(m);
        n = finishA3(m, chain, boxes);
        fprintf('  %-12s  생성 완료 — check_lines 지적 %d건\n', m, n);
    end

    %  강의자료가 쓰는 서브시스템 도면 — 가장 높은 단에서 뽑는다 (블록이 다 있다)
    if ~exist(fullfile(here,'img'),'dir'), mkdir(fullfile(here,'img')); end
    top = name{max(stages)};
    load_system(top);
    for nm = {'Guidance','OuterLoop','InnerLoop','Alloc','MotionModel'}
        if isempty(find_system(top, 'SearchDepth',1, 'Name',nm{1})), continue; end
        f = export_diagram(top, '', nm{1});
        movefile(f, fullfile(here, 'img', [nm{1} '.png']), 'f');
    end
    close_system(top, 0);

    fprintf('\n완료. 생성된 모델:\n');
    d = dir('A3_*.slx');
    for k = 1:numel(d), fprintf('  %s\n', d(k).name); end
end
