function ss = addPosSign(m, x, y)
%ADDPOSSIGN  방향각 명령을 가제보 서보가 받을 꼴로 바꾼다 (4·5단 공용)
%
%   addPosSign(m, 1600, 280)
%
%   세 가지를 한다
%     1. 변화율 깎기 — svo_rate [rad/s] 보다 빠르게 바뀌지 않게 한다
%     2. 계단참 뭉개기 — 1 차 지연 1/(svo_tau*s + 1)
%     3. 부호 뒤집기 — pos = vrx_pos_sign * delta
%
%   왜 지령을 다듬는가 — **계단 명령에 가제보 서보가 울렁거린다**
%     가제보의 조인트 위치 제어기는 속도 명령으로 도는데, 계단을 주면 넘어갔다
%     되돌아오기를 반복한다. 2026-11-13 실측 (W03_vrx_lite)
%       계단 90 deg (-45 -> +45)  조인트가 75.7 deg 까지 넘어갔다가 수렴
%       계단이 이어지면           ±180 deg 조인트 한계까지 밀려난다
%     설계 전제 ±45 deg 를 **명령에서만** 지켜도 조인트는 그 밖으로 나간다
%
%   변화율만으로는 부족하다 — 깎은 지령도 보내는 간격마다 **계단참**이다
%     45 deg/s 로 깎아 50.0 Hz 로 보냄 (한 칸 0.90 deg)  넘어감 +0.54 deg
%     45 deg/s 로 깎아 12.5 Hz 로 보냄 (한 칸 3.60 deg)  넘어감 +2.07 deg
%     1 차 지연을 더하면 (tau 0.15~0.30 s)              넘어감 +0.00 deg
%   즉 **변화율 + 1 차 지연** 둘을 같이 걸어야 조인트가 한계 안에 머문다
%
%   왜 상자 하나를 따로 두는가
%     본 부록의 $\delta$ 는 **우현 쪽이 양수**다 (1-2 절). 가제보 WAM-V 의
%     `.../pos` 조인트는 반대로 **좌현 쪽이 양수**다. 둘을 섞으면 배가 반대로
%     돌지만 **오류 메시지가 없다** — 각도 부호는 그래서 상자로 드러내 둔다.
%
%   실측 (2026-11-13 · W03_vrx_lite)
%     pos = -90 deg · thrust = +300 N  ->  v = -0.311 m/s (우현으로 밀림)
%     즉 delta = +90 deg 와 같은 거동이다. 그래서 pos = -delta 다.
%
%   부호값은 도면에 박지 않는다 — A3_setup 의 vrx_pos_sign 이다.

    ss = add_subsys(m, 'PosSign', [x y x+150 y+90], ...
                    {'dL','dR'}, {'dL_c','dR_c'}, gnc_colour('ros'));

    sig = {'dL','dR'};
    for k = 1:2
        %  (1) 변화율 깎기 — 서보가 따라올 수 있는 속도까지만
        p = port_xy(ss, sig{k}, 'Outport', 1);
        add_block('simulink/Discontinuities/Rate Limiter', [ss '/Rate' sig{k}], ...
                  'Position', [120 p(2)-20 170 p(2)+20], ...
                  'RisingSlewLimit', 'svo_rate', 'FallingSlewLimit', '-svo_rate');
        add_line(ss, [sig{k} '/1'], ['Rate' sig{k} '/1']);

        %  (2) 계단참 뭉개기 — 1 차 지연. 계단을 넣어도 출력이 입력 범위를 벗지 않는다
        p = port_xy(ss, ['Rate' sig{k}], 'Outport', 1);
        add_block('simulink/Continuous/Transfer Fcn', [ss '/Lag' sig{k}], ...
                  'Position', [220 p(2)-25 290 p(2)+25], ...
                  'Numerator', '[1]', 'Denominator', '[svo_tau 1]');
        add_line(ss, ['Rate' sig{k} '/1'], ['Lag' sig{k} '/1']);

        %  (3) 부호 뒤집기
        p = port_xy(ss, ['Lag' sig{k}], 'Outport', 1);
        sl_gain(ss, ['Sign' sig{k}], 'vrx_pos_sign', 390, p(2)-20);
        add_line(ss, ['Lag' sig{k} '/1'], ['Sign' sig{k} '/1']);

        q = port_xy(ss, ['Sign' sig{k}], 'Outport', 1);
        set_param([ss '/' sig{k} '_c'], 'Position', [520 q(2)-7 550 q(2)+7]);
        add_line(ss, ['Sign' sig{k} '/1'], [sig{k} '_c/1']);
    end

    sl_note(ss, 'np', ['가제보 서보에 보낼 꼴로 세 번 손본다' newline ...
        '(1) 변화율 깎기 svo_rate — 계단을 주면 서보가 울렁거려 ±45 deg 를 넘는다' newline ...
        '      실측: 계단 90 deg 에 조인트 75.7 deg, 이어지면 ±180 deg 까지' newline ...
        '(2) 계단참 뭉개기 1/(svo_tau*s+1) — 깎은 지령도 보내는 간격마다 계단참임' newline ...
        '      실측: 변화율만 깎으면 넘어감 +2.07 deg · 지연을 더하면 +0.00 deg' newline ...
        '(3) 부호 뒤집기 pos = vrx_pos_sign * delta' newline ...
        '      본 부록의 delta 는 우현 양수, 가제보 pos 는 좌현 양수임' newline ...
        '      틀리면 배가 반대로 도는데 **오류 메시지는 없다** (실측으로 -1)'], 60, 300);
end
