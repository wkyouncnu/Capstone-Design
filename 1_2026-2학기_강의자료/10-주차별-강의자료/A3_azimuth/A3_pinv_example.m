function E = A3_pinv_example()
%A3_PINV_EXAMPLE  라그랑주 승수로 얻는 최소 노름 해 — 손풀이와 숫자를 맞대어 본다
%
%   >> A3_pinv_example          % 표만 출력
%   >> E = A3_pinv_example;     % 숫자를 구조체로 받음
%
%   목적
%     배분기 한 줄  ue = B'*((B*B')\tau)  이 어디서 나온 식인지를
%     **손으로 풀 수 있는 크기**의 예제 셋으로 확인한다.
%     종이에 먼저 풀고, 이 스크립트의 출력과 숫자가 맞는지 본다.
%
%   예제 셋
%     예제 1   미지수 2 · 식 1      라그랑주 승수가 무엇인지만 본다
%     예제 2   미지수 4 · 식 3      실제 배분과 같은 꼴. 횡방향 요구
%     예제 3   미지수 4 · 식 3      최소 노름 해가 각도 한계를 넘는 경우
%
%   예제 2·3 의 기하는 **손풀이용 반올림 값**이다
%     b = 1 m, L = 2 m  (실제 WAM-V 는 b = 1.027135 m, L = 2.373776 m)
%     분수가 깔끔하게 떨어져 B*B' 의 역행렬을 손으로 쓸 수 있다
%
%   이 파일은 물리를 다시 구현한 것이 아니다 — 선형대수 한 줄의 검산기다

E = struct();

bb    = 1;        % 중심선 -> 추진기 가로 거리 [m]   (손풀이용 값)
LL    = 2;        % 무게중심 -> 추진기 뒤쪽 거리 [m] (손풀이용 값)
d_max = 45*pi/180;
F_max = 500;

%% ===================================================================
%  예제 1 — 미지수 둘, 식 하나. 라그랑주 승수가 무엇인가
%  -------------------------------------------------------------------
%  풀 문제   min 0.5*(x1^2 + x2^2)   s.t.   x1 + x2 = 10
%
%  손풀이
%    Lg(x,lam) = 0.5*(x1^2+x2^2) - lam*(x1+x2-10)
%    dLg/dx1 = x1 - lam = 0     ->  x1 = lam
%    dLg/dx2 = x2 - lam = 0     ->  x2 = lam
%    dLg/dlam = -(x1+x2-10) = 0 ->  2*lam = 10  ->  lam = 5
%    따라서 x = [5; 5],  norm = sqrt(50) = 7.0711
%% ===================================================================
fprintf('\n=== 예제 1 : 미지수 둘, 식 하나 ===\n');
A1 = [1 1];   d1 = 10;

lam1 = (A1*A1')\d1;        % 라그랑주 승수   (B*B'*lam = tau 의 1x1 판)
x1   = A1'*lam1;           % x = A'*lam      (미분해서 얻은 관계)

fprintf('  라그랑주 승수  lam = %g        (손풀이 5)\n', lam1);
fprintf('  해            x   = [%g %g]   (손풀이 [5 5])\n', x1(1), x1(2));
fprintf('  노름          |x| = %.4f      (손풀이 sqrt(50) = 7.0711)\n', norm(x1));
fprintf('  pinv 로 같은 해 : [%g %g]\n', pinv(A1)*d1);

fprintf('\n  다른 해들과 노름 비교 — 식은 모두 만족한다\n');
fprintf('    x = [x1 x2]        x1+x2      |x|\n');
cand = [5 5; 6 4; 8 2; 10 0; 0 10];
for k = 1:size(cand,1)
    mk = '';
    if norm(cand(k,:)-x1') < 1e-12
        mk = '  <- 최소';
    end
    fprintf('    [%5.1f %5.1f]      %5.1f   %8.4f%s\n', ...
            cand(k,1), cand(k,2), sum(cand(k,:)), norm(cand(k,:)), mk);
end

E.ex1 = struct('A',A1,'d',d1,'lam',lam1,'x',x1,'nrm',norm(x1));

%% ===================================================================
%  예제 2 — 미지수 넷, 식 셋. 실제 배분과 같은 꼴
%  -------------------------------------------------------------------
%  미지수  ue = [FxL; FyL; FxR; FyR]        (추진기 둘의 힘 성분)
%  식      B*ue = tau,  tau = [X; Y; N]
%
%          |  1   0   1   0 |
%      B = |  0   1   0   1 |
%          |  b  -L  -b  -L |
%
%  손풀이 (b = 1, L = 2)
%            | 2   0   0 |                | 0.5   0    0  |
%    B*B' =  | 0   2  -4 |  ->  inv =     |  0   2.5   1  |
%            | 0  -4  10 |                |  0    1   0.5 |
%
%    (오른쪽 아래 2x2 의 행렬식 = 2*10 - (-4)^2 = 4 이므로 손으로 뒤집힌다)
%
%    요구 tau = [0; 100; 0] 을 넣으면
%      lam = inv(B*B')*tau = [0; 250; 100]
%      ue  = B'*lam        = [100; 50; -100; 50]
%      |ue| = sqrt(25000)  = 158.11
%% ===================================================================
fprintf('\n=== 예제 2 : 미지수 넷, 식 셋 — 횡방향 요구 ===\n');
B    = [ 1  0  1  0
         0  1  0  1
        bb -LL -bb -LL];
tau2 = [0; 100; 0];

G    = B*B';
lam2 = G\tau2;
ue2  = B'*lam2;

fprintf('  B*B'' =\n');
fprintf('     %6.1f %6.1f %6.1f\n', G');
fprintf('  inv(B*B'') =\n');
fprintf('     %6.2f %6.2f %6.2f\n', inv(G)');
fprintf('  라그랑주 승수  lam = [%g %g %g]      (손풀이 [0 250 100])\n', lam2);
fprintf('  최소 노름 해   ue  = [%g %g %g %g]   (손풀이 [100 50 -100 50])\n', ue2);
fprintf('  노름          |ue| = %.4f            (손풀이 sqrt(25000) = 158.1139)\n', norm(ue2));
fprintf('  되짚어 본 요구  B*ue = [%g %g %g]      (요구 [0 100 0])\n', B*ue2);

[TL2,dL2] = az_polar(ue2(1), ue2(2), d_max, F_max);
[TR2,dR2] = az_polar(ue2(3), ue2(4), d_max, F_max);
fprintf('  추진기 지령    좌현 T = %8.3f N, delta = %7.3f deg\n', TL2, dL2*180/pi);
fprintf('                 우현 T = %8.3f N, delta = %7.3f deg   (뒤로 밂 — 90 deg 접기)\n', TR2, dR2*180/pi);

E.ex2 = struct('B',B,'tau',tau2,'G',G,'lam',lam2,'ue',ue2,'nrm',norm(ue2), ...
               'TL',TL2,'dL_deg',dL2*180/pi,'TR',TR2,'dR_deg',dR2*180/pi);

%% ===================================================================
%  예제 3 — 최소 노름 해가 각도 한계를 넘는 경우
%  -------------------------------------------------------------------
%  요구 tau = [100; 200; -200]
%    lam = [50; 300; 100]  ->  ue = [150; 100; -50; 100]
%    좌현 delta = atan2(100,150) = 33.69 deg   (한계 안)
%    우현 delta = atan2(100,-50) = 116.57 deg  -> 90 deg 접기 -> -63.43 deg  (한계 밖)
%
%  null space 벡터   nz = [0; 1; 0; -1]       (B*nz = 0 — 요구가 바뀌지 않는다)
%    ue + k*nz 로 옮겨도 X, Y, N 이 그대로다. 바뀌는 것은 각도뿐
%    좌현 조건  (100+k) <= 150  ->  k <= 50
%    우현 조건  (100-k) <=  50  ->  k >= 50
%    따라서 k = 50  ->  ue = [150; 150; -50; 50],  두 각도 모두 정확히 +-45 deg
%% ===================================================================
fprintf('\n=== 예제 3 : 최소 노름 해가 각도 한계를 넘는 경우 ===\n');
tau3 = [100; 200; -200];
lam3 = G\tau3;
ue3  = B'*lam3;
nz   = [0; 1; 0; -1];

fprintf('  B*nz = [%g %g %g]   <- null space 벡터. 요구를 바꾸지 않는다\n', B*nz);
fprintf('  라그랑주 승수  lam = [%g %g %g]\n', lam3);
fprintf('  최소 노름 해   ue  = [%g %g %g %g]   |ue| = %.4f\n', ue3, norm(ue3));

%  (1) 한계를 적용하지 **않은** 각도 — 여기서 위반이 보인다
[TL3,dL3] = az_fold(ue3(1), ue3(2));
[TR3,dR3] = az_fold(ue3(3), ue3(4));
fprintf('  한계를 걸기 전 각도 (90 deg 접기까지만)\n');
fprintf('    좌현 T = %8.3f N, delta = %7.3f deg  %s\n', ...
        TL3, dL3*180/pi, pass(abs(dL3)<=d_max+1e-9));
fprintf('    우현 T = %8.3f N, delta = %7.3f deg  %s\n', ...
        TR3, dR3*180/pi, pass(abs(dR3)<=d_max+1e-9));

%  (2) 보정 없이 각도만 깎으면 — 요구가 조용히 깎인다
[TL3s,dL3s] = az_polar(ue3(1), ue3(2), d_max, F_max);
[TR3s,dR3s] = az_polar(ue3(3), ue3(4), d_max, F_max);
w3s = wrench(TL3s, dL3s, TR3s, dR3s, bb, LL);
fprintf('  각도만 깎고 그대로 내보내면 (null space 보정 없음)\n');
fprintf('    우현 delta 가 %7.3f -> %7.3f deg 로 잘린다\n', dR3*180/pi, dR3s*180/pi);
fprintf('    실제 렌치  [%8.3f %8.3f %8.3f]\n', w3s);
fprintf('    요구 렌치  [%8.3f %8.3f %8.3f]\n', tau3);
fprintf('    못 낸 힘   [%8.3f %8.3f %8.3f]   <- 오류 메시지는 뜨지 않는다\n', w3s - tau3);

%  (3) null space 보정을 넣으면 — 요구를 그대로 내면서 한계 안으로 들어간다
k_n  = 50;
ue3c = ue3 + k_n*nz;
[TL3c,dL3c] = az_polar(ue3c(1), ue3c(2), d_max, F_max);
[TR3c,dR3c] = az_polar(ue3c(3), ue3c(4), d_max, F_max);
w3c = wrench(TL3c, dL3c, TR3c, dR3c, bb, LL);

fprintf('  보정량 k = %g  ->  ue = [%g %g %g %g]   |ue| = %.4f\n', ...
        k_n, ue3c, norm(ue3c));
fprintf('    좌현 T = %8.3f N, delta = %7.3f deg  %s\n', ...
        TL3c, dL3c*180/pi, pass(abs(dL3c)<=d_max+1e-9));
fprintf('    우현 T = %8.3f N, delta = %7.3f deg  %s\n', ...
        TR3c, dR3c*180/pi, pass(abs(dR3c)<=d_max+1e-9));
fprintf('    실제 렌치  [%8.3f %8.3f %8.3f]\n', w3c);
fprintf('    못 낸 힘   [%8.3f %8.3f %8.3f]   <- 0 이다\n', w3c - tau3);
fprintf('  노름은 커졌다  %.4f -> %.4f   (한계 안으로 들어가는 값이다)\n', ...
        norm(ue3), norm(ue3c));

E.ex3 = struct('tau',tau3,'lam',lam3,'ue',ue3,'nrm',norm(ue3), ...
               'k',k_n,'ue_corr',ue3c,'nrm_corr',norm(ue3c), ...
               'dL_raw_deg',dL3*180/pi,'dR_raw_deg',dR3*180/pi, ...
               'TL_raw',TL3,'TR_raw',TR3, ...
               'w_nocorr',w3s,'short_nocorr',w3s-tau3, ...
               'dL_corr_deg',dL3c*180/pi,'dR_corr_deg',dR3c*180/pi, ...
               'TL_corr',TL3c,'TR_corr',TR3c,'w_corr',w3c);

%% ===================================================================
%  세 가지 풀이법 비교 — pinv 는 같은 것인가
%% ===================================================================
fprintf('\n=== 세 가지 풀이법 — 같은 해인가 ===\n');
u_lag  = B'*((B*B')\tau2);     % 라그랑주 (배분기가 쓰는 식)
u_pinv = pinv(B)*tau2;         % pinv  — SVD 기반
u_bsl  = B\tau2;               % 역슬래시 — QR 기반 basic solution

fprintf('  라그랑주  B''*((B*B'')\\tau)  = [%8.3f %8.3f %8.3f %8.3f]  |u| = %8.4f\n', ...
        u_lag,  norm(u_lag));
fprintf('  pinv      pinv(B)*tau       = [%8.3f %8.3f %8.3f %8.3f]  |u| = %8.4f\n', ...
        u_pinv, norm(u_pinv));
fprintf('  역슬래시  B\\tau             = [%8.3f %8.3f %8.3f %8.3f]  |u| = %8.4f\n', ...
        u_bsl,  norm(u_bsl));
fprintf('  라그랑주 <-> pinv     최대 차이 : %.3e  (수치 오차 수준)\n', max(abs(u_lag-u_pinv)));
fprintf('  라그랑주 <-> 역슬래시 최대 차이 : %.3f  <- 다른 해다\n', max(abs(u_lag-u_bsl)));
fprintf('  역슬래시도 B*u = tau 를 만족한다 : B*u = [%g %g %g]\n', B*u_bsl);
fprintf('  다만 노름이 최소가 아니다 — 0 이 많은 해를 고르기 때문이다\n');

E.cmp = struct('u_lag',u_lag,'u_pinv',u_pinv,'u_bsl',u_bsl, ...
               'd_pinv',max(abs(u_lag-u_pinv)),'d_bsl',max(abs(u_lag-u_bsl)));

%% ===================================================================
%  승수의 뜻 — 요구를 1 N 늘리면 추력 제곱합이 얼마 늘어나는가
%% ===================================================================
fprintf('\n=== 라그랑주 승수의 뜻 ===\n');
J = 0.5*norm(ue2)^2;
fprintf('  0.5*|ue|^2              = %g\n', J);
fprintf('  0.5*tau''*inv(B*B'')*tau = %g   (같은 값 — 손풀이로도 확인된다)\n', 0.5*tau2'*(G\tau2));
h = 1e-6;
for i = 1:3
    tp = tau2;  tp(i) = tp(i) + h;
    Jp = 0.5*norm(B'*(G\tp))^2;
    fprintf('  d/dtau(%d) 수치미분 = %10.4f   lam(%d) = %10.4f\n', ...
            i, (Jp-J)/h, i, lam2(i));
end
fprintf('  즉 lam(i) 는 "요구 i 를 1 단위 늘릴 때 늘어나는 0.5*|ue|^2" 다\n');

%% ===================================================================
%  검산 — 틀리면 여기서 멈춘다
%% ===================================================================
assert(norm(B*ue2  - tau2) < 1e-10, '예제 2 : B*ue 가 요구와 다르다');
assert(norm(B*ue3  - tau3) < 1e-10, '예제 3 : B*ue 가 요구와 다르다');
assert(norm(B*ue3c - tau3) < 1e-10, '예제 3 : 보정 뒤 요구가 바뀌었다');
assert(norm(B*nz) < 1e-12,          'null space 벡터가 틀렸다');
assert(max(abs(u_lag - u_pinv)) < 1e-9, 'pinv 와 라그랑주 해가 다르다');
assert(norm(ue3c) >= norm(ue3) - 1e-9, '보정이 노름을 줄였다 — 있을 수 없다');
assert(abs(dR3) > d_max + 1e-6,     '예제 3 : 보정 전 각도가 한계를 넘지 않는다');
assert(norm(w3s - tau3) > 1,        '예제 3 : 각도를 깎았는데 요구가 그대로 나왔다');
assert(norm(w3c - tau3) < 1e-9,     '예제 3 : 보정 뒤에도 요구를 못 냈다');
fprintf('\n  검산 여섯 항목 모두 통과\n\n');
end

% ---------------------------------------------------------------------
function [T, dd] = az_fold(Fx, Fy)
%AZ_FOLD  성분 -> (크기, 각도). **접기까지만** 하고 한계는 적용하지 않는다
%         한계를 걸기 전의 각도를 보아야 위반 여부가 보인다
T  = hypot(Fx, Fy);
dd = atan2(Fy, Fx);
if abs(dd) > pi/2
    dd = dd - sign(dd)*pi;
    T  = -T;
end
end

% ---------------------------------------------------------------------
function w = wrench(T_L, d_L, T_R, d_R, bb, LL)
%WRENCH  추진기 지령 -> 실제로 나는 렌치. 같은 B 를 **바로** 쓴다
Bm = [ 1  0  1  0
       0  1  0  1
      bb -LL -bb -LL];
w  = Bm * [T_L*cos(d_L); T_L*sin(d_L); T_R*cos(d_R); T_R*sin(d_R)];
end

% ---------------------------------------------------------------------
function [T, dd] = az_polar(Fx, Fy, d_max, F_max)
%AZ_POLAR  성분 -> (크기, 각도).  배분기의 az_polar 과 같은 규칙 네 개
T  = hypot(Fx, Fy);
dd = atan2(Fy, Fx);
if abs(dd) > pi/2                 % (a) 뒤쪽 90 deg 접기
    dd = dd - sign(dd)*pi;
    T  = -T;
end
dd = max(-d_max, min(d_max, dd)); % (c) 각도 한계 — 추력은 건드리지 않는다
T  = max(-F_max, min(F_max, T));  % (d) 추력 한계
end

% ---------------------------------------------------------------------
function s = pass(ok)
if ok
    s = '(한계 안)';
else
    s = '<- 한계 밖';
end
end
