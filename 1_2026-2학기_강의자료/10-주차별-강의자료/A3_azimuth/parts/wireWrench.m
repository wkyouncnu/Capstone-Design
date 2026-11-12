function wireWrench(m, xg, yg, xf, yf)
%  요구 힘·모멘트와 실제로 난 힘·모멘트를 잇는다
%
%    InnerLoop ─선─> Alloc            바로 옆 칸이므로 선으로 그린다
%    Alloc ─태그─> MotionModel        사슬이 줄바꿈되는 자리이므로 태그로 보낸다
%
%  요구(X_c·Y_c·N_c) 도 태그로 한 번 더 뽑는다. 로그에서 요구와 실제를 겹쳐
%  보아야 "각도 한계 때문에 못 낸 힘" 이 눈에 보인다
    cmd = {'X_c','Y_c','N_c'};
    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Alloc/%d',k), 'autorouting','on');
        drop_tag(m, 'InnerLoop', k, cmd{k}, -80);
    end

    act = {'X_a','Y_a','N_a'};
    for k = 1:3
        sl_goto(m, act{k}, xg, yg+45*(k-1));
        add_line(m, sprintf('Alloc/%d',k), ['Go_' act{k} '/1'], 'autorouting','on');
    end
    for k = 1:3
        nm = sl_from(m, act{k}, xf, yf+45*(k-1));
        add_line(m, [nm '/1'], sprintf('MotionModel/%d',k), 'autorouting','on');
    end
end
