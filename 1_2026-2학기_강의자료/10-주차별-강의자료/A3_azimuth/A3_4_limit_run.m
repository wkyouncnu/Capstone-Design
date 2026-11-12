% A3_4_LIMIT_RUN  4단 — **무엇을 빼면 깨지는가.** 한계를 하나씩 바꿔 같은 과업을 돌린다
%
%   >> A3_4_limit_run
%
%   하는 일
%     설정값 **하나씩만** 바꿔 같은 과업을 다시 돌리고, 지표를 한 표로 모은다.
%     모델은 1·2단 것을 그대로 쓴다. 새 모델을 만들지 않는다.
%
%   재는 것 일곱
%     기준            아무것도 바꾸지 않음 (배분 수준 2)
%     추력 반전 금지   rev_on = 0      — 추진기가 앞으로만 민다
%     각도 한계 ±15   d_max_deg = 15  — 설계 전제를 더 보수적으로
%     변화율 1/20     d_rate_deg = 30 — 선외기가 느리게 돌아간다
%     배분 0 공통각도  alloc_mode = 0  — 두 대를 **같은 각도**로 튼다 (가장 단순)
%     배분 1 pseudo-inverse alloc_mode = 1  — 추력 제곱합 최소. null space 보정 없음
%     배분 2 +null-space   alloc_mode = 2  — 기준과 같은 설정. 표의 기준점으로 둔다
%
%   배분 셋은 **같은 해의 직선 위에 있는 서로 다른 점**이다
%     식 셋에 미지수 넷이므로 해는 점이 아니라 직선 하나다. 어느 점을 고르든
%     X·Y·N 은 똑같이 만족한다 — 다른 것은 그 점에서의 **각도**뿐이고,
%     그 각도가 ±45 deg 안에 드는지가 갈린다
%
%   왜 1단과 2단을 둘 다 돌리는가
%     1단(순수 횡이동)  요구가 Y 하나뿐이다. null space 보정을 꺼도 차이가 없다
%                       (순수 횡이동의 보정량이 0 이므로). **추력 반전**이 여기서 깨진다
%     2단(위치·선수각)  요구가 X·Y·N 셋이다. 요구가 **쐐기 구간**에 들어가므로
%                       null space 보정을 끄면 여기서 깨진다
%     한 과업만 돌리면 둘 중 하나를 놓친다
%
%   이 파일은 **오프라인 운동모델만** 돌린다. Gazebo(VRX) 는 다음 단계다.

setappdata(0, 'A3_skip_run', true);
setappdata(0, 'A3_override', []);

%  바꿀 것 — 이름, 덮어쓸 값
C = { ...
    '기준',            struct();
    '추력 반전 금지',   struct('rev_on', 0);
    '각도 한계 ±15',   struct('d_max_deg', 15);
    '변화율 30 deg/s', struct('d_rate_deg', 30);
    '배분0 공통각도',  struct('alloc_mode', 0);
    '배분1 pseudo-inverse', struct('alloc_mode', 1);
    '배분2 +null-space',   struct('alloc_mode', 2) };

for st = [1 2]
    fprintf('\n');
    T = struct('nm', {}, 'done', {}, 'e_ss', {}, 'psi_rms', {}, 'psi_pk', {}, ...
               'v_ss', {}, 'd_pk', {}, 'f_dsat', {}, 'f_ksat', {}, 'f_rsat', {}, 'w_pk', {});

    for k = 1:size(C, 1)
        setappdata(0, 'A3_override', C{k,2});
        setappdata(0, 'A3_stage', st);
        setappdata(0, 'A3_skip_run', true);
        evalc('A3_setup');                    % 설정 출력을 표 앞에 쌓지 않는다
        o  = sim(mdl);
        Si = A3_plot(o, sprintf('%d단 — %s', st, C{k,1}));
        close(Si.fig);  close(Si.fig_chk);    % 표만 남긴다

        T(k).nm      = C{k,1};
        T(k).done    = Si.t_done;
        T(k).e_ss    = Si.e_ss;
        T(k).psi_rms = Si.psi_rms;
        T(k).psi_pk  = Si.psi_pk;
        T(k).v_ss    = Si.v_ss;
        T(k).d_pk    = Si.d_pk;
        T(k).f_dsat  = Si.f_dsat;
        T(k).f_ksat  = Si.f_ksat;
        T(k).f_rsat  = Si.chk.f_rsat;         % 각도가 변화율 한계에 걸린 시간 [%]
        T(k).w_pk    = max(Si.w_err(1:2));    % 힘 요구를 못 낸 최대폭 [N]
    end

    if st == 1
        fprintf('[4단] 1단 과업(순수 횡이동 %.0f m) — 한계를 하나씩 바꿨을 때\n', crab_east);
        fprintf('  바꾼 것            psi RMS [deg]   psi 최대 [deg]   횡속도 [m/s]   최대 delta [deg]   각도포화 [%%]   변화율 [%%]   못 낸 힘 [N]\n');
        for k = 1:numel(T)
            fprintf('  %-16s %13.3f   %14.3f   %12.3f   %16.2f   %12.1f   %10.1f   %12.2f\n', ...
                    T(k).nm, T(k).psi_rms, T(k).psi_pk, T(k).v_ss, ...
                    T(k).d_pk, T(k).f_dsat, T(k).f_rsat, T(k).w_pk);
        end
    else
        fprintf('[4단] 2단 과업(위치·선수각 (%.0f, %.0f) m · %.0f deg) — 한계를 하나씩 바꿨을 때\n', ...
                hold_north, hold_east, hold_deg);
        fprintf('  바꾼 것            도착 [s]   위치오차 [m]   psi RMS [deg]   최대 delta [deg]   각도포화 [%%]   추력포화 [%%]   변화율 [%%]   못 낸 힘 [N]\n');
        for k = 1:numel(T)
            if isnan(T(k).done)
                td = ' 미완료';
            else
                td = sprintf('%7.1f', T(k).done);
            end
            fprintf('  %-16s %s   %12.3f   %13.3f   %16.2f   %12.1f   %12.1f   %10.1f   %12.2f\n', ...
                    T(k).nm, td, T(k).e_ss, T(k).psi_rms, ...
                    T(k).d_pk, T(k).f_dsat, T(k).f_ksat, T(k).f_rsat, T(k).w_pk);
        end
    end

    if st == 1
        A3_lim1 = T;
    else
        A3_lim2 = T;
    end
end

setappdata(0, 'A3_override', []);       % **반드시 비운다**
setappdata(0, 'A3_stage', []);

fprintf('\n  읽는 법\n');
fprintf('    "못 낸 힘" 은 요구한 X·Y 와 실제로 난 X·Y 의 최대 차이다. 0 이 아니면\n');
fprintf('    그 한계 때문에 요구를 그대로 내지 못했다는 뜻이다 — 오류 메시지는 뜨지 않는다\n');
