function [X, Y, inX, inY, mouthX, mouthY] = W08_dock_patch(dx, dy, dpsi, sd)
% W08_DOCK_PATCH  ㄷ 자 도킹 스테이션의 외곽·베이·입구 좌표를 낸다 [m, NED]
%
%   6주차 W06_dock_patch.m 과 치수·수식이 같다. 8주차가 6주차 폴더에 의존하지
%   않고 혼자 돌게 하려고 사본을 둔다 (tidy_layout.m 을 폴더마다 두는 것과 같은 이유).
%
%   입력
%     dx, dy : 접안 완료 위치 — 베이 안쪽의 정박점 [m] (북, 동)
%     dpsi   : 접안 자세 — 선수각 [rad]
%     sd     : 접안 방향  +1 = 우현 접안,  -1 = 좌현 접안
%
%   출력
%     X,  Y        벽 외곽 다각형 (patch 로 채운다)
%     inX, inY     베이 내부 다각형 (배가 들어가는 빈 공간)
%     mouthX, mouthY  입구 중앙선 — 들어가는 방향을 표시한다
%
%   치수가 왜 이 값인가 — 6주차 실측에서 나왔다
%     입구 반폭 H = 4.2 m   : 선체 횡방향 최대 |a| = 2.45 m → 좌우 1.75 m 여유
%     베이 깊이 K = 5.5 m   : 선수 쪽 최대 침입 4.16 m → 1.34 m 여유
%     날개 길이 Lw = 2.5 m  : 7 m 로 두었을 때 선체를 0.022 m 차이로 스쳤다
%     벽 두께 W = 1.3 m     : 그림에서 벽이 선으로 보이지 않게 하는 최소 두께

H  = 4.2;      % 입구 반폭   [m]
K  = 5.5;      % 베이 깊이   [m]
Lw = 2.5;      % 날개 길이   [m]
W  = 1.3;      % 벽 두께     [m]

%  접안 좌표계 (a, b) — a 는 입구와 나란한 방향, b 는 들어가는 방향(+ 가 바깥)
a  = [-H-W, -H-W,  H+W,  H+W,   H,   H,  -H,  -H];
b  = [  Lw,  -K-W, -K-W,   Lw,  Lw,  -K,  -K,   Lw];

ai = [-H,  H,  H, -H];
bi = [-K, -K, Lw, Lw];

am = [0, 0];
bm = [Lw, 0];

%  (a, b) -> NED.  a 는 선수방향 단위벡터, b 는 접안 쪽 법선
tx = cos(dpsi);        ty = sin(dpsi);
nx = -sd*sin(dpsi);    ny =  sd*cos(dpsi);

X = dx + a*tx + b*nx;        Y = dy + a*ty + b*ny;
inX = dx + ai*tx + bi*nx;    inY = dy + ai*ty + bi*ny;
mouthX = dx + am*tx + bm*nx; mouthY = dy + am*ty + bm*ny;
end
