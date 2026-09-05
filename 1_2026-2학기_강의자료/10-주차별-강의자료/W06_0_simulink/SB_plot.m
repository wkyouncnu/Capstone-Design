function SB_plot(out)
% SB_PLOT  SB6_param 실행 결과를 그린다.
%
%   로깅된 신호를 꺼내 쓰는 방법을 보여 주는 것이 목적이다.
%
%   >> SB_setup
%   >> out = sim('SB6_param_done');
%   >> SB_plot(out)

    % (1) 신호 로깅으로 꺼내기 — 신호선에 y 라는 이름을 붙여 두었다
    sig = out.logsout.getElement('y');
    t   = sig.Values.Time;
    y   = sig.Values.Data;

    figure('Name','SB6 결과','Color','w');
    plot(t, y, 'LineWidth', 1.4); grid on;
    xlabel('시간 [s]'); ylabel('y');
    title(sprintf('로깅 신호 y  (표본 %d개)', numel(t)));

    fprintf('\n[신호 로깅]  out.logsout.getElement(''y'')\n');
    fprintf('  표본 개수 : %d\n', numel(t));
    fprintf('  최댓값    : %.4f\n', max(y));
    fprintf('  최솟값    : %.4f\n', min(y));

    % (2) To Workspace 로 꺼내기 — 같은 신호를 다른 방법으로
    if isprop(out,'y_ts') || ismember('y_ts', out.who)
        fprintf('\n[To Workspace]  out.y_ts\n');
        fprintf('  표본 개수 : %d\n', numel(out.y_ts.Time));
    end
end
