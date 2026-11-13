function E = A3_nullspace_example()
%A3_NULLSPACE_EXAMPLE  null space 보정 — 보정 전과 보정 후를 숫자 하나로 맞대어 본다
%
%   >> A3_nullspace_example          % 표만 출력
%   >> E = A3_nullspace_example;     % 숫자를 구조체로 받음
%
%   목적
%     배분기의 아홉 줄(parts/azAllocFcn.m 의 2 단계)이 무엇을 하는지를
%     **종이에서 끝나는 크기**의 숫자 하나로 확인한다.
%     문서 1-7 절의 다섯 걸음과 이 스크립트의 출력은 한 자리까지 같다.
%
%   예제 기하는 **손풀이용 반올림 값**이다
%     b = 1 m, L = 2 m  (실제 WAM-V 는 b = 1.027135 m, L = 2.373776 m)
%     B*B' 의 역행렬이 분수로 떨어져 손으로 쓸 수 있다
%
%   요구는 ±45° 쐐기 한가운데를 고른 값이다
%     tau = [250; 100; 0]   ->  X/Y = 2.5,  쐐기는 1 ~ 3
%
%   이 파일은 물리를 다시 구현한 것이 아니다 — 선형대수 한 줄의 검산기다
%   (같은 꼴의 선례: A3_pinv_example.m)

E = struct();

bb    = 1;              % 중심선 -> 추진기 가로 거리 [m]   (손풀이용 값)
LL    = 2;              % 무게중심 -> 추진기 뒤쪽 거리 [m] (손풀이용 값)
d_max = 45*pi/180;      % 방향각 한계 [rad]
F_max = 500;            % 추력 한계 [N]
td    = tan(d_max);     % = 1

B  = [ 1   0   1   0
       0   1   0   1
      bb -LL -bb -LL];
nz = [0; 1; 0; -1];

tau = [250; 100; 0];

fprintf('\n');
fprintf('=====================================================================\n');
fprintf('  null space 보정 — 보정 전 / 보정 후  (b = %g m, L = %g m)\n', bb, LL);
fprintf('=====================================================================\n');

%% ===================================================================
%  1 걸음 — 요구와 배치행렬
%% ===================================================================
fprintf('\n[1] 요구와 배치행렬\n');
fprintf('    tau = [X; Y; N] = [%g; %g; %g]\n', tau);
fprintf('    B =\n');
fprintf('       %6.1f %6.1f %6.1f %6.1f\n', B');
fprintf('    B*nz = [%g %g %g]   <- null space 벡터. 요구를 바꾸지 않는다\n', B*nz);

%% ===================================================================
%  2 걸음 — 최소 노름 해를 손계산 그대로
%  -------------------------------------------------------------------
%            | 2   0   0 |                   | 0.5   0    0  |
%    B*B' =  | 0   2  -4 |   ->   inv(B*B') = |  0   2.5   1  |
%            | 0  -4  10 |                   |  0    1   0.5 |
%
%    lam = inv(B*B')*tau = [125; 250; 100]
%    ue  = B'*lam        = [225;  50;  25;  50]
%% ===================================================================
fprintf('\n[2] 최소 노름 해  ue = B''*((B*B'')\\tau)\n');
G   = B*B';
lam = G\tau;
ue  = B'*lam;

fprintf('    B*B'' =\n');
fprintf('       %6.1f %6.1f %6.1f\n', G');
fprintf('    inv(B*B'') =\n');
fprintf('       %6.2f %6.2f %6.2f\n', inv(G)');
fprintf('    lam = [%g %g %g]            (손풀이 [125 250 100])\n', lam);
fprintf('    ue  = [%g %g %g %g]    (손풀이 [225 50 25 50])\n', ue);
fprintf('    |ue| = %.4f                  (손풀이 sqrt(56250) = 237.1708)\n', norm(ue));
fprintf('    검산 B*ue = [%g %g %g]       (요구 그대로)\n', B*ue);

E.step2 = struct('G',G,'Ginv',inv(G),'lam',lam,'ue',ue,'nrm',norm(ue));

%% ===================================================================
%  3 걸음 — 보정하지 않은 해의 각도. 우현이 한계를 넘는다
%% ===================================================================
fprintf('\n[3] 보정 전 각도 (접기까지만, 한계는 아직 걸지 않음)\n');
[TL0, dL0] = az_fold(ue(1), ue(2));
[TR0, dR0] = az_fold(ue(3), ue(4));
fprintf('    좌현 (Fx, Fy) = (%7.3f, %7.3f)  T = %8.3f N  delta = %8.4f deg  %s\n', ...
        ue(1), ue(2), TL0, dL0*180/pi, pass(abs(dL0) <= d_max + 1e-9));
fprintf('    우현 (Fx, Fy) = (%7.3f, %7.3f)  T = %8.3f N  delta = %8.4f deg  %s\n', ...
        ue(3), ue(4), TR0, dR0*180/pi, pass(abs(dR0) <= d_max + 1e-9));

E.step3 = struct('TL',TL0,'dL_deg',dL0*180/pi,'TR',TR0,'dR_deg',dR0*180/pi);

%% ===================================================================
%  4 걸음 — 보정하지 않고 각도만 깎으면 얼마를 못 내는가
%% ===================================================================
fprintf('\n[4] 보정 없이 각도만 깎았을 때 (alloc = 1)\n');
[TL1, dL1] = az_polar(ue(1), ue(2), d_max, F_max);
[TR1, dR1] = az_polar(ue(3), ue(4), d_max, F_max);
w1 = wrench(TL1, dL1, TR1, dR1, bb, LL);
e1 = w1 - tau;

fprintf('    우현 delta 가 %8.4f -> %8.4f deg 로 잘린다 (추력은 그대로 %8.4f N)\n', ...
        dR0*180/pi, dR1*180/pi, TR1);
fprintf('    잘린 뒤 실제 성분  좌현 (%8.4f, %8.4f)  우현 (%8.4f, %8.4f)\n', ...
        TL1*cos(dL1), TL1*sin(dL1), TR1*cos(dR1), TR1*sin(dR1));
fprintf('    실제 렌치  tau_a = [%9.4f %9.4f %9.4f]\n', w1);
fprintf('    요구 렌치  tau_c = [%9.4f %9.4f %9.4f]\n', tau);
fprintf('    못 낸 힘   e     = [%9.4f %9.4f %9.4f]   |e| = %.4f\n', e1, norm(e1));

E.step4 = struct('TL',TL1,'dL_deg',dL1*180/pi,'TR',TR1,'dR_deg',dR1*180/pi, ...
                 'tau_a',w1,'err',e1,'err_norm',norm(e1));

%% ===================================================================
%  5 걸음 — 허용 구간을 1 차 부등식으로 푼다
%  -------------------------------------------------------------------
%    보정 뒤  FyL = 50 + lam,  FyR = 50 - lam   (Fx 는 건드리지 않는다)
%    좌현  |50 + lam| <= 1*|225|   ->  -275 <= lam <= 175
%    우현  |50 - lam| <= 1*| 25|   ->    25 <= lam <=  75
%    교집합 [25, 75]  ->  0 에 가장 가까운 값은 lam* = 25
%% ===================================================================
fprintf('\n[5] 허용 구간과 보정량\n');
loL = -td*abs(ue(1)) - ue(2);   hiL =  td*abs(ue(1)) - ue(2);
loR =  ue(4) - td*abs(ue(3));   hiR =  ue(4) + td*abs(ue(3));
lo  = max(loL, loR);            hi  = min(hiL, hiR);

fprintf('    좌현 구간  [%9.4f, %9.4f]   (|Fx_L| = %g 이라 넉넉함)\n', loL, hiL, abs(ue(1)));
fprintf('    우현 구간  [%9.4f, %9.4f]   (|Fx_R| = %g 이라 빡빡함)\n', loR, hiR, abs(ue(3)));
fprintf('    교집합     [%9.4f, %9.4f]\n', lo, hi);

if lo <= hi
    lamn = min(max(0, lo), hi);
    how  = '구간 안에서 0 에 가장 가까운 값';
else
    lamn = (lo + hi)/2;
    how  = '구간이 비어 가운데를 고름';
end
fprintf('    보정량     lam* = %g            (%s)\n', lamn, how);

E.step5 = struct('loL',loL,'hiL',hiL,'loR',loR,'hiR',hiR, ...
                 'lo',lo,'hi',hi,'lam_star',lamn);

%% ===================================================================
%  6 걸음 — 보정해를 다시 본다
%% ===================================================================
fprintf('\n[6] 보정 후 (alloc = 2)\n');
uec = ue + lamn*nz;
[TL2, dL2] = az_polar(uec(1), uec(2), d_max, F_max);
[TR2, dR2] = az_polar(uec(3), uec(4), d_max, F_max);
w2 = wrench(TL2, dL2, TR2, dR2, bb, LL);
e2 = w2 - tau;

fprintf('    ue* = ue + %g*nz = [%g %g %g %g]   |ue*| = %.4f\n', lamn, uec, norm(uec));
fprintf('    좌현 T = %8.4f N  delta = %8.4f deg  %s\n', ...
        TL2, dL2*180/pi, pass(abs(dL2) <= d_max + 1e-9));
fprintf('    우현 T = %8.4f N  delta = %8.4f deg  %s\n', ...
        TR2, dR2*180/pi, pass(abs(dR2) <= d_max + 1e-9));
fprintf('    실제 렌치  tau_a = [%9.4f %9.4f %9.4f]\n', w2);
fprintf('    못 낸 힘   e     = [%9.4f %9.4f %9.4f]   |e| = %.4e\n', e2, norm(e2));
fprintf('    노름       %.4f -> %.4f  (+%.2f %%)  <- 보정은 노름을 늘린다\n', ...
        norm(ue), norm(uec), 100*(norm(uec)/norm(ue) - 1));

E.step6 = struct('lam_star',lamn,'ue_corr',uec,'nrm_corr',norm(uec), ...
                 'TL',TL2,'dL_deg',dL2*180/pi,'TR',TR2,'dR_deg',dR2*180/pi, ...
                 'tau_a',w2,'err',e2,'err_norm',norm(e2));

%% ===================================================================
%  7 걸음 — 비교표
%% ===================================================================
fprintf('\n[7] 보정 전후 비교\n');
fprintf('    %-22s %14s %14s\n', '항목', '보정 없음', 'null space 보정');
fprintf('    %-22s %14s %14s\n', '----', '---------', '---------------');
fprintf('    %-20s %14.4f %14.4f\n', 'T_L            [N]',  TL1, TL2);
fprintf('    %-20s %14.4f %14.4f\n', 'T_R            [N]',  TR1, TR2);
fprintf('    %-18s %14.4f %14.4f\n', 'delta_L      [deg]',  dL1*180/pi, dL2*180/pi);
fprintf('    %-18s %14.4f %14.4f\n', 'delta_R      [deg]',  dR1*180/pi, dR2*180/pi);
fprintf('    %-20s %14.4f %14.4f\n', 'X_a            [N]',  w1(1), w2(1));
fprintf('    %-20s %14.4f %14.4f\n', 'Y_a            [N]',  w1(2), w2(2));
fprintf('    %-18s %14.4f %14.4f\n', 'N_a         [N m]',   w1(3), w2(3));
fprintf('    %-20s %14.4f %14.4e\n', '|e| 못 낸 힘      ',  norm(e1), norm(e2));
fprintf('    %-20s %14.4f %14.4f\n', '|ue|           [N]',  norm(ue), norm(uec));

%% ===================================================================
%  8 걸음 — 실제 WAM-V 기하로도 같은 일이 일어나는가
%% ===================================================================
fprintf('\n[8] 같은 요구를 실제 기하로 (b = 1.027135 m, L = 2.373776 m)\n');
b2 = 1.027135;  L2 = 2.373776;
Br = [ 1   0   1   0
       0   1   0   1
      b2 -L2 -b2 -L2];
uer = Br'*((Br*Br')\tau);
[~, dLr] = az_fold(uer(1), uer(2));
[~, dRr] = az_fold(uer(3), uer(4));
lor = max(-td*abs(uer(1)) - uer(2),  uer(4) - td*abs(uer(3)));
hir = min( td*abs(uer(1)) - uer(2),  uer(4) + td*abs(uer(3)));
lmr = min(max(0, lor), hir);
uerc = uer + lmr*nz;
[~, dLrc] = az_fold(uerc(1), uerc(2));
[~, dRrc] = az_fold(uerc(3), uerc(4));

fprintf('    ue  = [%9.4f %9.4f %9.4f %9.4f]\n', uer);
fprintf('    보정 전  delta_L = %8.4f deg   delta_R = %8.4f deg  %s\n', ...
        dLr*180/pi, dRr*180/pi, pass(abs(dRr) <= d_max + 1e-9));
fprintf('    허용 구간 [%8.4f, %8.4f]  ->  lam* = %.4f\n', lor, hir, lmr);
fprintf('    보정 후  delta_L = %8.4f deg   delta_R = %8.4f deg  %s\n', ...
        dLrc*180/pi, dRrc*180/pi, pass(abs(dRrc) <= d_max + 1e-9));
fprintf('    검산 B*ue* = [%.4f %.4f %.4f]\n', Br*uerc);

E.real = struct('b',b2,'L',L2,'ue',uer,'dL_deg',dLr*180/pi,'dR_deg',dRr*180/pi, ...
                'lo',lor,'hi',hir,'lam_star',lmr,'ue_corr',uerc, ...
                'dL_corr_deg',dLrc*180/pi,'dR_corr_deg',dRrc*180/pi);

%% ===================================================================
%  검산 — 틀리면 여기서 멈춘다
%% ===================================================================
assert(norm(B*nz) < 1e-12,              'null space 벡터가 틀렸다');
assert(norm(B*ue  - tau) < 1e-10,       '최소 노름 해가 요구를 못 낸다');
assert(norm(B*uec - tau) < 1e-10,       '보정이 요구를 바꾸었다');
assert(abs(dR0) > d_max + 1e-6,         '보정 전 우현 각도가 한계를 넘지 않는다');
assert(norm(e1) > 1,                    '보정 없이도 요구가 그대로 나왔다');
assert(norm(e2) < 1e-9,                 '보정 뒤에도 요구를 못 냈다');
assert(norm(uec) >= norm(ue) - 1e-9,    '보정이 노름을 줄였다 — 있을 수 없다');
assert(abs(dL2) <= d_max + 1e-9 && abs(dR2) <= d_max + 1e-9, ...
                                        '보정 뒤에도 각도가 한계 밖이다');
assert(abs(dRrc) <= d_max + 1e-9,       '실제 기하에서 보정이 듣지 않는다');
fprintf('\n  검산 아홉 항목 모두 통과\n\n');
end

% ---------------------------------------------------------------------
function [T, dd] = az_fold(Fx, Fy)
%AZ_FOLD  성분 -> (크기, 각도). **접기까지만** 하고 한계는 걸지 않는다
T  = hypot(Fx, Fy);
dd = atan2(Fy, Fx);
if abs(dd) > pi/2
    dd = dd - sign(dd)*pi;
    T  = -T;
end
end

% ---------------------------------------------------------------------
function [T, dd] = az_polar(Fx, Fy, d_max, F_max)
%AZ_POLAR  배분기의 az_polar 과 같은 규칙 (rev = 1 — 반전 허용)
[T, dd] = az_fold(Fx, Fy);
dd = max(-d_max, min(d_max, dd));     % (c) 각도 한계 — 추력은 건드리지 않는다
T  = max(-F_max, min(F_max, T));      % (d) 추력 한계
end

% ---------------------------------------------------------------------
function w = wrench(T_L, d_L, T_R, d_R, bb, LL)
%WRENCH  추진기 지령 -> 실제로 나는 렌치. 같은 B 를 **바로** 쓴다
Bm = [ 1   0   1   0
       0   1   0   1
      bb -LL -bb -LL];
w  = Bm * [T_L*cos(d_L); T_L*sin(d_L); T_R*cos(d_R); T_R*sin(d_R)];
end

% ---------------------------------------------------------------------
function s = pass(ok)
if ok
    s = '(한계 안)';
else
    s = '<- 한계 밖';
end
end
