% A3_1_CRAB_RUN  1단 — 순수 횡이동(crabbing)을 돌리고 **선수각이 흔들리는지** 본다
%
%   >> A3_1_crab_run
%
%   하는 일
%     (1) 1단 설정으로 A3_setup 을 부른다 (stage = 1)
%     (2) A3_1_crab.slx 를 돌린다
%     (3) A3_plot 으로 그림과 지표를 낸다
%     (4) **두 번째 실행** — 속도 지령 한계를 풀어 추력이 한계에 닿을 때까지 밀어,
%         이 배가 옆으로 낼 수 있는 **최대 횡속도**를 잰다
%
%   답해야 하는 질문 (a)
%     "옆으로만 갈 때 선수각이 유지되는가, 흔들리는가"
%
%   읽는 법
%     S.psi_rms   선수각 오차 RMS [deg] — 이 값이 답이다
%     S.d_mean    움직이는 동안의 평균 방향각 [deg]. 순수 횡이동의 이론값은
%                 atan2(b, L) 이고 설정 출력의 d_sway 와 같아야 한다
%     S.v_ss      정상 구간 평균 횡속도 [m/s]
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 다음 단계다.

setappdata(0, 'A3_stage', 1);
setappdata(0, 'A3_skip_run', true);     % 설정만 받아 온다 — 실행은 이 파일이 한다
setappdata(0, 'A3_override', []);       % 앞 실습이 남긴 덮어쓰기를 지운다
A3_setup

load_system(mdl);
out = sim(mdl);
S   = A3_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));

%% ---- 질문 (a) 에 수치로 답한다 ----
fprintf('\n[1단 점검] 순수 횡이동 — 선수각 유지\n');
fprintf('           선수각 오차   RMS %.4f deg · 최대 %.4f deg\n', S.psi_rms, S.psi_pk);
fprintf('           방향각        평균 %.3f deg · 최대 %.3f deg  (이론 %.3f deg)\n', ...
        S.d_mean, S.d_pk, rad2deg(d_sway));
fprintf('           횡속도        정상 구간 %.3f m/s · 최대 %.3f m/s  (지령 한계 %.2f)\n', ...
        S.v_ss, S.v_pk, v_max);
fprintf('           전후 위치     마지막 |x_n| %.4f m   (옆으로만 갔다면 0 에 가깝다)\n', ...
        abs(out.log_x_n.Data(end)));
fprintf('           추력          최대 |T| %.1f N / 한계 %.0f N · 각도 포화 %.1f %% · 추력 포화 %.1f %%\n', ...
        S.T_pk, F_max, S.f_dsat, S.f_ksat);
if S.psi_rms < 0.5
    fprintf('           판정          선수각이 유지됨 (RMS < 0.5 deg) — 흔들림 없음\n');
else
    fprintf('           판정          선수각이 흔들림 (RMS %.2f deg) — Kp_psi · Kd_psi 를 다시 볼 것\n', ...
            S.psi_rms);
end

%% ---- 두 번째 실행 — 옆으로 낼 수 있는 **최대 속도** ----
%   1차 실행은 속도 지령 한계(v_max)에 걸려 멈추므로 추력 한계를 보지 못한다.
%   한계를 풀고 목표를 멀리 두어, 추력이 500 N 에 붙은 채로 정상 속도에 닿게 한다.
y_far = 200;
s = struct('v_max', 3.0, 'crab_east', y_far, 'T_run', 220);
setappdata(0, 'A3_override', s);
setappdata(0, 'A3_stage', 1);
setappdata(0, 'A3_skip_run', true);
A3_setup

out2 = sim(mdl);
v2   = abs(out2.log_v.Data);
t2   = out2.log_v.Time;
%   정상 구간 — **아직 목표에서 먼** 구간만 센다. 감속이 시작되면 섞이므로
%   남은 거리가 R_brake 의 네 배를 넘고, 가속이 끝난 뒤(10 s 이후)만 본다
seg   = (y_far - out2.log_y_n.Data) > 4*R_brake & t2 > 10;
v_cap = mean(v2(seg));

%   닫힌식과 대조 — 배분에서 바로 나오는 값이다
%     Y_max = F_max / (hypot(b,L)/(2b))  이고  Yv*v + Yvv*v|v| = Y_max
v_thy = (-Yv + sqrt(Yv^2 + 4*Yvv*Y_max)) / (2*Yvv);

fprintf('\n[1단 점검] 추력 한계까지 밀었을 때의 횡속도 (v_max 를 %.1f m/s 로 풀고 다시 실행)\n', s.v_max);
fprintf('           실측 %.3f m/s · 닫힌식 %.3f m/s · 차이 %.3f m/s\n', ...
        v_cap, v_thy, abs(v_cap - v_thy));
ep2 = atan2(sin(out2.log_psi_ref.Data - out2.log_psi.Data), ...
            cos(out2.log_psi_ref.Data - out2.log_psi.Data))*180/pi;
fprintf('           이때 최대 |T| %.1f N (한계 %.0f N) · 선수각 오차 RMS %.4f deg\n', ...
        max(max(abs(out2.log_TL.Data)), max(abs(out2.log_TR.Data))), F_max, ...
        sqrt(mean(ep2.^2)));

%% ---- 세 번째 실행 — **조류를 걸고** 선수각이 유지되는지 다시 본다 ----
%   첫 실행에서 선수각 오차가 0 으로 나오는 것은 제어가 잘 되었기 때문이 아니다.
%   순수 횡이동에서는 배분이 내는 요 모멘트가 **구조적으로 0** 이다 — 좌우 추력이
%   크기가 같고 방향이 반대라 b(T_L - T_R) 와 L(F_yL + F_yR) 이 정확히 상쇄된다.
%   흔들 것이 없으면 "흔들리지 않는다" 는 답은 증명이 못 된다. 그래서 **옆에서
%   비스듬히 미는 조류**를 걸어 선수각 고리가 실제로 버티는지를 본다.
s = struct('current_speed', 0.6, 'current_direction', 45, 'crab_east', 20, 'T_run', 150);
setappdata(0, 'A3_override', s);
setappdata(0, 'A3_stage', 1);
setappdata(0, 'A3_skip_run', true);
A3_setup

out3 = sim(mdl);
S3   = A3_plot(out3, '1단 — 순수 횡이동 (조류 0.6 m/s, 45 deg)');

fprintf('\n[1단 점검] 조류를 걸었을 때 — 질문 (a) 의 실제 답\n');
fprintf('           조류          %.1f m/s · %.0f deg (NED)\n', ...
        s.current_speed, s.current_direction);
fprintf('           선수각 오차   RMS %.4f deg · 최대 %.4f deg\n', S3.psi_rms, S3.psi_pk);
fprintf('           방향각        평균 %.3f deg (조류가 없을 때 %.3f deg)\n', ...
        S3.d_mean, S.d_mean);
fprintf('           전후 위치     마지막 |x_n| %.3f m\n', abs(out3.log_x_n.Data(end)));
fprintf('           추력          최대 |T| %.1f N · 각도 포화 %.1f %% · 추력 포화 %.1f %%\n', ...
        S3.T_pk, S3.f_dsat, S3.f_ksat);

setappdata(0, 'A3_override', []);       % **반드시 비운다** — 다음 실행까지 따라온다
S.v_cap  = v_cap;
S.v_thy  = v_thy;
S.cur    = S3;
