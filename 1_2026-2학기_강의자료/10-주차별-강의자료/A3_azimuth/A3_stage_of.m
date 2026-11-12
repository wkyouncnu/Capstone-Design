function [st, is_vrx, offline] = A3_stage_of(mdl)
% A3_STAGE_OF  모델 이름 -> 단 번호 · VRX 쌍둥이 여부 · 짝이 되는 오프라인 모델
%
%   [st, is_vrx, offline] = A3_stage_of('A3_1_crab')       ->  1, false, 'A3_1_crab'
%   [st, is_vrx, offline] = A3_stage_of('A3_3_dock_vrx')   ->  3, true,  'A3_3_dock'
%   names = A3_stage_of()                                  ->  단 -> 이름 목록
%
%   단 번호는 A3_setup 의 model_name 순서다. 이름과 단의 대응은 **이 파일
%   하나**에만 있다 — 모델 콜백(A3_model_init · A3_model_done)이 "지금 눌린
%   모델이 몇 단인가" 를 알아내는 데 쓴다.
%
%   `_vrx` 꼬리를 미리 받아 둔다. 가제보 쌍둥이는 아직 만들지 않았으나
%   (오프라인 결과를 확인한 뒤의 다음 단계), 이름 규칙은 6주차와 같게 둔다.

name = {'A3_1_crab','A3_2_pose','A3_3_dock'};

if nargin == 0                            % 목록만 달라는 호출
    st = name;   is_vrx = [];   offline = '';
    return
end

mdl     = char(mdl);
is_vrx  = endsWith(mdl, '_vrx');
offline = mdl;
if is_vrx, offline = mdl(1:end-4); end

st = find(strcmp(name, offline), 1);
if isempty(st)
    error('A3_stage_of:unknown', '%s 는 부록 A3 모델이 아니다', mdl);
end
end
