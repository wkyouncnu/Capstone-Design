function fit_span(sys, blk, kind, y1, yN)
%FIT_SPAN  블록의 첫 포트가 Y1, 마지막 포트가 YN 에 오도록 키와 자리를 맞춘다.
%
%   fit_span(s, 'Sel', 'Outport', 200, 536)     % Bus Selector 의 출력을 Nav 입력에
%   fit_span(m, 'Sc',  'Inport',  150, 430)     % Scope 의 입력을 세 줄 높이에
%
%   왜 필요한가 / why this exists
%       여러 포트를 가진 두 블록을 곧은 선 여러 가닥으로 이으려면 포트 간격이 같아야
%       한다. 블록 높이를 공식으로 계산하면 Simulink 가 포트를 들여놓는 여백이 블록
%       종류마다 달라 몇 px 씩 어긋나고, 선이 전부 완만한 사선이 된다
%       (2026-09-19 PoseSubscriber 의 Sel -> Nav 아홉 가닥).
%
%       그래서 재고, 고치고, 다시 잰다. 두세 번이면 1 px 안으로 들어온다.
%       중간 포트는 끝 두 포트 사이에 고르게 놓이므로 양 끝만 맞추면 된다.
b = [sys '/' blk];
h = get_param(b, 'PortHandles');
n = numel(h.(kind));
for it = 1:6
    p  = get_param(b, 'Position');
    f  = port_xy(sys, blk, kind, 1);
    l  = port_xy(sys, blk, kind, n);
    if abs(f(2)-y1) < 0.5 && abs(l(2)-yN) < 0.5, return, end
    top = p(2) - (f(2) - y1);
    bot = p(4) - (l(2) - yN);
    set_param(b, 'Position', round([p(1) top p(3) bot]));
end
end
