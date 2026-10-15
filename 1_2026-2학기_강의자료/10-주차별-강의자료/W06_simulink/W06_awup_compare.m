function W06_awup_compare(stages)
% W06_AWUP_COMPARE  적분기 anti-windup 세 방식을 같은 과업으로 재서 견준다
%
%   >> W06_awup_compare          % 5·7·8단 모두
%   >> W06_awup_compare(5)       % 한 단계만
%
%   무엇을 견주는가 — 모델도 이득도 과업도 그대로 두고 **PI 블록의
%   anti-windup 설정만** 바꿔 돌린다. 물리를 m 으로 다시 짜지 않고 .slx 를
%   그대로 돌리므로, 숫자의 차이는 오직 그 설정에서 온다.
%
%     끔(none)              포화에 닿아도 적분기가 그대로 쌓는다
%     고정(clamping)        포화에 닿으면 적분을 멈춘다. 쌓인 양은 남는다
%     역계산(back-calc)     잘려 나간 몫을 Kb 배 해서 적분기로 되감는다
%
%       v = Kp*e + Ki*I,    dI/dt = e + Kb*( sat(v) - v )
%
%     Kb 의 단위는 1/s 이고 1/Kb 가 되감기는 시간상수다. Astrom 의 권고는
%     Kb = Ki/Kp (= 적분시간 Ti 와 같게) 이고, 6주차 설정으로는 1/3 이다.
%     느슨한 0.1 과 빡빡한 1.0 을 양쪽에 두어 권고값이 가운데인 것을 보인다.
%
%   추진기를 두 가지로 두고 잰다 — wind-up 은 **지령을 못 따라갈 때** 생긴다
%     설계 추진기 500/250 N   배가 지령 속도를 그대로 낸다. 속도 오차가
%                             곧 0 이 되므로 적분기가 쌓을 것이 없다
%     약한 추진기  60/ 40 N   지령 1.5 m/s 를 못 낸다. 오차가 한쪽 부호로
%                             계속 남으므로 적분기가 쌓인다 — wind-up 이다
%     F_max·F_bow_max 를 바꾸면 PI 의 출력 한계('2*F_max'·'F_bow_max')와
%     추력 배분의 한계가 함께 따라온다. 그래서 alloc_prm 만 다시 만든다.
%
%   어느 블록을 건드리는가
%     5·7단  InnerLoop/PI_u · PI_v      (선체고정 — 전후·횡 속도 PI)
%     8단    InnerLoop/PI_xd · PI_yd    (NED — 북·동 속도 PI)
%     parts/addInnerLoop.m 과 addInnerLoopNED.m 이 세운 그 블록이다.
%     Kb 는 블록에 숫자로 박히지 않고 base 의 변수 이름 'Kb' 로 들어가므로,
%     값을 바꿀 때는 base 의 Kb 만 바꿔 쓴다. 다 재고 나면 블록을 되돌리고
%     저장 없이 닫으므로 .slx 파일은 그대로다.
%
%   표의 열
%     완료[s]     gate 가 0 으로 떨어진 시각
%     끝오차[m]   마지막 표본의 목표까지 거리 — R_stop 안이어야 한다
%     지나침[m]   끝오차 - (목표까지 거리의 최솟값). 한 번 지나쳐 되돌아온
%                 몫이다. 쌓인 적분량이 미는 거리라 wind-up 의 민낯이다
%     타성[m]     gate 가 닫힌 뒤 더 간 거리
%     따라감[%]   max|u| / u_max. 100 이면 지령 속도를 낸 것이고, 낮을수록
%                 속도 오차가 한쪽으로 남아 적분기가 쌓을 거리가 길다
%     max|F_B|    선수추진기가 쓴 힘
%
%   W06_setup 이 base 를 비우므로 함수로 둔다 (W06_berth_compare 와 같다).

if nargin < 1, stages = [5 7 8]; end
here = fileparts(mfilename('fullpath'));
cd(here);

SN = containers.Map([5 7 8], {'5단 옆걸음', '7단 전진', '8단 NED'});

%  추진기 두 벌 — 아래 vary 가 참인 쪽만 Kb 를 흔들어 본다
LV = struct('name', {'설계 추진기 500/250 N', '약한 추진기 60/40 N'}, ...
            'F', {500, 60}, 'FB', {250, 40}, 'vary', {false, true});

%  모드 — kb 가 비면 그 이름 그대로, 숫자면 역계산. NaN 은 "Ki/Kp 로" 다
MD = struct( ...
    'name', {'끔 none', '고정 clamping', '역계산 Kb=0.1', '역계산 Kb=Ki/Kp', '역계산 Kb=1.0'}, ...
    'mode', {'none', 'clamping', 'back-calculation', 'back-calculation', 'back-calculation'}, ...
    'kb',   {[], [], 0.1, NaN, 1.0}, ...
    'vary', {false, false, true, false, true});
col = [0.85 0.33 0.10; 0.50 0.50 0.50; 0 0.45 0.74];   % none · clamping · 역계산

R = cell(numel(stages), numel(LV), numel(MD));

for k = 1:numel(stages)
    setappdata(0, 'W06_stage', stages(k));
    setappdata(0, 'W06_skip_run', true);
    evalc('evalin(''base'', ''W06_setup'')');
    assignin('base', 'animate', 0);
    mdl = evalin('base', 'mdl');
    if ~exist([mdl '.slx'], 'file')
        fprintf('\n%s — %s.slx 가 없다. build_w06_models 를 먼저 돌릴 것\n', ...
                SN(stages(k)), mdl);
        continue
    end
    load_system(mdl);
    pid    = find_pi(mdl);
    kb_rec = evalin('base', 'Ki_u/Kp_u');   % 권고값 — 세 PI 가 모두 같다

    fprintf('\n===== %s  (%s · PI %d 개) =====\n', SN(stages(k)), mdl, numel(pid));

    for L = 1:numel(LV)
        set_thrust(LV(L).F, LV(L).FB);
        fprintf('\n  [%s]\n', LV(L).name);
        fprintf('  %-16s %9s %10s %10s %9s %9s %10s\n', ...
                '방식', '완료[s]', '끝오차[m]', '지나침[m]', '타성[m]', '따라감[%]', 'max|F_B|');

        for j = 1:numel(MD)
            if MD(j).vary && ~LV(L).vary, continue; end    % 포화가 없으면 Kb 는 무의미
            kb = MD(j).kb;
            if ~isempty(kb)
                if isnan(kb), kb = kb_rec; end
                assignin('base', 'Kb', kb);
            end
            set_mode(pid, MD(j).mode);

            out = sim(mdl);
            S   = evalc_plot(out);
            Q   = metrics(out, S);
            R{k,L,j} = Q;

            fprintf('  %-16s %9s %10.3f %10.3f %9.3f %9.0f %10.1f\n', ...
                    MD(j).name, fmt(S.t_done), Q.e_final, Q.over, Q.coast, ...
                    Q.follow, Q.max_FB);
        end
    end

    %  건드린 것을 되돌리고 저장 없이 닫는다 — 모델 파일은 그대로 둔다
    set_mode(pid, 'back-calculation');
    close_system(mdl, 0);
end

draw(R, stages, SN, LV, MD, col, here);
end

% =====================================================================
function set_thrust(F, FB)
%  PI 의 출력 한계는 '2*F_max'·'F_bow_max' 라는 **식**으로 들어가 있으므로
%  base 의 변수만 바꾸면 블록을 건드리지 않고 따라온다. alloc_prm 은 숫자
%  벡터라 다시 만들어야 한다 (W06_setup 과 같은 차례로 쌓는다)
assignin('base', 'F_max', F);
assignin('base', 'F_bow_max', FB);
evalin('base', 'alloc_prm = [half_beam; l_bow; F_max; F_bow_max];');
end

% =====================================================================
function pid = find_pi(mdl)
%  PID Controller 는 마스크 서브시스템이다. LookUnderMasks 로 훑으면 그 안의
%  부품('PI_u/I Gain' 따위)까지 걸리므로, 경로가 'PI_xxx' 로 **끝나는** 것만 센다
b = find_system(mdl, 'LookUnderMasks','all', 'FollowLinks','on', ...
                'BlockType','SubSystem');
pid = b(~cellfun(@isempty, regexp(b, '/PI_[a-z]+$', 'once')));
end

% =====================================================================
function set_mode(pid, mode)
for i = 1:numel(pid)
    if strcmp(mode, 'back-calculation')
        set_param(pid{i}, 'AntiWindupMode', 'back-calculation', 'Kb', 'Kb');
    else
        set_param(pid{i}, 'AntiWindupMode', mode);
    end
end
end

% =====================================================================
function Q = metrics(out, S)
%  목표까지 거리의 때때 값에서 지나침과 타성을 뽑는다
dn = evalin('base', 'dock_north');   de = evalin('base', 'dock_east');
t  = out.log_x_n.Time;
x  = out.log_x_n.Data;   y = out.log_y_n.Data;
d  = hypot(x - dn, y - de);

Q.t  = t;   Q.d = d;   Q.x = x;   Q.y = y;
Q.FB = out.log_FB.Data;
Q.e_final = S.e_final;
Q.over    = S.e_final - min(d);
Q.max_FB  = S.max_FB;
Q.follow  = 100 * max(abs(out.log_u.Data)) / evalin('base', 'u_max');

%  gate 가 닫힌 뒤 더 간 거리 — 쌓인 적분량이 밀어 낸 몫이다
i0 = numel(t);
if isfinite(S.t_done)
    f = find(t >= S.t_done, 1);
    if ~isempty(f), i0 = f; end
end
if i0 >= numel(t)
    Q.coast = 0;
else
    Q.coast = sum(hypot(diff(x(i0:end)), diff(y(i0:end))));
end
end

% =====================================================================
function s = fmt(t)
if isfinite(t), s = num2str(t, '%.2f'); else, s = '미완료'; end
end

% =====================================================================
function draw(R, stages, SN, LV, MD, col, here)
%  그림은 세 방식만 겹친다 — Kb 를 흔든 둘은 표에만 둔다
show = [1 2 4];
fig = W06_fig('W06_awup', 'W06  anti-windup — 끔 · 고정 · 역계산', [60 60 1340 700]);
R_stop = evalin('base', 'R_stop');
n = numel(stages);

for k = 1:n
    for L = 1:numel(LV)
        subplot(numel(LV), n, (L-1)*n + k); hold on; grid on;
        for q = 1:numel(show)
            Q = R{k,L,show(q)};
            if isempty(Q), continue; end
            plot(Q.t, Q.d, '-', 'Color', col(q,:), 'LineWidth', 1.4);
        end
        yline(R_stop, 'k:');
        xlabel('시간 [s]'); ylabel('목표까지 거리 [m]');
        title(sprintf('%s — %s', SN(stages(k)), LV(L).name));
        if k == 1 && L == 1
            legend([{MD(show).name}, {'R_{stop}'}], 'Location','northeast', 'FontSize', 7.5);
        end
    end
end

if ~isfolder(fullfile(here, 'img')), mkdir(fullfile(here, 'img')); end
print(fig, '-dpng', '-r110', fullfile(here, 'img', 'W06_awup_compare.png'));
fprintf('\n  그림 저장: img/W06_awup_compare.png\n');
end

% =====================================================================
function S = evalc_plot(out)
%  W06_plot 은 지표를 스스로 찍는다. 표를 가리지 않도록 그 출력만 삼킨다
evalc('S = W06_plot(out, ''awup'');');
close(S.fig);
end
