function wireLoops(m, xo, yo, xi, yi)
%  바깥 고리와 안쪽 고리의 되먹임 입력을 태그로 받고, 둘 사이를 선으로 잇는다
%
%    바깥 고리 ins  {x_ref, y_ref, x_n, y_n, psi, gate}   -> 3·4·5 가 되먹임
%    안쪽 고리 ins  {u_cmd, u, v_cmd, v, psi_ref, psi, r} -> 2·4·5·6·7 이 되먹임
%
%  지령(u_cmd, v_cmd)만 선으로 잇고 나머지는 태그로 받는다. 되먹임 선을
%  최상위에 그으면 사슬을 거슬러 올라가는 긴 선이 생겨 그림이 읽히지 않는다.
    %  gate 도 태그로 받는다. 유도부에서 선으로 그으면 100 px 를 내려와야 해
    %  세 번 꺾인다 (2026-10-14 측정). gate 는 쓰는 곳이 바깥 고리·자동정지·
    %  그림·로깅 넷이라 애초에 태그가 어울리는 신호다
    o = {'x_n','y_n','psi','gate'};
    for k = 1:4
        nm = sl_from(m, o{k}, xo, yo+45*(k-1));
        add_line(m, [nm '/1'], sprintf('OuterLoop/%d',k+2), 'autorouting','on');
    end

    add_line(m, 'OuterLoop/1', 'InnerLoop/1', 'autorouting','on');   % u_cmd
    add_line(m, 'OuterLoop/2', 'InnerLoop/3', 'autorouting','on');   % v_cmd

    i = {'u',2; 'v',4; 'psi_ref',5; 'psi',6; 'r',7};
    for k = 1:size(i,1)
        nm = sl_from(m, i{k,1}, xi, yi+45*(k-1));
        add_line(m, [nm '/1'], sprintf('InnerLoop/%d',i{k,2}), 'autorouting','on');
    end
end
