"""
turtle_pose_relay — turtlesim 자세를 MATLAB 이 아는 메시지로 옮겨 다시 발행한다.

왜 필요한가
  - /turtle1/pose 의 형식은 turtlesim/msg/Pose (turtlesim 전용 메시지)
  - MATLAB ROS Toolbox 에는 이 형식이 내장돼 있지 않다
    -> Simulink Subscribe 블록에서 고를 수 없다
  - 표준 메시지(geometry_msgs)로 옮겨 담아 다시 발행하면 바로 받을 수 있다

토픽 대응
  입력  /turtle1/pose    turtlesim/msg/Pose
  출력  /turtle1/pose2d  geometry_msgs/msg/Pose2D   x, y, theta
  출력  /turtle1/vel     geometry_msgs/msg/Twist    linear.x, angular.z

실행
  ros2 run usv_basics turtle_pose_relay
  ros2 run usv_basics turtle_pose_relay --ros-args -p turtle:=turtle2
"""

from geometry_msgs.msg import Pose2D, Twist
import rclpy
from rclpy.node import Node
from turtlesim.msg import Pose


class TurtlePoseRelay(Node):

    def __init__(self):
        super().__init__('turtle_pose_relay')
        turtle = self.declare_parameter('turtle', 'turtle1').value

        self.pub_pose = self.create_publisher(Pose2D, f'/{turtle}/pose2d', 10)
        self.pub_vel = self.create_publisher(Twist, f'/{turtle}/vel', 10)
        self.sub = self.create_subscription(
            Pose, f'/{turtle}/pose', self.on_pose, 10)

        self.count = 0
        self.get_logger().info(
            f'/{turtle}/pose -> /{turtle}/pose2d (Pose2D), /{turtle}/vel (Twist)')

    def on_pose(self, msg):
        p = Pose2D()                        # 위치와 선수각
        p.x = msg.x
        p.y = msg.y
        p.theta = msg.theta
        self.pub_pose.publish(p)

        v = Twist()                         # 속도
        v.linear.x = msg.linear_velocity
        v.angular.z = msg.angular_velocity
        self.pub_vel.publish(v)

        self.count += 1
        if self.count == 1:                 # 첫 메시지만 알린다 — 연결 확인용
            self.get_logger().info(
                f'first relay: x={p.x:.3f} y={p.y:.3f} theta={p.theta:.3f}')


def main(args=None):
    rclpy.init(args=args)
    node = TurtlePoseRelay()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == '__main__':
    main()
