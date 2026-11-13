function cap = vrx_js_capture(dur, dec, domain, distro)
%VRX_JS_CAPTURE  가제보 조인트 각도 받기를 **시작만** 하고 바로 돌아온다
%
%   cap = vrx_js_capture(40);     % 40 초 동안 받는다
%   out = sim(mdl);               % 그 사이 Simulink 가 돈다
%   [t, dL, dR] = vrx_js_read(cap);
%
%   왜 바깥에서 받는가
%     sim() 이 도는 동안 MATLAB 은 묶여 있어 ros2subscriber 가 돌지 못한다.
%     그래서 WSL 쪽 ros2 topic echo 로 받아 파일에 쌓아 두고, 끝난 뒤 읽는다.
%
%   받는 일은 _tools/vrx_js_log.sh 가 한다. 그 사본을 윈도 임시 폴더로 옮겨
%   쓰는 이유 — 볼트 경로에 한글이 있어 WSL 로 그대로 넘기면 깨질 수 있다.

    if nargin < 2 || isempty(dec),    dec    = 20;             end
    if nargin < 3 || isempty(domain), domain = 7;              end
    if nargin < 4 || isempty(distro), distro = 'Ubuntu-22.04'; end

    tools = fileparts(mfilename('fullpath'));
    sh    = fullfile(tempdir, 'vrx_js_log.sh');
    txt   = fullfile(tempdir, 'vrx_js_out.csv');
    copyfile(fullfile(tools, 'vrx_js_log.sh'), sh);
    if exist(txt, 'file'), delete(txt); end

    shw = win2wsl(sh);   txtw = win2wsl(txt);
    cmd = sprintf('bash %s %d %s %d %d', shw, round(dur), txtw, dec, domain);

    %  java 로 띄운다 — MATLAB 의 system() 은 윈도에서 **끝날 때까지 기다린다**
    pb   = java.lang.ProcessBuilder({'wsl.exe', '-d', distro, ...
                                     '-e', 'bash', '-lc', cmd});
    cap  = struct('file', txt, 'dur', dur, 'proc', pb.start());
    pause(1.5);                             % 구독이 붙을 시간
end


function w = win2wsl(p)
%  C:\a\b  ->  /mnt/c/a/b
    p = strrep(p, '\', '/');
    w = ['/mnt/' lower(p(1)) p(3:end)];
end
