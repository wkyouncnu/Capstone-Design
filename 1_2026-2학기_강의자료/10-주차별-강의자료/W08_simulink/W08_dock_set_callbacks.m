function W08_dock_set_callbacks(mdl)
% W08_DOCK_SET_CALLBACKS  모델에 InitFcn · StopFcn 을 심는다. 저장은 부른 쪽의 일이다.
%
%   빌더가 모델마다 한 번 부른다 (6주차 W06_set_callbacks 와 같은 구실).
%   덕분에 학생이 .slx 를 탐색기에서 두 번 눌러 열고 Run 만 눌러도
%   설정이 깔리고 실시간 창이 미리 선다.
%
%   InitFcn 문자열에 addpath 가지가 붙어 있는 이유
%     탐색기에서 .slx 를 두 번 누르면 MATLAB 의 현재 폴더가 다른 곳일 수 있다.
%     그러면 Run 이 W08_dock_init 을 찾지 못해 멈춘다. 모델 파일이 있는 폴더를
%     스스로 경로에 더해 그 고장을 없앤다.

mdl = char(mdl);
init = sprintf(['if ~exist(''W08_dock_init'',''file''), ' ...
                'addpath(fileparts(get_param(''%s'',''FileName''))); end, ' ...
                'W08_dock_init(''%s'')'], mdl, mdl);
stop = sprintf('W08_dock_done(''%s'')', mdl);

load_system(mdl);
set_param(mdl, 'InitFcn', init, 'StopFcn', stop);
end
