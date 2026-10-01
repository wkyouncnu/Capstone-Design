function [ratio, info] = check_fill(mdl, verbose)
%CHECK_FILL  도면의 **채움 비율**을 잰다 — 블록 넓이 / 경계 넓이.
%            Measure how much of a diagram is actually drawn on.
%
%   ratio = check_fill(mdl)                최상위 채움 비율 (0~1)
%   [ratio, info] = check_fill(mdl, true)  층마다 나열한다
%
%   교수 지시 2026-10-01 — *"블록을 띄엄띄엄 놓지 말고 가까이 모아 주세요.
%   빈 공간이 너무 많습니다. 점검은 눈대중이 아니라 채움 비율로."*
%
%   왜 비율인가
%
%   도면이 넓어지면 PDF 쪽폭에 맞출 때 **글씨가 작아진다.** 같은 내용이면
%   작은 도면이 낫다. 그런데 "넓다" 는 눈대중으로는 판정이 갈린다. 블록이
%   실제로 차지하는 넓이를 경계상자 넓이로 나누면 숫자 하나로 남는다.
%
%   읽는 법 — 최상위 기준
%
%   | 비율 | 뜻 |
%   |---|---|
%   | 0.20 이상 | 좋다. 사슬이 모여 있다 |
%   | 0.10~0.20 | 보통. 로깅·화면 상자가 떨어져 있을 수 있다 |
%   | 0.10 미만 | **빈칸이 90 % 다.** 시작 좌표와 단계 간격을 줄인다 |
%
%   합격선을 두지 않는다. 사슬이 길면 가로로 눕고 비율이 자연히 낮아지기
%   때문이다. **고치기 전후를 견주는 숫자**로 쓴다.

if nargin < 2, verbose = false; end

sysList = [{mdl}; find_system(mdl, 'LookUnderMasks','all', 'BlockType','SubSystem')];
info    = cell(0, 6);

for i = 1:numel(sysList)
    s = sysList{i};
    try
        kids = find_system(s, 'SearchDepth',1, 'LookUnderMasks','all', 'Type','Block');
    catch
        continue
    end
    kids = kids(~strcmp(kids, s));
    if numel(kids) < 2, continue; end

    P = zeros(numel(kids), 4);
    ok = false(numel(kids),1);
    for k = 1:numel(kids)
        try
            P(k,:) = get_param(kids{k}, 'Position');
            ok(k)  = true;
        catch
        end
    end
    P = P(ok,:);
    if size(P,1) < 2, continue; end

    %  Note(주석) 블록은 Position 이 두 값만 있는 경우가 있다 — 걸러낸다
    good = (P(:,3) > P(:,1)) & (P(:,4) > P(:,2));
    P = P(good,:);
    if size(P,1) < 2, continue; end

    area  = sum((P(:,3)-P(:,1)) .* (P(:,4)-P(:,2)));
    bb    = [min(P(:,1)) min(P(:,2)) max(P(:,3)) max(P(:,4))];
    bbw   = bb(3)-bb(1);  bbh = bb(4)-bb(2);
    bbA   = max(bbw*bbh, 1);

    info(end+1,:) = {s, size(P,1), area/bbA, bbw, bbh, area};  %#ok<AGROW>
end

if isempty(info)
    ratio = NaN;
    if verbose, fprintf('  check_fill %s — 잴 것이 없음\n', mdl); end
    return
end

ratio = info{1,3};      % 첫 줄이 최상위다

if verbose
    fprintf('  check_fill %s — 최상위 채움 %.1f %%  (경계 %d x %d px)\n', ...
            mdl, 100*ratio, round(info{1,4}), round(info{1,5}));
    for i = 1:size(info,1)
        nm = info{i,1};
        if i == 1, nm = [nm '   <- 최상위']; end
        fprintf('    %-52s 블록 %3d   채움 %5.1f %%   %5d x %5d\n', ...
                nm, info{i,2}, 100*info{i,3}, round(info{i,4}), round(info{i,5}));
    end
end
end
