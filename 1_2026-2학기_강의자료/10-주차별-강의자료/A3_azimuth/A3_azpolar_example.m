function E = A3_azpolar_example()
%A3_AZPOLAR_EXAMPLE  az_polar 네 규칙 — 다섯 가지 요구를 한 줄씩 따라간다
%
%   >> A3_azpolar_example          % 표만 출력
%   >> E = A3_azpolar_example;     % 숫자를 구조체로 받음
%
%   목적
%     parts/azAllocFcn.m 안의 지역 함수 az_polar 가 성분 둘 (Fx, Fy) 을
%     추진기 지령 둘 (T, delta) 로 바꾸는 과정을 **한 줄 실행할 때마다**
%     찍어 본다. 문서 1-10 절의 추적표와 이 출력은 한 자리까지 같다.
%
%   네 규칙
%     (a) +-90 도 접기      요구를 바꾸지 않는다  (같은 힘의 다른 표기)
%     (b) 역추력 되돌리기   각도를 쐐기 밖으로 밀어낸다
%     (c) 각도 한계         **말없이 요구를 깎는다**
%     (d) 추력 한계         **말없이 요구를 깎는다**
%
%   이 파일은 물리를 다시 구현한 것이 아니다 — 지역 함수 한 개의 추적기다
%   (같은 꼴의 선례: A3_pinv_example.m, A3_nullspace_example.m)

E = struct();

F_max = 500;            % 추력 한계 [N]
d_max = 45*pi/180;      % 방향각 한계 [rad]

C = { ...
  'a  앞쪽 . 쐐기 안',    200, 100, 1
  'b  뒤쪽 요구 (접기)', -150,  80, 1
  'c  rev=0 되돌리기',   -150,  80, 0
  'd  각도 잘림',           25,  50, 1
  'e  추력 잘림',          600,   0, 1 };

fprintf('\n');
fprintf('===========================================================================\n');
fprintf('  az_polar 추적  (Fmax = %g N, dmax = %g deg)\n', F_max, d_max*180/pi);
fprintf('===========================================================================\n');

for k = 1:size(C,1)
    nm = C{k,1};  Fx = C{k,2};  Fy = C{k,3};  rv = C{k,4};
    fprintf('\n--- %s  :  (Fx, Fy) = (%g, %g) N,  rev = %d\n', nm, Fx, Fy, rv);
    S = trace_polar(Fx, Fy, F_max, d_max, rv);

    fprintf('    %-26s T = %9.4f N   delta = %10.4f deg\n', '1 극좌표 변환', S.T1, S.d1*180/pi);
    fprintf('    %-26s T = %9.4f N   delta = %10.4f deg   %s\n', '2 +-90 접기',  S.T2, S.d2*180/pi, S.m2);
    fprintf('    %-26s T = %9.4f N   delta = %10.4f deg   %s\n', '3 역추력 되돌리기', S.T3, S.d3*180/pi, S.m3);
    fprintf('    %-26s T = %9.4f N   delta = %10.4f deg   %s\n', '4 각도 한계',  S.T4, S.d4*180/pi, S.m4);
    fprintf('    %-26s T = %9.4f N   delta = %10.4f deg   %s\n', '5 추력 한계',  S.T5, S.d5*180/pi, S.m5);
    fprintf('    실제 나는 힘  (%9.4f, %9.4f) N      요구 (%g, %g) N\n', ...
            S.Fa(1), S.Fa(2), Fx, Fy);
    fprintf('    못 낸 힘      (%9.4f, %9.4f) N      |e| = %.4f N  %s\n', ...
            S.e(1), S.e(2), norm(S.e), verdict(norm(S.e)));

    E.(sprintf('case%d',k)) = S;
    E.(sprintf('case%d',k)).name = nm;
    E.(sprintf('case%d',k)).req  = [Fx; Fy];
end

%% ===================================================================
%  요약표 — 문서에 그대로 들어간다
%% ===================================================================
fprintf('\n');
fprintf('[요약] 어느 규칙이 요구를 깎았는가\n');
fprintf('  %-20s %8s %8s %10s %10s %9s %s\n', ...
        '경우', 'Fx', 'Fy', 'T [N]', 'delta[deg]', '|e| [N]', '발동한 규칙');
fprintf('  %-20s %8s %8s %10s %10s %9s %s\n', ...
        '----', '--', '--', '-----', '----------', '-------', '-----------');
for k = 1:size(C,1)
    S = E.(sprintf('case%d',k));
    fprintf('  %-18s %8g %8g %10.4f %10.4f %9.4f %s\n', ...
            S.name, S.req(1), S.req(2), S.T5, S.d5*180/pi, norm(S.e), S.fired);
end

%% ===================================================================
%  sign(0) 가드 — (d==0) 이 왜 있는가
%% ===================================================================
fprintf('\n[가드] rev=0 되돌리기에서 sign(d + (d==0)) 의 (d==0) 를 빼면\n');
d0 = 0;
fprintf('    delta = 0 일 때  sign(d)        = %g   ->  delta 가 %g deg 로 그대로. T 만 뒤집혀 힘의 방향이 반대가 된다\n', ...
        sign(d0), (d0 + sign(d0)*pi)*180/pi);
fprintf('    가드가 있으면    sign(d+(d==0)) = %g   ->  delta 가 %g deg 로 가서 (c) 가 %g deg 로 깎는다\n', ...
        sign(d0 + (d0==0)), (d0 + sign(d0 + (d0==0))*pi)*180/pi, d_max*180/pi);

%% ===================================================================
%  검산 — 틀리면 여기서 멈춘다
%% ===================================================================
assert(abs(E.case1.T5 - hypot(200,100)) < 1e-9,  'a: 바뀌지 않아야 한다');
assert(norm(E.case1.e) < 1e-9,                   'a: 요구를 그대로 내야 한다');
assert(abs(E.case2.T5 + 170) < 1e-9,             'b: 접기 뒤 T = -170 이어야 한다');
assert(norm(E.case2.e) < 1e-9,                   'b: 접기는 요구를 바꾸지 않는다');
assert(E.case3.T5 > 0,                           'c: rev=0 이면 추력이 양수여야 한다');
assert(norm(E.case3.e) > 100,                    'c: 되돌리기는 큰 오차를 남긴다');
assert(abs(E.case4.d5 - d_max) < 1e-12,          'd: 각도가 한계에 붙어야 한다');
assert(norm(E.case4.e) > 1,                      'd: 각도 잘림은 요구를 깎는다');
assert(abs(E.case5.T5 - F_max) < 1e-12,          'e: 추력이 한계에 붙어야 한다');
assert(abs(norm(E.case5.e) - 100) < 1e-9,        'e: 못 낸 힘이 100 N 이어야 한다');
fprintf('\n  검산 열 항목 모두 통과\n\n');
end

% ---------------------------------------------------------------------
function S = trace_polar(Fx, Fy, F_max, d_max, rev)
%TRACE_POLAR  az_polar 과 같은 줄 순서. 줄마다 (T, delta) 를 남긴다
S = struct();
fired = {};

% 1 극좌표 변환
T = hypot(Fx, Fy);
d = atan2(Fy, Fx);
S.T1 = T;  S.d1 = d;

% 2 +-90 접기 — 같은 힘의 다른 표기. 요구를 바꾸지 않는다
if abs(d) > pi/2
    d = d - sign(d)*pi;
    T = -T;
    S.m2 = '<- (a) 접힘';   fired{end+1} = '(a)';
else
    S.m2 = '';
end
S.T2 = T;  S.d2 = d;

% 3 역추력 금지면 되돌린다 — 각도를 쐐기 밖으로 밀어낸다
if rev < 0.5 && T < 0
    T = -T;
    d = d + sign(d + (d==0))*pi;
    if d >  pi, d = d - 2*pi; end
    if d < -pi, d = d + 2*pi; end
    S.m3 = '<- (b) 되돌림';  fired{end+1} = '(b)';
else
    S.m3 = '';
end
S.T3 = T;  S.d3 = d;

% 4 각도 한계 — 말없이 요구를 깎는다
dc = max(-d_max, min(d_max, d));
if abs(dc - d) > 1e-12
    S.m4 = '<- (c) 깎임 . 요구가 줄었다';  fired{end+1} = '(c)';
else
    S.m4 = '';
end
d = dc;
S.T4 = T;  S.d4 = d;

% 5 추력 한계 — 말없이 요구를 깎는다
Tc = max(-F_max, min(F_max, T));
if abs(Tc - T) > 1e-12
    S.m5 = '<- (d) 깎임 . 요구가 줄었다';  fired{end+1} = '(d)';
else
    S.m5 = '';
end
T = Tc;
S.T5 = T;  S.d5 = d;

% 실제로 나는 힘과 못 낸 힘
S.Fa = [T*cos(d); T*sin(d)];
S.e  = S.Fa - [Fx; Fy];

if isempty(fired)
    S.fired = '없음 (그대로 통과)';
else
    S.fired = strjoin(fired, ' ');
end
end

% ---------------------------------------------------------------------
function s = verdict(en)
if en < 1e-9
    s = '(요구 그대로)';
else
    s = '<- 요구가 깎였다';
end
end
