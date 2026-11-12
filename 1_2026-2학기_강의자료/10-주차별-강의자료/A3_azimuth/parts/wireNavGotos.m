function wireNavGotos(m, src, x, y)
%  운동모델 출력 열두 개를 전부 태그로 낸다 (뒤의 셋이 실제 렌치다)
    t = {'x_n','y_n','psi','u','v','r','beta','chi','U','X_a','Y_a','N_a'};
    for k = 1:numel(t)
        sl_goto(m, t{k}, x, y+(k-1)*45);
        add_line(m, sprintf('%s/%d',src,k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end
