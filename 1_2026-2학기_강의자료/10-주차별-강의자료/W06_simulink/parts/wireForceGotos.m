function wireForceGotos(m, x, y)
%  안쪽 고리가 낸 추력 지령 셋을 그대로 태그로 낸다 (추진기 동역학이 없는 단계)
%
%  3단에서 Thrusters 가 생기면 이 자리가 wireThrusterGotos 로 바뀐다. 태그
%  이름(FL·FR·FB)은 같으므로 운동모델·로깅·그림 쪽은 한 줄도 고치지 않는다.
    t = {'FL','FR','FB'};
    for k = 1:3
        sl_goto(m, t{k}, x, y+45*(k-1));
        add_line(m, sprintf('InnerLoop/%d',k), ['Go_' t{k} '/1'], 'autorouting','on');
    end
end
