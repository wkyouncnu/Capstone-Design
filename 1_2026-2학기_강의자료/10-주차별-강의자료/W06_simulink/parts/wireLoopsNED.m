function wireLoopsNED(m, xo, yo, xi, yi)
%  8단(NED 전략)의 두 고리를 잇는다 — wireLoops 와 포트 번호만 다르다
%
%    바깥 고리 ins  {x_ref, y_ref, x_n, y_n, gate}            -> 3·4·5 가 되먹임
%    안쪽 고리 ins  {xdot_cmd, ydot_cmd, u, v, psi_ref, psi, r} -> 3..7 이 되먹임
%
%  선체고정 전략(wireLoops)과 견주어 보면 두 가지가 눈에 띈다
%    (1) 바깥 고리가 psi 를 받지 않는다 — 위치 오차를 돌리지 않으므로 필요가 없다
%    (2) 지령이 u_cmd·v_cmd 가 아니라 xdot_cmd·ydot_cmd 다 — 선체축이 아니라
%        북·동 축의 속도 지령이고, 안쪽 고리의 1·2 번 포트로 나란히 들어간다
%
%  나머지는 같다. 되먹임은 태그로 받는다 — 최상위에 되먹임 선을 그으면 사슬을
%  거슬러 올라가는 긴 선이 생겨 그림이 읽히지 않는다.
    o = {'x_n','y_n','gate'};
    for k = 1:numel(o)
        nm = sl_from(m, o{k}, xo, yo+45*(k-1));
        add_line(m, [nm '/1'], sprintf('OuterLoop/%d',k+2), 'autorouting','on');
    end

    add_line(m, 'OuterLoop/1', 'InnerLoop/1', 'autorouting','on');   % xdot_cmd
    add_line(m, 'OuterLoop/2', 'InnerLoop/2', 'autorouting','on');   % ydot_cmd

    i = {'u',3; 'v',4; 'psi_ref',5; 'psi',6; 'r',7};
    for k = 1:size(i,1)
        nm = sl_from(m, i{k,1}, xi, yi+45*(k-1));
        add_line(m, [nm '/1'], sprintf('InnerLoop/%d',i{k,2}), 'autorouting','on');
    end
end
