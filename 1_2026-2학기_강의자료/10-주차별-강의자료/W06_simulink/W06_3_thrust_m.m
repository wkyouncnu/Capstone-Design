% W06_3_THRUST_M  3단을 m 파일 한 장으로 — 추진기 동역학을 넣고 끈 두 벌을 겹쳐 본다
%
%   >> W06_3_thrust_m
%
%   무엇을 보는가
%     목표는 1단과 같다 (북 30 m, 동 20 m, 선수각 45 deg). 같은 목표를 두 번 돌린다.
%
%       lag_on = 1   추진기 동역학을 넣는다 — 추력 지령이 회전수로 바뀌고,
%                    모터가 그 회전수에 이르는 데 tau_n 만큼 걸린다
%       lag_on = 0   추력 지령이 그대로 힘이 된다 — 1단(W06_1_point)과 같다
%
%     정상상태에서는 둘이 같다. 역 프로펠러 법칙과 프로펠러 법칙이 서로의 역이라
%     모터가 자리를 잡으면 실제 추력이 지령 추력과 같아지기 때문이다. 달라지는
%     것은 과도구간뿐이다 — 실제 추력이 지령보다 늦게 서고, 지령 회전수가
%     n_max 를 넘으면 그 자리에서 잘린다.
%
%   상태가 셋 늘었다
%     1·2단은 상태 8개였다 (배 6 + 속도 PI 적분기 2). 3단은 11개다 — 추진기
%     회전수 셋이 상태로 들어온다.
%
%         dn_i/dt = (n_cmd_i - n_i) / tau_n            i = 좌 · 우 · 선수
%
%     Simulink 의 MotorLag 는 이 식을 상태공간 A = -I/tau_n, B = I/tau_n 으로
%     적은 것이다. 연속 Transfer Fcn 이 벡터를 못 받아 상태공간으로 적었을 뿐,
%     식은 위 한 줄과 같다.
%
%   세 토막의 식 (Thrusters 서브시스템과 같다)
%     F2n       n_cmd = sign(F_cmd) * sqrt(|F_cmd| / k_prop),  |n_cmd| <= n_max
%     MotorLag  위의 1차 지연
%     n2F       F = k_prop * n * |n|
%
%   포화가 회전수에 걸리는 까닭
%     모터가 묶는 것은 힘이 아니라 회전수다. 추력은 회전수의 제곱이므로
%     회전수에 건 제한이 추력에 비례해 걸리지 않는다 — n_max 에서 잘린 회전수가
%     낼 수 있는 힘은 k_prop * n_max^2 = F_max 다.
%
%   이 파일의 규칙 (1·2단과 같다)
%     자체 함수 없음 · 설정은 W06_setup 에서만 · 적분은 RK4, 간격은 Ts_ctrl

%% ====================================================================
%  1. 설정 — 1단과 같은 목표를 쓴다 (W06_setup 의 stage = 1 그대로)
% =====================================================================
setappdata(0, 'W06_skip_run', true);
W06_setup;

gate  = 1;                      % 3단에는 도착 판정이 없다 (4단에서 생긴다)
N_lim = 2*F_max*half_beam + F_bow_max*l_bow;

h  = Ts_ctrl;
tt = (0:h:T_run)';
nt = numel(tt);

lag_list = [1 0];               % 추진기 동역학 넣음 · 끔
REC = cell(1,2);                % 상태 기록 (배 6개)
FRC = cell(1,2);                % 실제 추력 기록
CMD = cell(1,2);                % 추력 지령 기록
RPM = cell(1,2);                % 회전수 기록

%% ====================================================================
%  2. 두 벌을 차례로 돌린다 — 상태 11개를 RK4 로 함께 적분한다
%     s(1:6) 배 · z(1:2) 속도 PI 적분기 · g(1:3) 추진기 회전수
% =====================================================================
for i = 1:2
    lag_on = lag_list(i);
    s = x0;
    z = [0; 0];
    g = [0; 0; 0];              % 회전수는 0 에서 시작한다 (MotorLag 의 X0)
    rec = zeros(nt, 6);
    frc = zeros(nt, 3);
    cmd = zeros(nt, 3);
    rpm = zeros(nt, 3);
    K   = zeros(11, 4);

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
            e_psi = atan2(sin(psi_d - psi), cos(psi_d - psi));
            N_pre = Kp_psi*e_psi - Kd_psi*r;
            N_mom = min(max(N_pre, -N_lim), N_lim);

            % --- 추력 배분 : 여기까지가 "지령" 이다 --------------------
            FB_c  = min(max(Y, -F_bow_max), F_bow_max);
            M_yaw = N_mom - l_bow*FB_c;
            FL_c  = min(max(X/2 + M_yaw/(2*half_beam), -F_max), F_max);
            FR_c  = min(max(X/2 - M_yaw/(2*half_beam), -F_max), F_max);

            % --- 추진기 : 지령 추력 -> 회전수 -> 지연 -> 실제 추력 ------
            %     F2n — 역 프로펠러 법칙, 포화는 회전수에 건다
            F_c   = [FL_c; FR_c; FB_c];
            n_cmd = sign(F_c) .* sqrt(abs(F_c)/k_prop);
            n_cmd = min(max(n_cmd, -n_max), n_max);

            if lag_on
                dg = (n_cmd - p)/tau_n;                 % MotorLag
                F  = k_prop * p .* abs(p);              % n2F
                n_now = p;
            else
                dg = [0; 0; 0];                         % 1단 — 지연이 없다
                F  = F_c;
                n_now = n_cmd;                          % 그릴 것은 지령 회전수뿐
            end
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
                frc(k,:) = [FL   FR   FB  ];
                cmd(k,:) = [FL_c FR_c FB_c];
                rpm(k,:) = n_now';
            end
        end

        s = s + h/6*(K(1:6, 1) + 2*K(1:6, 2) + 2*K(1:6, 3) + K(1:6, 4));
        z = z + h/6*(K(7:8, 1) + 2*K(7:8, 2) + 2*K(7:8, 3) + K(7:8, 4));
        g = g + h/6*(K(9:11,1) + 2*K(9:11,2) + 2*K(9:11,3) + K(9:11,4));
    end

    REC{i} = rec;  FRC{i} = frc;  CMD{i} = cmd;  RPM{i} = rpm;
end

%% ====================================================================
%  3. 결과 — 두 벌을 나란히 찍는다
% =====================================================================
fprintf('\n[m 파일] 3단 추진기 동역학  —  목표 (%g, %g) m,  선수각 %g deg\n', ...
        x_d, y_d, rad2deg(psi_d));
fprintf('  시정수 tau_n = %g s,  회전수 한계 n_max = %.1f rad/s\n', tau_n, n_max);
for i = 1:2
    rec = REC{i};  frc = FRC{i};  rpm = RPM{i};
    fprintf('  lag_on = %d\n', lag_list(i));
    fprintf('    끝 자세    x = %7.3f  y = %7.3f  psi = %7.3f deg\n', ...
            rec(end,4), rec(end,5), rad2deg(rec(end,6)));
    fprintf('    남은 거리  %6.3f m,  선수각 오차 %6.3f deg\n', ...
            hypot(x_d - rec(end,4), y_d - rec(end,5)), ...
            rad2deg(atan2(sin(psi_d - rec(end,6)), cos(psi_d - rec(end,6)))));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))));
    fprintf('    회전수 최대 %6.1f  %6.1f  %6.1f rad/s\n', ...
            max(abs(rpm(:,1))), max(abs(rpm(:,2))), max(abs(rpm(:,3))));
end

%  과도구간이 얼마나 늦는가 — 지령과 실제가 1 N 안으로 붙는 데 걸린 시간
d1 = abs(FRC{1}(:,1) - CMD{1}(:,1));
j1 = find(d1 > 1);
if isempty(j1)
    fprintf('  lag_on = 1 : 실제 추력이 지령에서 1 N 넘게 벌어진 적이 없음\n');
else
    fprintf('  lag_on = 1 : 좌현 추력이 지령과 1 N 안으로 붙는 시각 %.2f s (최대 차이 %.1f N)\n', ...
            tt(j1(end)), max(d1));
end
fprintf('  두 벌의 끝 자리 차이 %.3e m (정상상태에서는 같아야 함)\n', ...
        hypot(REC{1}(end,4) - REC{2}(end,4), REC{1}(end,5) - REC{2}(end,5)));

%% ====================================================================
%  4. 그림 — 궤적 · 좌현 추력(지령 대 실제) · 회전수 · 거리 오차
% =====================================================================
figure('Name','W06 3단 — 추진기 동역학','Color','w','Position',[80 80 980 720]);
cl = {'-','--'};
lg = {'lag\_on = 1 (추진기 동역학)','lag\_on = 0 (1단과 같음)'};

subplot(2,2,1);
for i = 1:2
    plot(REC{i}(:,5), REC{i}(:,4), cl{i}, 'LineWidth', 1.4); hold on;
end
plot(y_d, x_d, 'rp', 'MarkerSize', 12, 'MarkerFaceColor','r');
grid on; axis equal; xlabel('동 y [m]'); ylabel('북 x [m]');
title('궤적 (별 = 목표)'); legend(lg, 'Location','best');

subplot(2,2,2);
plot(tt, CMD{1}(:,1), 'r:', 'LineWidth', 1.6); hold on;
plot(tt, FRC{1}(:,1), '-',  'LineWidth', 1.4);
grid on; xlim([0 30]); xlabel('시간 [s]'); ylabel('F_L [N]');
title('좌현 추력 — 점선 = 지령, 실선 = 실제');
legend({'지령','실제'}, 'Location','best');

subplot(2,2,3);
plot(tt, RPM{1}(:,1), '-', 'LineWidth', 1.4); hold on;
plot(tt, RPM{1}(:,2), '-', 'LineWidth', 1.4);
plot(tt, RPM{1}(:,3), '-', 'LineWidth', 1.4);
yline( n_max, 'r:'); yline(-n_max, 'r:');
grid on; xlim([0 30]); xlabel('시간 [s]'); ylabel('n [rad/s]');
title('회전수 (점선 = n_{max})'); legend({'좌','우','선수'}, 'Location','best');

subplot(2,2,4);
for i = 1:2
    plot(tt, hypot(x_d - REC{i}(:,4), y_d - REC{i}(:,5)), cl{i}, 'LineWidth', 1.4);
    hold on;
end
grid on; xlabel('시간 [s]'); ylabel('남은 거리 [m]');
title('목표까지 남은 거리');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다
%     lag_on = 1 은 W06_3_thrust 와, lag_on = 0 은 1단 W06_1_point 와 같아야 한다
% =====================================================================
animate = 0;
chk = {'W06_3_thrust', 1; 'W06_1_point', 2};
for c = 1:2
    mdl_c = chk{c,1};  i = chk{c,2};
    if ~exist([mdl_c '.slx'], 'file')
        fprintf('\n%s.slx 가 없어 대조를 건너뜀 — build_w06_models 로 만들 것\n', mdl_c);
        continue
    end
    out = sim(mdl_c);

    sl = [out.log_u.Data(:)   out.log_v.Data(:)   out.log_r.Data(:) ...
          out.log_x_n.Data(:) out.log_y_n.Data(:) out.log_psi.Data(:) ...
          out.log_FL.Data(:)  out.log_FR.Data(:)  out.log_FB.Data(:)];
    mm = [REC{i} FRC{i}];
    n2 = min(size(sl,1), nt);
    d  = max(abs(sl(1:n2,:) - mm(1:n2,:)));

    fprintf('\n[대조] %s  vs  m 파일 lag_on = %d  (표본 %d개)\n', ...
            mdl_c, lag_list(i), n2);
    fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
    fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
    fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(7), d(8), d(9));

    %  회전수는 3단에만 있다 (1단은 NotYet 상자가 0 을 흘린다)
    if i == 1
        dn = max(abs(out.log_n.Data(1:n2,:) - RPM{i}(1:n2,:)));
        fprintf('  n  %.2e  %.2e  %.2e rad/s\n', dn(1), dn(2), dn(3));
    end
end
