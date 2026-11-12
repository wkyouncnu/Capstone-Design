function src = wrenchFcn()
% wrenchFcn — 실제로 난 힘·모멘트를 되계산하는 MATLAB Function 의 본문
%
%   배분에서 각도를 잘랐거나 추력을 줄였으면, 실제로 난 힘은 요구와 다르다.
%   운동모델에는 **실제로 난 힘**을 넣어야 한다. 요구를 그대로 넣으면 한계가
%   없는 배를 돌리는 셈이 되어, 각도 한계의 효과가 그림에 나타나지 않는다.
    src = strjoin({
      'function [X_a, Y_a, N_a] = Wrench(TL, dL, TR, dR, p)'
      '%#codegen'
      '%  추진기 두 대가 **실제로** 낸 힘·모멘트 [N, N, N m]'
      '%'
      '%    추진기 한 대의 힘   Fx = T*cos(d),  Fy = T*sin(d)'
      '%    모멘트  N = x*Fy - y*Fx  를 좌·우에 더한다'
      '%            좌현 추진기 (x, y) = (-L, -b),  우현 (x, y) = (-L, +b)'
      '%            => N = b*(FxL - FxR) - L*(FyL + FyR)'
      '%'
      '%  요구와 이 값의 차이가 곧 **한계 때문에 못 낸 힘**이다 (로그로 본다).'
      'b = p(1);  L = p(2);'
      'FxL = TL*cos(dL);   FyL = TL*sin(dL);'
      'FxR = TR*cos(dR);   FyR = TR*sin(dR);'
      'X_a = FxL + FxR;'
      'Y_a = FyL + FyR;'
      'N_a = b*(FxL - FxR) - L*(FyL + FyR);'
      }, newline);
end
