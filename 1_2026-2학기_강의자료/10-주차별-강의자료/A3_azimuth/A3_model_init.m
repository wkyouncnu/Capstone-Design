function A3_model_init(mdl)
% A3_MODEL_INIT  Simulink 에서 모델을 직접 Run 했을 때 설정을 스스로 깐다
%
%   모델의 InitFcn 이 부른다 (A3_set_callbacks 가 심는다). 학생이 .slx 를 열어
%   Run 만 눌러도 그 모델의 단 설정이 들어가므로, "먼저 A3_setup 을 돌려야
%   한다" 를 기억하지 않아도 된다.
%
%   하는 일
%     (1) 베이스 워크스페이스의 out 을 지운다 — StopFcn 이 "직접 Run" 과
%         "m 파일의 sim()" 을 구별하는 표식이다. sim() 은 끝난 뒤에야 out 을
%         만들므로, StopFcn 이 돌 때 out 이 없으면 직접 Run 이다
%     (2) 이미 이 모델 설정이 깔려 있으면 다시 깔지 않는다 (시간 낭비)
%     (3) 아니면 A3_setup 을 **실행 없이** 불러 변수만 깐다

mdl = char(mdl);
st  = A3_stage_of(mdl);

evalin('base', 'clear out');

cfg_laid = isequal(getappdata(0,'A3_cfg_for'), mdl) && ...
           evalin('base', ['exist(''T_run'',''var'') && ' ...
                           'exist(''task_mode'',''var'') && ' ...
                           'exist(''az_prm'',''var'')']) == 1;
if cfg_laid, return; end

setappdata(0, 'A3_stage', st);
setappdata(0, 'A3_skip_run', true);
evalin('base', 'A3_setup');
setappdata(0, 'A3_cfg_for', mdl);
end
