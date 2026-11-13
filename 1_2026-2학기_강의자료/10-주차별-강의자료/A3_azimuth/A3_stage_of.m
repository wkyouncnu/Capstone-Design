function [st, is_vrx, offline] = A3_stage_of(mdl)
% A3_STAGE_OF  모델 이름 -> 단 번호 · 가제보 연동 여부 · 짝이 되는 오프라인 모델
%
%   [st, is_vrx, offline] = A3_stage_of('A3_1_crab')   ->  1, false, 'A3_1_crab'
%   [st, is_vrx, offline] = A3_stage_of('A3_4_vrx')    ->  4, true,  'A3_2_pose'
%   [st, is_vrx, offline] = A3_stage_of('A3_2_pose_vrx') -> 2, true, 'A3_2_pose'
%   names = A3_stage_of()                              ->  단 -> 이름 목록
%
%   단 번호는 A3_setup 의 model_name 순서다. 이름과 단의 대응은 **이 파일
%   하나**에만 있다 — 모델 콜백(A3_model_init · A3_model_done)이 "지금 눌린
%   모델이 몇 단인가" 를 알아내는 데 쓴다.
%
%   이름을 찾는 순서
%     (1) 목록에 **그대로** 있는 이름인가       — A3_4_vrx · A3_5_tilt 가 여기
%     (2) '_vrx' 꼬리를 뗀 이름이 목록에 있는가 — 6주차의 쌍둥이 이름 규칙
%
%   4단과 5단은 **한 모델이 목표를 바꿔 가며** 세 과업을 다 돌린다 (A3_setup
%   의 vrx_target). 그래서 과업 이름이 모델 이름에 들어 있지 않다.

name = {'A3_1_crab','A3_2_pose','A3_3_dock','A3_4_vrx','A3_5_tilt'};

if nargin == 0                            % 목록만 달라는 호출
    st = name;   is_vrx = [];   offline = '';
    return
end

mdl = char(mdl);

st = find(strcmp(name, mdl), 1);          % (1) 목록에 그대로 있는 이름
if ~isempty(st)
    is_vrx = st >= 4;                     % 4·5단은 가제보가 있어야 돈다
    if st == 4
        offline = 'A3_2_pose';            % 대조할 오프라인 쌍둥이
    elseif st == 5
        offline = '';                     % 서보 확인 — 오프라인 짝이 없다
    else
        offline = mdl;
    end
    return
end

is_vrx  = endsWith(mdl, '_vrx');          % (2) '_vrx' 꼬리를 뗀 짝
offline = mdl;
if is_vrx, offline = mdl(1:end-4); end

st = find(strcmp(name, offline), 1);
if isempty(st)
    error('A3_stage_of:unknown', '%s 는 부록 A3 모델이 아니다', mdl);
end
end
