% W06_1_POINT_M  1단을 Simulink 없이 m 파일 한 장으로 — 그리고 두 결과를 맞대 본다
%
%   >> W06_1_point_m
%
%   왜 같은 것을 두 번 만드는가
%     Simulink 도면은 신호의 흐름이 눈에 보이는 대신, 블록 안에서 무슨 수식이
%     도는지는 하나씩 열어 보아야 안다. m 파일은 그 반대다 — 식은 위에서
%     아래로 그대로 읽히지만 흐름은 머릿속으로 그려야 한다. 둘을 함께 두면
%     한쪽이 다른 쪽의 답지가 된다. 끝에서 두 결과의 최대 차이를 재어 찍는다.
%
%   이 파일의 규칙
%     (1) 자체 함수를 두지 않음 — 위에서 아래로 한 번 읽으면 끝남
%     (2) 설정은 W06_setup 하나에서만 읽음 (게인을 두 군데 적어 두면 반드시 갈라짐)
%     (3) 적분은 RK4, 간격은 Ts_ctrl — Simulink 모델의 ode4 고정간격과 같은 식
%
%   RK4 를 안쪽 for 로 도는 까닭
%     RK4 는 한 걸음에 미분을 네 번 잰다. 미분식을 네 번 적으면 네 군데를
%     똑같이 고쳐야 하므로, 자리만 바꾸어 네 번 도는 for 하나로 적는다.
%
%       s(t+h) = s + h/6 * (K1 + 2*K2 + 2*K3 + K4)
%         K1 = f(s)            K2 = f(s + h/2*K1)
%         K3 = f(s + h/2*K2)   K4 = f(s + h*K3)
%
%   상태는 여덟 개다 — 배의 여섯 개와 PI 적분기 두 개
%     s = [u v r x_n y_n psi]'      z = [전후 PI 적분량; 횡 PI 적분량]
%   PI 적분기도 상태이므로 제어기를 플랜트와 **함께** 적분한다. 그래야
%   Simulink 가 연속 블록으로 푸는 것과 같은 답이 된다.
%
%   고리 셋 (모델의 OuterLoop · InnerLoop 와 같은 순서)
%     위치 P     위치 오차를 선체좌표로 돌려 속도 지령으로 — 포화 u_max · v_max
%     속도 PI    속도 오차를 추력으로 — 출력 포화 + clamping (wind-up 방지)
%     선수각 P-D 선수각 오차와 요각속도로 요 모멘트
%   그 뒤 추력 배분이 X · Y · N 을 좌·우·선수 추진기로 나눈다.

%% ====================================================================
%  1. 설정 — 모델과 똑같은 값을 쓴다
%     W06_setup 은 끝에서 Simulink 모델을 돌리므로, 돌지 않게 먼저 일러둔다
%     (이 플래그는 W06_setup 안의 clear 로 지워지지 않는 자리에 둔다)
% =====================================================================
setappdata(0, 'W06_skip_run', true);
W06_setup;                      % stage = 1 로 두고 실행할 것

gate = 1;                       % 1단의 유도부는 gate 를 늘 1 로 열어 둔다
N_lim = 2*F_max*half_beam + F_bow_max*l_bow;    % 요 모멘트 포화 [N m]

%% ====================================================================
%  2. 시간과 초기 상태
% =====================================================================
h  = Ts_ctrl;                   % 적분 간격 [s] — 모델의 FixedStep 과 같다
tt = (0:h:T_run)';
nt = numel(tt);

s = x0;                         % [u v r x_n y_n psi]'  (W06_setup 12절)
z = [0; 0];                     % PI 적분량 둘 — 처음에는 0

rec = zeros(nt, 6);             % 상태 기록
frc = zeros(nt, 3);             % 추력 기록 [FL FR FB]
K   = zeros(8, 4);              % RK4 의 네 미분

%% ====================================================================
%  3. 시간 전진 — 한 걸음에 미분 네 번 (RK4)
% =====================================================================
for k = 1:nt
    rec(k,:) = s';

    for j = 1:4
        %  이번에 미분을 잴 자리 — RK4 의 네 지점
        switch j
            case 1, q = s;                     w = z;
            case 2, q = s + h/2*K(1:6,1);      w = z + h/2*K(7:8,1);
            case 3, q = s + h/2*K(1:6,2);      w = z + h/2*K(7:8,2);
            case 4, q = s + h  *K(1:6,3);      w = z + h  *K(7:8,3);
        end
        u = q(1);  v = q(2);  r = q(3);  x_n = q(4);  y_n = q(5);  psi = q(6);

        % --- 바깥 고리 : 위치 오차 -> 속도 지령 ------------------------
        %  NED 오차를 선체고정으로 돌린다. e_x 앞쪽, e_y 우현쪽 [m]
        e_N = x_d - x_n;
        e_E = y_d - y_n;
        e_x =  cos(psi)*e_N + sin(psi)*e_E;
        e_y = -sin(psi)*e_N + cos(psi)*e_E;
        u_cmd = gate * min(max(Kp_x*e_x, -u_max), u_max);
        v_cmd = gate * min(max(Kp_y*e_y, -v_max), v_max);

        % --- 안쪽 고리 : 속도 오차 -> 추력 (PI) ------------------------
        e_u = u_cmd - u;
        e_v = v_cmd - v;
        X_pre = Kp_u*e_u + Ki_u*w(1);           % 포화 전
        Y_pre = Kp_v*e_v + Ki_v*w(2);
        X = min(max(X_pre, -2*F_max),   2*F_max);
        Y = min(max(Y_pre, -F_bow_max), F_bow_max);

        %  clamping — 출력이 포화에 닿았고 오차가 더 밀어붙이는 쪽이면 적분을 멈춘다.
        %  그래야 멀리 있을 때 쌓인 적분량이 다 왔을 때 배를 지나치게 하지 않는다
        dz = [e_u; e_v];
        if X ~= X_pre && sign(e_u) == sign(X_pre - X), dz(1) = 0; end
        if Y ~= Y_pre && sign(e_v) == sign(Y_pre - Y), dz(2) = 0; end

        % --- 선수각 P-D -----------------------------------------------
        %  각도차는 반드시 ±pi 로 접는다 (ssa). 접지 않으면 350 deg 틀어진 것을
        %  10 deg 반대로 도는 대신 긴 쪽으로 돌려 버린다
        e_psi = atan2(sin(psi_d - psi), cos(psi_d - psi));
        N_pre = Kp_psi*e_psi - Kd_psi*r;
        N_mom = min(max(N_pre, -N_lim), N_lim);

        % --- 추력 배분 : X · Y · N 을 추진기 셋으로 --------------------
        %  선수추진기가 횡력을 내면 요 모멘트 l_bow*FB 가 딸려 온다.
        %  좌·우 추진기가 그만큼 되받아야 선수각이 틀어지지 않는다
        FB = min(max(Y, -F_bow_max), F_bow_max);
        M_yaw = N_mom - l_bow*FB;
        FL = min(max(X/2 + M_yaw/(2*half_beam), -F_max), F_max);
        FR = min(max(X/2 - M_yaw/(2*half_beam), -F_max), F_max);

        % --- 운동방정식 (3자유도) --------------------------------------
        %  조류는 상대속도에만 들어간다 — 저항은 물에 대한 속도로 생긴다
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
                   dz ];

        if j == 1, frc(k,:) = [FL FR FB]; end   % 기록은 그 시각의 값으로
    end

    s = s + h/6*(K(1:6,1) + 2*K(1:6,2) + 2*K(1:6,3) + K(1:6,4));
    z = z + h/6*(K(7:8,1) + 2*K(7:8,2) + 2*K(7:8,3) + K(7:8,4));
end

%% ====================================================================
%  4. 결과 — 끝 자세와 추력
% =====================================================================
fprintf('\n[m 파일] 1단  %g s,  %d 걸음 (h = %g s)\n', T_run, nt, h);
fprintf('  끝 자세   x = %7.3f  y = %7.3f  psi = %7.2f deg\n', ...
        rec(end,4), rec(end,5), rad2deg(rec(end,6)));
fprintf('  목표      x = %7.3f  y = %7.3f  psi = %7.2f deg\n', ...
        x_d, y_d, rad2deg(psi_d));
fprintf('  남은 거리 %6.3f m,  선수각 오차 %6.3f deg\n', ...
        hypot(x_d - rec(end,4), y_d - rec(end,5)), ...
        rad2deg(atan2(sin(psi_d - rec(end,6)), cos(psi_d - rec(end,6)))));
fprintf('  속도 끝   u = %7.4f  v = %7.4f m/s\n', rec(end,1), rec(end,2));
fprintf('  추력 최대 FL %6.1f  FR %6.1f  FB %6.1f N  (한계 %g · %g)\n', ...
        max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))), F_max, F_bow_max);

%% ====================================================================
%  5. 그림 넷 — 궤적 · 선수각 · 속도 · 추력
% =====================================================================
figure('Name','W06 1단 — m 파일','Color','w','Position',[80 80 980 720]);

subplot(2,2,1);
plot(rec(:,5), rec(:,4), 'LineWidth', 1.4); hold on; grid on; axis equal;
plot(y_d, x_d, 'rp', 'MarkerSize', 14, 'MarkerFaceColor','r');
plot(rec(1,5), rec(1,4), 'ko', 'MarkerFaceColor','k');
xlabel('동 y [m]'); ylabel('북 x [m]'); title('항적 (목표 = 별)');

subplot(2,2,2);
plot(tt, rad2deg(rec(:,6)), 'LineWidth', 1.4); hold on; grid on;
yline(rad2deg(psi_d), 'r--', 'LineWidth', 1.2);
xlabel('시간 [s]'); ylabel('선수각 [deg]'); title('선수각과 목표');

subplot(2,2,3);
plot(tt, rec(:,1), 'LineWidth', 1.4); hold on; grid on;
plot(tt, rec(:,2), 'LineWidth', 1.4);
xlabel('시간 [s]'); ylabel('속도 [m/s]'); title('선체속도');
legend('u 전후','v 횡','Location','best');

subplot(2,2,4);
plot(tt, frc, 'LineWidth', 1.2); grid on;
xlabel('시간 [s]'); ylabel('추력 [N]'); title('추진기 셋');
legend('FL 좌','FR 우','FB 선수','Location','best');

%% ====================================================================
%  6. Simulink 모델과 맞대 본다
%     같은 식 · 같은 적분법이므로 두 답은 같아야 한다. 차이가 0 에 가깝지
%     않으면 어느 한쪽을 잘못 적은 것이다 — 그것이 이 절의 쓸모다.
% =====================================================================
if exist('W06_1_point.slx', 'file')
    animate = 0;                               % 그림 창을 또 열지 않는다
    out = sim('W06_1_point');

    sl = [out.log_u.Data(:)   out.log_v.Data(:)   out.log_r.Data(:) ...
          out.log_x_n.Data(:) out.log_y_n.Data(:) out.log_psi.Data(:) ...
          out.log_FL.Data(:)  out.log_FR.Data(:)  out.log_FB.Data(:)];
    mm = [rec frc];
    n2 = min(size(sl,1), nt);

    nm = {'u [m/s]','v [m/s]','r [rad/s]','x_n [m]','y_n [m]','psi [rad]', ...
          'FL [N]','FR [N]','FB [N]'};
    fprintf('\n[대조] Simulink 와 m 파일의 최대 차이 — 표본 %d 개\n', n2);
    for k = 1:9
        fprintf('  %-10s  %.3e\n', nm{k}, max(abs(sl(1:n2,k) - mm(1:n2,k))));
    end

    subplot(2,2,1);
    plot(sl(1:n2,5), sl(1:n2,4), 'r--', 'LineWidth', 1.0);
    title('항적 — 실선 m 파일, 점선 Simulink');
else
    fprintf('\nW06_1_point.slx 가 없어 대조를 건너뜀 — build_w06_models(1) 로 만들 것\n');
end
