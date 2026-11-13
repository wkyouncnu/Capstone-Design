function wireAllocVrx(m, xg, yg, xf, yf)
%  배분 상자와 가제보(토픽) 를 잇는다 — 4단 전용. 오프라인 판은 wireAlloc 이다
%
%    InnerLoop ─선─> Alloc           바로 옆 칸이므로 선으로 그린다
%    Alloc ─태그─> (Wrench · 로깅 · 그림)
%    Alloc ─선─> PosSign ─선─> CmdPublisher
%
%  오프라인 판과 다른 곳이 둘이다
%    운동모델이 없다       추진기 명령이 토픽으로 나간다
%    각도만 PosSign 을 지난다  추력은 손볼 것이 없으므로 태그로 건너뛴다
%
%  추력을 Alloc 에서 CmdPublisher 로 **직선으로 끌면 PosSign 상자를 관통한다.**
%  5단에서 밟은 자리이므로 여기서도 태그로 건너뛴다.
    cmd = {'X_c','Y_c','N_c'};
    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Alloc/%d',k), 'autorouting','on');
        drop_tag(m, 'InnerLoop', k, cmd{k}, -80);
    end

    %  추진기 명령 넷을 태그로 낸다 — Wrench 상자와 로깅·그림이 이 이름으로 받는다
    act = {'TL','dL','TR','dR'};
    for k = 1:numel(act)
        sl_goto(m, act{k}, xg, yg+45*(k-1));
        add_line(m, sprintf('Alloc/%d',k), ['Go_' act{k} '/1'], 'autorouting','on');
    end

    %  각도 둘만 PosSign 을 지난다 (변화율 깎기 · 1 차 지연 · 부호 뒤집기)
    add_line(m, 'Alloc/2', 'PosSign/1', 'autorouting','on');
    add_line(m, 'Alloc/4', 'PosSign/2', 'autorouting','on');
    add_line(m, 'PosSign/1', 'CmdPublisher/2', 'autorouting','on');
    add_line(m, 'PosSign/2', 'CmdPublisher/4', 'autorouting','on');

    %  추력 둘은 태그로 건너뛴다
    for k = [1 3]
        nm = sl_from(m, act{k}, xf, yf+45*(k-1));
        add_line(m, [nm '/1'], sprintf('CmdPublisher/%d', k), 'autorouting','on');
    end
end
