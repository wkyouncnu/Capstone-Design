% W06_7_FRONT_M  7단을 m 파일 한 장으로 — 선수를 선석으로 들이대 붙인다
%
%   >> W06_7_front_m
%
%   무엇을 보는가
%     선석은 (북 40 m, 동 45 m), 선석 방위는 0 deg 다. 같은 선석·같은 접근점
%     에서 세 벌을 돌린다.
%
%       front_on = 1, bow_on = 1   전진 접안 (bow-first) — 7단의 모델
%       front_on = 0, bow_on = 1   옆걸음 접안 (lateral) — 5단의 모델
%       front_on = 1, bow_on = 0   전진 접안인데 선수추진기가 없는 배
%
%     세 벌이 다른 곳은 두 줄뿐이다
%
%         psi_f = dpsi - front_on*sd*pi/2      접안 선수각
%         FB_c  = bow_on * Y                   횡력 지령
%
%     셋 다 접근점이 같고 접안점도 같다. 가는 길이 아니라 **어느 쪽을 보고
%     가는가**와 **횡력을 낼 수 있는가**만 다르다.
%
%   접안 선수각 — 이것이 7단의 전부다
%     옆걸음은 선석과 나란히 서서 (psi_f = 선석 방위) 횡방향으로 붙인다.
%     전진은 선수를 부두로 돌려 (psi_f = 선석 방위에 수직) 앞으로 붙인다.
%
%         전진   psi_f = dpsi - sd*pi/2        sd = berth_side
%         옆걸음 psi_f = dpsi
%
%     sd = +1 이면 부두가 좌현쪽이므로 선수를 좌현쪽(-90 deg)으로 돌린다.
%
%   접근점은 두 전략이 같은 점이다 (실험실 논문 Bang et al. 2025 식 (5)·(8))
%     접안은 결국 부두 쪽으로 밀고 들어가는 일이다. 그 **진행 방향**은 두
%     전략이 같다 — 선석 방위에 수직하게, 부두 쪽으로다.
%
%         psi_go = dpsi - sd*pi/2
%
%     접근점은 접안점에서 그 방향의 뒤쪽으로 L_app 만큼 물러난 점이다.
%
%         ax = dx - La*cos(psi_go),   ay = dy - La*sin(psi_go)
%
%     논문은 두 전략의 접근점을 따로 적는다. 전진은 식 (5) 로 접안 선수각의
%     뒤쪽, 옆걸음은 식 (8) 로 접안 선수각의 옆쪽이다. 전진은 psi_f = psi_go
%     이므로 식 (5) 가 위 식이고, 옆걸음은 psi_f = dpsi 의 옆쪽이 역시 psi_go
%     의 뒤쪽이다 — 두 식이 같은 점을 준다.
%
%         cos(psi_go) =  sd*sin(dpsi),   sin(psi_go) = -sd*cos(dpsi)
%         -> ax = dx - sd*La*sin(dpsi),   ay = dy + sd*La*cos(dpsi)   (5단의 식)
%
%     논문의 식 (8) 은 부두가 우현쪽인 경우로 적혀 있고, 강의 모델은 berth_side
%     로 좌·우 어느 쪽이든 다룬다. 접근점이 같으므로 세 벌의 1단계 궤적도 같다.
%     갈라지는 곳은 2단계부터다.
%
%   왜 3단계가 전진인가
%     선수각을 psi_f 로 묶어 둔 채 목표만 선석으로 바꾸면, 바깥 고리가 선체
%     좌표로 돌린 오차가 거의 전후방향(e_x)으로만 남는다. 옆걸음에서는 같은
%     오차가 e_y 로 남았다 — 회전행렬을 한 번 더 보면 된다.
%
%         [e_x]   [ cos(psi)  sin(psi)] [x_ref - x_n]
%         [e_y] = [-sin(psi)  cos(psi)] [y_ref - y_n]
%
%     전후 오차는 선미추진기 둘이 그대로 낸다. 그러면 선수추진기가 없는 배도
%     전진으로 붙을 수 있을까 — 세째 벌이 그것을 재는 벌이다. 결과는 아래
%     출력에 그대로 찍힌다 (2단계에서 돌아설 때 생긴 횡방향 오차가 끝까지
%     남는다). 논문의 전진 접안은 3단계를 위치제어가 아니라 전후 속도 + 선수각
%     제어로 하므로 추진기 둘로도 되고, 그것은 이 사다리의 다음 칸이 아니다.
%
%   무엇이 비싼가
%     전후 속도 한계는 u_max = 1.5 m/s 이고 횡 속도 한계는 v_max = 0.6 m/s 다.
%     전진 접안은 그 빠른 쪽으로 들어가므로 gate 가 닫힌 뒤 관성으로 더 밀려
%     들어간다. 세 벌의 "선석을 지나 들어간 거리" 를 재어 견준다.
%
%   한 스텝 전 값 · AutoStop · 상태 11개 · 파일 규약은 5단과 같다
%     ph_prev 는 주요 스텝 경계에서만 갱신하고, RK4 의 네 소단계에서는 붙들어
%     둔 채 그 소단계의 상태로 거리와 선수각 오차만 다시 잰다. 자체 함수 없음,
%     설정은 W06_setup 에서만, 적분은 RK4, 간격은 Ts_ctrl.

%% ====================================================================
%  1. 설정 — 7단 설정을 불러온다
% =====================================================================
setappdata(0, 'W06_stage',    7);
setappdata(0, 'W06_skip_run', true);
W06_setup;

N_lim = 2*F_max*half_beam + F_bow_max*l_bow;

%  유도부가 쓰는 값 — task_q 에서 꺼낸다 (TaskFront 의 q 와 같은 순서)
dx = task_q(7);   dy = task_q(8);   dpsi = task_q(9);
Rd = task_q(10);  La = task_q(11);  sd   = task_q(12);  Rs = task_q(13);

h  = Ts_ctrl;
tt = (0:h:T_run)';
nt = numel(tt);

front_list = [1 0 1];           % 전진 · 옆걸음 · 전진(선수추진기 없음)
bow_list   = [1 1 0];
nv = numel(front_list);
REC = cell(1,nv);               % 배 상태 기록 (6개)
REF = cell(1,nv);               % 유도부가 낸 목표 기록 (x_ref y_ref psi_ref)
FRC = cell(1,nv);               % 실제 추력 기록
RPM = cell(1,nv);               % 회전수 기록
GPH = cell(1,nv);               % gate · phase 기록
NEN = zeros(1,nv);              % 벌마다 실제로 돈 표본 수
T_PH = nan(3,nv);               % 단계가 올라간 시각 (행 = phase 1·2·3)
T_HIT = nan(1,nv);              % gate 가 닫힌 시각
PSF  = zeros(1,nv);             % 벌마다의 접안 선수각

%% ====================================================================
%  2. 세 벌을 차례로 돌린다 — 상태 11개를 RK4 로 함께 적분한다
%     s(1:6) 배 · z(1:2) 속도 PI 적분기 · g(1:3) 추진기 회전수
%     ph_prev(래치) 와 held(정지 타이머) 는 스텝 경계에서만 움직인다
% =====================================================================
for i = 1:nv
    front_on = front_list(i);
    bow_on   = bow_list(i);

    %  접안 선수각과 접근점 — 첫째 벌은 TaskFront 와 글자 하나까지 같은 식이다
    %  (전진에서는 psi_f 와 psi_go 가 같은 값이므로 모델은 psi_f 로만 적는다)
    psi_f  = dpsi - front_on*sd*pi/2;   % 접안 선수각 — 전략이 갈리는 곳
    psi_go = dpsi - sd*pi/2;            % 접안 진행 방향 — 부두 쪽, 두 전략이 같다
    ax = dx - La*cos(psi_go);
    ay = dy - La*sin(psi_go);
    PSF(i) = psi_f;

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

            % --- 유도 : 단계마다 다른 목표 (TaskFront 와 같은 식) -------
            ph = ph_prev;
            if ph < 1
                %  1단계 — 접근점으로 간다. 선수각은 가는 방향으로 둔다
                x_ref = ax;  y_ref = ay;
                psi_ref = atan2(ay - y_n, ax - x_n);
                if sqrt((ax - x_n)^2 + (ay - y_n)^2) < Rd, ph = 1; end
            elseif ph < 2
                %  2단계 — 접근점에 머물며 선수각만 접안 선수각으로
                x_ref = ax;  y_ref = ay;  psi_ref = psi_f;
                if abs(atan2(sin(psi_f - psi), cos(psi_f - psi))) < 5*pi/180
                    ph = 2;
                end
            else
                %  3단계 — 선수각을 지킨 채 선석에 붙인다 (전진 또는 옆걸음)
                x_ref = dx;  y_ref = dy;  psi_ref = psi_f;
                if sqrt((dx - x_n)^2 + (dy - y_n)^2) < Rs, ph = 3; end
            end
            gate = double(ph < 3);

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

            % --- 추력 배분 : bow_on 이 붙는 곳은 여기 한 군데다 --------
            FB_c  = min(max(bow_on*Y, -F_bow_max), F_bow_max);
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
%  3. 결과 — 세 벌을 나란히 찍는다
% =====================================================================
psi_go = dpsi - sd*pi/2;                                  % 접안 진행 방향
ax1 = dx - La*cos(psi_go);   ay1 = dy - La*sin(psi_go);   % 세 벌이 같은 점이다
fprintf('\n[m 파일] 7단 전진 접안  —  선석 (%g, %g) m,  선석 방위 %g deg\n', ...
        dx, dy, rad2deg(dpsi));
fprintf('  접근점 (%g, %g) m,  전환반경 R_dock = %g m,  도착반경 R_stop = %g m\n', ...
        ax1, ay1, Rd, Rs);
fprintf('  출발 선수각 %.2f deg (접근점 방향),  정지 유예 stop_hold = %g s\n', ...
        rad2deg(x0(6)), stop_hold);
fprintf('  속도 한계 u_max = %g m/s (전진) · v_max = %g m/s (옆걸음)\n', u_max, v_max);
way = {'전진 접안 — 선수를 부두로 돌려 앞으로', ...
       '옆걸음 접안 — 선석과 나란히 서서 옆으로 (5단)', ...
       '전진 접안, 선수추진기 없음 — 추진기 둘뿐인 배'};
for i = 1:nv
    rec = REC{i};  frc = FRC{i};  rpm = RPM{i};
    fprintf('  front_on = %d, bow_on = %d  (%s)\n', ...
            front_list(i), bow_list(i), way{i});
    fprintf('    접안 선수각 %7.2f deg\n', rad2deg(PSF(i)));
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
            rad2deg(atan2(sin(PSF(i) - rec(end,6)), cos(PSF(i) - rec(end,6)))));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N  (한계 %g · %g N)\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))), F_max, F_bow_max);
    fprintf('    회전수 최대 %6.1f  %6.1f  %6.1f rad/s  (한계 %.1f)\n', ...
            max(abs(rpm(:,1))), max(abs(rpm(:,2))), max(abs(rpm(:,3))), n_max);
end

%  선석을 지나 들어간 거리 — 전진 접안이 무엇을 치르는지 재는 지표다.
%  접근점에서 선석을 보는 방향을 양의 방향으로 잡고, 멈춘 자리를 그 축에
%  내리꽂는다. 양수면 선석을 지나 부두 쪽으로 들어간 것이고 음수면 못 간 것이다
ex = (dx - ax1)/La;   ey = (dy - ay1)/La;        % 접근점 -> 선석 단위벡터
fprintf('\n  선석에서 어긋난 거리 — 진행축(양수 = 부두 쪽으로 더) 과 그 옆축\n');
for i = 1:nv
    rec  = REC{i};
    ddx  = rec(end,4) - dx;   ddy = rec(end,5) - dy;
    down =  ex*ddx + ey*ddy;                    % 진행축 — 들어간 깊이
    side = -ey*ddx + ex*ddy;                    % 옆축 — 좌우로 벗어난 양
    fprintf('    front_on = %d, bow_on = %d :  진행축 %6.3f m,  옆축 %6.3f m', ...
            front_list(i), bow_list(i), down, side);
    if isnan(T_HIT(i))
        fprintf('   (gate 가 닫히지 않음 — 옆축 오차가 남아 붙지 못함)\n');
    else
        kh = find(tt(1:NEN(i)) >= T_HIT(i), 1);
        d0 = ex*(rec(kh,4) - dx) + ey*(rec(kh,5) - dy);
        fprintf('   (gate 닫힌 자리 %6.3f m -> 관성으로 %5.3f m 더)\n', ...
                d0, down - d0);
    end
end

%% ====================================================================
%  4. 그림 — 궤적 · 단계 · 남은 거리 · 선수각
% =====================================================================
figure('Name','W06 7단 — 전진 접안','Color','w','Position',[80 80 980 720]);
cl = {'-','--',':'};
lg = {'전진 (bow-first)','옆걸음 (lateral)','전진, 선수추진기 없음'};
th = linspace(0, 2*pi, 180);

subplot(2,2,1);
for i = 1:nv
    plot(REC{i}(:,5), REC{i}(:,4), cl{i}, 'LineWidth', 1.4); hold on;
end
plot(ay1 + Rd*cos(th), ax1 + Rd*sin(th), 'b:', 'LineWidth', 1.2);
plot(dy  + Rs*cos(th), dx  + Rs*sin(th), 'r:', 'LineWidth', 1.2);
plot([dy ay1], [dx ax1], 'k-.', 'LineWidth', 1.0);
plot(ay1, ax1, 'bo', 'MarkerSize', 9, 'MarkerFaceColor','b');
plot(dy,  dx,  'rp', 'MarkerSize', 13, 'MarkerFaceColor','r');
grid on; axis equal; xlabel('동 y [m]'); ylabel('북 x [m]');
title('궤적 (별 = 선석, 원 = 접근점)');
legend([lg {'R_{dock}','R_{stop}'}], 'Location','best');

subplot(2,2,2);
for i = 1:nv
    stairs(tt(1:NEN(i)), GPH{i}(:,2), cl{i}, 'LineWidth', 1.6); hold on;
end
grid on; ylim([-0.2 3.2]); xlabel('시간 [s]'); ylabel('phase [-]');
title('phase 는 올라가기만 함 — 1단계는 세 벌이 같음');
legend(lg, 'Location','best');

subplot(2,2,3);
for i = 1:nv
    plot(tt(1:NEN(i)), hypot(dx - REC{i}(:,4), dy - REC{i}(:,5)), ...
         cl{i}, 'LineWidth', 1.4); hold on;
end
yline(Rs, 'r:', 'LineWidth', 1.2);
for c = 1:3
    if ~isnan(T_PH(c,1)), xline(T_PH(c,1), 'k:', 'LineWidth', 1.0); end
end
grid on; xlabel('시간 [s]'); ylabel('선석까지 거리 [m]');
title('선석까지 남은 거리 (세로 점선 = 전진 벌의 단계 전이)');
legend(lg, 'Location','best');

subplot(2,2,4);
for i = 1:nv
    plot(tt(1:NEN(i)), rad2deg(REF{i}(:,3)), cl{i}, 'LineWidth', 1.0); hold on;
    plot(tt(1:NEN(i)), rad2deg(REC{i}(:,6)), cl{i}, 'LineWidth', 1.6);
end
grid on; xlabel('시간 [s]'); ylabel('선수각 [deg]');
title('2단계에서 갈라짐 — 전진은 -90 deg, 옆걸음은 0 deg (얇은 선 = 지령)');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다
%     첫째 벌(front_on = 1, bow_on = 1)이 W06_7_front 와 같아야 한다. 둘째는
%     5단 모델이 따로 있고, 세째는 대응하는 모델이 없다 (BowOn 게인은 2단에만
%     달려 있다) — 그래서 첫째 벌만 맞댄다.
% =====================================================================
animate = 0;
mdl_c = 'W06_7_front';
if ~exist([mdl_c '.slx'], 'file')
    fprintf('\n%s.slx 가 없어 대조를 건너뜀 — build_w06_models(7) 로 만들 것\n', mdl_c);
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

    fprintf('\n[대조] %s  vs  m 파일 첫째 벌  (표본 %d개 — 모델 %d, m 파일 %d)\n', ...
            mdl_c, n2, size(sl,1), NEN(1));
    fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
    fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
    fprintf('  x_ref %.2e m   y_ref %.2e m   psi_ref %.2e rad\n', d(7), d(8), d(9));
    fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(10), d(11), d(12));
    fprintf('  n  %.2e  %.2e  %.2e rad/s\n', dn(1), dn(2), dn(3));
    fprintf('  gate %.0e   phase %.0e  (0 이어야 전이 시각이 같다)\n', d(13), d(14));
end
