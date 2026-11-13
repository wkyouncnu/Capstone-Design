function ss = addTiltCmd(m, x, y)
%ADDTILTCMD  시간표대로 방향각만 바꿔 내는 상자 — 5단(서보 틸팅 확인)이 쓴다
%
%   addTiltCmd(m, 1150, 280)
%
%   무엇을 하는가
%     A3_setup 의 tilt_deg 표를 한 줄씩 tilt_hold 초 동안 내보낸다. 추력은
%     tilt_thrust 로 고정한다 (기본 0 N — 배가 제자리에 있어야 각도만 보인다).
%
%   왜 따로 만드는가
%     4단 VRX 모델이 돌지 않을 때, 원인이 **토픽인지 제어기인지** 가리기 위한
%     상자다. 제어기도 배분기도 없이 각도 명령만 보내므로, 가제보의 서보가
%     돌면 토픽과 도메인이 맞은 것이고, 돌지 않으면 그 둘이 틀린 것이다.
%
%   한계를 두 번 깎는 이유
%     tilt_deg 표에는 ±60 deg 줄이 **일부러** 들어 있다. 가제보 조인트 자체는
%     ±180 deg 까지 돌지만, 본 과목은 설계 전제로 ±45 deg 를 쓴다. 그 전제를
%     모델이 지키는지 눈으로 보이려면, 한계 밖 요구를 넣고 깎이는 것을 보아야
%     한다. 깎는 자리는 TiltFcn 의 한 줄 — `d = max(min(d,dmax),-dmax)` 다.

    ss = add_subsys(m, 'TiltCmd', [x y x+190 y+160], ...
                    {}, {'TL','dL','TR','dR'}, gnc_colour('guidance'));

    %  시간 — 표의 어느 줄인지를 고르는 데 쓴다
    add_block('simulink/Sources/Clock', [ss '/Clock'], ...
              'Position', [60 100 90 130]);

    sl_const(ss, 'Q',   'tilt_q', 60, 250);
    sl_const(ss, 'DMX', 'd_max',  60, 320);

    %  높이를 넉넉히 — MATLAB Function 의 포트는 높이를 균등 분할한 자리에 생긴다
    add_block('simulink/User-Defined Functions/MATLAB Function', [ss '/TiltFcn'], ...
              'Position', [330 60 510 380]);
    sl_fcn(ss, 'TiltFcn', tiltFcn());
    row_feed(ss, 'TiltFcn', {'Clock','Q','DMX'});

    %  변화율은 여기서 깎지 않는다 — PosSign 상자가 svo_rate 로 한 번만 깎는다
    %    이 상자는 **표를 그대로 내는 것**이 일이다. 계단 명령이 그대로 나가야
    %    "계단을 주면 서보가 울렁거린다" 는 것을 PosSign 앞뒤로 견줄 수 있다
    outs = {'TL','TiltFcn',1; 'dL','TiltFcn',2; 'TR','TiltFcn',3; 'dR','TiltFcn',4};
    for k = 1:4
        p = port_xy(ss, outs{k,2}, 'Outport', outs{k,3});
        set_param([ss '/' outs{k,1}], 'Position', [760 p(2)-7 790 p(2)+7]);
        add_line(ss, sprintf('%s/%d', outs{k,2}, outs{k,3}), [outs{k,1} '/1'], ...
                 'autorouting','on');
    end

    sl_note(ss, 'nt', ['시간표대로 각도만 바꿔 낸다 — 제어기도 배분기도 없다' newline ...
        'tilt_q = [유지시간; 추력; 줄 수; 좌·우 각도...]  (A3_setup)' newline ...
        '±45 deg 는 가제보가 아니라 **이 상자**가 거는 한계임' newline ...
        '표의 ±60 deg 줄은 깎이는 것을 보이려고 일부러 넣은 것' newline ...
        '변화율은 다음 상자(PosSign) 가 깎는다 — 여기서는 계단으로 낸다'], 60, 420);
end


function c = tiltFcn()
%  블록 안에 들어가는 코드. 표를 시간으로 훑어 한 줄을 고르고 한계로 깎는다
c = strjoin({
'function [TL, dL, TR, dR] = TiltFcn(t, q, dmax)'
'%#codegen'
'%  시간표대로 방향각을 내는 함수 — 추력은 상수, 각도만 바뀐다'
'%    q(1)        한 자세를 유지하는 시간 [s]'
'%    q(2)        그 동안 줄 추력 [N]'
'%    q(3)        표의 줄 수 n'
'%    q(4:3+2n)   [좌현; 우현] 각도가 줄 순서대로 [rad]'
''
'hold_t = q(1);'
'T_cmd  = q(2);'
'n      = q(3);'
''
'%  몇 번째 줄인가 — 마지막 줄을 지나면 그 줄에 머문다 (중립으로 끝난다)'
'i = floor(t/hold_t) + 1;'
'if i < 1, i = 1; end'
'if i > n, i = n; end'
''
'%  q 안에서 그 줄이 시작하는 자리. 줄 하나가 두 칸을 쓴다'
'j  = 3 + 2*(i-1);'
'dL = q(j+1);'
'dR = q(j+2);'
''
'%  **설계 한계** — 가제보 조인트에는 없는 한계를 여기서 건다'
'%    표의 ±60 deg 줄이 ±45 deg 로 깎이는 것이 이 두 줄이다'
'dL = max(min(dL, dmax), -dmax);'
'dR = max(min(dR, dmax), -dmax);'
''
'TL = T_cmd;'
'TR = T_cmd;'
'end'
}, newline);
end
