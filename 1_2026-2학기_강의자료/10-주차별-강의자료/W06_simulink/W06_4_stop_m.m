% W06_4_STOP_M  4단을 m 파일 한 장으로 — 도착을 판정하고 스스로 멈춘다
%
%   >> W06_4_stop_m
%
%   무엇을 보는가
%     목표는 3단과 같다 (북 30 m, 동 20 m, 선수각 45 deg). 같은 목표를 두 번 돌린다.
%
%       stop_on = 1   도착 판정을 켠다 — 목표에 닿으면 gate 가 닫히고,
%                     stop_hold 초 뒤 계산이 스스로 끝난다
%       stop_on = 0   gate 가 늘 1 이다 — 3단(W06_3_thrust)과 같다
%
%     3단까지 배는 목표에 닿아도 속도 지령을 계속 받았다. 자리를 "잡고" 있었던
%     것이고 멈춘 것이 아니었다. 4단에서 처음으로 멈추는 법이 생긴다.
%
%   도착 판정과 래치
%     도착 = 거리가 R_stop 안이고 선수각 오차가 5 deg 안
%
%         d = hypot(x_d - x_n, y_d - y_n)
%         e = ssa(psi_d - psi)
%         도착하면 phase 가 0 -> 1,  gate = (phase < 1) 이 1 -> 0
%
%     phase 는 한 번 올라가면 내려오지 않는다. 래치가 없으면 gate 가 닫힌 뒤
%     배가 관성으로 조금 더 나가 거리가 R_stop 을 다시 넘고, gate 가 열렸다
%     닫혔다 깜빡인다.
%
%   한 스텝 전 값을 쓰는 까닭 (Simulink 의 Unit Delay 에 해당한다)
%     phase 는 자기 자신의 입력이다. 그대로 되먹이면 대수 루프가 되어 Simulink
%     가 풀지 못한다. 모델은 Unit Delay 로 한 스텝 전 값을 쓴다 — 표본 간격이
%     고정 스텝(Ts_ctrl)과 같다.
%
%     이 파일도 같게 맞춘다. ph_prev 는 **주요 스텝 경계에서만** 갱신하고,
%     RK4 의 네 소단계에서는 ph_prev 를 붙들어 둔 채 그 소단계의 상태로 d·e 만
%     다시 잰다. 다음 스텝에 넘길 값은 소단계 첫째(j = 1)에서 나온 값이다 —
%     Unit Delay 가 표본 시각의 값을 집어 가는 것과 같다.
%
%   AutoStop (모델의 AutoStop 상자에 해당한다)
%     gate 가 1 인 동안 적분기가 0 에 묶여 있고(level 리셋), 0 이 되면 1 을
%     적분해 초를 센다. 그 값이 stop_hold 에 이르면 Stop Simulation 이 돈다.
%     1 을 적분하는 것이므로 RK4 로도 한 스텝에 정확히 h 가 더해진다 —
%     이 파일은 held = held + h 로 적는다.
%
%     그래서 stop_on = 1 벌은 T_run 까지 가지 않고 표본 수가 줄어든다. 두 벌을
%     맞댈 때도, Simulink 와 맞댈 때도 **짧은 쪽의 표본 수만큼만** 맞댄다.
%
%   상태는 3단과 같은 11개다
%     배 6 + 속도 PI 적분기 2 + 추진기 회전수 3. phase 와 held 는 미분방정식이
%     아니라 스텝 경계에서 갱신되는 값이라 RK4 묶음에 들어가지 않는다.
%
%   이 파일의 규칙 (1~3단과 같다)
%     자체 함수 없음 · 설정은 W06_setup 에서만 · 적분은 RK4, 간격은 Ts_ctrl

%% ====================================================================
%  1. 설정 — 3단과 같은 목표를 쓴다 (W06_setup 의 stage = 1 그대로,
%     1·3·4단은 목표 자세가 같다)
% =====================================================================
setappdata(0, 'W06_skip_run', true);
W06_setup;

N_lim = 2*F_max*half_beam + F_bow_max*l_bow;

h  = Ts_ctrl;
tt = (0:h:T_run)';
nt = numel(tt);

stop_list = [1 0];              % 도착 판정 켬 · 끔
REC = cell(1,2);                % 배 상태 기록 (6개)
FRC = cell(1,2);                % 실제 추력 기록
RPM = cell(1,2);                % 회전수 기록
GPH = cell(1,2);                % gate · phase 기록
NEN = zeros(1,2);               % 벌마다 실제로 돈 표본 수
T_HIT = nan(1,2);               % gate 가 닫힌 시각

%% ====================================================================
%  2. 두 벌을 차례로 돌린다 — 상태 11개를 RK4 로 함께 적분한다
%     s(1:6) 배 · z(1:2) 속도 PI 적분기 · g(1:3) 추진기 회전수
%     ph_prev(래치) 와 held(정지 타이머) 는 스텝 경계에서만 움직인다
% =====================================================================
for i = 1:2
    stop_on = stop_list(i);
    s = x0;
    z = [0; 0];
    g = [0; 0; 0];
    ph_prev  = 0;               % Unit Delay 의 InitialCondition
    held     = 0;               % AutoStop 적분기의 InitialCondition
    gate_pre = 1;               % 한 스텝 전 gate — 리셋이 풀린 순간을 가린다
    rec = zeros(nt, 6);
    frc = zeros(nt, 3);
    rpm = zeros(nt, 3);
    gph = zeros(nt, 2);
    K   = zeros(11, 4);
    n_end = nt;

    for k = 1:nt
        rec(k,:) = s';

        for j = 1:4
            %  RK4 의 네 지점 — 세 묶음을 같은 계수로 옮긴다
            switch j
                case 1, q = s;                 w = z;                 p = g;
                case 2, q = s + h/2*K(1:6,1);  w = z + h/2*K(7:8,1);  p = g + h/2*K(9:11,1);
                case 3, q = s + h/2*K(1:6,2);  w = z + h/2*K(7:8,2);  p = g + h/2*K(9:11,2);
                case 4, q = s + h  *K(1:6,3);  w = z + h  *K(7:8,3);  p = g + h  *K(9:11,3);
            end
            u = q(1);  v = q(2);  r = q(3);  x_n = q(4);  y_n = q(5);  psi = q(6);

            % --- 유도 : 도착 판정 (TaskHold 와 같은 식) -----------------
            %     ph_prev 는 이 스텝 동안 고정이고, 거리와 선수각 오차만
            %     소단계 상태로 다시 잰다
            d_go  = hypot(x_d - x_n, y_d - y_n);
            e_psi = atan2(sin(psi_d - psi), cos(psi_d - psi));
            ph = ph_prev;
            if stop_on && ph < 1 && d_go < R_stop && abs(e_psi) < 5*pi/180
                ph = 1;                 % 도착 — 한 번 올라가면 내려오지 않는다
            end
            gate = double(ph < 1);

            % --- 바깥 고리 : 위치 오차 -> 속도 지령 --------------------
            e_N = x_d - x_n;
            e_E = y_d - y_n;
            e_x =  cos(psi)*e_N + sin(psi)*e_E;
            e_y = -sin(psi)*e_N + cos(psi)*e_E;
            u_cmd = gate * min(max(Kp_x*e_x, -u_max), u_max);
            v_cmd = gate * min(max(Kp_y*e_y, -v_max), v_max);

            % --- 안쪽 고리 : 속도 오차 -> 추력 (PI + clamping) ---------
            e_u = u_cmd - u;
            e_v = v_cmd - v;
            X_pre = Kp_u*e_u + Ki_u*w(1);
            Y_pre = Kp_v*e_v + Ki_v*w(2);
            X = min(max(X_pre, -2*F_max),   2*F_max);
            Y = min(max(Y_pre, -F_bow_max), F_bow_max);

            dz = [e_u; e_v];
            if X ~= X_pre && sign(e_u) == sign(X_pre - X), dz(1) = 0; end
            if Y ~= Y_pre && sign(e_v) == sign(Y_pre - Y), dz(2) = 0; end

            % --- 선수각 P-D -------------------------------------------
            N_pre = Kp_psi*e_psi - Kd_psi*r;
            N_mom = min(max(N_pre, -N_lim), N_lim);

            % --- 추력 배분 : 여기까지가 "지령" 이다 --------------------
            FB_c  = min(max(Y, -F_bow_max), F_bow_max);
            M_yaw = N_mom - l_bow*FB_c;
            FL_c  = min(max(X/2 + M_yaw/(2*half_beam), -F_max), F_max);
            FR_c  = min(max(X/2 - M_yaw/(2*half_beam), -F_max), F_max);

            % --- 추진기 : 지령 추력 -> 회전수 -> 지연 -> 실제 추력 ------
            F_c   = [FL_c; FR_c; FB_c];
            n_cmd = sign(F_c) .* sqrt(abs(F_c)/k_prop);
            n_cmd = min(max(n_cmd, -n_max), n_max);
            dg    = (n_cmd - p)/tau_n;              % MotorLag
            F     = k_prop * p .* abs(p);           % n2F
            FL = F(1);  FR = F(2);  FB = F(3);

            % --- 운동방정식 --------------------------------------------
            u_c = current_speed*cos(beta_c - psi);
            v_c = current_speed*sin(beta_c - psi);
            u_r = u - u_c;
            v_r = v - v_c;
            D_x = (Xu + Xuu*abs(u_r))*u_r;
            D_y = (Yv + Yvv*abs(v_r))*v_r;
            D_n = (Nr + Nrr*abs(r))*r;

            K(:,j) = [ (FL + FR - D_x)/m_usv + v*r
                       (FB      - D_y)/m_usv - u*r
                       ((FL - FR)*half_beam + l_bow*FB - D_n)/Izz
                       u*cos(psi) - v*sin(psi)
                       u*sin(psi) + v*cos(psi)
                       r
                       dz
                       dg ];

            if j == 1
                frc(k,:) = [FL FR FB];
                rpm(k,:) = p';
                gph(k,:) = [gate ph];
                ph_now   = ph;          % Unit Delay 가 집어 갈 값
                gate_now = gate;
            end
        end

        % --- AutoStop : gate 가 0 인 동안만 초를 센다 -------------------
        if gate_now ~= 0
            held = 0;                   % level 리셋 — 0 에 묶여 있다
        elseif gate_pre == 0
            held = held + h;            % 1 을 적분 — 한 스텝에 정확히 h
        end
        if isnan(T_HIT(i)) && gate_now == 0, T_HIT(i) = tt(k); end
        if stop_on && held >= stop_hold
            n_end = k;  break           % Stop Simulation 이 도는 자리
        end

        s = s + h/6*(K(1:6, 1) + 2*K(1:6, 2) + 2*K(1:6, 3) + K(1:6, 4));
        z = z + h/6*(K(7:8, 1) + 2*K(7:8, 2) + 2*K(7:8, 3) + K(7:8, 4));
        g = g + h/6*(K(9:11,1) + 2*K(9:11,2) + 2*K(9:11,3) + K(9:11,4));
        ph_prev  = ph_now;              % 다음 스텝이 쓸 한 스텝 전 값
        gate_pre = gate_now;
    end

    NEN(i) = n_end;
    REC{i} = rec(1:n_end,:);  FRC{i} = frc(1:n_end,:);
    RPM{i} = rpm(1:n_end,:);  GPH{i} = gph(1:n_end,:);
end

%% ====================================================================
%  3. 결과 — 두 벌을 나란히 찍는다
% =====================================================================
fprintf('\n[m 파일] 4단 도착 판정과 정지  —  목표 (%g, %g) m,  선수각 %g deg\n', ...
        x_d, y_d, rad2deg(psi_d));
fprintf('  도착 반지름 R_stop = %g m,  선수각 창 5 deg,  정지 유예 stop_hold = %g s\n', ...
        R_stop, stop_hold);
for i = 1:2
    rec = REC{i};  frc = FRC{i};  rpm = RPM{i};
    fprintf('  stop_on = %d\n', stop_list(i));
    fprintf('    돈 시간    %6.2f s  (표본 %d개, 최대 %g s)\n', ...
            tt(NEN(i)), NEN(i), T_run);
    if isnan(T_HIT(i))
        fprintf('    gate       끝까지 1 — 도착 판정이 걸리지 않음\n');
    else
        fprintf('    gate 닫힘  %6.2f s  (그 뒤 %.2f s 더 돌고 멈춤)\n', ...
                T_HIT(i), tt(NEN(i)) - T_HIT(i));
    end
    fprintf('    끝 자세    x = %7.3f  y = %7.3f  psi = %7.3f deg\n', ...
            rec(end,4), rec(end,5), rad2deg(rec(end,6)));
    fprintf('    남은 거리  %6.3f m,  선수각 오차 %6.3f deg\n', ...
            hypot(x_d - rec(end,4), y_d - rec(end,5)), ...
            rad2deg(atan2(sin(psi_d - rec(end,6)), cos(psi_d - rec(end,6)))));
    fprintf('    끝 속도    u = %7.4f  v = %7.4f m/s,  r = %7.4f rad/s\n', ...
            rec(end,1), rec(end,2), rec(end,3));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))));
    fprintf('    회전수 최대 %6.1f  %6.1f  %6.1f rad/s\n', ...
            max(abs(rpm(:,1))), max(abs(rpm(:,2))), max(abs(rpm(:,3))));
end

%  gate 가 닫힌 뒤 배가 얼마나 더 나가는가 — 멈추는 법의 값어치
if ~isnan(T_HIT(1))
    kh = find(tt(1:NEN(1)) >= T_HIT(1), 1);
    dd = hypot(REC{1}(:,4) - REC{1}(kh,4), REC{1}(:,5) - REC{1}(kh,5));
    fprintf('  gate 닫힌 뒤 관성으로 더 간 거리 %.3f m, 끝 추력 FL %.2f N\n', ...
            max(dd(kh:end)), FRC{1}(end,1));
end
%  gate 가 닫히기 전까지는 두 벌의 식이 글자 하나까지 같다 — 그 구간만 맞대 본다
%  (닫힌 뒤는 한 벌만 속도 지령을 0 으로 내리므로 당연히 갈라진다)
if ~isnan(T_HIT(1))
    dpre = max(abs(REC{1}(1:kh,4:6) - REC{2}(1:kh,4:6)));
    fprintf('  gate 닫히기 전까지 두 벌 차이 (표본 %d개) x %.2e m  y %.2e m  psi %.2e rad\n', ...
            kh, dpre(1), dpre(2), dpre(3));
end

%% ====================================================================
%  4. 그림 — 궤적 · 남은 거리 · gate 와 phase · 추력
% =====================================================================
figure('Name','W06 4단 — 도착 판정과 정지','Color','w','Position',[80 80 980 720]);
cl = {'-','--'};
lg = {'stop\_on = 1 (도착하면 멈춤)','stop\_on = 0 (3단과 같음)'};

subplot(2,2,1);
for i = 1:2
    plot(REC{i}(:,5), REC{i}(:,4), cl{i}, 'LineWidth', 1.4); hold on;
end
th = linspace(0, 2*pi, 180);
plot(y_d + R_stop*cos(th), x_d + R_stop*sin(th), 'r:', 'LineWidth', 1.2);
plot(y_d, x_d, 'rp', 'MarkerSize', 12, 'MarkerFaceColor','r');
grid on; axis equal; xlabel('동 y [m]'); ylabel('북 x [m]');
title('궤적 (별 = 목표, 점선 원 = R_{stop})');
legend([lg {'R_{stop}'}], 'Location','best');

subplot(2,2,2);
for i = 1:2
    plot(tt(1:NEN(i)), hypot(x_d - REC{i}(:,4), y_d - REC{i}(:,5)), ...
         cl{i}, 'LineWidth', 1.4);
    hold on;
end
yline(R_stop, 'r:', 'LineWidth', 1.2);
if ~isnan(T_HIT(1)), xline(T_HIT(1), 'k:', 'LineWidth', 1.2); end
grid on; xlabel('시간 [s]'); ylabel('남은 거리 [m]');
title('목표까지 남은 거리 (세로 점선 = gate 닫힘)');

subplot(2,2,3);
stairs(tt(1:NEN(1)), GPH{1}(:,1), '-',  'LineWidth', 1.6); hold on;
stairs(tt(1:NEN(1)), GPH{1}(:,2), '--', 'LineWidth', 1.6);
grid on; ylim([-0.2 1.2]); xlabel('시간 [s]'); ylabel('[-]');
title('stop\_on = 1 의 gate 와 phase (래치)');
legend({'gate','phase'}, 'Location','best');

subplot(2,2,4);
for i = 1:2
    plot(tt(1:NEN(i)), FRC{i}(:,1), cl{i}, 'LineWidth', 1.4); hold on;
end
if ~isnan(T_HIT(1)), xline(T_HIT(1), 'k:', 'LineWidth', 1.2); end
grid on; xlabel('시간 [s]'); ylabel('F_L [N]');
title('좌현 추력 — gate 가 닫히면 0 으로 내려감');
legend(lg, 'Location','best');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다
%     stop_on = 1 은 W06_4_stop 과, stop_on = 0 은 3단 W06_3_thrust 와 같아야 한다
% =====================================================================
animate = 0;
chk = {'W06_4_stop', 1; 'W06_3_thrust', 2};
for c = 1:2
    mdl_c = chk{c,1};  i = chk{c,2};
    if ~exist([mdl_c '.slx'], 'file')
        fprintf('\n%s.slx 가 없어 대조를 건너뜀 — build_w06_models 로 만들 것\n', mdl_c);
        continue
    end
    out = sim(mdl_c);

    sl = [out.log_u.Data(:)   out.log_v.Data(:)   out.log_r.Data(:) ...
          out.log_x_n.Data(:) out.log_y_n.Data(:) out.log_psi.Data(:) ...
          out.log_FL.Data(:)  out.log_FR.Data(:)  out.log_FB.Data(:) ...
          out.log_gate.Data(:) out.log_phase.Data(:)];
    mm = [REC{i} FRC{i} GPH{i}];
    n2 = min(size(sl,1), NEN(i));
    d  = max(abs(sl(1:n2,:) - mm(1:n2,:)));
    dn = max(abs(out.log_n.Data(1:n2,:) - RPM{i}(1:n2,:)));

    fprintf('\n[대조] %s  vs  m 파일 stop_on = %d  (표본 %d개 — 모델 %d, m 파일 %d)\n', ...
            mdl_c, stop_list(i), n2, size(sl,1), NEN(i));
    fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
    fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
    fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(7), d(8), d(9));
    fprintf('  n  %.2e  %.2e  %.2e rad/s\n', dn(1), dn(2), dn(3));
    fprintf('  gate %.0e   phase %.0e  (0 이어야 판정 시각이 같다)\n', d(10), d(11));
end
