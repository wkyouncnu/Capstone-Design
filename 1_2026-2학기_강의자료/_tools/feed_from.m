function blk = feed_from(sys, name, dst, dk, dy, sfx)
%FEED_FROM  From 태그를 도착 포트 아래(또는 위)에 놓고 잇는다. 꺾임 1회, 관통 0.
%
%   feed_from(m, 'u', 'SumE', 2, 90)          % SumE 의 2번 입력을 90 px 아래에서
%   feed_from(m, 'noise', 'SumY_lib', 2, 90, '1')
%
%   왜 이 함수가 필요한가 / why this exists
%       From 의 **출력 포트는 오른쪽 테두리**에 있다. 도착 포트의 x 를 통로로 삼으면
%       선은 가로로 간 뒤 세로로 들어가며 꺾임이 한 번뿐이다. 그러려면 From 이
%       도착 포트보다 **왼쪽**에 있어야 한다. 이 함수가 그 자리를 계산한다.
%
%       둥근 Sum 의 2번 입력은 원의 **아래쪽**에 있다. 되먹임이 아래에서 올라오는
%       MSS 데모의 모양이 이렇게 나온다.
%
%   SYS   부모 시스템
%   NAME  태그 이름. 블록 이름은 'Fr_<NAME>_<SFX>' 가 된다
%   DST   도착 블록 이름
%   DK    도착 블록의 입력 포트 번호
%   DY    도착 포트로부터의 세로 거리 [px]. 보통 양수(아래)
%   SFX   같은 태그를 여러 번 쓸 때의 꼬리표. 생략하면 '1'

if nargin < 6 || isempty(sfx), sfx = '1'; end

W = 60; H = 22; GAP = 40;

b  = port_xy(sys, dst, 'Inport', dk);
x2 = round(b(1) - GAP);              % From 의 오른쪽 테두리(출력 포트)
r  = get_param([sys '/' dst], 'Position');
sidePort = b(1) <= r(1) || b(1) >= r(3);

%  그 자리에 이미 다른 블록·선이 있으면 같은 방향으로 10 px 씩 더 민다 (drop_tag 와 같다)
sg = sign(dy);  ok = false;
for t = 0:40
    y = round(b(2) + dy + sg*10*t);
    if sidePort, pts = [x2 y; x2 b(2); b]; else, pts = [x2 y; b(1) y; b]; end
    if sg == 0 || spot_free(sys, [x2-W, y-H/2, x2, y+H/2], ['Fr_' name '_' sfx], ...
                            pts, {dst}), ok = true; break, end
end
if ~ok, y = round(b(2) + dy); end              % 빈자리가 없으면 원래 자리 (검사가 보고한다)

blk = [sys '/Fr_' name '_' sfx];
add_block('simulink/Signal Routing/From', blk, ...
          'Position', [x2-W, y-H/2, x2, y+H/2], 'GotoTag', name);

%  포트가 블록의 **옆면**에 있으면 선은 가로로 들어가야 한다. 세로로 먼저 내려가고
%  마지막에 가로로 붙인다. 포트가 **아래쪽**에 있으면 반대다 — 가로로 간 뒤 세로로
%  올라간다. 이것을 구분하지 않으면 마지막 토막이 사선이 되어 포트에 비스듬히 붙는다.

if sidePort
    pts = [x2 y; x2 b(2); b];
else
    pts = [x2 y; b(1) y; b];
end

%  포트로 먼저 잇는다. 점만 주면 끝점이 포트에 붙지 않고 매달릴 수 있다 —
%  도면은 이어져 보이는데 신호는 끊긴다 (drop_tag 의 같은 주석 참조).
pf = get_param(blk, 'PortHandles');
pd = get_param([sys '/' dst], 'PortHandles');
draw_line(sys, pf.Outport(1), pd.Inport(dk), pts);
end
