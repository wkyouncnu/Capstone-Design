function cap = gz_shot_capture(dur, ivl, partition, model, alt, distro)
%GZ_SHOT_CAPTURE  가제보 드론뷰 떠내기를 **시작만** 하고 바로 돌아온다
%
%   cap = gz_shot_capture(120, 0.4, 'a3');   % 120 초 동안 0.4 초 간격
%   out = sim(mdl);                          % 그 사이 Simulink 가 돈다
%   [t, f] = gz_shot_read(cap);              % 찍힌 시각과 파일 목록
%
%   왜 바깥에서 받는가
%     sim() 이 도는 동안 MATLAB 은 묶여 있다. 가제보 화면은 WSL 쪽에서 따로
%     받아 폴더에 쌓아 두고, 끝난 뒤 읽어 영상으로 붙인다 (gz_split_video).
%
%   받는 일은 _tools/gz_shot_log.sh 가 한다. 그 사본을 윈도 임시 폴더로 옮겨
%   쓰는 이유 — 볼트 경로에 한글이 있어 WSL 로 그대로 넘기면 깨질 수 있다.
%
%   그림은 윈도 임시 폴더(<tempdir>\gzshot) 에 쌓인다. WSL 의 /tmp 는 윈도
%   쪽에서 바로 못 읽으므로, 처음부터 /mnt/c/... 로 쓰게 한다.

    if nargin < 1 || isempty(dur),       dur       = 120;             end
    if nargin < 2 || isempty(ivl),       ivl       = 0.4;             end
    if nargin < 3 || isempty(partition), partition = 'a3';            end
    if nargin < 4 || isempty(model),     model     = 'wamv';          end
    if nargin < 5 || isempty(alt),       alt       = 18;              end
    if nargin < 6 || isempty(distro),    distro    = 'Ubuntu-22.04';  end

    tools = fileparts(mfilename('fullpath'));
    sh    = fullfile(tempdir, 'gz_shot_log.sh');
    shots = fullfile(tempdir, 'gzshot');
    copyfile(fullfile(tools, 'gz_shot_log.sh'), sh);
    if ~isfolder(shots), mkdir(shots); end

    cmd = sprintf('bash %s %d %s %g %s %s %g', win2wsl(sh), round(dur), ...
                  win2wsl(shots), ivl, partition, model, alt);

    %  java 로 띄운다 — MATLAB 의 system() 은 윈도에서 끝날 때까지 기다린다
    pb  = java.lang.ProcessBuilder({'wsl.exe', '-d', distro, ...
                                    '-e', 'bash', '-lc', cmd});
    cap = struct('dir', shots, 'index', fullfile(shots, 'index.txt'), ...
                 'dur', dur, 'ivl', ivl, 'proc', pb.start());

    pause(3);                 % 카메라가 선박 위로 올라앉을 시간
    fprintf('    가제보 화면 떠내기 시작 — %s  (%g 초 간격, 최대 %g 초)\n', ...
            shots, ivl, dur);
end


function w = win2wsl(p)
%  C:\a\b  ->  /mnt/c/a/b
    p = strrep(p, '\', '/');
    w = ['/mnt/' lower(p(1)) p(3:end)];
end
