#!/usr/bin/env bash
# view_dock.sh — 대회 RViz2 설정(auto_usv.rviz)을 해양누리 월드에 맞춰 띄운다
#
#   bash view_dock.sh
#
# 보이는 것
#   - 라이다 점군  /wamv/sensors/lidars/lidar_wamv_sensor/points  (높이로 색을 낸다)
#   - 도킹 스테이션 마커  /tp_dock/debug_markers   (tp_dock_detect.py 가 낸다)
#   - TF · 전방 카메라 영상
#
# 대회 원본에서 뺀 것 — 이 과제 범위가 아니다
#   /vfh/debug_markers · /rf/debug_markers  (충돌회피)
#   /lidar/scan · /berthing/debug_plane · /lidar/bev_image  (우리가 내지 않는 토픽)
#
# 유의 사항
#   - 가제보를 띄운 터미널과 **같은** GZ_PARTITION 을 준다
#   - 점군은 커서 BEST_EFFORT 로는 한 장도 안 온다 — 설정이 RELIABLE 로 되어 있다
set -e
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-7}
export GZ_PARTITION=${GZ_PARTITION:-dockA}
source /opt/ros/humble/setup.bash
source ~/vrx_ws/install/setup.bash
HERE="$(cd "$(dirname "$0")" && pwd)"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID  GZ_PARTITION=$GZ_PARTITION"
exec rviz2 -d "$HERE/tp_dock.rviz"
