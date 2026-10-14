% W06_8_NED_M  8단을 m 파일 한 장으로 — 제어기를 NED 축에서 돌린다
%
%   >> W06_8_ned_m
%
%   무엇을 보는가
%     선석은 (북 40 m, 동 45 m), 선석 방위는 0 deg 다. 과업·접근점·단계 전이가
%     모두 5단과 같고, **제어기가 도는 좌표계**만 다른 두 벌을 돌린다.
%
%       ned_on = 1   NED 축 제어      (8단의 모델 — 논문 식 13~16)
%       ned_on = 0   선체고정 축 제어 (5단의 모델 — 논문 식 17~19)
%
%     유도부는 두 벌이 글자까지 같다. 갈라지는 곳은 아래 두 토막뿐이다.
%
%   회전행렬이 어디에 앉는가 — 이것이 두 전략의 전부다
%
%     선체고정 (5단)   위치오차 -> [R] -> 속도지령 -> 속도PI -> 힘 -> 배분
%     NED      (8단)   위치오차 ------> 속도지령 -> 속도PI -> [R] -> 힘 -> 배분
%                                          측정속도 -> [R] -> 되먹임
%
%     선체고정은 회전행렬이 하나, NED 는 둘이다. 제어기가 NED 에서 도는데
%     센서(u·v)도 구동기(FL·FR·FB)도 선체고정이므로 들어올 때 한 번, 나갈 때
%     한 번 돌려야 한다.
%
%   NED 쪽 식 (실험실 논문 Bang et al. 2025 식 13~16)
%
%       xdot_p = Kp_ned*(x_ref - x_n),      ydot_p = Kp_ned*(y_ref - y_n)
%       크기 묶기 : s = hypot(xdot_p, ydot_p) > V_ned_max 면 둘을 s 로 나눠 줌
%       되먹임    : xdot = u*cos(psi) - v*sin(psi),  ydot = u*sin(psi) + v*cos(psi)
%       속도 PI   : X_N = Kp_vn*e_xd + Ki_vn*int(e_xd),  Y_E 도 같은 꼴
%       힘 돌리기 : X =  X_N*cos(psi) + Y_E*sin(psi)
%                   Y = -X_N*sin(psi) + Y_E*cos(psi)
%
%   속도 지령을 왜 벡터 크기로 묶는가
%     선체좌표에서는 전후 1.5 m/s · 횡 0.6 m/s 로 축마다 다르게 묶을 수 있었다.
%     어느 추진기가 그 속도를 내는지 알기 때문이다. NED 축은 그것을 모른다 —
%     북쪽으로 1.5 m/s 를 지시해도 선수가 동쪽을 보고 있으면 그것은 횡방향
%     1.5 m/s 이고, 선수추진기 하나로는 낼 수 없다. 그래서 느린 축의 한계로
%     묶는다 (V_ned_max = v_max). 두 축을 따로 0.6 으로 자르면 비스듬한
%     방향에서 0.6*sqrt(2) = 0.85 m/s 가 되므로, 자르는 것도 축마다가 아니라
%     **크기**로 한다 — 방향은 그대로 두고 빠르기만 줄인다.
%
%     그 값으로 치르는 것이 아래 출력의 "돈 시간" 이다. 1단계에서 접근점까지
%     전후로 1.5 m/s 로 달릴 수 있었던 거리를 0.6 m/s 로 간다.
%
%   anti-windup 이 느슨해지는 것도 값이다
%     선체고정에서는 횡 속도 PI 의 clamping 한계를 F_bow_max 로 둘 수 있었다 —
%     그 힘을 선수추진기가 낸다는 것을 알기 때문이다. NED 축에서는 북쪽 힘을
%     어느 추진기가 낼지 선수각에 따라 달라지므로 그렇게 묶을 수 없다. 두 축
%     모두 2*F_max 로 두고, 실제 한계는 배분에서 FB 가 F_bow_max 로 잘리며
%     드러난다 — 잘린 만큼은 적분기가 모르므로 쌓인다.
%
%   한 스텝 전 값 · AutoStop · 상태 11개 · 파일 규약은 5단과 같다
%     ph_prev 는 주요 스텝 경계에서만 갱신하고, RK4 의 네 소단계에서는 붙들어
%     둔 채 그 소단계의 상태로 거리와 선수각 오차만 다시 잰다. 자체 함수 없음,
%     설정은 W06_setup 에서만, 적분은 RK4, 간격은 Ts_ctrl.

%% ====================================================================
%  1. 설정 — 8단 설정을 불러온다 (5단과 같은 과업·같은 초기 자세)
% =====================================================================
setappdata(0, 'W06_stage',    8);
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

ned_list = [1 0];               % NED 축 · 선체고정 축
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
%     z 가 세는 오차는 벌마다 다르다 — NED 벌은 북·동 속도 오차,
%     선체고정 벌은 전후·횡 속도 오차다 (자리는 같고 뜻이 다르다)
% =====================================================================
for i = 1:2
    ned_on = ned_list(i);
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

            % --- 유도 : 단계마다 다른 목표 (5단과 글자까지 같다) --------
            ph = ph_prev;
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

            e_N = x_ref - x_n;
            e_E = y_ref - y_n;

            if ned_on
                % --- 바깥 고리 (NED) : 위치 오차를 돌리지 않는다 -------
                xdot_p = Kp_ned*e_N;
                ydot_p = Kp_ned*e_E;
                sv = sqrt(xdot_p^2 + ydot_p^2);         % CapV — 크기로 묶는다
                if sv > V_ned_max
                    xdot_p = xdot_p*V_ned_max/sv;
                    ydot_p = ydot_p*V_ned_max/sv;
                end
                xdot_cmd = gate*xdot_p;
                ydot_cmd = gate*ydot_p;

                % --- 되먹임을 NED 로 돌린다 (회전행렬 하나) -----------
                xdot = u*cos(psi) - v*sin(psi);
                ydot = u*sin(psi) + v*cos(psi);
                e_1  = xdot_cmd - xdot;
                e_2  = ydot_cmd - ydot;

                % --- NED 속도 PI -> NED 힘 지령 ----------------------
                A_pre = Kp_vn*e_1 + Ki_vn*w(1);         % X_N  북쪽 힘 [N]
                B_pre = Kp_vn*e_2 + Ki_vn*w(2);         % Y_E  동쪽 힘 [N]
                A = min(max(A_pre, -2*F_max), 2*F_max);
                B = min(max(B_pre, -2*F_max), 2*F_max);

                % --- 힘 지령을 선체좌표로 돌린다 (회전행렬 둘) --------
                X =  A*cos(psi) + B*sin(psi);
                Y = -A*sin(psi) + B*cos(psi);
            else
                % --- 바깥 고리 (선체고정) : 위치 오차를 먼저 돌린다 ----
                e_x =  cos(psi)*e_N + sin(psi)*e_E;
                e_y = -sin(psi)*e_N + cos(psi)*e_E;
                e_1 = gate*min(max(Kp_x*e_x, -u_max), u_max) - u;
                e_2 = gate*min(max(Kp_y*e_y, -v_max), v_max) - v;

                % --- 선체축 속도 PI -> 선체축 힘 (회전행렬 없음) ------
                A_pre = Kp_u*e_1 + Ki_u*w(1);           % X  전후력 [N]
                B_pre = Kp_v*e_2 + Ki_v*w(2);           % Y  횡력   [N]
                A = min(max(A_pre, -2*F_max),   2*F_max);
                B = min(max(B_pre, -F_bow_max), F_bow_max);
                X = A;
                Y = B;
            end

            %  clamping — 포화된 쪽은 적분을 멈춘다 (두 벌이 같은 꼴이다)
            dz = [e_1; e_2];
            if A ~= A_pre && sign(e_1) == sign(A_pre - A), dz(1) = 0; end
            if B ~= B_pre && sign(e_2) == sign(B_pre - B), dz(2) = 0; end

            % --- 선수각 P-D — 두 벌이 같다 ----------------------------
            e_psi = atan2(sin(psi_ref - psi), cos(psi_ref - psi));
            N_pre = Kp_psi*e_psi - Kd_psi*r;
            N_mom = min(max(N_pre, -N_lim), N_lim);

            % --- 추력 배분 — 두 벌이 같다. 들어오는 X·Y 는 선체고정이다
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
        for c = 1:3
            if ph_now >= c && isnan(T_PH(c,i)), T_PH(c,i) = tt(k); end
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
fprintf('\n[m 파일] 8단 NED 좌표계 위치제어 접안  —  선석 (%g, %g) m,  방위 %g deg\n', ...
        dx, dy, rad2deg(dpsi));
fprintf('  접근점 (%g, %g) m,  전환반경 R_dock = %g m,  도착반경 R_stop = %g m\n', ...
        ax, ay, Rd, Rs);
fprintf('  NED 게인   Kp_ned = %g,  속도 PI %g / %g,  크기 한계 %g m/s\n', ...
        Kp_ned, Kp_vn, Ki_vn, V_ned_max);
fprintf('  선체고정   Kp_x = Kp_y = %g,  속도 PI %g / %g,  한계 %g · %g m/s\n', ...
        Kp_x, Kp_u, Ki_u, u_max, v_max);
way = {'NED 축 제어 — 위치 오차를 돌리지 않음 (회전행렬 둘)', ...
       '선체고정 축 제어 — 위치 오차를 먼저 돌림 (회전행렬 하나, 5단)'};
for i = 1:2
    rec = REC{i};  frc = FRC{i};  rpm = RPM{i};
    U = hypot(rec(:,1), rec(:,2));
    fprintf('  ned_on = %d  (%s)\n', ned_list(i), way{i});
    fprintf('    돈 시간    %6.2f s  (표본 %d개, 최대 %g s)\n', ...
            tt(NEN(i)), NEN(i), T_run);
    for c = 1:3
        if isnan(T_PH(c,i)), continue, end
        kv = find(tt(1:NEN(i)) >= T_PH(c,i), 1);
        fprintf('    phase %d    %6.2f s  (%7.3f, %7.3f) m,  psi = %7.3f deg\n', ...
                c, T_PH(c,i), rec(kv,4), rec(kv,5), rad2deg(rec(kv,6)));
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
    fprintf('    빠르기 최대 %5.3f m/s  (전후 %5.3f · 횡 %5.3f)\n', ...
            max(U), max(abs(rec(:,1))), max(abs(rec(:,2))));
    fprintf('    간 거리    %6.2f m  (직선거리 %6.2f m)\n', ...
            sum(hypot(diff(rec(:,4)), diff(rec(:,5)))), ...
            hypot(rec(end,4) - x0(4), rec(end,5) - x0(5)));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N  (한계 %g · %g N)\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))), F_max, F_bow_max);
    fprintf('    회전수 최대 %6.1f  %6.1f  %6.1f rad/s  (한계 %.1f)\n', ...
            max(abs(rpm(:,1))), max(abs(rpm(:,2))), max(abs(rpm(:,3))), n_max);
end

%  선석에서 어긋난 거리 — 접근점에서 선석을 보는 방향을 양의 방향으로 잡는다.
%  양수면 선석을 지나 부두 쪽으로 들어간 것이고 음수면 못 간 것이다
ex = (dx - ax)/La;   ey = (dy - ay)/La;          % 접근점 -> 선석 단위벡터
fprintf('\n  선석에서 어긋난 거리 — 진행축(양수 = 부두 쪽으로 더) 과 그 옆축\n');
for i = 1:2
    rec  = REC{i};
    ddx  = rec(end,4) - dx;   ddy = rec(end,5) - dy;
    fprintf('    ned_on = %d :  진행축 %6.3f m,  옆축 %6.3f m\n', ...
            ned_list(i),  ex*ddx + ey*ddy,  -ey*ddx + ex*ddy);
end
fprintf('  두 벌의 시간 차  %6.2f s  (NED 가 %.2f 배)\n', ...
        tt(NEN(1)) - tt(NEN(2)), tt(NEN(1))/tt(NEN(2)));

%% ====================================================================
%  4. 그림 — 궤적 · 빠르기 · 남은 거리 · 선수각
% =====================================================================
figure('Name','W06 8단 — NED 좌표계 위치제어','Color','w','Position',[80 80 980 720]);
cl = {'-','--'};
lg = {'NED 축','선체고정 축 (5단)'};
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
    plot(tt(1:NEN(i)), hypot(REC{i}(:,1), REC{i}(:,2)), cl{i}, 'LineWidth', 1.4); hold on;
end
yline(V_ned_max, 'r:', 'LineWidth', 1.2);
yline(u_max,     'b:', 'LineWidth', 1.2);
grid on; xlabel('시간 [s]'); ylabel('빠르기 |U| [m/s]');
title('NED 는 크기가 V_{ned max} 에 묶임 — 선체고정은 전후로 u_{max} 까지');
legend([lg {'V_{ned max}','u_{max}'}], 'Location','best');

subplot(2,2,3);
for i = 1:2
    plot(tt(1:NEN(i)), hypot(dx - REC{i}(:,4), dy - REC{i}(:,5)), ...
         cl{i}, 'LineWidth', 1.4); hold on;
end
yline(Rs, 'r:', 'LineWidth', 1.2);
for c = 1:3
    if ~isnan(T_PH(c,1)), xline(T_PH(c,1), 'k:', 'LineWidth', 1.0); end
end
grid on; xlabel('시간 [s]'); ylabel('선석까지 거리 [m]');
title('선석까지 남은 거리 (세로 점선 = NED 벌의 단계 전이)');
legend(lg, 'Location','best');

subplot(2,2,4);
for i = 1:2
    plot(tt(1:NEN(i)), rad2deg(REF{i}(:,3)), cl{i}, 'LineWidth', 1.0); hold on;
    plot(tt(1:NEN(i)), rad2deg(REC{i}(:,6)), cl{i}, 'LineWidth', 1.6);
end
grid on; xlabel('시간 [s]'); ylabel('선수각 [deg]');
title('선수각 — 두 벌이 같은 목표를 따름 (얇은 선 = 지령)');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다 — 두 벌 다 짝이 있다
%     첫째 벌은 W06_8_ned, 둘째 벌은 W06_5_dock 과 같아야 한다. 둘째가 맞으면
%     이 m 파일이 5단을 그대로 담고 있다는 뜻이고, 그 위에서 첫째 벌의 차이가
%     좌표계 하나에서만 왔다는 것이 보인다
% =====================================================================
animate = 0;
pair = {'W06_8_ned', 1; 'W06_5_dock', 2};
for c = 1:size(pair,1)
    mdl_c = pair{c,1};   iv = pair{c,2};
    if ~exist([mdl_c '.slx'], 'file')
        fprintf('\n%s.slx 가 없어 대조를 건너뜀 — build_w06_models 로 만들 것\n', mdl_c);
        continue
    end
    out = sim(mdl_c);

    sl = [out.log_u.Data(:)     out.log_v.Data(:)     out.log_r.Data(:) ...
          out.log_x_n.Data(:)   out.log_y_n.Data(:)   out.log_psi.Data(:) ...
          out.log_x_ref.Data(:) out.log_y_ref.Data(:) out.log_psi_ref.Data(:) ...
          out.log_FL.Data(:)    out.log_FR.Data(:)    out.log_FB.Data(:) ...
          out.log_gate.Data(:)  out.log_phase.Data(:)];
    mm = [REC{iv} REF{iv} FRC{iv} GPH{iv}];
    n2 = min(size(sl,1), NEN(iv));
    d  = max(abs(sl(1:n2,:) - mm(1:n2,:)));
    dn = max(abs(out.log_n.Data(1:n2,:) - RPM{iv}(1:n2,:)));

    fprintf('\n[대조] %s  vs  m 파일 %d째 벌  (표본 %d개 — 모델 %d, m 파일 %d)\n', ...
            mdl_c, iv, n2, size(sl,1), NEN(iv));
    fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
    fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
    fprintf('  x_ref %.2e m   y_ref %.2e m   psi_ref %.2e rad\n', d(7), d(8), d(9));
    fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(10), d(11), d(12));
    fprintf('  n  %.2e  %.2e  %.2e rad/s\n', dn(1), dn(2), dn(3));
    fprintf('  gate %.0e   phase %.0e  (0 이어야 전이 시각이 같다)\n', d(13), d(14));
end
