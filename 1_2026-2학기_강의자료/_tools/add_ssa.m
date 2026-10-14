function [sumBlk, ssaBlk] = add_ssa(sys, sumName, ssaName, centre, gap)
%ADD_SSA  선수각 오차를 **블록 두 개**로 적는다 — 합산점 하나와 Fcn 하나.
%         Heading error drawn as two blocks: a summing junction and one Fcn.
%
%   [sumBlk, ssaBlk] = add_ssa(sys, sumName, ssaName, centre)
%   [sumBlk, ssaBlk] = add_ssa(sys, sumName, ssaName, centre, gap)
%
%     sys       부모 시스템, 예를 들어 [mdl '/InnerLoop']
%     sumName   합산점 블록 이름 (예: 'ErrPsi')
%     ssaName   Fcn 블록 이름 (예: 'Ssa')
%     centre    **합산점 원의 중심** [x y]
%     gap       합산점 중심에서 Fcn 왼쪽 모서리까지 [px]. 기본 60
%
%   무엇이 만들어지는가 / what gets built
%
%       psi_ref --->(+)---> [ atan2(sin(u), cos(u)) ] ---> e
%                    ^
%                    | (-)
%                  psi
%
%     합산점은 '|+-' 이므로 지령이 **왼쪽**, 되먹임이 **아래**로 들어간다 (add_sum).
%     Fcn 은 들어온 각 하나를 (-pi, pi] 로 접는다. 그것이 ssa 의 전부다.
%
%   왜 MATLAB Function 이 아니라 Fcn 한 개인가 / why not a MATLAB Function
%
%     전에는 이 자리에 MATLAB Function 블록이 있었고 그 안에
%
%         d = psi_ref - psi;
%         e = atan2(sin(d), cos(d));
%
%     두 줄이 들어 있었다. 돌아가기는 하지만 **도면에서 뺄셈이 사라진다** —
%     오차가 만들어지는 자리가 상자 안으로 숨어, 블록도만 보고는 무엇에서
%     무엇을 빼는지 알 수 없다. 되먹임 제어의 그림에서 가장 먼저 찾는 곳이
%     바로 그 합산점인데, 그것이 보이지 않는 것이다.
%
%     빼기를 합산점으로 꺼내면 남는 일은 "접기" 하나뿐이고, 그것은 식 한 줄이라
%     Fcn 블록이면 족하다. Fcn 은 아이콘에 **식이 그대로 보이고**, 안으로
%     들어가 볼 것이 없으며, 컴파일할 코드도 없어 모델이 가볍다.
%
%     교수 지시 2026-10-14 — "ssa 도 이렇게 간단하게." 4주차 `W04_3_heading`
%     의 `HeadingCtrl` 을 교수가 직접 그렇게 고쳐 놓은 것이 본보기다.
%
%   값이 달라지는가 / does the number change
%     달라지지 않는다. 같은 식 atan2(sin(psi_ref - psi), cos(psi_ref - psi))
%     을 같은 배정밀도로 셈한다. 바뀐 것은 그것을 **어디에 적는가** 뿐이다.

if nargin < 4, error('add_ssa:args', 'add_ssa(sys, sumName, ssaName, centre, gap)'); end
if nargin < 5 || isempty(gap), gap = 60; end

sumBlk = add_sum(sys, sumName, '+-', centre);

ssaBlk = [sys '/' ssaName];
x0 = centre(1) + gap;
y0 = centre(2);
add_block('simulink/User-Defined Functions/Fcn', ssaBlk, ...
          'Expr', 'atan2(sin(u), cos(u))', ...
          'Position', [x0, y0-20, x0+90, y0+20]);

add_line(sys, [sumName '/1'], [ssaName '/1'], 'autorouting','on');
end
