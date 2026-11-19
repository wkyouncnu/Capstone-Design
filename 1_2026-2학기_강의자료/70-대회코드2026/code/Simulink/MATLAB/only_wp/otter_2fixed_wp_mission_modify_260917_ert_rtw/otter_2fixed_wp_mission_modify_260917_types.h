//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_wp_mission_modify_260917_types.h
//
// Code generated for Simulink model 'otter_2fixed_wp_mission_modify_260917'.
//
// Model version                  : 6.91
// Simulink Coder version         : 24.2 (R2024b) 21-Jun-2024
// C/C++ source code generated on : Thu Oct  1 20:46:46 2026
//
// Target selection: ert.tlc
// Embedded hardware selection: ARM Compatible->ARM Cortex
// Code generation objectives: Unspecified
// Validation result: Not run
//
#ifndef otter_2fixed_wp_mission_modify_260917_types_h_
#define otter_2fixed_wp_mission_modify_260917_types_h_
#include "rtwtypes.h"
#include "MW_Parameter.h"
#include <uORB/topics/mission_result.h>
#include <uORB/topics/trajectory_setpoint.h>
#include <uORB/topics/actuator_armed.h>
#include <uORB/topics/vehicle_odometry.h>
#include <uORB/topics/offboard_control_mode.h>
#include <uORB/topics/position_setpoint.h>
#include <uORB/topics/position_setpoint_triplet.h>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/vehicle_global_position.h>
#include <uORB/topics/vehicle_local_position.h>
#include <uORB/topics/states_and_actuators.h>
#include <uORB/topics/input_rc.h>

// Custom Type definition for MATLABSystem: '<S3>/Read Parameter2'
#include "MW_Parameter.h"
#ifndef struct_px4_internal_block_ParameterU_T
#define struct_px4_internal_block_ParameterU_T

struct px4_internal_block_ParameterU_T
{
  boolean_T matlabCodegenIsDeleted;
  int32_T isInitialized;
  boolean_T isSetupComplete;
  MW_Param_Handle MW_PARAMHANDLE;
};

#endif                                // struct_px4_internal_block_ParameterU_T

#ifndef struct_d_px4_internal_block_SampleTi_T
#define struct_d_px4_internal_block_SampleTi_T

struct d_px4_internal_block_SampleTi_T
{
  int32_T __dummy;
};

#endif                                // struct_d_px4_internal_block_SampleTi_T

#ifndef struct_px4_internal_block_Subscriber_T
#define struct_px4_internal_block_Subscriber_T

struct px4_internal_block_Subscriber_T
{
  boolean_T matlabCodegenIsDeleted;
  int32_T isInitialized;
  boolean_T isSetupComplete;
  d_px4_internal_block_SampleTi_T SampleTimeHandler;
  pollfd_t eventStructObj;
  orb_metadata_t * orbMetadataObj;
};

#endif                                // struct_px4_internal_block_Subscriber_T

#ifndef struct_px4_internal_block_PWM_otter__T
#define struct_px4_internal_block_PWM_otter__T

struct px4_internal_block_PWM_otter__T
{
  boolean_T matlabCodegenIsDeleted;
  int32_T isInitialized;
  boolean_T isSetupComplete;
  unsigned int servoCount;
  int channelMask;
  boolean_T isMain;
  orb_advert_t armAdvertiseObj;
  orb_advert_t actuatorAdvertiseObj;
  boolean_T isArmed;
};

#endif                                // struct_px4_internal_block_PWM_otter__T

#ifndef struct_px4_internal_block_getPX4Abso_T
#define struct_px4_internal_block_getPX4Abso_T

struct px4_internal_block_getPX4Abso_T
{
  boolean_T matlabCodegenIsDeleted;
  int32_T isInitialized;
  boolean_T isSetupComplete;
  d_px4_internal_block_SampleTi_T SampleTimeHandler;
};

#endif                                // struct_px4_internal_block_getPX4Abso_T

#ifndef struct_px4_internal_block_Publisher__T
#define struct_px4_internal_block_Publisher__T

struct px4_internal_block_Publisher__T
{
  boolean_T matlabCodegenIsDeleted;
  int32_T isInitialized;
  boolean_T isSetupComplete;
  orb_advert_t orbAdvertiseObj;
  orb_metadata_t * orbMetadataObj;
};

#endif                                // struct_px4_internal_block_Publisher__T

// Parameters (default storage)
typedef struct P_otter_2fixed_wp_mission_mod_T_ P_otter_2fixed_wp_mission_mod_T;

// Forward declaration for rtModel
typedef struct tag_RTM_otter_2fixed_wp_missi_T RT_MODEL_otter_2fixed_wp_miss_T;

#endif                        // otter_2fixed_wp_mission_modify_260917_types_h_

//
// File trailer for generated code.
//
// [EOF]
//
