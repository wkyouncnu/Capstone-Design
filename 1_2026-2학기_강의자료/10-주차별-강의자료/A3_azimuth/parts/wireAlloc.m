function wireAlloc(m, xg, yg, xf, yf)
%  배분 상자와 운동모델을 잇는다
%
%    InnerLoop ─선─> Alloc                  바로 옆 칸이므로 선으로 그린다
%    Alloc ─태그─> MotionModel              사슬이 줄바꿈되는 자리이므로 태그로
%
%  건너가는 것은 **힘이 아니라 추진기 명령 넷** (TL·dL·TR·dR) 이다.
%  명령을 실제 렌치로 바꾸는 일은 운동모델 안에서 한다.
%
%  요구(X_c·Y_c·N_c) 는 태그로 한 번 더 뽑는다. 로그에서 요구와 실제를 겹쳐
%  보아야 "각도 한계 때문에 못 낸 힘" 이 눈에 보인다
    cmd = {'X_c','Y_c','N_c'};
    for k = 1:3
        add_line(m, sprintf('InnerLoop/%d',k), sprintf('Alloc/%d',k), 'autorouting','on');
        drop_tag(m, 'InnerLoop', k, cmd{k}, -80);
    end

    act = {'TL','dL','TR','dR'};
    for k = 1:numel(act)
        sl_goto(m, act{k}, xg, yg+45*(k-1));
        add_line(m, sprintf('Alloc/%d',k), ['Go_' act{k} '/1'], 'autorouting','on');
    end
    for k = 1:numel(act)
        nm = sl_from(m, act{k}, xf, yf+45*(k-1));
        add_line(m, [nm '/1'], sprintf('MotionModel/%d',k), 'autorouting','on');
    end
end
