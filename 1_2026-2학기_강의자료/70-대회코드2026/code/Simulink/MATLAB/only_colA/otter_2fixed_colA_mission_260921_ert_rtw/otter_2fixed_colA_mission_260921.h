//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_colA_mission_260921.h
//
// Code generated for Simulink model 'otter_2fixed_colA_mission_260921'.
//
// Model version                  : 6.97
// Simulink Coder version         : 24.2 (R2024b) 21-Jun-2024
// C/C++ source code generated on : Fri Oct  2 15:30:21 2026
//
// Target selection: ert.tlc
// Embedded hardware selection: ARM Compatible->ARM Cortex
// Code generation objectives: Unspecified
// Validation result: Not run
//
#ifndef otter_2fixed_colA_mission_260921_h_
#define otter_2fixed_colA_mission_260921_h_
#include <poll.h>
#include <uORB/uORB.h>
#include <drivers/drv_hrt.h>
#include "rtwtypes.h"
#include "MW_Parameter.h"
#include "MW_ParameterRead.h"
#include "MW_uORB_Read.h"
#include "MW_uORB_Write.h"
#include "MW_PX4_PWM.h"
#include "otter_2fixed_colA_mission_260921_types.h"
#include <uORB/topics/position_setpoint_triplet.h>
#include <uORB/topics/vehicle_local_position.h>
#include <uORB/topics/vehicle_odometry.h>
#include <uORB/topics/position_setpoint.h>
#include <uORB/topics/input_rc.h>
#include <uORB/topics/trajectory_setpoint.h>
#include <uORB/topics/vehicle_global_position.h>
#include <uORB/topics/vehicle_attitude.h>
#include <uORB/topics/mission_result.h>
#include <uORB/topics/actuator_armed.h>
#include <uORB/topics/offboard_control_mode.h>
#include <uORB/topics/operation_mode.h>

extern "C"
{

#include "rt_nonfinite.h"

}

extern "C"
{

#include "rtGetNaN.h"

}

#include <stddef.h>
#define otter_2fixed_colA_mission_260921_M (otter_2fixed_colA_mission_26_M)

// Block signals (default storage)
struct B_otter_2fixed_colA_mission_2_T {
  px4_Bus_position_setpoint_triplet In1;// '<S90>/In1'
  px4_Bus_position_setpoint_triplet r;
  px4_Bus_vehicle_local_position In1_n;// '<S93>/In1'
  px4_Bus_vehicle_local_position r1;
  px4_Bus_vehicle_odometry In1_h;      // '<S87>/In1'
  px4_Bus_vehicle_odometry r2;
  px4_Bus_position_setpoint r3;
  px4_Bus_input_rc In1_d;              // '<S105>/In1'
  px4_Bus_input_rc r4;
  real_T VectorConcatenate_e[9];       // '<S38>/Vector Concatenate'
  real_T VectorConcatenate[9];         // '<S80>/Vector Concatenate'
  px4_Bus_trajectory_setpoint r5;
  px4_Bus_vehicle_global_position In1_e;// '<S92>/In1'
  px4_Bus_trajectory_setpoint In1_j;   // '<S85>/In1'
  px4_Bus_vehicle_global_position r6;
  px4_Bus_vehicle_attitude In1_du;     // '<S91>/In1'
  px4_Bus_vehicle_attitude r7;
  px4_Bus_mission_result In1_i;        // '<S84>/In1'
  px4_Bus_mission_result r8;
  real_T ecefPosWithENUOrigin[3];
  real_T dv[3];
  real_T rtb_VectorConcatenate_e_m[3];
  real_T dv1[3];
  real_T dv2[3];
  uint16_T pwmValue[8];
  px4_Bus_actuator_armed r9;
  px4_Bus_offboard_control_mode In1_nl;// '<S88>/In1'
  px4_Bus_actuator_armed In1_p;        // '<S86>/In1'
  px4_Bus_offboard_control_mode r10;
  px4_Bus_operation_mode BusAssignment;// '<S3>/Bus Assignment'
  boolean_T Compare[9];                // '<S68>/Compare'
  real_T Integrator3;                  // '<S10>/Integrator3'
  real_T OutportBufferFortau_auto[3];
  real_T sinphi;
  real_T coslambda;
  real_T sinlambda;
  real_T Fx_sat;                       // '<S10>/sat1'
  real_T Add;                          // '<S2>/Add'
  real_T Sum_h;                        // '<S9>/Sum'
  real_T Sum_jw;                       // '<S10>/Sum'
  real_T TransferFcn1_tmp;
  real_T rtb_Switch_o_idx_0;
  real_T rtb_Switch_o_idx_1;
  real_T rtb_Switch_o_idx_2;
  real_T rtb_Switch_o_idx_3;
  real_T enuPos_idx_0;
  real_T rtb_Fx_unsat_tmp;
  real_T rtb_Product1_b_tmp;
  real_T cosphi;
  real_T sinphi_c;
  real_T coslambda_k;
  real_T sinlambda_c;
  real_T tmp;
  real_T ecefPosWithENUOrigin_idx_0;
  real_T ecefPosWithENUOrigin_idx_1;
  real_T ecefPosWithENUOrigin_idx_2;
  real_T sinphi_b;
  real_T N;
  real_T b;
  real_T c;
  real_T d;
  real_T b_x;
  real_T absx;
  real_T q;
  real_T b_x_p;
  real_T absx_c;
  real32_T ParamStep;
};

// Block states (default storage) for system '<Root>'
struct DW_otter_2fixed_colA_mission__T {
  px4_internal_block_Subscriber_T obj; // '<S104>/SourceBlock'
  px4_internal_block_Subscriber_T obj_o;// '<S24>/SourceBlock'
  px4_internal_block_Subscriber_T obj_k;// '<S23>/SourceBlock'
  px4_internal_block_Subscriber_T obj_f;// '<S22>/SourceBlock'
  px4_internal_block_Subscriber_T obj_a;// '<S21>/SourceBlock'
  px4_internal_block_Subscriber_T obj_b;// '<S20>/SourceBlock'
  px4_internal_block_Subscriber_T obj_p;// '<S19>/SourceBlock'
  px4_internal_block_Subscriber_T obj_b2;// '<S18>/SourceBlock'
  px4_internal_block_Subscriber_T obj_e;// '<S17>/SourceBlock'
  px4_internal_block_Subscriber_T obj_n;// '<S16>/SourceBlock'
  px4_internal_block_Subscriber_T obj_nu;// '<S15>/SourceBlock'
  px4_internal_block_getPX4Abso_T obj_m;// '<S3>/PX4 Timestamp'
  px4_internal_block_ParameterU_T obj_fl;// '<S3>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_p4;// '<S10>/Read Parameter3'
  px4_internal_block_ParameterU_T obj_l;// '<S10>/Read Parameter2'
  px4_internal_block_ParameterU_T obj_od;// '<S10>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_l4;// '<S10>/Read Parameter'
  px4_internal_block_ParameterU_T obj_j;// '<S9>/Read Parameter1'
  px4_internal_block_ParameterU_T obj_ja;// '<S9>/Read Parameter'
  px4_internal_block_Publisher__T obj_jh;// '<S97>/SinkBlock'
  px4_internal_block_PWM_otter__T obj_fc;// '<Root>/PX4 PWM Output1'
  real_T UnitDelay2_DSTATE;            // '<S10>/Unit Delay2'
  real_T Integrator3_DSTATE;           // '<S10>/Integrator3'
  real_T TransferFcn1_states;          // '<S10>/Transfer Fcn1'
  uint8_T is_active_c3_otter_2fixed_colA_;// '<S3>/Chart'
  uint8_T is_c3_otter_2fixed_colA_mission;// '<S3>/Chart'
  uint8_T Integrator3_SYSTEM_ENABLE;   // '<S10>/Integrator3'
  boolean_T Controller_MODE;           // '<Root>/Controller'
};

// Parameters (default storage)
struct P_otter_2fixed_colA_mission_2_T_ {
  real_T Fx_max;                       // Variable: Fx_max
                                          //  Referenced by: '<S10>/sat1'

  real_T Fx_min;                       // Variable: Fx_min
                                          //  Referenced by: '<S10>/sat1'

  real_T N_max;                        // Variable: N_max
                                          //  Referenced by: '<S9>/stern constraint'

  real_T N_min;                        // Variable: N_min
                                          //  Referenced by: '<S9>/stern constraint'

  real_T RC_max;                       // Variable: RC_max
                                          //  Referenced by: '<S7>/Gain'

  real_T RC_min;                       // Variable: RC_min
                                          //  Referenced by: '<S7>/Gain'

  real_T Thrust_max;                   // Variable: Thrust_max
                                          //  Referenced by: '<S6>/Constant3'

  real_T Thrust_min;                   // Variable: Thrust_min
                                          //  Referenced by: '<S6>/Constant2'

  real_T d;                            // Variable: d
                                          //  Referenced by: '<S6>/Constant1'

  real_T k_neg;                        // Variable: k_neg
                                          //  Referenced by: '<S6>/1//k_pos1'

  real_T k_pos;                        // Variable: k_pos
                                          //  Referenced by: '<S6>/1//k_pos'

  real_T n_uniq[187];                  // Variable: n_uniq
                                          //  Referenced by:
                                          //    '<S6>/1-D Lookup Table'
                                          //    '<S6>/1-D Lookup Table1'

  real_T pwm_uniq[187];                // Variable: pwm_uniq
                                          //  Referenced by:
                                          //    '<S6>/1-D Lookup Table'
                                          //    '<S6>/1-D Lookup Table1'

  real_T ref_lla[3];                   // Variable: ref_lla
                                          //  Referenced by:
                                          //    '<S2>/Constant'
                                          //    '<S2>/Constant1'

  real_T DirectionCosineMatrixtoRotation;
                              // Mask Parameter: DirectionCosineMatrixtoRotation
                                 //  Referenced by:
                                 //    '<S68>/Constant'
                                 //    '<S70>/Constant'

  uint8_T DirectionCosineMatrixtoRotati_l;
                              // Mask Parameter: DirectionCosineMatrixtoRotati_l
                                 //  Referenced by:
                                 //    '<S47>/Constant'
                                 //    '<S57>/Constant'
                                 //    '<S59>/Constant'

  px4_Bus_position_setpoint_triplet Out1_Y0;// Computed Parameter: Out1_Y0
                                               //  Referenced by: '<S90>/Out1'

  px4_Bus_position_setpoint_triplet Constant_Value;// Computed Parameter: Constant_Value
                                                      //  Referenced by: '<S21>/Constant'

  px4_Bus_vehicle_local_position Out1_Y0_k;// Computed Parameter: Out1_Y0_k
                                              //  Referenced by: '<S93>/Out1'

  px4_Bus_vehicle_local_position Constant_Value_h;// Computed Parameter: Constant_Value_h
                                                     //  Referenced by: '<S24>/Constant'

  px4_Bus_vehicle_odometry Out1_Y0_e;  // Computed Parameter: Out1_Y0_e
                                          //  Referenced by: '<S87>/Out1'

  px4_Bus_vehicle_odometry Constant_Value_g;// Computed Parameter: Constant_Value_g
                                               //  Referenced by: '<S18>/Constant'

  px4_Bus_input_rc Out1_Y0_m;          // Computed Parameter: Out1_Y0_m
                                          //  Referenced by: '<S105>/Out1'

  px4_Bus_input_rc Constant_Value_m;   // Computed Parameter: Constant_Value_m
                                          //  Referenced by: '<S104>/Constant'

  px4_Bus_position_setpoint Out1_Y0_a; // Computed Parameter: Out1_Y0_a
                                          //  Referenced by: '<S89>/Out1'

  px4_Bus_position_setpoint Constant_Value_b;// Computed Parameter: Constant_Value_b
                                                //  Referenced by: '<S20>/Constant'

  px4_Bus_trajectory_setpoint Out1_Y0_j;// Computed Parameter: Out1_Y0_j
                                           //  Referenced by: '<S85>/Out1'

  px4_Bus_trajectory_setpoint Constant_Value_l;// Computed Parameter: Constant_Value_l
                                                  //  Referenced by: '<S16>/Constant'

  px4_Bus_vehicle_global_position Out1_Y0_d;// Computed Parameter: Out1_Y0_d
                                               //  Referenced by: '<S92>/Out1'

  px4_Bus_vehicle_global_position Constant_Value_f;// Computed Parameter: Constant_Value_f
                                                      //  Referenced by: '<S23>/Constant'

  px4_Bus_vehicle_attitude Out1_Y0_o;  // Computed Parameter: Out1_Y0_o
                                          //  Referenced by: '<S91>/Out1'

  px4_Bus_vehicle_attitude Constant_Value_hr;// Computed Parameter: Constant_Value_hr
                                                //  Referenced by: '<S22>/Constant'

  px4_Bus_mission_result Out1_Y0_c;    // Computed Parameter: Out1_Y0_c
                                          //  Referenced by: '<S84>/Out1'

  px4_Bus_mission_result Constant_Value_i;// Computed Parameter: Constant_Value_i
                                             //  Referenced by: '<S15>/Constant'

  px4_Bus_actuator_armed Out1_Y0_h;    // Computed Parameter: Out1_Y0_h
                                          //  Referenced by: '<S86>/Out1'

  px4_Bus_actuator_armed Constant_Value_a;// Computed Parameter: Constant_Value_a
                                             //  Referenced by: '<S17>/Constant'

  px4_Bus_offboard_control_mode Out1_Y0_b;// Computed Parameter: Out1_Y0_b
                                             //  Referenced by: '<S88>/Out1'

  px4_Bus_offboard_control_mode Constant_Value_h1;// Computed Parameter: Constant_Value_h1
                                                     //  Referenced by: '<S19>/Constant'

  px4_Bus_operation_mode Constant_Value_j;// Computed Parameter: Constant_Value_j
                                             //  Referenced by: '<S96>/Constant'

  real_T tau_auto_Y0;                  // Computed Parameter: tau_auto_Y0
                                          //  Referenced by: '<S1>/tau_auto'

  real_T Constant_Value_jl;            // Expression: 0
                                          //  Referenced by: '<S1>/Constant'

  real_T UnitDelay2_InitialCondition;  // Expression: 0
                                          //  Referenced by: '<S10>/Unit Delay2'

  real_T Integrator3_gainval;         // Computed Parameter: Integrator3_gainval
                                         //  Referenced by: '<S10>/Integrator3'

  real_T Integrator3_IC;               // Expression: 0
                                          //  Referenced by: '<S10>/Integrator3'

  real_T TransferFcn1_NumCoef[2];
                          // Expression: [1.960784313725490 -1.960784313725490 ]
                             //  Referenced by: '<S10>/Transfer Fcn1'

  real_T TransferFcn1_DenCoef[2];
                           // Expression: [1.000000000000000 0.960784313725490 ]
                              //  Referenced by: '<S10>/Transfer Fcn1'

  real_T TransferFcn1_InitialStates;   // Expression: 0
                                          //  Referenced by: '<S10>/Transfer Fcn1'

  real_T Constant_Value_lu[4];         // Expression: [1 0 0 0]
                                          //  Referenced by: '<S25>/Constant'

  real_T Constant_Value_l4;            // Expression: 1
                                          //  Referenced by: '<S53>/Constant'

  real_T Constant_Value_d;             // Expression: 1
                                          //  Referenced by: '<S54>/Constant'

  real_T Constant_Value_c;             // Expression: 1
                                          //  Referenced by: '<S49>/Constant'

  real_T Constant_Value_co;            // Expression: 1
                                          //  Referenced by: '<S50>/Constant'

  real_T Constant1_Value;              // Expression: 0
                                          //  Referenced by: '<S59>/Constant1'

  real_T Constant1_Value_k;            // Expression: 0
                                          //  Referenced by: '<S57>/Constant1'

  real_T Bias1_Bias[9];                // Expression: -eye(3)
                                          //  Referenced by: '<S60>/Bias1'

  real_T Bias_Bias;                    // Expression: -1
                                          //  Referenced by: '<S61>/Bias'

  real_T Constant_Value_mv;            // Expression: 0
                                          //  Referenced by: '<S101>/Constant'

  real_T Constant_Value_dx;            // Expression: 0
                                          //  Referenced by: '<S100>/Constant'

  real_T Constant_Value_k;             // Expression: 0
                                          //  Referenced by: '<S102>/Constant'

  real_T Switch_Threshold;             // Expression: 0.5
                                          //  Referenced by: '<S95>/Switch'

  real_T Constant1_Value_l;            // Expression: 1
                                          //  Referenced by: '<S4>/Constant1'

  real_T Constant_Value_ds;            // Expression: 0
                                          //  Referenced by: '<S4>/Constant'

  real_T Gain4_Gain;                   // Expression: 1
                                          //  Referenced by: '<S6>/Gain4'

  real_T Constant_Value_hc;            // Expression: 0
                                          //  Referenced by: '<S108>/Constant'

  real_T Constant_Value_e;             // Expression: 0
                                          //  Referenced by: '<S109>/Constant'

  real_T Constant_Value_if;            // Expression: 0
                                          //  Referenced by: '<S112>/Constant'

  real_T Constant_Value_db;            // Expression: 0
                                          //  Referenced by: '<S113>/Constant'

  real_T Constant1_Value_h;            // Expression: 1
                                          //  Referenced by: '<S8>/Constant1'

  real_T Constant_Value_du;            // Expression: 0
                                          //  Referenced by: '<S8>/Constant'

  real_T Constant_Value_n;             // Expression: 0
                                          //  Referenced by: '<S110>/Constant'

  real_T Constant_Value_ft;            // Expression: 0
                                          //  Referenced by: '<S111>/Constant'

  real_T Constant_Value_bp;            // Expression: 0
                                          //  Referenced by: '<S114>/Constant'

  real_T Constant_Value_ex;            // Expression: 0
                                          //  Referenced by: '<S115>/Constant'

  real_T Switch_Threshold_o;           // Expression: 0
                                          //  Referenced by: '<S25>/Switch'

  real_T Gain_Gain;                    // Expression: 2
                                          //  Referenced by: '<S32>/Gain'

  real_T Gain_Gain_m;                  // Expression: 2
                                          //  Referenced by: '<S35>/Gain'

  real_T Gain_Gain_c;                  // Expression: 2
                                          //  Referenced by: '<S30>/Gain'

  real_T Gain_Gain_g;                  // Expression: 2
                                          //  Referenced by: '<S36>/Gain'

  real_T Gain_Gain_ge;                 // Expression: 2
                                          //  Referenced by: '<S31>/Gain'

  real_T Gain_Gain_e;                  // Expression: 2
                                          //  Referenced by: '<S34>/Gain'

  real_T Constant2_Value;              // Expression: 1
                                          //  Referenced by: '<S2>/Constant2'

  real_T Gain_Gain_co;                 // Expression: 2
                                          //  Referenced by: '<S74>/Gain'

  real_T Gain_Gain_e1;                 // Expression: 2
                                          //  Referenced by: '<S77>/Gain'

  real_T Gain_Gain_h;                  // Expression: 2
                                          //  Referenced by: '<S72>/Gain'

  real_T Gain_Gain_o;                  // Expression: 2
                                          //  Referenced by: '<S78>/Gain'

  real_T Gain_Gain_p;                  // Expression: 2
                                          //  Referenced by: '<S73>/Gain'

  real_T Gain_Gain_k;                  // Expression: 2
                                          //  Referenced by: '<S76>/Gain'

  real_T Gain1_Gain[3];                // Expression: [1 1 -1]
                                          //  Referenced by: '<S46>/Gain1'

  real_T Gain2_Gain[2];                // Expression: [1 1]
                                          //  Referenced by: '<S46>/Gain2'

  real_T Gain3_Gain[2];                // Expression: [-1 1]
                                          //  Referenced by: '<S46>/Gain3'

  real_T Constant2_Value_k[2];         // Expression: [-RC_min -RC_min]
                                          //  Referenced by: '<S7>/Constant2'

  real_T Gain1_Gain_o;                 // Expression: 2
                                          //  Referenced by: '<S7>/Gain1'

  real_T Constant_Value_dl[2];         // Expression: [-1 -1]
                                          //  Referenced by: '<S7>/Constant'

  real_T DeadZone_Start;               // Expression: -0.1
                                          //  Referenced by: '<S113>/Dead Zone'

  real_T DeadZone_End;                 // Expression: 0.1
                                          //  Referenced by: '<S113>/Dead Zone'

  real_T Constant4_Value;              // Expression: 0
                                          //  Referenced by: '<S7>/Constant4'

  real_T DeadZone_Start_o;             // Expression: -0.05
                                          //  Referenced by: '<S112>/Dead Zone'

  real_T DeadZone_End_h;               // Expression: 0.05
                                          //  Referenced by: '<S112>/Dead Zone'

  real_T Constant17_Value[3];          // Expression: [Fx_min Fy_min N_min]
                                          //  Referenced by: '<S6>/Constant17'

  real_T Constant16_Value[3];          // Expression: [Fx_max Fy_max N_max]
                                          //  Referenced by: '<S6>/Constant16'

  real_T Switch2_Threshold;            // Expression: 0
                                          //  Referenced by: '<S6>/Switch2'

  real_T Switch_Threshold_c;           // Expression: 0
                                          //  Referenced by: '<S6>/Switch'

  real_T DeadZone_Start_l;             // Expression: -33
                                          //  Referenced by: '<S108>/Dead Zone'

  real_T DeadZone_End_e;               // Expression: 33
                                          //  Referenced by: '<S108>/Dead Zone'

  real_T Saturation_UpperSat;          // Expression: 1900
                                          //  Referenced by: '<S6>/Saturation'

  real_T Saturation_LowerSat;          // Expression: 1100
                                          //  Referenced by: '<S6>/Saturation'

  real_T Constant1_Value_kc;           // Expression: 0
                                          //  Referenced by: '<Root>/Constant1'

  real_T DeadZone_Start_m;             // Expression: -33
                                          //  Referenced by: '<S109>/Dead Zone'

  real_T DeadZone_End_o;               // Expression: 33
                                          //  Referenced by: '<S109>/Dead Zone'

  real_T Saturation1_UpperSat;         // Expression: 1800
                                          //  Referenced by: '<S6>/Saturation1'

  real_T Saturation1_LowerSat;         // Expression: 1200
                                          //  Referenced by: '<S6>/Saturation1'

  uint16_T Switch_Threshold_a;         // Computed Parameter: Switch_Threshold_a
                                          //  Referenced by: '<S4>/Switch'

  uint16_T Switch_Threshold_i;         // Computed Parameter: Switch_Threshold_i
                                          //  Referenced by: '<S8>/Switch'

  boolean_T Assertion_Enabled;         // Computed Parameter: Assertion_Enabled
                                          //  Referenced by: '<S67>/Assertion'

  boolean_T Assertion_Enabled_h;      // Computed Parameter: Assertion_Enabled_h
                                         //  Referenced by: '<S65>/Assertion'

  boolean_T Assertion_Enabled_b;      // Computed Parameter: Assertion_Enabled_b
                                         //  Referenced by: '<S64>/Assertion'

  boolean_T Assertion_Enabled_k;      // Computed Parameter: Assertion_Enabled_k
                                         //  Referenced by: '<S62>/Assertion'

};

// Real-time Model Data Structure
struct tag_RTM_otter_2fixed_colA_mis_T {
  const char_T * volatile errorStatus;
  const char_T* getErrorStatus() const;
  void setErrorStatus(const char_T* const volatile aErrorStatus);
};

// Block parameters (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern P_otter_2fixed_colA_mission_2_T otter_2fixed_colA_mission_260_P;

#ifdef __cplusplus

}

#endif

// Block signals (default storage)
#ifdef __cplusplus

extern "C"
{

#endif

  extern struct B_otter_2fixed_colA_mission_2_T otter_2fixed_colA_mission_260_B;

#ifdef __cplusplus

}

#endif

// Block states (default storage)
extern struct DW_otter_2fixed_colA_mission__T otter_2fixed_colA_mission_26_DW;

#ifdef __cplusplus

extern "C"
{

#endif

  // Model entry point functions
  extern void otter_2fixed_colA_mission_260921_initialize(void);
  extern void otter_2fixed_colA_mission_260921_step(void);
  extern void otter_2fixed_colA_mission_260921_terminate(void);

#ifdef __cplusplus

}

#endif

// Real-time Model object
#ifdef __cplusplus

extern "C"
{

#endif

  extern RT_MODEL_otter_2fixed_colA_mi_T *const otter_2fixed_colA_mission_26_M;

#ifdef __cplusplus

}

#endif

extern volatile boolean_T stopRequested;
extern volatile boolean_T runModel;

//-
//  These blocks were eliminated from the model due to optimizations:
//
//  Block '<S15>/NOT' : Unused code path elimination
//  Block '<S16>/NOT' : Unused code path elimination
//  Block '<S17>/NOT' : Unused code path elimination
//  Block '<S18>/NOT' : Unused code path elimination
//  Block '<S19>/NOT' : Unused code path elimination
//  Block '<S20>/NOT' : Unused code path elimination
//  Block '<S21>/NOT' : Unused code path elimination
//  Block '<S22>/NOT' : Unused code path elimination
//  Block '<S23>/NOT' : Unused code path elimination
//  Block '<S24>/NOT' : Unused code path elimination
//  Block '<S5>/Bitwise Operator' : Unused code path elimination
//  Block '<S5>/Data Type Conversion' : Unused code path elimination
//  Block '<S5>/Data Type Conversion1' : Unused code path elimination
//  Block '<S5>/Data Type Conversion2' : Unused code path elimination
//  Block '<S5>/Gain' : Unused code path elimination
//  Block '<S5>/Gain1' : Unused code path elimination
//  Block '<S104>/NOT' : Unused code path elimination
//  Block '<S2>/Data Type Conversion4' : Eliminate redundant data type conversion
//  Block '<S12>/Data Type Conversion' : Eliminate redundant data type conversion
//  Block '<S12>/Data Type Conversion1' : Eliminate redundant data type conversion
//  Block '<S38>/Reshape (9) to [3x3] column-major' : Reshape block reduction
//  Block '<S46>/Reshape' : Reshape block reduction
//  Block '<S46>/Reshape1' : Reshape block reduction
//  Block '<S46>/Reshape2' : Reshape block reduction
//  Block '<S60>/Reshape' : Reshape block reduction
//  Block '<S69>/Reshape' : Reshape block reduction
//  Block '<S80>/Reshape (9) to [3x3] column-major' : Reshape block reduction


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
//  '<Root>' : 'otter_2fixed_colA_mission_260921'
//  '<S1>'   : 'otter_2fixed_colA_mission_260921/Controller'
//  '<S2>'   : 'otter_2fixed_colA_mission_260921/Estimator Output'
//  '<S3>'   : 'otter_2fixed_colA_mission_260921/Guidance1'
//  '<S4>'   : 'otter_2fixed_colA_mission_260921/RC on//off'
//  '<S5>'   : 'otter_2fixed_colA_mission_260921/Radio Control Transmitter1'
//  '<S6>'   : 'otter_2fixed_colA_mission_260921/Subsystem'
//  '<S7>'   : 'otter_2fixed_colA_mission_260921/input setting'
//  '<S8>'   : 'otter_2fixed_colA_mission_260921/on//off'
//  '<S9>'   : 'otter_2fixed_colA_mission_260921/Controller/Heading Controller'
//  '<S10>'  : 'otter_2fixed_colA_mission_260921/Controller/Surge Controller'
//  '<S11>'  : 'otter_2fixed_colA_mission_260921/Controller/Heading Controller/MATLAB Function'
//  '<S12>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation'
//  '<S13>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/MATLAB Function'
//  '<S14>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/MATLAB Function1'
//  '<S15>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read'
//  '<S16>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read1'
//  '<S17>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read2'
//  '<S18>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read3'
//  '<S19>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/offboard contol mode'
//  '<S20>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/position setpoint'
//  '<S21>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/position setpoint set'
//  '<S22>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_attitude'
//  '<S23>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_global_pos'
//  '<S24>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_local_pos'
//  '<S25>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternion Validity Check'
//  '<S26>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix'
//  '<S27>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles'
//  '<S28>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternion Validity Check/Quaternion Norm'
//  '<S29>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A11'
//  '<S30>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A12'
//  '<S31>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A13'
//  '<S32>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A21'
//  '<S33>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A22'
//  '<S34>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A23'
//  '<S35>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A31'
//  '<S36>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A32'
//  '<S37>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/A33'
//  '<S38>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Create 3x3 Matrix'
//  '<S39>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize'
//  '<S40>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus'
//  '<S41>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus/Quaternion Norm'
//  '<S42>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles'
//  '<S43>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix'
//  '<S44>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault'
//  '<S45>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3'
//  '<S46>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Get DCM Values'
//  '<S47>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM'
//  '<S48>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input'
//  '<S49>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem'
//  '<S50>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem1'
//  '<S51>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotDefault/Protect asincos input/If Action Subsystem2'
//  '<S52>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input'
//  '<S53>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem'
//  '<S54>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem1'
//  '<S55>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/AxisRotZeroR3/Protect asincos input/If Action Subsystem2'
//  '<S56>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error'
//  '<S57>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal'
//  '<S58>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else No Action'
//  '<S59>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper'
//  '<S60>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotOrthogonal'
//  '<S61>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper'
//  '<S62>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/Error'
//  '<S63>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/None'
//  '<S64>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/Else If Not Orthogonal/Warning'
//  '<S65>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/Error'
//  '<S66>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/None'
//  '<S67>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/If Not Proper/Warning'
//  '<S68>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotOrthogonal/transpose*dcm ~= eye(3)'
//  '<S69>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper/Determinant of 3x3 Matrix'
//  '<S70>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Direction Cosine Matrix to Rotation Angles/Validate DCM/If Warning//Error/isNotProper/determinant does not equal 1'
//  '<S71>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A11'
//  '<S72>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A12'
//  '<S73>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A13'
//  '<S74>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A21'
//  '<S75>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A22'
//  '<S76>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A23'
//  '<S77>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A31'
//  '<S78>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A32'
//  '<S79>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/A33'
//  '<S80>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Create 3x3 Matrix'
//  '<S81>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize'
//  '<S82>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus'
//  '<S83>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/Input Allocation/Quaternions to Rotation Angles/Quaternions to  Direction Cosine Matrix/Quaternion Normalize/Quaternion Modulus/Quaternion Norm'
//  '<S84>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read/Enabled Subsystem'
//  '<S85>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read1/Enabled Subsystem'
//  '<S86>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read2/Enabled Subsystem'
//  '<S87>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/PX4 uORB Read3/Enabled Subsystem'
//  '<S88>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/offboard contol mode/Enabled Subsystem'
//  '<S89>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/position setpoint/Enabled Subsystem'
//  '<S90>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/position setpoint set/Enabled Subsystem'
//  '<S91>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_attitude/Enabled Subsystem'
//  '<S92>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_global_pos/Enabled Subsystem'
//  '<S93>'  : 'otter_2fixed_colA_mission_260921/Estimator Output/vehicle_local_pos/Enabled Subsystem'
//  '<S94>'  : 'otter_2fixed_colA_mission_260921/Guidance1/Chart'
//  '<S95>'  : 'otter_2fixed_colA_mission_260921/Guidance1/Collision Avoidance'
//  '<S96>'  : 'otter_2fixed_colA_mission_260921/Guidance1/PX4 uORB Message'
//  '<S97>'  : 'otter_2fixed_colA_mission_260921/Guidance1/PX4 uORB Write'
//  '<S98>'  : 'otter_2fixed_colA_mission_260921/Guidance1/Waypoint following'
//  '<S99>'  : 'otter_2fixed_colA_mission_260921/Guidance1/Collision Avoidance/Atan2_guidance'
//  '<S100>' : 'otter_2fixed_colA_mission_260921/Guidance1/Collision Avoidance/valid_nan'
//  '<S101>' : 'otter_2fixed_colA_mission_260921/Guidance1/Collision Avoidance/valid_nan1'
//  '<S102>' : 'otter_2fixed_colA_mission_260921/Guidance1/Collision Avoidance/valid_nan2'
//  '<S103>' : 'otter_2fixed_colA_mission_260921/Guidance1/Waypoint following/Atan2_guidance'
//  '<S104>' : 'otter_2fixed_colA_mission_260921/Radio Control Transmitter1/PX4 uORB Read'
//  '<S105>' : 'otter_2fixed_colA_mission_260921/Radio Control Transmitter1/PX4 uORB Read/Enabled Subsystem'
//  '<S106>' : 'otter_2fixed_colA_mission_260921/Subsystem/MATLAB Function'
//  '<S107>' : 'otter_2fixed_colA_mission_260921/Subsystem/MATLAB Function1'
//  '<S108>' : 'otter_2fixed_colA_mission_260921/Subsystem/deadband'
//  '<S109>' : 'otter_2fixed_colA_mission_260921/Subsystem/deadband1'
//  '<S110>' : 'otter_2fixed_colA_mission_260921/Subsystem/deadband/Compare To Zero'
//  '<S111>' : 'otter_2fixed_colA_mission_260921/Subsystem/deadband1/Compare To Zero'
//  '<S112>' : 'otter_2fixed_colA_mission_260921/input setting/deadband1'
//  '<S113>' : 'otter_2fixed_colA_mission_260921/input setting/deadband4'
//  '<S114>' : 'otter_2fixed_colA_mission_260921/input setting/deadband1/Compare To Zero'
//  '<S115>' : 'otter_2fixed_colA_mission_260921/input setting/deadband4/Compare To Zero'

#endif                                 // otter_2fixed_colA_mission_260921_h_

//
// File trailer for generated code.
//
// [EOF]
//
