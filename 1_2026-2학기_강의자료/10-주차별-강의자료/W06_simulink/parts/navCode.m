function code = navCode()
% NAVCODE  VRX 판의 PoseSubscriber 안 Nav 함수 본문 (6단과 VRX 쌍둥이 전부가 쓴다)
%  Gazebo 의 odometry(ENU) 를 해양제어의 항법량(NED) 으로 바꾼다.
%  출력 순서는 addMotionModel 의 States 와 **같다** — 그래야 wireNavGotos 가
%  같은 태그 아홉 개를 내고, 로깅·그림·스코프가 5단과 똑같이 읽는다.
code = strjoin({
  'function [x_n, y_n, psi, u, v, r, beta, chi, U] = Nav(ex, ey, qx, qy, qz, qw, bx, by, wz, org_x, org_y)'
  '%#codegen'
  '%  Gazebo/ROS 는 ENU 에 선체축 x 앞 · y 좌현 · z 위.'
  '%  해양제어는 NED 에 선체축 x 앞 · y 우현 · z 아래.'
  '%'
  '%    위치   : 북 = y_ENU,  동 = x_ENU   (스폰 원점을 뺀다)'
  '%    선수각 : psi = pi/2 - yaw_ENU'
  '%    선체속도: u = bx,  v = -by,  r = -wz   (y·z 부호가 바뀐다)'
  ''
  '%  첫 메시지가 오기 전 Subscribe 는 0 으로 채운 버스를 낸다. 그대로 쓰면'
  '%  위치가 스폰 원점만큼(약 568 m) 튀어 로그 첫 점이 망가진다.'
  'if ex == 0 && ey == 0'
  '    x_n = 0; y_n = 0; psi = 0; u = 0; v = 0; r = 0; beta = 0; chi = 0; U = 0;'
  '    return'
  'end'
  'x_n = ey - org_x;    % north, 스폰 기준 상대좌표'
  'y_n = ex - org_y;    % east'
  ''
  'yaw_enu = atan2(2*(qw*qz + qx*qy), 1 - 2*(qy*qy + qz*qz));'
  'p   = pi/2 - yaw_enu;'
  'psi = atan2(sin(p), cos(p));'
  ''
  'u = bx;'
  'v = -by;'
  'r = -wz;'
  ''
  'U    = sqrt(u*u + v*v);'
  'beta = atan2(v, u);          % 크랩각'
  'c    = psi + beta;'
  'chi  = atan2(sin(c), cos(c));'
  }, newline);
end
