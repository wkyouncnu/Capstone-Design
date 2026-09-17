function s = add_animate_box(m, tags, fcnName, code, pos, ts)
%ADD_ANIMATE_BOX  포트 없는 Animate 서브시스템. 실시간 그림 블록을 한 상자에 넣는다.
%
%   add_animate_box(m, {'pn','pe','psi'}, 'W07_animate', code, [x y], 'Ts_ctrl')
%
%     TAGS     그릴 신호의 Goto 태그 이름들. 이 순서가 함수 인자 순서가 된다
%     FCNNAME  실제로 그림을 그리는 MATLAB 함수 이름 (coder.extrinsic 로 부른다)
%     CODE     MATLAB Function 블록에 넣을 본문. 비우면 표준 본문을 만들어 준다
%     POS      최상위에서 이 상자가 놓일 자리 [x y]
%     TS       Digital Clock 의 샘플 타임
%
%   함수의 인자 순서는 **TAGS, t, en** 이다. 마지막 두 개는 이 함수가 붙인다.
%     t  = 시뮬레이션 시각      en = 켜기/끄기 (base 의 animate 변수)
%
%   왜 상자에 넣는가
%       실시간 그림은 제어 루프와 아무 상관이 없다. 최상위에 Clock·상수·From 을
%       늘어놓으면 신호 사슬을 읽는 눈이 그쪽으로 끌려간다. 끄고 싶을 때
%       상자 하나만 보면 되는 것도 이점이다 (animate = 0).

if nargin < 6 || isempty(ts), ts = '-1'; end
n = numel(tags);

s = add_subsys(m, 'Animate', [pos(1) pos(2) pos(1)+140 pos(2)+70], {}, {}, ...
               gnc_colour('measurement'));

%  MATLAB Function 을 먼저 만들어 포트 높이를 읽는다. 포트 간격을 계산하지 않는다
H = max(200, 52*(n+2) + 40);
fb = [s '/AnimateFcn'];
add_block('simulink/User-Defined Functions/MATLAB Function', fb, ...
          'Position', [340 100 500 100+H]);
if isempty(code)
    args = strjoin(tags, ', ');
    code = [ ...
    sprintf('function ok = AnimateFcn(%s, t, en)', args)                newline ...
    '%#codegen'                                                          newline ...
    '% Live plot while the model runs. A MATLAB Function block cannot'   newline ...
    '% plot, so the drawing function is declared extrinsic: Simulink'    newline ...
    '% calls plain MATLAB instead of generating code for it.'            newline ...
    sprintf('coder.extrinsic(''%s'');', fcnName)                         newline ...
    'ok = 1;'                                                            newline ...
    'if en > 0.5'                                                        newline ...
    sprintf('    %s(%s, t);', fcnName, args)                             newline ...
    'end'];
end
ch = sfroot().find('-isa','Stateflow.EMChart','Path', fb);
ch.Script = code;

%  From · Clock · 상수를 각자 포트 높이에 놓는다 -> 선이 전부 수평 직선
for k = 1:n
    q = port_xy(s, 'AnimateFcn', 'Inport', k);
    b = [s '/Fr_' tags{k}];
    add_block('simulink/Signal Routing/From', b, ...
              'Position', [150 q(2)-11 220 q(2)+11], 'GotoTag', tags{k});
    add_line(s, ['Fr_' tags{k} '/1'], sprintf('AnimateFcn/%d', k));
end

q = port_xy(s, 'AnimateFcn', 'Inport', n+1);
add_block('simulink/Sources/Digital Clock', [s '/Clk'], ...
          'Position', [180 q(2)-10 220 q(2)+10], 'SampleTime', ts);
add_line(s, 'Clk/1', sprintf('AnimateFcn/%d', n+1));

q = port_xy(s, 'AnimateFcn', 'Inport', n+2);
add_block('simulink/Sources/Constant', [s '/Anim'], ...
          'Position', [165 q(2)-15 220 q(2)+15], 'Value','animate');
add_line(s, 'Anim/1', sprintf('AnimateFcn/%d', n+2));

q = port_xy(s, 'AnimateFcn', 'Outport', 1);
add_block('simulink/Sinks/Terminator', [s '/AnimEnd'], ...
          'Position', [580 q(2)-10 600 q(2)+10]);
add_line(s, 'AnimateFcn/1', 'AnimEnd/1');

add_block('built-in/Note', [s '/note'], 'Position', [150 140+H], ...
    'Text', sprintf(['실시간 그림 — 이 상자는 입출력 포트가 없다.\n' ...
        '끄려면 base workspace 에서  animate = 0  으로 두고 다시 Run.\n' ...
        '끄면 시뮬레이션이 눈에 띄게 빨라진다.\n' ...
        '그리는 일은 %s.m 이 한다.'], fcnName));
end
