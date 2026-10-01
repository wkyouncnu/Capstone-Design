function n = mss_style(mdl, verbose)
%MSS_STYLE  모델 안의 모든 블록 크기를 MSS 가 쓰는 치수로 맞춘다.
%           Resize every block in a model to the sizes MSS uses.
%
%   mss_style(mdl)              조용히 적용한다 / apply, silently
%   n = mss_style(mdl, true)    적용하고 무엇이 바뀌었는지 나열한 뒤 개수를 돌려준다
%                               apply, list what changed, return the count
%
%   빌더의 끝에서, save_system 직전에 한 번 부른다.
%   Call it once at the end of a builder, just before save_system.
%
%   WHERE THE NUMBERS COME FROM
%
%   Not invented. Measured across every demo model in
%   Tools/MSS/SIMULINK/mssSimulinkDemos - 211 Sum blocks, 242 Gains, 354
%   Inports and so on - and the median of each block type taken. The table
%   below is that measurement. Regenerate it with the survey at the bottom of
%   this file if MSS is ever updated.
%
%   WHY IT MATTERS
%
%   Simulink's defaults are larger than MSS's in almost every case: a default
%   Gain is 40 wide against 50 x 36, a default Sum is a 25 x 40 rectangle
%   against a 20 x 20 circle, a default Transfer Fcn sprawls. On a diagram
%   that has to be read at page width in a PDF, oversized blocks push the
%   chain apart, and the reader loses the line of the signal. Matching MSS
%   also means a student who opens an MSS demo next to one of these models
%   sees the same drawing conventions in both.
%
%   THE CENTRE IS PRESERVED
%
%   Blocks are resized about their own centre, so a block that was lined up
%   with the signal passing through it stays lined up. Simulink keeps the
%   lines attached and redraws them.
%
%   GAIN BLOCKS ARE WIDENED TO FIT THEIR EXPRESSION  (교수 지시 2026-10-01)
%
%   MSS 치수 50 x 36 은 숫자 게인에는 맞지만 `Kp_psi` 같은 **변수 이름**은 그
%   폭에 들어가지 않는다. Simulink 는 식이 블록보다 넓으면 식을 숨기고 `-K-`
%   를 그린다. 그러면 도면만 보고는 **어느 게인인지 알 수 없다.** 가독성이 MSS
%   치수보다 앞서므로 Gain 만 예외로 두고 식 길이에 맞춰 폭을 늘린다.
%   글자당 GAIN_PX_PER_CHAR, 좌우 여백 GAIN_PAD, 최소 폭은 MSS 의 50 px 그대로.
%   숫자 게인(`2` · `0.5`)은 식이 짧아 50 px 에서 멈추므로 달라지지 않는다.
%   중심은 그대로 두므로 배선이 틀어지지 않는다.
%
%   WHAT IS LEFT ALONE
%
%   SubSystem blocks. Those are the six stages of the signal chain and their
%   sizes come from gnc_chain, which places them deliberately. Mux and Demux
%   keep their height too - the height is how many signals they carry, and
%   forcing it would misrepresent the model.

if nargin < 2, verbose = false; end

%  block type -> [width height], median over the MSS demo models
S = { 'Sum',           20  20
      'Gain',          50  36
      'Constant',      55  30
      'Integrator',    30  30
      'TransferFcn',   60  36
      'Saturate',      30  30
      'Scope',         30  30
      'Step',          30  30
      'Clock',         20  20
      'Inport',        30  14
      'Outport',       30  14
      'ToWorkspace',   60  30
      'Product',       45  35
      'Terminator',    20  20
      'Math',          30  30
      'Trigonometry',  30  30
      'Signum',        30  30
      'Switch',        30  30
      'Rounding',      30  30
      'RandomNumber',  30  28
      'Fcn',           60  22 };

want = containers.Map(S(:,1), num2cell(cell2mat(S(:,2:3)), 2));

blocks = find_system(mdl, 'LookUnderMasks','all', 'Type','Block');
n = 0;
for i = 1:numel(blocks)
    b = blocks{i};
    try, t = get_param(b, 'BlockType'); catch, continue; end
    if ~isKey(want, t), continue; end

    %  입력이 여럿인 Scope 는 높이가 곧 포트 간격이다. 30 px 로 줄이면 포트가
    %  겹치고 들어오는 선이 전부 얕은 사선이 된다. 크기를 그대로 둔다.
    if strcmp(t, 'Scope')
        try
            if numel(get_param(b,'PortHandles').Inport) > 1, continue; end
        catch
        end
    end

    wh = want(t);

    %  Gain 은 식이 보여야 한다. MSS 폭 50 px 를 **최소값**으로 두고 식 길이에
    %  맞춰 늘린다. 안 그러면 Simulink 가 식을 숨기고 `-K-` 를 그린다.
    if strcmp(t, 'Gain')
        wh(1) = max(wh(1), gain_width(b));
    end

    p  = get_param(b, 'Position');
    if (p(3)-p(1)) == wh(1) && (p(4)-p(2)) == wh(2), continue; end

    cx = (p(1)+p(3))/2;  cy = (p(2)+p(4))/2;
    q  = round([cx-wh(1)/2, cy-wh(2)/2, cx+wh(1)/2, cy+wh(2)/2]);
    set_param(b, 'Position', q);
    n = n + 1;
    if verbose
        fprintf('    %-38s %s  %dx%d -> %dx%d\n', get_param(b,'Name'), t, ...
                p(3)-p(1), p(4)-p(2), wh(1), wh(2));
    end
end

%  A round summing junction is the MSS signature. Any Sum still drawn as a
%  rectangle is one a builder created without add_sum; fix it here rather than
%  leaving one slab in an otherwise consistent diagram.
sums = find_system(mdl, 'LookUnderMasks','all', 'BlockType','Sum');
for i = 1:numel(sums)
    if ~strcmp(get_param(sums{i}, 'IconShape'), 'round')
        set_param(sums{i}, 'IconShape', 'round');
        sg = strrep(get_param(sums{i}, 'Inputs'), '|', '');
        set_param(sums{i}, 'Inputs', ['|' sg]);
        n = n + 1;
    end
end

%  크기를 바꾸면 Simulink 는 선의 끝점만 새 포트로 당기고 이웃 점은 두어 끝 토막이
%  2~7 px 기운 사선이 된다 (2026-09-19). 이웃 점을 따라 옮겨 직각으로 되돌린다.
square_lines(mdl);

if verbose, fprintf('    %d blocks restyled in %s\n', n, mdl); end
end

% -------------------------------------------------------------------------
function w = gain_width(b)
%GAIN_WIDTH  Gain 의 식이 글자 그대로 보이는 데 필요한 폭 [px].
%
%   Simulink 는 식이 블록보다 넓으면 `-K-` 를 그린다. 블록을 글자가 들어갈
%   만큼 키우면 변수 이름이 그대로 보인다. 폭만 늘리고 높이는 그대로 둔다.
%
%   7 px/글자는 Simulink 의 기본 도면 글꼴(Helvetica 10 pt)을 도면에서 재
%   얻은 값이다. 여백 16 px 는 좌우 8 px 씩이다.
GAIN_PX_PER_CHAR = 7;
GAIN_PAD         = 16;
GAIN_MAX         = 200;     % 이보다 길면 식이 아니라 수식이다. 거기서 멈춘다

try
    ex = get_param(b, 'Gain');
catch
    w = 0; return
end
if ~ischar(ex) && ~isstring(ex), w = 0; return; end
ex = char(ex);

%  행렬 게인은 여러 줄로 그려진다 — 가장 긴 줄로 잰다
lines = strsplit(ex, {char(10), char(13), ';'});
len   = max(cellfun(@(s) numel(strtrim(s)), lines));

w = min(GAIN_MAX, len*GAIN_PX_PER_CHAR + GAIN_PAD);
end

% =========================================================================
%  The survey that produced the table above. Kept so the numbers can be
%  checked rather than trusted.
%
%   root = <...>/Tools/MSS;  addpath(genpath(root));
%   dd = dir(fullfile(root,'SIMULINK','mssSimulinkDemos','demo*.slx'));
%   S = containers.Map('KeyType','char','ValueType','any');
%   for k = 1:numel(dd)
%       [~,m] = fileparts(dd(k).name);
%       evalc(sprintf('load_system(''%s'')', fullfile(dd(k).folder, dd(k).name)));
%       b = find_system(m,'LookUnderMasks','all','FollowLinks','on','Type','Block');
%       for i = 1:numel(b)
%           t = get_param(b{i},'BlockType');  p = get_param(b{i},'Position');
%           if ~isKey(S,t), S(t) = []; end
%           S(t) = [S(t); p(3)-p(1) p(4)-p(2)];
%       end
%       evalc(sprintf('close_system(''%s'',0)', m));
%   end
%   for k = sort(S.keys), v = S(k{1});
%       fprintf('%-16s %4d  %dx%d\n', k{1}, size(v,1), median(v(:,1)), median(v(:,2)));
%   end
