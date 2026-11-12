% A3_2_POSE_RUN  2단 — 위치·선수각 (x, y, psi) 유지가 **되는가**
%
%   >> A3_2_pose_run
%
%   하는 일
%     (1) 2단 설정으로 A3_setup 을 부른다 (stage = 2)
%     (2) A3_2_pose.slx 를 돌린다 — 목표점에 목표 선수각으로 서서 멈춘다
%     (3) A3_plot 으로 그림과 지표를 낸다
%     (4) **두 번째 실행** — 선수각 목표를 바꿔 가며 (0 · 45 · 90 deg) 셋을 비교한다
%
%   답해야 하는 질문 (b)
%     "6주차처럼 (x, y, psi) 세 개를 동시에 세울 수 있는가"
%
%   읽는 법
%     S.e_final     마지막 위치 오차 [m]  — R_stop(1.5 m) 안이어야 성공
%     S.epsi_final  마지막 선수각 오차 [deg]
%     S.t_done      도착 시각 [s]  (NaN 이면 끝까지 못 섰다)
%     S.f_dsat      각도 한계에 붙어 있던 시간 비율 [%] — 쐐기 구간을 밟았는지
%
%   6주차와 **게인이 같다** (A3_setup 4절). 추진기 배치만 다르므로 숫자를
%   그대로 6주차와 견줄 수 있다.
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 다음 단계다.

setappdata(0, 'A3_stage', 2);
setappdata(0, 'A3_skip_run', true);
setappdata(0, 'A3_override', []);
A3_setup

load_system(mdl);
out = sim(mdl);
S   = A3_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));

%% ---- 질문 (b) 에 수치로 답한다 ----
fprintf('\n[2단 점검] 위치·선수각 동시 유지\n');
fprintf('           목표          (%.1f, %.1f) m · %.1f deg\n', x_d, y_d, rad2deg(psi_d));
fprintf('           도착          ');
if isnan(S.t_done)
    fprintf('미완료 — 끝까지 서지 못했다\n');
else
    fprintf('%.1f s  (전체 %.0f s 가운데)\n', S.t_done, T_run);
end
%   도착 순간의 오차와 그 뒤 **더 줄어든 거리**를 따로 본다
%     gate 는 표시등일 뿐 고리를 끊지 않는다. 도착 뒤에도 위치 고리가 계속
%     그 자리를 잡으므로 오차는 보통 더 줄어든다 — 아래 둘째 줄이 음수면 정상이다.
%     (2026-11-13 이전에는 gate 를 지령에 곱했고, 그 탓에 목표점을 지나쳤다)
dn   = hypot(x_d - out.log_x_n.Data, y_d - out.log_y_n.Data);
i_g  = find(out.log_gate.Data < 0.5, 1);
if isempty(i_g)
    d_gate = NaN;  d_coast = NaN;
else
    d_gate  = dn(i_g);
    d_coast = S.e_final - d_gate;
end
fprintf('           도착 순간     위치 오차 %.3f m  (판정선 %.1f m)\n', d_gate, R_stop);
fprintf('           그 뒤 변화     %+.3f m  (음수 = 더 좁혔다 · 고리는 계속 잡는다)\n', d_coast);
fprintf('           마지막 오차   위치 %.3f m · 선수각 %.3f deg\n', S.e_final, S.epsi_final);
fprintf('           마지막 10 초  위치 %.3f m · 선수각 %.3f deg\n', S.e_ss, S.epsi_ss);
fprintf('           선수각 오차   RMS %.3f deg · 최대 %.3f deg\n', S.psi_rms, S.psi_pk);
fprintf('           추력          최대 |T| %.1f N / 한계 %.0f N · 추력 포화 %.1f %%\n', ...
        S.T_pk, F_max, S.f_tsat);
fprintf('           방향각        최대 %.2f deg / 한계 %.0f deg · 각도 포화 %.1f %%\n', ...
        S.d_pk, d_max_deg, S.f_dsat);
fprintf('           요구 대비 실제 차이  X %.2f N · Y %.2f N · N %.2f N m\n', S.w_err);
%   합격선 — 도착 판정이 걸렸고(거리 < R_stop 이고 선수각 오차 < 5 deg),
%   선수각을 끝까지 유지했는가
ok = ~isnan(S.t_done) && abs(S.epsi_ss) < 2;
if ok
    fprintf('           판정          (x, y, psi) 셋을 동시에 세웠다 — 6주차와 같은 과업 성공\n');
else
    fprintf('           판정          세우지 못했다 — 도착 판정과 선수각 오차를 먼저 볼 것\n');
end

%% ---- 두 번째 실행 — 목표 선수각을 바꿔 가며 셋을 비교한다 ----
%   선수각 목표가 접근 방향과 **얼마나 어긋나는가**가 이 배의 난이도를 정한다.
%     0 deg   목표점 방향(33.7 deg)과 어긋남 -> 전진·횡이동·선회를 함께 요구
%     45 deg  기준 실행
%     90 deg  옆으로 선 채 비스듬히 접근 -> 요구가 쐐기 구간에 들어가기 쉽다
psi_try = [0 45 90];
R = struct('psi_deg', {}, 't_done', {}, 'd_gate', {}, 'e_ss', {}, ...
           'epsi_ss', {}, 'psi_rms', {}, 'd_pk', {}, 'f_dsat', {}, 'f_tsat', {});

for i_p = 1:numel(psi_try)
    s = struct('hold_deg', psi_try(i_p));
    setappdata(0, 'A3_override', s);
    setappdata(0, 'A3_stage', 2);
    setappdata(0, 'A3_skip_run', true);
    A3_setup
    o = sim(mdl);
    Si = A3_plot(o, sprintf('2단 — 목표 선수각 %d deg', psi_try(i_p)));
    close(Si.fig);                       % 표만 남긴다 — 그림 셋을 띄우지 않는다

    dni = hypot(x_d - o.log_x_n.Data, y_d - o.log_y_n.Data);
    igi = find(o.log_gate.Data < 0.5, 1);

    R(i_p).psi_deg = psi_try(i_p);
    R(i_p).t_done  = Si.t_done;
    if isempty(igi)
        R(i_p).d_gate = NaN;
    else
        R(i_p).d_gate = dni(igi);
    end
    R(i_p).e_ss    = Si.e_ss;
    R(i_p).epsi_ss = Si.epsi_ss;
    R(i_p).psi_rms = Si.psi_rms;
    R(i_p).d_pk    = Si.d_pk;
    R(i_p).f_dsat  = Si.f_dsat;
    R(i_p).f_tsat  = Si.f_tsat;
end
setappdata(0, 'A3_override', []);        % **반드시 비운다**

fprintf('\n[2단 점검] 목표 선수각을 바꿔 가며 (같은 목표점 (%.0f, %.0f) m)\n', x_d, y_d);
fprintf('  목표 psi   도착 [s]   도착시 오차 [m]   마지막 10초 [m]   psi RMS [deg]   최대 delta [deg]   각도포화 [%%]\n');
for i_p = 1:numel(R)
    if isnan(R(i_p).t_done)
        td = '  미완료';
    else
        td = sprintf('%8.1f', R(i_p).t_done);
    end
    fprintf('  %6.0f   %s   %15.3f   %13.3f   %13.3f   %16.2f   %12.1f\n', ...
            R(i_p).psi_deg, td, R(i_p).d_gate, R(i_p).e_ss, ...
            R(i_p).psi_rms, R(i_p).d_pk, R(i_p).f_dsat);
end

S.sweep = R;
