function out = TP_make_video(gz_dir, gcs_dir, out, opt)
%TP_MAKE_VIDEO  왼쪽 가제보 · 오른쪽 GCS 를 나란히 붙인 동영상을 만든다 (MATLAB VideoWriter)
%
%   TP_make_video(gz_dir, gcs_dir)                      % TP_manual_mission.mp4 로 저장
%   TP_make_video(gz_dir, gcs_dir, 'my.mp4', opt)
%
%   gz_dir    rec_gazebo.py 가 남긴 폴더   — gz_<벽시계 ms>.jpg          (벽시계 1 초마다)
%   gcs_dir   TP_gcs 의 녹화가 남긴 폴더   — gcs_<벽시계 ms>_<모델 시각>.jpg (모델 시간 2 초마다)
%   opt.speed  재생 배속 (기본 8).  가제보 프레임이 1 초에 한 장이므로 프레임률 = 배속
%   opt.crop   가제보 그림에서 남길 곳 [x y 폭 높이] (화소). 비우면 전체
%   opt.height 만들 영상의 높이 [px] (기본 720)
%
%   두 화면을 맞추는 법
%     두 폴더의 파일 이름에 **벽시계(ms)** 가 들어 있다. 가제보 프레임마다 벽시계가 가장 가까운
%     GCS 프레임을 골라 옆에 붙인다. 가제보와 MATLAB 이 같은 PC 에서 돌므로 시계가 같다.
%     GCS 가 돌던 동안(첫 GCS 프레임 ~ 마지막 GCS 프레임 + 3 초)의 가제보 프레임만 쓴다.

if nargin < 3 || isempty(out)
    out = fullfile(fileparts(mfilename('fullpath')), 'TP_manual_mission.mp4');
end
if nargin < 4, opt = struct(); end
if ~isfield(opt, 'speed'),  opt.speed  = 8;   end
if ~isfield(opt, 'crop'),   opt.crop   = [];  end
if ~isfield(opt, 'height'), opt.height = 720; end

a = dir(fullfile(gz_dir, 'gz_*.jpg'));
b = dir(fullfile(gcs_dir, 'gcs_*.jpg'));
assert(~isempty(a) && ~isempty(b), '프레임이 없다 — 폴더를 확인할 것');
tg = cellfun(@(s) sscanf(s, 'gz_%f.jpg'), {a.name});
tc = zeros(1, numel(b));   ts = zeros(1, numel(b));
for k = 1:numel(b)
    v = sscanf(b(k).name, 'gcs_%f_%f.jpg');
    tc(k) = v(1);   ts(k) = v(2);
end
[tc, o] = sort(tc);   b = b(o);   ts = ts(o);
[tg, o] = sort(tg);   a = a(o);
use = find(tg >= tc(1) - 500 & tg <= tc(end) + 3000);
fprintf('가제보 %d 장 가운데 %d 장 · GCS %d 장 (모델 %.0f s)\n', numel(a), numel(use), numel(b), max(ts));

H  = 2*floor(opt.height/2);
vw = VideoWriter(out, 'MPEG-4');
vw.FrameRate = opt.speed;   vw.Quality = 90;
open(vw);
W = [];   Rprev = [];   jprev = 0;
for k = use
    [~, j] = min(abs(tc - tg(k)));
    if j ~= jprev
        Rprev = fit_h(imread(fullfile(gcs_dir, b(j).name)), H);   jprev = j;
    end
    L = imread(fullfile(gz_dir, a(k).name));
    if ~isempty(opt.crop)
        c = opt.crop;
        L = L(c(2) + (1:c(4)) - 1, c(1) + (1:c(3)) - 1, :);
    end
    F = [fit_h(L, H), Rprev];
    if isempty(W), W = 2*floor(size(F, 2)/2); end      % 코덱은 짝수 폭만 받는다
    writeVideo(vw, F(:, 1:W, :));
end
close(vw);
d = dir(out);
fprintf('저장 : %s  (%d x %d, %d 장, %g fps → %.0f 초, %.1f MB)\n', ...
        out, W, H, numel(use), opt.speed, numel(use)/opt.speed, d.bytes/1e6);
end

% =====================================================================
function I = fit_h(I, H)
%FIT_H  높이를 H 로 맞춘다 (가로는 비율대로). Image Processing Toolbox 없이도 돈다
if size(I, 1) == H, return; end
w = max(2, round(size(I, 2)*H/size(I, 1)));
if exist('imresize', 'file') == 2
    I = imresize(I, [H w]);
else
    r = round(linspace(1, size(I, 1), H));
    c = round(linspace(1, size(I, 2), w));
    I = I(r, c, :);
end
end
