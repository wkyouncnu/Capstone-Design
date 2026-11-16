#!/usr/bin/env python3
# see_search.py — 탐색 : 부표 색을 보고 선회 방향을 고른다
#
#   bash goto.sh search_red                     # 또는 search_grn · search_ylw
#   python3 see_search.py --out /tmp/search.png
#
#   규정 5.2(6) — 경기규정-202611
#     빨강 부표 · 초록 부표 : 우현선회
#     노랑 부표            : 좌현선회
#   (2025년 임무설명서의 "흰색 = 반시계" 는 2026-11 규정에서 노랑으로 바뀌었다.
#    월드의 탐색 부표도 노랑으로 넣었다.)
#
#   확인하는 것 : 세 색이 영상에서 갈리는지, 그래서 방향이 하나로 정해지는지.
#   하지 않는 것 : 선회 자체. 선회는 Stateflow 가 "좌/우" 한 비트를 받아서 한다.
#
#   월드 : 빨강 (동 -542, 북 206) · 초록 (동 -550, 북 195, 9주차 로이터 기둥을 그대로 씀)
#          노랑 (동 -556, 북 205)

import argparse

import tp_percep as tp

#  규정 5.2(6) 을 표 하나로 옮긴 것. 코드에서 if 를 늘리지 않고 이 표만 고친다.
TURN = {'빨강': ('우현선회', 'STARBOARD'),
        '초록': ('우현선회', 'STARBOARD'),
        '노랑': ('좌현선회', 'PORT')}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='/tmp/tp_search.png')
    ap.add_argument('--min-area', type=int, default=300,
                    help='탐색 부표는 가까이서 보므로 크다. 작은 것은 다른 물체다')
    a = ap.parse_args()

    bgr, fx, cx, cy = tp.grab_image()
    print('카메라 : %d x %d,  fx = %.1f px' % (bgr.shape[1], bgr.shape[0], fx))

    #  세 색을 모두 재어 보고 가장 큰 덩어리 하나를 "그 부표" 로 본다.
    #  까닭 : 탐색 구간에서는 부표 한 개를 정면에서 본다. 여럿이 잡히면
    #         물결 반사나 다른 구간의 물체다 — 면적으로 가린다.
    found = []
    for color in TURN:
        for b in tp.find_blobs(bgr, color, a.min_area, top=2):
            found.append(b)
    found.sort(key=lambda b: -b['면적'])

    print()
    print('%-6s %10s %10s %10s' % ('색', '면적[px]', '방위[deg]', '채움률'))
    for b in found:
        print('%-6s %10.0f %10.1f %10.2f'
              % (b['색'], b['면적'], tp.bearing_deg(b['u'], fx, cx), b['채움률']))

    if not found:
        print()
        print('부표를 못 찾았다. bash goto.sh search_red 로 자세를 맞추거나 --min-area 를 낮춘다')
        tp.save_png(tp.draw_blobs(bgr, [], 'search: nothing found', fx, cx), a.out)
        return

    b = found[0]
    ko, en = TURN[b['색']]
    bear = tp.bearing_deg(b['u'], fx, cx)
    print()
    print('가장 큰 덩어리 : %s,  면적 %.0f px,  상대방위 %+.1f deg' % (b['색'], b['면적'], bear))
    print('규정 5.2(6) 에 따른 선회 : **%s**' % ko)
    print()
    print('Stateflow 로 넘길 값 한 개 : turn_dir = %+d   (+1 우현 / -1 좌현)'
          % (+1 if en == 'STARBOARD' else -1))
    if len(found) > 1 and found[1]['면적'] > 0.5 * b['면적']:
        print('주의 : 두 번째 덩어리(%s, %.0f px)가 비슷하게 크다. 색이 섞여 보일 수 있다'
              % (found[1]['색'], found[1]['면적']))

    note = 'search: %s -> turn %s (%+.1f deg)' % (
        {'빨강': 'RED', '초록': 'GREEN', '노랑': 'YELLOW'}[b['색']], en, bear)
    tp.save_png(tp.draw_blobs(bgr, found, note, fx, cx), a.out)


if __name__ == '__main__':
    main()
