% A3_3_DOCK_RUN  3단 — 단계 전이 접안. 6주차 5단과 **같은 과업**을 추진기 둘로
%
%   >> A3_3_dock_run
%
%   하는 일
%     (1) 3단 설정으로 A3_setup 을 부른다 (stage = 3)
%     (2) A3_3_dock.slx 를 돌린다
%     (3) A3_plot 으로 그림과 지표를 낸다
%     (4) **두 번째 실행** — dock_on = 0 (단계를 밟지 않고 선석으로 직행) 과 견준다
%
%   과업의 세 단계 (유도부가 스스로 올린다 · 한 번 올라가면 내려오지 않는다)
%     1단계  접근점으로 간다 — 선수각은 가는 방향 (저항이 작다)
%     2단계  접근점에 머물며 선수각만 접안 선수각으로 돌린다
%     3단계  선수각을 지킨 채 **옆걸음으로** 선석에 밀어 넣는다
%
%   3단계가 이 부록의 요점이다
%     선수각을 고정한 채 옆으로만 들어가는 구간이므로, 아지무스 추진기가 없으면
%     애초에 밟을 수 없는 단계다. 6주차는 선수추진기로, 여기서는 **방향각으로** 낸다
%
%   읽는 법
%     S.t_phase    단계가 올라간 시각 셋 [s]
%     S.e_final    마지막 위치 오차 [m]
%     S.epsi_ss    마지막 10 초 평균 선수각 오차 [deg] — 접안 선수각을 지켰는가
%     S.f_dsat     각도 한계에 붙어 있던 시간 비율 [%]
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 다음 단계다.

setappdata(0, 'A3_stage', 3);
setappdata(0, 'A3_skip_run', true);
setappdata(0, 'A3_override', []);
A3_setup

load_system(mdl);
out = sim(mdl);
S   = A3_plot(out, sprintf('%d단 — %s', stage, stage_name{stage}));

%% ---- 단계가 제때 올라갔는가 ----
ph_name = {'접근점 도달', '선수각 정렬 완료', '선석 도달'};
fprintf('\n[3단 점검] 단계 전이 접안\n');
fprintf('           선석          (%.1f, %.1f) m · %.1f deg · 댈 현 %+d\n', ...
        dock_north, dock_east, dock_deg, berth_side);
fprintf('           접근점        (%.1f, %.1f) m  (선석에서 %.0f m)\n', ...
        app_north, app_east, L_app);
for k = 1:3
    if isnan(S.t_phase(k))
        fprintf('           phase %d (%s)  올라가지 못했다\n', k, ph_name{k});
    else
        fprintf('           phase %d (%s)  %.1f s\n', k, ph_name{k}, S.t_phase(k));
    end
end
fprintf('           마지막 오차   위치 %.3f m · 선수각 %.3f deg  (판정선 %.1f m)\n', ...
        S.e_final, S.epsi_final, R_stop);
fprintf('           마지막 10 초  위치 %.3f m · 선수각 %.3f deg\n', S.e_ss, S.epsi_ss);
fprintf('           추력          최대 |T| %.1f N / 한계 %.0f N · 추력 포화 %.1f %%\n', ...
        S.T_pk, F_max, S.f_tsat);
fprintf('           방향각        최대 %.2f deg / 한계 %.0f deg · 각도 포화 %.1f %%\n', ...
        S.d_pk, d_max_deg, S.f_dsat);

%   옆걸음 구간만 따로 — 이 구간이 아지무스 추진기의 몫이다
%     phase 값은 **올라간 뒤의 상태**를 뜻한다. phase = 2 가 "선수각 정렬이
%     끝나 이제 선석으로 밀어 넣는 중", phase = 3 이 "선석에 닿았다" 이므로
%     옆걸음 구간은 phase == 2 다. phase >= 3 으로 잡으면 도착 뒤 정지 구간을
%     재게 되어 선수각 오차가 0, 횡속도가 0 으로 읽힌다 (처음에 그렇게 틀렸다)
ph  = out.log_phase.Data;
t   = out.log_phase.Time;
in3 = ph >= 2 & ph < 3;
if any(in3)
    ep  = atan2(sin(out.log_psi_ref.Data - out.log_psi.Data), ...
                cos(out.log_psi_ref.Data - out.log_psi.Data))*180/pi;
    dLd = abs(out.log_dL.Data)*180/pi;
    dRd = abs(out.log_dR.Data)*180/pi;
    fprintf('\n           -- 옆걸음 구간만 (phase = 2) %.1f ~ %.1f s --\n', ...
            t(find(in3,1)), t(find(in3,1,'last')));
    fprintf('           선수각 오차   RMS %.3f deg · 최대 %.3f deg\n', ...
            sqrt(mean(ep(in3).^2)), max(abs(ep(in3))));
    fprintf('           방향각        평균 %.2f deg · 최대 %.2f deg  (순수 횡이동 %.2f)\n', ...
            mean([dLd(in3); dRd(in3)]), max(max(dLd(in3)), max(dRd(in3))), rad2deg(d_sway));
    fprintf('           횡속도        평균 %.3f m/s · 최대 %.3f m/s\n', ...
            mean(abs(out.log_v.Data(in3))), max(abs(out.log_v.Data(in3))));
end

if ~isnan(S.t_phase(3)) && S.e_ss < 2*R_stop && abs(S.epsi_ss) < 3
    fprintf('           판정          세 단계를 밟고 접안했다 — 6주차와 같은 과업 성공\n');
else
    fprintf('           판정          접안하지 못했다 — 단계 전이 시각부터 볼 것\n');
end

%% ---- 두 번째 실행 — 단계를 나누지 않으면 어떻게 되는가 ----
%   dock_on = 0 이면 처음부터 목표가 선석이다. 어느 현을 댈지 고르지 못하므로
%   배가 선석에 비스듬히 닿는다. **단계를 나누는 값어치**를 재는 자리다
s = struct('dock_on', 0);
setappdata(0, 'A3_override', s);
setappdata(0, 'A3_stage', 3);
setappdata(0, 'A3_skip_run', true);
A3_setup
o0 = sim(mdl);
S0 = A3_plot(o0, '3단 — 단계를 나누지 않음 (dock_on = 0)');
setappdata(0, 'A3_override', []);       % **반드시 비운다**

fprintf('\n[3단 점검] 단계를 나누는 값어치 — 같은 선석, 같은 게인\n');
fprintf('  경우                    마지막 위치 [m]   마지막 선수각 [deg]   psi RMS [deg]   각도포화 [%%]\n');
fprintf('  세 단계 (dock_on = 1)   %15.3f   %19.3f   %13.3f   %12.1f\n', ...
        S.e_ss,  S.epsi_ss,  S.psi_rms,  S.f_dsat);
fprintf('  직행   (dock_on = 0)   %15.3f   %19.3f   %13.3f   %12.1f\n', ...
        S0.e_ss, S0.epsi_ss, S0.psi_rms, S0.f_dsat);

S.direct = S0;
