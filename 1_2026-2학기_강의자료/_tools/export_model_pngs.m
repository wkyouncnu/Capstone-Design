function n = export_model_pngs(mdl, folder)
%EXPORT_MODEL_PNGS  모델의 도면과, 강의노트가 이미 싣고 있는 서브시스템 도면을
%                   한꺼번에 다시 찍는다.
%
%   export_model_pngs('W02_2_goto_offline')
%
%   무엇을 찍는가 / what it saves
%     1) 최상위 도면                 img/<모델>.png
%     2) **이미 파일이 있는** 서브시스템  img/<모델>__<이름>.png
%
%   왜 "이미 있는" 것만인가 / why only the ones already there
%       모든 서브시스템을 찍으면 강의노트가 쓰지 않는 그림이 폴더에 쌓이고,
%       vault_check §6 이 세는 "뒤처진 도면" 의 수만 늘어난다. 노트에 새 그림을
%       넣기로 하는 것은 사람의 판단이므로, 파일을 한 번 만들어 두면 그 뒤로는
%       빌더가 알아서 갱신한다.
%
%   배치를 다시 잡으면 도면이 달라진다. 빌더 끝에서 부르지 않으면 강의노트의
%   그림이 모델과 어긋난다 — export_diagram 의 설명 참조.

if nargin < 2 || isempty(folder), folder = fullfile(pwd, 'img'); end
n = 0;

opened = false;
if ~bdIsLoaded(mdl), load_system(mdl); opened = true; end

export_diagram(mdl, folder);
n = n + 1;

subs = find_system(mdl, 'SearchDepth',1, 'BlockType','SubSystem');
for i = 1:numel(subs)
    nm = get_param(subs{i}, 'Name');
    if isfile(fullfile(folder, [mdl '__' nm '.png']))
        export_diagram(mdl, folder, nm);
        n = n + 1;
    end
end

if opened, close_system(mdl, 0); end
end
