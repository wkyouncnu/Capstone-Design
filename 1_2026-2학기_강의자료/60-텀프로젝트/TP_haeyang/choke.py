#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""최소 통로 바로 위 문턱에서 A 쪽·B 쪽 영역을 색으로 갈라 그린다."""
import os
import runpy

import cv2
import numpy as np

g = runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'clearance.py'))
dist, A, B, half, free = g['dist'], g['A'], g['B'], g['half'], g['free']
X0, Y0, RES, W = g['X0'], g['Y0'], g['RES'], g['W']

for r in (half - 0.05, half + 0.05, half + 0.4, half + 1.0):
    m = (dist >= r).astype(np.uint8)
    n, lab = cv2.connectedComponents(m, connectivity=8)
    ca, cb = lab[A[1], A[0]], lab[B[1], B[0]]
    print(f'r={r:5.2f}  덩어리 {n-1:3d}   A={ca} ({int((lab==ca).sum())} 칸)  '
          f'B={cb} ({int((lab==cb).sum())} 칸)  {"붙음" if ca==cb and ca else "갈라짐"}')

r = half + 0.05
m = (dist >= r).astype(np.uint8)
n, lab = cv2.connectedComponents(m, connectivity=8)
ca, cb = lab[A[1], A[0]], lab[B[1], B[0]]
img = np.full((free.shape[0], free.shape[1], 3), 255, np.uint8)
img[free == 0] = (70, 70, 70)
img[lab == ca] = (120, 230, 120)
img[lab == cb] = (230, 160, 120)
oth = (lab > 0) & (lab != ca) & (lab != cb)
img[oth] = (200, 200, 255)
cv2.circle(img, A, 6, (255, 0, 0), -1)
cv2.circle(img, B, 6, (255, 0, 255), -1)
img = cv2.flip(img, 0)
img = cv2.resize(img, None, fx=3, fy=3, interpolation=cv2.INTER_NEAREST)
cv2.putText(img, f'at r={r:.2f} m : green=from entry, orange=from exit', (14, 28),
            cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
cv2.imwrite('/tmp/choke.png', img)
print('→ /tmp/choke.png')
