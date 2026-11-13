function [t, dL, dR] = vrx_js_read(cap)
%VRX_JS_READ  vrx_js_capture 가 받아 둔 조인트 각도를 읽는다 [deg]
%
%   [t, dL, dR] = vrx_js_read(cap)
%
%   시각은 파일에 없다. timeout 이 정확히 cap.dur 초 동안만 받으므로 일정
%   간격 표본으로 보고 linspace 로 되돌린다 (vrx_js_log.sh 머리말 참조).

    t = [];  dL = [];  dR = [];
    for k = 1:20                            % 마지막 줄까지 쓰일 시간을 준다
        if exist(cap.file, 'file') && dir(cap.file).bytes > 0, break; end
        pause(0.5);
    end
    if ~exist(cap.file, 'file')
        fprintf(2, '  조인트 각도 파일이 없습니다 — %s\n', cap.file);  return
    end

    M = readmatrix(cap.file);
    if isempty(M) || size(M,2) < 2
        fprintf(2, '  조인트 각도를 한 줄도 받지 못했습니다\n');       return
    end
    %  조인트 한계는 ±pi 다 (URDF 의 revolute limit). 그보다 큰 값은 줄이
    %  덜 쓰인 채 읽힌 것이므로 버린다 — 프로펠러 각도(수백 rad)가 칸이
    %  밀려 들어오면 그래프가 못 쓰게 된다
    ok = all(abs(M(:,1:2)) <= pi + 1e-3, 2);
    if ~all(ok)
        fprintf('  덜 쓰인 줄 %d 개를 버렸습니다 (전체 %d 줄)\n', nnz(~ok), numel(ok));
    end

    t  = linspace(0, cap.dur, size(M,1))';
    t  = t(ok);
    dL = rad2deg(M(ok,1));
    dR = rad2deg(M(ok,2));
end
