function out = keep_signals(m, saved)
%KEEP_SIGNALS  신호에 붙은 표시(이름·로깅)를 챙겼다가 되돌린다.
%
%   s = keep_signals(m)        % 챙긴다
%   keep_signals(m, s)         % 되돌린다
%
%   왜 필요한가 / why this exists
%       "이 신호를 기록한다" 는 표시는 **출력 포트**에 붙어 있는데, 그 포트에
%       걸린 선을 지우면 표시도 함께 지워진다. 배치를 다시 잡는 도구는 선을
%       지웠다 다시 긋는 것이 일이므로, 그대로 두면 기록이 조용히 사라진다.
%
%       2026-09-17 에 SB5_pid_done 의 yout 하나가 이렇게 없어졌다. 도면은
%       깨끗해졌는데 결과 파일에서 신호가 빠졌다 — 배치 작업이 저지를 수 있는
%       가장 나쁜 실수다. 그림만 보고는 알 수 없기 때문이다.
%
%       포트는 블록 경로와 포트 번호로 가리키므로, 선이 지워져도 다시 찾을 수 있다.
%
%   되돌리는 것 / what is restored
%       포트  DataLogging, DataLoggingNameMode, DataLoggingName,
%             DataLoggingDecimateData, DataLoggingDecimation,
%             DataLoggingLimitDataPoints, DataLoggingMaxPoints
%       선    Name (신호 이름표)

P = {'DataLogging','DataLoggingNameMode','DataLoggingName', ...
     'DataLoggingDecimateData','DataLoggingDecimation', ...
     'DataLoggingLimitDataPoints','DataLoggingMaxPoints'};

opened = false;
if ~bdIsLoaded(m), load_system(m); opened = true; end
sys = [{m}; find_system(m, 'LookUnderMasks','all', 'BlockType','SubSystem')];

if nargin < 2
    % ---- 챙긴다 --------------------------------------------------------
    out = struct('blk',{},'port',{},'prop',{},'name',{});
    for s = 1:numel(sys)
        blks = find_system(sys{s}, 'SearchDepth',1, 'Type','Block');
        for i = 1:numel(blks)
            if strcmp(blks{i}, sys{s}), continue, end
            ph = get_param(blks{i}, 'PortHandles');
            for k = 1:numel(ph.Outport)
                pr = struct();
                for j = 1:numel(P)
                    try, pr.(P{j}) = get_param(ph.Outport(k), P{j}); catch, end
                end
                if ~isfield(pr,'DataLogging') || ~strcmp(pr.DataLogging,'on')
                    pr = [];                       % 기록하지 않는 포트는 넘어간다
                end
                nm = '';
                try
                    ln = get_param(ph.Outport(k), 'Line');
                    if ln > 0, nm = get_param(ln, 'Name'); end
                catch
                end
                if isempty(pr) && isempty(nm), continue, end
                out(end+1) = struct('blk', blks{i}, 'port', k, ...
                                    'prop', pr, 'name', nm); %#ok<AGROW>
            end
        end
    end
    if opened, close_system(m, 0); end
    return
end

% ---- 되돌린다 ----------------------------------------------------------
out = 0;
for i = 1:numel(saved)
    try
        ph = get_param(saved(i).blk, 'PortHandles');
        p  = ph.Outport(saved(i).port);
    catch
        warning('keep_signals:gone', '%s 의 포트 %d 가 없다', saved(i).blk, saved(i).port);
        continue
    end
    if ~isempty(saved(i).prop)
        f = fieldnames(saved(i).prop);
        for j = 1:numel(f)
            try, set_param(p, f{j}, saved(i).prop.(f{j})); catch, end
        end
        out = out + 1;
    end
    if ~isempty(saved(i).name)
        try
            ln = get_param(p, 'Line');
            if ln > 0, set_param(ln, 'Name', saved(i).name); end
        catch
        end
    end
end
if opened, save_system(m); close_system(m, 0); end
end
