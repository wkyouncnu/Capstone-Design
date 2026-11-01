function W08_dock_done(mdl)
% W08_DOCK_DONE  실습 E 모델의 StopFcn — 직접 Run 한 경우에만 결과 그림을 그린다.
%
%   왜 "직접 Run 한 경우에만" 인가
%     sim('W08_2_dock') 으로 돌리면 부른 쪽(W08_dock_setup 또는 교수님 스크립트)이
%     out 을 받아 스스로 그린다. 여기서 또 그리면 같은 그림이 두 번 뜬다.
%     Simulink 리본의 Run 은 베이스 워크스페이스에 out 을 남기고, sim() 은
%     남기지 않는다 (InitFcn 이 시작할 때 clear out 을 해 둔다) — 그것으로 가린다.

mdl = char(mdl);
if evalin('base', 'exist(''out'',''var'')') ~= 1
    return                                  % sim() 이 돌렸다. 부른 쪽이 그린다
end

out = evalin('base', 'out');
if contains(mdl, 'vrx')
    ttl = 'VRX 연동 — WP -> 로이터 -> WP -> 접안';
else
    ttl = '오프라인 — WP -> 로이터 -> WP -> 접안';
end

S = W08_dock_plot(out, ttl);
assignin('base', 'S', S);
end
