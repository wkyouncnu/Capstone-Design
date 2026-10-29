function A2_ex7_roundtrip(lla)
%A2_EX7_ROUNDTRIP  예제 7 — 위경고 -> NED -> 위경고 로 되돌아오는가
%
%   입력 : lla  Nx3  [위도 경도 고도]  — 생략하면 기준점 둘레의 다섯 점을 쓴다
%   출력 : 화면 출력만 (왕복한 뒤의 좌표와, 처음 값과의 차)
%
%   >> A2_ex7_roundtrip
%   >> A2_ex7_roundtrip([36.3800 127.4000 25])
%
%   무엇을 보는가
%     lla2ned 와 ned2lla 가 **서로의 역함수인가**를 숫자로 확인한다.
%     GCS 는 매 주기마다 이 왕복을 한다 — 클릭한 점을 NED 로 내리고,
%     배의 NED 위치를 다시 위경도로 올려 지도에 찍는다
%
%   왕복 오차가 0 에 가까워야 하는 이유
%     ned2llaFlat 은 lla2nedFlat 과 **정확히 같은 R_N, R_M** 을 쓰고 나눗셈을
%     곱셈으로 바꾼 것뿐이다. 그래서 'flat' 왕복은 부동소수점 한계까지 맞는다
%
%   주의
%     이 왕복이 0 이라는 것은 "변환이 서로 일관된다" 는 뜻이지
%     "평면 가정이 정확하다" 는 뜻이 아니다. 그 확인은 예제 5·6 과 1단에서 한다

    if nargin < 1
        lla0 = A2_ex_lla0();
        lla = [lla0(1)+0.0005, lla0(2)+0.0005,   0
               lla0(1)+0.0020, lla0(2)-0.0015,   5
               lla0(1)-0.0030, lla0(2)+0.0040, -10
               lla0(1)+0.0100, lla0(2)+0.0100,   0
               lla0(1)+0.1000, lla0(2)+0.1000,   0];
    end
    lla0 = A2_ex_lla0();

    fprintf('\n=== 예제 7 · 왕복 변환 ===\n');
    fprintf('\n[입력]  기준점 lla0 = [%.7f  %.7f  %.1f]\n', lla0);

    for method = {'flat', 'ellipsoid'}
        m = method{1};

        ned  = lla2ned(lla, lla0, m);          % 내려가기
        back = ned2lla(ned, lla0, m);          % 다시 올라오기

        fprintf('\n[출력]  method = ''%s''\n', m);
        fprintf('  %4s  %13s %14s %7s  %10s %10s %8s  %11s\n', ...
                '점', '위도[deg]', '경도[deg]', '고도[m]', ...
                'x_n[m]', 'y_n[m]', 'z_n[m]', '왕복오차[m]');
        for k = 1:size(lla,1)
            %  각도 차를 m 로 환산해 "몇 m 틀렸는가" 로 읽는다
            gap = lla2ned(back(k,:), lla(k,:), 'flat');
            fprintf('  %4d  %13.7f %14.7f %7.1f  %10.3f %10.3f %8.3f  %11.3e\n', ...
                    k, back(k,1), back(k,2), back(k,3), ...
                    ned(k,1), ned(k,2), ned(k,3), norm(gap));
        end

        gap_all = zeros(size(lla,1),1);
        for k = 1:size(lla,1)
            gap_all(k) = norm(lla2ned(back(k,:), lla(k,:), 'flat'));
        end
        fprintf('  최대 왕복 오차 = %.3e m\n', max(gap_all));
        fprintf('  각도로는        = %.3e deg\n', max(max(abs(back(:,1:2) - lla(:,1:2)))));
    end

    fprintf('\n[읽는 법]\n');
    fprintf('  - 왕복 오차는 거리와 무관하게 0 에 붙어 있다 (두 함수가 한 쌍이므로)\n');
    fprintf('  - 마지막 점은 기준점에서 10 km 이상 떨어져 있는데도 왕복은 맞는다\n');
    fprintf('  - 즉 왕복 시험만으로는 평면 가정의 오차를 **찾아낼 수 없다**\n');
    fprintf('  - 평면 가정의 오차는 ''flat'' 과 ''ellipsoid'' 를 서로 비교해야 보인다 (1단 [3])\n');

    fprintf('\n[직접 해 볼 것]\n');
    fprintf('  1. 고도를 25 m 로 넣으면 z_n 이 얼마가 되는가 (부호를 확인할 것)\n');
    fprintf('  2. lla2ned 로 내린 뒤 ned2lla 에 **다른 기준점**을 주면 어떻게 되는가\n');

    fprintf('\n=== 예제 7 끝 ===\n');
end
