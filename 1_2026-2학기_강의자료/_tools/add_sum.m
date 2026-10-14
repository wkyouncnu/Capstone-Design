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
%       '+-' 는 두 입력을 원의 **위와 아래** 가장자리에 붙인다 — 첫 입력(지령)이
%       위, 둘째 입력(되먹임)이 아래다. 출력은 오른쪽이다. 2026-10-02 에 세
%       모양의 포트 좌표를 직접 재어 확인했다 (20 x 20 원 기준).
%
%           '+-'   입력1 (위)      입력2 (아래)     출력 (오른쪽)
%           '|+-'  입력1 (왼쪽)    입력2 (아래)     출력 (오른쪽)
%           '++|'  입력1 (위)      입력2 (왼쪽)     출력 (오른쪽)
%
%       **둘 다 왼쪽 가장자리에 붙이는 설정은 Simulink 에 없다.** 2026-10-02 에
%       이 머리글이 그렇게 적혀 있었던 것은 잘못이다 (2026-10-14 바로잡음).
%
%       With '+-' the two inputs attach to the top and the bottom edge, the
%       reference above and the feedback below. No sign string puts both on
%       the left edge; the bar is a spacer, and it moves one port, not two.
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
%   막대는 포트가 아니라 **포트 자리 띄우개**다. '|+-' 로 적으면 첫 입력이 원의
%   **왼쪽**에 남고 둘째 입력만 아래로 내려가, 지령과 되먹임이 서로 다른 쪽에서
%   들어온다. 그냥 '+-' 로 적으면 둘이 **위와 아래로 마주 보고** 들어오고
%   오차가 만들어지는 자리가 대칭으로 읽힌다.
%
%   2026-10-02 에 교수가 두 모양을 나란히 놓고 보고 **뒤쪽(막대 없는 것)**을
%   골랐다. 오차가 만들어지는 자리는 도면에서 가장 먼저 찾는 곳이고, 지령과
%   되먹임이 **마주 보고** 들어와야 "무엇에서 무엇을 빼는가" 가 한눈에 읽힌다.
%
%   The bar is a port-position spacer, not a port. With it the first input stays
%   on the left edge while the second drops to the bottom, so the reference and
%   the feedback arrive from two different sides. Without it the two face each
%   other across the circle, top and bottom.
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
