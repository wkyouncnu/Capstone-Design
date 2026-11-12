function addAnimateA3(m, x, y)
%  실시간 그림 상자 — A3_animate.m 을 매 스텝 부른다
%
%  태그 **순서가 곧 A3_animate 의 인자 순서**다. 바꾸면 그림이 엉뚱한 값을
%  그린다 (오류는 뜨지 않는다). A3_animate.m 의 머리 주석과 함께 고칠 것.
%
%  X_c·Y_c·N_c 를 넣는 까닭
%    제어기가 **요구한** 힘·모멘트다. 실제로 난 값은 추진기 상태(TL·dL·TR·dR)
%    에서 A3_animate 안에서 다시 계산한다 — 모델의 Wrench 블록과 같은 식이다.
%    둘의 차이가 0 에서 떨어지는 순간이 곧 각도·추력 한계가 물린 순간이다.
    tags = {'x_n','y_n','psi','psi_ref','x_ref','y_ref', ...
            'u','v','r','gate','phase', ...
            'TL','dL','TR','dR','kscl', ...
            'X_c','Y_c','N_c'};
    add_animate_box(m, tags, 'A3_animate', '', [x y], 'Ts_ctrl');
end
