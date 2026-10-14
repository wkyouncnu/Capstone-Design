% W06_5_DOCK_M  5단을 m 파일 한 장으로 — 단계마다 목표를 바꿔 접안한다
%
%   >> W06_5_dock_m
%
%   무엇을 보는가
%     선석은 (북 40 m, 동 45 m), 붙었을 때의 선수각은 0 deg 다. 같은 선석을
%     두 가지 방법으로 노린다.
%
%       dock_on = 1   단계 전이를 켠다 — 접근점 -> 선수각 정렬 -> 옆걸음 접안
%       dock_on = 0   단계 전이를 끈다 — 처음부터 선석을 목표로 둔다 (4단과
%                     같은 한 점 추종이고, 목표만 선석이다)
%
%     4단까지 목표는 처음부터 끝까지 한 점이었다. 접안은 그렇게 하지 못한다.
%     선석을 바로 노리면 배가 부두 앞 물을 비스듬히 가로질러 들어간다. 사람이
%     배를 대는 순서가 따로 있다.
%
%   단계 셋 (모델의 TaskRef 와 같은 식이다)
%     접근점 = 선석에서 부두 반대쪽으로 L_app 만큼 떨어진 점
%
%         ax = dx - sd*La*sin(dpsi)
%         ay = dy + sd*La*cos(dpsi)        sd = berth_side, La = L_app
%
%       1단계  목표 = 접근점,  선수각 = 가는 방향 atan2(ay - y_n, ax - x_n)
%              접근점까지 거리 < R_dock 이면 phase 0 -> 1
%       2단계  목표 = 접근점 그대로,  선수각 = 접안 선수각 dpsi
%              선수각 오차 < 5 deg 이면 phase 1 -> 2
%       3단계  목표 = 선석,  선수각 = dpsi 그대로
%              선석까지 거리 < R_stop 이면 phase 2 -> 3,  이때 gate 가 닫힌다
%
%     gate = (phase < 3) 이다. phase 는 한 번 올라가면 내려오지 않는다 (래치).
%
%   왜 3단계가 옆걸음인가
%     선수각을 dpsi 로 묶어 둔 채 목표만 선석으로 바꾸면, 바깥 고리가 선체
%     좌표로 돌린 오차가 거의 횡방향(e_y)으로만 남는다 — 2단에서 본 순수
%     횡이동이 여기서 쓰인다. 선수추진기가 없으면 이 단계가 되지 않는다.
%
%   한 스텝 전 값을 쓰는 까닭 (모델의 Unit Delay 에 해당한다)
%     phase 는 자기 자신의 입력이다. 그대로 되먹이면 대수 루프가 되어 Simulink
%     가 풀지 못한다. 모델은 Unit Delay 로 한 스텝 전 값을 쓰고, 표본 간격을
%     고정 스텝(Ts_ctrl)과 같게 둔다.
%
%     이 파일도 같게 맞춘다. ph_prev 는 **주요 스텝 경계에서만** 갱신하고,
%     RK4 의 네 소단계에서는 ph_prev 를 붙들어 둔 채 그 소단계의 상태로 거리와
%     선수각 오차만 다시 잰다. 다음 스텝에 넘길 값은 소단계 첫째(j = 1)에서
%     나온 값이다 — Unit Delay 가 표본 시각의 값을 집어 가는 것과 같다.
%
%   AutoStop
%     gate 가 1 인 동안 적분기가 0 에 묶여 있고(level 리셋), 0 이 되면 1 을
%     적분해 초를 센다. 그 값이 stop_hold 에 이르면 계산이 끝난다. 1 을 적분
%     하므로 RK4 로도 한 스텝에 정확히 h 가 더해진다 — held = held + h 로 적는다.
%
%   상태는 4단과 같은 11개다
%     배 6 + 속도 PI 적분기 2 + 추진기 회전수 3. phase 와 held 는 미분방정식이
%     아니라 스텝 경계에서 갱신되는 값이라 RK4 묶음에 들어가지 않는다.
%
%   이 파일의 규칙 (1~4단과 같다)
%     자체 함수 없음 · 설정은 W06_setup 에서만 · 적분은 RK4, 간격은 Ts_ctrl

%% ====================================================================
%  1. 설정 — 5단 설정을 불러온다
%     W06_setup 의 stage 한 줄을 고치지 않고 5단 값을 쓰기 위해 뒷문을 쓴다.
%     5단은 초기 선수각을 접근점 방향으로 두므로(psi_init) 이 값이 다르면
%     Simulink 와 맞대 볼 수 없다.
% =====================================================================
setappdata(0, 'W06_stage',    5);
setappdata(0, 'W06_skip_run', true);
W06_setup;

N_lim = 2*F_max*half_beam + F_bow_max*l_bow;

%  유도부가 쓰는 값 — task_q 에서 꺼낸다 (TaskRef 의 q 와 같은 순서)
dx = task_q(7);   dy = task_q(8);   dpsi = task_q(9);
Rd = task_q(10);  La = task_q(11);  sd   = task_q(12);  Rs = task_q(13);
ax = dx - sd*La*sin(dpsi);          % 접근점 — TaskRef 와 글자 하나까지 같다
ay = dy + sd*La*cos(dpsi);

h  = Ts_ctrl;
tt = (0:h:T_run)';
nt = numel(tt);

dock_list = [1 0];              % 단계 전이 켬 · 끔
REC = cell(1,2);                % 배 상태 기록 (6개)
REF = cell(1,2);                % 유도부가 낸 목표 기록 (x_ref y_ref psi_ref)
FRC = cell(1,2);                % 실제 추력 기록
RPM = cell(1,2);                % 회전수 기록
GPH = cell(1,2);                % gate · phase 기록
NEN = zeros(1,2);               % 벌마다 실제로 돈 표본 수
T_PH = nan(3,2);                % 단계가 올라간 시각 (행 = phase 1·2·3)
T_HIT = nan(1,2);               % gate 가 닫힌 시각

%% ====================================================================
%  2. 두 벌을 차례로 돌린다 — 상태 11개를 RK4 로 함께 적분한다
%     s(1:6) 배 · z(1:2) 속도 PI 적분기 · g(1:3) 추진기 회전수
%     ph_prev(래치) 와 held(정지 타이머) 는 스텝 경계에서만 움직인다
% =====================================================================
for i = 1:2
    dock_on = dock_list(i);
    s = x0;
    z = [0; 0];
    g = [0; 0; 0];
    ph_prev  = 0;               % Unit Delay 의 InitialCondition
    held     = 0;               % AutoStop 적분기의 InitialCondition
    gate_pre = 1;               % 한 스텝 전 gate — 리셋이 풀린 순간을 가린다
    rec = zeros(nt, 6);
    ref = zeros(nt, 3);
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

            % --- 유도 : 단계마다 다른 목표 (TaskRef 와 같은 식) ---------
            %     ph_prev 는 이 스텝 동안 고정이고, 거리와 선수각 오차만
            %     소단계 상태로 다시 잰다
            ph = ph_prev;
            if dock_on
                if ph < 1
                    %  1단계 — 접근점으로 간다. 선수각은 가는 방향으로 둔다
                    x_ref = ax;  y_ref = ay;
                    psi_ref = atan2(ay - y_n, ax - x_n);
                    if sqrt((ax - x_n)^2 + (ay - y_n)^2) < Rd, ph = 1; end
                elseif ph < 2
                    %  2단계 — 접근점에 머물며 선수각만 접안 선수각으로
                    x_ref = ax;  y_ref = ay;  psi_ref = dpsi;
                    if abs(atan2(sin(dpsi - psi), cos(dpsi - psi))) < 5*pi/180
                        ph = 2;
                    end
                else
                    %  3단계 — 선수각을 지킨 채 옆걸음으로 선석에 붙인다
                    x_ref = dx;  y_ref = dy;  psi_ref = dpsi;
                    if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs, ph = 3; end
                end
                gate = double(ph < 3);
            else
                %  단계 전이를 끈 벌 — 처음부터 선석이 목표다 (4단과 같은 꼴).
                %  도착 판정은 phase 0 -> 1 하나뿐이고 gate = (phase < 1) 이다
                x_ref = dx;  y_ref = dy;  psi_ref = dpsi;
                d_go  = sqrt((dx - x_n)^2 + (dy - y_n)^2);
                e_hit = atan2(sin(dpsi - psi), cos(dpsi - psi));
                if ph < 1 && d_go < Rs && abs(e_hit) < 5*pi/180, ph = 1; end
                gate = double(ph < 1);
            end

            % --- 바깥 고리 : 위치 오차 -> 속도 지령 --------------------
            e_N = x_ref - x_n;
            e_E = y_ref - y_n;
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
            e_psi = atan2(sin(psi_ref - psi), cos(psi_ref - psi));
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
                ref(k,:) = [x_ref y_ref psi_ref];
                frc(k,:) = [FL FR FB];
                rpm(k,:) = p';
                gph(k,:) = [gate ph];
                ph_now   = ph;          % Unit Delay 가 집어 갈 값
                gate_now = gate;
            end
        end

        % --- 단계가 올라간 시각을 적어 둔다 ----------------------------
        for v = 1:3
            if ph_now >= v && isnan(T_PH(v,i)), T_PH(v,i) = tt(k); end
        end

        % --- AutoStop : gate 가 0 인 동안만 초를 센다 -------------------
        if gate_now ~= 0
            held = 0;                   % level 리셋 — 0 에 묶여 있다
        elseif gate_pre == 0
            held = held + h;            % 1 을 적분 — 한 스텝에 정확히 h
        end
        if isnan(T_HIT(i)) && gate_now == 0, T_HIT(i) = tt(k); end
        if held >= stop_hold
            n_end = k;  break           % Stop Simulation 이 도는 자리
        end

        s = s + h/6*(K(1:6, 1) + 2*K(1:6, 2) + 2*K(1:6, 3) + K(1:6, 4));
        z = z + h/6*(K(7:8, 1) + 2*K(7:8, 2) + 2*K(7:8, 3) + K(7:8, 4));
        g = g + h/6*(K(9:11,1) + 2*K(9:11,2) + 2*K(9:11,3) + K(9:11,4));
        ph_prev  = ph_now;              % 다음 스텝이 쓸 한 스텝 전 값
        gate_pre = gate_now;
    end

    NEN(i) = n_end;
    REC{i} = rec(1:n_end,:);  REF{i} = ref(1:n_end,:);  FRC{i} = frc(1:n_end,:);
    RPM{i} = rpm(1:n_end,:);  GPH{i} = gph(1:n_end,:);
end

%% ====================================================================
%  3. 결과 — 두 벌을 나란히 찍는다
% =====================================================================
fprintf('\n[m 파일] 5단 단계 전이 접안  —  선석 (%g, %g) m,  선수각 %g deg\n', ...
        dx, dy, rad2deg(dpsi));
fprintf('  접근점 (%g, %g) m,  전환반경 R_dock = %g m,  도착반경 R_stop = %g m\n', ...
        ax, ay, Rd, Rs);
fprintf('  출발 선수각 %.2f deg (접근점 방향),  정지 유예 stop_hold = %g s\n', ...
        rad2deg(x0(6)), stop_hold);
way = {'단계 전이 켬 — 접근점 -> 선수각 정렬 -> 옆걸음', ...
       '단계 전이 끔 — 처음부터 선석을 목표로'};
for i = 1:2
    rec = REC{i};  frc = FRC{i};  rpm = RPM{i};
    fprintf('  dock_on = %d  (%s)\n', dock_list(i), way{i});
    fprintf('    돈 시간    %6.2f s  (표본 %d개, 최대 %g s)\n', ...
            tt(NEN(i)), NEN(i), T_run);
    for v = 1:3
        if isnan(T_PH(v,i)), continue, end
        kv = find(tt(1:NEN(i)) >= T_PH(v,i), 1);
        fprintf('    phase %d    %6.2f s  (%7.3f, %7.3f) m,  psi = %7.3f deg\n', ...
                v, T_PH(v,i), rec(kv,4), rec(kv,5), rad2deg(rec(kv,6)));
    end
    if isnan(T_HIT(i))
        fprintf('    gate       끝까지 1 — 닫히지 않음\n');
    else
        fprintf('    gate 닫힘  %6.2f s  (그 뒤 %.2f s 더 돌고 멈춤)\n', ...
                T_HIT(i), tt(NEN(i)) - T_HIT(i));
    end
    fprintf('    끝 자세    x = %7.3f  y = %7.3f  psi = %7.3f deg\n', ...
            rec(end,4), rec(end,5), rad2deg(rec(end,6)));
    fprintf('    남은 거리  %6.3f m,  선수각 오차 %6.3f deg\n', ...
            hypot(dx - rec(end,4), dy - rec(end,5)), ...
            rad2deg(atan2(sin(dpsi - rec(end,6)), cos(dpsi - rec(end,6)))));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N  (한계 %g · %g N)\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))), F_max, F_bow_max);
    fprintf('    회전수 최대 %6.1f  %6.1f  %6.1f rad/s  (한계 %.1f)\n', ...
            max(abs(rpm(:,1))), max(abs(rpm(:,2))), max(abs(rpm(:,3))), n_max);
end

%  어느 쪽에서 선석에 닿았는가 — 단계 전이의 값어치가 여기서 드러난다.
%  설계한 접근 방향은 선석에서 접근점을 보는 방향이다 (열린 물 쪽). 배가 멈춘
%  자리가 선석에서 어느 쪽인지 재어 그 방향과 견준다. 0 deg 면 설계한 쪽에서
%  붙은 것이고, 180 deg 면 반대쪽 — 부두를 지나 들어간 것이다
bear_app = atan2(ay - dy, ax - dx);
for i = 1:2
    kh = find(tt(1:NEN(i)) >= T_HIT(i), 1);
    bear = atan2(REC{i}(kh,5) - dy, REC{i}(kh,4) - dx);
    fprintf('  dock_on = %d : 닿은 쪽이 설계 방향에서 %6.1f deg 벗어남\n', ...
            dock_list(i), abs(rad2deg(atan2(sin(bear - bear_app), cos(bear - bear_app)))));
end

%% ====================================================================
%  4. 그림 — 궤적 · 단계 · 남은 거리 · 선수각
% =====================================================================
figure('Name','W06 5단 — 단계 전이 접안','Color','w','Position',[80 80 980 720]);
cl = {'-','--'};
lg = {'dock\_on = 1 (단계 전이)','dock\_on = 0 (선석을 바로)'};
th = linspace(0, 2*pi, 180);

subplot(2,2,1);
for i = 1:2
    plot(REC{i}(:,5), REC{i}(:,4), cl{i}, 'LineWidth', 1.4); hold on;
end
plot(ay + Rd*cos(th), ax + Rd*sin(th), 'b:', 'LineWidth', 1.2);
plot(dy + Rs*cos(th), dx + Rs*sin(th), 'r:', 'LineWidth', 1.2);
plot([dy ay], [dx ax], 'k-.', 'LineWidth', 1.0);
plot(ay, ax, 'bo', 'MarkerSize', 9, 'MarkerFaceColor','b');
plot(dy, dx, 'rp', 'MarkerSize', 13, 'MarkerFaceColor','r');
grid on; axis equal; xlabel('동 y [m]'); ylabel('북 x [m]');
title('궤적 (별 = 선석, 원 = 접근점)');
legend([lg {'R_{dock}','R_{stop}'}], 'Location','best');

subplot(2,2,2);
for i = 1:2
    stairs(tt(1:NEN(i)), GPH{i}(:,2), cl{i}, 'LineWidth', 1.6); hold on;
end
stairs(tt(1:NEN(1)), GPH{1}(:,1), 'k:', 'LineWidth', 1.4);
grid on; ylim([-0.2 3.2]); xlabel('시간 [s]'); ylabel('[-]');
title('phase 는 올라가기만 함 (점선 = dock\_on = 1 의 gate)');
legend([lg {'gate'}], 'Location','best');

subplot(2,2,3);
for i = 1:2
    plot(tt(1:NEN(i)), hypot(dx - REC{i}(:,4), dy - REC{i}(:,5)), ...
         cl{i}, 'LineWidth', 1.4); hold on;
end
yline(Rs, 'r:', 'LineWidth', 1.2);
for v = 1:3
    if ~isnan(T_PH(v,1)), xline(T_PH(v,1), 'k:', 'LineWidth', 1.0); end
end
grid on; xlabel('시간 [s]'); ylabel('선석까지 거리 [m]');
title('선석까지 남은 거리 (세로 점선 = 단계 전이)');

subplot(2,2,4);
for i = 1:2
    plot(tt(1:NEN(i)), rad2deg(REF{i}(:,3)), cl{i}, 'LineWidth', 1.0); hold on;
    plot(tt(1:NEN(i)), rad2deg(REC{i}(:,6)), cl{i}, 'LineWidth', 1.6);
end
grid on; xlabel('시간 [s]'); ylabel('선수각 [deg]');
title('가는 방향을 보다가 접안 선수각으로 돌아섬 (얇은 선 = 지령)');
legend({'지령 (전이)','응답 (전이)','지령 (바로)','응답 (바로)'}, 'Location','best');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다
%     dock_on = 1 은 W06_5_dock 과 같아야 한다. dock_on = 0 은 선석을 목표로
%     둔 4단 꼴이고 대응하는 모델이 없으므로 맞대지 않는다.
% =====================================================================
animate = 0;
mdl_c = 'W06_5_dock';
if ~exist([mdl_c '.slx'], 'file')
    fprintf('\n%s.slx 가 없어 대조를 건너뜀 — build_w06_models 로 만들 것\n', mdl_c);
else
    out = sim(mdl_c);

    sl = [out.log_u.Data(:)     out.log_v.Data(:)     out.log_r.Data(:) ...
          out.log_x_n.Data(:)   out.log_y_n.Data(:)   out.log_psi.Data(:) ...
          out.log_x_ref.Data(:) out.log_y_ref.Data(:) out.log_psi_ref.Data(:) ...
          out.log_FL.Data(:)    out.log_FR.Data(:)    out.log_FB.Data(:) ...
          out.log_gate.Data(:)  out.log_phase.Data(:)];
    mm = [REC{1} REF{1} FRC{1} GPH{1}];
    n2 = min(size(sl,1), NEN(1));
    d  = max(abs(sl(1:n2,:) - mm(1:n2,:)));
    dn = max(abs(out.log_n.Data(1:n2,:) - RPM{1}(1:n2,:)));

    fprintf('\n[대조] %s  vs  m 파일 dock_on = 1  (표본 %d개 — 모델 %d, m 파일 %d)\n', ...
            mdl_c, n2, size(sl,1), NEN(1));
    fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
    fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
    fprintf('  x_ref %.2e m   y_ref %.2e m   psi_ref %.2e rad\n', d(7), d(8), d(9));
    fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(10), d(11), d(12));
    fprintf('  n  %.2e  %.2e  %.2e rad/s\n', dn(1), dn(2), dn(3));
    fprintf('  gate %.0e   phase %.0e  (0 이어야 전이 시각이 같다)\n', d(13), d(14));
end
