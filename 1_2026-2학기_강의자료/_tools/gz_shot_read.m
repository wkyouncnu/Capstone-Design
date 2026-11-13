function [t, files] = gz_shot_read(cap)
%GZ_SHOT_READ  gz_shot_capture 가 쌓아 둔 그림의 **벽시계 시각**과 파일 목록
%
%   [t, files] = gz_shot_read(cap)
%     t      찍힌 시각 [epoch s]  — MATLAB 녹화의 posixtime 과 같은 눈금
%     files  그때의 png 파일 (윈도 경로)
%
%   같은 파일이 두 줄에 걸쳐 적힐 수 있다 — 서비스가 늦어 새 그림이 아직
%   없을 때다. 뒤의 줄을 버린다 (처음 찍힌 시각을 그 그림의 시각으로 둔다).

    t = [];  files = {};
    if ~isfile(cap.index)
        warning('gz_shot_read:none', '색인 파일이 없다 — %s', cap.index);
        return
    end

    fid = fopen(cap.index, 'r');
    C   = textscan(fid, '%f %s', 'Delimiter', ' ');
    fclose(fid);
    if isempty(C{1}), return, end

    ts = C{1};  fs = C{2};

    %  WSL 경로(/mnt/c/...) 를 윈도 경로로 되돌린다
    seen = containers.Map('KeyType','char','ValueType','logical');
    for k = 1:numel(ts)
        w = wsl2win(fs{k});
        if ~isfile(w), continue, end
        if isKey(seen, w), continue, end          % 같은 그림의 둘째 줄은 버린다
        seen(w)      = true;
        t(end+1,1)   = ts(k);                     %#ok<AGROW>
        files{end+1,1} = w;                       %#ok<AGROW>
    end
end


function w = wsl2win(p)
%  /mnt/c/a/b  ->  C:\a\b
    p = strtrim(p);
    if numel(p) > 6 && strncmp(p, '/mnt/', 5)
        w = [upper(p(6)) ':' strrep(p(7:end), '/', '\')];
    else
        w = p;
    end
end
