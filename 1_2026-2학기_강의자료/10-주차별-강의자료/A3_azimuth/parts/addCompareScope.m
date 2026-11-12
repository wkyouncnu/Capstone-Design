function addCompareScope(m, pairs, x, y)
%  포트 없는 상자다. 신호는 안에서 From 으로 받는다 (lay_chain 의 'Boxes')
    nAx = size(pairs,1);
    s   = add_subsys(m, 'Observe', [x y x+170 y+90], {}, {}, gnc_colour('logging'));
    sc  = [s '/Scope'];

    %  From 은 25 px 높이에 이름표가 12 px 더 붙는다. 한 칸 안의 두 From 은
    %  25+12 보다 넓게(GAP), 칸과 칸은 GAP+25+12 보다 넓게(ROW) 띄운다
    ROW = 120;  GAP = 60;
    add_block('simulink/Sinks/Scope', sc, 'Position',[360 60 410 60+ROW*nAx]);
    set_param(sc, 'NumInputPorts', num2str(nAx));
    for i = 1:nAx
        ref = pairs{i,1};  act = pairs{i,2};  yi = 60 + ROW*(i-1);
        if isempty(ref)
            nm = from_name(s, act);
            add_block('simulink/Signal Routing/From', [s '/' nm], ...
                      'GotoTag', act, 'Position',[60 yi 130 yi+25]);
            add_line(s, [nm '/1'], sprintf('Scope/%d', i), 'autorouting','on');
        else
            add_block('simulink/Signal Routing/Mux', sprintf('%s/MuxSc%d', s, i), ...
                      'Inputs','2', 'Position',[250 yi 255 yi+GAP+25]);
            n1 = from_name(s, ref);
            add_block('simulink/Signal Routing/From', [s '/' n1], ...
                      'GotoTag', ref, 'Position',[60 yi 130 yi+25]);
            n2 = from_name(s, act);
            add_block('simulink/Signal Routing/From', [s '/' n2], ...
                      'GotoTag', act, 'Position',[60 yi+GAP 130 yi+GAP+25]);
            add_line(s, [n1 '/1'], sprintf('MuxSc%d/1', i), 'autorouting','on');
            add_line(s, [n2 '/1'], sprintf('MuxSc%d/2', i), 'autorouting','on');
            add_line(s, sprintf('MuxSc%d/1', i), sprintf('Scope/%d', i), 'autorouting','on');
        end
    end
end
