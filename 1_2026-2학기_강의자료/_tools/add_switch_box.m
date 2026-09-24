function s = add_switch_box(mdl, name, pos, ports, swVar, on, colour, txt)
%ADD_SWITCH_BOX  "켜고 끄는 스위치" 하나를 담은 작은 서브시스템.
%
%   s = add_switch_box(m, 'RefShape', pos, {'u_raw','u_ref'}, 'ref_smooth', ...
%                      struct('name','Lag', 'lib','simulink/Continuous/Transfer Fcn', ...
%                             'params',{{'Numerator','1','Denominator','[T_ref 1]'}}, ...
%                             'fed',true, 'w',60, 'h',36), ...
%                      gnc_colour('guidance'), '설명 여러 줄');
%
%   무엇을 하는가
%       swVar 가 1 이면 **위 갈래**(ON 블록)의 값을, 0 이면 **들어온 신호 그대로**를
%       내보낸다. 강의에서 "스위치 하나로 두 번 Run" 을 하는 자리에 쓴다 —
%       개루프/폐루프, 목표값 계단/평활, ssa 켬/끔.
%
%   왜 상자로 만드는가
%       스위치 하나를 최상위에 두면 상수 두 개가 따라 붙어 사슬이 세 칸 길어지고,
%       Switch 의 제어 포트(왼쪽 가운데)로 들어가는 선이 다른 블록을 지나간다.
%       상자 안에서는 자리를 넉넉히 쓸 수 있어 꺾임 1회로 끝난다.
%
%   인자
%       pos     [x1 y1 x2 y2] 최상위에서 이 상자가 차지할 사각형
%       ports   {입력포트이름, 출력포트이름}
%       swVar   Constant 에 그대로 들어갈 변수 이름. W04_setup 이 값을 준다
%       on      struct — ON 갈래 블록
%                 .name   블록 이름
%                 .lib    라이브러리 경로
%                 .params set_param 인자 쌍 (cell)
%                 .fed    true 면 입력 신호를 그 블록에 먹인다 (필터 따위).
%                         false 면 입력과 무관한 소스다 (개루프 상수 따위)
%                 .w .h   블록 크기 (생략하면 60x36)
%       colour  배경색 문자열. gnc_colour 가 준다
%       txt     상자 안에 붙일 설명 (생략 가능)
%
%   스위치 판정은 'u2 >= Threshold', Threshold = 0.5 이다. 그래서 swVar 는
%   0 또는 1 만 쓰면 된다.

if nargin < 7 || isempty(colour), colour = gnc_colour('control'); end
if nargin < 8, txt = ''; end
if ~isfield(on,'w') || isempty(on.w), on.w = 60; end
if ~isfield(on,'h') || isempty(on.h), on.h = 36; end

R = 200;                      % 상자 안의 주선 높이
s = add_subsys(mdl, name, pos, ports(1), ports(2), colour);

set_param([s '/' ports{1}], 'Position', [ 45 R-7  75 R+7]);
set_param([s '/' ports{2}], 'Position', [620 R-7 650 R+7]);

place(s, on.lib, on.name, 250, R-100, on.w, on.h, on.params);
place(s, 'simulink/Sources/Constant', 'SwVal', 370, R+140, 55, 30, {'Value', swVar});
place(s, 'simulink/Signal Routing/Switch', 'Sel', 480, R, 30, 30, ...
      {'Criteria','u2 >= Threshold', 'Threshold','0.5'});

xin = port_xy(s, ports{1}, 'Outport', 1);
if on.fed
    lane_line(s, ports{1}, 1, on.name, 1, xin(1));     % 올라가서 들어간다
end
xon = port_xy(s, on.name, 'Outport', 1);
lane_line(s, on.name, 1, 'Sel', 1, xon(1));            % 내려와서 1번(위) 포트로
lane_line(s, ports{1}, 1, 'Sel', 3, xin(1));           % 그대로 3번(아래) 포트로
xsw = port_xy(s, 'SwVal', 'Outport', 1);
lane_line(s, 'SwVal', 1, 'Sel', 2, xsw(1));            % 올라와서 제어 포트로
add_line(s, 'Sel/1', [ports{2} '/1']);

if ~isempty(txt)
    n = Simulink.Annotation([s '/note']);
    n.Text = txt;  n.Position = [45 R+240];
end
end

% ---------------------------------------------------------------------
function place(sys, lib, name, cx, cy, w, h, params)
add_block(lib, [sys '/' name], ...
          'Position', round([cx-w/2, cy-h/2, cx+w/2, cy+h/2]));
for k = 1:2:numel(params)
    set_param([sys '/' name], params{k}, params{k+1});
end
end
