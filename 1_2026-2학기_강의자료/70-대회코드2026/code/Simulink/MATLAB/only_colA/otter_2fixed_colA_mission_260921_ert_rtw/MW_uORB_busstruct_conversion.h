#ifndef _MW_UORB_BUSSTRUCT_CONVERSION_H_
#define _MW_UORB_BUSSTRUCT_CONVERSION_H_

#include <uORB/topics/actuator_armed.h>
#include <uORB/topics/input_rc.h>
#include <uORB/topics/mission_result.h>
#include <uORB/topics/offboard_control_mode.h>
#include <uORB/topics/operation_mode.h>
#include <uORB/topics/position_setpoint.h>
#include <uORB/topics/position_setpoint_triplet.h>
#include <uORB/topics/trajectory_setpoint.h>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/vehicle_global_position.h>
#include <uORB/topics/vehicle_local_position.h>
#include <uORB/topics/vehicle_odometry.h>

typedef struct actuator_armed_s  px4_Bus_actuator_armed ;
typedef struct input_rc_s  px4_Bus_input_rc ;
typedef struct mission_result_s  px4_Bus_mission_result ;
typedef struct offboard_control_mode_s  px4_Bus_offboard_control_mode ;
typedef struct operation_mode_s  px4_Bus_operation_mode ;
typedef struct position_setpoint_s  px4_Bus_position_setpoint ;
typedef struct position_setpoint_triplet_s  px4_Bus_position_setpoint_triplet ;
typedef struct trajectory_setpoint_s  px4_Bus_trajectory_setpoint ;
typedef struct vehicle_attitude_s  px4_Bus_vehicle_attitude ;
typedef struct vehicle_global_position_s  px4_Bus_vehicle_global_position ;
typedef struct vehicle_local_position_s  px4_Bus_vehicle_local_position ;
typedef struct vehicle_odometry_s  px4_Bus_vehicle_odometry ;

#endif
