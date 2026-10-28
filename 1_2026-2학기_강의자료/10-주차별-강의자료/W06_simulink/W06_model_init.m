function W06_model_init(mdl)
% W06_MODEL_INIT  모델의 InitFcn — 눌린 모델 **자신의** 설정을 베이스 워크스페이스에 깐다
%
%   Simulink 에서 Run 을 누르면 블록 파라미터를 읽기 전에 이것이 먼저 돈다. 덕분에
%     - 어느 모델을 눌러도 그 모델의 단계로 W06_setup 이 돌고
%     - m 파일로 돌린 것과 직접 Run 한 것이 **같은 그래프**를 낸다
%
%   왜 필요한가 — 2026-10-28 실측
%     이 콜백이 없을 때 모델은 베이스 워크스페이스에 **남아 있던 다른 단계의 설정**을
%     그대로 썼다. 1단을 돌린 뒤 5단 모델을 직접 Run 하면
%       | 경우                    | 끝 위치              | 끝 선수각 | task_mode |
%       | 5단 m 파일              | (40.000, 45.545) m  | 0.00 deg  | 3         |
%       | 5단 직접 Run (1단 잔류) | (31.831, 21.812) m  | 45.00 deg | 1         |
%     배가 선석이 아니라 1단 목표로 가고, task_mode 가 1 이라 W06_animate ·
%     W06_plot 이 부두도 접근점도 없는 1단 장면을 그렸다. 오류 메시지는 없다.
%
%   같은 모델을 연달아 Run 하면 설정을 다시 깔지 않는다
%     - 베이스 워크스페이스에서 손으로 고쳐 둔 게인·목표가 살아 있다
%     - m 파일이 깔아 둔 설정을 덮어쓰지 않는다 (m 파일 결과와 어긋나지 않는다)
%     - 다른 모델을 누르면 그 모델의 설정으로 통째로 바뀐다
%     판단 근거는 W06_setup 이 끝에 남기는 appdata 'W06_cfg_for' 하나다
%
%   실시간 화면도 여기서 **미리** 만들어 둔다. 창 만들기를 첫 스텝에 하면 그
%   동안 모델은 멈춰 있고 Gazebo 는 마지막 추력 명령을 그대로 지킨다 — 4단
%   VRX 에서 모델 시간 0.4 s 사이에 배가 9.4 m 를 갔다 ([[W06_animate]] 머리말).
%
%   VRX 쌍둥이(`*_vrx`)는 설정에 더해 W06_vrx_prep 이 Gazebo 쪽 준비까지 한다.
%   쌍둥이는 **매번** 다시 잰다 — 실험마다 VRX 를 새로 띄우므로 스폰 위치와 RTF 가
%   달라진다.

mdl = char(mdl);
[st, is_vrx] = W06_stage_of(mdl);

%  베이스의 out 을 비워 둔다 — StopFcn 이 "직접 Run 인가 sim() 인가" 를 이것으로 가른다
%  (직접 Run 은 StopFcn 전에 out 을 베이스에 넣어 준다. sim() 은 돌려준 뒤에 넣는다)
evalin('base', 'clear out');

if ~isequal(getappdata(0, 'W06_cfg_for'), mdl)
    fprintf('\n[%s] %d단 설정을 깐다 (InitFcn -> W06_setup)\n', mdl, st);
    setappdata(0, 'W06_stage', st);
    setappdata(0, 'W06_skip_run', true);     % 설정만. W06_setup 이 sim 을 부르면 안 된다
    evalin('base', 'W06_setup');
    setappdata(0, 'W06_cfg_for', mdl);       % 쌍둥이는 W06_setup 이 오프라인 이름을 남긴다
else
    fprintf('\n[%s] %d단 설정이 이미 깔려 있다 — 그대로 쓴다\n', mdl, st);
end

if is_vrx
    W06_vrx_prep(mdl);
end

%  실시간 화면을 **지금** 만들어 둔다 — 첫 스텝에서 만들면 그 동안 모델이
%  멈춰 있고 Gazebo 는 마지막 추력 명령을 그대로 지킨다 ([[W06_animate]] 머리말)
if evalin('base', 'animate')
    W06_animate('init');
end
end
