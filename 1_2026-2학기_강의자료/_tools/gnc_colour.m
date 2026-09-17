function c = gnc_colour(stage)
%GNC_COLOUR  GNC 신호 사슬의 각 단계에 정해진 색. CLAUDE.md §11 의 표가 원본이다.
%
%   c = gnc_colour('control')
%
%   색은 의미를 나르며 장식이 아니다. 모델 하나를 본 학생은 다른 모든 모델에서
%   초록 블록이 무엇인지 안다. 그래서 색을 임의로 고르지 않고 여기서만 정한다.
%
%     command       흰색      설정값 — 무엇을 요구하는가
%     reference     연보라    실현 가능한가, 얼마나 빨리
%     guidance      파랑      유도 — 어디로 갈 것인가
%     mission       보라      미션 판단 (Stateflow, 모드 전환)
%     control       주황      제어 — 그러려면 어떤 힘이 필요한가
%     allocation    노랑      추력 배분 — 어느 추진기가 그 힘을 내는가
%     thruster      노랑      추진기
%     plant         초록      운동모델 — 배가 어떻게 반응하는가
%     env           분홍      외란 (바람 · 파랑 · 센서 잡음)
%     ros           연보라    ROS 통신 · 신호처리
%     measurement   회색      로깅 · 스코프 · 실시간 그림
%
%   tidy_layout.m 의 colorFor 와 같은 값이다. 둘이 어긋나면 CLAUDE.md 가 이긴다.

switch lower(strtrim(stage))
    case 'command',                 c = 'white';
    case {'reference','ros'},       c = '[0.87, 0.87, 0.96]';
    case 'guidance',                c = '[0.80, 0.89, 0.98]';
    case 'mission',                 c = '[0.90, 0.83, 0.96]';
    case {'control','controller'},  c = '[1.00, 0.88, 0.72]';
    case {'allocation','thruster'}, c = '[1.00, 0.95, 0.70]';
    case 'plant',                   c = '[0.81, 0.93, 0.81]';
    case 'env',                     c = '[0.98, 0.85, 0.85]';
    case {'measurement','logging'}, c = '[0.93, 0.93, 0.93]';
    otherwise
        error('gnc_colour:stage', '모르는 단계 ''%s''.', stage);
end
end
