#!/usr/bin/env python3
"""
pc2_util.py — sensor_msgs/PointCloud2 → (N,3) xyz numpy 변환 (벡터화)
Livox MID-360 등 x,y,z float32 필드를 가진 PointCloud2 를 빠르게 파싱.
ROS 의존은 메시지 객체 필드 접근뿐 (rclpy 불필요, 테스트 용이).
"""
import numpy as np


# PointField datatype → numpy dtype
_DT = {1: 'i1', 2: 'u1', 3: 'i2', 4: 'u2', 5: 'i4', 6: 'u4', 7: 'f4', 8: 'f8'}


def pointcloud2_to_xyz(msg) -> np.ndarray:
    """PointCloud2 메시지 → (N,3) float32 xyz. NaN/원점 점은 호출측에서 걸러도 됨."""
    # 필드 offset 파악
    off = {f.name: (f.offset, f.datatype) for f in msg.fields}
    if not all(k in off for k in ('x', 'y', 'z')):
        return np.empty((0, 3), dtype=np.float32)

    step = msg.point_step
    n = msg.width * msg.height
    buf = np.frombuffer(bytes(msg.data), dtype=np.uint8).reshape(n, step)

    def col(name):
        o, dt = off[name]
        npdt = np.dtype(_DT[dt]).newbyteorder('>' if msg.is_bigendian else '<')
        raw = buf[:, o:o + npdt.itemsize].copy()
        return raw.view(npdt).reshape(-1).astype(np.float32)

    xyz = np.column_stack([col('x'), col('y'), col('z')])
    return xyz


def filter_xyz(xyz: np.ndarray, z_min: float, z_max: float,
               x_min: float, x_max: float, y_abs_max: float) -> np.ndarray:
    """z 높이 + 전방 ROI 필터 후 (M,2) [x,y] 반환 (2D 투영)."""
    if len(xyz) == 0:
        return np.empty((0, 2))
    v = (np.isfinite(xyz).all(1) & (np.abs(xyz).sum(1) > 0)
         & (xyz[:, 2] >= z_min) & (xyz[:, 2] < z_max)
         & (xyz[:, 0] > x_min) & (xyz[:, 0] < x_max)
         & (np.abs(xyz[:, 1]) < y_abs_max))
    return xyz[v][:, :2]


def remove_ground_to_2d(xyz: np.ndarray, z_min: float, z_max: float,
                        x_min: float, x_max: float, y_abs_max: float,
                        cell: float, z_wall_min: float) -> np.ndarray:
    """
    지면 제거 후 (M,2) [x,y] 반환. z 정보가 있는 PointCloud2 전용.

    원리: 스테이션 벽은 수직 구조라 한 xy 위치에 z 가 낮은 점부터 높은 점까지
    쌓인다(그 셀의 z_max 가 높다). 지면은 평평해 그 위치 z 가 모두 낮다(z_max 낮음).
    → xy 격자(cell)로 나눠, 셀의 z_max 가 z_wall_min 이상인 셀만 '벽'으로 남긴다.

    이 필터는 z 축이 필요하므로 LaserScan(2D)에서는 쓸 수 없다.
    실측 검증: 지면을 min_height 로 못 거르는 상황에서 3-bay 를 안정적으로 분리.

      cell        : xy 격자 크기 [m] (예: 0.1)
      z_wall_min  : 셀 z_max 가 이 값 이상이면 벽 (예: -0.2)
    """
    if len(xyz) == 0:
        return np.empty((0, 2))
    # 1차 ROI + z 범위 (넉넉한 z 하한으로 지면까지 포함해 받은 뒤 셀 판정)
    v = (np.isfinite(xyz).all(1) & (np.abs(xyz).sum(1) > 0)
         & (xyz[:, 2] >= z_min) & (xyz[:, 2] < z_max)
         & (xyz[:, 0] > x_min) & (xyz[:, 0] < x_max)
         & (np.abs(xyz[:, 1]) < y_abs_max))
    r = xyz[v]
    if len(r) == 0:
        return np.empty((0, 2))
    # xy 셀별 z_max 계산 (벡터화)
    keys = np.floor(r[:, :2] / cell).astype(np.int64)
    # 셀키를 1D 해시로
    kx = keys[:, 0] - keys[:, 0].min()
    ky = keys[:, 1] - keys[:, 1].min()
    hsh = kx.astype(np.int64) * 100000 + ky
    order = np.argsort(hsh)
    hs = hsh[order]; zs = r[order, 2]
    # 각 유니크 셀의 z_max
    uniq, start = np.unique(hs, return_index=True)
    zmax = np.maximum.reduceat(zs, start)
    wall_cells = uniq[zmax >= z_wall_min]
    is_wall = np.isin(hsh, wall_cells)
    return r[is_wall][:, :2]