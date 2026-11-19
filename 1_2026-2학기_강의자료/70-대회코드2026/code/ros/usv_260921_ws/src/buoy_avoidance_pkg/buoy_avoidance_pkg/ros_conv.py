"""ros_conv.py — sensor_msgs → numpy 변환 (cv_bridge 없이).

usb_cam 이 yuyv 로 띄워지면 /image_raw 인코딩이 'yuv422_yuy2' 로 나오는데, 이 인코딩은
humble cv_bridge 가 bgr8 변환을 지원하지 않는 경우가 있어 직접 변환한다.
/image_raw/compressed 는 exp1016 에서 mono8(흑백)으로 저장돼 있었으니 색 판정에 쓰지 말 것.
"""
import cv2
import numpy as np

_PF_DTYPE = {1: np.int8, 2: np.uint8, 3: np.int16, 4: np.uint16,
             5: np.int32, 6: np.uint32, 7: np.float32, 8: np.float64}


def image_to_bgr(msg):
    """sensor_msgs/Image → BGR uint8 (H, W, 3). 지원하지 않는 인코딩이면 None."""
    enc = msg.encoding.lower()
    h, w, step = msg.height, msg.width, msg.step
    buf = np.frombuffer(msg.data, dtype=np.uint8)
    if enc in ('yuv422_yuy2', 'yuyv', 'yuy2'):
        img = buf.reshape(h, step)[:, :w * 2].reshape(h, w, 2)
        return cv2.cvtColor(img, cv2.COLOR_YUV2BGR_YUY2)
    if enc in ('yuv422', 'uyvy'):
        img = buf.reshape(h, step)[:, :w * 2].reshape(h, w, 2)
        return cv2.cvtColor(img, cv2.COLOR_YUV2BGR_UYVY)
    if enc in ('bgr8', 'rgb8'):
        img = buf.reshape(h, step)[:, :w * 3].reshape(h, w, 3)
        return img.copy() if enc == 'bgr8' else cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    if enc in ('bgra8', 'rgba8'):
        img = buf.reshape(h, step)[:, :w * 4].reshape(h, w, 4)
        return cv2.cvtColor(img, cv2.COLOR_BGRA2BGR if enc == 'bgra8' else cv2.COLOR_RGBA2BGR)
    if enc == 'mono8':
        img = buf.reshape(h, step)[:, :w]
        return cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    return None


def cloud_to_xyz(msg):
    """sensor_msgs/PointCloud2 → (N, 3) float32. Livox 처럼 필드 타입이 섞여 있어도 동작."""
    fields = {f.name: f for f in msg.fields}
    dtype = np.dtype({
        'names': ['x', 'y', 'z'],
        'formats': [_PF_DTYPE[fields[n].datatype] for n in ('x', 'y', 'z')],
        'offsets': [fields[n].offset for n in ('x', 'y', 'z')],
        'itemsize': msg.point_step,
    })
    n = msg.width * msg.height
    arr = np.frombuffer(msg.data, dtype=dtype, count=n)
    xyz = np.stack([arr['x'], arr['y'], arr['z']], axis=1).astype(np.float32)
    return xyz[np.isfinite(xyz).all(axis=1)]
