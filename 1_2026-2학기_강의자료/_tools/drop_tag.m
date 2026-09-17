function blk = drop_tag(sys, src, sk, name, dy)
%DROP_TAG  신호를 통로 하나로 내려(또는 올려) Goto 태그에 건다. 꺾임 1회, 관통 0.
%
%   drop_tag(m, 'MotorLag', 1, 'X', 110)     % 출력 포트에서 110 px 아래
%   drop_tag(m, 'PID_lib',  1, 'u_lib', -90) % 음수면 위로
%
%   왜 이 함수가 필요한가 / why this exists
%       Goto 의 **입력 포트는 왼쪽 테두리**에 있다. 통로 x 를 블록의 x 범위 안에
%       두면 선이 블록 위로 내려온 뒤 왼쪽으로 빠져나가며, 도면에서는 선이 태그를
%       관통한 것으로 보인다. 2026-09-16 에 사용자가 지적한 바로 그 그림이다.
%
%       태그를 통로의 **오른쪽**에 놓으면 선은 내려온 뒤 오른쪽으로 들어가고,
%       블록을 넘지 않으며 꺾임도 한 번뿐이다.
%
%           신호 ────┐                     신호 ────┐
%                    │  (나쁨)                      │  (좋음)
%               ┌────┼────┐                        └──▶┌────────┐
%               │  Go_X   │                            │  Go_X  │
%               └─────────┘                            └────────┘
%
%   SYS   부모 시스템 (모델 또는 서브시스템 경로)
%   SRC   출발 블록 이름
%   SK    출발 블록의 출력 포트 번호
%   NAME  태그 이름. 블록 이름은 'Go_<NAME>' 이 된다
%   DY    출발 포트로부터의 세로 거리 [px]. 음수면 위로

W = 60; H = 22; GAP = 30;

a  = port_xy(sys, src, 'Outport', sk);
y  = round(a(2) + dy);
x1 = round(a(1) + GAP);

blk = [sys '/Go_' name];
add_block('simulink/Signal Routing/Goto', blk, ...
          'Position', [x1, y-H/2, x1+W, y+H/2], ...
          'GotoTag', name, 'TagVisibility', 'global');

%  세로로 내려간 뒤 오른쪽으로 들어간다. 꺾임은 한 번뿐이다.
if abs(dy) < 0.5
    pts = [a; x1 y];                   % 같은 높이면 직선 한 토막
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
