function [st, is_vrx, offline] = W06_stage_of(mdl)
% W06_STAGE_OF  모델 이름 -> 단계 번호 · VRX 쌍둥이 여부 · 짝이 되는 오프라인 모델
%
%   [st, is_vrx, offline] = W06_stage_of('W06_5_dock_vrx')   ->  6, true, 'W06_5_dock'
%   [st, is_vrx, offline] = W06_stage_of('W06_1_point_vrx')  ->  1, true, 'W06_1_point'
%   names = W06_stage_of()                                   ->  단계 -> 이름 목록
%
%   단계 번호는 W06_setup 의 model_name 순서다. 접안만 오프라인(5단)과
%   Gazebo 연동(6단)이 따로 번호를 받는다 — 문서와 같은 번호다.
%
%   모델 콜백(W06_model_init · W06_model_done)이 "지금 눌린 모델이 몇 단인가" 를
%   알아내는 데 쓴다. 이름과 단계의 대응은 **이 파일 하나**에만 있다.

name = {'W06_1_point','W06_2_sway','W06_3_thrust','W06_4_stop', ...
        'W06_5_dock', 'W06_5_dock_vrx', 'W06_7_front','W06_8_ned'};

if nargin == 0                            % 목록만 달라는 호출 (W06_vrx_run 이 쓴다)
    st = name;   is_vrx = [];   offline = '';
    return
end

mdl     = char(mdl);
is_vrx  = endsWith(mdl, '_vrx');
offline = mdl;
if is_vrx, offline = mdl(1:end-4); end

st = find(strcmp(name, mdl), 1);          % 이름이 그대로 목록에 있는 단 (6단)
if isempty(st)
    st = find(strcmp(name, offline), 1);  % 쌍둥이 -> 오프라인 이름으로 찾는다
end
if isempty(st)
    error('W06_stage_of:unknown', '%s 는 6주차 모델이 아니다', mdl);
end
end
