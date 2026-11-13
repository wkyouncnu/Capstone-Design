function ss = addWrenchBox(m, x, y)
%ADDWRENCHBOX  추진기 명령으로부터 렌치를 계산해 태그로만 내는 상자 (4단 전용)
%
%   addWrenchBox(m, 2500, 1500)
%
%   왜 필요한가
%     오프라인 판(2·3단)에서는 Wrench 가 **운동모델 안**에 있다. 4단은 운동모델
%     자리에 가제보가 들어서므로 그 상자가 없어지는데, 로깅·대조그림·실시간
%     그림은 X_a·Y_a·N_a 세 태그를 **그대로 요구한다**. 두 판의 그림을 같은
%     코드로 그리려면 이 셋이 4단에도 있어야 한다.
%
%   무엇을 계산하는가 — **명령으로 계산한 렌치**다
%     parts/wrenchFcn.m 을 오프라인 판과 글자 하나까지 같이 쓴다. 입력은
%     배분기가 낸 TL·dL·TR·dR 이다. 즉 "이 명령이 그대로 실현되면 선체에
%     걸릴 힘" 이고, 가제보가 실제로 물에서 받은 힘을 재어 온 값이 아니다.
%     둘이 갈리는 자리가 둘 있다
%       서보 지연   PosSign 의 1 차 지연만큼 실제 각도가 늦게 따라온다
%       유체력      가제보는 추력 외에 항력·조류를 같이 건다
%     그래서 4단의 X_a·Y_a·N_a 는 **요구와 명령을 견주는 데**만 쓴다.
%     배가 실제로 어떻게 움직였는가는 ground truth (PoseSubscriber) 쪽이 답한다.
%
%   왜 포트가 없는가
%     From 으로 받고 Goto 로 내므로 최상위에 선이 생기지 않는다. 사슬이 아니라
%     **상자**로 들어가 배치 도구가 신호 흐름 가운데로 끌어들이지 않는다
%     (_tools/add_logging_box.m 과 같은 꼴이다).

    ss = add_subsys(m, 'Wrench', [x y x+150 y+90], {}, {}, ...
                    gnc_colour('plant'));

    %  명령 넷을 태그로 받는다 — 이름은 Fr_<태그> 로 둔다
    src = {'TL','dL','TR','dR'};
    for k = 1:4
        add_block('simulink/Signal Routing/From', [ss '/Fr_' src{k}], ...
                  'Position', [60 60+80*(k-1) 130 85+80*(k-1)], ...
                  'GotoTag', src{k});
    end

    sl_const(ss, 'AZP', 'az_prm', 60, 450);

    %  높이를 넉넉히 — MATLAB Function 의 포트는 높이를 균등 분할한 자리에 생긴다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/Wrench'], ...
              'Position', [330 60 510 400]);
    sl_fcn(ss, 'Wrench', wrenchFcn());
    row_feed(ss, 'Wrench', {'Fr_TL','Fr_dL','Fr_TR','Fr_dR','AZP'});

    %  셋을 태그로 낸다. 로깅·대조그림·실시간 그림이 이 이름으로 받는다
    out = {'X_a','Y_a','N_a'};
    for k = 1:3
        p = port_xy(ss, 'Wrench', 'Outport', k);
        sl_goto(ss, out{k}, 600, p(2)-12);
        add_line(ss, sprintf('Wrench/%d', k), ['Go_' out{k} '/1']);
    end

    sl_note(ss, 'nw', ['명령(TL·dL·TR·dR)으로 렌치를 계산해 태그로만 낸다' newline ...
        '오프라인 판에서는 이 계산이 운동모델 안에 있었음' newline ...
        '4단은 운동모델 자리에 가제보가 들어서므로 상자로 떼어 둔 것' newline ...
        '**실측 렌치가 아니다** — 서보 지연과 유체력은 들어 있지 않음' newline ...
        '요구(X_c·Y_c·N_c) 와 견주는 데 쓴다. 실제 거동은 ground truth 가 답함'], ...
        60, 540);
end
