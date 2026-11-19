#!/usr/bin/env python3
"""
docking_pc2_ransac_flight.py
────────────────────────────────────────────────────────────────────────
[PC2 + RANSAC 실비행 통합 버전 (직사각형 ROI - 오타 수정본)]
- PointCloud2 구독 -> 직사각형 ROI(x, y) 컷팅 -> 지면/천장 제거 -> 2D 투영 및 Voxel 축적
- DBSCAN + RANSAC 알고리즘으로 초정밀 4기둥 탐색 및 3-Bay(목표점, Yaw) 계산
- Gating(op==4 & detect_on==1), Smoothing(이동평균), Lock(고정) 등 비행 안전 로직 적용
- PX4/FMU로 DockingTestParam 발행 & RViz용 MarkerArray 발행
────────────────────────────────────────────────────────────────────────
"""
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
from sensor_msgs.msg import PointCloud2
from px4_msgs.msg import DockingTestParam, OperationMode, ForDockingMission
from visualization_msgs.msg import MarkerArray

import numpy as np
import math
import itertools
from sklearn.cluster import DBSCAN

# 기존 패키지 유틸리티
from ugv_docking_pkg.bay_core import PointAccumulator
from ugv_docking_pkg.pc2_util import pointcloud2_to_xyz, filter_xyz, remove_ground_to_2d
from ugv_docking_pkg.marker_viz import build_markers


class DockingDetectorPC2Ransac(Node):
    def __init__(self):
        super().__init__('docking_lidar_ransac_detector')

        self.declare_parameters(namespace='', parameters=[
            # 1. 직사각형 ROI (관심 영역) 및 높이 필터
            ('roi.x_min',            2.0),   # 스테이션 최소 전방거리 [m]
            ('roi.x_max',            6.2),   # 최대 전방거리 [m]
            ('roi.y_abs_max',        3.0),   # |y| 이내 [m]
            ('roi.z_min',           -0.7),   # 높이 하한 [m] (지면까지 받아 셀판정에 사용)
            ('roi.z_max',            1.5),   # 높이 상한 [m]

            # 2. 지면 제거 및 PC2 전처리
            ('ground.enable',        True),
            ('ground.cell',          0.10),
            ('ground.z_wall_min',   -0.35),  # 7/6 bag: 왼쪽기둥 z_max=-0.16 (-0.15면 소실)
            ('accum.enable',         True),
            ('accum.voxel',          0.05),  # 연산량 감소를 위해 0.05m(5cm) 권장
            ('accum.target_pts',     400),

            # 3. DBSCAN 및 RANSAC 알고리즘 파라미터
            ('ransac.dbscan_eps',           0.15),
            ('ransac.dbscan_min_samples',   3),
            ('ransac.iterations',           250),  # 250에서 20/20 검증 (100은 30%대)
            ('ransac.dist_threshold',       0.04),
            ('ransac.min_points',           3),
            ('ransac.max_lines_per_cluster',6),    # 1이면 클러스터당 선 1개 → 기둥 4개 불가
            ('ransac.seg_gap',              0.15), # 동일선상 기둥 분할 간격 [m]
            ('ransac.dir_tol_deg',          30.0), # 클러스터 지배방향 대비 허용 각 (대각선 배제)

            # 4. 기하학 매칭 파라미터 (기둥 크기 및 간격)
            ('bay.min_pillar_length',       0.10),
            ('bay.max_pillar_length',       0.50),
            ('bay.expected_bay_width',      0.90), # 기둥 가장자리간 개구부 (안쪽벽폭 0.6과 다름!)
            ('bay.width_tolerance',         0.25),
            ('bay.alignment_tolerance',     0.10), # 4기둥 일직선 허용 (가짜기둥 배제 위해 조임)
            ('bay.depth_spread_tol',        0.15), # 4기둥 중심의 전면방향 산포 허용 [m]
            ('bay.use_inner_wall',          True), # 안쪽벽으로 idx 깊이 실측 (3bay_pc2 와 idx 의미 통일)
            ('bay.inner_depth_min',         0.25), # 기둥선 대비 안쪽벽 최소 깊이 [m]
            ('bay.inner_depth_max',         0.70), # 최대 탐색 깊이 [m]
            ('bay.target_idx',              0),      # 진입할 베이 (0: 좌, 1: 중, 2: 우)
            ('approach_dist',               0.80),   # 베이 앞 대기 지점 거리

            # 5. 상태머신 / 통신 / 스무딩 (실비행 제어용)
            ('stable.thresh',        5),
            ('stable.smooth_window', 15),
            ('stable.lock_duration', 1.0),
            ('stable.pos_tol',       0.20),
            ('stable.psi_tol',       5.0),
            ('enu_to_ned',           True),
            ('publish_hz',           10.0),
            ('active_mode',          4),
            ('ransac.seed',          0),     # RANSAC 난수 시드 (재현성). 음수면 매번 랜덤
            
            # 5-b. 포켓(빗살형) 베이 검출 — 현재 사용 중인 방식
            #   스테이션은 안쪽 벽에서 격벽이 센서 쪽으로 돌출해 ㄷ자 포켓 3개를 만든다.
            #   벽 방향 깊이 프로파일에서 '파인 구간'을 베이로 본다.
            ('bay.wall_thr',         0.10),   # 안쪽 벽 직선 인라이어 허용 [m]
            ('bay.bin_w',            0.10),   # 벽 방향 프로파일 구간 폭 [m]
            ('bay.pocket_depth_min', 0.35),   # 격벽 돌출량 최소 [m] (이하면 포켓 아님)
            ('bay.width_min',        0.55),   # 포켓 폭 하한 [m] (실측 0.95~1.20)
            ('bay.width_max',        1.80),   # 포켓 폭 상한 [m]

            # 6. RViz 시각화
            ('viz.enable',           True),
            ('viz.frame_id',         'livox_frame'),
        ])

        g = lambda n: self.get_parameter(n).value
        
        # 필터 변수 할당
        self.x_min=g('roi.x_min'); self.x_max=g('roi.x_max'); self.y_abs=g('roi.y_abs_max')
        self.z_min=g('roi.z_min'); self.z_max=g('roi.z_max')
        
        self.ground_enable=g('ground.enable')
        self.ground_cell=g('ground.cell'); self.ground_z_wall_min=g('ground.z_wall_min')
        
        self.accum_enable=g('accum.enable')
        self._accum=PointAccumulator(g('accum.voxel'), int(g('accum.target_pts')))
        
        # RANSAC 변수 할당 (✨ 오타 방지를 위해 두 이름 모두에 바인딩 처리 완료)
        self.dbscan_eps = g('ransac.dbscan_eps'); self.dbscan_min_samples = g('ransac.dbscan_min_samples')
        self.ransac_iter = g('ransac.iterations'); self.ransac_dist = g('ransac.dist_threshold')
        self.ransac_min_pts = g('ransac.min_points')
        self.ransac_min_points = self.ransac_min_pts  # 두 변수명 호환성 보장
        self.max_lines = g('ransac.max_lines_per_cluster')
        self.seg_gap = g('ransac.seg_gap'); self.dir_tol_deg = g('ransac.dir_tol_deg')
        
        self.min_pillar = g('bay.min_pillar_length'); self.max_pillar = g('bay.max_pillar_length')
        self.expected_width = g('bay.expected_bay_width'); self.width_tol = g('bay.width_tolerance')
        self.align_tol = g('bay.alignment_tolerance')
        self.depth_spread_tol = g('bay.depth_spread_tol')
        self.use_inner = g('bay.use_inner_wall')
        self.inner_dmin = g('bay.inner_depth_min'); self.inner_dmax = g('bay.inner_depth_max')
        
        self.target_bay=int(g('bay.target_idx')); self.approach_dist=g('approach_dist')

        # 포켓 검출 파라미터
        self.wall_thr=g('bay.wall_thr'); self.bin_w=g('bay.bin_w')
        self.pocket_depth_min=g('bay.pocket_depth_min')
        self.bay_w_min=g('bay.width_min'); self.bay_w_max=g('bay.width_max')
        
        # 상태 제어 변수 할당
        self.stable_thresh=int(g('stable.thresh')); self.smooth_window=int(g('stable.smooth_window'))
        self.lock_duration=g('stable.lock_duration')
        self.pos_tol=g('stable.pos_tol'); self.psi_tol_rad=g('stable.psi_tol')*np.pi/180
        self.enu_to_ned=g('enu_to_ned'); self.active_mode=int(g('active_mode'))
        _seed=int(g('ransac.seed'))
        self._rng=np.random.default_rng(None if _seed<0 else _seed)
        
        publish_hz=g('publish_hz')
        self.viz_enable=g('viz.enable'); self.viz_frame=str(g('viz.frame_id'))

        # ROS 2 Publisher & Subscriber 
        sensor_qos=QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, durability=DurabilityPolicy.VOLATILE, history=HistoryPolicy.KEEP_LAST, depth=10)
        self.create_subscription(PointCloud2, '/livox/lidar', self.cloud_callback, sensor_qos)
        self.create_subscription(OperationMode, '/fmu/out/operation_mode', self.mode_callback, sensor_qos)
        self.create_subscription(ForDockingMission, '/fmu/out/for_docking_mission', self.detect_callback, sensor_qos)
        
        self.target_pub=self.create_publisher(DockingTestParam, '/fmu/in/docking_test_param', 10)
        self.marker_pub=self.create_publisher(MarkerArray, '/docking/debug_markers', 10)
        self.create_timer(1.0/publish_hz, self.publish_timer_callback)

        # 상태 초기화
        self._op_active=False; self._detect_on=False; self.mission_active=False
        self._reset_state()
        self.get_logger().info('✅ [PC2+RANSAC] 직사각형 ROI 도킹 검출 노드 대기 중')

    # ---- gating ----
    def mode_callback(self, m):
        self._op_active=(round(float(m.operation_mode))==self.active_mode); self._update_gate()
    def detect_callback(self, m):
        self._detect_on=(float(m.detect_on)>0.5); self._update_gate()
    def _update_gate(self):
        active=self._op_active and self._detect_on
        if active and not self.mission_active:
            self.get_logger().info(f"🚀 Gating 통과 (op={self.active_mode}, detect_on=1) : RANSAC 검출 가동"); self.mission_active=True
        elif not active and self.mission_active:
            self.get_logger().info(f"🛑 Gating 해제 : 검출 초기화")
            self.mission_active=False; self._reset_state()

    def _reset_state(self):
        self._accum.reset()
        self._stable_count=0; self._stable_start=None
        self._last_out=None; self._locked=None; self._lock_logged=False
        self._sm=[[] for _ in range(5)]  
        self._viz_pts=None; self._viz_bays=[]

    # ---- publish ----
    def publish_timer_callback(self):
        m=DockingTestParam(); m.timestamp=self.get_clock().now().nanoseconds//1000
        if not self.mission_active or self._locked is None:
            m.psi_ned=0.0; m.idx_ned_x=0.0; m.idx_ned_y=0.0; m.wp_ned_x=0.0; m.wp_ned_y=0.0
        else:
            psi,ix,iy,wx,wy=self._locked
            # ⚠️ Simulink DockingFlagManager 는 psi_ned==1.0 을 detect_valid 플래그로 사용.
            #    실제 진입각은 Simulink 가 wp→idx 벡터에서 스스로 계산한다.
            m.psi_ned=1.0; m.idx_ned_x=float(ix); m.idx_ned_y=float(iy)
            m.wp_ned_x=float(wx); m.wp_ned_y=float(wy)
        self.target_pub.publish(m)

    # ---- RViz 시각화 ----
    def _pub_viz(self, points, bays, status, locked=False):
        if not self.viz_enable: return
        ma=build_markers(self.get_clock().now().to_msg(), self.viz_frame, points, bays, self.target_bay, status, locked)
        self.marker_pub.publish(ma)

    # ---- 스무딩 ----
    def _smooth(self, ix, iy, psi, wx, wy):
        self._sm[0].append(ix); self._sm[1].append(iy)
        self._sm[2].append(np.sin(psi)); self._sm[3].append(np.cos(psi))
        self._sm[4].append((wx,wy))
        for k in range(5):
            if len(self._sm[k])>self.smooth_window: self._sm[k].pop(0)
        mx=float(np.mean(self._sm[0])); my=float(np.mean(self._sm[1]))
        mpsi=float(np.arctan2(np.mean(self._sm[2]),np.mean(self._sm[3])))
        wpa=np.array(self._sm[4]); mwx=float(wpa[:,0].mean()); mwy=float(wpa[:,1].mean())
        return mx,my,mpsi,mwx,mwy

    # ---- 메인 콜백 ----
    def cloud_callback(self, msg):
        if not self.mission_active:
            self._pub_viz(None, [], 'GATE CLOSED (need op==4 & detect_on==1)')
            return
        if self._locked is not None:
            self._pub_viz(self._viz_pts, self._viz_bays, 'LOCKED', locked=True)
            return

        xyz = pointcloud2_to_xyz(msg)
        
        if self.ground_enable:
            pts=remove_ground_to_2d(xyz, self.z_min, self.z_max, self.x_min, self.x_max, self.y_abs, self.ground_cell, self.ground_z_wall_min)
        else:
            pts=filter_xyz(xyz, self.z_min, self.z_max, self.x_min, self.x_max, self.y_abs)

        # 복셀 축적
        if self.accum_enable:
            self._accum.add(pts)
            if not self._accum.ready:
                self.get_logger().info(f"ACCUM {self._accum.count()}/{self._accum.target_pts}", throttle_duration_sec=1.0)
                self._pub_viz(self._accum.get(), [], f'ACCUM {self._accum.count()}/{self._accum.target_pts}')
                return
            det=self._accum.get()
        else:
            det=pts

        if det.shape[1] >= 3: det = det[:, :2]  # RANSAC을 위해 순수 2D (x,y)만 추출

        # ✨ 포켓(빗살형) 베이 탐색
        bays = self.find_bays_pocket(det)
        
        self._viz_pts=det; self._viz_bays=bays
        if len(bays)==0 or self.target_bay>=len(bays):
            self._stable_count=0
            self._sm=[[] for _ in range(5)]   # 검출이 끊겼다 돌아올 때 옛 값과 섞이지 않게
            self.get_logger().info(f"베이 탐색중 (RANSAC 못찾음)", throttle_duration_sec=1.0)
            self._pub_viz(det, bays, f'SEARCHING via RANSAC')
            return
            
        self._pub_viz(det, bays, f'DETECTED 3 bays')

        # 검출된 타겟 베이 데이터 추출 및 스무딩/Lock 처리
        b=bays[self.target_bay]
        ix,iy = float(b['idx'][0]), float(b['idx'][1])
        wx,wy = float(b['wp'][0]), float(b['wp'][1])
        psi = float(b['psi'])
        
        self._process_target(ix, iy, psi, wx, wy)

    # ---- 🧠 포켓(빗살형) 도킹 검출 알고리즘 ----
    #
    #  스테이션 형상 (실측: kaboat2026_bag/docking_test1~7, 2026-09-21)
    #      ┌────────────────────────────┐  ← 안쪽 벽
    #      │  ▭    │  ▭    │  ▭   │     │
    #      │ 베이0 │ 베이1 │ 베이2│     │  ← 격벽이 센서 쪽으로 돌출
    #      └───────┴───────┴──────┘
    #                  ▲ 센서
    #  포켓 폭 실측 0.95~1.20 m, 격벽 돌출량 0.5 m 이상.
    #
    #  ⚠️ 구 방식(4기둥 조합 매칭)은 이 형상에서 동작하지 않는다 —
    #     일렬 기둥 사이의 '틈'을 찾는 알고리즘이라 깊이로 파인 홈을 못 본다.
    #     실측 검출률 0~22%, 검출돼도 좌표가 0.9 m 흔들렸다.
    #     구 구현은 replay_tools/docking_node.py.bak 에 보관.
    #
    #  ⚠️ 스테이션 옆에 긴 안벽이 이어져 있다. '최다 인라이어 직선'을 그냥 쓰면
    #     안벽을 잡으므로, 센서에서 먼 점들로만 벽 직선을 찾는다.
    def find_bays_pocket(self, points):
        """(N,2) 점 → 베이 리스트 [{'idx','wp','psi','width'}] (벽 방향 순서)"""
        bays = []
        P = np.asarray(points, dtype=float)
        if len(P) < 30: return bays

        # 1) 안쪽 벽 직선 — 먼 점들만으로 RANSAC
        dist = np.linalg.norm(P, axis=1)
        far = P[dist > np.percentile(dist, 40)]
        if len(far) < 10: return bays
        M = len(far)
        i1 = self._rng.integers(0, M, self.ransac_iter)
        i2 = self._rng.integers(0, M, self.ransac_iter)
        ok = i1 != i2
        if not ok.any(): return bays
        p1 = far[i1[ok]]; v = far[i2[ok]] - p1
        L = np.linalg.norm(v, axis=1)
        ok2 = L > 1.0                      # 너무 가까운 두 점은 방향이 불안정
        if not ok2.any(): return bays
        p1, vh = p1[ok2], v[ok2] / L[ok2, None]
        nh_all = np.stack([-vh[:, 1], vh[:, 0]], axis=1)
        cst = -np.einsum('hd,hd->h', nh_all, p1)
        d = np.abs(far @ nh_all.T + cst[None, :])
        h = int(np.argmax((d < self.wall_thr).sum(axis=0)))
        inl = far[d[:, h] < self.wall_thr]
        if len(inl) < 10: return bays
        q = inl - inl.mean(axis=0)
        _w, _V = np.linalg.eigh(q.T @ q)
        v_hat = _V[:, np.argmax(_w)]
        p0 = inl.mean(axis=0)
        n_hat = np.array([-v_hat[1], v_hat[0]])
        if np.dot(n_hat, p0) < 0: n_hat = -n_hat     # 법선을 센서 반대(안쪽)로

        # 2) 벽 방향 깊이 프로파일 (돌출량, +가 센서 쪽)
        s = (P - p0) @ v_hat
        dep = (P - p0) @ n_hat
        m = (dep > -3.0) & (dep < 0.4)               # 벽 뒤 배경 제거
        s, dep = s[m], dep[m]
        if len(s) < 30: return bays
        bins = np.arange(s.min(), s.max() + self.bin_w, self.bin_w)
        bidx = np.clip(np.digitize(s, bins) - 1, 0, len(bins) - 1)
        prof = np.full(len(bins), np.nan)
        for k in range(len(bins)):
            vv = dep[bidx == k]
            if len(vv) >= 3: prof[k] = -np.percentile(vv, 5)
        okb = ~np.isnan(prof)
        if okb.sum() < 8: return bays

        # 3) 포켓(낮음) vs 격벽(높음)
        tip = np.nanpercentile(prof, 90); base = np.nanpercentile(prof, 10)
        depth = tip - base
        if depth < self.pocket_depth_min: return bays
        is_bay = okb & (prof < base + depth * 0.5)

        # 4) 연속 구간 → 포켓 후보 (양 옆에 격벽이 있어야 포켓)
        runs = []; k = 0
        while k < len(is_bay):
            j = k
            while j < len(is_bay) and is_bay[j] == is_bay[k]: j += 1
            runs.append((bool(is_bay[k]), k, j)); k = j
        cands = []
        for b, a, z in runs:
            if not b: continue
            w = (z - a) * self.bin_w
            if not (self.bay_w_min <= w <= self.bay_w_max): continue
            if a == 0 or z >= len(is_bay): continue   # 프로파일 끝 = 개방부
            cands.append((a, z, w))

        # 5) 후보가 3개를 넘으면(옆 안벽의 틈 등) 폭이 가장 고른 연속 3개
        NB = 3
        if len(cands) > NB:
            best, bs = None, 1e9
            for k in range(len(cands) - NB + 1):
                grp = cands[k:k + NB]
                ws = np.array([g[2] for g in grp])
                sp = float(ws.max() - ws.min())
                if sp < bs: bs, best = sp, grp
            cands = best

        for a, z, w in cands[:NB]:
            sc = (bins[a] + bins[min(z, len(bins) - 1)]) / 2.0
            inner = p0 + v_hat * sc                       # 포켓 안쪽 벽 중앙
            wp = inner - n_hat * self.approach_dist       # 입구 앞 접근점
            bays.append({'idx': inner, 'wp': wp,
                         'psi': float(math.atan2(n_hat[1], n_hat[0])), 'width': w})
        return bays


    def _process_target(self, ix, iy, psi, wx, wy):
        self._stable_count += 1
        s_ix,s_iy,s_psi,s_wx,s_wy=self._smooth(ix,iy,psi,wx,wy)
        if self._stable_count < self.stable_thresh: return

        if self.enu_to_ned:
            o_psi=-s_psi; o_ix=s_ix; o_iy=-s_iy; o_wx=s_wx; o_wy=-s_wy
        else:
            o_psi=s_psi; o_ix=s_ix; o_iy=s_iy; o_wx=s_wx; o_wy=s_wy
            
        now = self.get_clock().now().nanoseconds * 1e-9
        if self._last_out is not None:
            pd=np.hypot(o_ix-self._last_out[1], o_iy-self._last_out[2])
            ad=abs(np.arctan2(np.sin(o_psi-self._last_out[0]),np.cos(o_psi-self._last_out[0])))
            stable=(pd<self.pos_tol and ad<self.psi_tol_rad)
        else:
            stable=False
            
        if stable and self._stable_start is None: self._stable_start=now
        if not stable: self._stable_start=None
        self._last_out=(o_psi,o_ix,o_iy,o_wx,o_wy)
        
        elapsed=(now-self._stable_start) if self._stable_start else 0
        if self._locked is None and elapsed>=self.lock_duration:
            self._locked=(o_psi,o_ix,o_iy,o_wx,o_wy)
            if not self._lock_logged:
                self.get_logger().info(f'🔒 [RANSAC] Target Lock! psi={np.degrees(o_psi):.1f} idx=({o_ix:.2f},{o_iy:.2f}) wp=({o_wx:.2f},{o_wy:.2f})')
                self._lock_logged=True


def main(args=None):
    rclpy.init(args=args)
    node=DockingDetectorPC2Ransac()
    try: rclpy.spin(node)
    except KeyboardInterrupt: pass
    finally:
        node.destroy_node()
        if rclpy.ok(): rclpy.shutdown()

if __name__=='__main__':
    main()