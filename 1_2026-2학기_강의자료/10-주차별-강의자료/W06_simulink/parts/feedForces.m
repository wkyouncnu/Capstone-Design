function feedForces(m, dst, x, y)
%  FL·FR·FB 태그를 받아 운동모델(또는 추력 발행기)의 입력 셋에 넣는다
    t = {'FL','FR','FB'};
    for k = 1:3
        nm = sl_from(m, t{k}, x, y+45*(k-1));
        add_line(m, [nm '/1'], sprintf('%s/%d',dst,k), 'autorouting','on');
    end
end
