% W06_2_SWAY_M  2단을 m 파일 한 장으로 — 선수추진기를 켜고 끈 두 벌을 겹쳐 본다
%
%   >> W06_2_sway_m
%
%   무엇을 보는가
%     목표는 "선수각 0 deg 를 지킨 채 동쪽으로 12 m" 다. 북쪽 성분은 0 이므로
%     배가 할 일은 옆걸음뿐이다. 같은 목표를 두 번 돌린다.
%
%       bow_on = 1   선수추진기를 쓴다 — 동쪽 오차가 줄어 목표에 선다
%       bow_on = 0   횡력 지령이 끊긴다 — 추진기 둘뿐인 배가 된다
%
%     추진기 둘인 배는 동쪽 오차를 줄이지 못한다. 옆으로 밀 힘이 없기 때문이다.
%     그래도 선수각은 0 deg 로 잡힌다 — 요 모멘트는 좌·우 추진기의 차이로
%     내므로 선수추진기가 없어도 낼 수 있다. 위치와 선수각 가운데 **선수각만**
%     잡히는 것이 추진기 둘의 한계다.
%
%   1단(W06_1_point_m) 과 식이 똑같다. 딱 한 군데가 다르다
%
%       FB = bow_on * (횡 속도 PI 의 출력)        <- 여기 bow_on 이 붙었다
%
%   끄는 자리가 추력 배분 **앞** 인 까닭
%     배분 뒤에서 FB 를 0 으로 만들면, 배분이 되받아 둔 요 모멘트 -l_bow*FB 가
%     남아 내지도 않은 힘을 상쇄하려 들어 선수각까지 틀어진다. 앞에서 끊으면
%     "횡력만 못 내는 배" 가 되어 선수추진기의 몫만 또렷하게 보인다.
%
%   이 파일의 규칙 (1단과 같다)
%     자체 함수 없음 · 설정은 W06_setup 에서만 · 적분은 RK4, 간격은 Ts_ctrl

%% ====================================================================
%  1. 설정 — 2단의 목표로 바꿔 둔다
%     W06_setup 의 stage 는 1 이어도 된다. 2단의 목표를 아래에서 다시 주므로
%     Simulink 모델(W06_2_sway)도 같은 목표로 돈다 — 상수 블록이 이 변수를 읽는다
% =====================================================================
setappdata(0, 'W06_skip_run', true);
W06_setup;

x_d = sway_north;  y_d = sway_east;  psi_d = deg2rad(sway_deg);
x0(6) = psi_d;                  % 처음부터 목표 선수각으로 서 있다
gate  = 1;
N_lim = 2*F_max*half_beam + F_bow_max*l_bow;

h  = Ts_ctrl;
tt = (0:h:T_run)';
nt = numel(tt);

bow_list = [1 0];               % 선수추진기 켬 · 끔
REC = cell(1,2);                % 두 벌의 상태 기록
FRC = cell(1,2);                % 두 벌의 추력 기록

%% ====================================================================
%  2. 두 벌을 차례로 돌린다 — 바깥 for 가 bow_on 을 바꾼다
% =====================================================================
for i = 1:2
    bow_on = bow_list(i);
    s = x0;
    z = [0; 0];
    rec = zeros(nt, 6);
    frc = zeros(nt, 3);
    K   = zeros(8, 4);

    for k = 1:nt
        rec(k,:) = s';

        for j = 1:4
            %  RK4 의 네 지점 (1단과 같다)
            switch j
                case 1, q = s;                     w = z;
                case 2, q = s + h/2*K(1:6,1);      w = z + h/2*K(7:8,1);
                case 3, q = s + h/2*K(1:6,2);      w = z + h/2*K(7:8,2);
                case 4, q = s + h  *K(1:6,3);      w = z + h  *K(7:8,3);
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

            % --- 추력 배분 — 1단과 다른 곳은 bow_on 한 군데뿐 ----------
            FB = min(max(bow_on*Y, -F_bow_max), F_bow_max);
            M_yaw = N_mom - l_bow*FB;
            FL = min(max(X/2 + M_yaw/(2*half_beam), -F_max), F_max);
            FR = min(max(X/2 - M_yaw/(2*half_beam), -F_max), F_max);

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
                       dz ];

            if j == 1, frc(k,:) = [FL FR FB]; end
        end

        s = s + h/6*(K(1:6,1) + 2*K(1:6,2) + 2*K(1:6,3) + K(1:6,4));
        z = z + h/6*(K(7:8,1) + 2*K(7:8,2) + 2*K(7:8,3) + K(7:8,4));
    end

    REC{i} = rec;
    FRC{i} = frc;
end

%% ====================================================================
%  3. 결과 — 두 벌을 나란히 찍는다
% =====================================================================
fprintf('\n[m 파일] 2단 순수 횡이동  —  목표 (%g, %g) m,  선수각 %g deg\n', ...
        x_d, y_d, rad2deg(psi_d));
for i = 1:2
    rec = REC{i};  frc = FRC{i};
    fprintf('  bow_on = %d\n', bow_list(i));
    fprintf('    끝 자세    x = %7.3f  y = %7.3f  psi = %7.3f deg\n', ...
            rec(end,4), rec(end,5), rad2deg(rec(end,6)));
    fprintf('    남은 거리  %6.3f m   (동쪽 오차 %6.3f m)\n', ...
            hypot(x_d - rec(end,4), y_d - rec(end,5)), y_d - rec(end,5));
    fprintf('    선수각     최대 틀어짐 %6.3f deg\n', ...
            max(abs(rad2deg(rec(:,6) - psi_d))));
    fprintf('    추력 최대  FL %6.1f  FR %6.1f  FB %6.1f N\n', ...
            max(abs(frc(:,1))), max(abs(frc(:,2))), max(abs(frc(:,3))));
end

%% ====================================================================
%  4. 그림 — 동쪽 거리 · 선수각 · 횡속도 · 선수추진기 추력
% =====================================================================
figure('Name','W06 2단 — 선수추진기 켬·끔','Color','w','Position',[80 80 980 720]);
cl = {'-','--'};
lg = {'bow\_on = 1','bow\_on = 0'};

subplot(2,2,1);
for i = 1:2
    plot(tt, REC{i}(:,5), cl{i}, 'LineWidth', 1.4); hold on;
end
yline(y_d, 'r:', 'LineWidth', 1.2); grid on;
xlabel('시간 [s]'); ylabel('동 y [m]'); title('동쪽 거리 (점선 = 목표)');
legend(lg, 'Location','best');

subplot(2,2,2);
for i = 1:2
    plot(tt, rad2deg(REC{i}(:,6)), cl{i}, 'LineWidth', 1.4); hold on;
end
grid on; xlabel('시간 [s]'); ylabel('선수각 [deg]');
title('선수각 — 둘 다 묶여 있음');

subplot(2,2,3);
for i = 1:2
    plot(tt, REC{i}(:,2), cl{i}, 'LineWidth', 1.4); hold on;
end
yline(v_max, 'r:'); yline(-v_max, 'r:'); grid on;
xlabel('시간 [s]'); ylabel('v [m/s]'); title('횡속도 (점선 = 지령 포화)');

subplot(2,2,4);
for i = 1:2
    plot(tt, FRC{i}(:,3), cl{i}, 'LineWidth', 1.4); hold on;
end
grid on; xlabel('시간 [s]'); ylabel('FB [N]'); title('선수추진기 추력');

%% ====================================================================
%  5. Simulink 모델과 맞대 본다 — 두 벌 각각
% =====================================================================
if exist('W06_2_sway.slx', 'file')
    animate = 0;
    for i = 1:2
        bow_on = bow_list(i);
        out = sim('W06_2_sway');

        sl = [out.log_u.Data(:)   out.log_v.Data(:)   out.log_r.Data(:) ...
              out.log_x_n.Data(:) out.log_y_n.Data(:) out.log_psi.Data(:) ...
              out.log_FL.Data(:)  out.log_FR.Data(:)  out.log_FB.Data(:)];
        mm = [REC{i} FRC{i}];
        n2 = min(size(sl,1), nt);
        d  = max(abs(sl(1:n2,:) - mm(1:n2,:)));

        fprintf('\n[대조] bow_on = %d — Simulink 와 m 파일의 최대 차이 (표본 %d개)\n', ...
                bow_on, n2);
        fprintf('  x_n %.2e m   y_n %.2e m   psi %.2e rad\n', d(4), d(5), d(6));
        fprintf('  u %.2e   v %.2e m/s   r %.2e rad/s\n', d(1), d(2), d(3));
        fprintf('  FL %.2e   FR %.2e   FB %.2e N\n', d(7), d(8), d(9));
    end
else
    fprintf('\nW06_2_sway.slx 가 없어 대조를 건너뜀 — build_w06_models(2) 로 만들 것\n');
end
