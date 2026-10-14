function wireGuid(m, guidIns, guidOuts, x, y)
%  유도부의 입력(되먹임 태그)과 출력(목표 태그)을 잇는다
%
%    guidIns   유도부가 받는 태그 이름. 상수 유도부는 {} 다
%    guidOuts  유도부가 내놓는 태그 이름. 순서가 곧 출력 포트 순서다
%
%  출력은 **태그로 한 번, 선으로 한 번** 낸다. 바로 오른쪽 블록(바깥 고리)이
%  쓰는 셋은 선으로 그어야 신호 흐름이 보이고, 두 칸 넘게 떨어진 psi_ref 와
%  phase 는 태그로만 내보내야 선이 다른 단계를 가로지르지 않는다.
    for k = 1:numel(guidIns)
        nm = sl_from(m, guidIns{k}, 40, 65+45*(k-1));
        add_line(m, [nm '/1'], sprintf('Guidance/%d',k), 'autorouting','on');
    end
    for k = 1:numel(guidOuts)
        sl_goto(m, guidOuts{k}, x, y+45*(k-1));
        add_line(m, sprintf('Guidance/%d',k), ['Go_' guidOuts{k} '/1'], 'autorouting','on');
    end
    %  바깥 고리가 선으로 바로 받는 둘. gate 는 태그로 간다 (wireLoops 참조)
    direct = {'x_ref',1; 'y_ref',2};
    for k = 1:size(direct,1)
        j = find(strcmp(guidOuts, direct{k,1}), 1);
        add_line(m, sprintf('Guidance/%d',j), sprintf('OuterLoop/%d',direct{k,2}), ...
                 'autorouting','on');
    end
end
