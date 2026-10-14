function wireThrusterGotos(m, x, y)
%  추진기 출력 네 개를 태그로 낸다. 줄이 바뀌는 자리를 이 태그로 건너간다
    t = {'FL','FR','FB','nprop'};
    for k = 1:numel(t)
        sl_goto(m, t{k}, x, y+(k-1)*45);
        add_line(m, sprintf('Thrusters/%d',k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end
