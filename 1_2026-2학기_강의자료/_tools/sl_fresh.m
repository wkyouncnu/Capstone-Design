function sl_fresh(m)
%SL_FRESH  같은 이름의 모델을 지우고 빈 모델을 새로 만든다.
%
%   sl_fresh('W06_1_point')
%
%   빌더는 언제 다시 돌려도 같은 결과가 나와야 한다. 열려 있던 모델이 남아
%   있으면 add_block 이 "이미 있다" 로 멈추므로, 닫고 지우고 새로 만든다.
    try, close_system(m, 0); catch, end
    if exist([m '.slx'],'file'), delete([m '.slx']); end
    new_system(m);
end
