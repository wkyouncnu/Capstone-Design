//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_Loitering_mission_260921.cpp
//
// Code generated for Simulink model 'otter_2fixed_Loitering_mission_260921'.
//
// Model version                  : 6.98
// Simulink Coder version         : 24.2 (R2024b) 21-Jun-2024
// C/C++ source code generated on : Fri Oct  2 14:52:18 2026
//
// Target selection: ert.tlc
// Embedded hardware selection: ARM Compatible->ARM Cortex
// Code generation objectives: Unspecified
// Validation result: Not run
//
#include "otter_2fixed_Loitering_mission_260921.h"
#include "rtwtypes.h"
#include "otter_2fixed_Loitering_mission_260921_types.h"
#include "otter_2fixed_Loitering_mission_260921_private.h"
#include <math.h>

extern "C"
{

#include "rt_nonfinite.h"

}

#include "rt_assert.h"
#include <float.h>
#include "rt_defines.h"

// Named constants for Chart: '<S3>/Chart'
const uint8_T otter_2fixed_IN_NO_ACTIVE_CHILD = 0U;
const uint8_T otter_2fixed_Loiter_IN_MISSION1 = 1U;
const uint8_T otter_2fixed_Loiter_IN_MISSION2 = 2U;
const uint8_T otter_2fixed_Loiter_IN_MISSION3 = 3U;
const uint8_T otter_2fixed_Loiter_IN_MISSION4 = 4U;
const uint8_T otter_2fixed_Loiter_IN_MISSION5 = 5U;

// Named constants for Chart: '<S95>/Chart'
const uint8_T otter_2fixed_Loit_IN_ATAN2_MODE = 1U;
const uint8_T otter_2fixed__IN_LOITERING_MODE = 2U;

// Block signals (default storage)
B_otter_2fixed_Loitering_miss_T otter_2fixed_Loitering_missio_B;

// Block states (default storage)
DW_otter_2fixed_Loitering_mis_T otter_2fixed_Loitering_missi_DW;

// Real-time model
RT_MODEL_otter_2fixed_Loiteri_T otter_2fixed_Loitering_missi_M_ =
  RT_MODEL_otter_2fixed_Loiteri_T();
RT_MODEL_otter_2fixed_Loiteri_T *const otter_2fixed_Loitering_missi_M =
  &otter_2fixed_Loitering_missi_M_;

// Forward declaration for local functions
static real_T otter_2fixed_Loiter_rt_remd_snf(real_T u0, real_T u1);
static void otter_2fixed_Loitering_mis_cosd(real_T *x);
static void otter_2fixed_Loitering_mis_sind(real_T *x);
static void otter_2fixed_Loitering_lla2ecef(const real_T llaPos[3], real_T
  ecefPos[3]);
static void otter_2fixed_Loitering__lla2ned(const real_T lla[3], const real_T
  lla0[3], real_T xyzNED[3]);
static void otter_2fixed_Loit_PWM_setupImpl(px4_internal_block_PWM_otter__T *obj,
  boolean_T armPWM, boolean_T forceFailsafe);
real_T look1_binlxpw(real_T u0, const real_T bp0[], const real_T table[],
                     uint32_T maxIndex)
{
  real_T frac;
  real_T yL_0d0;
  uint32_T iLeft;

  // Column-major Lookup 1-D
  // Search method: 'binary'
  // Use previous index: 'off'
  // Interpolation method: 'Linear point-slope'
  // Extrapolation method: 'Linear'
  // Use last breakpoint for index at or above upper limit: 'off'
  // Remove protection against out-of-range input in generated code: 'off'

  // Prelookup - Index and Fraction
  // Index Search method: 'binary'
  // Extrapolation method: 'Linear'
  // Use previous index: 'off'
  // Use last breakpoint for index at or above upper limit: 'off'
  // Remove protection against out-of-range input in generated code: 'off'

  if (u0 <= bp0[0U]) {
    iLeft = 0U;
    frac = (u0 - bp0[0U]) / (bp0[1U] - bp0[0U]);
  } else if (u0 < bp0[maxIndex]) {
    uint32_T bpIdx;
    uint32_T iRght;

    // Binary Search
    bpIdx = maxIndex >> 1U;
    iLeft = 0U;
    iRght = maxIndex;
    while (iRght - iLeft > 1U) {
      if (u0 < bp0[bpIdx]) {
        iRght = bpIdx;
      } else {
        iLeft = bpIdx;
      }

      bpIdx = (iRght + iLeft) >> 1U;
    }

    frac = (u0 - bp0[iLeft]) / (bp0[iLeft + 1U] - bp0[iLeft]);
  } else {
    iLeft = maxIndex - 1U;
    frac = (u0 - bp0[maxIndex - 1U]) / (bp0[maxIndex] - bp0[maxIndex - 1U]);
  }

  // Column-major Interpolation 1-D
  // Interpolation method: 'Linear point-slope'
  // Use last breakpoint for index at or above upper limit: 'off'
  // Overflow mode: 'portable wrapping'

  yL_0d0 = table[iLeft];
  return (table[iLeft + 1U] - yL_0d0) * frac + yL_0d0;
}

real_T rt_atan2d_snf(real_T u0, real_T u1)
{
  real_T y;
  if (rtIsNaN(u0) || rtIsNaN(u1)) {
    y = (rtNaN);
  } else if (rtIsInf(u0) && rtIsInf(u1)) {
    int32_T tmp;
    int32_T tmp_0;
    if (u0 > 0.0) {
      tmp = 1;
    } else {
      tmp = -1;
    }

    if (u1 > 0.0) {
      tmp_0 = 1;
    } else {
      tmp_0 = -1;
    }

    y = atan2(static_cast<real_T>(tmp), static_cast<real_T>(tmp_0));
  } else if (u1 == 0.0) {
    if (u0 > 0.0) {
      y = RT_PI / 2.0;
    } else if (u0 < 0.0) {
      y = -(RT_PI / 2.0);
    } else {
      y = 0.0;
    }
  } else {
    y = atan2(u0, u1);
  }

  return y;
}

//
// Output and update for atomic system:
//    '<S98>/Atan2_guidance'
//    '<S95>/Atan2_guidance'
//
void otter_2fixed_Loi_Atan2_guidance(real_T rtu_pn, real_T rtu_pe, real_T
  rtu_wp_x, real_T rtu_wp_y, real_T rtu_u_setpoint, boolean_T rtu_mission_done,
  real_T *rty_u_ref, real_T *rty_psi_ref, real_T *rty_dist)
{
  real_T e_diff;
  real_T n_diff;
  *rty_u_ref = rtu_u_setpoint;
  n_diff = rtu_wp_x - rtu_pn;
  e_diff = rtu_wp_y - rtu_pe;
  *rty_dist = n_diff * n_diff + e_diff * e_diff;
  *rty_dist = sqrt(*rty_dist);
  if (rtu_mission_done) {
    *rty_u_ref = 0.0;
    *rty_psi_ref = 0.0;
  } else {
    *rty_psi_ref = rt_atan2d_snf(e_diff, n_diff);
  }
}

static real_T otter_2fixed_Loiter_rt_remd_snf(real_T u0, real_T u1)
{
  real_T y;
  if (rtIsNaN(u0) || rtIsNaN(u1) || rtIsInf(u0)) {
    y = (rtNaN);
  } else if (rtIsInf(u1)) {
    y = u0;
  } else {
    if (u1 < 0.0) {
      otter_2fixed_Loitering_missio_B.q = ceil(u1);
    } else {
      otter_2fixed_Loitering_missio_B.q = floor(u1);
    }

    if ((u1 != 0.0) && (u1 != otter_2fixed_Loitering_missio_B.q)) {
      otter_2fixed_Loitering_missio_B.q = fabs(u0 / u1);
      if (!(fabs(otter_2fixed_Loitering_missio_B.q - floor
                 (otter_2fixed_Loitering_missio_B.q + 0.5)) > DBL_EPSILON *
            otter_2fixed_Loitering_missio_B.q)) {
        y = 0.0 * u0;
      } else {
        y = fmod(u0, u1);
      }
    } else {
      y = fmod(u0, u1);
    }
  }

  return y;
}

// Function for MATLAB Function: '<S2>/MATLAB Function'
static void otter_2fixed_Loitering_mis_cosd(real_T *x)
{
  int8_T n;
  if (rtIsInf(*x) || rtIsNaN(*x)) {
    *x = (rtNaN);
  } else {
    otter_2fixed_Loitering_missio_B.b_x_c = otter_2fixed_Loiter_rt_remd_snf(*x,
      360.0);
    otter_2fixed_Loitering_missio_B.absx_f = fabs
      (otter_2fixed_Loitering_missio_B.b_x_c);
    if (otter_2fixed_Loitering_missio_B.absx_f > 180.0) {
      if (otter_2fixed_Loitering_missio_B.b_x_c > 0.0) {
        otter_2fixed_Loitering_missio_B.b_x_c -= 360.0;
      } else {
        otter_2fixed_Loitering_missio_B.b_x_c += 360.0;
      }

      otter_2fixed_Loitering_missio_B.absx_f = fabs
        (otter_2fixed_Loitering_missio_B.b_x_c);
    }

    if (otter_2fixed_Loitering_missio_B.absx_f <= 45.0) {
      otter_2fixed_Loitering_missio_B.b_x_c *= 0.017453292519943295;
      n = 0;
    } else if (otter_2fixed_Loitering_missio_B.absx_f <= 135.0) {
      if (otter_2fixed_Loitering_missio_B.b_x_c > 0.0) {
        otter_2fixed_Loitering_missio_B.b_x_c =
          (otter_2fixed_Loitering_missio_B.b_x_c - 90.0) * 0.017453292519943295;
        n = 1;
      } else {
        otter_2fixed_Loitering_missio_B.b_x_c =
          (otter_2fixed_Loitering_missio_B.b_x_c + 90.0) * 0.017453292519943295;
        n = -1;
      }
    } else if (otter_2fixed_Loitering_missio_B.b_x_c > 0.0) {
      otter_2fixed_Loitering_missio_B.b_x_c =
        (otter_2fixed_Loitering_missio_B.b_x_c - 180.0) * 0.017453292519943295;
      n = 2;
    } else {
      otter_2fixed_Loitering_missio_B.b_x_c =
        (otter_2fixed_Loitering_missio_B.b_x_c + 180.0) * 0.017453292519943295;
      n = -2;
    }

    switch (n) {
     case 0:
      *x = cos(otter_2fixed_Loitering_missio_B.b_x_c);
      break;

     case 1:
      *x = -sin(otter_2fixed_Loitering_missio_B.b_x_c);
      break;

     case -1:
      *x = sin(otter_2fixed_Loitering_missio_B.b_x_c);
      break;

     default:
      *x = -cos(otter_2fixed_Loitering_missio_B.b_x_c);
      break;
    }
  }
}

// Function for MATLAB Function: '<S2>/MATLAB Function'
static void otter_2fixed_Loitering_mis_sind(real_T *x)
{
  int8_T n;
  if (rtIsInf(*x) || rtIsNaN(*x)) {
    *x = (rtNaN);
  } else {
    otter_2fixed_Loitering_missio_B.b_x = otter_2fixed_Loiter_rt_remd_snf(*x,
      360.0);
    otter_2fixed_Loitering_missio_B.absx = fabs
      (otter_2fixed_Loitering_missio_B.b_x);
    if (otter_2fixed_Loitering_missio_B.absx > 180.0) {
      if (otter_2fixed_Loitering_missio_B.b_x > 0.0) {
        otter_2fixed_Loitering_missio_B.b_x -= 360.0;
      } else {
        otter_2fixed_Loitering_missio_B.b_x += 360.0;
      }

      otter_2fixed_Loitering_missio_B.absx = fabs
        (otter_2fixed_Loitering_missio_B.b_x);
    }

    if (otter_2fixed_Loitering_missio_B.absx <= 45.0) {
      otter_2fixed_Loitering_missio_B.b_x *= 0.017453292519943295;
      n = 0;
    } else if (otter_2fixed_Loitering_missio_B.absx <= 135.0) {
      if (otter_2fixed_Loitering_missio_B.b_x > 0.0) {
        otter_2fixed_Loitering_missio_B.b_x =
          (otter_2fixed_Loitering_missio_B.b_x - 90.0) * 0.017453292519943295;
        n = 1;
      } else {
        otter_2fixed_Loitering_missio_B.b_x =
          (otter_2fixed_Loitering_missio_B.b_x + 90.0) * 0.017453292519943295;
        n = -1;
      }
    } else if (otter_2fixed_Loitering_missio_B.b_x > 0.0) {
      otter_2fixed_Loitering_missio_B.b_x = (otter_2fixed_Loitering_missio_B.b_x
        - 180.0) * 0.017453292519943295;
      n = 2;
    } else {
      otter_2fixed_Loitering_missio_B.b_x = (otter_2fixed_Loitering_missio_B.b_x
        + 180.0) * 0.017453292519943295;
      n = -2;
    }

    switch (n) {
     case 0:
      *x = sin(otter_2fixed_Loitering_missio_B.b_x);
      break;

     case 1:
      *x = cos(otter_2fixed_Loitering_missio_B.b_x);
      break;

     case -1:
      *x = -cos(otter_2fixed_Loitering_missio_B.b_x);
      break;

     default:
      *x = -sin(otter_2fixed_Loitering_missio_B.b_x);
      break;
    }
  }
}

// Function for MATLAB Function: '<S2>/MATLAB Function'
static void otter_2fixed_Loitering_lla2ecef(const real_T llaPos[3], real_T
  ecefPos[3])
{
  otter_2fixed_Loitering_missio_B.sinphi_b = llaPos[0];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.sinphi_b);
  otter_2fixed_Loitering_missio_B.N_p = 6.378137E+6 / sqrt(1.0 -
    otter_2fixed_Loitering_missio_B.sinphi_b *
    otter_2fixed_Loitering_missio_B.sinphi_b * 0.0066943799901413165);
  otter_2fixed_Loitering_missio_B.b = llaPos[0];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.b);
  otter_2fixed_Loitering_missio_B.b *= otter_2fixed_Loitering_missio_B.N_p +
    llaPos[2];
  otter_2fixed_Loitering_missio_B.c = llaPos[1];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.c);
  otter_2fixed_Loitering_missio_B.d = llaPos[1];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.d);
  ecefPos[0] = otter_2fixed_Loitering_missio_B.b *
    otter_2fixed_Loitering_missio_B.c;
  ecefPos[1] = otter_2fixed_Loitering_missio_B.b *
    otter_2fixed_Loitering_missio_B.d;
  ecefPos[2] = (otter_2fixed_Loitering_missio_B.N_p * 0.99330562000985867 +
                llaPos[2]) * otter_2fixed_Loitering_missio_B.sinphi_b;
}

// Function for MATLAB Function: '<S2>/MATLAB Function1'
static void otter_2fixed_Loitering__lla2ned(const real_T lla[3], const real_T
  lla0[3], real_T xyzNED[3])
{
  otter_2fixed_Loitering_missio_B.cosphi = lla0[0];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.cosphi);
  otter_2fixed_Loitering_missio_B.sinphi_c = lla0[0];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.sinphi_c);
  otter_2fixed_Loitering_missio_B.coslambda_k = lla0[1];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.coslambda_k);
  otter_2fixed_Loitering_missio_B.sinlambda_c = lla0[1];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.sinlambda_c);
  otter_2fixed_Loitering_lla2ecef(lla, otter_2fixed_Loitering_missio_B.dv1);
  otter_2fixed_Loitering_lla2ecef(lla0, otter_2fixed_Loitering_missio_B.dv2);
  otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_0 =
    otter_2fixed_Loitering_missio_B.dv1[0] -
    otter_2fixed_Loitering_missio_B.dv2[0];
  otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_1 =
    otter_2fixed_Loitering_missio_B.dv1[1] -
    otter_2fixed_Loitering_missio_B.dv2[1];
  otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_2 =
    otter_2fixed_Loitering_missio_B.dv1[2] -
    otter_2fixed_Loitering_missio_B.dv2[2];
  otter_2fixed_Loitering_missio_B.tmp =
    otter_2fixed_Loitering_missio_B.coslambda_k *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_0 +
    otter_2fixed_Loitering_missio_B.sinlambda_c *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_1;
  xyzNED[0] = -otter_2fixed_Loitering_missio_B.sinphi_c *
    otter_2fixed_Loitering_missio_B.tmp + otter_2fixed_Loitering_missio_B.cosphi
    * otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_2;
  xyzNED[1] = -otter_2fixed_Loitering_missio_B.sinlambda_c *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_0 +
    otter_2fixed_Loitering_missio_B.coslambda_k *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_1;
  xyzNED[2] = -(otter_2fixed_Loitering_missio_B.cosphi *
                otter_2fixed_Loitering_missio_B.tmp +
                otter_2fixed_Loitering_missio_B.sinphi_c *
                otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin_idx_2);
}

static void otter_2fixed_Loit_PWM_setupImpl(px4_internal_block_PWM_otter__T *obj,
  boolean_T armPWM, boolean_T forceFailsafe)
{
  obj->isMain = true;
  pwm_open(&obj->actuatorAdvertiseObj, &obj->armAdvertiseObj);
  obj->servoCount = 8;
  if (armPWM) {
    pwm_arm(&obj->armAdvertiseObj);
    obj->isArmed = true;
  } else {
    pwm_disarm(&obj->armAdvertiseObj);
    obj->isArmed = false;
  }

  obj->channelMask = 3;
  if (obj->isMain) {
    if (forceFailsafe) {
      pwm_disarm(&obj->armAdvertiseObj);
    } else {
      pwm_arm(&obj->armAdvertiseObj);
    }
  }
}

// Model step function
void otter_2fixed_Loitering_mission_260921_step(void)
{
  int32_T loiter_done;
  int32_T rtb_loiter_mode;
  int32_T rtb_loiter_used;
  int32_T rtb_operation_mode;
  real32_T ParamStep;
  real32_T ParamStep_0;
  real32_T ParamStep_1;
  int8_T rtPrevAction;
  boolean_T rEQ0;

  // MATLABSystem: '<S22>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_f.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_f.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r7, false, 1.0);

  // Outputs for Enabled SubSystem: '<S22>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S91>/Enable'

  // Start for MATLABSystem: '<S22>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S91>/In1'
    otter_2fixed_Loitering_missio_B.In1_du = otter_2fixed_Loitering_missio_B.r7;
  }

  // End of Outputs for SubSystem: '<S22>/Enabled Subsystem'

  // DataTypeConversion: '<S2>/Data Type Conversion3' incorporates:
  //   Switch: '<S25>/Switch'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
    otter_2fixed_Loitering_missio_B.In1_du.q[0];
  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 =
    otter_2fixed_Loitering_missio_B.In1_du.q[1];
  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 =
    otter_2fixed_Loitering_missio_B.In1_du.q[2];
  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 =
    otter_2fixed_Loitering_missio_B.In1_du.q[3];

  // Switch: '<S25>/Switch' incorporates:
  //   Constant: '<S25>/Constant'
  //   DataTypeConversion: '<S2>/Data Type Conversion3'
  //   Product: '<S28>/Product'
  //   Product: '<S28>/Product1'
  //   Product: '<S28>/Product2'
  //   Product: '<S28>/Product3'
  //   Sum: '<S28>/Sum'

  if (!(((static_cast<real_T>(otter_2fixed_Loitering_missio_B.In1_du.q[0]) *
          otter_2fixed_Loitering_missio_B.In1_du.q[0] + static_cast<real_T>
          (otter_2fixed_Loitering_missio_B.In1_du.q[1]) *
          otter_2fixed_Loitering_missio_B.In1_du.q[1]) + static_cast<real_T>
         (otter_2fixed_Loitering_missio_B.In1_du.q[2]) *
         otter_2fixed_Loitering_missio_B.In1_du.q[2]) + static_cast<real_T>
        (otter_2fixed_Loitering_missio_B.In1_du.q[3]) *
        otter_2fixed_Loitering_missio_B.In1_du.q[3] >
        otter_2fixed_Loitering_missio_P.Switch_Threshold)) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_P.Constant_Value_lu[0];
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 =
      otter_2fixed_Loitering_missio_P.Constant_Value_lu[1];
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 =
      otter_2fixed_Loitering_missio_P.Constant_Value_lu[2];
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 =
      otter_2fixed_Loitering_missio_P.Constant_Value_lu[3];
  }

  // End of Switch: '<S25>/Switch'

  // MATLABSystem: '<S24>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_o.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_o.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r1, false, 1.0);

  // Outputs for Enabled SubSystem: '<S24>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S93>/Enable'

  // Start for MATLABSystem: '<S24>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S93>/In1'
    otter_2fixed_Loitering_missio_B.In1_n = otter_2fixed_Loitering_missio_B.r1;
  }

  // End of Outputs for SubSystem: '<S24>/Enabled Subsystem'

  // Sqrt: '<S40>/sqrt' incorporates:
  //   Product: '<S41>/Product'
  //   Product: '<S41>/Product1'
  //   Product: '<S41>/Product2'
  //   Product: '<S41>/Product3'
  //   Sqrt: '<S82>/sqrt'
  //   Sum: '<S41>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp = sqrt
    (((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 *
       otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
       otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 *
       otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1) +
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 *
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2) +
     otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 *
     otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3);

  // Product: '<S39>/Product' incorporates:
  //   Product: '<S81>/Product'
  //   Sqrt: '<S40>/sqrt'

  otter_2fixed_Loitering_missio_B.Add =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 /
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Product: '<S39>/Product1' incorporates:
  //   Product: '<S81>/Product1'
  //   Sqrt: '<S40>/sqrt'

  otter_2fixed_Loitering_missio_B.sinphi =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 /
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Product: '<S39>/Product2' incorporates:
  //   Product: '<S81>/Product2'
  //   Sqrt: '<S40>/sqrt'

  otter_2fixed_Loitering_missio_B.r_dot =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 /
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Product: '<S39>/Product3' incorporates:
  //   Product: '<S81>/Product3'
  //   Sqrt: '<S40>/sqrt'

  otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 /
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Product: '<S29>/Product3' incorporates:
  //   Product: '<S33>/Product3'
  //   Product: '<S39>/Product'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 =
    otter_2fixed_Loitering_missio_B.Add * otter_2fixed_Loitering_missio_B.Add;

  // Product: '<S29>/Product2' incorporates:
  //   Product: '<S33>/Product2'
  //   Product: '<S39>/Product1'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 =
    otter_2fixed_Loitering_missio_B.sinphi *
    otter_2fixed_Loitering_missio_B.sinphi;

  // Product: '<S29>/Product1' incorporates:
  //   Product: '<S33>/Product1'
  //   Product: '<S37>/Product1'
  //   Product: '<S39>/Product2'

  otter_2fixed_Loitering_missio_B.enuPos_idx_0 =
    otter_2fixed_Loitering_missio_B.r_dot *
    otter_2fixed_Loitering_missio_B.r_dot;

  // Product: '<S29>/Product' incorporates:
  //   Product: '<S33>/Product'
  //   Product: '<S37>/Product'
  //   Product: '<S39>/Product3'

  otter_2fixed_Loitering_missio_B.coslambda =
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp *
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Sum: '<S29>/Sum' incorporates:
  //   Product: '<S29>/Product'
  //   Product: '<S29>/Product1'
  //   Product: '<S29>/Product2'
  //   Product: '<S29>/Product3'
  //   Sum: '<S71>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 =
    ((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 +
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2) -
     otter_2fixed_Loitering_missio_B.enuPos_idx_0) -
    otter_2fixed_Loitering_missio_B.coslambda;
  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[0] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1;

  // Product: '<S32>/Product3' incorporates:
  //   Product: '<S30>/Product3'
  //   Product: '<S39>/Product'
  //   Product: '<S39>/Product3'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp *
    otter_2fixed_Loitering_missio_B.Add;

  // Product: '<S32>/Product2' incorporates:
  //   Product: '<S30>/Product2'
  //   Product: '<S39>/Product1'
  //   Product: '<S39>/Product2'

  otter_2fixed_Loitering_missio_B.TransferFcn1_tmp =
    otter_2fixed_Loitering_missio_B.sinphi *
    otter_2fixed_Loitering_missio_B.r_dot;

  // Sum: '<S32>/Sum' incorporates:
  //   Product: '<S32>/Product2'
  //   Product: '<S32>/Product3'
  //   Sum: '<S74>/Sum'

  otter_2fixed_Loitering_missio_B.Sum_jw =
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp -
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0;

  // Gain: '<S32>/Gain' incorporates:
  //   Sum: '<S32>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[1] =
    otter_2fixed_Loitering_missio_B.Sum_jw *
    otter_2fixed_Loitering_missio_P.Gain_Gain;

  // Product: '<S35>/Product2' incorporates:
  //   Product: '<S31>/Product2'
  //   Product: '<S39>/Product1'
  //   Product: '<S39>/Product3'

  otter_2fixed_Loitering_missio_B.Fx_unsat =
    otter_2fixed_Loitering_missio_B.sinphi *
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Product: '<S35>/Product1' incorporates:
  //   Product: '<S31>/Product1'
  //   Product: '<S39>/Product'
  //   Product: '<S39>/Product2'

  otter_2fixed_Loitering_missio_B.sinlambda =
    otter_2fixed_Loitering_missio_B.Add * otter_2fixed_Loitering_missio_B.r_dot;

  // Sum: '<S35>/Sum' incorporates:
  //   Product: '<S35>/Product1'
  //   Product: '<S35>/Product2'
  //   Sum: '<S77>/Sum'

  otter_2fixed_Loitering_missio_B.Fx_sat =
    otter_2fixed_Loitering_missio_B.sinlambda +
    otter_2fixed_Loitering_missio_B.Fx_unsat;

  // Gain: '<S35>/Gain' incorporates:
  //   Sum: '<S35>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[2] =
    otter_2fixed_Loitering_missio_B.Fx_sat *
    otter_2fixed_Loitering_missio_P.Gain_Gain_m;

  // Sum: '<S30>/Sum' incorporates:
  //   Sum: '<S72>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +=
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;

  // Gain: '<S30>/Gain' incorporates:
  //   Sum: '<S30>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[3] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 *
    otter_2fixed_Loitering_missio_P.Gain_Gain_c;

  // Sum: '<S33>/Sum' incorporates:
  //   Sum: '<S37>/Sum'
  //   Sum: '<S75>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 -=
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2;
  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 =
    (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 +
     otter_2fixed_Loitering_missio_B.enuPos_idx_0) -
    otter_2fixed_Loitering_missio_B.coslambda;
  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[4] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2;

  // Product: '<S36>/Product1' incorporates:
  //   Product: '<S34>/Product1'
  //   Product: '<S39>/Product'
  //   Product: '<S39>/Product1'

  otter_2fixed_Loitering_missio_B.TransferFcn1_tmp =
    otter_2fixed_Loitering_missio_B.Add * otter_2fixed_Loitering_missio_B.sinphi;

  // Product: '<S36>/Product2' incorporates:
  //   Product: '<S34>/Product2'
  //   Product: '<S39>/Product2'
  //   Product: '<S39>/Product3'

  otter_2fixed_Loitering_missio_B.Add = otter_2fixed_Loitering_missio_B.r_dot *
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp;

  // Sum: '<S36>/Sum' incorporates:
  //   Product: '<S36>/Product1'
  //   Product: '<S36>/Product2'
  //   Sum: '<S78>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp =
    otter_2fixed_Loitering_missio_B.Add -
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;

  // Gain: '<S36>/Gain' incorporates:
  //   Sum: '<S36>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[5] =
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp *
    otter_2fixed_Loitering_missio_P.Gain_Gain_g;

  // Sum: '<S31>/Sum' incorporates:
  //   Sum: '<S73>/Sum'

  otter_2fixed_Loitering_missio_B.Fx_unsat -=
    otter_2fixed_Loitering_missio_B.sinlambda;

  // Gain: '<S31>/Gain' incorporates:
  //   Sum: '<S31>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[6] =
    otter_2fixed_Loitering_missio_B.Fx_unsat *
    otter_2fixed_Loitering_missio_P.Gain_Gain_ge;

  // Sum: '<S34>/Sum' incorporates:
  //   Sum: '<S76>/Sum'

  otter_2fixed_Loitering_missio_B.TransferFcn1_tmp +=
    otter_2fixed_Loitering_missio_B.Add;

  // Gain: '<S34>/Gain' incorporates:
  //   Sum: '<S34>/Sum'

  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[7] =
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp *
    otter_2fixed_Loitering_missio_P.Gain_Gain_e;

  // Sum: '<S37>/Sum' incorporates:
  //   Sum: '<S79>/Sum'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 =
    (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 -
     otter_2fixed_Loitering_missio_B.enuPos_idx_0) +
    otter_2fixed_Loitering_missio_B.coslambda;
  otter_2fixed_Loitering_missio_B.VectorConcatenate_e[8] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3;

  // MATLABSystem: '<S17>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_e.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_e.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r9, false, 1.0);

  // Outputs for Enabled SubSystem: '<S17>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S86>/Enable'

  // Start for MATLABSystem: '<S17>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S86>/In1'
    otter_2fixed_Loitering_missio_B.In1_p = otter_2fixed_Loitering_missio_B.r9;
  }

  // End of Outputs for SubSystem: '<S17>/Enabled Subsystem'

  // MATLABSystem: '<S15>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_nu.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_nu.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r8, false, 1.0);

  // Outputs for Enabled SubSystem: '<S15>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S84>/Enable'

  // Start for MATLABSystem: '<S15>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S84>/In1'
    otter_2fixed_Loitering_missio_B.In1_i = otter_2fixed_Loitering_missio_B.r8;
  }

  // End of Outputs for SubSystem: '<S15>/Enabled Subsystem'

  // Sum: '<S2>/Add' incorporates:
  //   Constant: '<S2>/Constant2'

  otter_2fixed_Loitering_missio_B.Add =
    otter_2fixed_Loitering_missio_P.Constant2_Value + static_cast<real_T>
    (otter_2fixed_Loitering_missio_B.In1_i.seq_current);

  // Chart: '<S3>/Chart'
  if (otter_2fixed_Loitering_missi_DW.is_active_c3_otter_2fixed_Loite == 0) {
    otter_2fixed_Loitering_missi_DW.is_active_c3_otter_2fixed_Loite = 1U;
    otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
      otter_2fixed_Loiter_IN_MISSION1;
    rtb_operation_mode = 1;
  } else {
    switch (otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi) {
     case otter_2fixed_Loiter_IN_MISSION1:
      rtb_operation_mode = 1;
      if (otter_2fixed_Loitering_missio_B.Add == 2.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION2;
      } else if (otter_2fixed_Loitering_missio_B.Add == 3.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION3;
        rtb_operation_mode = 2;
      } else if (otter_2fixed_Loitering_missio_B.Add == 4.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION4;
      } else if (otter_2fixed_Loitering_missio_B.Add == 5.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION5;
      }
      break;

     case otter_2fixed_Loiter_IN_MISSION2:
      rtb_operation_mode = 1;
      if (otter_2fixed_Loitering_missio_B.Add == 3.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION3;
        rtb_operation_mode = 2;
      } else if (otter_2fixed_Loitering_missio_B.Add == 1.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION1;
      } else if (otter_2fixed_Loitering_missio_B.Add == 4.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION4;
      } else if (otter_2fixed_Loitering_missio_B.Add == 5.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION5;
      }
      break;

     case otter_2fixed_Loiter_IN_MISSION3:
      rtb_operation_mode = 2;
      if (otter_2fixed_Loitering_missio_B.Add == 4.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION4;
        rtb_operation_mode = 1;
      } else if (otter_2fixed_Loitering_missio_B.Add == 1.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION1;
        rtb_operation_mode = 1;
      } else if (otter_2fixed_Loitering_missio_B.Add == 5.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION5;
        rtb_operation_mode = 1;
      }
      break;

     case otter_2fixed_Loiter_IN_MISSION4:
      rtb_operation_mode = 1;
      if (otter_2fixed_Loitering_missio_B.Add == 1.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION1;
      } else if (otter_2fixed_Loitering_missio_B.Add == 5.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION5;
      }
      break;

     default:
      // case IN_MISSION5:
      rtb_operation_mode = 1;
      if (otter_2fixed_Loitering_missio_B.Add == 1.0) {
        otter_2fixed_Loitering_missi_DW.is_c3_otter_2fixed_Loitering_mi =
          otter_2fixed_Loiter_IN_MISSION1;
      }
      break;
    }
  }

  // End of Chart: '<S3>/Chart'

  // MATLABSystem: '<S23>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_k.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_k.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r6, false, 1.0);

  // Outputs for Enabled SubSystem: '<S23>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S92>/Enable'

  // Start for MATLABSystem: '<S23>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S92>/In1'
    otter_2fixed_Loitering_missio_B.In1_e = otter_2fixed_Loitering_missio_B.r6;
  }

  // End of Outputs for SubSystem: '<S23>/Enabled Subsystem'

  // MATLAB Function: '<S2>/MATLAB Function' incorporates:
  //   Constant: '<S2>/Constant'

  otter_2fixed_Loitering_missio_B.Add = otter_2fixed_Loitering_missio_P.ref_lla
    [0];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.Add);
  otter_2fixed_Loitering_missio_B.sinphi =
    otter_2fixed_Loitering_missio_P.ref_lla[0];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.sinphi);
  otter_2fixed_Loitering_missio_B.coslambda =
    otter_2fixed_Loitering_missio_P.ref_lla[1];
  otter_2fixed_Loitering_mis_cosd(&otter_2fixed_Loitering_missio_B.coslambda);
  otter_2fixed_Loitering_missio_B.sinlambda =
    otter_2fixed_Loitering_missio_P.ref_lla[1];
  otter_2fixed_Loitering_mis_sind(&otter_2fixed_Loitering_missio_B.sinlambda);
  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[0] =
    otter_2fixed_Loitering_missio_B.In1_e.lat;
  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[1] =
    otter_2fixed_Loitering_missio_B.In1_e.lon;
  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[2] = 0.0;
  otter_2fixed_Loitering_lla2ecef
    (otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m,
     otter_2fixed_Loitering_missio_B.dv);
  otter_2fixed_Loitering_lla2ecef(otter_2fixed_Loitering_missio_P.ref_lla,
    otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m);
  otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0] =
    otter_2fixed_Loitering_missio_B.dv[0] -
    otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[0];
  otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1] =
    otter_2fixed_Loitering_missio_B.dv[1] -
    otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[1];
  otter_2fixed_Loitering_missio_B.enuPos_idx_0 =
    -otter_2fixed_Loitering_missio_B.sinlambda *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0] +
    otter_2fixed_Loitering_missio_B.coslambda *
    otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1];
  otter_2fixed_Loitering_missio_B.coslambda =
    (otter_2fixed_Loitering_missio_B.coslambda *
     otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0] +
     otter_2fixed_Loitering_missio_B.sinlambda *
     otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1]) *
    -otter_2fixed_Loitering_missio_B.sinphi +
    (otter_2fixed_Loitering_missio_B.dv[2] -
     otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[2]) *
    otter_2fixed_Loitering_missio_B.Add;

  // MATLABSystem: '<S21>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_a.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_a.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r, false, 1.0);

  // Outputs for Enabled SubSystem: '<S21>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S90>/Enable'

  // Start for MATLABSystem: '<S21>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S90>/In1'
    otter_2fixed_Loitering_missio_B.In1 = otter_2fixed_Loitering_missio_B.r;
  }

  // End of Outputs for SubSystem: '<S21>/Enabled Subsystem'

  // MATLAB Function: '<S2>/MATLAB Function1' incorporates:
  //   Constant: '<S2>/Constant1'
  //   SignalConversion generated from: '<S14>/ SFunction '

  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[0] =
    otter_2fixed_Loitering_missio_B.In1.current.lat;
  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[1] =
    otter_2fixed_Loitering_missio_B.In1.current.lon;
  otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[2] = 0.0;
  otter_2fixed_Loitering__lla2ned
    (otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m,
     otter_2fixed_Loitering_missio_P.ref_lla,
     otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin);

  // MATLABSystem: '<S3>/Read Parameter1'
  rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_fl.MW_PARAMHANDLE,
                       MW_SINGLE, &otter_2fixed_Loitering_missio_B.ParamStep);
  if (rEQ0) {
    otter_2fixed_Loitering_missio_B.ParamStep = 0.0F;
  }

  // MATLABSystem: '<S3>/Read Parameter2'
  rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_d.MW_PARAMHANDLE,
                       MW_SINGLE, &ParamStep);
  if (rEQ0) {
    ParamStep = 0.0F;
  }

  // MATLABSystem: '<S3>/Read Parameter3'
  rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_nw.MW_PARAMHANDLE,
                       MW_SINGLE, &ParamStep_0);
  if (rEQ0) {
    ParamStep_0 = 0.0F;
  }

  // MATLABSystem: '<S3>/Read Parameter'
  rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_l.MW_PARAMHANDLE,
                       MW_SINGLE, &ParamStep_1);
  if (rEQ0) {
    ParamStep_1 = 0.0F;
  }

  // If: '<S3>/If'
  rtPrevAction = otter_2fixed_Loitering_missi_DW.If_ActiveSubsystem;
  otter_2fixed_Loitering_missi_DW.If_ActiveSubsystem = static_cast<int8_T>
    (rtb_operation_mode != 1);
  if (otter_2fixed_Loitering_missi_DW.If_ActiveSubsystem == 0) {
    // Outputs for IfAction SubSystem: '<S3>/Waypoint following' incorporates:
    //   ActionPort: '<S98>/Action Port'

    // SignalConversion generated from: '<S98>/m1_ref' incorporates:
    //   DataTypeConversion: '<S3>/Data Type Conversion'
    //   MATLAB Function: '<S2>/MATLAB Function'
    //   MATLAB Function: '<S2>/MATLAB Function1'
    //   MATLAB Function: '<S98>/Atan2_guidance'
    //   MATLABSystem: '<S3>/Read Parameter1'
    //
    otter_2fixed_Loi_Atan2_guidance(otter_2fixed_Loitering_missio_B.coslambda,
      otter_2fixed_Loitering_missio_B.enuPos_idx_0,
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0],
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1],
      static_cast<real_T>(otter_2fixed_Loitering_missio_B.ParamStep),
      otter_2fixed_Loitering_missio_B.In1_i.finished,
      &otter_2fixed_Loitering_missio_B.Add,
      &otter_2fixed_Loitering_missio_B.sinphi,
      &otter_2fixed_Loitering_missio_B.sinlambda);

    // End of Outputs for SubSystem: '<S3>/Waypoint following'
  } else {
    if (rtPrevAction != 1) {
      // InitializeConditions for IfAction SubSystem: '<S3>/Loitering' incorporates:
      //   ActionPort: '<S95>/Action Port'

      // InitializeConditions for If: '<S3>/If' incorporates:
      //   UnitDelay: '<S95>/Unit Delay'
      //   UnitDelay: '<S95>/Unit Delay1'
      //   UnitDelay: '<S95>/Unit Delay2'
      //   UnitDelay: '<S95>/Unit Delay3'

      otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE =
        otter_2fixed_Loitering_missio_P.UnitDelay2_InitialCondition_p;
      otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE =
        otter_2fixed_Loitering_missio_P.UnitDelay1_InitialCondition;
      otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE =
        otter_2fixed_Loitering_missio_P.UnitDelay_InitialCondition;
      otter_2fixed_Loitering_missi_DW.UnitDelay3_DSTATE =
        otter_2fixed_Loitering_missio_P.UnitDelay3_InitialCondition;

      // End of InitializeConditions for SubSystem: '<S3>/Loitering'

      // SystemReset for IfAction SubSystem: '<S3>/Loitering' incorporates:
      //   ActionPort: '<S95>/Action Port'

      // SystemReset for If: '<S3>/If' incorporates:
      //   Chart: '<S95>/Chart'
      //   MATLAB Function: '<S95>/MATLAB Function'

      otter_2fixed_Loitering_missi_DW.prev_armed_lm = 0.0;
      otter_2fixed_Loitering_missi_DW.is_active_c1_otter_2fixed_Loite = 0U;
      otter_2fixed_Loitering_missi_DW.is_c1_otter_2fixed_Loitering_mi =
        otter_2fixed_IN_NO_ACTIVE_CHILD;

      // End of SystemReset for SubSystem: '<S3>/Loitering'
    }

    // Outputs for IfAction SubSystem: '<S3>/Loitering' incorporates:
    //   ActionPort: '<S95>/Action Port'

    // MATLAB Function: '<S95>/Atan2_guidance' incorporates:
    //   DataTypeConversion: '<S3>/Data Type Conversion'
    //   MATLAB Function: '<S2>/MATLAB Function'
    //   MATLAB Function: '<S2>/MATLAB Function1'
    //   MATLABSystem: '<S3>/Read Parameter1'
    //
    otter_2fixed_Loi_Atan2_guidance(otter_2fixed_Loitering_missio_B.coslambda,
      otter_2fixed_Loitering_missio_B.enuPos_idx_0,
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0],
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1],
      static_cast<real_T>(otter_2fixed_Loitering_missio_B.ParamStep),
      otter_2fixed_Loitering_missio_B.In1_i.finished,
      &otter_2fixed_Loitering_missio_B.Add,
      &otter_2fixed_Loitering_missio_B.sinphi,
      &otter_2fixed_Loitering_missio_B.sinlambda);

    // MATLAB Function: '<S95>/MATLAB Function2' incorporates:
    //   MATLAB Function: '<S2>/MATLAB Function'
    //   MATLAB Function: '<S2>/MATLAB Function1'
    //   MATLAB Function: '<S95>/MATLAB Function'
    //   MATLAB Function: '<S95>/MATLAB Function1'

    otter_2fixed_Loitering_missio_B.r_dot =
      otter_2fixed_Loitering_missio_B.coslambda -
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[0];
    otter_2fixed_Loitering_missio_B.N =
      otter_2fixed_Loitering_missio_B.enuPos_idx_0 -
      otter_2fixed_Loitering_missio_B.ecefPosWithENUOrigin[1];

    // MATLAB Function: '<S95>/MATLAB Function' incorporates:
    //   DataTypeConversion: '<S2>/Data Type Conversion7'
    //   DataTypeConversion: '<S3>/Data Type Conversion3'
    //   MATLAB Function: '<S95>/MATLAB Function1'
    //   MATLABSystem: '<S3>/Read Parameter'
    //   UnitDelay: '<S95>/Unit Delay'
    //   UnitDelay: '<S95>/Unit Delay1'
    //   UnitDelay: '<S95>/Unit Delay2'
    //   UnitDelay: '<S95>/Unit Delay3'
    //
    otter_2fixed_Loitering_missio_B.sinlambda = rt_atan2d_snf
      (otter_2fixed_Loitering_missio_B.N, otter_2fixed_Loitering_missio_B.r_dot);
    otter_2fixed_Loitering_missio_B.enuPos_idx_0 =
      otter_2fixed_Loitering_missio_B.sinlambda;
    if ((otter_2fixed_Loitering_missi_DW.prev_armed_lm == 0.0) &&
        otter_2fixed_Loitering_missio_B.In1_p.armed) {
      otter_2fixed_Loitering_missi_DW.prev_armed_lm =
        otter_2fixed_Loitering_missio_B.In1_p.armed;
      otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE = 0.0;
      otter_2fixed_Loitering_missio_B.enuPos_idx_0 =
        otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE;
      loiter_done = 0;
      rtb_loiter_used = 0;
    } else {
      otter_2fixed_Loitering_missi_DW.prev_armed_lm =
        otter_2fixed_Loitering_missio_B.In1_p.armed;
      if (otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE == 2.0) {
        if (otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE == 0.0) {
          otter_2fixed_Loitering_missio_B.coslambda = 0.0;
        } else {
          otter_2fixed_Loitering_missio_B.coslambda =
            otter_2fixed_Loitering_missio_B.sinlambda -
            otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE;
          otter_2fixed_Loitering_missio_B.coslambda = rt_atan2d_snf(sin
            (otter_2fixed_Loitering_missio_B.coslambda), cos
            (otter_2fixed_Loitering_missio_B.coslambda));
        }

        otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE += fabs
          (otter_2fixed_Loitering_missio_B.coslambda);
      } else {
        otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE = 0.0;
        otter_2fixed_Loitering_missio_B.enuPos_idx_0 =
          otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE;
      }

      loiter_done = (otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE >=
                     0.017453292519943295 * ParamStep_1);
      rtb_loiter_used = ((otter_2fixed_Loitering_missi_DW.UnitDelay3_DSTATE !=
                          0.0) || (loiter_done != 0));
    }

    // Chart: '<S95>/Chart' incorporates:
    //   DataTypeConversion: '<S3>/Data Type Conversion1'
    //   MATLAB Function: '<S95>/MATLAB Function'
    //   MATLAB Function: '<S95>/MATLAB Function2'
    //   MATLABSystem: '<S3>/Read Parameter2'
    //
    if (otter_2fixed_Loitering_missi_DW.is_active_c1_otter_2fixed_Loite == 0) {
      otter_2fixed_Loitering_missi_DW.is_active_c1_otter_2fixed_Loite = 1U;
      otter_2fixed_Loitering_missi_DW.is_c1_otter_2fixed_Loitering_mi =
        otter_2fixed_Loit_IN_ATAN2_MODE;
      rtb_loiter_mode = 1;
    } else if (otter_2fixed_Loitering_missi_DW.is_c1_otter_2fixed_Loitering_mi ==
               otter_2fixed_Loit_IN_ATAN2_MODE) {
      rtb_loiter_mode = 1;
      if ((sqrt(otter_2fixed_Loitering_missio_B.r_dot *
                otter_2fixed_Loitering_missio_B.r_dot +
                otter_2fixed_Loitering_missio_B.N *
                otter_2fixed_Loitering_missio_B.N) <= ParamStep) && (loiter_done
           == 0) && (rtb_loiter_used == 0)) {
        otter_2fixed_Loitering_missi_DW.is_c1_otter_2fixed_Loitering_mi =
          otter_2fixed__IN_LOITERING_MODE;
        rtb_loiter_mode = 2;
      }
    } else {
      // case IN_LOITERING_MODE:
      rtb_loiter_mode = 2;
      if (loiter_done == 1) {
        otter_2fixed_Loitering_missi_DW.is_c1_otter_2fixed_Loitering_mi =
          otter_2fixed_Loit_IN_ATAN2_MODE;
        rtb_loiter_mode = 1;
      }
    }

    // End of Chart: '<S95>/Chart'

    // MATLAB Function: '<S95>/MATLAB Function1' incorporates:
    //   DataTypeConversion: '<S3>/Data Type Conversion'
    //   DataTypeConversion: '<S3>/Data Type Conversion1'
    //   DataTypeConversion: '<S3>/Data Type Conversion2'
    //   MATLABSystem: '<S3>/Read Parameter1'
    //   MATLABSystem: '<S3>/Read Parameter2'
    //   MATLABSystem: '<S3>/Read Parameter3'
    //
    otter_2fixed_Loitering_missio_B.coslambda = sqrt
      (otter_2fixed_Loitering_missio_B.r_dot *
       otter_2fixed_Loitering_missio_B.r_dot + otter_2fixed_Loitering_missio_B.N
       * otter_2fixed_Loitering_missio_B.N);
    if (otter_2fixed_Loitering_missio_B.coslambda < 1.0E-6) {
      otter_2fixed_Loitering_missio_B.coslambda = 1.0E-6;
    }

    otter_2fixed_Loitering_missio_B.r_dot =
      otter_2fixed_Loitering_missio_B.coslambda - ParamStep;
    otter_2fixed_Loitering_missio_B.N = ParamStep_0 *
      otter_2fixed_Loitering_missio_B.coslambda;
    otter_2fixed_Loitering_missio_B.N = sqrt
      (otter_2fixed_Loitering_missio_B.r_dot *
       otter_2fixed_Loitering_missio_B.r_dot + otter_2fixed_Loitering_missio_B.N
       * otter_2fixed_Loitering_missio_B.N);
    if (otter_2fixed_Loitering_missio_B.N < 1.0E-9) {
      otter_2fixed_Loitering_missio_B.N = 1.0E-9;
    }

    otter_2fixed_Loitering_missio_B.r_dot =
      otter_2fixed_Loitering_missio_B.r_dot * -static_cast<real_T>
      (otter_2fixed_Loitering_missio_B.ParamStep) /
      otter_2fixed_Loitering_missio_B.N;
    otter_2fixed_Loitering_missio_B.coslambda = static_cast<real_T>
      (otter_2fixed_Loitering_missio_B.ParamStep) * ParamStep_0 *
      otter_2fixed_Loitering_missio_B.coslambda /
      otter_2fixed_Loitering_missio_B.N;
    otter_2fixed_Loitering_missio_B.N = sin
      (otter_2fixed_Loitering_missio_B.sinlambda);
    otter_2fixed_Loitering_missio_B.vx_ref_tmp = cos
      (otter_2fixed_Loitering_missio_B.sinlambda);
    otter_2fixed_Loitering_missio_B.sinlambda =
      otter_2fixed_Loitering_missio_B.r_dot *
      otter_2fixed_Loitering_missio_B.vx_ref_tmp -
      otter_2fixed_Loitering_missio_B.coslambda *
      otter_2fixed_Loitering_missio_B.N;
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.r_dot * otter_2fixed_Loitering_missio_B.N
      + otter_2fixed_Loitering_missio_B.coslambda *
      otter_2fixed_Loitering_missio_B.vx_ref_tmp;

    // MultiPortSwitch: '<S95>/Multiport Switch' incorporates:
    //   MATLAB Function: '<S95>/MATLAB Function1'

    if (rtb_loiter_mode != 1) {
      otter_2fixed_Loitering_missio_B.Add = sqrt
        (otter_2fixed_Loitering_missio_B.sinlambda *
         otter_2fixed_Loitering_missio_B.sinlambda +
         otter_2fixed_Loitering_missio_B.coslambda *
         otter_2fixed_Loitering_missio_B.coslambda);
      otter_2fixed_Loitering_missio_B.sinphi = rt_atan2d_snf
        (otter_2fixed_Loitering_missio_B.coslambda,
         otter_2fixed_Loitering_missio_B.sinlambda);
    }

    // End of MultiPortSwitch: '<S95>/Multiport Switch'

    // Update for UnitDelay: '<S95>/Unit Delay2'
    otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE = rtb_loiter_mode;

    // Update for UnitDelay: '<S95>/Unit Delay' incorporates:
    //   MATLAB Function: '<S95>/MATLAB Function'

    otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE =
      otter_2fixed_Loitering_missio_B.enuPos_idx_0;

    // Update for UnitDelay: '<S95>/Unit Delay3'
    otter_2fixed_Loitering_missi_DW.UnitDelay3_DSTATE = rtb_loiter_used;

    // End of Outputs for SubSystem: '<S3>/Loitering'
  }

  // End of If: '<S3>/If'

  // Sum: '<S71>/Sum'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[0] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1;

  // Gain: '<S74>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[1] =
    otter_2fixed_Loitering_missio_B.Sum_jw *
    otter_2fixed_Loitering_missio_P.Gain_Gain_co;

  // Gain: '<S77>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[2] =
    otter_2fixed_Loitering_missio_B.Fx_sat *
    otter_2fixed_Loitering_missio_P.Gain_Gain_e1;

  // Gain: '<S72>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[3] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 *
    otter_2fixed_Loitering_missio_P.Gain_Gain_h;

  // Sum: '<S75>/Sum'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[4] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2;

  // Gain: '<S78>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[5] =
    otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp *
    otter_2fixed_Loitering_missio_P.Gain_Gain_o;

  // Gain: '<S73>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[6] =
    otter_2fixed_Loitering_missio_B.Fx_unsat *
    otter_2fixed_Loitering_missio_P.Gain_Gain_p;

  // Gain: '<S76>/Gain'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[7] =
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp *
    otter_2fixed_Loitering_missio_P.Gain_Gain_k;

  // Sum: '<S79>/Sum'
  otter_2fixed_Loitering_missio_B.VectorConcatenate[8] =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3;

  // Gain: '<S46>/Gain1' incorporates:
  //   Concatenate: '<S80>/Vector Concatenate'
  //   Selector: '<S46>/Selector1'

  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
    otter_2fixed_Loitering_missio_P.Gain1_Gain[2] *
    otter_2fixed_Loitering_missio_B.VectorConcatenate[6];

  // MATLABSystem: '<S18>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_b2.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj_b2.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r2, false, 1.0);

  // Outputs for Enabled SubSystem: '<S18>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S87>/Enable'

  // Start for MATLABSystem: '<S18>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S87>/In1'
    otter_2fixed_Loitering_missio_B.In1_h = otter_2fixed_Loitering_missio_B.r2;
  }

  // End of Outputs for SubSystem: '<S18>/Enabled Subsystem'

  // Outputs for Enabled SubSystem: '<Root>/Controller' incorporates:
  //   EnablePort: '<S1>/Enable'

  // DataTypeConversion: '<S2>/Data Type Conversion7'
  if (otter_2fixed_Loitering_missio_B.In1_p.armed) {
    if (!otter_2fixed_Loitering_missi_DW.Controller_MODE) {
      // Enable for DiscreteIntegrator: '<S10>/Integrator3'
      otter_2fixed_Loitering_missi_DW.Integrator3_SYSTEM_ENABLE = 1U;
      otter_2fixed_Loitering_missi_DW.Controller_MODE = true;
    }

    // If: '<S42>/If' incorporates:
    //   Concatenate: '<S80>/Vector Concatenate'
    //   Fcn: '<S44>/Fcn1'
    //   Fcn: '<S45>/Fcn1'
    //   Gain: '<S46>/Gain1'
    //   Gain: '<S46>/Gain3'
    //   Selector: '<S46>/Selector1'
    //   Selector: '<S46>/Selector3'
    //   Sum: '<S9>/Sum'

    if ((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 >= 1.0) ||
        (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 <= -1.0)) {
      // Outputs for IfAction SubSystem: '<S42>/AxisRotZeroR3' incorporates:
      //   ActionPort: '<S45>/Action Port'

      otter_2fixed_Loitering_missio_B.coslambda = rt_atan2d_snf
        (otter_2fixed_Loitering_missio_P.Gain3_Gain[0] *
         otter_2fixed_Loitering_missio_B.VectorConcatenate[1],
         otter_2fixed_Loitering_missio_P.Gain3_Gain[1] *
         otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2);

      // End of Outputs for SubSystem: '<S42>/AxisRotZeroR3'
    } else {
      // Outputs for IfAction SubSystem: '<S42>/AxisRotDefault' incorporates:
      //   ActionPort: '<S44>/Action Port'

      otter_2fixed_Loitering_missio_B.coslambda = rt_atan2d_snf
        (otter_2fixed_Loitering_missio_P.Gain1_Gain[0] *
         otter_2fixed_Loitering_missio_B.VectorConcatenate[3],
         otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 *
         otter_2fixed_Loitering_missio_P.Gain1_Gain[1]);

      // End of Outputs for SubSystem: '<S42>/AxisRotDefault'
    }

    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_B.sinphi -
      otter_2fixed_Loitering_missio_B.coslambda;

    // End of If: '<S42>/If'

    // MATLAB Function: '<S9>/MATLAB Function'
    if (rtIsNaN(otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
                3.1415926535897931)) {
      otter_2fixed_Loitering_missio_B.coslambda = (rtNaN);
    } else if (rtIsInf(otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
                       3.1415926535897931)) {
      otter_2fixed_Loitering_missio_B.coslambda = (rtNaN);
    } else if (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
               3.1415926535897931 == 0.0) {
      otter_2fixed_Loitering_missio_B.coslambda = 0.0;
    } else {
      otter_2fixed_Loitering_missio_B.coslambda = fmod
        (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 + 3.1415926535897931,
         6.2831853071795862);
      rEQ0 = (otter_2fixed_Loitering_missio_B.coslambda == 0.0);
      if (!rEQ0) {
        otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 = fabs
          ((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
            3.1415926535897931) / 6.2831853071795862);
        rEQ0 = !(fabs(otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 - floor
                      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 + 0.5)) >
                 2.2204460492503131E-16 *
                 otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0);
      }

      if (rEQ0) {
        otter_2fixed_Loitering_missio_B.coslambda = 0.0;
      } else if (otter_2fixed_Loitering_missio_B.coslambda < 0.0) {
        otter_2fixed_Loitering_missio_B.coslambda += 6.2831853071795862;
      }
    }

    // MATLABSystem: '<S9>/Read Parameter'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_ja.MW_PARAMHANDLE,
                         MW_SINGLE, &otter_2fixed_Loitering_missio_B.ParamStep);
    if (rEQ0) {
      otter_2fixed_Loitering_missio_B.ParamStep = 0.0F;
    }

    // MATLABSystem: '<S9>/Read Parameter1'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_j.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep);
    if (rEQ0) {
      ParamStep = 0.0F;
    }

    // MATLABSystem: '<S10>/Read Parameter2'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_lb.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_0);
    if (rEQ0) {
      ParamStep_0 = 0.0F;
    }

    // MATLABSystem: '<S10>/Read Parameter3'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_p4.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_1);
    if (rEQ0) {
      ParamStep_1 = 0.0F;
    }

    // Product: '<S12>/Matrix Multiply2' incorporates:
    //   Concatenate: '<S38>/Vector Concatenate'
    //   DataTypeConversion: '<S2>/Data Type Conversion1'

    for (loiter_done = 0; loiter_done < 3; loiter_done++) {
      otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[loiter_done] =
        (otter_2fixed_Loitering_missio_B.VectorConcatenate_e[loiter_done + 3] *
         otter_2fixed_Loitering_missio_B.In1_n.vy +
         otter_2fixed_Loitering_missio_B.VectorConcatenate_e[loiter_done] *
         otter_2fixed_Loitering_missio_B.In1_n.vx) +
        otter_2fixed_Loitering_missio_B.VectorConcatenate_e[loiter_done + 6] *
        otter_2fixed_Loitering_missio_B.In1_n.vz;
    }

    // End of Product: '<S12>/Matrix Multiply2'

    // Sum: '<S10>/Sum'
    otter_2fixed_Loitering_missio_B.Sum_jw = otter_2fixed_Loitering_missio_B.Add
      - otter_2fixed_Loitering_missio_B.rtb_VectorConcatenate_e_m[0];

    // Product: '<S10>/Product3' incorporates:
    //   MATLABSystem: '<S10>/Read Parameter2'
    //   MATLABSystem: '<S10>/Read Parameter3'
    //   Product: '<S10>/Product4'
    //   Sum: '<S10>/Sum11'
    //   UnitDelay: '<S10>/Unit Delay2'
    //
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      (otter_2fixed_Loitering_missio_B.Sum_jw - ParamStep_1 *
       otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE_f) * ParamStep_0;

    // DiscreteIntegrator: '<S10>/Integrator3'
    if (otter_2fixed_Loitering_missi_DW.Integrator3_SYSTEM_ENABLE != 0) {
      // DiscreteIntegrator: '<S10>/Integrator3'
      otter_2fixed_Loitering_missio_B.Integrator3 =
        otter_2fixed_Loitering_missi_DW.Integrator3_DSTATE;
    } else {
      // DiscreteIntegrator: '<S10>/Integrator3'
      otter_2fixed_Loitering_missio_B.Integrator3 =
        otter_2fixed_Loitering_missio_P.Integrator3_gainval *
        otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
        otter_2fixed_Loitering_missi_DW.Integrator3_DSTATE;
    }

    // End of DiscreteIntegrator: '<S10>/Integrator3'

    // MATLABSystem: '<S10>/Read Parameter'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_l4.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_0);
    if (rEQ0) {
      ParamStep_0 = 0.0F;
    }

    // DiscreteTransferFcn: '<S10>/Transfer Fcn1'
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp =
      (otter_2fixed_Loitering_missio_B.Sum_jw -
       otter_2fixed_Loitering_missio_P.TransferFcn1_DenCoef[1] *
       otter_2fixed_Loitering_missi_DW.TransferFcn1_states) /
      otter_2fixed_Loitering_missio_P.TransferFcn1_DenCoef[0];

    // MATLABSystem: '<S10>/Read Parameter1'
    rEQ0 = MW_Param_Step(otter_2fixed_Loitering_missi_DW.obj_od.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_1);
    if (rEQ0) {
      ParamStep_1 = 0.0F;
    }

    // Sum: '<S10>/Sum9' incorporates:
    //   DiscreteTransferFcn: '<S10>/Transfer Fcn1'
    //   MATLABSystem: '<S10>/Read Parameter'
    //   MATLABSystem: '<S10>/Read Parameter1'
    //   Product: '<S10>/Product1'
    //   Product: '<S10>/Product2'
    //
    otter_2fixed_Loitering_missio_B.Fx_unsat =
      (otter_2fixed_Loitering_missio_P.TransferFcn1_NumCoef[0] *
       otter_2fixed_Loitering_missio_B.TransferFcn1_tmp +
       otter_2fixed_Loitering_missio_P.TransferFcn1_NumCoef[1] *
       otter_2fixed_Loitering_missi_DW.TransferFcn1_states) * ParamStep_1 +
      (otter_2fixed_Loitering_missio_B.Sum_jw * ParamStep_0 +
       otter_2fixed_Loitering_missio_B.Integrator3);

    // Saturate: '<S10>/sat1'
    if (otter_2fixed_Loitering_missio_B.Fx_unsat >
        otter_2fixed_Loitering_missio_P.Fx_max) {
      otter_2fixed_Loitering_missio_B.Fx_sat =
        otter_2fixed_Loitering_missio_P.Fx_max;
    } else if (otter_2fixed_Loitering_missio_B.Fx_unsat <
               otter_2fixed_Loitering_missio_P.Fx_min) {
      otter_2fixed_Loitering_missio_B.Fx_sat =
        otter_2fixed_Loitering_missio_P.Fx_min;
    } else {
      otter_2fixed_Loitering_missio_B.Fx_sat =
        otter_2fixed_Loitering_missio_B.Fx_unsat;
    }

    // End of Saturate: '<S10>/sat1'

    // SignalConversion generated from: '<S1>/tau_auto' incorporates:
    //   Constant: '<S1>/Constant'

    otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[0] =
      otter_2fixed_Loitering_missio_B.Fx_sat;
    otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[1] =
      otter_2fixed_Loitering_missio_P.Constant_Value_jl;

    // Sum: '<S9>/Sum2' incorporates:
    //   DataTypeConversion: '<S2>/Data Type Conversion2'
    //   MATLAB Function: '<S9>/MATLAB Function'
    //   MATLABSystem: '<S9>/Read Parameter'
    //   MATLABSystem: '<S9>/Read Parameter1'
    //   Product: '<S9>/Product'
    //   Product: '<S9>/Product1'
    //
    otter_2fixed_Loitering_missio_B.Sum_jw =
      (otter_2fixed_Loitering_missio_B.coslambda - 3.1415926535897931) *
      otter_2fixed_Loitering_missio_B.ParamStep - static_cast<real_T>
      (otter_2fixed_Loitering_missio_B.In1_h.angular_velocity[2]) * ParamStep;

    // Saturate: '<S9>/stern constraint'
    if (otter_2fixed_Loitering_missio_B.Sum_jw >
        otter_2fixed_Loitering_missio_P.N_max) {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[2] =
        otter_2fixed_Loitering_missio_P.N_max;
    } else if (otter_2fixed_Loitering_missio_B.Sum_jw <
               otter_2fixed_Loitering_missio_P.N_min) {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[2] =
        otter_2fixed_Loitering_missio_P.N_min;
    } else {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[2] =
        otter_2fixed_Loitering_missio_B.Sum_jw;
    }

    // End of Saturate: '<S9>/stern constraint'

    // Sum: '<S10>/Sum10' incorporates:
    //   UnitDelay: '<S10>/Unit Delay2'

    otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE_f =
      otter_2fixed_Loitering_missio_B.Fx_unsat -
      otter_2fixed_Loitering_missio_B.Fx_sat;

    // Update for DiscreteIntegrator: '<S10>/Integrator3'
    otter_2fixed_Loitering_missi_DW.Integrator3_SYSTEM_ENABLE = 0U;
    otter_2fixed_Loitering_missi_DW.Integrator3_DSTATE =
      otter_2fixed_Loitering_missio_P.Integrator3_gainval *
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
      otter_2fixed_Loitering_missio_B.Integrator3;

    // Update for DiscreteTransferFcn: '<S10>/Transfer Fcn1'
    otter_2fixed_Loitering_missi_DW.TransferFcn1_states =
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  } else if (otter_2fixed_Loitering_missi_DW.Controller_MODE) {
    // Disable for DiscreteIntegrator: '<S10>/Integrator3'
    otter_2fixed_Loitering_missi_DW.Integrator3_DSTATE =
      otter_2fixed_Loitering_missio_B.Integrator3;
    otter_2fixed_Loitering_missi_DW.Controller_MODE = false;
  }

  // End of Outputs for SubSystem: '<Root>/Controller'

  // MATLABSystem: '<S105>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_Loitering_missi_DW.obj.orbMetadataObj,
                        &otter_2fixed_Loitering_missi_DW.obj.eventStructObj,
                        &otter_2fixed_Loitering_missio_B.r4, false, 5000.0);

  // Outputs for Enabled SubSystem: '<S105>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S106>/Enable'

  // Start for MATLABSystem: '<S105>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S106>/In1'
    otter_2fixed_Loitering_missio_B.In1_d = otter_2fixed_Loitering_missio_B.r4;
  }

  // End of Outputs for SubSystem: '<S105>/Enabled Subsystem'

  // Gain: '<S7>/Gain'
  otter_2fixed_Loitering_missio_B.coslambda = 1.0 /
    (otter_2fixed_Loitering_missio_P.RC_max -
     otter_2fixed_Loitering_missio_P.RC_min);

  // Sum: '<S7>/Sum' incorporates:
  //   Constant: '<S7>/Constant'
  //   Constant: '<S7>/Constant2'
  //   Gain: '<S7>/Gain'
  //   Gain: '<S7>/Gain1'
  //   Sum: '<S7>/Sum1'

  otter_2fixed_Loitering_missio_B.Add = (static_cast<real_T>
    (otter_2fixed_Loitering_missio_B.In1_d.values[2]) +
    otter_2fixed_Loitering_missio_P.Constant2_Value_k[0]) *
    otter_2fixed_Loitering_missio_B.coslambda *
    otter_2fixed_Loitering_missio_P.Gain1_Gain_o +
    otter_2fixed_Loitering_missio_P.Constant_Value_dl[0];
  otter_2fixed_Loitering_missio_B.sinphi = (static_cast<real_T>
    (otter_2fixed_Loitering_missio_B.In1_d.values[0]) +
    otter_2fixed_Loitering_missio_P.Constant2_Value_k[1]) *
    otter_2fixed_Loitering_missio_B.coslambda *
    otter_2fixed_Loitering_missio_P.Gain1_Gain_o +
    otter_2fixed_Loitering_missio_P.Constant_Value_dl[1];

  // DeadZone: '<S114>/Dead Zone'
  if (otter_2fixed_Loitering_missio_B.Add >
      otter_2fixed_Loitering_missio_P.DeadZone_End) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.Add -
      otter_2fixed_Loitering_missio_P.DeadZone_End;
  } else if (otter_2fixed_Loitering_missio_B.Add >=
             otter_2fixed_Loitering_missio_P.DeadZone_Start) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.Add -
      otter_2fixed_Loitering_missio_P.DeadZone_Start;
  }

  // Switch: '<S114>/Switch1' incorporates:
  //   Abs: '<S114>/Abs'
  //   Constant: '<S116>/Constant'
  //   DeadZone: '<S114>/Dead Zone'
  //   RelationalOperator: '<S116>/Compare'

  if (fabs(otter_2fixed_Loitering_missio_B.coslambda) <=
      otter_2fixed_Loitering_missio_P.Constant_Value_ex) {
    // SignalConversion generated from: '<S107>/ SFunction ' incorporates:
    //   Constant: '<S114>/Constant'
    //   MATLAB Function: '<S6>/MATLAB Function'

    otter_2fixed_Loitering_missio_B.Add =
      otter_2fixed_Loitering_missio_P.Constant_Value_db;
  }

  // End of Switch: '<S114>/Switch1'

  // DeadZone: '<S113>/Dead Zone'
  if (otter_2fixed_Loitering_missio_B.sinphi >
      otter_2fixed_Loitering_missio_P.DeadZone_End_h) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.sinphi -
      otter_2fixed_Loitering_missio_P.DeadZone_End_h;
  } else if (otter_2fixed_Loitering_missio_B.sinphi >=
             otter_2fixed_Loitering_missio_P.DeadZone_Start_o) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.sinphi -
      otter_2fixed_Loitering_missio_P.DeadZone_Start_o;
  }

  // Switch: '<S113>/Switch1' incorporates:
  //   Abs: '<S113>/Abs'
  //   Constant: '<S115>/Constant'
  //   DeadZone: '<S113>/Dead Zone'
  //   RelationalOperator: '<S115>/Compare'

  if (fabs(otter_2fixed_Loitering_missio_B.coslambda) <=
      otter_2fixed_Loitering_missio_P.Constant_Value_bp) {
    // SignalConversion generated from: '<S107>/ SFunction ' incorporates:
    //   Constant: '<S113>/Constant'
    //   MATLAB Function: '<S6>/MATLAB Function'

    otter_2fixed_Loitering_missio_B.sinphi =
      otter_2fixed_Loitering_missio_P.Constant_Value_if;
  }

  // End of Switch: '<S113>/Switch1'

  // MATLAB Function: '<S6>/MATLAB Function' incorporates:
  //   Constant: '<S6>/Constant16'
  //   Constant: '<S6>/Constant17'

  if (otter_2fixed_Loitering_missio_B.Add < 0.0) {
    otter_2fixed_Loitering_missio_B.Add = (otter_2fixed_Loitering_missio_B.Add +
      1.0) * (0.0 - otter_2fixed_Loitering_missio_P.Constant17_Value[0]) +
      otter_2fixed_Loitering_missio_P.Constant17_Value[0];
  } else {
    otter_2fixed_Loitering_missio_B.Add *=
      otter_2fixed_Loitering_missio_P.Constant16_Value[0];
  }

  if (otter_2fixed_Loitering_missio_B.sinphi < 0.0) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      (otter_2fixed_Loitering_missio_B.sinphi + 1.0) * (0.0 -
      otter_2fixed_Loitering_missio_P.Constant17_Value[2]) +
      otter_2fixed_Loitering_missio_P.Constant17_Value[2];
  } else {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_B.sinphi *
      otter_2fixed_Loitering_missio_P.Constant16_Value[2];
  }

  // Switch: '<S4>/Switch' incorporates:
  //   Constant: '<S4>/Constant'
  //   Constant: '<S4>/Constant1'

  if (otter_2fixed_Loitering_missio_B.In1_d.values[6] >=
      otter_2fixed_Loitering_missio_P.Switch_Threshold_a) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_P.Constant1_Value_l;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_P.Constant_Value_ds;
  }

  // Switch: '<S6>/Switch2' incorporates:
  //   Gain: '<S6>/Gain4'
  //   Switch: '<S4>/Switch'

  if (otter_2fixed_Loitering_missio_B.coslambda >
      otter_2fixed_Loitering_missio_P.Switch2_Threshold) {
    otter_2fixed_Loitering_missio_B.sinphi =
      otter_2fixed_Loitering_missio_P.Gain4_Gain *
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0;
  } else {
    otter_2fixed_Loitering_missio_B.Add =
      otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[0];
    otter_2fixed_Loitering_missio_B.sinphi =
      otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[2];
  }

  // End of Switch: '<S6>/Switch2'

  // MATLAB Function: '<S6>/MATLAB Function1' incorporates:
  //   Constant: '<S6>/Constant1'
  //   Constant: '<S6>/Constant2'
  //   Constant: '<S6>/Constant3'
  //   SignalConversion generated from: '<S108>/ SFunction '

  otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp =
    otter_2fixed_Loitering_missio_B.sinphi / otter_2fixed_Loitering_missio_P.d;
  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
    (otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp +
     otter_2fixed_Loitering_missio_B.Add) / 2.0;
  otter_2fixed_Loitering_missio_B.TransferFcn1_tmp =
    (otter_2fixed_Loitering_missio_B.Add -
     otter_2fixed_Loitering_missio_B.rtb_Saturation1_tmp) / 2.0;
  otter_2fixed_Loitering_missio_B.Fx_unsat =
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 -
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  otter_2fixed_Loitering_missio_B.Sum_jw =
    otter_2fixed_Loitering_missio_P.Thrust_max -
    otter_2fixed_Loitering_missio_P.Thrust_min;
  if (fabs(otter_2fixed_Loitering_missio_B.Fx_unsat) >
      otter_2fixed_Loitering_missio_B.Sum_jw) {
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp =
      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +
       otter_2fixed_Loitering_missio_B.TransferFcn1_tmp) / 2.0;
    if (rtIsNaN(otter_2fixed_Loitering_missio_B.Fx_unsat)) {
      otter_2fixed_Loitering_missio_B.coslambda = (rtNaN);
    } else if (otter_2fixed_Loitering_missio_B.Fx_unsat < 0.0) {
      otter_2fixed_Loitering_missio_B.coslambda = -1.0;
    } else {
      otter_2fixed_Loitering_missio_B.coslambda =
        (otter_2fixed_Loitering_missio_B.Fx_unsat > 0.0);
    }

    otter_2fixed_Loitering_missio_B.Fx_unsat =
      otter_2fixed_Loitering_missio_B.coslambda *
      otter_2fixed_Loitering_missio_B.Sum_jw;
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_B.Fx_unsat / 2.0 +
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp -=
      otter_2fixed_Loitering_missio_B.Fx_unsat / 2.0;
  }

  if ((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 >=
       otter_2fixed_Loitering_missio_B.TransferFcn1_tmp) || rtIsNaN
      (otter_2fixed_Loitering_missio_B.TransferFcn1_tmp)) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  }

  otter_2fixed_Loitering_missio_B.Sum_jw =
    otter_2fixed_Loitering_missio_B.coslambda -
    otter_2fixed_Loitering_missio_P.Thrust_max;
  if (otter_2fixed_Loitering_missio_B.Sum_jw > 0.0) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 -=
      otter_2fixed_Loitering_missio_B.Sum_jw;
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp -=
      otter_2fixed_Loitering_missio_B.Sum_jw;
  }

  if ((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 <=
       otter_2fixed_Loitering_missio_B.TransferFcn1_tmp) || rtIsNaN
      (otter_2fixed_Loitering_missio_B.TransferFcn1_tmp)) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  }

  otter_2fixed_Loitering_missio_B.Sum_jw =
    otter_2fixed_Loitering_missio_P.Thrust_min -
    otter_2fixed_Loitering_missio_B.coslambda;
  if (otter_2fixed_Loitering_missio_B.Sum_jw > 0.0) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 +=
      otter_2fixed_Loitering_missio_B.Sum_jw;
    otter_2fixed_Loitering_missio_B.TransferFcn1_tmp +=
      otter_2fixed_Loitering_missio_B.Sum_jw;
  }

  // Gain: '<S6>/1//k_pos'
  otter_2fixed_Loitering_missio_B.coslambda = 1.0 /
    otter_2fixed_Loitering_missio_P.k_pos;

  // Gain: '<S6>/1//k_pos1'
  otter_2fixed_Loitering_missio_B.Sum_jw = 1.0 /
    otter_2fixed_Loitering_missio_P.k_neg;

  // Sqrt: '<S6>/Signed Square Root' incorporates:
  //   Gain: '<S6>/1//k_pos'
  //   Gain: '<S6>/1//k_pos1'
  //   MATLAB Function: '<S6>/MATLAB Function1'
  //   Switch: '<S6>/Switch'
  //
  //  About '<S6>/Signed Square Root':
  //   Operator: signedSqrt

  if (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 >
      otter_2fixed_Loitering_missio_P.Switch_Threshold_c) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 *=
      otter_2fixed_Loitering_missio_B.coslambda;
  } else {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 *=
      otter_2fixed_Loitering_missio_B.Sum_jw;
  }

  if (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 < 0.0) {
    otter_2fixed_Loitering_missio_B.Add = -sqrt(fabs
      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0));
  } else {
    otter_2fixed_Loitering_missio_B.Add = sqrt
      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0);
  }

  if (otter_2fixed_Loitering_missio_B.TransferFcn1_tmp >
      otter_2fixed_Loitering_missio_P.Switch_Threshold_c) {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_B.coslambda *
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  } else {
    otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 =
      otter_2fixed_Loitering_missio_B.Sum_jw *
      otter_2fixed_Loitering_missio_B.TransferFcn1_tmp;
  }

  if (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0 < 0.0) {
    otter_2fixed_Loitering_missio_B.sinphi = -sqrt(fabs
      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0));
  } else {
    otter_2fixed_Loitering_missio_B.sinphi = sqrt
      (otter_2fixed_Loitering_missio_B.rtb_Switch_idx_0);
  }

  // End of Sqrt: '<S6>/Signed Square Root'

  // MATLABSystem: '<Root>/PX4 PWM Output1'
  for (loiter_done = 0; loiter_done < 8; loiter_done++) {
    otter_2fixed_Loitering_missio_B.pwmValue[loiter_done] = 0U;
  }

  // DeadZone: '<S109>/Dead Zone'
  if (otter_2fixed_Loitering_missio_B.Add >
      otter_2fixed_Loitering_missio_P.DeadZone_End_e) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.Add -
      otter_2fixed_Loitering_missio_P.DeadZone_End_e;
  } else if (otter_2fixed_Loitering_missio_B.Add >=
             otter_2fixed_Loitering_missio_P.DeadZone_Start_l) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.Add -
      otter_2fixed_Loitering_missio_P.DeadZone_Start_l;
  }

  // Switch: '<S109>/Switch1' incorporates:
  //   Abs: '<S109>/Abs'
  //   Constant: '<S109>/Constant'
  //   Constant: '<S111>/Constant'
  //   DeadZone: '<S109>/Dead Zone'
  //   RelationalOperator: '<S111>/Compare'

  if (fabs(otter_2fixed_Loitering_missio_B.coslambda) <=
      otter_2fixed_Loitering_missio_P.Constant_Value_n) {
    otter_2fixed_Loitering_missio_B.Add =
      otter_2fixed_Loitering_missio_P.Constant_Value_hc;
  }

  // Lookup_n-D: '<S6>/1-D Lookup Table' incorporates:
  //   Switch: '<S109>/Switch1'

  otter_2fixed_Loitering_missio_B.Sum_jw = look1_binlxpw
    (otter_2fixed_Loitering_missio_B.Add, otter_2fixed_Loitering_missio_P.n_uniq,
     otter_2fixed_Loitering_missio_P.pwm_uniq, 186U);

  // Saturate: '<S6>/Saturation'
  if (otter_2fixed_Loitering_missio_B.Sum_jw >
      otter_2fixed_Loitering_missio_P.Saturation_UpperSat) {
    otter_2fixed_Loitering_missio_B.Sum_jw =
      otter_2fixed_Loitering_missio_P.Saturation_UpperSat;
  } else if (otter_2fixed_Loitering_missio_B.Sum_jw <
             otter_2fixed_Loitering_missio_P.Saturation_LowerSat) {
    otter_2fixed_Loitering_missio_B.Sum_jw =
      otter_2fixed_Loitering_missio_P.Saturation_LowerSat;
  }

  // DataTypeConversion: '<Root>/Data Type Conversion2' incorporates:
  //   Saturate: '<S6>/Saturation'

  otter_2fixed_Loitering_missio_B.coslambda = floor
    (otter_2fixed_Loitering_missio_B.Sum_jw);
  if (rtIsNaN(otter_2fixed_Loitering_missio_B.coslambda) || rtIsInf
      (otter_2fixed_Loitering_missio_B.coslambda)) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda = fmod
      (otter_2fixed_Loitering_missio_B.coslambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion2'

  otter_2fixed_Loitering_missio_B.pwmValue[0] = static_cast<uint16_T>
    (otter_2fixed_Loitering_missio_B.coslambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_Loitering_missio_B.coslambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_Loitering_missio_B.coslambda)));

  // DeadZone: '<S110>/Dead Zone'
  if (otter_2fixed_Loitering_missio_B.sinphi >
      otter_2fixed_Loitering_missio_P.DeadZone_End_o) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.sinphi -
      otter_2fixed_Loitering_missio_P.DeadZone_End_o;
  } else if (otter_2fixed_Loitering_missio_B.sinphi >=
             otter_2fixed_Loitering_missio_P.DeadZone_Start_m) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_B.sinphi -
      otter_2fixed_Loitering_missio_P.DeadZone_Start_m;
  }

  // Switch: '<S110>/Switch1' incorporates:
  //   Abs: '<S110>/Abs'
  //   Constant: '<S110>/Constant'
  //   Constant: '<S112>/Constant'
  //   DeadZone: '<S110>/Dead Zone'
  //   RelationalOperator: '<S112>/Compare'

  if (fabs(otter_2fixed_Loitering_missio_B.coslambda) <=
      otter_2fixed_Loitering_missio_P.Constant_Value_ft) {
    otter_2fixed_Loitering_missio_B.sinphi =
      otter_2fixed_Loitering_missio_P.Constant_Value_e;
  }

  // Lookup_n-D: '<S6>/1-D Lookup Table1' incorporates:
  //   Switch: '<S110>/Switch1'

  otter_2fixed_Loitering_missio_B.Sum_jw = look1_binlxpw
    (otter_2fixed_Loitering_missio_B.sinphi,
     otter_2fixed_Loitering_missio_P.n_uniq,
     otter_2fixed_Loitering_missio_P.pwm_uniq, 186U);

  // Saturate: '<S6>/Saturation1'
  if (otter_2fixed_Loitering_missio_B.Sum_jw >
      otter_2fixed_Loitering_missio_P.Saturation1_UpperSat) {
    otter_2fixed_Loitering_missio_B.Sum_jw =
      otter_2fixed_Loitering_missio_P.Saturation1_UpperSat;
  } else if (otter_2fixed_Loitering_missio_B.Sum_jw <
             otter_2fixed_Loitering_missio_P.Saturation1_LowerSat) {
    otter_2fixed_Loitering_missio_B.Sum_jw =
      otter_2fixed_Loitering_missio_P.Saturation1_LowerSat;
  }

  // DataTypeConversion: '<Root>/Data Type Conversion4' incorporates:
  //   Saturate: '<S6>/Saturation1'

  otter_2fixed_Loitering_missio_B.coslambda = floor
    (otter_2fixed_Loitering_missio_B.Sum_jw);
  if (rtIsNaN(otter_2fixed_Loitering_missio_B.coslambda) || rtIsInf
      (otter_2fixed_Loitering_missio_B.coslambda)) {
    otter_2fixed_Loitering_missio_B.coslambda = 0.0;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda = fmod
      (otter_2fixed_Loitering_missio_B.coslambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion4'

  otter_2fixed_Loitering_missio_B.pwmValue[1] = static_cast<uint16_T>
    (otter_2fixed_Loitering_missio_B.coslambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_Loitering_missio_B.coslambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_Loitering_missio_B.coslambda)));

  // Switch: '<S8>/Switch' incorporates:
  //   Constant: '<S8>/Constant'
  //   Constant: '<S8>/Constant1'

  if (otter_2fixed_Loitering_missio_B.In1_d.values[4] >=
      otter_2fixed_Loitering_missio_P.Switch_Threshold_i) {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_P.Constant1_Value_h;
  } else {
    otter_2fixed_Loitering_missio_B.coslambda =
      otter_2fixed_Loitering_missio_P.Constant_Value_du;
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   Constant: '<Root>/Constant1'
  //   DataTypeConversion: '<Root>/Cast To Boolean1'
  //   DataTypeConversion: '<Root>/Cast To Boolean3'
  //   Switch: '<S8>/Switch'

  if (otter_2fixed_Loitering_missio_B.coslambda != 0.0) {
    if (!otter_2fixed_Loitering_missi_DW.obj_fc.isArmed) {
      otter_2fixed_Loitering_missi_DW.obj_fc.isArmed = true;
      pwm_arm(&otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
    }

    pwm_setServo(otter_2fixed_Loitering_missi_DW.obj_fc.servoCount,
                 otter_2fixed_Loitering_missi_DW.obj_fc.channelMask,
                 &otter_2fixed_Loitering_missio_B.pwmValue[0],
                 otter_2fixed_Loitering_missi_DW.obj_fc.isMain,
                 &otter_2fixed_Loitering_missi_DW.obj_fc.actuatorAdvertiseObj);
  } else {
    pwm_disarm(&otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
    otter_2fixed_Loitering_missi_DW.obj_fc.isArmed = false;
    pwm_resetServo(otter_2fixed_Loitering_missi_DW.obj_fc.servoCount,
                   otter_2fixed_Loitering_missi_DW.obj_fc.isMain,
                   &otter_2fixed_Loitering_missi_DW.obj_fc.actuatorAdvertiseObj);
  }

  if (otter_2fixed_Loitering_missi_DW.obj_fc.isMain) {
    if (otter_2fixed_Loitering_missio_P.Constant1_Value_kc != 0.0) {
      pwm_disarm(&otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
    } else {
      pwm_arm(&otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
    }
  }

  // If: '<S47>/If1' incorporates:
  //   Constant: '<S47>/Constant'

  if (otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotati_l > 1) {
    // Outputs for IfAction SubSystem: '<S47>/If Warning//Error' incorporates:
    //   ActionPort: '<S56>/if'

    // Bias: '<S60>/Bias1' incorporates:
    //   Concatenate: '<S80>/Vector Concatenate'
    //   Math: '<S60>/Math Function'
    //   Product: '<S60>/Product'

    for (loiter_done = 0; loiter_done < 3; loiter_done++) {
      for (rtb_loiter_used = 0; rtb_loiter_used < 3; rtb_loiter_used++) {
        rtb_loiter_mode = 3 * rtb_loiter_used + loiter_done;
        otter_2fixed_Loitering_missio_B.VectorConcatenate_e[rtb_loiter_mode] =
          ((otter_2fixed_Loitering_missio_B.VectorConcatenate[3 * loiter_done +
            1] * otter_2fixed_Loitering_missio_B.VectorConcatenate[3 *
            rtb_loiter_used + 1] +
            otter_2fixed_Loitering_missio_B.VectorConcatenate[3 * loiter_done] *
            otter_2fixed_Loitering_missio_B.VectorConcatenate[3 *
            rtb_loiter_used]) +
           otter_2fixed_Loitering_missio_B.VectorConcatenate[3 * loiter_done + 2]
           * otter_2fixed_Loitering_missio_B.VectorConcatenate[3 *
           rtb_loiter_used + 2]) +
          otter_2fixed_Loitering_missio_P.Bias1_Bias[rtb_loiter_mode];
      }
    }

    // End of Bias: '<S60>/Bias1'

    // RelationalOperator: '<S68>/Compare' incorporates:
    //   Abs: '<S60>/Abs2'
    //   Constant: '<S68>/Constant'

    for (loiter_done = 0; loiter_done < 9; loiter_done++) {
      otter_2fixed_Loitering_missio_B.Compare[loiter_done] = (fabs
        (otter_2fixed_Loitering_missio_B.VectorConcatenate_e[loiter_done]) >
        otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotation);
    }

    // End of RelationalOperator: '<S68>/Compare'

    // Logic: '<S60>/Logical Operator1' incorporates:
    //   RelationalOperator: '<S68>/Compare'

    rEQ0 = otter_2fixed_Loitering_missio_B.Compare[0];
    for (loiter_done = 0; loiter_done < 8; loiter_done++) {
      rEQ0 = (rEQ0 || otter_2fixed_Loitering_missio_B.Compare[loiter_done + 1]);
    }

    // If: '<S56>/If' incorporates:
    //   Abs: '<S61>/Abs1'
    //   Bias: '<S61>/Bias'
    //   Constant: '<S70>/Constant'
    //   Logic: '<S60>/Logical Operator1'
    //   Product: '<S69>/Product'
    //   Product: '<S69>/Product1'
    //   Product: '<S69>/Product2'
    //   Product: '<S69>/Product3'
    //   Product: '<S69>/Product4'
    //   Product: '<S69>/Product5'
    //   RelationalOperator: '<S70>/Compare'
    //   Sum: '<S69>/Sum'

    if (fabs((((((otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 *
                  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 *
                  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3 -
                  otter_2fixed_Loitering_missio_B.rtb_Switch_idx_1 *
                  otter_2fixed_Loitering_missio_B.VectorConcatenate[5] *
                  otter_2fixed_Loitering_missio_B.VectorConcatenate[7]) -
                 otter_2fixed_Loitering_missio_B.VectorConcatenate[1] *
                 otter_2fixed_Loitering_missio_B.VectorConcatenate[3] *
                 otter_2fixed_Loitering_missio_B.rtb_Switch_idx_3) +
                otter_2fixed_Loitering_missio_B.VectorConcatenate[2] *
                otter_2fixed_Loitering_missio_B.VectorConcatenate[3] *
                otter_2fixed_Loitering_missio_B.VectorConcatenate[7]) +
               otter_2fixed_Loitering_missio_B.VectorConcatenate[1] *
               otter_2fixed_Loitering_missio_B.VectorConcatenate[5] *
               otter_2fixed_Loitering_missio_B.VectorConcatenate[6]) -
              otter_2fixed_Loitering_missio_B.VectorConcatenate[2] *
              otter_2fixed_Loitering_missio_B.rtb_Switch_idx_2 *
              otter_2fixed_Loitering_missio_B.VectorConcatenate[6]) +
             otter_2fixed_Loitering_missio_P.Bias_Bias) >
        otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotation) {
      // Outputs for IfAction SubSystem: '<S56>/If Not Proper' incorporates:
      //   ActionPort: '<S59>/Action Port'

      // If: '<S59>/If' incorporates:
      //   Constant: '<S59>/Constant'

      if (otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotati_l == 2)
      {
        // Outputs for IfAction SubSystem: '<S59>/Warning' incorporates:
        //   ActionPort: '<S67>/Action Port'

        // Assertion: '<S67>/Assertion' incorporates:
        //   Constant: '<S59>/Constant1'

        utAssert(otter_2fixed_Loitering_missio_P.Constant1_Value != 0.0);

        // End of Outputs for SubSystem: '<S59>/Warning'
      } else if (otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotati_l
                 == 3) {
        // Outputs for IfAction SubSystem: '<S59>/Error' incorporates:
        //   ActionPort: '<S65>/Action Port'

        // Assertion: '<S65>/Assertion' incorporates:
        //   Constant: '<S59>/Constant1'

        utAssert(otter_2fixed_Loitering_missio_P.Constant1_Value != 0.0);

        // End of Outputs for SubSystem: '<S59>/Error'
      }

      // End of If: '<S59>/If'
      // End of Outputs for SubSystem: '<S56>/If Not Proper'
    } else if (rEQ0) {
      // Outputs for IfAction SubSystem: '<S56>/Else If Not Orthogonal' incorporates:
      //   ActionPort: '<S57>/Action Port'

      // If: '<S57>/If' incorporates:
      //   Constant: '<S57>/Constant'

      if (otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotati_l == 2)
      {
        // Outputs for IfAction SubSystem: '<S57>/Warning' incorporates:
        //   ActionPort: '<S64>/Action Port'

        // Assertion: '<S64>/Assertion' incorporates:
        //   Constant: '<S57>/Constant1'

        utAssert(otter_2fixed_Loitering_missio_P.Constant1_Value_k != 0.0);

        // End of Outputs for SubSystem: '<S57>/Warning'
      } else if (otter_2fixed_Loitering_missio_P.DirectionCosineMatrixtoRotati_l
                 == 3) {
        // Outputs for IfAction SubSystem: '<S57>/Error' incorporates:
        //   ActionPort: '<S62>/Action Port'

        // Assertion: '<S62>/Assertion' incorporates:
        //   Constant: '<S57>/Constant1'

        utAssert(otter_2fixed_Loitering_missio_P.Constant1_Value_k != 0.0);

        // End of Outputs for SubSystem: '<S57>/Error'
      }

      // End of If: '<S57>/If'
      // End of Outputs for SubSystem: '<S56>/Else If Not Orthogonal'
    }

    // End of If: '<S56>/If'
    // End of Outputs for SubSystem: '<S47>/If Warning//Error'
  }

  // End of If: '<S47>/If1'

  // BusAssignment: '<S3>/Bus Assignment' incorporates:
  //   MATLABSystem: '<S3>/PX4 Timestamp'

  otter_2fixed_Loitering_missio_B.BusAssignment.timestamp = hrt_absolute_time();
  otter_2fixed_Loitering_missio_B.BusAssignment.operation_mode =
    rtb_operation_mode;

  // MATLABSystem: '<S97>/SinkBlock' incorporates:
  //   BusAssignment: '<S3>/Bus Assignment'

  uORB_write_step(otter_2fixed_Loitering_missi_DW.obj_jh.orbMetadataObj,
                  &otter_2fixed_Loitering_missi_DW.obj_jh.orbAdvertiseObj,
                  &otter_2fixed_Loitering_missio_B.BusAssignment);

  // MATLABSystem: '<S19>/SourceBlock'
  uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_p.orbMetadataObj,
                 &otter_2fixed_Loitering_missi_DW.obj_p.eventStructObj,
                 &otter_2fixed_Loitering_missio_B.r10, false, 1.0);

  // MATLABSystem: '<S16>/SourceBlock'
  uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_n.orbMetadataObj,
                 &otter_2fixed_Loitering_missi_DW.obj_n.eventStructObj,
                 &otter_2fixed_Loitering_missio_B.r5, false, 1.0);

  // MATLABSystem: '<S20>/SourceBlock'
  uORB_read_step(otter_2fixed_Loitering_missi_DW.obj_b.orbMetadataObj,
                 &otter_2fixed_Loitering_missi_DW.obj_b.eventStructObj,
                 &otter_2fixed_Loitering_missio_B.r3, false, 1.0);
}

// Model initialize function
void otter_2fixed_Loitering_mission_260921_initialize(void)
{
  // Registration code

  // initialize non-finites
  rt_InitInfAndNaN(sizeof(real_T));

  {
    static const char_T ParameterNameStr[11] = "U_SETPOINT";
    static const char_T ParameterNameStr_0[4] = "R_D";
    static const char_T ParameterNameStr_1[4] = "P_C";
    static const char_T ParameterNameStr_2[17] = "LOITER_ANGLE_DEG";
    static const char_T ParameterNameStr_3[10] = "HEADING_P";
    static const char_T ParameterNameStr_4[10] = "HEADING_D";
    static const char_T ParameterNameStr_5[12] = "SURGE_VEL_I";
    static const char_T ParameterNameStr_6[16] = "SURGE_VEL_KANTI";
    static const char_T ParameterNameStr_7[12] = "SURGE_VEL_P";
    static const char_T ParameterNameStr_8[12] = "SURGE_VEL_D";

    // Start for If: '<S3>/If'
    otter_2fixed_Loitering_missi_DW.If_ActiveSubsystem = -1;

    // SystemInitialize for Enabled SubSystem: '<S22>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S91>/In1' incorporates:
    //   Outport: '<S91>/Out1'

    otter_2fixed_Loitering_missio_B.In1_du =
      otter_2fixed_Loitering_missio_P.Out1_Y0_o;

    // End of SystemInitialize for SubSystem: '<S22>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S24>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S93>/In1' incorporates:
    //   Outport: '<S93>/Out1'

    otter_2fixed_Loitering_missio_B.In1_n =
      otter_2fixed_Loitering_missio_P.Out1_Y0_k;

    // End of SystemInitialize for SubSystem: '<S24>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S17>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S86>/In1' incorporates:
    //   Outport: '<S86>/Out1'

    otter_2fixed_Loitering_missio_B.In1_p =
      otter_2fixed_Loitering_missio_P.Out1_Y0_h;

    // End of SystemInitialize for SubSystem: '<S17>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S15>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S84>/In1' incorporates:
    //   Outport: '<S84>/Out1'

    otter_2fixed_Loitering_missio_B.In1_i =
      otter_2fixed_Loitering_missio_P.Out1_Y0_c;

    // End of SystemInitialize for SubSystem: '<S15>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S23>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S92>/In1' incorporates:
    //   Outport: '<S92>/Out1'

    otter_2fixed_Loitering_missio_B.In1_e =
      otter_2fixed_Loitering_missio_P.Out1_Y0_d;

    // End of SystemInitialize for SubSystem: '<S23>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S21>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S90>/In1' incorporates:
    //   Outport: '<S90>/Out1'

    otter_2fixed_Loitering_missio_B.In1 =
      otter_2fixed_Loitering_missio_P.Out1_Y0;

    // End of SystemInitialize for SubSystem: '<S21>/Enabled Subsystem'

    // SystemInitialize for IfAction SubSystem: '<S3>/Loitering'
    // InitializeConditions for UnitDelay: '<S95>/Unit Delay2'
    otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE =
      otter_2fixed_Loitering_missio_P.UnitDelay2_InitialCondition_p;

    // InitializeConditions for UnitDelay: '<S95>/Unit Delay1'
    otter_2fixed_Loitering_missi_DW.UnitDelay1_DSTATE =
      otter_2fixed_Loitering_missio_P.UnitDelay1_InitialCondition;

    // InitializeConditions for UnitDelay: '<S95>/Unit Delay'
    otter_2fixed_Loitering_missi_DW.UnitDelay_DSTATE =
      otter_2fixed_Loitering_missio_P.UnitDelay_InitialCondition;

    // InitializeConditions for UnitDelay: '<S95>/Unit Delay3'
    otter_2fixed_Loitering_missi_DW.UnitDelay3_DSTATE =
      otter_2fixed_Loitering_missio_P.UnitDelay3_InitialCondition;

    // End of SystemInitialize for SubSystem: '<S3>/Loitering'

    // SystemInitialize for Enabled SubSystem: '<S18>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S87>/In1' incorporates:
    //   Outport: '<S87>/Out1'

    otter_2fixed_Loitering_missio_B.In1_h =
      otter_2fixed_Loitering_missio_P.Out1_Y0_e;

    // End of SystemInitialize for SubSystem: '<S18>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<Root>/Controller'
    // InitializeConditions for UnitDelay: '<S10>/Unit Delay2'
    otter_2fixed_Loitering_missi_DW.UnitDelay2_DSTATE_f =
      otter_2fixed_Loitering_missio_P.UnitDelay2_InitialCondition;

    // InitializeConditions for DiscreteIntegrator: '<S10>/Integrator3'
    otter_2fixed_Loitering_missi_DW.Integrator3_DSTATE =
      otter_2fixed_Loitering_missio_P.Integrator3_IC;

    // InitializeConditions for DiscreteTransferFcn: '<S10>/Transfer Fcn1'
    otter_2fixed_Loitering_missi_DW.TransferFcn1_states =
      otter_2fixed_Loitering_missio_P.TransferFcn1_InitialStates;

    // Start for MATLABSystem: '<S9>/Read Parameter'
    otter_2fixed_Loitering_missi_DW.obj_ja.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_ja.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_ja.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_3[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_ja.isSetupComplete = true;

    // Start for MATLABSystem: '<S9>/Read Parameter1'
    otter_2fixed_Loitering_missi_DW.obj_j.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_j.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_j.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_4[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_j.isSetupComplete = true;

    // Start for MATLABSystem: '<S10>/Read Parameter2'
    otter_2fixed_Loitering_missi_DW.obj_lb.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_lb.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_lb.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_5[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_lb.isSetupComplete = true;

    // Start for MATLABSystem: '<S10>/Read Parameter3'
    otter_2fixed_Loitering_missi_DW.obj_p4.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_p4.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_p4.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_6[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_p4.isSetupComplete = true;

    // Start for MATLABSystem: '<S10>/Read Parameter'
    otter_2fixed_Loitering_missi_DW.obj_l4.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_l4.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_l4.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_7[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_l4.isSetupComplete = true;

    // Start for MATLABSystem: '<S10>/Read Parameter1'
    otter_2fixed_Loitering_missi_DW.obj_od.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_od.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_od.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_8[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_od.isSetupComplete = true;

    // SystemInitialize for SignalConversion generated from: '<S1>/tau_auto' incorporates:
    //   Outport: '<S1>/tau_auto'

    otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[0] =
      otter_2fixed_Loitering_missio_P.tau_auto_Y0;
    otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[1] =
      otter_2fixed_Loitering_missio_P.tau_auto_Y0;
    otter_2fixed_Loitering_missio_B.OutportBufferFortau_auto[2] =
      otter_2fixed_Loitering_missio_P.tau_auto_Y0;

    // End of SystemInitialize for SubSystem: '<Root>/Controller'

    // SystemInitialize for Enabled SubSystem: '<S105>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S106>/In1' incorporates:
    //   Outport: '<S106>/Out1'

    otter_2fixed_Loitering_missio_B.In1_d =
      otter_2fixed_Loitering_missio_P.Out1_Y0_m;

    // End of SystemInitialize for SubSystem: '<S105>/Enabled Subsystem'

    // Start for MATLABSystem: '<S22>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_f.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_f.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_f.orbMetadataObj = ORB_ID
      (vehicle_attitude);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_f.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_f.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_f.isSetupComplete = true;

    // Start for MATLABSystem: '<S24>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_o.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_o.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_o.orbMetadataObj = ORB_ID
      (vehicle_local_position);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_o.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_o.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_o.isSetupComplete = true;

    // Start for MATLABSystem: '<S17>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_e.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_e.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_e.orbMetadataObj = ORB_ID(actuator_armed);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_e.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_e.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_e.isSetupComplete = true;

    // Start for MATLABSystem: '<S15>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_nu.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_nu.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_nu.orbMetadataObj = ORB_ID
      (mission_result);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_nu.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_nu.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_nu.isSetupComplete = true;

    // Start for MATLABSystem: '<S23>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_k.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_k.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_k.orbMetadataObj = ORB_ID
      (vehicle_global_position);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_k.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_k.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_k.isSetupComplete = true;

    // Start for MATLABSystem: '<S21>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_a.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_a.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_a.orbMetadataObj = ORB_ID
      (position_setpoint_triplet);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_a.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_a.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_a.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter1'
    otter_2fixed_Loitering_missi_DW.obj_fl.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_fl.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_fl.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_fl.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter2'
    otter_2fixed_Loitering_missi_DW.obj_d.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_d.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_d.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_0[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_d.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter3'
    otter_2fixed_Loitering_missi_DW.obj_nw.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_nw.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_nw.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_1[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_nw.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter'
    otter_2fixed_Loitering_missi_DW.obj_l.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_l.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_l.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_2[0], true, 200.0);
    otter_2fixed_Loitering_missi_DW.obj_l.isSetupComplete = true;

    // Start for MATLABSystem: '<S18>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_b2.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_b2.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_b2.orbMetadataObj = ORB_ID
      (vehicle_odometry);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_b2.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_b2.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_b2.isSetupComplete = true;

    // Start for MATLABSystem: '<S105>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj.orbMetadataObj = ORB_ID(input_rc);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj.isSetupComplete = true;

    // Start for MATLABSystem: '<Root>/PX4 PWM Output1'
    otter_2fixed_Loitering_missi_DW.obj_fc.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_fc.isSetupComplete = false;
    otter_2fixed_Loitering_missi_DW.obj_fc.isInitialized = 1;
    otter_2fixed_Loit_PWM_setupImpl(&otter_2fixed_Loitering_missi_DW.obj_fc,
      false, false);
    otter_2fixed_Loitering_missi_DW.obj_fc.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/PX4 Timestamp'
    otter_2fixed_Loitering_missi_DW.obj_m.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_m.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_m.isSetupComplete = true;

    // Start for MATLABSystem: '<S97>/SinkBlock' incorporates:
    //   BusAssignment: '<S3>/Bus Assignment'

    otter_2fixed_Loitering_missi_DW.obj_jh.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_jh.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_jh.orbMetadataObj = ORB_ID
      (operation_mode);
    uORB_write_initialize(otter_2fixed_Loitering_missi_DW.obj_jh.orbMetadataObj,
                          &otter_2fixed_Loitering_missi_DW.obj_jh.orbAdvertiseObj,
                          &otter_2fixed_Loitering_missio_B.BusAssignment, 1);
    otter_2fixed_Loitering_missi_DW.obj_jh.isSetupComplete = true;

    // Start for MATLABSystem: '<S19>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_p.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_p.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_p.orbMetadataObj = ORB_ID
      (offboard_control_mode);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_p.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_p.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_p.isSetupComplete = true;

    // Start for MATLABSystem: '<S16>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_n.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_n.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_n.orbMetadataObj = ORB_ID
      (trajectory_setpoint);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_n.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_n.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_n.isSetupComplete = true;

    // Start for MATLABSystem: '<S20>/SourceBlock'
    otter_2fixed_Loitering_missi_DW.obj_b.matlabCodegenIsDeleted = false;
    otter_2fixed_Loitering_missi_DW.obj_b.isInitialized = 1;
    otter_2fixed_Loitering_missi_DW.obj_b.orbMetadataObj = ORB_ID
      (position_setpoint);
    uORB_read_initialize(otter_2fixed_Loitering_missi_DW.obj_b.orbMetadataObj,
                         &otter_2fixed_Loitering_missi_DW.obj_b.eventStructObj);
    otter_2fixed_Loitering_missi_DW.obj_b.isSetupComplete = true;
  }
}

// Model terminate function
void otter_2fixed_Loitering_mission_260921_terminate(void)
{
  // Terminate for MATLABSystem: '<S22>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_f.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_f.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_f.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_f.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_f.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S22>/SourceBlock'

  // Terminate for MATLABSystem: '<S24>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_o.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_o.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_o.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_o.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_o.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S24>/SourceBlock'

  // Terminate for MATLABSystem: '<S17>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_e.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_e.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_e.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_e.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_e.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S17>/SourceBlock'

  // Terminate for MATLABSystem: '<S15>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_nu.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_nu.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_nu.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_nu.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_nu.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S15>/SourceBlock'

  // Terminate for MATLABSystem: '<S23>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_k.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_k.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_k.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_k.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_k.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S23>/SourceBlock'

  // Terminate for MATLABSystem: '<S21>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_a.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_a.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_a.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_a.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_a.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S21>/SourceBlock'

  // Terminate for MATLABSystem: '<S3>/Read Parameter1'
  if (!otter_2fixed_Loitering_missi_DW.obj_fl.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_fl.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter1'

  // Terminate for MATLABSystem: '<S3>/Read Parameter2'
  if (!otter_2fixed_Loitering_missi_DW.obj_d.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_d.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter2'

  // Terminate for MATLABSystem: '<S3>/Read Parameter3'
  if (!otter_2fixed_Loitering_missi_DW.obj_nw.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_nw.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter3'

  // Terminate for MATLABSystem: '<S3>/Read Parameter'
  if (!otter_2fixed_Loitering_missi_DW.obj_l.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_l.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter'

  // Terminate for MATLABSystem: '<S18>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_b2.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_b2.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_b2.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_b2.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_b2.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S18>/SourceBlock'

  // Terminate for Enabled SubSystem: '<Root>/Controller'
  // Terminate for MATLABSystem: '<S9>/Read Parameter'
  if (!otter_2fixed_Loitering_missi_DW.obj_ja.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_ja.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S9>/Read Parameter'

  // Terminate for MATLABSystem: '<S9>/Read Parameter1'
  if (!otter_2fixed_Loitering_missi_DW.obj_j.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_j.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S9>/Read Parameter1'

  // Terminate for MATLABSystem: '<S10>/Read Parameter2'
  if (!otter_2fixed_Loitering_missi_DW.obj_lb.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_lb.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S10>/Read Parameter2'

  // Terminate for MATLABSystem: '<S10>/Read Parameter3'
  if (!otter_2fixed_Loitering_missi_DW.obj_p4.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_p4.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S10>/Read Parameter3'

  // Terminate for MATLABSystem: '<S10>/Read Parameter'
  if (!otter_2fixed_Loitering_missi_DW.obj_l4.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_l4.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S10>/Read Parameter'

  // Terminate for MATLABSystem: '<S10>/Read Parameter1'
  if (!otter_2fixed_Loitering_missi_DW.obj_od.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_od.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S10>/Read Parameter1'
  // End of Terminate for SubSystem: '<Root>/Controller'

  // Terminate for MATLABSystem: '<S105>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S105>/SourceBlock'

  // Terminate for MATLABSystem: '<Root>/PX4 PWM Output1'
  if (!otter_2fixed_Loitering_missi_DW.obj_fc.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_fc.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_fc.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_fc.isSetupComplete) {
      pwm_disarm(&otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
      pwm_resetServo(otter_2fixed_Loitering_missi_DW.obj_fc.servoCount,
                     otter_2fixed_Loitering_missi_DW.obj_fc.isMain,
                     &otter_2fixed_Loitering_missi_DW.obj_fc.actuatorAdvertiseObj);
      pwm_close(otter_2fixed_Loitering_missi_DW.obj_fc.servoCount,
                &otter_2fixed_Loitering_missi_DW.obj_fc.actuatorAdvertiseObj,
                &otter_2fixed_Loitering_missi_DW.obj_fc.armAdvertiseObj);
    }
  }

  // End of Terminate for MATLABSystem: '<Root>/PX4 PWM Output1'

  // Terminate for MATLABSystem: '<S3>/PX4 Timestamp'
  if (!otter_2fixed_Loitering_missi_DW.obj_m.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_m.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/PX4 Timestamp'

  // Terminate for MATLABSystem: '<S97>/SinkBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_jh.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_jh.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_jh.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_jh.isSetupComplete) {
      uORB_write_terminate
        (&otter_2fixed_Loitering_missi_DW.obj_jh.orbAdvertiseObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S97>/SinkBlock'

  // Terminate for MATLABSystem: '<S19>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_p.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_p.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_p.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_p.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_p.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S19>/SourceBlock'

  // Terminate for MATLABSystem: '<S16>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_n.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_n.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_n.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_n.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_n.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S16>/SourceBlock'

  // Terminate for MATLABSystem: '<S20>/SourceBlock'
  if (!otter_2fixed_Loitering_missi_DW.obj_b.matlabCodegenIsDeleted) {
    otter_2fixed_Loitering_missi_DW.obj_b.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_Loitering_missi_DW.obj_b.isInitialized == 1) &&
        otter_2fixed_Loitering_missi_DW.obj_b.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_Loitering_missi_DW.obj_b.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S20>/SourceBlock'
}

const char_T* RT_MODEL_otter_2fixed_Loiteri_T::getErrorStatus() const
{
  return (errorStatus);
}

void RT_MODEL_otter_2fixed_Loiteri_T::setErrorStatus(const char_T* const
  volatile aErrorStatus)
{
  (errorStatus = aErrorStatus);
}

//
// File trailer for generated code.
//
// [EOF]
//
