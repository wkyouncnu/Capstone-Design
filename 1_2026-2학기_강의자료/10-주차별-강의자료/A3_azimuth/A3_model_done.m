function A3_model_done(mdl)
% A3_MODEL_DONE  Simulink 에서 직접 Run 한 결과를 그림과 지표로 낸다
%
%   모델의 StopFcn 이 부른다 (A3_set_callbacks 가 심는다).
%
%   m 파일의 sim() 으로 돌린 경우에는 **아무것도 하지 않는다**
%     sim() 은 끝난 뒤에 out 을 돌려주고, 부른 스크립트가 직접 A3_plot 을
%     부른다. 여기서 또 그리면 같은 그림을 두 번 그리게 된다.
%     구별은 베이스 워크스페이스의 out 하나로 한다 — InitFcn 이 지워 두었으므로,
%     StopFcn 이 도는 시점에 out 이 있으면 "직접 Run (To Workspace 가 채운 것)",
%     없으면 "sim() 호출" 이다.

mdl = char(mdl);
st  = A3_stage_of(mdl);

%  녹화를 먼저 닫는다 — mp4 는 닫지 않으면 재생되지 않는다. 아래 그림 그리기
%  보다 **앞**에 두어야, sim() 으로 돌린 경우(바로 return)와 그림에서 오류가
%  난 경우에도 영상이 온전히 남는다. 녹화를 켜지 않았으면 아무 일도 하지 않는다
try, A3_animate('close'); catch, end

if evalin('base', 'exist(''out'',''var'')') ~= 1
    return                                  % sim() 으로 돌린 것 — 부른 쪽이 그린다
end

out  = evalin('base', 'out');
name = evalin('base', 'stage_name');
S    = A3_plot(out, sprintf('%d단 — %s  (Simulink 직접 Run)', st, name{st}));
assignin('base', 'S', S);
end
