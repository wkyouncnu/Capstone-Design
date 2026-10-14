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
%   부호 목록은 언제나 막대로 시작한다 / the sign list always starts with a bar
%
%       교수 지시 2026-10-14 — "Simulink sum 블록은 항상 |+- 이런 부호 목록만
%       사용." 그래서 이 함수는 막대가 없는 목록을 받아도 앞에 막대를 붙인다.
%       '+-' 를 주어도 실제로는 '|+-' 가 들어간다.
%
%           '|+-'  입력1 (왼쪽)   입력2 (아래)   출력 (오른쪽)
%           '|++'  입력1 (왼쪽)   입력2 (아래)   출력 (오른쪽)
%
%       막대는 포트가 아니라 **포트 자리 하나를 비우는 띄우개**다. 원의 위
%       자리를 비우면 첫 입력이 왼쪽 가장자리에 남고 둘째 입력만 아래로
%       내려간다. 그림에서는 이렇게 읽힌다.
%
%           지령 ------->(+)-----> 제어기 ...
%                         ^
%                         | (-)
%                      되먹임
%
%       신호가 **왼쪽에서 들어와 오른쪽으로 나가는 한 줄**이 되고, 되먹임만
%       아래에서 올라온다. 되먹임 제어 그림의 표준 모양이며, 지령선·출력선이
%       모두 수평이라 블록을 포트 높이에 맞추어 놓으면 꺾임이 없는 직선이 된다.
%
%       2026-10-02 에는 막대 없는 '+-' (지령 위·되먹임 아래)를 골랐고 이 머리글도
%       그렇게 적혀 있었다. 2026-10-14 지시로 바뀌었다 — 위에서 내려오는 지령선은
%       신호 흐름을 끊고, 합산점마다 긴 세로줄이 생겨 선이 서로 겹치기 때문이다.
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
%   The centre is the argument rather than a corner because a summing junction
%   is placed to line up with the signal it interrupts. Aligning centres keeps
%   the wire straight; aligning corners does not.
%
%   옛 차수의 빌더 / older builders
%       부호만 '+-' 로 적어 둔 빌더도 그대로 돈다 (막대는 여기서 붙는다). 다만
%       포트가 위에서 왼쪽으로 옮겨 가므로, 그 차수를 **다시 빌드할 때** 합산점
%       주변 블록 높이를 한 번 맞추어 주어야 check_lines 가 0 으로 남는다.

if nargin < 4, error('add_sum:args', 'add_sum(sys, name, signs, centre)'); end

signs = strrep(signs, '|', '');            % 들어온 막대는 떼고
signs = ['|' signs];                       % 맨 앞에 하나만 다시 붙인다
R     = 10;                                % half of the MSS 20 x 20

blk = [sys '/' name];
add_block('simulink/Math Operations/Sum', blk, ...
          'IconShape', 'round', ...
          'Inputs',    signs, ...
          'Position',  [centre(1)-R, centre(2)-R, centre(1)+R, centre(2)+R]);
end
