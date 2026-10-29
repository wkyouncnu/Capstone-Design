function A2_gui_report()
%A2_GUI_REPORT  5단 — 실행이 끝난 뒤 측정값을 표로 낸다
%
%   >> A2_gui_report
%
%   '정지' 버튼을 누르면 자동으로 불린다. 손으로 다시 보고 싶을 때도 쓴다
%
%   어디서 값을 읽는가
%     모델을 `sim()` 으로 돌리지 않고 **버튼으로** 돌렸으므로 결과 객체를
%     돌려받을 자리가 없다. 그래서 모델에
%
%       ReturnWorkspaceOutputs      = 'on'
%       ReturnWorkspaceOutputsName  = 'out'
%
%     을 걸어 두었다. 실행이 멈추면 Simulink 가 베이스 워크스페이스에
%     `out` 이라는 변수를 만들어 로그를 넣어 준다 (`A2_5_gui_done` 이 설정한다)
%
%   왜 측정까지 하는가
%     "잘 가는 것처럼 보였다" 는 결과가 아니다. 과제는 숫자로 제출한다
%     -> [[측정하지-않은-성공은-성공이-아니다]]

    if ~evalin('base', 'exist(''out'', ''var'')')
        fprintf(['\n측정할 로그가 없다.\n' ...
                 '  - 아직 한 번도 돌리지 않았거나\n' ...
                 '  - 출발한 직후에 정지해 로그가 비었을 수 있다\n']);
        return
    end

    out      = evalin('base', 'out');
    wp_north = evalin('base', 'wp_north');
    wp_east  = evalin('base', 'wp_east');
    n_wp     = double(evalin('base', 'n_wp'));
    R_LOS    = evalin('base', 'R_LOS');
    Ts_ctrl  = evalin('base', 'Ts_ctrl');
    u_ref    = evalin('base', 'u_ref');

    if ~isprop(out, 'log_x_n') && ~isfield(out, 'log_x_n')
        fprintf('\nout 에 로그가 없다 — Logging 블록을 확인할 것\n');
        return
    end

    t  = out.log_x_n.Time;
    xs = out.log_x_n.Data;
    ys = out.log_y_n.Data;
    ye = out.log_y_e.Data;
    gt = out.log_gate.Data;
    ps = out.log_psi.Data;
    pr = out.log_psi_ref.Data;
    us = out.log_u.Data;

    if numel(t) < 2
        fprintf('\n로그가 %d 점뿐이다 — 더 돌린 뒤 다시 볼 것\n', numel(t));
        return
    end

    %  gate 가 0 으로 떨어진 **마지막** 순간까지를 주행 구간으로 본다.
    %  5단은 임무가 끝난 뒤에도 모델이 계속 돌고, 점을 더 찍으면 다시 1 이 된다.
    %  그래서 4단처럼 '처음 0 이 된 자리' 로 자르면 뒤의 주행이 통째로 빠진다
    k_last = find(gt > 0.5, 1, 'last');
    if isempty(k_last)
        fprintf('\ngate 가 한 번도 1 이 아니었다 — 웨이포인트를 찍고 출발할 것\n');
        return
    end
    k_end = min(k_last + 1, numel(t));
    k_ss  = min(round(20/Ts_ctrl), k_end);      % 초기 수렴 20 초를 뺀 구간의 시작

    e_psi = atan2(sin(pr - ps), cos(pr - ps)) * 180/pi;   % 헤딩 오차 [deg], ssa

    %  계획 경로 길이는 **마지막 임무 기준**이다 (중간에 점을 더 찍었으면 그만큼 길다)
    leg_len = hypot(diff(wp_north(1:n_wp)), diff(wp_east(1:n_wp)));
    L_total = sum(leg_len);

    fprintf('\n[측정]  구간 = 처음부터 gate 가 마지막으로 1 이었던 시각까지\n');
    fprintf('  기록 길이          : %.1f s  (주행 구간 %.1f s)\n', t(end), t(k_end));
    fprintf('  계획 경로 길이     : %.2f m  (점 %d 개, 최소 소요 %.1f s)\n', ...
            L_total, n_wp, L_total/u_ref);
    fprintf('  평균 |y_e|         : 전 구간 %.3f m / 초기 20 s 제외 %.3f m\n', ...
            mean(abs(ye(1:k_end))), mean(abs(ye(k_ss:k_end))));
    fprintf('  최대 |y_e|         : %.3f m\n', max(abs(ye(1:k_end))));
    fprintf('  헤딩 오차 RMS      : 전 구간 %.2f deg / 초기 20 s 제외 %.2f deg\n', ...
            rms(e_psi(1:k_end)), rms(e_psi(k_ss:k_end)));
    fprintf('  최대 |헤딩 오차|   : %.2f deg\n', max(abs(e_psi(1:k_end))));
    fprintf('  평균 속도          : %.3f m/s  (지령 %.2f m/s)\n', ...
            mean(us(k_ss:k_end)), u_ref);

    %  최근접 거리는 **그 점을 향해 떠난 뒤**로만 찾는다.
    %  전 구간에서 찾으면 출발점으로 돌아오는 임무에서 마지막 점의 최근접이
    %  t = 0 (아직 떠나지도 않은 자리) 에서 잡힌다.
    %  한편 구간이 바뀌는 순간(d - x_e < R)에 끊으면 값이 전부 R 로 나와
    %  "정말 가까이 갔는가" 를 못 본다 -> 떠난 뒤 기록 끝까지를 본다
    wi = out.log_wp_idx.Data;

    fprintf('\n[웨이포인트 최근접 거리]\n');
    fprintf('  %3s  %12s  %12s\n', '#', '최근접[m]', '그때[s]');
    for k = 1:n_wp
        if k == 1
            sel = 1;                                 % 출발점 — 떠난 자리다
        else
            i0 = find(wi(1:k_end) == k-1, 1);        % k-1 번 구간 = k 번째 점을 향해 떠난 때
            if isempty(i0), i0 = 1; end              % 아직 가지 않은 점
            sel = (i0:k_end).';
        end
        d = hypot(xs(sel) - wp_north(k), ys(sel) - wp_east(k));
        [dmin, imin] = min(d);
        fprintf('  %3d  %12.2f  %12.1f\n', k-1, dmin, t(sel(imin)));
    end
    fprintf('  수락반경 R = %g m —  R 보다 큰 점은 지나치지 않고 돌아 나간 것이다\n', ...
            R_LOS);

    %  실행 중에 점을 더 찍었는가 — gate 가 0 에서 1 로 **다시** 올라간 자리
    up = find(diff(gt > 0.5) > 0);
    if ~isempty(up)
        fprintf('\n[임무 변경]  실행 중에 점을 더 찍어 다시 출발한 횟수 = %d\n', numel(up));
        for k = 1:numel(up)
            fprintf('  %d 회 : t = %.1f s 에 gate 가 0 -> 1\n', k, t(up(k)+1));
        end
        fprintf('  이것이 5단의 요점이다 — 임무가 끝난 뒤에도 배가 다시 움직였다\n');
    end
end
