function blk = drop_tag(sys, src, sk, name, dy)
%DROP_TAG  Goto 태그를 **출발 포트 바로 옆**에 놓고 잇는다. 꺾임 0회, 관통 0.
%
%   drop_tag(m, 'MotorLag', 1, 'X')          % 포트 옆 — 선은 수평 직선
%   drop_tag(m, 'MotorLag', 1, 'X', 110)     % 옆자리가 차 있으면 110 px 아래로
%   drop_tag(m, 'PID_lib',  1, 'u_lib', -90) % 음수면 위로 비킨다
%
%   태그는 신호 바로 옆에 둔다 / a tag belongs beside its signal
%       2026-10-01 교수 지시 — "Goto 부분은 실제 신호에 최대한 가까이 모아 주고,
%       선들도 꺾이는 부분을 최소화해서 해 줄 것."
%
%       출발 포트와 **같은 높이**, 한 칸(30 px) 오른쪽에 놓으면 잇는 선이 수평
%       한 토막이 되어 꺾임이 **0회**다. 멀리 두면 선이 길어지고 꺾인다.
%
%           좋음                              나쁨
%           신호 ──▶┌────────┐                신호 ────┐
%                   │  Go_X  │                         │
%                   └────────┘                    ┌────▼───┐
%                                                 │  Go_X  │   (내려가느라 꺾임 1회,
%                                                 └────────┘    거리도 멀다)
%
%       DY 는 **비켜 둘 방향**일 뿐이다. 포트 옆이 이미 차 있을 때만 쓴다.
%       그 자리가 다음 단계로 가는 본선 위이면 spot_free 가 막아 준다.
%
%   왜 태그를 통로의 오른쪽에 두는가 / why the tag sits right of the lane
%       Goto 의 **입력 포트는 왼쪽 테두리**에 있다. 통로 x 를 블록의 x 범위 안에
%       두면 선이 블록 위로 내려온 뒤 왼쪽으로 빠져나가며, 도면에서는 선이 태그를
%       관통한 것으로 보인다. 2026-09-16 에 사용자가 지적한 바로 그 그림이다.
%
%   SYS   부모 시스템 (모델 또는 서브시스템 경로)
%   SRC   출발 블록 이름
%   SK    출발 블록의 출력 포트 번호
%   NAME  태그 이름. 블록 이름은 'Go_<NAME>' 이 된다
%   DY    옆자리가 찼을 때 비켜 갈 세로 거리 [px]. 생략하면 아래로 90. 음수면 위로

if nargin < 5 || isempty(dy), dy = 90; end

W = 60; H = 22; GAP = 30;

a  = port_xy(sys, src, 'Outport', sk);

%  1) 먼저 **포트와 같은 높이**를 본다. 한 칸씩 오른쪽으로 물려 가며 빈자리를 찾는다.
%     여기서 잡히면 선은 수평 직선 한 토막이고 꺾임이 0 회다.
x1 = round(a(1) + GAP);  y = round(a(2));  ok = false;
for g = GAP + [0 40 90 150 220]
    x1 = round(a(1) + g);
    if spot_free(sys, [x1, y-H/2, x1+W, y+H/2], ['Go_' name], ...
                 [a; x1 y], {src}), ok = true; break, end
end

%  2) 옆이 전부 차 있으면 DY 쪽으로 10 px 씩 비킨다. 그때는 꺾임이 한 번 생긴다.
%     포개진 태그는 선 검사를 모두 통과하지만 도면에서 읽을 수 없다 (spot_free.m).
if ~ok
    sg = sign(dy);  if sg == 0, sg = 1; end
    x1 = round(a(1) + GAP);
    for t = 0:40
        y = round(a(2) + dy + sg*10*t);
        if spot_free(sys, [x1, y-H/2, x1+W, y+H/2], ['Go_' name], ...
                     [a; a(1) y; x1 y], {src}), ok = true; break, end
    end
    if ~ok                                     % 빈자리가 없다 (검사가 보고한다)
        x1 = round(a(1) + GAP);  y = round(a(2) + dy);
    end
end

blk = [sys '/Go_' name];
add_block('simulink/Signal Routing/Goto', blk, ...
          'Position', [x1, y-H/2, x1+W, y+H/2], ...
          'GotoTag', name, 'TagVisibility', 'global');

%  같은 높이면 직선 한 토막. 비켜 놓았으면 세로로 간 뒤 오른쪽으로 들어간다.
if abs(y - a(2)) < 0.5
    pts = [a; x1 y];
else
    pts = [a; a(1) y; x1 y];
end

%  포트로 먼저 잇는다. 점만 주면 끝점이 태그의 입력 포트에 붙지 않고 매달릴 수
%  있다 — 특히 그 출력에 이미 다른 선이 있어 **가지**가 되는 경우가 그렇다
%  (2026-09-17 W02_2 의 IntegDly. 도면은 멀쩡한데 모델이 컴파일되지 않았다).
ps = get_param([sys '/' src], 'PortHandles');
pg = get_param(blk, 'PortHandles');
draw_line(sys, ps.Outport(sk), pg.Inport(1), pts);
end
