#!/usr/bin/env bash
# rviz_term.sh — 텀프로젝트 확인용 Rviz2 를 띄운다
#
#   bash rviz_term.sh                 # tp.rviz 판으로 띄운다
#   bash rviz_term.sh &               # 백그라운드로 띄우고 다른 명령을 이어 칠 때
#
#   보이는 것
#     PointCloud2  라이다 점 (높이로 색을 낸다)
#     LaserScan    /scan 한 층 (회피가 쓰는 것)
#     Image        전방 카메라 영상
#     Grid         5 m 눈금 — 거리를 눈으로 재는 데 쓴다
#
#   Fixed Frame 은 tp.rviz 가 wamv/wamv/base_link 로 굳혀 두었다.
#   Rviz2 기본값 map 으로 열면 모든 표시가 Status: Error 로 뜬다.
#
#   주의 : 가제보를 띄운 터미널과 ROS_DOMAIN_ID 가 같아야 한다.
#          (GZ_PARTITION 은 가제보 안쪽 통신용이라 Rviz2 에는 필요 없다)
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-7}"
source /opt/ros/humble/setup.bash

CFG="${1:-$HERE/tp.rviz}"
echo "Rviz2 판 : $CFG"
echo "ROS_DOMAIN_ID = $ROS_DOMAIN_ID"
echo
exec rviz2 -d "$CFG"
