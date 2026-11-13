function [chain, boxes] = buildA3Stage5(m)
% 5단  A3_5_tilt — 서보 틸팅 확인. **4단보다 먼저 돌린다**
%
%   무엇을 가리려고 만든 단인가
%     4단(VRX 연동)이 움직이지 않을 때, 원인은 늘 셋 중 하나다.
%       (1) 토픽 이름이 틀렸다      (2) 도메인 ID 가 다르다
%       (3) 제어기·배분기가 틀렸다
%     이 모델에는 제어기도 배분기도 운동모델도 없다. 시간표대로 각도만 낸다.
%     그래서 가제보의 서보가 돌면 (1)·(2) 가 맞은 것이고, 돌지 않으면 (3) 은
%     볼 필요도 없다. **원인을 반으로 자르는 모델**이다.
%
%   사슬
%     TiltCmd  ->  PosSign  ->  CmdPublisher  ->  (가제보)
%     시간표      부호 맞춤     토픽 넷
%
%   무엇을 보아야 하는가
%     가제보 화면 — 선미 두 추진기가 표대로 돌아간다 (추력 0 N 이라 배는 제자리)
%     log_dL · log_dR — ±60 deg 줄이 **±45 deg 로 깎여** 평평해진다
%     돌지 않으면 — A3_5_tilt_run 의 1부(순수 MATLAB 발행)가 토픽을 다시 짚는다
%
%   실행
%     >> A3_5_tilt_run      (1부 토픽 확인 -> 2부 Simulink 시간표)
    sl_fresh(m);
    sl_solver(m, 'T_run');

    addTiltCmd(m,  250, 60);
    addPosSign(m,  700, 60);

    %  토픽 넷 — 순서가 곧 입력 이름 순서다. 추력 둘 + 방향각 둘
    %    A3_setup 의 vrx_thr_topic · vrx_pos_topic 과 **같은 이름**을 쓴다.
    %    문자열을 여기 박지 않는 이유 — 토픽이 바뀌면 고칠 자리가 둘이 된다
    tp = {evalin('base','vrx_thr_topic{1}'), evalin('base','vrx_pos_topic{1}'), ...
          evalin('base','vrx_thr_topic{2}'), evalin('base','vrx_pos_topic{2}')};
    add_cmd_publisher(m, [1150 60], tp, 'Ts_ctrl', {'TL','dL','TR','dR'});

    %  배선 — 각도만 PosSign 을 거친다
    add_line(m, 'TiltCmd/2', 'PosSign/1', 'autorouting','on');
    add_line(m, 'TiltCmd/4', 'PosSign/2', 'autorouting','on');
    add_line(m, 'PosSign/1', 'CmdPublisher/2', 'autorouting','on');
    add_line(m, 'PosSign/2', 'CmdPublisher/4', 'autorouting','on');

    %  로깅용 태그 — **출발 포트 바로 옆**에 떨어뜨린다. 멀리 두면 선이 뒤
    %  상자들을 관통한다 (drop_tag 주석 참조)
    t = {'TL','dL','TR','dR'};
    for k = 1:4
        drop_tag(m, 'TiltCmd', k, t{k}, 60*k);
    end

    %  추력은 PosSign 을 거치지 않는다. 그렇다고 TiltCmd 에서 직선으로 끌면
    %  그 선이 PosSign 상자를 **관통한다** — 태그로 건너뛴다
    for k = [1 3]
        nm = sl_from(m, t{k}, 1050, 60 + 45*(k-1));
        add_line(m, [nm '/1'], sprintf('CmdPublisher/%d', k), 'autorouting','on');
    end

    add_logging_box(m, t, t, [1900 60], 'Ts_ctrl');

    sl_note(m, 'n5', ['A3 5단  —  서보 틸팅 확인 (4단보다 먼저 돌린다)' newline ...
        '제어기·배분기·운동모델이 없음. 시간표대로 **각도만** 낸다' newline ...
        '가제보의 서보가 돌면 토픽과 도메인이 맞은 것임' newline ...
        '±45 deg 는 가제보가 아니라 TiltCmd 가 거는 설계 한계임' newline ...
        '가제보를 먼저 띄울 것 — W03_vrx_lite 의 run_vrx.sh lite' newline ...
        '실행 전: A3_setup (stage = 5)  또는  A3_5_tilt_run'], 250, -180);

    save_system(m);  close_system(m);
    chain = {'TiltCmd','PosSign','CmdPublisher'};
    boxes = {'Logging'};
end
