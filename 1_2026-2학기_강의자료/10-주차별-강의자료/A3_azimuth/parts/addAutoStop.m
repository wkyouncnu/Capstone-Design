function addAutoStop(m, x, y)
%  과업이 끝난 뒤 stop_hold 초를 더 돌고 스스로 멈춘다.
%  포트 없는 상자여야 lay_chain 의 'Boxes' 가 자리를 잡아 준다
    s = add_subsys(m, 'AutoStop', [x y x+150 y+80], {}, {}, gnc_colour('logging'));

    add_block('simulink/Signal Routing/From', [s '/Fr_gate'], ...
              'GotoTag','gate', 'Position',[40 100 110 125]);
    %  gate 가 1 인 동안(아직 과업 중) 적분기를 0 에 묶는다. 0 이 되면 초를 센다.
    %  'level' 이라야 처음부터 gate = 1 일 때도 리셋이 걸린다 ('rising' 은 안 걸린다)
    add_block('simulink/Sources/Constant', [s '/One'], ...
              'Value','1', 'Position',[120 40 170 70]);
    add_block('simulink/Continuous/Integrator', [s '/HeldFor'], ...
              'ExternalReset','level', 'InitialCondition','0', ...
              'Position',[240 95 280 135]);
    add_block('simulink/Sources/Constant', [s '/Hold'], ...
              'Value','stop_hold', 'Position',[240 190 340 220]);
    add_block('simulink/Logic and Bit Operations/Relational Operator', [s '/Done'], ...
              'Operator','>=', 'Position',[380 110 410 140]);
    add_block('simulink/Sinks/Stop Simulation', [s '/StopSim'], ...
              'Position',[470 110 510 140]);

    add_line(s,'One/1','HeldFor/1','autorouting','on');
    add_line(s,'Fr_gate/1','HeldFor/2','autorouting','on');
    add_line(s,'HeldFor/1','Done/1','autorouting','on');
    add_line(s,'Hold/1','Done/2','autorouting','on');
    add_line(s,'Done/1','StopSim/1','autorouting','on');
end
