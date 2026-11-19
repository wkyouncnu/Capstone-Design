//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_wp_mission_modify_260917.h
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
#ifndef otter_2fixed_wp_mission_modify_260917_h_
#define otter_2fixed_wp_mission_modify_260917_h_
#include <poll.h>
#include <uORB/uORB.h>
#include <drivers/drv_hrt.h>
#include "rtwtypes.h"
#include "MW_Parameter.h"
#include "MW_ParameterRead.h"
#include "MW_uORB_Read.h"
#include "MW_PX4_PWM.h"
#include "MW_uORB_Write.h"
#include "otter_2fixed_wp_mission_modify_260917_types.h"
#include <uORB/topics/position_setpoint_triplet.h>
#include <uORB/topics/vehicle_local_position.h>
#include <uORB/topics/states_and_actuators.h>
#include <uORB/topics/vehicle_odometry.h>
#include <uORB/topics/position_setpoint.h>
#include <uORB/topics/input_rc.h>
#include <uORB/topics/trajectory_setpoint.h>
#include <uORB/topics/vehicle_global_position.h>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/mission_result.h>
#include <uORB/topics/actuator_armed.h>
#include <uORB/topics/offboard_control_mode.h>

extern "C"
{

#include "rt_nonfinite.h"

}

extern "C"
{

#include "rtGetNaN.h"

}

#include <stddef.h>
#define otter_2fixed_wp_mission_modify_260917_M (otter_2fixed_wp_mission_modi_M)

// Block signals (default storage)
struct B_otter_2fixed_wp_mission_mod_T {
  px4_Bus_position_setpoint_triplet In1;// '<S92>/In1'
  px4_Bus_position_setpoint_triplet r;
  px4_Bus_vehicle_local_position In1_n;// '<S95>/In1'
  px4_Bus_vehicle_local_position r1;
  px4_Bus_states_and_actuators BusAssignment1;// '<Root>/Bus Assignment1'
  px4_Bus_vehicle_odometry In1_h;      // '<S89>/In1'
  px4_Bus_vehicle_odometry r2;
  px4_Bus_position_setpoint r3;
  px4_Bus_input_rc In1_d;              // '<S98>/In1'
  px4_Bus_input_rc r4;
  real_T VectorConcatenate_e[9];       // '<S40>/Vector Concatenate'
  real_T rtb_VectorConcatenate_e_m[9];
  px4_Bus_trajectory_setpoint r5;
  px4_Bus_vehicle_global_position In1_e;// '<S94>/In1'
  px4_Bus_vehicle_global_position r6;
  px4_Bus_vehicle_attitude In1_du;     // '<S93>/In1'
  px4_Bus_vehicle_attitude r7;
  px4_Bus_mission_result In1_i;        // '<S86>/In1'
  px4_Bus_mission_result r8;
  real_T ned2[3];
  real_T uvw[3];                       // '<S14>/Matrix Multiply2'
  real_T dv[3];
  real_T dv1[3];
  real_T dv2[3];
  real_T dv3[3];
  uint16_T pwmValue[8];
  px4_Bus_actuator_armed In1_p;        // '<S88>/In1'
  px4_Bus_actuator_armed r9;
  px4_Bus_offboard_control_mode r10;
  boolean_T Compare[9];                // '<S70>/Compare'
  real_T Integrator3;                  // '<S12>/Integrator3'
  real_T OutportBufferFortau_auto[3];
  real_T sinphi;
  real_T coslambda;
  real_T sinlambda;
  real_T Fx_sat;                       // '<S12>/sat1'
  real_T rtb_cur_ne_idx_0;
  real_T rtb_cur_ne_idx_1;
  real_T rtb_Switch_idx_0;
  real_T rtb_Switch_idx_1;
  real_T rtb_Switch_idx_2;
  real_T rtb_Switch_idx_3;
  real_T rtb_VectorConcatenate_c_idx_2;
  real_T enuPos_idx_0;
  real_T rtb_VectorConcatenate_e_tmp;
  real_T rtb_Product1_b_tmp;
  real_T rtb_VectorConcatenate_e_tmp_c;
  real_T cosphi;
  real_T sinphi_k;
  real_T coslambda_c;
  real_T sinlambda_b;
  real_T tmp;
  real_T ecefPosWithENUOrigin_idx_0;
  real_T ecefPosWithENUOrigin_idx_1;
  real_T ecefPosWithENUOrigin_idx_2;
  real_T sinphi_p;
  real_T N;
  real_T b;
  real_T c;
  real_T sinphi_c;
  uint64_T rtb_PX4Timestamp1_f;
};

// Block states (default storage) for system '<Root>'
struct DW_otter_2fixed_wp_mission_mo_T {
  px4_internal_block_Subscriber_T obj; // '<S97>/SourceBlock'
  px4_internal_block_Subscriber_T obj_o;// '<S26>/SourceBlock'
  px4_internal_block_Subscriber_T obj_k;// '<S25>/SourceBlock'
  px4_internal_block_Subscriber_T obj_f;// '<S24>/SourceBlock'
  px4_internal_block_Subscriber_T obj_a;// '<S23>/SourceBlock'
  px4_internal_block_Subscriber_T obj_b;// '<S22>/SourceBlock'
  px4_internal_block_Subscriber_T obj_p;// '<S21>/SourceBlock'
  px4_internal_block_Subscriber_T obj_b2;// '<S20>/SourceBlock'
  px4_internal_block_Subscriber_T obj_e;// '<S19>/SourceBlock'
  px4_internal_block_Subscriber_T obj_n;// '<S18>/SourceBlock'
  px4_internal_block_Subscriber_T obj_nu;// '<S17>/SourceBlock'
  px4_internal_block_getPX4Abso_T obj_ki;// '<Root>/PX4 Timestamp1'
  px4_internal_block_ParameterU_T obj_j;// '<S3>/Read Parameter2'
  px4_internal_block_ParameterU_T obj_kn;// '<S3>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_p4;// '<S12>/Read Parameter3'
  px4_internal_block_ParameterU_T obj_l;// '<S12>/Read Parameter2'
  px4_internal_block_ParameterU_T obj_od;// '<S12>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_l4;// '<S12>/Read Parameter'
  px4_internal_block_ParameterU_T obj_je;// '<S11>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_ja;// '<S11>/Read Parameter'
  px4_internal_block_PWM_otter__T obj_fc;// '<Root>/PX4 PWM Output1'
  px4_internal_block_Publisher__T obj_c;// '<S5>/SinkBlock'
  real_T UnitDelay2_DSTATE;            // '<S12>/Unit Delay2'
  real_T Integrator3_DSTATE;           // '<S12>/Integrator3'
  real_T TransferFcn1_states;          // '<S12>/Transfer Fcn1'
  uint8_T Integrator3_SYSTEM_ENABLE;   // '<S12>/Integrator3'
  boolean_T Controller_MODE;           // '<Root>/Controller'
};

// Parameters (default storage)
struct P_otter_2fixed_wp_mission_mod_T_ {
  real_T Fx_max;                       // Variable: Fx_max
                                          //  Referenced by: '<S12>/sat1'

  real_T Fx_min;                       // Variable: Fx_min
                                          //  Referenced by: '<S12>/sat1'

  real_T N_max;                        // Variable: N_max
                                          //  Referenced by: '<S11>/stern constraint'

  real_T N_min;                        // Variable: N_min
                                          //  Referenced by: '<S11>/stern constraint'

  real_T RC_max;                       // Variable: RC_max
                                          //  Referenced by: '<S9>/Gain'

  real_T RC_min;                       // Variable: RC_min
                                          //  Referenced by: '<S9>/Gain'

  real_T Thrust_max;                   // Variable: Thrust_max
                                          //  Referenced by: '<S8>/Constant3'

  real_T Thrust_min;                   // Variable: Thrust_min
                                          //  Referenced by: '<S8>/Constant2'

  real_T d;                            // Variable: d
                                          //  Referenced by: '<S8>/Constant1'

  real_T k_neg;                        // Variable: k_neg
                                          //  Referenced by: '<S8>/1//k_pos1'

  real_T k_pos;                        // Variable: k_pos
                                          //  Referenced by: '<S8>/1//k_pos'

  real_T n_uniq[187];                  // Variable: n_uniq
                                          //  Referenced by:
                                          //    '<S8>/1-D Lookup Table'
                                          //    '<S8>/1-D Lookup Table1'

  real_T pwm_uniq[187];                // Variable: pwm_uniq
                                          //  Referenced by:
                                          //    '<S8>/1-D Lookup Table'
                                          //    '<S8>/1-D Lookup Table1'

  real_T ref_lla[3];                   // Variable: ref_lla
                                          //  Referenced by:
                                          //    '<S2>/Constant'
                                          //    '<S2>/Constant1'

  real_T DirectionCosineMatrixtoRotation;
                              // Mask Parameter: DirectionCosineMatrixtoRotation
                                 //  Referenced by:
                                 //    '<S70>/Constant'
                                 //    '<S72>/Constant'

  uint8_T DirectionCosineMatrixtoRotati_l;
                              // Mask Parameter: DirectionCosineMatrixtoRotati_l
                                 //  Referenced by:
                                 //    '<S49>/Constant'
                                 //    '<S59>/Constant'
                                 //    '<S61>/Constant'

  px4_Bus_position_setpoint_triplet Out1_Y0;// Computed Parameter: Out1_Y0
                                               //  Referenced by: '<S92>/Out1'

  px4_Bus_position_setpoint_triplet Constant_Value;// Computed Parameter: Constant_Value
                                                      //  Referenced by: '<S23>/Constant'

  px4_Bus_vehicle_local_position Out1_Y0_k;// Computed Parameter: Out1_Y0_k
                                              //  Referenced by: '<S95>/Out1'

  px4_Bus_vehicle_local_position Constant_Value_h;// Computed Parameter: Constant_Value_h
                                                     //  Referenced by: '<S26>/Constant'

  px4_Bus_states_and_actuators Constant_Value_k;// Computed Parameter: Constant_Value_k
                                                   //  Referenced by: '<S4>/Constant'

  px4_Bus_vehicle_odometry Out1_Y0_e;  // Computed Parameter: Out1_Y0_e
                                          //  Referenced by: '<S89>/Out1'

  px4_Bus_vehicle_odometry Constant_Value_g;// Computed Parameter: Constant_Value_g
                                               //  Referenced by: '<S20>/Constant'

  px4_Bus_input_rc Out1_Y0_m;          // Computed Parameter: Out1_Y0_m
                                          //  Referenced by: '<S98>/Out1'

  px4_Bus_input_rc Constant_Value_m;   // Computed Parameter: Constant_Value_m
                                          //  Referenced by: '<S97>/Constant'

  px4_Bus_position_setpoint Out1_Y0_a; // Computed Parameter: Out1_Y0_a
                                          //  Referenced by: '<S91>/Out1'

  px4_Bus_position_setpoint Constant_Value_b;// Computed Parameter: Constant_Value_b
                                                //  Referenced by: '<S22>/Constant'

  px4_Bus_trajectory_setpoint Out1_Y0_j;// Computed Parameter: Out1_Y0_j
                                           //  Referenced by: '<S87>/Out1'

  px4_Bus_trajectory_setpoint Constant_Value_l;// Computed Parameter: Constant_Value_l
                                                  //  Referenced by: '<S18>/Constant'

  px4_Bus_vehicle_global_position Out1_Y0_d;// Computed Parameter: Out1_Y0_d
                                               //  Referenced by: '<S94>/Out1'

  px4_Bus_vehicle_global_position Constant_Value_f;// Computed Parameter: Constant_Value_f
                                                      //  Referenced by: '<S25>/Constant'

  px4_Bus_vehicle_attitude Out1_Y0_o;  // Computed Parameter: Out1_Y0_o
                                          //  Referenced by: '<S93>/Out1'

  px4_Bus_vehicle_attitude Constant_Value_hr;// Computed Parameter: Constant_Value_hr
                                                //  Referenced by: '<S24>/Constant'

  px4_Bus_mission_result Out1_Y0_c;    // Computed Parameter: Out1_Y0_c
                                          //  Referenced by: '<S86>/Out1'

  px4_Bus_mission_result Constant_Value_i;// Computed Parameter: Constant_Value_i
                                             //  Referenced by: '<S17>/Constant'

  px4_Bus_actuator_armed Out1_Y0_h;    // Computed Parameter: Out1_Y0_h
                                          //  Referenced by: '<S88>/Out1'

  px4_Bus_actuator_armed Constant_Value_a;// Computed Parameter: Constant_Value_a
                                             //  Referenced by: '<S19>/Constant'

  px4_Bus_offboard_control_mode Out1_Y0_b;// Computed Parameter: Out1_Y0_b
                                             //  Referenced by: '<S90>/Out1'

  px4_Bus_offboard_control_mode Constant_Value_h1;// Computed Parameter: Constant_Value_h1
                                                     //  Referenced by: '<S21>/Constant'

  real_T tau_auto_Y0;                  // Computed Parameter: tau_auto_Y0
                                          //  Referenced by: '<S1>/tau_auto'

  real_T Constant_Value_j;             // Expression: 0
                                          //  Referenced by: '<S1>/Constant'

  real_T UnitDelay2_InitialCondition;  // Expression: 0
                                          //  Referenced by: '<S12>/Unit Delay2'

  real_T Integrator3_gainval;         // Computed Parameter: Integrator3_gainval
                                         //  Referenced by: '<S12>/Integrator3'

  real_T Integrator3_IC;               // Expression: 0
                                          //  Referenced by: '<S12>/Integrator3'

  real_T TransferFcn1_NumCoef[2];
                          // Expression: [1.960784313725490 -1.960784313725490 ]
                             //  Referenced by: '<S12>/Transfer Fcn1'

  real_T TransferFcn1_DenCoef[2];
                           // Expression: [1.000000000000000 0.960784313725490 ]
                              //  Referenced by: '<S12>/Transfer Fcn1'

  real_T TransferFcn1_InitialStates;   // Expression: 0
                                          //  Referenced by: '<S12>/Transfer Fcn1'

  real_T Constant_Value_lu[4];         // Expression: [1 0 0 0]
                                          //  Referenced by: '<S27>/Constant'

  real_T Constant_Value_l4;            // Expression: 1
                                          //  Referenced by: '<S55>/Constant'

  real_T Constant_Value_d;             // Expression: 1
                                          //  Referenced by: '<S56>/Constant'

  real_T Constant_Value_c;             // Expression: 1
                                          //  Referenced by: '<S51>/Constant'

  real_T Constant_Value_co;            // Expression: 1
                                          //  Referenced by: '<S52>/Constant'

  real_T Constant1_Value;              // Expression: 0
                                          //  Referenced by: '<S61>/Constant1'

  real_T Constant1_Value_k;            // Expression: 0
                                          //  Referenced by: '<S59>/Constant1'

  real_T Bias1_Bias[9];                // Expression: -eye(3)
                                          //  Referenced by: '<S62>/Bias1'

  real_T Bias_Bias;                    // Expression: -1
                                          //  Referenced by: '<S63>/Bias'

  real_T Constant1_Value_l;            // Expression: 1
                                          //  Referenced by: '<S6>/Constant1'

  real_T Constant_Value_ds;            // Expression: 0
                                          //  Referenced by: '<S6>/Constant'

  real_T Gain4_Gain;                   // Expression: 1
                                          //  Referenced by: '<S8>/Gain4'

  real_T Constant_Value_hc;            // Expression: 0
                                          //  Referenced by: '<S101>/Constant'

  real_T Constant_Value_e;             // Expression: 0
                                          //  Referenced by: '<S102>/Constant'

  real_T Constant_Value_if;            // Expression: 0
                                          //  Referenced by: '<S105>/Constant'

  real_T Constant_Value_db;            // Expression: 0
                                          //  Referenced by: '<S106>/Constant'

  real_T Constant1_Value_h;            // Expression: 1
                                          //  Referenced by: '<S10>/Constant1'

  real_T Constant_Value_du;            // Expression: 0
                                          //  Referenced by: '<S10>/Constant'

  real_T Constant_Value_n;             // Expression: 0
                                          //  Referenced by: '<S103>/Constant'

  real_T Constant_Value_ft;            // Expression: 0
                                          //  Referenced by: '<S104>/Constant'

  real_T Constant_Value_bp;            // Expression: 0
                                          //  Referenced by: '<S107>/Constant'

  real_T Constant_Value_ex;            // Expression: 0
                                          //  Referenced by: '<S108>/Constant'

  real_T Switch_Threshold;             // Expression: 0
                                          //  Referenced by: '<S27>/Switch'

  real_T Gain_Gain;                    // Expression: 2
                                          //  Referenced by: '<S34>/Gain'

  real_T Gain_Gain_m;                  // Expression: 2
                                          //  Referenced by: '<S37>/Gain'

  real_T Gain_Gain_c;                  // Expression: 2
                                          //  Referenced by: '<S32>/Gain'

  real_T Gain_Gain_g;                  // Expression: 2
                                          //  Referenced by: '<S38>/Gain'

  real_T Gain_Gain_ge;                 // Expression: 2
                                          //  Referenced by: '<S33>/Gain'

  real_T Gain_Gain_e;                  // Expression: 2
                                          //  Referenced by: '<S36>/Gain'

  real_T Gain_Gain_co;                 // Expression: 2
                                          //  Referenced by: '<S76>/Gain'

  real_T Gain_Gain_e1;                 // Expression: 2
                                          //  Referenced by: '<S79>/Gain'

  real_T Gain_Gain_h;                  // Expression: 2
                                          //  Referenced by: '<S74>/Gain'

  real_T Gain_Gain_o;                  // Expression: 2
                                          //  Referenced by: '<S80>/Gain'

  real_T Gain_Gain_p;                  // Expression: 2
                                          //  Referenced by: '<S75>/Gain'

  real_T Gain_Gain_k;                  // Expression: 2
                                          //  Referenced by: '<S78>/Gain'

  real_T Gain1_Gain[3];                // Expression: [1 1 -1]
                                          //  Referenced by: '<S48>/Gain1'

  real_T Gain2_Gain[2];                // Expression: [1 1]
                                          //  Referenced by: '<S48>/Gain2'

  real_T Gain3_Gain[2];                // Expression: [-1 1]
                                          //  Referenced by: '<S48>/Gain3'

  real_T Constant2_Value[2];           // Expression: [-RC_min -RC_min]
                                          //  Referenced by: '<S9>/Constant2'

  real_T Gain1_Gain_o;                 // Expression: 2
                                          //  Referenced by: '<S9>/Gain1'

  real_T Constant_Value_dl[2];         // Expression: [-1 -1]
                                          //  Referenced by: '<S9>/Constant'

  real_T DeadZone_Start;               // Expression: -0.1
                                          //  Referenced by: '<S106>/Dead Zone'

  real_T DeadZone_End;                 // Expression: 0.1
                                          //  Referenced by: '<S106>/Dead Zone'

  real_T Constant4_Value;              // Expression: 0
                                          //  Referenced by: '<S9>/Constant4'

  real_T DeadZone_Start_o;             // Expression: -0.05
                                          //  Referenced by: '<S105>/Dead Zone'

  real_T DeadZone_End_h;               // Expression: 0.05
                                          //  Referenced by: '<S105>/Dead Zone'

  real_T Constant17_Value[3];          // Expression: [Fx_min Fy_min N_min]
                                          //  Referenced by: '<S8>/Constant17'

  real_T Constant16_Value[3];          // Expression: [Fx_max Fy_max N_max]
                                          //  Referenced by: '<S8>/Constant16'

  real_T Switch2_Threshold;            // Expression: 0
                                          //  Referenced by: '<S8>/Switch2'

  real_T Switch_Threshold_c;           // Expression: 0
                                          //  Referenced by: '<S8>/Switch'

  real_T DeadZone_Start_l;             // Expression: -33
                                          //  Referenced by: '<S101>/Dead Zone'

  real_T DeadZone_End_e;               // Expression: 33
                                          //  Referenced by: '<S101>/Dead Zone'

  real_T Saturation_UpperSat;          // Expression: 1900
                                          //  Referenced by: '<S8>/Saturation'

  real_T Saturation_LowerSat;          // Expression: 1100
                                          //  Referenced by: '<S8>/Saturation'

  real_T Constant1_Value_kc;           // Expression: 0
                                          //  Referenced by: '<Root>/Constant1'

  real_T DeadZone_Start_m;             // Expression: -33
                                          //  Referenced by: '<S102>/Dead Zone'

  real_T DeadZone_End_o;               // Expression: 33
                                          //  Referenced by: '<S102>/Dead Zone'

  real_T Saturation1_UpperSat;         // Expression: 1800
                                          //  Referenced by: '<S8>/Saturation1'

  real_T Saturation1_LowerSat;         // Expression: 1200
                                          //  Referenced by: '<S8>/Saturation1'

  real_T Constant5_Value;              // Expression: 1500
                                          //  Referenced by: '<Root>/Constant5'

  real_T Constant6_Value;              // Expression: 1500
                                          //  Referenced by: '<Root>/Constant6'

  real_T Constant_Value_gh;            // Expression: 0
                                          //  Referenced by: '<Root>/Constant'

  real_T Constant3_Value;              // Expression: 0
                                          //  Referenced by: '<Root>/Constant3'

  real_T Constant4_Value_o;            // Expression: 0
                                          //  Referenced by: '<Root>/Constant4'

  real_T Constant2_Value_e;            // Expression: 0
                                          //  Referenced by: '<Root>/Constant2'

  uint16_T Switch_Threshold_a;         // Computed Parameter: Switch_Threshold_a
                                          //  Referenced by: '<S6>/Switch'

  uint16_T Switch_Threshold_i;         // Computed Parameter: Switch_Threshold_i
                                          //  Referenced by: '<S10>/Switch'

  boolean_T Assertion_Enabled;         // Computed Parameter: Assertion_Enabled
                                          //  Referenced by: '<S69>/Assertion'

  boolean_T Assertion_Enabled_h;      // Computed Parameter: Assertion_Enabled_h
                                         //  Referenced by: '<S67>/Assertion'

  boolean_T Assertion_Enabled_b;      // Computed Parameter: Assertion_Enabled_b
                                         //  Referenced by: '<S66>/Assertion'

  boolean_T Assertion_Enabled_k;      // Computed Parameter: Assertion_Enabled_k
                                         //  Referenced by: '<S64>/Assertion'

};

// Real-time Model Data Structure
struct tag_RTM_otter_2fixed_wp_missi_T {
  const char_T * volatile errorStatus;
  const char_T* getErrorStatus() const;
  void setErrorStatus(const char_T* const volatile aErrorStatus);
};

// Block parameters (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern P_otter_2fixed_wp_mission_mod_T otter_2fixed_wp_mission_modif_P;

#ifdef __cplusplus

}

#endif

// Block signals (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern struct B_otter_2fixed_wp_mission_mod_T otter_2fixed_wp_mission_modif_B;

#ifdef __cplusplus

}

#endif

// Block states (default storage)
extern struct DW_otter_2fixed_wp_mission_mo_T otter_2fixed_wp_mission_modi_DW;

#ifdef __cplusplus

extern "C"
{

#endif

  // Model entry point functions
  extern void otter_2fixed_wp_mission_modify_260917_initialize(void);
  extern void otter_2fixed_wp_mission_modify_260917_step(void);
  extern void otter_2fixed_wp_mission_modify_260917_terminate(void);

#ifdef __cplusplus

}

#endif

// Real-time Model object
#ifdef __cplusplus

extern "C"
{

#endif

  extern RT_MODEL_otter_2fixed_wp_miss_T *const otter_2fixed_wp_mission_modi_M;

#ifdef __cplusplus

}

#endif

extern volatile boolean_T stopRequested;
extern volatile boolean_T runModel;

//-
//  These blocks were eliminated from the model due to optimizations:
//
//  Block '<S2>/Add' : Unused code path elimination
//  Block '<S2>/Constant2' : Unused code path elimination
//  Block '<S17>/NOT' : Unused code path elimination
//  Block '<S18>/NOT' : Unused code path elimination
//  Block '<S19>/NOT' : Unused code path elimination
//  Block '<S20>/NOT' : Unused code path elimination
//  Block '<S21>/NOT' : Unused code path elimination
//  Block '<S22>/NOT' : Unused code path elimination
//  Block '<S23>/NOT' : Unused code path elimination
//  Block '<S24>/NOT' : Unused code path elimination
//  Block '<S25>/NOT' : Unused code path elimination
//  Block '<S26>/NOT' : Unused code path elimination
//  Block '<S3>/Data Type Conversion1' : Unused code path elimination
//  Block '<S7>/Bitwise Operator' : Unused code path elimination
//  Block '<S7>/Data Type Conversion' : Unused code path elimination
//  Block '<S7>/Data Type Conversion1' : Unused code path elimination
//  Block '<S7>/Data Type Conversion2' : Unused code path elimination
//  Block '<S7>/Gain' : Unused code path elimination
//  Block '<S7>/Gain1' : Unused code path elimination
//  Block '<S97>/NOT' : Unused code path elimination
//  Block '<Root>/Data Type Conversion1' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion11' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion12' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion13' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion14' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion15' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion16' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion17' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion21' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion29' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion30' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion31' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion32' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion33' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion34' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion35' : Eliminate redundant data type conversion
//  Block '<Root>/Data Type Conversion9' : Eliminate redundant data type conversion
//  Block '<S2>/Data Type Conversion4' : Eliminate redundant data type conversion
//  Block '<S14>/Data Type Conversion' : Eliminate redundant data type conversion
//  Block '<S14>/Data Type Conversion1' : Eliminate redundant data type conversion
//  Block '<S40>/Reshape (9) to [3x3] column-major' : Reshape block reduction
//  Block '<S48>/Reshape' : Reshape block reduction
//  Block '<S48>/Reshape1' : Reshape block reduction
//  Block '<S48>/Reshape2' : Reshape block reduction
//  Block '<S62>/Reshape' : Reshape block reduction
//  Block '<S71>/Reshape' : Reshape block reduction
//  Block '<S82>/Reshape (9) to [3x3] column-major' : Reshape block reduction


//-
//  The generated code includes comments that allow you to trace directly
//  back to the appropriate location in the model.  The basic format
//  is <system>/block_name, where system is the system number (uniquely
//  assigned by Simulink) and block_name is the name of the block.
//
//  Use the MATLAB hilite_system command to trace the generated code back
//  to the model.  For example,
//
//  hilite_system('<S3>')    - opens system 3
//  hilite_system('<S3>/Kp') - opens and selects block Kp which resides in S3
//
//  Here is the system hierarchy for this model
//
//  '<Root>' : 'otter_2fixed_wp_mission_modify_260917'
//  '<S1>'   : 'otter_2fixed_wp_mission_modify_260917/Controller'
//  '<S2>'   : 'otter_2fixed_wp_mission_modify_260917/Estimator Output'
//  '<S3>'   : 'otter_2fixed_wp_mission_modify_260917/Guidance'
//  '<S4>'   : 'otter_2fixed_wp_mission_modify_260917/PX4 uORB Message1'
//  '<S5>'   : 'otter_2fixed_wp_mission_modify_260917/PX4 uORB Write1'
//  '<S6>'   : 'otter_2fixed_wp_mission_modify_260917/RC on//off'
//  '<S7>'   : 'otter_2fixed_wp_mission_modify_260917/Radio Control Transmitter1'
//  '<S8>'   : 'otter_2fixed_wp_mission_modify_260917/Subsystem'
//  '<S9>'   : 'otter_2fixed_wp_mission_modify_260917/input setting'
//  '<S10>'  : 'otter_2fixed_wp_mission_modify_260917/on//off'
//  '<S11>'  : 'otter_2fixed_wp_mission_modify_260917/Controller/Heading Controller'
//  '<S12>'  : 'otter_2fixed_wp_mission_modify_260917/Controller/Surge Controller'
//  '<S13>'  : 'otter_2fixed_wp_mission_modify_260917/Controller/Heading Controller/MATLAB Function'
//  '<S14>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation'
//  '<S15>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/MATLAB Function'
//  '<S16>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/MATLAB Function1'
//  '<S17>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read'
//  '<S18>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read1'
//  '<S19>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read2'
//  '<S20>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read3'
//  '<S21>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/offboard contol mode'
//  '<S22>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/position setpoint'
//  '<S23>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/position setpoint set'
//  '<S24>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_attitude'
//  '<S25>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_global_pos'
//  '<S26>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_local_pos'
//  '<S27>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternion Validity Check'
//  '<S28>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix'
//  '<S29>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles'
//  '<S30>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternion Validity Check/Quaternion Norm'
//  '<S31>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A11'
//  '<S32>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A12'
//  '<S33>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A13'
//  '<S34>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A21'
//  '<S35>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A22'
//  '<S36>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A23'
//  '<S37>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A31'
//  '<S38>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A32'
//  '<S39>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A33'
//  '<S40>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Create 3x3 Matrix'
//  '<S41>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize'
//  '<S42>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus'
//  '<S43>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus/Quaternion Norm'
//  '<S44>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles'
//  '<S45>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix'
//  '<S46>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault'
//  '<S47>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3'
//  '<S48>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Get DCM Values'
//  '<S49>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM'
//  '<S50>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input'
//  '<S51>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem'
//  '<S52>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem1'
//  '<S53>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem2'
//  '<S54>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input'
//  '<S55>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem'
//  '<S56>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem1'
//  '<S57>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem2'
//  '<S58>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error'
//  '<S59>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal'
//  '<S60>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else No Action'
//  '<S61>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper'
//  '<S62>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotOrthogonal'
//  '<S63>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper'
//  '<S64>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/Error'
//  '<S65>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/None'
//  '<S66>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/Warning'
//  '<S67>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/Error'
//  '<S68>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/None'
//  '<S69>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/Warning'
//  '<S70>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotOrthogonal/transpose*dcm ~= eye(3)'
//  '<S71>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper/Determinant of 3x3 Matrix'
//  '<S72>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper/determinant does not equal 1'
//  '<S73>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A11'
//  '<S74>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A12'
//  '<S75>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A13'
//  '<S76>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A21'
//  '<S77>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A22'
//  '<S78>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A23'
//  '<S79>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A31'
//  '<S80>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A32'
//  '<S81>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A33'
//  '<S82>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Create 3x3 Matrix'
//  '<S83>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize'
//  '<S84>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus'
//  '<S85>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus/Quaternion Norm'
//  '<S86>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read/Enabled Subsystem'
//  '<S87>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read1/Enabled Subsystem'
//  '<S88>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read2/Enabled Subsystem'
//  '<S89>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/PX4 uORB Read3/Enabled Subsystem'
//  '<S90>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/offboard contol mode/Enabled Subsystem'
//  '<S91>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/position setpoint/Enabled Subsystem'
//  '<S92>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/position setpoint set/Enabled Subsystem'
//  '<S93>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_attitude/Enabled Subsystem'
//  '<S94>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_global_pos/Enabled Subsystem'
//  '<S95>'  : 'otter_2fixed_wp_mission_modify_260917/Estimator Output/vehicle_local_pos/Enabled Subsystem'
//  '<S96>'  : 'otter_2fixed_wp_mission_modify_260917/Guidance/Atan2_guidance'
//  '<S97>'  : 'otter_2fixed_wp_mission_modify_260917/Radio Control Transmitter1/PX4 uORB Read'
//  '<S98>'  : 'otter_2fixed_wp_mission_modify_260917/Radio Control Transmitter1/PX4 uORB Read/Enabled Subsystem'
//  '<S99>'  : 'otter_2fixed_wp_mission_modify_260917/Subsystem/MATLAB Function'
//  '<S100>' : 'otter_2fixed_wp_mission_modify_260917/Subsystem/MATLAB Function1'
//  '<S101>' : 'otter_2fixed_wp_mission_modify_260917/Subsystem/deadband'
//  '<S102>' : 'otter_2fixed_wp_mission_modify_260917/Subsystem/deadband1'
//  '<S103>' : 'otter_2fixed_wp_mission_modify_260917/Subsystem/deadband/Compare To Zero'
//  '<S104>' : 'otter_2fixed_wp_mission_modify_260917/Subsystem/deadband1/Compare To Zero'
//  '<S105>' : 'otter_2fixed_wp_mission_modify_260917/input setting/deadband1'
//  '<S106>' : 'otter_2fixed_wp_mission_modify_260917/input setting/deadband4'
//  '<S107>' : 'otter_2fixed_wp_mission_modify_260917/input setting/deadband1/Compare To Zero'
//  '<S108>' : 'otter_2fixed_wp_mission_modify_260917/input setting/deadband4/Compare To Zero'

#endif                              // otter_2fixed_wp_mission_modify_260917_h_

//
// File trailer for generated code.
//
// [EOF]
//
