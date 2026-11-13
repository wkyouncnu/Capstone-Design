function wireNavGotos(m, src, x, y, tags)
%  항법 출력을 전부 태그로 낸다
%
%    wireNavGotos(m, 'MotionModel', 2410, 280)        오프라인 — 열두 개
%    wireNavGotos(m, 'PoseSubscriber', 3400, 280, t)  VRX — 아홉 개
%
%  태그 목록을 주지 않으면 운동모델의 열두 출력을 쓴다 (뒤의 셋이 실제 렌치다).
%  VRX 판은 운동모델 자리에 가제보가 들어서므로 ground truth 로 아홉 개만 나오고,
%  실제 렌치 셋은 Wrench 상자(addWrenchBox) 가 따로 낸다.
%
%  **순서가 곧 출발 블록의 출력 포트 순서**다. 바꾸면 태그 이름과 신호가 어긋나는데
%  오류는 뜨지 않는다 — 그림이 엉뚱한 값을 그릴 뿐이다.
    if nargin < 5 || isempty(tags)
        tags = {'x_n','y_n','psi','u','v','r','beta','chi','U','X_a','Y_a','N_a'};
    end
    for k = 1:numel(tags)
        sl_goto(m, tags{k}, x, y+(k-1)*45);
        add_line(m, sprintf('%s/%d',src,k), ['Go_' tags{k} '/1'], 'autorouting','on');
    end
end
