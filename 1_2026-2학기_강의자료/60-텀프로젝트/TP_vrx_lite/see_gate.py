#!/usr/bin/env python3
# see_gate.py — 항로추종 : 게이트 부표 한 쌍(빨강·초록)이 카메라에 잡히는지 확인한다
#
#   bash goto.sh gate1                       # 1번 게이트 앞으로 옮긴 뒤
#   python3 see_gate.py --out /tmp/gate1.png
#
#   확인하는 것 (요구조건 문서 4-1 이 요구하는 출발점)
#     1) 빨강 부표와 초록 부표가 같은 화면에 든다
#     2 ) 각각의 상대방위[deg] 가 나온다 — 우현에 빨강, 좌현에 초록이어야 맞다
#     3) 둘의 중간 방위가 게이트 통과 방위다
#
#   하지 않는 것
#     게이트를 짝지어 순서를 매기는 일, 다음 게이트를 고르는 일, 그 방위로 배를 돌리는 일.
#     돌리는 쪽은 5주차 PD 헤딩 제어(Simulink)가 이미 한다. 팀이 붙여야 하는 것은
#     "이 상대방위를 목표 선수각으로 바꿔 Simulink 로 보내는" 한 줄이다.
#
#   규정 : 빨강·초록 부표 한 쌍이 게이트다. 빠뜨리고 지나가면 벌점 (임무설명 Ⅲ).
#   월드 : 게이트 8쌍. 빨강 동 -520/-522, 초록 동 -528/-530, 북 174 부터 6 m 간격.
#          항로 중심은 동 -525 다.

import argparse

import tp_percep as tp


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_gate.png', help='얹은 그림을 쓸 곳')
    ap.add_argument('--raw', default=None, help='원본 그림도 남기려면 경로')
    ap.add_argument('--min-area', type=int, default=80, help='이보다 작은 덩어리는 버린다')
    a = ap.parse_args()

    bgr, fx, cx, cy = tp.grab_image()
    print('카메라 : %d x %d,  fx = %.1f px,  중심 (%.0f, %.0f)'
          % (bgr.shape[1], bgr.shape[0], fx, cx, cy))

    red = tp.find_blobs(bgr, '빨강', a.min_area, top=3)
    grn = tp.find_blobs(bgr, '초록', a.min_area, top=3)

    print()
    print('%-6s %-6s %10s %10s %8s' % ('색', '개수', '상대방위[deg]', '면적[px]', '폭[px]'))
    for name, blobs in (('빨강', red), ('초록', grn)):
        if not blobs:
            print('%-6s %-6s   (못 찾음)' % (name, 0))
            continue
        for i, b in enumerate(blobs):
            print('%-6s %-6s %10.1f %10.0f %8d'
                  % (name if i == 0 else '', len(blobs) if i == 0 else '',
                     tp.bearing_deg(b['u'], fx, cx), b['면적'], b['w']))

    note = ''
    if red and grn:
        br = tp.bearing_deg(red[0]['u'], fx, cx)
        bg = tp.bearing_deg(grn[0]['u'], fx, cx)
        mid = (br + bg) / 2.0
        print()
        print('게이트 한 쌍을 찾았다')
        print('  빨강 %+.1f deg,  초록 %+.1f deg  ->  통과 방위 %+.1f deg (선수 기준, 우현 +)'
              % (br, bg, mid))
        if br > bg:
            print('  빨강이 우현, 초록이 좌현 — 규정대로 들어가는 자세다')
        else:
            print('  빨강이 좌현에 있다. 게이트를 반대로 보고 있거나 다른 부표를 잡았다')
        print('  부표 사이 화면 거리 %.0f px — 가까워질수록 벌어진다 (거리 가늠에 쓸 수 있다)'
              % abs(red[0]['u'] - grn[0]['u']))
        note = 'gate: red %+.1f / green %+.1f -> pass %+.1f deg' % (br, bg, mid)
    else:
        print()
        print('한 쌍이 아니다. 둘 중 하나가 화면 밖이거나 문턱값이 안 맞는다.')
        print('  해 볼 것 : bash goto.sh gate1 로 자세를 맞춘다 / --min-area 를 낮춘다')
        note = 'gate: pair NOT found'

    img = tp.draw_blobs(bgr, red + grn, note, fx, cx)
    tp.save_png(img, a.out)
    if a.raw:
        tp.save_png(bgr, a.raw)


if __name__ == '__main__':
    main()
