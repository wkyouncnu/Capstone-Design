function W06_model_done(mdl)
% W06_MODEL_DONE  모델의 StopFcn — 실행이 끝나면 최종 결과 그림을 그린다
%
%   실시간 그림(W06_animate)과 **별개**다. 주행 중에는 실시간 화면이 돌고,
%   끝나면 이 함수가 네 칸 결과 그림을 한 장 더 띄운다. m 파일로 돌렸을 때와
%   같은 그림이다 — 같은 W06_plot 을 부르므로 같을 수밖에 없다.
%
%   직접 Run 인가, m 파일의 sim() 인가 — 베이스의 out 으로 가른다
%     직접 Run 은 StopFcn 이 돌기 **전에** out 을 베이스 워크스페이스에 넣어 준다.
%     sim() 은 돌려준 **뒤에** 부른 쪽이 넣는다. InitFcn 이 out 을 비워 두므로
%     이 자리에서 out 이 있으면 직접 Run, 없으면 sim() 이다. sim() 이면 그리지
%     않는다 — 부른 m 파일이 자기 그림을 그리므로 같은 그림이 두 장 뜬다.
%
%   오프라인 모델이면 기준 궤적을 ref/ 에 남긴다. VRX 쌍둥이를 직접 Run 할 때
%   이것 위에 겹쳐 그린다 ([[W06_ref]]).
%
%   VRX 쌍둥이면 W06_vrx_report 가 결과 그림 · 동기 점검 · 대조까지 한다.

mdl = char(mdl);
if evalin('base', 'exist(''out'',''var'')') ~= 1
    return                                  % sim() 으로 돈 것 — 부른 쪽이 그린다
end
out = evalin('base', 'out');
[st, is_vrx] = W06_stage_of(mdl);

if is_vrx
    S = W06_vrx_report(mdl, out);
else
    sn = evalin('base', 'stage_name');
    S  = W06_plot(out, sprintf('%d단 — %s', st, sn{st}));
    fprintf('\n[%s] %d단 — %s\n', mdl, st, sn{st});
    fprintf('   완료 시각 %s s,  끝 오차 %.3f m,  선수각 끝 오차 %.2f deg\n', ...
            mat2str(round(S.t_done,2)), S.e_final, S.epsi_final);
    fprintf('   max|v| %.3f m/s,  max|F_B| %.1f N,  max|F_err| %.2e N\n', ...
            S.max_v, S.max_FB, S.max_Ferr);
    if finished(out)
        W06_ref('save', st, out, S);
    else
        fprintf('   손으로 멈춘 실행이라 기준 궤적을 덮어쓰지 않았다\n');
    end
end
assignin('base', 'S', S);
end

% ---------------------------------------------------------------------
function tf = finished(out)
%  끝까지 돈 실행인가 — 손으로 Stop 을 누른 것은 기준으로 쓰지 않는다
tf = true;
try
    tf = ~strcmpi(out.SimulationMetadata.ExecutionInfo.StopEvent, 'Stopped');
catch
end
end
