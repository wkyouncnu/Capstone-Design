function wireThrusterGotos(m, x, y)
%  추진기 출력 다섯 개를 태그로 낸다. 줄이 바뀌는 자리를 이 태그로 건너간다
%  Ferr 는 프로펠러 법칙 왕복 검산값이다 (추력 -> 회전수 -> 추력 의 차이)
    t = {'FL','FR','FB','nprop','Ferr'};
    for k = 1:numel(t)
        sl_goto(m, t{k}, x, y+(k-1)*45);
        add_line(m, sprintf('Thrusters/%d',k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end
