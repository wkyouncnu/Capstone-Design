function k = TP_gcs_keys(t)
%TP_GCS_KEYS  GCS 창에서 눌린 조종 입력을 모델에 넘긴다 — ManualPad/GcsKeys 블록이 매 스텝 부른다
%
%   k = TP_gcs_keys(t)      6x1,  각 칸 0 또는 1
%       [전진; 후진; 좌선회; 우선회; 좌현 횡이동; 우현 횡이동]
%
%   값의 출처 둘 (큰 쪽을 쓴다)
%     1) appdata 'TP_keys'    GCS 창의 키보드(W S A D Q E)·화살표 버튼이 적어 둔다 (TP_gcs.m)
%     2) appdata 'TP_pilot'   함수 핸들 k = f(t, state). 사람이 누르는 대신 스크립트가 누른다
%                             (TP_manual_check.m 의 재현 가능한 확인 주행이 쓴다)
%                             state = [t x_n y_n psi u v r FL FR FB X Y N x_true y_true valid]
%
%   왜 set_param 으로 버튼 Constant 를 바꾸지 않는가
%     그림 콜백은 모델이 한 스텝을 도는 **도중에** 불릴 수 있다. 그때 블록 파라미터를
%     바꾸면 거부되거나 다음 스텝으로 밀린다. 값을 appdata 에 두고 모델이 제 박자에 읽으면
%     그런 일이 없다.

k = zeros(6, 1);
a = getappdata(0, 'TP_keys');
if numel(a) == 6, k = double(a(:)); end

P = getappdata(0, 'TP_pilot');
if isa(P, 'function_handle')
    s = getappdata(0, 'TP_state');
    if isempty(s), s = zeros(1, 16); end
    kp = double(P(t, s));
    if numel(kp) == 6, k = max(k, kp(:)); end
end
k = min(max(k, 0), 1);
end
