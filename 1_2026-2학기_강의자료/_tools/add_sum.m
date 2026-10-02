function blk = add_sum(sys, name, signs, centre)
%ADD_SUM  MSS 가 그리는 모양 그대로의 합산점 — 작은 원 하나.
%         A summing junction drawn the way MSS draws one: a small round circle.
%
%   blk = add_sum(sys, name, signs, centre)
%
%     sys      부모 시스템, 예를 들어 [mdl '/Controller']
%              the parent system, e.g. [mdl '/Controller']
%     signs    포트 순서대로의 부호. '+-', '++', '-+' 등
%              the signs, in port order
%     centre   원의 **중심** [x y]. 모서리가 아니다
%              the centre of the circle, not a corner
%
%   포트가 어디에 붙는지 / where the ports end up
%       **두 입력이 모두 왼쪽 가장자리에 붙는다** — 위가 첫 입력(지령), 아래가
%       둘째 입력(되먹임)이다. 오차가 만들어지는 자리를 한눈에 읽으려면 두 선이
%       같은 쪽에서 들어와야 한다는 것이 교수 결정이다 (2026-10-02).
%
%       Both inputs attach to the left edge, the first above the second. The
%       error junction is the block a reader looks for first, and it reads
%       fastest when the reference and the feedback arrive on the same side.
%
%   WHY THIS EXISTS
%
%   Simulink's default Sum block is a rectangle 25 x 40 with the signs printed
%   inside it. On a diagram that has to be read at page width it is a slab: it
%   is larger than the gain blocks around it, it breaks the line of the signal
%   chain, and the error junction - the one block a reader looks for first -
%   ends up the most visually heavy thing in the loop.
%
%   MSS uses a circle 20 x 20 throughout. Checked against
%   Tools/MSS/SIMULINK/mssSimulinkDemos/demoOtterUSVHeadingControl.slx, whose
%   eight Sum blocks are all IconShape 'round' at 20 x 20. This function keeps
%   that shape and size.
%
%   왜 '|' 를 넣지 않는가 / why no bar in the sign string
%
%   막대는 포트가 아니라 **포트 자리 띄우개**다. '|+-' 로 적으면 둘째 입력이
%   원의 **아래쪽** 가장자리로 내려가고, 되먹임선이 밑에서 올라와 꺾인다.
%   그냥 '+-' 로 적으면 두 입력이 **왼쪽 가장자리에 위아래로** 붙고, 지령과
%   되먹임이 같은 쪽에서 나란히 들어온다.
%
%   2026-10-02 에 교수가 두 모양을 나란히 놓고 보고 **뒤쪽(막대 없는 것)**을
%   골랐다. 오차가 만들어지는 자리는 도면에서 가장 먼저 찾는 곳이고, 두 선이
%   같은 쪽에서 들어와야 "무엇에서 무엇을 빼는가" 가 한눈에 읽힌다.
%
%   The bar is a port-position spacer, not a port. With it the second input
%   drops to the bottom edge and the feedback line has to come up from below.
%   Without it both inputs sit on the left edge, one above the other, and the
%   reference and the feedback arrive side by side.
%
%   The centre is the argument rather than a corner because a summing junction
%   is placed to line up with the signal it interrupts. Aligning centres keeps
%   the wire straight; aligning corners does not.

if nargin < 4, error('add_sum:args', 'add_sum(sys, name, signs, centre)'); end

signs = strrep(signs, '|', '');            % 막대는 받아도 버린다 (위 설명)
R     = 10;                                % half of the MSS 20 x 20

blk = [sys '/' name];
add_block('simulink/Math Operations/Sum', blk, ...
          'IconShape', 'round', ...
          'Inputs',    signs, ...
          'Position',  [centre(1)-R, centre(2)-R, centre(1)+R, centre(2)+R]);
end
