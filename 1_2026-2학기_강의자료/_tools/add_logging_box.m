function s = add_logging_box(m, sig, tag, pos, ts)
%ADD_LOGGING_BOX  포트 없는 Logging 서브시스템. From -> To Workspace 쌍을 쌓는다.
%
%   add_logging_box(m, sig, tag, [x y], 'Ts_ctrl')
%
%     SIG   To Workspace 변수 이름의 꼬리 — 'pn' 이면 변수는 log_pn
%     TAG   그 신호를 내보내는 Goto 태그 이름 (보통 SIG 와 같다)
%     POS   최상위에서 이 상자가 놓일 자리 [x y]
%     TS    샘플 타임 문자열. 보통 'Ts_ctrl'
%
%   왜 상자에 넣는가 / why this goes in a box
%       로깅은 신호 사슬이 아니다. From 과 To Workspace 를 최상위에 늘어놓으면
%       블록 수가 배로 늘고, 배치 도구가 그것들을 사슬 한가운데로 끌어들인다.
%       W05 오프라인 모델은 최상위 68 블록 중 **28 개가 로깅**이었다.
%
%       Logging is not part of the signal chain. Leaving the From and To
%       Workspace blocks on the top level doubles the block count and lets the
%       layout tool drag them into the middle of the chain.
%
%   배선 / wiring
%       From 의 출력 포트 높이에 To Workspace 를 놓는다. 선은 수평 직선 한 토막이며
%       꺾이지 않는다. 통로를 지어내지 않는다 — line-routing.md §2 참조.

if nargin < 5 || isempty(ts), ts = '-1'; end

s = add_subsys(m, 'Logging', [pos(1) pos(2) pos(1)+140 pos(2)+70], {}, {}, ...
               gnc_colour('measurement'));

for k = 1:numel(sig)
    y = 80 + (k-1)*60;

    fb = [s '/Fr_' tag{k}];
    add_block('simulink/Signal Routing/From', fb, ...
              'Position', [100 y-11 170 y+11], 'GotoTag', tag{k});

    wb = [s '/log_' sig{k}];
    add_block('simulink/Sinks/To Workspace', wb, ...
              'Position', [240 y-15 340 y+15]);
    set_param(wb, 'VariableName', ['log_' sig{k}], ...
                  'SaveFormat','Timeseries', 'SampleTime', ts);

    add_line(s, ['Fr_' tag{k} '/1'], ['log_' sig{k} '/1']);   % 수평 직선
end

add_block('built-in/Note', [s '/note'], 'Position', [100 80+numel(sig)*60], ...
    'Text', sprintf(['로깅 — 이 상자는 입출력 포트가 없다.\n' ...
        '모든 신호를 From 태그로 받으므로 최상위에 선이 생기지 않는다.\n' ...
        '변수는 base workspace 가 아니라 sim() 의 결과 객체에 담긴다.\n' ...
        '  >> out = sim(''%s'');  out.log_%s'], m, sig{1}));
end
