#!/usr/bin/env bash
# shoot_bow.sh — 선수추진기 그림을 화면 없이(headless) 찍는다 (6주차 2-5)
#
#   bash shoot_bow.sh                 # ~/w06_shots 에 PNG 3장
#   bash shoot_bow.sh ~/내그림폴더     # 저장 폴더를 직접 주기
#
#   찍는 세 장
#     w06_bow_close.png    선수추진기 근접 — 뱃머리 아래에 가로로 달린 통
#     w06_three.png        세 추진기가 한 장에 — 좌현 앞쪽 위에서
#     w06_stern_pair.png   선미 좌·우 추진기 — 뒤에서
#
#   왜 GUI 스크린샷이 아닌가
#     Gazebo 의 Screenshot 단추·`/gui/screenshot` 서비스는 WSLg 에서 `data: true` 를
#     돌려주고도 파일을 만들지 않음 (플러그인이 MinimalScene 의 카메라를 못 찾음).
#     그래서 시뮬레이터 안에 사진기 모델(photo_cam.sdf)을 띄워 그 그림을 저장함.
#     화면이 없어도 되므로 후진 노트북에서도 그림을 얻을 수 있음.
#
#   VRX 가 이미 떠 있으면 그대로 쓰고, 안 떠 있으면 이 스크립트가 headless 로 띄웠다 끔.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HOME/w06_shots}"
WORLD="${WORLD:-sydney_regatta}"
mkdir -p "$OUT"

source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash

LAUNCHED=0
if ! ros2 topic list 2>/dev/null | grep -q '/wamv/thrusters/bow/thrust'; then
  echo "VRX 가 안 떠 있음 → headless 로 띄움"
  bash "$HERE/run_vrx_bow.sh" headless > "$OUT/vrx_launch.log" 2>&1 &
  LPID=$!
  LAUNCHED=1
  for i in $(seq 1 90); do
    ros2 topic list 2>/dev/null | grep -q '/wamv/thrusters/bow/thrust' && break
    sleep 2
  done
  sleep 10          # 배가 물에 안착할 시간
fi

cleanup() {
  kill $BPID 2>/dev/null
  [ "$LAUNCHED" = 1 ] && { kill -INT $LPID 2>/dev/null; sleep 3; pkill -f 'gz sim' 2>/dev/null; }
  return 0
}
trap cleanup EXIT

# 사진기를 장면에 띄운다. 자리는 아래 python 이 배 위치를 읽어 다시 잡는다
ros2 run ros_gz_sim create -world "$WORLD" -file "$HERE/photo_cam.sdf" \
     -name photo_cam -allow_renaming false -x -532 -y 190 -z 2 > /dev/null 2>&1
sleep 3

# Gazebo 의 그림 토픽을 ROS 쪽으로 넘긴다
ros2 run ros_gz_image image_bridge /photo/image > /dev/null 2>&1 &
BPID=$!
sleep 4

python3 - "$OUT" "$WORLD" <<'PY'
import math, os, struct, subprocess, sys, time, zlib
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
from nav_msgs.msg import Odometry

OUT   = sys.argv[1]
WORLD = sys.argv[2]
ODOM  = '/wamv/sensors/position/ground_truth_odometry'

#  (사진기 자리, 바라볼 점) — 둘 다 선체 고정 좌표. x 앞, y 좌현, z 위 [m]
SHOTS = [
    ('w06_bow_close',  ( 3.4,  1.5, 0.9), ( 0.75, 0.0, 0.25), '선수추진기 근접'),
    ('w06_three',      (-2.0,  7.5, 3.2), (-0.60, 0.0, 0.30), '세 추진기'),
    ('w06_stern_pair', (-6.5,  0.0, 1.3), (-2.40, 0.0, 0.10), '선미 좌·우 추진기'),
]

def write_png(path, w, h, rgb):
    raw = b''.join(b'\x00' + rgb[y*w*3:(y+1)*w*3] for y in range(h))
    def chunk(tag, data):
        body = tag + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)
    head = struct.pack('>2I5B', w, h, 8, 2, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\x0a' + chunk(b'IHDR', head)
                + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))

def quat(roll, pitch, yaw):
    cr, sr = math.cos(roll/2),  math.sin(roll/2)
    cp, sp = math.cos(pitch/2), math.sin(pitch/2)
    cy, sy = math.cos(yaw/2),   math.sin(yaw/2)
    return (sr*cp*cy - cr*sp*sy, cr*sp*cy + sr*cp*sy,
            cr*cp*sy - sr*sp*cy, cr*cp*cy + sr*sp*sy)      # x y z w

def set_pose(name, p, rpy):
    q = quat(*rpy)
    req = ('name: "%s", position: {x: %.3f, y: %.3f, z: %.3f}, '
           'orientation: {x: %.6f, y: %.6f, z: %.6f, w: %.6f}'
           % (name, p[0], p[1], p[2], q[0], q[1], q[2], q[3]))
    subprocess.run(['gz', 'service', '-s', '/world/%s/set_pose' % WORLD,
                    '--reqtype', 'gz.msgs.Pose', '--reptype', 'gz.msgs.Boolean',
                    '--timeout', '3000', '--req', req],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

class Shooter(Node):
    def __init__(self):
        super().__init__('shoot_bow')
        self.img = None
        self.odom = None
        self.create_subscription(Image, '/photo/image', self.on_img, 1)
        self.create_subscription(Odometry, ODOM, self.on_odom, 1)
    def on_img(self, m):
        self.img = m
    def on_odom(self, m):
        self.odom = m
    def wait(self, what, secs):
        t0 = time.time()
        while getattr(self, what) is None and time.time() - t0 < secs:
            rclpy.spin_once(self, timeout_sec=0.1)
        return getattr(self, what) is not None
    def fresh(self, secs=6.0):
        self.img = None
        return self.wait('img', secs)

rclpy.init()
nd = Shooter()

if not nd.wait('odom', 15.0):
    print('%s 가 오지 않음 — VRX 가 떠 있는지 확인' % ODOM)
    raise SystemExit(1)
if not nd.wait('img', 20.0):
    print('/photo/image 가 오지 않음 — photo_cam 이 떴는지, image_bridge 가 살아 있는지 확인')
    raise SystemExit(1)

o = nd.odom.pose.pose
bx, by = o.position.x, o.position.y
qq = o.orientation
yaw = math.atan2(2.0*(qq.w*qq.z + qq.x*qq.y), 1.0 - 2.0*(qq.y*qq.y + qq.z*qq.z))
c, s = math.cos(yaw), math.sin(yaw)
print('배 위치   : ENU x=%8.3f  y=%8.3f   yaw=%7.2f deg' % (bx, by, math.degrees(yaw)))

def to_enu(off):
    return (bx + c*off[0] - s*off[1], by + s*off[0] + c*off[1], off[2])

for name, cam_b, tgt_b, label in SHOTS:
    cam = to_enu(cam_b)
    tgt = to_enu(tgt_b)
    dx, dy, dz = tgt[0]-cam[0], tgt[1]-cam[1], tgt[2]-cam[2]
    cam_yaw   = math.atan2(dy, dx)
    cam_pitch = -math.atan2(dz, math.hypot(dx, dy))      # Gazebo 는 아래로 볼 때 pitch 가 +
    set_pose('photo_cam', cam, (0.0, cam_pitch, cam_yaw))
    time.sleep(2.0)
    if not nd.fresh(8.0):
        print('%-16s 그림이 오지 않음' % name)
        continue
    m = nd.img
    buf = bytes(m.data)
    if m.encoding == 'bgr8':
        ba = bytearray(buf)
        ba[0::3], ba[2::3] = buf[2::3], buf[0::3]
        buf = bytes(ba)
    path = os.path.join(OUT, name + '.png')
    write_png(path, m.width, m.height, buf)
    print('%-16s %4dx%-4d  %-22s -> %s' % (name, m.width, m.height, label, path))

nd.destroy_node()
rclpy.shutdown()
PY

echo "저장 폴더 : $OUT"
ls -l "$OUT"/*.png 2>/dev/null
