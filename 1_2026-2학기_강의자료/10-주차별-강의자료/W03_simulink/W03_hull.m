function [X, Y, hx, hy] = W03_hull(x, y, th, L)
% W03_HULL  선박 모양 다각형 — 선미는 네모, 선수는 뾰족하다.
%
%   [X, Y]         = W03_hull(x, y, th)      선체 윤곽 (patch 에 그대로 넣는다)
%   [X, Y, hx, hy] = W03_hull(x, y, th, L)   선수 방향선까지
%
%   입력
%     x, y : 선체 중심 (turtlesim 좌표)
%     th   : 선수각 [rad]  (+x 축 기준 반시계 +)
%     L    : 반길이. 생략하면 3.0  (WAM-V 전장 약 4.9 m)
%
%   모양은 W07_animate 의 WAM-V 선체와 같다
%
%        by
%        ^     ___________
%        |    |           \        선수(뾰족)
%        +----|-----+------>  bx
%             |___________/
%          선미(네모)

if nargin < 4 || isempty(L), L = 3.0; end
B = 0.45 * L;                         % 반폭

bx = L * [ -1   -1    0.35   1    0.35  -1 ];   % 선미 -> 선수 -> 선미 (닫힌 도형)
by = B * [  1   -1   -1      0    1      1 ];

c = cos(th);  s = sin(th);
X = x + bx*c - by*s;
Y = y + bx*s + by*c;

% 선수 방향선 — 선체 길이의 2배만큼 앞으로
hx = [x, x + 2.2*L*c];
hy = [y, y + 2.2*L*s];
end
