function was_paused = vrx_play(partition, world, distro)
%VRX_PLAY  가제보 세계가 멈춰 있으면 다시 돌린다 (MATLAB 에서 WSL 로 한 번)
%
%   was_paused = vrx_play('a3', 'sydney_regatta')
%
%   왜 필요한가 — **멈춘 세계는 오류를 내지 않는다**
%     GUI 의 일시정지 단추를 눌렀거나, 창이 멈춘 채로 떠 있으면 토픽은 전부
%     살아 있다. 명령도 받는다. 다만 물리가 한 발짝도 나아가지 않으므로
%     조인트 각도는 **영원히 0 이다**. 실측값이 전부 0 으로 나오면 부호나
%     토픽을 의심하기 전에 이것을 먼저 본다 (2026-11-13 에 실제로 겪은 일).
%
%   무엇을 하는가
%     1. /world/<world>/stats 의 paused 를 읽는다
%     2. 멈춰 있으면 /world/<world>/control 에 pause: false 를 보낸다
%
%   칸(partition) 을 왜 받는가
%     가제보 내부 통신은 ROS_DOMAIN_ID 가 아니라 GZ_PARTITION 으로 갈린다.
%     띄울 때 준 값과 **같은 값**을 주어야 그 세계가 보인다.

    if nargin < 1 || isempty(partition), partition = 'a3';              end
    if nargin < 2 || isempty(world),     world     = 'sydney_regatta';  end
    if nargin < 3 || isempty(distro),    distro    = 'Ubuntu-22.04';    end

    %  stats 를 한 번 읽고, 멈춰 있으면 control 에 pause: false 를 보낸다
    %    **paused 가 false 일 때는 그 줄이 아예 없다** — 프로토버프가 기본값을
    %    생략하기 때문이다. 그래서 'paused: true' 가 있는지만 본다
    sh = ['export GZ_PARTITION=' partition '; ' ...
          'timeout 8 gz topic -e -t /world/' world '/stats 2>/dev/null | head -12; ' ...
          'gz service -s /world/' world '/control' ...
          ' --reqtype gz.msgs.WorldControl --reptype gz.msgs.Boolean' ...
          ' --timeout 3000 --req ''pause: false'' > /dev/null 2>&1'];

    cmd = ['wsl.exe -d ' distro ' -e bash -lc "' sh '"'];
    [st, txt] = system(cmd);

    if st ~= 0
        warning('vrx_play: WSL 명령이 실패했습니다 (코드 %d). 가제보가 떠 있는지 보십시오.', st);
        was_paused = [];  return
    end

    if ~contains(txt, 'sim_time')
        was_paused = [];
        fprintf(2, '    가제보 stats 를 읽지 못했습니다 — GZ_PARTITION=%s · 세계 %s 가 맞습니까\n', ...
                partition, world);
        return
    end

    was_paused = contains(txt, 'paused: true');
    if was_paused
        fprintf('    가제보가 멈춰 있었습니다 — 다시 돌립니다\n');
        pause(1.5);                       % 물리가 몇 발짝 나아갈 시간을 준다
    else
        fprintf('    가제보가 돌고 있습니다\n');
    end
end
