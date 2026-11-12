function A3_set_callbacks(mdl)
% A3_SET_CALLBACKS  모델에 InitFcn · StopFcn 을 심는다 (저장은 부른 쪽이 한다)
%
%   InitFcn  -> A3_model_init   눌린 모델 자신의 단으로 A3_setup 을 돌린다
%   StopFcn  -> A3_model_done   끝나면 결과 그림과 성능 지표를 낸다
%
%   이 두 줄이 "m 파일 결과 ↔ Simulink 직접 Run 결과" 를 같게 만드는 전부다.
%   finishA3 가 모델을 만들 때마다 부르므로 다시 빌드해도 사라지지 않는다.
%
%   콜백이 addpath 를 먼저 하는 까닭
%     탐색기에서 .slx 를 두 번 눌러 열면 MATLAB 의 현재 폴더가 A3_azimuth 가
%     아닐 수 있다. 그러면 A3_model_init 을 못 찾아 Run 이 오류로 멈춘다.

mdl = char(mdl);
A3_stage_of(mdl);                       % 부록 A3 모델이 아니면 여기서 멈춘다

init = sprintf(['if ~exist(''A3_model_init'',''file''), ' ...
                'addpath(fileparts(get_param(''%s'',''FileName''))); end, ' ...
                'A3_model_init(''%s'')'], mdl, mdl);
stop = sprintf('A3_model_done(''%s'')', mdl);

load_system(mdl);
set_param(mdl, 'InitFcn', init, 'StopFcn', stop);
end
