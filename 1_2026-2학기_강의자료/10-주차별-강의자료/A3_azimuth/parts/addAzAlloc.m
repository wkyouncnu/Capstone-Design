function addAzAlloc(m, x, y)
% addAzAlloc — 아지무스 추력 배분 상자 (부록 A3 에서 새로 만드는 것은 이것 하나다)
%
%   들어오는 것   X_c · Y_c · N_c   안쪽 고리가 요구한 힘·모멘트 (선체고정)
%   나가는 것     X_a · Y_a · N_a   추진기 두 대가 **실제로** 낼 힘·모멘트
%
%   안에 셋이 줄지어 있다
%     1. AzAlloc    요구를 (추력, 각도) 둘씩으로 나눈다. 각도·추력 한계도 여기서
%     2. RateL/R    각도 변화율 한계 — 선외기가 즉시 돌아가지는 않는다
%     3. Wrench     잘린 각도·줄인 추력으로 **실제로 난 힘**을 되계산한다
%
%   2 번이 1 번 뒤에 오는 이유 — 변화율 한계는 기구(機構)의 한계이므로 지령을
%   만든 다음에 걸린다. 1 번 안에서 걸 수는 없다 (상태를 가져야 하므로).
    ss = add_subsys(m, 'Alloc', [x y x+190 y+190], ...
                    {'X_c','Y_c','N_c'}, {'X_a','Y_a','N_a'}, ...
                    gnc_colour('allocation'));

    sl_const(ss, 'PRM', 'az_prm', 60, 320);

    %  1. 배분 — 요구 셋을 (추력, 각도) 둘씩 + 축소 배율로
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/AzAlloc'], ...
              'Position', [330 60 510 420]);
    sl_fcn(ss, 'AzAlloc', azAllocFcn());
    row_feed(ss, 'AzAlloc', {'X_c','Y_c','N_c','PRM'});

    %  2. 각도 변화율 한계 — 좌·우 각각
    rl = {'RateL', 2; 'RateR', 4};
    for k = 1:2
        p = port_xy(ss, 'AzAlloc', 'Outport', rl{k,2});
        add_block('simulink/Discontinuities/Rate Limiter', [ss '/' rl{k,1}], ...
                  'Position', [620 p(2)-20 670 p(2)+20], ...
                  'RisingSlewLimit', 'd_rate', 'FallingSlewLimit', '-d_rate');
        add_line(ss, sprintf('AzAlloc/%d', rl{k,2}), [rl{k,1} '/1'], 'autorouting','on');
    end

    %  3. 실제로 난 힘 되계산
    %     높이를 AzAlloc 과 같게 잡는 이유 — MATLAB Function 블록의 포트는 높이를
    %     균등 분할한 자리에 생긴다. 둘의 높이를 맞추면 출력 5개와 입력 5개의 y 가
    %     그대로 겹치므로 TL·TR·dL·dR 네 선이 **꺾임 없이 직선**으로 들어간다.
    %     어긋나게 두면 다섯 선이 Wrench 왼쪽 한 칸에 모여 서로 겹친다 (실측 3건).
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Wrench'], ...
              'Position', [820 60 1000 420]);
    sl_fcn(ss, 'Wrench', wrenchFcn());
    %     네 선 모두 **자동 배선을 쓰지 않는다.** 포트 높이가 이미 같으므로 직선
    %     한 토막이면 끝인데, 자동 배선은 TL 선에 5 px 짜리 턱을 넣어 꺾임 4회로
    %     보고되었다 (실측). 같은 높이끼리는 손으로 잇는 쪽이 늘 깔끔하다.
    add_line(ss, 'AzAlloc/1', 'Wrench/1');
    add_line(ss, 'RateL/1',   'Wrench/2');
    add_line(ss, 'AzAlloc/3', 'Wrench/3');
    add_line(ss, 'RateR/1',   'Wrench/4');

    %     기하·한계 묶음은 **태그로** 건넨다. PRM 은 AzAlloc 왼쪽에 있으므로 선으로
    %     이으면 AzAlloc 블록을 피해 아래로 돌아야 한다 — 꺾임 4회에 이름표를 밟는다.
    %     태그로 받으면 Wrench 입력 포트 바로 옆에서 수평 한 토막으로 끝난다.
    drop_tag(ss, 'PRM', 1, 'prm', 120);
    feed_from(ss, 'prm', 'Wrench', 5);

    outs = {'X_a','Y_a','N_a'};
    for k = 1:3
        p = port_xy(ss, 'Wrench', 'Outport', k);
        set_param([ss '/' outs{k}], 'Position', [1080 p(2)-10 1110 p(2)+10]);
        add_line(ss, sprintf('Wrench/%d', k), [outs{k} '/1'], 'autorouting','on');
    end

    %  추진기 상태를 로그로 뽑는다 — 각도가 한계에 붙었는지, 추력을 얼마나
    %  줄였는지는 수치로 보아야 알 수 있다
    drop_tag(ss, 'AzAlloc', 1, 'TL',    -90);
    drop_tag(ss, 'AzAlloc', 3, 'TR',    -90);
    drop_tag(ss, 'AzAlloc', 5, 'kscl',   90);
    drop_tag(ss, 'RateL',   1, 'dL',    -70);
    drop_tag(ss, 'RateR',   1, 'dR',     70);
end
