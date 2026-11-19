#!/usr/bin/env python3

import rclpy
from rclpy.node import Node
from rclpy.executors import MultiThreadedExecutor
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy, DurabilityPolicy
import numpy as np
from pyproj import Transformer, Proj
from scipy.spatial.transform import Rotation as R # 쿼터니언/회전 행렬 변환을 위해 SciPy 임포트

from std_msgs.msg import Float32
from px4_msgs.msg import VehicleGlobalPosition, PositionSetpointTriplet, VehicleLocalPosition, VehicleAttitude 
from geometry_msgs.msg import Point # Used for publishing NED position and Goal


class CoordinateTransformerNode(Node):
    """
    Subscribes to global position (LLA) and local state (Heading, Velocity) 
    and transforms them into the NED frame relative to a defined origin, 
    publishing the results for other nodes.
    
    Modified to subscribe to VehicleAttitude to transform NED velocity 
    (from VehicleLocalPosition) into Body-Fixed velocity.
    """
    def __init__(self):
        super().__init__('coordinate_transformer_node')

        # === QoS Profiles ===
        px4_qos = QoSProfile(
            reliability=ReliabilityPolicy.BEST_EFFORT, 
            durability=DurabilityPolicy.VOLATILE, 
            history=HistoryPolicy.KEEP_LAST, 
            depth=1
        )
        
        # --- State Variables ---
        # 쿼터니언 저장 변수 (초기값: 단위 쿼터니언 - 회전 없음)
        self.q = np.array([1.0, 0.0, 0.0, 0.0]) # w, x, y, z
        
        # --- Parameters (Origin) ---
        self.declare_parameters(
            namespace='',
            parameters=[
                ('origin.latitude', 36.395991),
                ('origin.longitude', 127.401794),
                ('origin.altitude', 25.1110),
            ])

        self.lat_origin = self.get_parameter('origin.latitude').get_parameter_value().double_value
        self.lon_origin = self.get_parameter('origin.longitude').get_parameter_value().double_value
        self.alt_origin = self.get_parameter('origin.altitude').get_parameter_value().double_value
        
        # --- LLA to NED Converter Initialization (Using PyProj for ECEF conversion) ---
        try:
            self.proj_lla = Proj(proj='latlong', ellps='WGS84')
            self.proj_ecef = Proj(proj='geocent', ellps='WGS84')
            self.transformer_to_ecef = Transformer.from_proj(self.proj_lla, self.proj_ecef)
            
            # Calculate ECEF reference point for subtraction
            self.ref_x, self.ref_y, self.ref_z = self.transformer_to_ecef.transform(
                self.lon_origin, self.lat_origin, self.alt_origin
            )
            
            # Rotation Matrix (ECEF to NED) calculation
            lat_rad, lon_rad = np.radians(self.lat_origin), np.radians(self.lon_origin)
            self.R_ecef_to_ned = np.array([
                [-np.sin(lat_rad) * np.cos(lon_rad), -np.sin(lat_rad) * np.sin(lon_rad),  np.cos(lat_rad)],
                [-np.sin(lon_rad),                   np.cos(lon_rad),                    0],
                [-np.cos(lat_rad) * np.cos(lon_rad), -np.cos(lat_rad) * np.sin(lon_rad), -np.sin(lat_rad)]
            ])
            self.get_logger().info(f"NED Origin set to LLA: ({self.lat_origin:.6f}, {self.lon_origin:.6f})")

        except Exception as e:
            self.get_logger().error(f"Failed to initialize PyProj/Coordinate Transformer: {e}")
            raise

        # === Subscribers ===
        self.create_subscription(VehicleGlobalPosition, '/fmu/out/vehicle_global_position', self.global_position_callback, px4_qos)
        self.create_subscription(VehicleLocalPosition, '/fmu/out/vehicle_local_position', self.local_position_callback, px4_qos)
        self.create_subscription(PositionSetpointTriplet, '/fmu/out/position_setpoint_triplet', self.wp_callback, px4_qos)
        self.create_subscription(VehicleAttitude, '/fmu/out/vehicle_attitude', self.attitude_callback, px4_qos) # VehicleAttitude 구독
        
        # === Publishers ===
        self.ned_pos_pub = self.create_publisher(Point, '/usv/state/position_ned', 10)
        self.ned_goal_pub = self.create_publisher(Point, '/usv/state/goal_ned', 10)
        self.heading_pub = self.create_publisher(Float32, '/usv/state/heading', 10)
        self.velocity_pub = self.create_publisher(Point, '/usv/state/velocity_body', 10) 

        self.get_logger().info("Coordinate Transformer Node started successfully.")

    # =================================================================
    #                       Helper Function
    # =================================================================
    def _is_valid_quaternion(self, q: np.ndarray) -> bool:
        """Checks quaternion array for correct size, finiteness, and non-zero norm."""
        return (
            q.shape == (4,)
            and np.all(np.isfinite(q))
            and np.linalg.norm(q) > 1e-6
        )

    def lla_to_ned(self, lat, lon, alt):
        """Converts Latitude, Longitude, Altitude (LLA) to North, East, Down (NED) 
        relative to the initialized origin."""
        
        # 1. Convert LLA to ECEF (Earth-Centered, Earth-Fixed)
        x, y, z = self.transformer_to_ecef.transform(lon, lat, alt)
        
        # 2. Subtract ECEF reference point
        ecef_relative = np.array([x - self.ref_x, y - self.ref_y, z - self.ref_z])
        
        # 3. Rotate from relative ECEF to NED
        return self.R_ecef_to_ned @ ecef_relative

    # =================================================================
    #                        Callbacks
    # =================================================================
    def attitude_callback(self, msg: VehicleAttitude):
        """Handles incoming vehicle attitude (quaternion) and stores it."""
        # PX4 VehicleAttitude uses (w, x, y, z) order for the quaternion
        incoming_q = np.array([msg.q[0], msg.q[1], msg.q[2], msg.q[3]])

        if not self._is_valid_quaternion(incoming_q):
            self.get_logger().warn("Received invalid quaternion. Keeping previous attitude.", throttle_duration_sec=5.0)
            return

        # Normalize to avoid scaling issues during rotation conversions
        self.q = incoming_q / np.linalg.norm(incoming_q)

    def global_position_callback(self, msg):
        """Handles incoming global position (LLA) and publishes NED position."""
        
        # 1. Convert LLA to NED
        north, east, down = self.lla_to_ned(msg.lat, msg.lon, msg.alt)
        
        # 2. Publish NED Position (Point message: x=North, y=East, z=Down)
        ned_msg = Point(x=float(north), y=float(east), z=float(down))
        self.ned_pos_pub.publish(ned_msg)

    def local_position_callback(self, msg: VehicleLocalPosition):
        """Handles incoming local state (Heading, Velocity) and publishes them after conversion."""
        
        # 1. Publish Heading (Yaw)
        heading_msg = Float32(data=msg.heading)
        self.heading_pub.publish(heading_msg)
        
        # 2. Convert NED Velocity to Body-Fixed Velocity
        # Assuming VehicleLocalPosition.vx/vy/vz are in the LOCAL NED frame (North, East, Down)
        ned_vel = np.array([msg.vx, msg.vy, msg.vz])
        
        try:
            if not self._is_valid_quaternion(self.q):
                self.get_logger().warn("Quaternion not initialized; publishing raw velocity.", throttle_duration_sec=5.0)
                vel_msg = Point(x=float(msg.vx), y=float(msg.vy), z=float(msg.vz))
                self.velocity_pub.publish(vel_msg)
                return

            # Create a Rotation object from the stored quaternion (w, x, y, z)
            # R.from_quat() expects (x, y, z, w), so reorder the stored array [w, x, y, z]
            # This rotation object R is R_ned_to_body (Rotation from NED to Body)
            rotation = R.from_quat([self.q[1], self.q[2], self.q[3], self.q[0]])
            
            # Use the inverse transformation to get v_body = (R_ned_to_body)^-1 * v_ned
            body_vel = rotation.apply(ned_vel, inverse=True)

            # 3. Publish Body-Fixed Velocity (Point message: x=Forward, y=Right, z=Down)
            vel_msg = Point(x=float(body_vel[0]), y=float(body_vel[1]), z=float(body_vel[2]))
            self.velocity_pub.publish(vel_msg)
        
        except Exception as e:
            self.get_logger().error(f"Velocity transformation (NED -> Body) failed: {e}")
            # Fallback: Publish raw velocity if transformation fails (x=N, y=E, z=D)
            vel_msg = Point(x=float(msg.vx), y=float(msg.vy), z=float(msg.vz))
            self.get_logger().warn("Publishing raw NED velocity due to error.")
            self.velocity_pub.publish(vel_msg)


    def wp_callback(self, msg):
        """Handles incoming Position Setpoint Triplet and publishes the current goal WP in NED."""
        
        # Only process the current waypoint (msg.current) for the goal
        if np.isnan(msg.current.lat) or msg.current.lat == 0.0:
            self.get_logger().warn("Invalid current waypoint received. Skipping goal.", throttle_duration_sec=5.0)
            return

        # Use the origin altitude as an approximation for WP conversion
        alt_approx = self.alt_origin 
        
        # 1. Convert current WP (Goal) LLA to NED
        n1, e1, d1 = self.lla_to_ned(msg.current.lat, msg.current.lon, alt_approx)
        
        # 2. Publish NED Goal (Point message: x=North, y=East, z=Down)
        goal_msg = Point(x=float(n1), y=float(e1), z=float(d1))
        self.ned_goal_pub.publish(goal_msg)


def main(args=None):
    rclpy.init(args=args)
    
    node = CoordinateTransformerNode()
    
    # Use MultiThreadedExecutor to allow callbacks (subscriptions) to run concurrently
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    
    try:
        executor.spin()
    except KeyboardInterrupt:
        node.get_logger().info('Keyboard Interrupt received. Shutting down...')
    except Exception as e:
        node.get_logger().error(f'Unhandled exception in spin: {e}')
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()

if __name__ == '__main__':
    main()