function t = name_box(blk, r)
%NAME_BOX  블록 이름표가 차지하는 자리 (어림). 이름을 숨긴 블록은 NaN.
%
%   t = name_box('W06_3_heading_offline/log_FL')   % 블록 — 위치·방향을 읽는다
%   t = name_box('Go_X', [x1 y1 x2 y2])            % 이름 + 사각형 (아직 없는 블록)
%
%   왜 필요한가 / why this exists
%       선 검사는 선만 본다. 블록 이름은 블록 **밖**에 쓰이므로, 사각형을 피해
%       그은 통로가 이름표 위를 지나가 이름을 읽을 수 없게 만든다. 배치 도구가
%       통로를 고를 때 사각형과 **함께** 피해야 하는 자리다.
%
%   어림 / the estimate
%       글자 폭은 ASCII 6.5 px, 한글 12 px. 이름표 너비는 그 폭과 블록 폭 중
%       큰 쪽이고 (이름이 짧아도 블록 폭만큼은 차지한다), 줄 하나가 14 px.
%       방향이 오른쪽·왼쪽이면 이름은 블록 **아래**, 위·아래면 **오른쪽**에 붙는다.
%       NamePlacement 가 alternate 면 반대쪽이다.
%
%       check_lines 의 (6) 블록겹침 · (7) 이름표 위 선과 같은 계산이다. 고칠 때는
%       둘을 함께 고칠 것.

nm = '';  ori = 'right';  alt = false;  known = false;
try
    nm    = get_param(blk, 'Name');
    pos   = get_param(blk, 'Position');
    known = true;
    if strcmp(get_param(blk, 'ShowName'), 'off'), t = nan(1,4); return, end
    ori = get_param(blk, 'Orientation');
    alt = strcmp(get_param(blk, 'NamePlacement'), 'alternate');
catch
    nm = char(blk);                       % 아직 놓지 않은 블록 — 이름만 준 것
end
if nargin >= 2 && ~isempty(r), pos = r; elseif ~known
    error('name_box:rect', '사각형을 함께 줄 것');
end

parts = strsplit(nm, newline);
w = 0;
for k = 1:numel(parts)
    c = double(parts{k});
    w = max(w, sum(c < 128)*6.5 + sum(c >= 128)*12);
end
h = 14*numel(parts);

if any(strcmp(ori, {'right','left'}))
    ww = max(w, pos(3)-pos(1));  cx = (pos(1)+pos(3))/2;
    if alt, y = [pos(2)-2-h, pos(2)-2]; else, y = [pos(4)+2, pos(4)+2+h]; end
    t = [cx-ww/2 y(1) cx+ww/2 y(2)];
else
    cy = (pos(2)+pos(4))/2;
    if alt, x = [pos(1)-2-w, pos(1)-2]; else, x = [pos(3)+2, pos(3)+2+w]; end
    t = [x(1) cy-h/2 x(2) cy+h/2];
end
end
