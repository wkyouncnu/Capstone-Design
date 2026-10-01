function nm = from_name(sys, tag)
%FROM_NAME  이 시스템에서 비어 있는 From 블록 이름. 'Fr_<태그>', 중복이면 **번호만**.
%
%   nm = from_name(m, 'psi')          % 'Fr_psi' — 비어 있으면 그대로
%   nm = from_name(m, 'psi')          % 'Fr_psi_2' — 이미 있으면 번호만 붙인다
%
%   왜 번호만 붙이는가 / why only a number
%       2026-10-01 교수 지시 — "From 블록 이름도 정리할 것. Fr_psi_HeadingCtrl 이
%       아니라 Fr_psi 꼴로. 같은 태그를 여러 곳에서 받으면 Fr_psi_1 · Fr_psi_2
%       처럼 번호만 붙일 것 (블록 이름을 섞지 말 것)."
%
%       블록 이름을 섞으면 이름이 길어져 이름표가 이웃 블록을 덮고, 받는 블록을
%       바꾸면 태그 이름까지 손대야 한다. 태그가 나르는 것은 **신호**이므로
%       이름에 들어갈 것도 신호 이름뿐이다.
%
%   돌려주는 것은 블록 **이름**이다 (경로가 아니다). 태그 이름(GotoTag)은
%   건드리지 않는다 — 그것은 신호 이름이고, 바꾸면 연결이 끊긴다.

nm = ['Fr_' char(tag)];
j  = 1;
while ~isempty(find_system(sys, 'SearchDepth',1, 'LookUnderMasks','all', ...
                           'FollowLinks','on', 'Name', nm))
    j  = j + 1;
    nm = sprintf('Fr_%s_%d', char(tag), j);
end
end
