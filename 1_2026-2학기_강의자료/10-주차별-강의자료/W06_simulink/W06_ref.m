function R = W06_ref(op, st, out, S)
% W06_REF  오프라인 기준 궤적을 ref/ 에 저장하고 꺼낸다
%
%   W06_ref('save', st, out, S)     오프라인 실행 결과를 st 단의 기준으로 저장
%   R = W06_ref('load', st)         없으면 빈 구조체 ([])
%
%   무엇을 위한 것인가
%     VRX 쌍둥이를 Simulink 에서 직접 Run 했을 때, **m 파일이 남긴 오프라인 결과**
%     위에 겹쳐 그려 두 그래프가 같은지를 그 자리에서 본다. 예전에는 쌍둥이를 돌린
%     뒤 오프라인을 **다시** 돌려 대조했다 — 한 번에 두 모델이 도는 것이 헷갈렸다.
%
%   저장 위치 — ref/W06_<단계>_offline.mat
%     6단(W06_5_dock_vrx) 의 기준은 5단(W06_5_dock) 것이다. 번호만 다르고 과업이 같다.
%
%   언제 쌓이는가
%     - W06_<n>_..._run.m 을 돌릴 때마다 (m 파일 = 오프라인 전용)
%     - 오프라인 모델을 Simulink 에서 직접 Run 할 때마다 (StopFcn)

here = fileparts(mfilename('fullpath'));
DIR  = fullfile(here, 'ref');
st   = W06_ref_stage(st);
file = fullfile(DIR, sprintf('W06_%d_offline.mat', st));

switch lower(op)
    case 'save'
        if ~isfolder(DIR), mkdir(DIR); end
        R = W06_pack(out);
        R.stage = st;
        R.mdl   = evalin('base', 'mdl');
        R.T_run = evalin('base', 'T_run');
        R.psi0  = R.psi(1);
        R.when  = datetime('now');
        if nargin >= 4 && ~isempty(S)
            R.S = rmfield(S, intersect(fieldnames(S), {'fig'}));
        end
        save(file, '-struct', 'R');
        fprintf('   기준 궤적 저장 — ref/W06_%d_offline.mat (VRX 대조에 쓴다)\n', st);

    case 'load'
        if isfile(file), R = load(file); else, R = []; end

    otherwise
        error('W06_ref:op', 'op 는 save 또는 load');
end
end

% ---------------------------------------------------------------------
function st = W06_ref_stage(st)
%  6단은 5단과 같은 과업이다 — 기준을 따로 두지 않는다
if st == 6, st = 5; end
end
