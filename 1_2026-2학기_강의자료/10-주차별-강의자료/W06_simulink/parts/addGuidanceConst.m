% =====================================================================
% 1단  Guidance (상수) — 목표 자세를 숫자 세 개로 준다
% =====================================================================
%   사다리의 첫 칸이다. 유도부가 할 일이 없다 — 목표 (x_d, y_d, psi_d) 를
%   상수로 내놓고 gate 를 1 로 열어 둔다. 되먹임 입력도 없으므로 이 블록에는
%   입력 포트가 하나도 없다.
%
%   왜 이렇게 시작하는가
%     위치 제어가 되는지 아닌지는 목표가 움직이지 않을 때 가장 또렷하게 보인다.
%     웨이포인트·단계 전이·도착 판정은 모두 **목표를 어떻게 만드는가**의 문제이고,
%     제어기는 그대로다. 그러므로 제어기를 먼저 혼자 세워 본다.
function addGuidanceConst(m, x, y)
    ss = add_subsys(m, 'Guidance', [x y x+170 y+150], {}, ...
                    {'x_ref','y_ref','psi_ref','gate'}, gnc_colour('guidance'));

    src = {'X_d','x_d'; 'Y_d','y_d'; 'Psi_d','psi_d'; 'Gate','1'};
    out = {'x_ref','y_ref','psi_ref','gate'};
    for k = 1:4
        sl_const(ss, src{k,1}, src{k,2}, 400, 75+60*(k-1));
        add_line(ss, [src{k,1} '/1'], [out{k} '/1']);
    end
    Simulink.BlockDiagram.arrangeSystem(ss);

    sl_note(ss, 'n_g', [ ...
        '목표 자세를 상수로 줌 — x_d · y_d · psi_d (W06_setup 에서 고침)' newline ...
        'gate = 1 로 늘 열려 있음. 도착해도 멈추지 않으므로 제자리 유지가 그대로 보임' newline ...
        '입력 포트가 없음 — 유도부가 되먹임을 쓰지 않는 가장 단순한 꼴'], 400, 400);
end
