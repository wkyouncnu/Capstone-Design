function wireNavGotos(m, src, x, y)
%  운동모델(또는 항법) 출력 아홉 개를 전부 태그로 낸다
    t = {'x_n','y_n','psi','u','v','r','beta','chi','U'};
    for k = 1:numel(t)
        sl_goto(m, t{k}, x, y+(k-1)*45);
        add_line(m, sprintf('%s/%d',src,k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end
