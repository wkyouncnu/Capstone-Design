function align_to(sys, blk, kind, target, k)
%ALIGN_TO  블록을 위아래로만 옮겨, 그 블록의 포트 하나를 목표 높이에 맞춘다.
%
%   align_to(s, 'BlankL', 'Outport', port_xy(s, 'AsgL', 'Inport', 1))
%   align_to(s, 'OdomSub', 'Outport', port_xy(s, 'Sel', 'Inport', 1), 2)
%
%   왜 필요한가 / why this exists
%       두 포트를 직선으로 이으려면 높이가 **정확히** 같아야 한다. 블록 가운데를
%       맞추는 것으로는 부족하다 — 포트가 둘 이상인 블록은 포트가 가운데에 있지
%       않고, Simulink 가 포트를 테두리에서 들여놓는 여백도 블록 종류마다 다르다.
%       1~20 px 어긋나면 선이 완만한 사선이 된다 (check_lines 의 (5)).
%
%       그래서 목표 높이와 **읽은** 포트 높이의 차이만큼 블록을 옮긴다.
%
%   SYS     부모 시스템
%   BLK     옮길 블록 이름
%   KIND    'Inport' 또는 'Outport'
%   TARGET  [x y] 또는 y. y 만 쓴다
%   K       포트 번호. 생략하면 1

if nargin < 5 || isempty(k), k = 1; end
y = target(end);
b = [sys '/' blk];
for it = 1:3                          % 몇 px 격자에 붙는 블록이 있어 한두 번 더 본다
    p  = port_xy(sys, blk, kind, k);
    dy = round(y - p(2));
    if dy == 0, return, end
    set_param(b, 'Position', get_param(b, 'Position') + [0 dy 0 dy]);
end
end
