function info = gz_split_video(anim_mp4, cap, out_mp4, labels, paneW)
%GZ_SPLIT_VIDEO  가제보 화면(왼쪽)과 Simulink 실시간 화면(오른쪽)을 반씩 붙인다
%
%   info = gz_split_video('img/A3_4_vrx_anim.mp4', cap, 'video/a3_crab.mp4', ...
%                         {'가제보 — 위에서 본 선박', 'Simulink 실시간 화면'})
%
%   입력
%     anim_mp4  A3_animate 가 녹화한 mp4. 옆에 <이름>_t.mat (프레임 시각) 이 있어야 한다
%     cap       gz_shot_capture 가 돌려준 묶음 (그림 폴더와 색인)
%     out_mp4   내보낼 파일. 폴더가 없으면 만든다
%     labels    위 띠에 적을 두 줄 {왼쪽, 오른쪽}. 비우면 띠를 넣지 않는다
%     paneW     한 칸의 너비 [픽셀]. 기본 960 — 전체 1920 이 된다
%
%   어떻게 짝을 맞추는가
%     두 화면을 **같은 루프에서 찍지 않는다** (하나는 MATLAB, 하나는 WSL).
%     그래서 프레임 번호로는 맞출 수 없고, 둘 다 적어 둔 **벽시계 시각**으로
%     가장 가까운 그림을 고른다. 기준은 Simulink 쪽 프레임이다.
%
%   두 칸은 **정확히 반반**이다. 가제보 화면은 세로로 길어 그대로는 안 맞으므로,
%   비율을 지킨 채 칸 안에 넣고 남는 자리는 흰색으로 둔다.
%
%   ffmpeg 를 쓰지 않는다 — 이 PC 에 없다. VideoReader/VideoWriter 로만 붙인다.

    if nargin < 4, labels = {}; end
    if nargin < 5 || isempty(paneW), paneW = 960; end

    %% 1. Simulink 쪽 녹화와 그 프레임 시각
    assert(isfile(anim_mp4), 'gz_split_video:anim', '녹화 파일이 없다 — %s', anim_mp4);
    [ad, an] = fileparts(anim_mp4);
    tmat = fullfile(ad, [an '_t.mat']);

    vr  = VideoReader(anim_mp4);
    fps = vr.FrameRate;
    A   = read(vr);                       % H x W x 3 x N
    nA  = size(A, 4);

    if isfile(tmat)
        S  = load(tmat, 'stamp');
        tA = S.stamp(:);
    else
        tA = [];
        warning('gz_split_video:nostamp', ...
                '프레임 시각 파일이 없다 (%s) — 프레임 번호를 비례로 맞춘다', tmat);
    end

    %% 2. 가제보 쪽 그림과 그 시각
    [tG, fG] = gz_shot_read(cap);
    assert(~isempty(fG), 'gz_split_video:nogz', ...
           '가제보 그림이 없다 — %s 를 보라', cap.dir);

    %% 2-2. 시간대 어긋남 바로잡기
    %    두 시각이 **15 분의 정수배**만큼 떨어져 있으면 시간대 문제다
    %    (posixtime 에 TimeZone 을 주지 않으면 지역시를 UTC 로 읽는다).
    %    실제 촬영 간격은 초 단위이므로, 15 분 배수는 시간대일 수밖에 없다
    if ~isempty(tA)
        off = round((median(tA) - median(tG)) / 900) * 900;
        if off ~= 0
            warning('gz_split_video:tz', ...
                    '두 시각이 %g 시간 어긋나 있다 — 시간대 차이로 보고 맞춘다', off/3600);
            tA = tA - off;
        end
    end

    %% 3. 칸 크기 — 오른쪽(Simulink) 비율을 기준으로 높이를 정한다
    H = round(paneW * size(A,1) / size(A,2));
    H = H - mod(H, 2);                    % mp4 는 짝수여야 한다
    W = paneW - mod(paneW, 2);

    band = [];
    if ~isempty(labels)
        band = label_band(labels, W, 38);
    end

    %% 4. 붙여 쓴다
    od = fileparts(out_mp4);
    if ~isempty(od) && ~isfolder(od), mkdir(od); end
    vw = VideoWriter(out_mp4, 'MPEG-4');
    vw.FrameRate = max(1, fps);
    vw.Quality   = 95;
    open(vw);

    nPair = 0;  dtmax = 0;
    for k = 1:nA
        %  이 프레임과 시각이 가장 가까운 가제보 그림
        if isempty(tA)
            j = max(1, min(numel(fG), round(k/nA * numel(fG))));
        else
            [dt, j] = min(abs(tG - tA(min(k, numel(tA)))));
            dtmax = max(dtmax, dt);
        end

        gi = imread(fG{j});
        L  = fit_pane(gi(:,:,1:3), H, W);
        R  = imresize(A(:,:,:,k), [H W]);

        fr = [L R];
        if ~isempty(band), fr = [band; fr]; end     %#ok<AGROW>
        writeVideo(vw, fr);
        nPair = nPair + 1;
    end
    close(vw);

    info = struct('file', out_mp4, 'frames', nPair, 'fps', fps, ...
                  'size', [size(A,1) size(A,2)], 'pane', [H W], ...
                  'n_gz', numel(fG), 'dt_max', dtmax);
    fprintf('  분할 영상 — %s\n', out_mp4);
    fprintf('    %d 프레임 · %g frame/s · %d x %d · 가제보 그림 %d 장', ...
            nPair, fps, 2*W, H + size(band,1), numel(fG));
    if dtmax > 0
        fprintf(' · 짝 맞춤 오차 최대 %.2f s', dtmax);
    end
    fprintf('\n');
end


function P = fit_pane(im, H, W)
%  비율을 지킨 채 H x W 칸을 **가득 채운다** — 남는 쪽은 가운데만 남기고 자른다
%
%  가제보 화면은 세로로 길다 (781 x 952). 빈 자리를 흰색으로 두면 배가
%  칸의 절반밖에 못 쓰고 그만큼 작아진다. 카메라가 선박을 따라다니므로
%  배는 늘 화면 가운데에 있고, 가장자리는 물뿐이다 — 잘라도 잃는 것이 없다
    s  = max(H/size(im,1), W/size(im,2));
    im = imresize(im, s);
    r0 = 1 + floor((size(im,1) - H)/2);
    c0 = 1 + floor((size(im,2) - W)/2);
    P  = im(r0:r0+H-1, c0:c0+W-1, :);
end


function B = label_band(labels, W, h)
%  두 칸 위에 붙일 흰 띠 — 글자는 그림으로 떠낸다 (insertText 의 한글 폰트를 믿지 않는다)
    f = figure('Visible','off', 'Units','pixels', 'Color','w', ...
               'Position',[100 100 2*W h], 'MenuBar','none', 'ToolBar','none');
    ax = axes('Parent', f, 'Position',[0 0 1 1]);
    axis(ax, 'off');  xlim(ax, [0 2]);  ylim(ax, [0 1]);
    for k = 1:min(2, numel(labels))
        text(ax, (k-1) + 0.012, 0.46, labels{k}, 'Parent', ax, ...
             'FontName','Malgun Gothic', 'FontSize', 15, ...
             'Color',[0.12 0.16 0.22], 'VerticalAlignment','middle');
    end
    line(ax, [1 1], [0 1], 'Color',[0.796 0.835 0.882], 'LineWidth', 1.2);
    drawnow;
    fr = getframe(f);
    close(f);
    B = imresize(fr.cdata, [h 2*W]);
end
