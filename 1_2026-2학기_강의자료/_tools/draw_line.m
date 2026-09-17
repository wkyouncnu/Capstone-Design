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
    try, set_param(h, 'Points', pts); catch, end
end
end
