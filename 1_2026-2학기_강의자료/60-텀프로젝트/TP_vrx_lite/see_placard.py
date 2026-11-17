#!/usr/bin/env python3
# see_placard.py — 도킹 : 세 베이의 표식이 카메라에 보이는지 확인한다
#
#   bash goto.sh dock                            # 세 베이가 한 화면에 드는 자리
#   python3 see_placard.py --out /tmp/dock_cam.png
#
#   확인하는 것 (요구조건 문서 4-3 의 출발점)
#     1) 표식 셋이 한 화면에 든다
#     2) 색이 갈린다 (빨강 · 초록 · 파랑)
#     3) 모양이 갈린다 (삼각형 · 원형 · 네모)
#     4) 왼쪽에서 오른쪽 순서가 나온다 — 어느 베이로 들어갈지 고르는 데 쓰는 값이다
#
#   하지 않는 것
#     접근·크래빙·접안. 그쪽은 선수추진기까지 쓰는 3자유도 문제이고 Simulink 몫이다.
#
#   월드 (kaboat_term.sdf)
#     베이 중심 동 -556 (빨강 삼각형) · -550.5 (초록 원형) · -545 (파랑 네모)
#     개구부는 남쪽을 본다. 입구 북 227, 뒷벽 북 232.25, 벽 높이 2.0 m.
#     표식은 뒷벽 안쪽 면, 중심 높이 1.2 m.
#   임무설명 Ⅲ 은 모양 셋(삼각형·원형·네모)과 색 다섯(빨강·초록·파랑·주황·노랑) 중
#   임의 조합을 쓴다고 했다. 즉 **색만** 보거나 **모양만** 보는 코드는 경기에서 깨진다.
#
#   파랑이 어려운 까닭 — 미리 알아 둘 것
#     물빛이 파랑이다. 파랑 표식을 색만으로 찾으면 바다가 같이 잡힌다.
#     여기서는 수평선 위쪽만 보고(--sky-cut) 면적으로 가린다. 그래도 완벽하지 않다.
#     팀은 라이다로 찾은 도킹 스테이션 방향으로 관심영역을 좁히는 쪽이 낫다
#     (see_dock_cloud.py 가 그 방향을 내준다).

import argparse

import cv2

import tp_percep as tp

COLORS = ['빨강', '초록', '파랑', '노랑', '주황']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_placard.png')
    ap.add_argument('--min-area', type=int, default=120,
                    help='이보다 작은 덩어리는 버린다. 12 m 에서 삼각 표식이 200 px 쯤이다')
    ap.add_argument('--max-frac', type=float, default=0.04,
                    help='띠 넓이의 이 비율을 넘는 덩어리는 버린다 (바다·하늘)')
    ap.add_argument('--max-w-frac', type=float, default=0.25,
                    help='화면 폭의 이 비율보다 넓은 덩어리는 버린다 (수평으로 뻗은 바다)')
    ap.add_argument('--sky-cut', type=float, default=0.35,
                    help='화면 위쪽 이 비율은 버린다 (하늘). 0 이면 다 본다')
    ap.add_argument('--water-cut', type=float, default=0.75,
                    help='화면 아래쪽 이 비율 밑은 버린다 (뱃머리·물보라)')
    ap.add_argument('--truth', default='왼쪽 빨강 삼각형 · 가운데 초록 원형 · 오른쪽 파랑 네모',
                    help='월드에 넣어 둔 표식 차례. 월드마다 다르므로 밖에서 준다 '
                         '(해양누리공원 월드는 check_all.sh 가 알맞은 값을 넘긴다)')
    a = ap.parse_args()

    bgr, fx, cx, cy = tp.grab_image()
    h, w = bgr.shape[:2]
    print('카메라 : %d x %d,  fx = %.1f px' % (w, h, fx))

    #  띠 하나만 본다 — 표식은 수면에서 1.2 m 높이라 화면 가운데 띠에 들어온다
    v0, v1 = int(h * a.sky_cut), int(h * a.water_cut)
    band = bgr[v0:v1, :].copy()
    print('보는 띠 : v %d ~ %d (전체 %d)' % (v0, v1, h))

    #  바다를 걸러 내는 두 자 ─ 실측으로 정한 값이다
    #    띠 안에서 바다는 27,790 px (띠의 30 %) 로 잡혔고 화면 폭 전체로 뻗었다.
    #    표식은 12 m 에서 200~550 px (띠의 0.2~0.6 %), 폭 20~40 px 이다.
    #    그래서 "띠 넓이의 4 % 초과" 또는 "화면 폭의 25 % 초과" 면 표식이 아니다.
    band_area = float(band.shape[0] * band.shape[1])
    버린것 = []

    def 표식인가(b):
        if b['면적'] > band_area * a.max_frac:
            버린것.append((b['색'], b['면적'], '너무 넓다 — 바다나 하늘'))
            return False
        if b['w'] > w * a.max_w_frac:
            버린것.append((b['색'], b['면적'], '가로로 너무 길다 — 수평선'))
            return False
        return True

    found = []
    for color in COLORS:
        for b in tp.find_blobs(band, color, a.min_area, top=6):
            if not 표식인가(b):
                continue
            b['v'] += v0          # 띠 좌표를 전체 화면 좌표로 되돌린다
            b['y'] += v0
            b['모양'] = tp.shape_of(b)
            found.append(b)

    #  왼쪽에서 오른쪽 순서로 — 베이 순서와 같다
    found.sort(key=lambda b: b['u'])

    print()
    print('%-4s %-6s %-8s %10s %10s %8s' % ('자리', '색', '모양', '방위[deg]', '면적[px]', '채움률'))
    for i, b in enumerate(found):
        print('%-4d %-6s %-8s %10.1f %10.0f %8.2f'
              % (i + 1, b['색'], b['모양'], tp.bearing_deg(b['u'], fx, cx),
                 b['면적'], b['채움률']))

    if 버린것:
        print()
        print('바다·하늘로 보고 버린 덩어리 %d 개' % len(버린것))
        for c, ar, why in 버린것[:5]:
            print('  %-4s %8.0f px  %s' % (c, ar, why))

    print()
    if len(found) >= 3:
        print('표식 %d 개를 찾았다. 왼쪽 -> 오른쪽 :' % len(found))
        print('  ' + '  |  '.join('%s %s (%+.1f deg)'
                                  % (b['색'], b['모양'], tp.bearing_deg(b['u'], fx, cx))
                                  for b in found[:3]))
        print()
        print('월드에 넣어 둔 정답 : %s' % a.truth)
        print('Stateflow 로 넘길 값 : 고른 베이의 상대방위 한 개 (deg)')
    else:
        print('표식이 %d 개만 잡혔다 (셋이어야 한다).' % len(found))
        print('  해 볼 것')
        print('    bash goto.sh dock        12 m 앞 — 가시폭 20 m 로 베이 폭 11 m 를 덮는다')
        print('    --min-area 를 낮춘다      멀면 표식이 작다')
        print('    --sky-cut 0 --water-cut 1 띠를 없애고 전부 본다 (대신 바다가 섞인다)')

    #  표식 네모와 함께 "보는 띠" 를 선으로 그려 둔다 — 왜 빠졌는지 눈으로 보이게
    img = tp.draw_blobs(bgr, found, 'dock placards: %d found' % len(found), fx, cx)
    cv2.line(img, (0, v0), (w, v0), (90, 90, 90), 1)
    cv2.line(img, (0, v1), (w, v1), (90, 90, 90), 1)
    for b in found:
        cv2.putText(img, {'삼각형': 'TRI', '원형': 'CIR', '네모': 'SQR'}.get(b['모양'], '?'),
                    (b['x'], b['y'] + b['h'] + 14), cv2.FONT_HERSHEY_SIMPLEX,
                    0.45, (240, 240, 240), 1, cv2.LINE_AA)
    tp.save_png(img, a.out)


if __name__ == '__main__':
    main()
