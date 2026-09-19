function h = draw_line(sys, sp, dp, pts)
%DRAW_LINE  포트로 **먼저 잇고**, 모양은 그 다음에 준다.
%
%   draw_line(m, srcPortHandle, dstPortHandle, [x1 y1; x2 y2; ...])
%
%   왜 이렇게 하는가 / why connect first, shape second
%       add_line 에 점만 주면 Simulink 가 **끝점의 좌표로** 포트를 찾는다. 몇 픽셀만
%       어긋나거나 다가가는 방향이 마음에 들지 않으면 선이 포트에 붙지 않고
%       **한쪽이 매달린 채** 남는다. 도면에서는 이어져 보이는데 신호는 끊겨 있다.
%
%       2026-09-17 에 W02_2 의 TurtlePlant 이 그렇게 되어, 모델이 "차원을 완전히
%       설정하지 않습니다" 로 컴파일에 실패했다. 배선 검사는 0 건이었다 —
%       매달린 선도 선이라 겹치지도, 블록을 뚫지도 않기 때문이다.
%
%       포트 핸들로 이으면 연결은 반드시 생긴다. 모양은 그 뒤에 얹는다.
%       제어 포트(enable·trigger)도 핸들이면 그냥 된다.
%
%   PTS 를 주지 않으면 Simulink 가 알아서 긋는다.

try
    h = add_line(sys, sp, dp);
catch
    %  도착 포트에 이미 선이 있으면 그것을 끊고 다시 잇는다. 그냥 포기하면
    %  앞서 끊어 둔 가지가 영영 돌아오지 않는다.
    cut_line(sys, dp);
    h = add_line(sys, sp, dp);
end
if nargin > 3 && ~isempty(pts)
    pts = snap_ends(pts, sp, dp);
    try, set_param(h, 'Points', pts); catch, end
end
end

% -------------------------------------------------------------------------
function p = snap_ends(p, sp, dp)
%SNAP_ENDS  양 끝점을 **실제 포트 위치**로 바꾸고, 이웃 점을 같이 옮겨 직각을 지킨다.
%
%   포트는 블록 테두리에서 몇 px 바깥에 있다. 테두리 좌표로 계산한 끝점을 주면
%   Simulink 가 끝점만 포트로 당기고 이웃 점은 그대로 두어, 첫 토막이 3~7 px
%   기운 사선이 된다 (2026-09-19 전 모델 검사에서 feed_from 계열 다수).
q = p;
try, s = get_param(sp, 'Position'); catch, s = []; end
try, d = get_param(dp(1), 'Position'); catch, d = []; end
n = size(p,1);
if ~isempty(s)
    p(1,:) = s;
    if n > 2
        if abs(q(1,1)-q(2,1)) < 1e-6, p(2,1) = s(1); end   % 세로 토막 -> x 를 따라감
        if abs(q(1,2)-q(2,2)) < 1e-6, p(2,2) = s(2); end   % 가로 토막 -> y 를 따라감
    end
end
if ~isempty(d)
    p(n,:) = d;
    if n > 2
        if abs(q(n,1)-q(n-1,1)) < 1e-6, p(n-1,1) = d(1); end
        if abs(q(n,2)-q(n-1,2)) < 1e-6, p(n-1,2) = d(2); end
    end
end
end
