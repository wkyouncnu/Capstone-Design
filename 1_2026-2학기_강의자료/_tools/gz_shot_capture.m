function cap = gz_shot_capture(dur, ivl, partition, cen_enu, alt, distro)
%GZ_SHOT_CAPTURE  가제보 고정 탑다운 떠내기를 **시작만** 하고 바로 돌아온다
%
%   cap = gz_shot_capture(120, 0.4, 'a3', [-526 200], 26);
%   out = sim(mdl);                          % 그 사이 Simulink 가 돈다
%   [t, f] = gz_shot_read(cap);              % 찍힌 시각과 파일 목록
%
%   왜 바깥에서 받는가
%     sim() 이 도는 동안 MATLAB 은 묶여 있다. 가제보 화면은 WSL 쪽에서 따로
%     받아 폴더에 쌓아 두고, 끝난 뒤 읽어 영상으로 붙인다 (gz_split_video).
%
%   카메라는 **고정**이다 (2026-11-13 변경). follow 를 쓰면 선박이 늘 화면
%     한가운데에 머물러 이동량이 보이지 않는다. 배경을 멈춰 두어야 학습자가
%     얼마나 갔고 얼마나 돌았는지를 눈으로 잴 수 있다
%
%   입력
%     dur        받을 시간 [s]
%     ivl        간격 [s]. 0.4 보다 짧게 주면 가제보가 따라오지 못한다
%     partition  GZ_PARTITION (기본 'a3')
%     cen_enu    카메라가 내려다볼 지점 [ENU x y]. 보통 출발점과 목표점의
%                **중점**을 준다
%     alt        고도 [m]. 보이는 폭은 대략 1.155 * alt [m]
%
%   받는 일은 _tools/gz_shot_log.sh 가 한다. 그 사본을 윈도 임시 폴더로 옮겨
%   쓰는 이유 — 볼트 경로에 한글이 있어 WSL 로 그대로 넘기면 깨질 수 있다.
%
%   그림은 윈도 임시 폴더(<tempdir>\gzshot) 에 쌓인다. WSL 의 /tmp 는 윈도
%   쪽에서 바로 못 읽으므로, 처음부터 /mnt/c/... 로 쓰게 한다.

    if nargin < 1 || isempty(dur),       dur       = 120;             end
    if nargin < 2 || isempty(ivl),       ivl       = 0.4;             end
    if nargin < 3 || isempty(partition), partition = 'a3';            end
    if nargin < 4 || isempty(cen_enu),   cen_enu   = [-532 200];      end
    if nargin < 5 || isempty(alt),       alt       = 30;              end
    if nargin < 6 || isempty(distro),    distro    = 'Ubuntu-22.04';  end

    tools = fileparts(mfilename('fullpath'));
    sh    = fullfile(tempdir, 'gz_shot_log.sh');
    shots = fullfile(tempdir, 'gzshot');
    copyfile(fullfile(tools, 'gz_shot_log.sh'), sh);
    if ~isfolder(shots), mkdir(shots); end

    cmd = sprintf('bash %s %d %s %g %s %g %g %g', win2wsl(sh), round(dur), ...
                  win2wsl(shots), ivl, partition, cen_enu(1), cen_enu(2), alt);

    %  java 로 띄운다 — MATLAB 의 system() 은 윈도에서 끝날 때까지 기다린다
    pb  = java.lang.ProcessBuilder({'wsl.exe', '-d', distro, ...
                                    '-e', 'bash', '-lc', cmd});
    cap = struct('dir', shots, 'index', fullfile(shots, 'index.txt'), ...
                 'dur', dur, 'ivl', ivl, 'proc', pb.start());

    pause(3);                 % 카메라가 자리를 잡을 시간
    fprintf(['    가제보 화면 떠내기 시작 — %s\n' ...
             '      고정 탑다운 · 중심 ENU (%.1f, %.1f) · 고도 %.0f m ' ...
             '(보이는 폭 약 %.0f m)\n'], shots, cen_enu(1), cen_enu(2), ...
            alt, 1.155*alt);
end


function w = win2wsl(p)
%  C:\a\b  ->  /mnt/c/a/b
    p = strrep(p, '\', '/');
    w = ['/mnt/' lower(p(1)) p(3:end)];
end
