function A2_6_prep(mdl)
%A2_6_PREP  6단 모델의 InitFcn — 실시간 창을 **첫 스텝 전에** 세워 둔다
%
%   A2_gps.slx 의 InitFcn 이 이것을 부른다. 직접 부를 일은 없다.
%
%   왜 이것이 필요한가
%     Animate 블록이 첫 스텝에서 창을 만들면, 그림이 뜨는 1~3 초 동안 모델이
%     멎는다. 오프라인이면 아무 일도 아니지만 VRX 와 같이 돌 때는 다르다 —
%     가제보는 모델이 멎은 줄 모르고 직전 추력 명령을 계속 쥐고 있어서 배는
%     그동안 계속 간다. 6주차 4단에서 모델 시간 0.4 s 사이에 배가 9.4 m 를
%     움직여, m 파일이 찍은 궤적과 실제가 어긋났다 (커밋 a799189)
%
%     그래서 창을 만드는 일은 시뮬레이션 밖에서 미리 끝낸다. 첫 스텝의
%     Animate 호출은 이미 서 있는 창에 점 하나를 보태는 일만 하게 된다
%
%   하는 일 세 가지
%     1. 지난 실행이 남긴 out 을 베이스에서 지운다 (헷갈리는 결과를 막는다)
%     2. 설정이 올라와 있는지 확인한다 — 없으면 바로 멈춘다
%     3. A2_animate_map 을 t = 0 으로 한 번 불러 창을 세우고 다 그려 둔다

    if nargin < 1, mdl = bdroot; end

    % --- 1. 지난 결과 지우기 ------------------------------------------
    if evalin('base', 'exist(''out'',''var'')')
        evalin('base', 'clear out');
    end

    % --- 2. 설정 확인 --------------------------------------------------
    need = {'lla0', 'wp_north', 'wp_east', 'R_LOS', 'u_ref', 'animate'};
    miss = need(~cellfun(@(v) evalin('base', ...
                 sprintf('exist(''%s'',''var'') == 1', v)), need));
    if ~isempty(miss)
        error('A2:nosetup', ...
              ['%s 를 돌리기 전에 설정을 올려야 한다.\n' ...
               '  없는 변수 : %s\n' ...
               '  >> A2_6_gps_setup'], mdl, strjoin(miss, ', '));
    end

    if ~evalin('base', 'animate')
        return      % 그림을 안 그리는 실행 — 세울 창도 없다
    end

    % --- 3. 창 세우기 --------------------------------------------------
    %  출발점은 A2_6_run 이 가제보에서 읽어 베이스에 넣어 둔다. 오프라인으로
    %  돌릴 때는 없으므로 경로 원점을 쓴다
    if evalin('base', 'exist(''start_n'',''var'') == 1')
        x0n = evalin('base', 'start_n');
        y0n = evalin('base', 'start_e');
    else
        x0n = 0;  y0n = 0;
    end
    psi0 = evalin('base', 'psi_init');

    %  인자 열한 개는 A2_animate_map 의 서명 그대로다
    %  (x_n, y_n, psi, psi_ref, y_e, u, gate, FL, FR, wp_idx, t)
    %  t = 0 으로 부르면 함수가 새 실행으로 보아 창을 만들고 한 번 다 그린다.
    %  첫 스텝도 t = 0 이지만 그때는 이미 만들어진 창에 덧붙이기만 한다
    A2_animate_map(x0n, y0n, psi0, psi0, 0, 0, 1, 0, 0, 1, 0);
    drawnow;

    f = A2_animate_map();
    if isempty(f) || ~isvalid(f)
        error('A2:nofig', '실시간 창을 세우지 못했다 — A2_animate_map 을 확인할 것');
    end
    fprintf('[InitFcn] 실시간 창 준비 완료 — 출발점 (북 %.2f, 동 %.2f)\n', x0n, y0n);
end
