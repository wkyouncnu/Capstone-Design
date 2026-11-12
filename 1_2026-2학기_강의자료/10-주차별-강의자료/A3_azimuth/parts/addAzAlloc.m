function addAzAlloc(m, x, y)
% addAzAlloc — 아지무스 추력 배분 상자 (부록 A3 에서 새로 만드는 것은 이것 하나다)
%
%   들어오는 것   X_c · Y_c · N_c       안쪽 고리가 요구한 힘·모멘트 (선체고정)
%   나가는 것     TL · dL · TR · dR     추진기 두 대에 보내는 추력과 각도
%
%   **추진기 명령까지만 낸다.** 그 명령이 선체에 얼마의 힘·모멘트로 걸리는가는
%   운동모델 안에서 계산한다 (parts/addMotionModelXYN.m 의 Wrench).
%   힘으로 되돌리는 계산은 추진기 배치(기하)를 알아야 하는 일이고, 그것은
%   배가 가진 성질이므로 배 쪽 상자에 둔다.
%
%   안에 둘이 줄지어 있다
%     1. AzAlloc    요구를 (추력, 각도) 둘씩으로 나눈다. 각도·추력 한계도 여기서
%     2. RateL/R    각도 변화율 한계 — 선외기가 즉시 돌아가지는 않는다
%
%   2 번이 1 번 뒤에 오는 이유 — 변화율 한계는 기구(機構)의 한계이므로 지령을
%   만든 다음에 걸린다. 1 번 안에서 걸 수는 없다 (상태를 가져야 하므로).
    ss = add_subsys(m, 'Alloc', [x y x+190 y+190], ...
                    {'X_c','Y_c','N_c'}, {'TL','dL','TR','dR'}, ...
                    gnc_colour('allocation'));

    %  배분 방식은 **설정값 하나**로 고른다 — 1 = pseudo-inverse,
    %  2 = pseudo-inverse + null space 보정. A3_setup.m 의 alloc_mode 다
    sl_const(ss, 'ALLOC', 'alloc_mode', 60, 320);
    sl_const(ss, 'PRM',   'az_prm',     60, 390);

    %  1. 배분 — 요구 셋을 (추력, 각도) 둘씩으로
    %     높이를 넉넉히 잡는 이유 — MATLAB Function 블록의 포트는 높이를 균등
    %     분할한 자리에 생긴다. 입력 다섯이 52 px 보다 촘촘하면 왼쪽에서 선과
    %     이름표가 겹친다 (_tools/row_feed.m 이 경고를 낸다).
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/AzAlloc'], ...
              'Position', [330 60 510 400]);
    sl_fcn(ss, 'AzAlloc', azAllocFcn());
    row_feed(ss, 'AzAlloc', {'X_c','Y_c','N_c','ALLOC','PRM'});

    %  2. 각도 변화율 한계 — 좌·우 각각 (출력 2 번과 4 번이 각도다)
    rl = {'RateL', 2; 'RateR', 4};
    for k = 1:2
        p = port_xy(ss, 'AzAlloc', 'Outport', rl{k,2});
        add_block('simulink/Discontinuities/Rate Limiter', [ss '/' rl{k,1}], ...
                  'Position', [620 p(2)-20 670 p(2)+20], ...
                  'RisingSlewLimit', 'd_rate', 'FallingSlewLimit', '-d_rate');
        add_line(ss, sprintf('AzAlloc/%d', rl{k,2}), [rl{k,1} '/1'], 'autorouting','on');
    end

    %  바깥으로 — 추력은 배분기에서 바로, 각도는 변화율 한계를 거친 쪽으로
    outs = {'TL','AzAlloc',1; 'dL','RateL',1; 'TR','AzAlloc',3; 'dR','RateR',1};
    for k = 1:4
        p = port_xy(ss, outs{k,2}, 'Outport', outs{k,3});
        set_param([ss '/' outs{k,1}], 'Position', [780 p(2)-10 810 p(2)+10]);
        add_line(ss, sprintf('%s/%d', outs{k,2}, outs{k,3}), ...
                 [outs{k,1} '/1'], 'autorouting','on');
    end
end
