function T = W08_segments(crab)
% W08_SEGMENTS  8주차 C-2 — 도는 도중에 방향·속도·반경을 바꾸는 시나리오를 구간별로 잰다.
%
%   >> T = W08_segments        % 크랩 보상 켬 (C-2 표와 같은 조건)
%   >> T = W08_segments(0)     % 크랩 보상 끔
%
%   W08_setup 을 불러 기본값을 올린 뒤 이 함수 안에서만
%     use_schedule = 1, required_turns = 0, crab_comp = crab, 600 s
%   로 바꿔 W08_0_offline 을 한 번 돌린다 (VRX 불필요, 몇 초).
%
%   구간마다 **앞 30 초는 뺀다** — 방향·속도·반경이 막 바뀐 과도 구간이라서.
%     평균 반경  중심까지 거리 r 의 평균 [m]
%     평균 u     전후 속도 평균 [m/s]
%     방향       중심에서 본 방위 theta 가 늘면 시계방향 (NED: 북에서 시계 +)
%   끝나면 W08_setup 을 다시 불러 기본값으로 돌아간다.

if nargin < 1, crab = 1; end
here = fileparts(mfilename('fullpath'));  cd(here);
setappdata(0, 'W08_skip_run', true);
evalc('evalin(''base'', ''W08_setup'')');
assignin('base','use_schedule', 1);
assignin('base','required_turns', 0);
assignin('base','crab_comp', crab);
assignin('base','animate', 0);
c = onCleanup(@() restore());

load_system('W08_0_offline');
evalc('out = sim(''W08_0_offline'', ''StopTime'', ''600'');');

t  = out.log_x_n.Time;
xn = out.log_x_n.Data(:);  yn = out.log_y_n.Data(:);
u  = out.log_u.Data(:);    rr = out.log_r_dist.Data(:);
xc = evalin('base','center_north');  yc = evalin('base','center_east');
th = unwrap(atan2(yn - yc, xn - xc));

edges = [0 150 300 450 600];
name  = {'1) 기본'; '2) 방향 반전'; '3) 속도 1.6배'; '4) 반경 0.6배'};
R = zeros(4,1);  U = zeros(4,1);  D = strings(4,1);
for k = 1:4
    sel = t >= edges(k) + 30 & t < edges(k+1);
    R(k) = mean(rr(sel));
    U(k) = mean(u(sel));
    if mean(diff(th(sel))) > 0, D(k) = "시계방향"; else, D(k) = "반시계방향"; end
end
T = table(name, R, U, D, 'VariableNames', {'구간','평균반경_m','평균u_mps','회전방향'});
fprintf('\nW08 도중 변경 시나리오 (crab_comp = %d, 600 s, 구간마다 앞 30 s 제외)\n', crab);
disp(T);
end

function restore()
setappdata(0, 'W08_skip_run', true);
evalc('evalin(''base'', ''W08_setup'')');
end
