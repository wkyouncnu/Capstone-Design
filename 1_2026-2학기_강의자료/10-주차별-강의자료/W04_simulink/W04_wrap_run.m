function T = W04_wrap_run()
% W04_WRAP_RUN  +-180 deg 이음매 — ssa 를 켜고 끄고 두 번 돌려 **돈 각**을 잰다.
%
%   시나리오 (값은 W04_setup 의 6번에 있다)
%     t_wrap1 = 5 s  에 psi_wrap1_deg = 170 deg   이음매를 넘지 않는 큰 선회
%     t_wrap2 = 20 s 에 psi_wrap2_deg = -170 deg  이음매를 넘는다. 60 s 까지
%
%   첫 계단은 두 경우가 **똑같다**. 20 s 의 둘째 계단에서만 갈린다.
%   선수각은 unwrap 한 값으로 찍는다 — 어느 쪽으로 몇 도 돌았는지가 그대로 보인다.
%
%   >> W04_setup
%   >> W04_wrap_run
%
%   만드는 것: img/W04_wrap_two_steps.png

evalin('base', 'W04_setup');              % 기본값 확보. sim 은 base 를 본다
mdl = 'W04_6_wrap'; load_system(mdl);
t1  = evalin('base', 't_wrap1');
t2  = evalin('base', 't_wrap2');
p1  = evalin('base', 'psi_wrap1_deg');
p2  = evalin('base', 'psi_wrap2_deg');
tf  = str2double(get_param(mdl, 'StopTime'));

f  = figure('Name','W04 이음매 - 계단 두 번','Color','w');
ax = axes(f);  hold(ax,'on');  grid(ax,'on');

fprintf('\n  W04 실험 2-11  %g s 에 %g deg, %g s 에 %g deg (%g s 까지)\n', ...
        t1, p1, t2, p2, tf);
fprintf(['    use_ssa   %g s 선수각 [deg]   %g s 선수각 [deg]' ...
         '   %g s 뒤 돈 각 [deg]\n'], t2, tf, t2);

rows = cell(2,1);
for k = 1:2
    us  = 2 - k;                          % 1 을 먼저, 그다음 0
    in  = Simulink.SimulationInput(mdl);
    in  = in.setVariable('use_ssa', us);
    out = sim(in);

    t    = out.log_psi.Time;
    psi  = rad2deg(unwrap(squeeze(out.log_psi.Data)));   % 접지 않은 선수각
    p20  = interp1(t, psi, t2);
    turn = abs(psi(end) - p20);
    fprintf('    %-7g%20.1f%20.1f%22.1f\n', us, p20, psi(end), turn);

    plot(ax, t, psi, 'LineWidth',1.8, 'DisplayName', sprintf('use_ssa = %g', us));
    rows{k} = table(us, p20, psi(end), turn, ...
        'VariableNames', {'use_ssa','psi_at_t2_deg','psi_end_deg','turn_deg'});
end

%  지령 — 계단 두 개의 합. 모델 안의 psi_step1 + psi_step2 와 같은 값이다
cmd = p1*(t >= t1) + (p2 - p1)*(t >= t2);
plot(ax, t, cmd, 'k--', 'LineWidth',1.2, 'DisplayName','지령');
yline(ax,  180, ':', 'HandleVisibility','off');
yline(ax, -180, ':', 'HandleVisibility','off');
title(ax, sprintf('%g deg 는 %g deg 에서 %g deg 만 더 간 곳이다', p2, p1, 360+p2-p1), ...
      'FontWeight','normal');
xlabel(ax, '시간 [s]');  ylabel(ax, '선수각 psi [deg] (unwrap)');
legend(ax, 'Location','southwest', 'Interpreter','none');

exportgraphics(f, fullfile(fileparts(mfilename('fullpath')), 'img', ...
               'W04_wrap_two_steps.png'), 'Resolution', 110);
fprintf('그림: img/W04_wrap_two_steps.png\n');

T = vertcat(rows{:});
end
