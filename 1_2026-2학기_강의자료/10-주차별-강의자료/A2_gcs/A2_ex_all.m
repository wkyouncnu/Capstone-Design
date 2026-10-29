function A2_ex_all()
%A2_EX_ALL  예제 1~7 을 차례로 실행한다
%
%   입력 : 없음
%   출력 : 화면 출력만
%
%   >> A2_ex_all
%
%   처음에는 하나씩 눌러 보는 쪽을 권한다. 각 예제의 머리말에 입력과 출력이 적혀 있다
%
%     >> help A2_ex4_curvature
%     >> A2_ex4_curvature
%
%   예제 목록
%     1  A2_ex1_wgs84              WGS84 타원체의 모양
%     2  A2_ex2_lla2ecef           위경고 -> ECEF
%     3  A2_ex3_latitude           측지위도와 지심위도
%     4  A2_ex4_curvature          곡률반경과 1 도의 길이
%     5  A2_ex5_flat_formula       'flat' 내부 식
%     6  A2_ex6_ellipsoid_formula  'ellipsoid' 내부 식
%     7  A2_ex7_roundtrip          왕복 변환

    list = {@A2_ex1_wgs84, @A2_ex2_lla2ecef, @A2_ex3_latitude, ...
            @A2_ex4_curvature, @A2_ex5_flat_formula, ...
            @A2_ex6_ellipsoid_formula, @A2_ex7_roundtrip};

    for k = 1:numel(list)
        fprintf('\n\n--------------------------------------------------------\n');
        list{k}();
    end

    fprintf('\n\n예제 1~7 을 모두 실행했다.\n');
end
