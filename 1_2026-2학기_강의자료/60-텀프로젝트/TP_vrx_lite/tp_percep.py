#!/usr/bin/env python3
# tp_percep.py — 텀프로젝트 인지 예제 다섯 개가 함께 쓰는 토막
#
#   이 파일만으로는 아무 일도 하지 않는다. see_*.py 가 불러 쓴다.
#   한 군데에 모아 둔 까닭은 미션마다 같은 코드를 베껴 쓰지 않기 위해서다.
#
#   들어 있는 것
#     grab_image()   카메라에서 한 장 받는다 (BGR 배열, 초점거리 fx, 중심 cx·cy 까지)
#     grab_cloud()   라이다에서 한 스캔 받는다 (라이다 좌표계의 N x 3 배열)
#     find_blobs()   정해 둔 색의 덩어리를 찾는다
#     bearing_deg()  화면의 가로 위치 u 를 선수 기준 상대방위[deg] 로 바꾼다
#     draw_blobs()   찾은 덩어리에 네모와 글씨를 얹는다
#     save_png()     파일로 쓴다
#
#   ** 이것은 알고리즘이 아니다 **
#     색 문턱값으로 덩어리를 찾는 수준이다. 경기에서는 물결 반사·역광·물보라가
#     이 문턱값을 그대로 깨뜨린다. 요구조건 문서 4장이 요구하는 것은
#     "부표가 보이는지 확인되는 출발점" 이고, 그 다음(추적·게이트 짝짓기·자세 추정)은
#     팀이 만들어야 하는 부분이다.
#
#   좌표계 세 개를 섞지 않기
#     화면 : u 오른쪽 +, v 아래쪽 +  (픽셀)
#     라이다·선체 : x 선수 +, y 좌현 +, z 위 +  (ROS 관례, 미터)
#     월드 : x 동, y 북  (Gazebo ENU. goto.sh 가 쓰는 숫자가 이것이다)

import math
import sys

import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import Image, CameraInfo, PointCloud2
from sensor_msgs_py import point_cloud2 as pc2
from cv_bridge import CvBridge
import cv2

CAM_IMAGE = '/wamv/sensors/cameras/front_camera_sensor/image_raw'
CAM_INFO = '/wamv/sensors/cameras/front_camera_sensor/camera_info'
LIDAR_POINTS = '/wamv/sensors/lidars/lidar_wamv_sensor/points'

#  가제보 센서는 Best Effort 로 낸다. Reliable 로 구독하면 한 장도 못 받는다.
SENSOR_QOS = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT,
                        history=HistoryPolicy.KEEP_LAST, depth=1)


# ── 색 문턱값 ────────────────────────────────────────────────────────────────
#   OpenCV HSV 는 H 가 0~179 다 (0~359 가 아니다. 반으로 접혀 있다).
#   아래 값은 kaboat_term.sdf 에 넣은 재질색을 가제보가 그려 낸 화면에서 잡은 것이다.
#   빨강은 H 가 0 을 넘나들므로 구간이 둘이다.
COLORS = {
    '빨강': [((0, 90, 60), (10, 255, 255)), ((170, 90, 60), (179, 255, 255))],
    '초록': [((40, 60, 40), (85, 255, 255))],
    '노랑': [((22, 90, 90), (34, 255, 255))],
    '파랑': [((100, 90, 50), (130, 255, 255))],
    '주황': [((11, 120, 120), (21, 255, 255))],
}

#  그릴 때 쓰는 BGR 색 (화면에 얹는 네모 색)
DRAW_BGR = {'빨강': (40, 40, 230), '초록': (60, 200, 60), '노랑': (40, 220, 230),
            '파랑': (230, 120, 40), '주황': (40, 150, 255)}


# ── 받아오기 ─────────────────────────────────────────────────────────────────
class _Once(Node):
    """토픽에서 한 건만 받고 끝내는 노드. 예제마다 새로 쓰지 않게 여기 둔다."""

    def __init__(self, name, specs):
        super().__init__(name)
        self.got = {}
        for key, (msg_type, topic, qos) in specs.items():
            self.create_subscription(
                msg_type, topic,
                lambda m, k=key: self.got.setdefault(k, m), qos)
        self._specs = specs

    def wait(self, timeout=20.0):
        end = self.get_clock().now().nanoseconds + int(timeout * 1e9)
        while len(self.got) < len(self._specs):
            if self.get_clock().now().nanoseconds > end:
                missing = [k for k in self._specs if k not in self.got]
                raise TimeoutError(
                    '%.0f 초 안에 못 받은 것: %s\n'
                    '  확인할 것 : 가제보가 떠 있는지, ROS_DOMAIN_ID 가 같은지,\n'
                    '              일시정지가 풀렸는지 (gz service -s /world/kaboat_term/control ...)'
                    % (timeout, ', '.join(self._specs[k][1] for k in missing)))
            rclpy.spin_once(self, timeout_sec=0.2)
        return self.got


def grab_image(timeout=20.0):
    """카메라 한 장을 받아 (bgr, fx, cx, cy) 로 돌려준다.

    fx 를 숫자로 적어 두지 않고 camera_info 에서 읽는 까닭 :
      make_wamv_term.sh 가 판(lite·ultralite·full)마다 해상도를 바꾼다.
      해상도가 바뀌면 fx 도 바뀐다 (640 -> 381.4, 1280 -> 762.7).
      적어 두면 판을 바꾼 날 상대방위가 조용히 두 배 틀린다.
    """
    own = not rclpy.ok()
    if own:
        rclpy.init()
    node = _Once('tp_grab_image', {
        'img': (Image, CAM_IMAGE, SENSOR_QOS),
        'info': (CameraInfo, CAM_INFO, SENSOR_QOS)})
    try:
        got = node.wait(timeout)
        bgr = CvBridge().imgmsg_to_cv2(got['img'], desired_encoding='bgr8')
        k = got['info'].k
        return bgr, float(k[0]), float(k[2]), float(k[5])
    finally:
        node.destroy_node()
        if own:
            rclpy.shutdown()


def grab_cloud(timeout=20.0):
    """라이다 한 스캔을 라이다 좌표계의 (N, 3) 배열로 돌려준다 (x 선수, y 좌현, z 위)."""
    own = not rclpy.ok()
    if own:
        rclpy.init()
    node = _Once('tp_grab_cloud', {'pc': (PointCloud2, LIDAR_POINTS, SENSOR_QOS)})
    try:
        msg = node.wait(timeout)['pc']
        rec = pc2.read_points(msg, field_names=('x', 'y', 'z'), skip_nans=True)
        xyz = np.stack([rec['x'], rec['y'], rec['z']], axis=-1).astype(np.float64)
        return xyz, msg.header.frame_id
    finally:
        node.destroy_node()
        if own:
            rclpy.shutdown()


# ── 영상 ─────────────────────────────────────────────────────────────────────
def color_mask(bgr, color):
    """정해 둔 색만 흰색으로 남긴 이진 영상."""
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    mask = np.zeros(hsv.shape[:2], np.uint8)
    for lo, hi in COLORS[color]:
        mask |= cv2.inRange(hsv, np.array(lo, np.uint8), np.array(hi, np.uint8))
    #  물결 반사로 생기는 한두 픽셀짜리 점을 지운다 (열림 -> 닫힘)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, k)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k)
    return mask


def find_blobs(bgr, color, min_area=60, top=None):
    """색 덩어리를 큰 것부터 찾아 목록으로 준다.

    돌려주는 것 : [{'색', 'u', 'v', 'x', 'y', 'w', 'h', '면적', '채움률'}, ...]
      u, v  덩어리 중심의 화면 좌표
      채움률 = 면적 / (w*h).  공은 0.785 (= pi/4) 에 가깝고 네모는 1 에 가깝다.
    """
    mask = color_mask(bgr, color)
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    out = []
    for c in cnts:
        a = cv2.contourArea(c)
        if a < min_area:
            continue
        x, y, w, h = cv2.boundingRect(c)
        out.append({'색': color, 'u': x + w / 2.0, 'v': y + h / 2.0,
                    'x': x, 'y': y, 'w': w, 'h': h, '면적': a,
                    '채움률': a / float(w * h), '윤곽': c})
    out.sort(key=lambda b: -b['면적'])
    return out[:top] if top else out


def bearing_deg(u, fx, cx):
    """화면 가로 위치 u 를 선수 기준 상대방위[deg] 로. 오른쪽(우현)이 +."""
    return math.degrees(math.atan2(u - cx, fx))


def shape_of(blob):
    """윤곽을 다각형으로 줄여 삼각형·네모·원을 가른다.

    표식이 삼각형·원형·네모 셋 중 하나라는 것은 임무설명 Ⅲ 의 전제다.
    여기서는 꼭짓점 수와 채움률 둘로 가른다 — 기울어지면 틀린다.
    팀은 이보다 나은 판정을 만들어야 한다 (요구조건 문서 4-3).
    """
    c = blob['윤곽']
    peri = cv2.arcLength(c, True)
    if peri <= 0:
        return '모름'
    ap = cv2.approxPolyDP(c, 0.04 * peri, True)
    n = len(ap)
    fill = blob['채움률']
    if n == 3 or fill < 0.62:
        return '삼각형'
    if n == 4 and fill > 0.80:
        return '네모'
    if fill > 0.70:
        return '원형'
    return '모름'


def draw_blobs(bgr, blobs, note=None, fx=None, cx=None):
    """찾은 덩어리에 네모와 글씨를 얹은 새 영상을 돌려준다.

    글씨는 영문·숫자만 쓴다 — OpenCV 기본 글꼴에 한글이 없어서
    한글을 넣으면 네모(두부)로 나온다. 한글 설명은 터미널 출력과 문서에 적는다.
    """
    img = bgr.copy()
    for i, b in enumerate(blobs):
        col = DRAW_BGR.get(b['색'], (255, 255, 255))
        cv2.rectangle(img, (b['x'], b['y']), (b['x'] + b['w'], b['y'] + b['h']), col, 2)
        tag = {'빨강': 'RED', '초록': 'GREEN', '노랑': 'YELLOW',
               '파랑': 'BLUE', '주황': 'ORANGE'}.get(b['색'], '?')
        if fx is not None and cx is not None:
            tag += ' %+.1fdeg' % bearing_deg(b['u'], fx, cx)
        cv2.putText(img, tag, (b['x'], max(14, b['y'] - 6)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, col, 1, cv2.LINE_AA)
    h, w = img.shape[:2]
    #  화면 중심 세로선 — 상대방위 0 이 어디인지 눈으로 확인하려고 긋는다
    cv2.line(img, (w // 2, 0), (w // 2, h), (160, 160, 160), 1)
    if note:
        cv2.putText(img, note, (8, h - 10), cv2.FONT_HERSHEY_SIMPLEX,
                    0.45, (240, 240, 240), 1, cv2.LINE_AA)
    return img


def save_png(img, path):
    ok = cv2.imwrite(path, img)
    if not ok:
        print('못 썼음: %s' % path, file=sys.stderr)
        return False
    print('저장 : %s  (%d x %d)' % (path, img.shape[1], img.shape[0]))
    return True


# ── 포인트클라우드 ───────────────────────────────────────────────────────────
def front_slab(xyz, x_max=30.0, half_fov_deg=60.0, z_min=-1.0, z_max=6.0):
    """앞쪽 부채꼴만 남긴다. 자기 배 지붕과 하늘 쪽 반사를 함께 떨어낸다."""
    x, y, z = xyz[:, 0], xyz[:, 1], xyz[:, 2]
    ang = np.degrees(np.arctan2(y, x))
    keep = (x > 0.5) & (x < x_max) & (np.abs(ang) < half_fov_deg) & (z > z_min) & (z < z_max)
    return xyz[keep]


def bin_nearest(xyz, half_fov_deg=60.0, step_deg=5.0):
    """각도 칸마다 가장 가까운 거리를 뽑는다 — 장애물이 어느 쪽에 얼마나 있는지 보는 가장 싼 방법.

    돌려주는 것 : [(칸중심각[deg], 최단거리[m], 점수), ...] 가까운 칸부터
    """
    if len(xyz) == 0:
        return []
    ang = np.degrees(np.arctan2(xyz[:, 1], xyz[:, 0]))
    rng = np.hypot(xyz[:, 0], xyz[:, 1])
    out = []
    a = -half_fov_deg
    while a < half_fov_deg:
        sel = (ang >= a) & (ang < a + step_deg)
        if sel.any():
            out.append((a + step_deg / 2.0, float(rng[sel].min()), int(sel.sum())))
        a += step_deg
    out.sort(key=lambda t: t[1])
    return out


def save_cloud_png(xyz, path, title='', x_max=30.0, marks=()):
    """포인트클라우드를 위에서 내려다본 그림으로 저장한다 (RViz2 를 못 띄울 때의 대체물).

    RViz2 화면이 있어야 하는 자리에는 RViz2 캡처를 쓴다. 이 그림은
    headless 로 돌릴 때와 숫자를 문서에 적을 때 쓴다.
    """
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(5.2, 5.2), dpi=130)
    if len(xyz):
        sc = ax.scatter(xyz[:, 1], xyz[:, 0], c=xyz[:, 2], s=3, cmap='viridis')
        fig.colorbar(sc, ax=ax, label='z [m]', shrink=0.8)
    for mx, my, lab in marks:
        ax.plot([my], [mx], 'r+', ms=12, mew=2)
        ax.annotate(lab, (my, mx), textcoords='offset points', xytext=(6, 4), fontsize=8)
    ax.plot([0], [0], 'ks', ms=6)
    ax.set_xlabel('y [m]  (port +)')
    ax.set_ylabel('x [m]  (bow +)')
    ax.set_xlim(x_max, -x_max)   # 좌현이 왼쪽에 오게 뒤집는다
    ax.set_ylim(-2, x_max)
    ax.set_aspect('equal')
    ax.grid(alpha=0.3)
    ax.set_title(title, fontsize=9)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)
    print('저장 : %s  (점 %d 개)' % (path, len(xyz)))
