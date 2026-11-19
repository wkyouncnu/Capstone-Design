function S = TP_manual_stop(mdl)
%TP_MANUAL_STOP  수동 조종 모델의 StopFcn — 추력을 0 으로 돌려놓고 주행 요약을 찍는다
%
%   왜 0 을 보내는가
%     VRX 의 추진기 플러그인은 명령이 끊기면 **마지막 값을 유지한다.** 버튼을 누른 채
%     Stop 을 누르면 모델은 멎어도 배는 계속 간다. 그래서 끝에서 0 을 한 번 더 보낸다.
%
%   찍는 것 (GCS 가 쌓아 둔 기록에서)
%     주행 시간 · 지나온 거리 · WP1/WP2 위치유지 판정 · GPS 위치와 참값의 차이

mdl = char(mdl);
setappdata(0, 'TP_keys', zeros(1, 6));

if endsWith(mdl, '_vrx')
    try
        nd = ros2node(sprintf('/tp_stop_%d', randi(9999)));
        for side = {'left', 'right', 'bow'}
            pb  = ros2publisher(nd, ['/wamv/thrusters/' side{1} '/thrust'], 'std_msgs/Float64');
            msg = ros2message(pb);   msg.data = 0;
            for k = 1:5, send(pb, msg); pause(0.05); end
        end
        clear pb nd
        fprintf('\n[%s] 추력 셋을 0 으로 돌려놓았다\n', mdl);
    catch e
        warning('TP_manual:stop', '추력 0 을 보내지 못했다 (%s)', e.message);
    end
end

%  GCS 를 끄고 돌린 실행(animate = 0)에는 기록이 없다. 지난 실행의 요약을 찍지 않게 여기서 끝낸다
if isequal(getappdata(0, 'TP_gcs_on'), false)
    S = struct('n', 0);
    return
end
S = TP_gcs('result');
if isempty(S) || S.n < 2
    return
end
fprintf('\n[%s] 주행 요약\n', mdl);
fprintf('  주행 시간      : %.1f s   (기록 %d 점)\n', S.t(end) - S.t(1), S.n);
fprintf('  지나온 거리    : %.1f m\n', S.path);
fprintf('  끝 위치        : 북 %+.2f m · 동 %+.2f m   (위도 %.7f, 경도 %.7f)\n', ...
        S.x_n(end), S.y_n(end), S.lat(end), S.lon(end));
for k = 1:2
    if ~isnan(S.hold_done(k))
        fprintf('  WP%d 위치유지  : 성공 (t = %.1f s 에 판정)\n', k, S.hold_done(k));
    elseif S.inside(k)
        fprintf('  WP%d 위치유지  : 링 안에 들어갔으나 정지 유지 못 함 (끝 거리 %.2f m)\n', k, S.dist_end(k));
    else
        fprintf('  WP%d 위치유지  : 링에 들어가지 않음 (끝 거리 %.2f m)\n', k, S.dist_end(k));
    end
end
if endsWith(mdl, '_vrx')
    fprintf('  GPS - 참값     : RMS %.3f m · 최대 %.3f m   (전 구간, 선체 중심으로 옮긴 뒤)\n', ...
            sqrt(mean(S.gps_err.^2)), max(S.gps_err));
    %  동기 점검 — 모델이 가제보와 같은 빠르기로 돌았는가. k 가 1.08 을 넘으면 모델이 뒤처진 것이다
    if evalin('base', 'exist(''TP_RTF'',''var'')') == 1
        rtf = evalin('base', 'TP_RTF');
        fprintf('  동기 점검      : 모델 빠르기 %.3f · 가제보 RTF %.3f → k = %.3f', S.pace, rtf, rtf/S.pace);
        if rtf/S.pace > 1.08
            fprintf('   ** 모델이 뒤처졌다 — TP_manual_setup 의 animate_every 를 1.0 으로 올릴 것\n');
        else
            fprintf('   (1.08 이하면 정상)\n');
        end
    end
    if max(abs([S.FL; S.FR; S.FB])) > 50 && S.path < 0.5
        fprintf(['  ** 추력을 냈는데 배가 움직이지 않았다 — 배를 풀지 않은 것이다\n' ...
                 '     WSL :  export GZ_PARTITION=hy1; gz topic -t /vrx/release -m gz.msgs.Empty -p ""\n']);
    end
end
assignin('base', 'TP_last', S);
end
