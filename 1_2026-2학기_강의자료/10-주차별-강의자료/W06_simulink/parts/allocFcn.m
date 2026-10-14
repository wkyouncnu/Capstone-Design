function src = allocFcn()
% allocFcn — 추력 배분 MATLAB Function 의 본문 (글자만 내놓는다, 모델은 손대지 않는다)
%
%   같은 배분식을 쓰는 안쪽 고리가 둘이다 — addInnerLoop (선체고정 전략) 과
%   addInnerLoopNED (NED 전략). 두 군데에 같은 글을 적어 두면 한쪽만 고쳐져
%   어긋난다. 글을 한 곳에 두고 둘이 불러 쓴다.
%
%   힘·모멘트가 어느 좌표계에서 왔는지는 이 함수가 알 바가 아니다. 들어오는
%   X·Y·N 은 **선체고정** 값이어야 한다 — NED 전략은 부르기 전에 돌려 놓는다.
    src = strjoin({
      'function [FL, FR, FB] = Alloc(X, Y, N, p)'
      '%#codegen'
      '%  추력 배분 — 요구 힘·모멘트를 세 추진기로 나눈다.'
      '%'
      '%    X = FL + FR                      전후력 [N]'
      '%    Y = FB                           횡력 [N]  — 선수추진기만 낸다'
      '%    N = (FL - FR)*b + l3*FB          요 모멘트 [N m]'
      '%'
      '%  p = [b; l3; Fmax; Fbmax]'
      '%    b     half_beam   좌·우 추진기까지의 반폭 [m]'
      '%    l3    l_bow       무게중심에서 선수추진기까지 [m]'
      '%    Fmax  선미 추진기 추력 한계 [N],  Fbmax 선수추진기 추력 한계 [N]'
      '%'
      '%  선수추진기가 횡력을 내면 요 모멘트 l3*FB 가 딸려 온다. 그것을 좌·우'
      '%  추진기가 되받아 빼야 선수각이 돌아가지 않는다 — 아래 N - l3*FB 가 그것이다.'
      'b = p(1);  l3 = p(2);  Fmax = p(3);  Fbmax = p(4);'
      'FB = Y;'
      'if FB >  Fbmax, FB =  Fbmax; end'
      'if FB < -Fbmax, FB = -Fbmax; end'
      '%  포화된 뒤의 FB 로 모멘트를 센다 — 실제로 딸려 온 만큼만 되받는다'
      'M  = N - l3*FB;'
      'FL = X/2 + M/(2*b);'
      'FR = X/2 - M/(2*b);'
      'if FL >  Fmax, FL =  Fmax; end'
      'if FL < -Fmax, FL = -Fmax; end'
      'if FR >  Fmax, FR =  Fmax; end'
      'if FR < -Fmax, FR = -Fmax; end'
      }, newline);
end
