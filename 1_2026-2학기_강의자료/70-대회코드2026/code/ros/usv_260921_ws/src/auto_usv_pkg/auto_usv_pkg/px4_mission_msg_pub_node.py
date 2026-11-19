import rclpy
from rclpy.node import Node
from rclpy.executors import MultiThreadedExecutor 
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
from px4_msgs.msg import OffboardControlMode, TrajectorySetpoint, ModeFlag
from std_msgs.msg import Bool, Float32
from geometry_msgs.msg import PoseStamped, Twist, Point
import numpy as np
from threading import Lock
import math

class MissionMsgPublisherforPx4(Node):
    """
    A ROS 2 node that sends Offboard control commands to PX4.
    It switches between VFH (Velocity Control) and Berthing (Position Control)
    based on PX4 ModeFlags.
    """
    
    # --- Constants ---
    # PX4 uORB Topic Names
    TOPIC_OFFBOARD_CONTROL_MODE = '/fmu/in/offboard_control_mode'
    TOPIC_TRAJECTORY_SETPOINT = '/fmu/in/trajectory_setpoint'

    # Subscriber Topic Names
    TOPIC_VFH_COMMAND = '/vfh/command'             # Twist (linear.x=u_d, angular.z=yaw)
    TOPIC_VFH_FLAG = '/vfh/oa_flag'


    def __init__(self):
        """Initializes the node, setting up publishers, subscribers, timer, and lock."""
        super().__init__('mission_msg_pub_px4')

        # --- Parameter Declaration ---
        self.declare_parameter('timer_period', 0.02)        # [sec] 50Hz

        # Get parameter values
        timer_period = self.get_parameter('timer_period').get_parameter_value().double_value

        # Reliable QoS profile for control messages
        px4_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )
        
        # Best Effort QoS for high-rate sensors
        sensor_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=1
        )

        # Lock for data protection
        self.data_lock = Lock()

        # Data initialization
        with self.data_lock:
            self.current_oa_flags = False
            
            # VFH State (Twist)
            self.vfh_linear_vel = 0.0 # u_d
            self.vfh_target_yaw = 0.0 # psi_d
            self.vfh_cmd_received = False
            self.vfh_cmd_stamp_ns = 0

        # Create publishers
        self.offboard_control_mode_publisher = self.create_publisher(OffboardControlMode, self.TOPIC_OFFBOARD_CONTROL_MODE, px4_qos)
        self.trajectory_setpoint_publisher = self.create_publisher(TrajectorySetpoint, self.TOPIC_TRAJECTORY_SETPOINT, px4_qos)

        # Create subscribers
        self.create_subscription(Twist, self.TOPIC_VFH_COMMAND, self.vfh_cmd_callback, sensor_qos)
        self.create_subscription(Bool, self.TOPIC_VFH_FLAG, self.vfh_flag_callback, sensor_qos)
        
        # Timer for periodic message publishing
        self.timer = self.create_timer(timer_period, self.timer_callback)
        self.get_logger().info(f"PX4 Mission Pub Node initialized at {1.0/timer_period:.1f} Hz.")
        self.cmd_timeout_sec = 1.5

    # --- Subscriber Callbacks ---
    def vfh_cmd_callback(self, msg):
        """Receives Twist message from VFH Node."""
        with self.data_lock:
            self.vfh_linear_vel = msg.linear.x  # Longitudinal velocity (u_d)
            self.vfh_target_yaw = msg.angular.z # Absolute Yaw angle (psi_d)
            self.vfh_cmd_received = True
            self.vfh_cmd_stamp_ns = self.get_clock().now().nanoseconds

    def vfh_flag_callback(self, msg):
        with self.data_lock:
            self.current_oa_flags = msg.data

    # --- Publish Functions ---
    def publish_offboard_control_mode(self, timestamp, position=False, velocity=False, attitude=False):
        """Publishes the OffboardControlMode message."""
        msg = OffboardControlMode()
        msg.timestamp = timestamp
        msg.position = position
        msg.velocity = velocity
        msg.acceleration = False
        msg.attitude = attitude
        msg.body_rate = False
        self.offboard_control_mode_publisher.publish(msg)

    def publish_trajectory_setpoint(self, timestamp, pos=None, vel=None, yaw=0.0):
        """Publishes the TrajectorySetpoint message."""
        msg = TrajectorySetpoint()
        msg.timestamp = timestamp
        
        # Position Setpoint (NED)
        if pos is not None:
            msg.position = [float(pos[0]), float(pos[1]), float(pos[2])]
        else:
            msg.position = [0.0, 0.0, 0.0]
            
        # Velocity Setpoint (NED)
        if vel is not None:
            msg.velocity = [float(vel[0]), float(vel[1]), float(vel[2])]
        else:
            msg.velocity = [0.0, 0.0, 0.0]

        msg.yaw = float(yaw)
        self.trajectory_setpoint_publisher.publish(msg)

    # --- Main Loop ---
    def timer_callback(self):
        """Periodically called to publish control messages based on mode."""
        current_time_us = int(self.get_clock().now().nanoseconds / 1000)
        is_vfh = self.vfh_cmd_received
        
        control_mode = "IDLE"

        # Logic Branching
        if is_vfh:
            # --- OA MODE: Velocity Control (command in → immediately publish) ---
            control_mode = "OA_VEL"
            with self.data_lock:
                u_d = self.vfh_linear_vel
                psi_d = self.vfh_target_yaw
                cmd_age = (
                    (self.get_clock().now().nanoseconds - self.vfh_cmd_stamp_ns) / 1e9
                    if self.vfh_cmd_stamp_ns else None
                )
                cmd_ready = self.vfh_cmd_received and cmd_age is not None and cmd_age <= self.cmd_timeout_sec
                current_oa_flags = self.current_oa_flags

            if cmd_ready:
                self.publish_offboard_control_mode(
                    current_time_us,
                    position=False,
                    velocity=False,
                    attitude=current_oa_flags,
                )
                self.publish_trajectory_setpoint(current_time_us, pos=[0.0,0.0,0.0], vel=[u_d, 0.0, 0.0], yaw=psi_d)
            else:
                control_mode = "VFH_WAIT_CMD"
            
        else:
            # --- IDLE: Do nothing or allow Manual Control ---
            pass

        # Logging (throttled)
        if control_mode != "IDLE":
            self.get_logger().info(f"Mode: {control_mode} | Active", throttle_duration_sec=2.0)

def main(args=None):
    rclpy.init(args=args)
    node = MissionMsgPublisherforPx4()
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    
    try:
        executor.spin()
    except KeyboardInterrupt:
        node.get_logger().info('KeyboardInterrupt, shutting down.')
    except Exception as e:
        node.get_logger().error(f"Executor failed: {e}")
    finally:
        executor.shutdown()
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
