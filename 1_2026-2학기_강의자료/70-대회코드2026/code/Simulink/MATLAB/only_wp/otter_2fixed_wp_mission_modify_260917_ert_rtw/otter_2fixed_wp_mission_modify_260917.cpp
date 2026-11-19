//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_wp_mission_modify_260917.cpp
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
#include "otter_2fixed_wp_mission_modify_260917.h"
#include "rtwtypes.h"
#include "otter_2fixed_wp_mission_modify_260917_types.h"
#include <math.h>
#include "otter_2fixed_wp_mission_modify_260917_private.h"

extern "C"
{

#include "rt_nonfinite.h"

}

#include "rt_assert.h"
#include "rt_defines.h"
#include <float.h>

// Block signals (default storage)
B_otter_2fixed_wp_mission_mod_T otter_2fixed_wp_mission_modif_B;

// Block states (default storage)
DW_otter_2fixed_wp_mission_mo_T otter_2fixed_wp_mission_modi_DW;

// Real-time model
RT_MODEL_otter_2fixed_wp_miss_T otter_2fixed_wp_mission_modi_M_ =
  RT_MODEL_otter_2fixed_wp_miss_T();
RT_MODEL_otter_2fixed_wp_miss_T *const otter_2fixed_wp_mission_modi_M =
  &otter_2fixed_wp_mission_modi_M_;

// Forward declaration for local functions
static void otter_2fixed_wp_mission_mo_cosd(real_T *x);
static void otter_2fixed_wp_mission_mo_sind(real_T *x);
static void otter_2fixed_wp_missio_lla2ecef(const real_T llaPos[3], real_T
  ecefPos[3]);
static void otter_2fixed_wp_mission_lla2ned(const real_T lla[3], const real_T
  lla0[3], real_T xyzNED[3]);
static void otter_2fixed_wp_m_PWM_setupImpl(px4_internal_block_PWM_otter__T *obj,
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

real_T rt_remd_snf(real_T u0, real_T u1)
{
  real_T y;
  if (rtIsNaN(u0) || rtIsNaN(u1) || rtIsInf(u0)) {
    y = (rtNaN);
  } else if (rtIsInf(u1)) {
    y = u0;
  } else {
    real_T q;
    if (u1 < 0.0) {
      q = ceil(u1);
    } else {
      q = floor(u1);
    }

    if ((u1 != 0.0) && (u1 != q)) {
      q = fabs(u0 / u1);
      if (!(fabs(q - floor(q + 0.5)) > DBL_EPSILON * q)) {
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
static void otter_2fixed_wp_mission_mo_cosd(real_T *x)
{
  real_T absx;
  real_T b_x;
  int8_T n;
  if (rtIsInf(*x) || rtIsNaN(*x)) {
    *x = (rtNaN);
  } else {
    b_x = rt_remd_snf(*x, 360.0);
    absx = fabs(b_x);
    if (absx > 180.0) {
      if (b_x > 0.0) {
        b_x -= 360.0;
      } else {
        b_x += 360.0;
      }

      absx = fabs(b_x);
    }

    if (absx <= 45.0) {
      b_x *= 0.017453292519943295;
      n = 0;
    } else if (absx <= 135.0) {
      if (b_x > 0.0) {
        b_x = (b_x - 90.0) * 0.017453292519943295;
        n = 1;
      } else {
        b_x = (b_x + 90.0) * 0.017453292519943295;
        n = -1;
      }
    } else if (b_x > 0.0) {
      b_x = (b_x - 180.0) * 0.017453292519943295;
      n = 2;
    } else {
      b_x = (b_x + 180.0) * 0.017453292519943295;
      n = -2;
    }

    switch (n) {
     case 0:
      *x = cos(b_x);
      break;

     case 1:
      *x = -sin(b_x);
      break;

     case -1:
      *x = sin(b_x);
      break;

     default:
      *x = -cos(b_x);
      break;
    }
  }
}

// Function for MATLAB Function: '<S2>/MATLAB Function'
static void otter_2fixed_wp_mission_mo_sind(real_T *x)
{
  real_T absx;
  real_T b_x;
  int8_T n;
  if (rtIsInf(*x) || rtIsNaN(*x)) {
    *x = (rtNaN);
  } else {
    b_x = rt_remd_snf(*x, 360.0);
    absx = fabs(b_x);
    if (absx > 180.0) {
      if (b_x > 0.0) {
        b_x -= 360.0;
      } else {
        b_x += 360.0;
      }

      absx = fabs(b_x);
    }

    if (absx <= 45.0) {
      b_x *= 0.017453292519943295;
      n = 0;
    } else if (absx <= 135.0) {
      if (b_x > 0.0) {
        b_x = (b_x - 90.0) * 0.017453292519943295;
        n = 1;
      } else {
        b_x = (b_x + 90.0) * 0.017453292519943295;
        n = -1;
      }
    } else if (b_x > 0.0) {
      b_x = (b_x - 180.0) * 0.017453292519943295;
      n = 2;
    } else {
      b_x = (b_x + 180.0) * 0.017453292519943295;
      n = -2;
    }

    switch (n) {
     case 0:
      *x = sin(b_x);
      break;

     case 1:
      *x = cos(b_x);
      break;

     case -1:
      *x = -cos(b_x);
      break;

     default:
      *x = -sin(b_x);
      break;
    }
  }
}

// Function for MATLAB Function: '<S2>/MATLAB Function'
static void otter_2fixed_wp_missio_lla2ecef(const real_T llaPos[3], real_T
  ecefPos[3])
{
  real_T d;
  otter_2fixed_wp_mission_modif_B.sinphi_p = llaPos[0];
  otter_2fixed_wp_mission_mo_sind(&otter_2fixed_wp_mission_modif_B.sinphi_p);
  otter_2fixed_wp_mission_modif_B.N = 6.378137E+6 / sqrt(1.0 -
    otter_2fixed_wp_mission_modif_B.sinphi_p *
    otter_2fixed_wp_mission_modif_B.sinphi_p * 0.0066943799901413165);
  otter_2fixed_wp_mission_modif_B.b = llaPos[0];
  otter_2fixed_wp_mission_mo_cosd(&otter_2fixed_wp_mission_modif_B.b);
  otter_2fixed_wp_mission_modif_B.b *= otter_2fixed_wp_mission_modif_B.N +
    llaPos[2];
  otter_2fixed_wp_mission_modif_B.c = llaPos[1];
  otter_2fixed_wp_mission_mo_cosd(&otter_2fixed_wp_mission_modif_B.c);
  d = llaPos[1];
  otter_2fixed_wp_mission_mo_sind(&d);
  ecefPos[0] = otter_2fixed_wp_mission_modif_B.b *
    otter_2fixed_wp_mission_modif_B.c;
  ecefPos[1] = otter_2fixed_wp_mission_modif_B.b * d;
  ecefPos[2] = (otter_2fixed_wp_mission_modif_B.N * 0.99330562000985867 +
                llaPos[2]) * otter_2fixed_wp_mission_modif_B.sinphi_p;
}

// Function for MATLAB Function: '<S2>/MATLAB Function1'
static void otter_2fixed_wp_mission_lla2ned(const real_T lla[3], const real_T
  lla0[3], real_T xyzNED[3])
{
  otter_2fixed_wp_mission_modif_B.cosphi = lla0[0];
  otter_2fixed_wp_mission_mo_cosd(&otter_2fixed_wp_mission_modif_B.cosphi);
  otter_2fixed_wp_mission_modif_B.sinphi_k = lla0[0];
  otter_2fixed_wp_mission_mo_sind(&otter_2fixed_wp_mission_modif_B.sinphi_k);
  otter_2fixed_wp_mission_modif_B.coslambda_c = lla0[1];
  otter_2fixed_wp_mission_mo_cosd(&otter_2fixed_wp_mission_modif_B.coslambda_c);
  otter_2fixed_wp_mission_modif_B.sinlambda_b = lla0[1];
  otter_2fixed_wp_mission_mo_sind(&otter_2fixed_wp_mission_modif_B.sinlambda_b);
  otter_2fixed_wp_missio_lla2ecef(lla, otter_2fixed_wp_mission_modif_B.dv2);
  otter_2fixed_wp_missio_lla2ecef(lla0, otter_2fixed_wp_mission_modif_B.dv3);
  otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_0 =
    otter_2fixed_wp_mission_modif_B.dv2[0] -
    otter_2fixed_wp_mission_modif_B.dv3[0];
  otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_1 =
    otter_2fixed_wp_mission_modif_B.dv2[1] -
    otter_2fixed_wp_mission_modif_B.dv3[1];
  otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_2 =
    otter_2fixed_wp_mission_modif_B.dv2[2] -
    otter_2fixed_wp_mission_modif_B.dv3[2];
  otter_2fixed_wp_mission_modif_B.tmp =
    otter_2fixed_wp_mission_modif_B.coslambda_c *
    otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_0 +
    otter_2fixed_wp_mission_modif_B.sinlambda_b *
    otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_1;
  xyzNED[0] = -otter_2fixed_wp_mission_modif_B.sinphi_k *
    otter_2fixed_wp_mission_modif_B.tmp + otter_2fixed_wp_mission_modif_B.cosphi
    * otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_2;
  xyzNED[1] = -otter_2fixed_wp_mission_modif_B.sinlambda_b *
    otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_0 +
    otter_2fixed_wp_mission_modif_B.coslambda_c *
    otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_1;
  xyzNED[2] = -(otter_2fixed_wp_mission_modif_B.cosphi *
                otter_2fixed_wp_mission_modif_B.tmp +
                otter_2fixed_wp_mission_modif_B.sinphi_k *
                otter_2fixed_wp_mission_modif_B.ecefPosWithENUOrigin_idx_2);
}

static void otter_2fixed_wp_m_PWM_setupImpl(px4_internal_block_PWM_otter__T *obj,
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

  obj->channelMask = 15;
  if (obj->isMain) {
    if (forceFailsafe) {
      pwm_disarm(&obj->armAdvertiseObj);
    } else {
      pwm_arm(&obj->armAdvertiseObj);
    }
  }
}

// Model step function
void otter_2fixed_wp_mission_modify_260917_step(void)
{
  int32_T i;
  int32_T i_0;
  int32_T rtb_VectorConcatenate_e_tmp;
  real32_T ParamStep;
  real32_T ParamStep_0;
  real32_T ParamStep_1;
  real32_T ParamStep_2;
  boolean_T rEQ0;

  // MATLABSystem: '<S24>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_f.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_f.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r7, false, 1.0);

  // Outputs for Enabled SubSystem: '<S24>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S93>/Enable'

  // Start for MATLABSystem: '<S24>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S93>/In1'
    otter_2fixed_wp_mission_modif_B.In1_du = otter_2fixed_wp_mission_modif_B.r7;
  }

  // End of Outputs for SubSystem: '<S24>/Enabled Subsystem'

  // DataTypeConversion: '<S2>/Data Type Conversion3' incorporates:
  //   Switch: '<S27>/Switch'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 =
    otter_2fixed_wp_mission_modif_B.In1_du.q[0];
  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 =
    otter_2fixed_wp_mission_modif_B.In1_du.q[1];
  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 =
    otter_2fixed_wp_mission_modif_B.In1_du.q[2];
  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 =
    otter_2fixed_wp_mission_modif_B.In1_du.q[3];

  // Switch: '<S27>/Switch' incorporates:
  //   Constant: '<S27>/Constant'
  //   DataTypeConversion: '<S2>/Data Type Conversion3'
  //   Product: '<S30>/Product'
  //   Product: '<S30>/Product1'
  //   Product: '<S30>/Product2'
  //   Product: '<S30>/Product3'
  //   Sum: '<S30>/Sum'

  if (!(((static_cast<real_T>(otter_2fixed_wp_mission_modif_B.In1_du.q[0]) *
          otter_2fixed_wp_mission_modif_B.In1_du.q[0] + static_cast<real_T>
          (otter_2fixed_wp_mission_modif_B.In1_du.q[1]) *
          otter_2fixed_wp_mission_modif_B.In1_du.q[1]) + static_cast<real_T>
         (otter_2fixed_wp_mission_modif_B.In1_du.q[2]) *
         otter_2fixed_wp_mission_modif_B.In1_du.q[2]) + static_cast<real_T>
        (otter_2fixed_wp_mission_modif_B.In1_du.q[3]) *
        otter_2fixed_wp_mission_modif_B.In1_du.q[3] >
        otter_2fixed_wp_mission_modif_P.Switch_Threshold)) {
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 =
      otter_2fixed_wp_mission_modif_P.Constant_Value_lu[0];
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 =
      otter_2fixed_wp_mission_modif_P.Constant_Value_lu[1];
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 =
      otter_2fixed_wp_mission_modif_P.Constant_Value_lu[2];
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 =
      otter_2fixed_wp_mission_modif_P.Constant_Value_lu[3];
  }

  // End of Switch: '<S27>/Switch'

  // MATLABSystem: '<S26>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_o.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_o.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r1, false, 1.0);

  // Outputs for Enabled SubSystem: '<S26>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S95>/Enable'

  // Start for MATLABSystem: '<S26>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S95>/In1'
    otter_2fixed_wp_mission_modif_B.In1_n = otter_2fixed_wp_mission_modif_B.r1;
  }

  // End of Outputs for SubSystem: '<S26>/Enabled Subsystem'

  // Sqrt: '<S42>/sqrt' incorporates:
  //   Product: '<S43>/Product'
  //   Product: '<S43>/Product1'
  //   Product: '<S43>/Product2'
  //   Product: '<S43>/Product3'
  //   Sqrt: '<S84>/sqrt'
  //   Sum: '<S43>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 = sqrt
    (((otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
       otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 +
       otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 *
       otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1) +
      otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 *
      otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2) +
     otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 *
     otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3);

  // Product: '<S41>/Product' incorporates:
  //   Product: '<S83>/Product'
  //   Sqrt: '<S42>/sqrt'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 /=
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Product: '<S41>/Product1' incorporates:
  //   Product: '<S83>/Product1'
  //   Sqrt: '<S42>/sqrt'

  otter_2fixed_wp_mission_modif_B.sinphi =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 /
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Product: '<S41>/Product2' incorporates:
  //   Product: '<S83>/Product2'
  //   Sqrt: '<S42>/sqrt'

  otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 /
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Product: '<S41>/Product3' incorporates:
  //   Product: '<S83>/Product3'
  //   Sqrt: '<S42>/sqrt'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 /
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Product: '<S31>/Product3' incorporates:
  //   Product: '<S35>/Product3'
  //   Product: '<S41>/Product'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0;

  // Product: '<S31>/Product2' incorporates:
  //   Product: '<S35>/Product2'
  //   Product: '<S41>/Product1'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 =
    otter_2fixed_wp_mission_modif_B.sinphi *
    otter_2fixed_wp_mission_modif_B.sinphi;

  // Product: '<S31>/Product1' incorporates:
  //   Product: '<S35>/Product1'
  //   Product: '<S39>/Product1'
  //   Product: '<S41>/Product2'

  otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
    otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp *
    otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp;

  // Product: '<S31>/Product' incorporates:
  //   Product: '<S35>/Product'
  //   Product: '<S39>/Product'
  //   Product: '<S41>/Product3'

  otter_2fixed_wp_mission_modif_B.coslambda =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 *
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Sum: '<S31>/Sum' incorporates:
  //   Product: '<S31>/Product'
  //   Product: '<S31>/Product1'
  //   Product: '<S31>/Product2'
  //   Product: '<S31>/Product3'
  //   Sum: '<S73>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 =
    ((otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 +
      otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2) -
     otter_2fixed_wp_mission_modif_B.enuPos_idx_0) -
    otter_2fixed_wp_mission_modif_B.coslambda;
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[0] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1;

  // Product: '<S34>/Product3' incorporates:
  //   Product: '<S32>/Product3'
  //   Product: '<S41>/Product'
  //   Product: '<S41>/Product3'

  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 *
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0;

  // Product: '<S34>/Product2' incorporates:
  //   Product: '<S32>/Product2'
  //   Product: '<S41>/Product1'
  //   Product: '<S41>/Product2'

  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_B.sinphi *
    otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp;

  // Sum: '<S34>/Sum' incorporates:
  //   Product: '<S34>/Product2'
  //   Product: '<S34>/Product3'
  //   Sum: '<S76>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 =
    otter_2fixed_wp_mission_modif_B.sinlambda -
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;

  // Gain: '<S34>/Gain' incorporates:
  //   Sum: '<S34>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[1] =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain;

  // Product: '<S37>/Product2' incorporates:
  //   Product: '<S33>/Product2'
  //   Product: '<S41>/Product1'
  //   Product: '<S41>/Product3'

  otter_2fixed_wp_mission_modif_B.Fx_sat =
    otter_2fixed_wp_mission_modif_B.sinphi *
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Product: '<S37>/Product1' incorporates:
  //   Product: '<S33>/Product1'
  //   Product: '<S41>/Product'
  //   Product: '<S41>/Product2'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
    otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp;

  // Sum: '<S37>/Sum' incorporates:
  //   Product: '<S37>/Product1'
  //   Product: '<S37>/Product2'
  //   Sum: '<S79>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp_c =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp +
    otter_2fixed_wp_mission_modif_B.Fx_sat;

  // Gain: '<S37>/Gain' incorporates:
  //   Sum: '<S37>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[2] =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp_c *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_m;

  // Sum: '<S32>/Sum' incorporates:
  //   Sum: '<S74>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +=
    otter_2fixed_wp_mission_modif_B.sinlambda;

  // Gain: '<S32>/Gain' incorporates:
  //   Sum: '<S32>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3] =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_c;

  // Sum: '<S35>/Sum' incorporates:
  //   Sum: '<S39>/Sum'
  //   Sum: '<S77>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 -=
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2;
  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 =
    (otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 +
     otter_2fixed_wp_mission_modif_B.enuPos_idx_0) -
    otter_2fixed_wp_mission_modif_B.coslambda;
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[4] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2;

  // Product: '<S38>/Product1' incorporates:
  //   Product: '<S36>/Product1'
  //   Product: '<S41>/Product'
  //   Product: '<S41>/Product1'

  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
    otter_2fixed_wp_mission_modif_B.sinphi;

  // Product: '<S38>/Product2' incorporates:
  //   Product: '<S36>/Product2'
  //   Product: '<S41>/Product2'
  //   Product: '<S41>/Product3'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 *=
    otter_2fixed_wp_mission_modif_B.rtb_Product1_b_tmp;

  // Sum: '<S38>/Sum' incorporates:
  //   Product: '<S38>/Product1'
  //   Product: '<S38>/Product2'
  //   Sum: '<S80>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 -
    otter_2fixed_wp_mission_modif_B.sinlambda;

  // Gain: '<S38>/Gain' incorporates:
  //   Sum: '<S38>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[5] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_g;

  // Sum: '<S33>/Sum' incorporates:
  //   Sum: '<S75>/Sum'

  otter_2fixed_wp_mission_modif_B.Fx_sat -=
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp;

  // Gain: '<S33>/Gain' incorporates:
  //   Sum: '<S33>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[6] =
    otter_2fixed_wp_mission_modif_B.Fx_sat *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_ge;

  // Sum: '<S36>/Sum' incorporates:
  //   Sum: '<S78>/Sum'

  otter_2fixed_wp_mission_modif_B.sinlambda +=
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

  // Gain: '<S36>/Gain' incorporates:
  //   Sum: '<S36>/Sum'

  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[7] =
    otter_2fixed_wp_mission_modif_B.sinlambda *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_e;

  // Sum: '<S39>/Sum' incorporates:
  //   Sum: '<S81>/Sum'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 =
    (otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 -
     otter_2fixed_wp_mission_modif_B.enuPos_idx_0) +
    otter_2fixed_wp_mission_modif_B.coslambda;
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[8] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3;

  // Product: '<S14>/Matrix Multiply2' incorporates:
  //   Concatenate: '<S40>/Vector Concatenate'
  //   DataTypeConversion: '<S2>/Data Type Conversion1'

  for (i = 0; i < 3; i++) {
    otter_2fixed_wp_mission_modif_B.uvw[i] =
      (otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[i + 3] *
       otter_2fixed_wp_mission_modif_B.In1_n.vy +
       otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[i] *
       otter_2fixed_wp_mission_modif_B.In1_n.vx) +
      otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[i + 6] *
      otter_2fixed_wp_mission_modif_B.In1_n.vz;
  }

  // End of Product: '<S14>/Matrix Multiply2'

  // Sum: '<S73>/Sum'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[0] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1;

  // Gain: '<S76>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[1] =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_co;

  // Gain: '<S79>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[2] =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp_c *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_e1;

  // Gain: '<S74>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3] =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_h;

  // Sum: '<S77>/Sum'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[4] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2;

  // Gain: '<S80>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[5] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_o;

  // Gain: '<S75>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[6] =
    otter_2fixed_wp_mission_modif_B.Fx_sat *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_p;

  // Gain: '<S78>/Gain'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[7] =
    otter_2fixed_wp_mission_modif_B.sinlambda *
    otter_2fixed_wp_mission_modif_P.Gain_Gain_k;

  // Sum: '<S81>/Sum'
  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[8] =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3;

  // Gain: '<S48>/Gain1' incorporates:
  //   Concatenate: '<S82>/Vector Concatenate'
  //   Selector: '<S48>/Selector1'

  otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 =
    otter_2fixed_wp_mission_modif_P.Gain1_Gain[2] *
    otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[6];

  // If: '<S44>/If'
  if ((otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 >= 1.0) ||
      (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 <= -1.0)) {
    // Outputs for IfAction SubSystem: '<S44>/AxisRotZeroR3' incorporates:
    //   ActionPort: '<S47>/Action Port'

    // Fcn: '<S47>/Fcn1' incorporates:
    //   Concatenate: '<S82>/Vector Concatenate'
    //   Gain: '<S48>/Gain3'
    //   Selector: '<S48>/Selector3'

    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 =
      rt_atan2d_snf(otter_2fixed_wp_mission_modif_P.Gain3_Gain[0] *
                    otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[1],
                    otter_2fixed_wp_mission_modif_P.Gain3_Gain[1] *
                    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2);

    // End of Outputs for SubSystem: '<S44>/AxisRotZeroR3'
  } else {
    // Outputs for IfAction SubSystem: '<S44>/AxisRotDefault' incorporates:
    //   ActionPort: '<S46>/Action Port'

    // Fcn: '<S46>/Fcn1' incorporates:
    //   Concatenate: '<S82>/Vector Concatenate'
    //   Gain: '<S48>/Gain1'
    //   Selector: '<S48>/Selector1'

    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2 =
      rt_atan2d_snf(otter_2fixed_wp_mission_modif_P.Gain1_Gain[0] *
                    otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3],
                    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 *
                    otter_2fixed_wp_mission_modif_P.Gain1_Gain[1]);

    // End of Outputs for SubSystem: '<S44>/AxisRotDefault'
  }

  // End of If: '<S44>/If'

  // MATLABSystem: '<S23>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_a.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_a.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r, false, 1.0);

  // Outputs for Enabled SubSystem: '<S23>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S92>/Enable'

  // Start for MATLABSystem: '<S23>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S92>/In1'
    otter_2fixed_wp_mission_modif_B.In1 = otter_2fixed_wp_mission_modif_B.r;
  }

  // End of Outputs for SubSystem: '<S23>/Enabled Subsystem'

  // MATLAB Function: '<S2>/MATLAB Function1' incorporates:
  //   Constant: '<S2>/Constant1'
  //   SignalConversion generated from: '<S16>/ SFunction '

  otter_2fixed_wp_mission_modif_B.dv[0] =
    otter_2fixed_wp_mission_modif_B.In1.current.lat;
  otter_2fixed_wp_mission_modif_B.dv[1] =
    otter_2fixed_wp_mission_modif_B.In1.current.lon;
  otter_2fixed_wp_mission_modif_B.dv[2] = 0.0;
  otter_2fixed_wp_mission_lla2ned(otter_2fixed_wp_mission_modif_B.dv,
    otter_2fixed_wp_mission_modif_P.ref_lla,
    otter_2fixed_wp_mission_modif_B.ned2);
  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
    otter_2fixed_wp_mission_modif_B.ned2[0];
  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 =
    otter_2fixed_wp_mission_modif_B.ned2[1];

  // MATLABSystem: '<S25>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_k.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_k.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r6, false, 1.0);

  // Outputs for Enabled SubSystem: '<S25>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S94>/Enable'

  // Start for MATLABSystem: '<S25>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S94>/In1'
    otter_2fixed_wp_mission_modif_B.In1_e = otter_2fixed_wp_mission_modif_B.r6;
  }

  // End of Outputs for SubSystem: '<S25>/Enabled Subsystem'

  // MATLAB Function: '<S2>/MATLAB Function' incorporates:
  //   Constant: '<S2>/Constant'

  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 =
    otter_2fixed_wp_mission_modif_P.ref_lla[0];
  otter_2fixed_wp_mission_mo_cosd
    (&otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0);
  otter_2fixed_wp_mission_modif_B.sinphi =
    otter_2fixed_wp_mission_modif_P.ref_lla[0];
  otter_2fixed_wp_mission_mo_sind(&otter_2fixed_wp_mission_modif_B.sinphi);
  otter_2fixed_wp_mission_modif_B.coslambda =
    otter_2fixed_wp_mission_modif_P.ref_lla[1];
  otter_2fixed_wp_mission_mo_cosd(&otter_2fixed_wp_mission_modif_B.coslambda);
  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_P.ref_lla[1];
  otter_2fixed_wp_mission_mo_sind(&otter_2fixed_wp_mission_modif_B.sinlambda);
  otter_2fixed_wp_mission_modif_B.dv[0] =
    otter_2fixed_wp_mission_modif_B.In1_e.lat;
  otter_2fixed_wp_mission_modif_B.dv[1] =
    otter_2fixed_wp_mission_modif_B.In1_e.lon;
  otter_2fixed_wp_mission_modif_B.dv[2] = 0.0;
  otter_2fixed_wp_missio_lla2ecef(otter_2fixed_wp_mission_modif_B.dv,
    otter_2fixed_wp_mission_modif_B.dv1);
  otter_2fixed_wp_missio_lla2ecef(otter_2fixed_wp_mission_modif_P.ref_lla,
    otter_2fixed_wp_mission_modif_B.dv);
  otter_2fixed_wp_mission_modif_B.ned2[0] = otter_2fixed_wp_mission_modif_B.dv1
    [0] - otter_2fixed_wp_mission_modif_B.dv[0];
  otter_2fixed_wp_mission_modif_B.ned2[1] = otter_2fixed_wp_mission_modif_B.dv1
    [1] - otter_2fixed_wp_mission_modif_B.dv[1];
  otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
    -otter_2fixed_wp_mission_modif_B.sinlambda *
    otter_2fixed_wp_mission_modif_B.ned2[0] +
    otter_2fixed_wp_mission_modif_B.coslambda *
    otter_2fixed_wp_mission_modif_B.ned2[1];
  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0 =
    (otter_2fixed_wp_mission_modif_B.coslambda *
     otter_2fixed_wp_mission_modif_B.ned2[0] +
     otter_2fixed_wp_mission_modif_B.sinlambda *
     otter_2fixed_wp_mission_modif_B.ned2[1]) *
    -otter_2fixed_wp_mission_modif_B.sinphi +
    (otter_2fixed_wp_mission_modif_B.dv1[2] -
     otter_2fixed_wp_mission_modif_B.dv[2]) *
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0;
  otter_2fixed_wp_mission_modif_B.sinphi =
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0;

  // MATLABSystem: '<S3>/Read Parameter1'
  rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_kn.MW_PARAMHANDLE,
                       MW_SINGLE, &ParamStep);
  if (rEQ0) {
    ParamStep = 0.0F;
  }

  // MATLABSystem: '<S17>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_nu.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_nu.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r8, false, 1.0);

  // Outputs for Enabled SubSystem: '<S17>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S86>/Enable'

  // Start for MATLABSystem: '<S17>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S86>/In1'
    otter_2fixed_wp_mission_modif_B.In1_i = otter_2fixed_wp_mission_modif_B.r8;
  }

  // End of Outputs for SubSystem: '<S17>/Enabled Subsystem'

  // MATLAB Function: '<S3>/Atan2_guidance' incorporates:
  //   MATLAB Function: '<S2>/MATLAB Function'
  //   MATLABSystem: '<S3>/Read Parameter1'
  //
  otter_2fixed_wp_mission_modif_B.coslambda = ParamStep;
  if (otter_2fixed_wp_mission_modif_B.In1_i.finished) {
    otter_2fixed_wp_mission_modif_B.coslambda = 0.0;
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = rt_atan2d_snf
      (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
       otter_2fixed_wp_mission_modif_B.enuPos_idx_0,
       otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
       otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0);
  }

  // End of MATLAB Function: '<S3>/Atan2_guidance'

  // MATLABSystem: '<S19>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_e.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_e.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r9, false, 1.0);

  // Outputs for Enabled SubSystem: '<S19>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S88>/Enable'

  // Start for MATLABSystem: '<S19>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S88>/In1'
    otter_2fixed_wp_mission_modif_B.In1_p = otter_2fixed_wp_mission_modif_B.r9;
  }

  // End of Outputs for SubSystem: '<S19>/Enabled Subsystem'

  // MATLABSystem: '<S20>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_b2.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj_b2.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r2, false, 1.0);

  // Outputs for Enabled SubSystem: '<S20>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S89>/Enable'

  // Start for MATLABSystem: '<S20>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S89>/In1'
    otter_2fixed_wp_mission_modif_B.In1_h = otter_2fixed_wp_mission_modif_B.r2;
  }

  // End of Outputs for SubSystem: '<S20>/Enabled Subsystem'

  // Outputs for Enabled SubSystem: '<Root>/Controller' incorporates:
  //   EnablePort: '<S1>/Enable'

  // DataTypeConversion: '<S2>/Data Type Conversion7'
  if (otter_2fixed_wp_mission_modif_B.In1_p.armed) {
    if (!otter_2fixed_wp_mission_modi_DW.Controller_MODE) {
      // Enable for DiscreteIntegrator: '<S12>/Integrator3'
      otter_2fixed_wp_mission_modi_DW.Integrator3_SYSTEM_ENABLE = 1U;
      otter_2fixed_wp_mission_modi_DW.Controller_MODE = true;
    }

    // Sum: '<S11>/Sum'
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
      otter_2fixed_wp_mission_modif_B.enuPos_idx_0 -
      otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;

    // MATLAB Function: '<S11>/MATLAB Function'
    if (rtIsNaN(otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
                3.1415926535897931)) {
      otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = (rtNaN);
    } else if (rtIsInf(otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
                       3.1415926535897931)) {
      otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = (rtNaN);
    } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
               3.1415926535897931 == 0.0) {
      otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = 0.0;
    } else {
      otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = fmod
        (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 + 3.1415926535897931,
         6.2831853071795862);
      rEQ0 = (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 == 0.0);
      if (!rEQ0) {
        otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 = fabs
          ((otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
            3.1415926535897931) / 6.2831853071795862);
        rEQ0 = !(fabs(otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 - floor
                      (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 + 0.5)) >
                 2.2204460492503131E-16 *
                 otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0);
      }

      if (rEQ0) {
        otter_2fixed_wp_mission_modif_B.enuPos_idx_0 = 0.0;
      } else if (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 < 0.0) {
        otter_2fixed_wp_mission_modif_B.enuPos_idx_0 += 6.2831853071795862;
      }
    }

    // MATLABSystem: '<S11>/Read Parameter'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_ja.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep);
    if (rEQ0) {
      ParamStep = 0.0F;
    }

    // MATLABSystem: '<S11>/Read Parameter1'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_je.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_0);
    if (rEQ0) {
      ParamStep_0 = 0.0F;
    }

    // MATLABSystem: '<S12>/Read Parameter2'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_l.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_1);
    if (rEQ0) {
      ParamStep_1 = 0.0F;
    }

    // MATLABSystem: '<S12>/Read Parameter3'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_p4.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_2);
    if (rEQ0) {
      ParamStep_2 = 0.0F;
    }

    // Sum: '<S12>/Sum'
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.coslambda -
      otter_2fixed_wp_mission_modif_B.uvw[0];

    // Product: '<S12>/Product3' incorporates:
    //   MATLABSystem: '<S12>/Read Parameter2'
    //   MATLABSystem: '<S12>/Read Parameter3'
    //   Product: '<S12>/Product4'
    //   Sum: '<S12>/Sum11'
    //   UnitDelay: '<S12>/Unit Delay2'
    //
    otter_2fixed_wp_mission_modif_B.coslambda =
      (otter_2fixed_wp_mission_modif_B.sinlambda - ParamStep_2 *
       otter_2fixed_wp_mission_modi_DW.UnitDelay2_DSTATE) * ParamStep_1;

    // DiscreteIntegrator: '<S12>/Integrator3'
    if (otter_2fixed_wp_mission_modi_DW.Integrator3_SYSTEM_ENABLE != 0) {
      // DiscreteIntegrator: '<S12>/Integrator3'
      otter_2fixed_wp_mission_modif_B.Integrator3 =
        otter_2fixed_wp_mission_modi_DW.Integrator3_DSTATE;
    } else {
      // DiscreteIntegrator: '<S12>/Integrator3'
      otter_2fixed_wp_mission_modif_B.Integrator3 =
        otter_2fixed_wp_mission_modif_P.Integrator3_gainval *
        otter_2fixed_wp_mission_modif_B.coslambda +
        otter_2fixed_wp_mission_modi_DW.Integrator3_DSTATE;
    }

    // End of DiscreteIntegrator: '<S12>/Integrator3'

    // MATLABSystem: '<S12>/Read Parameter'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_l4.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_1);
    if (rEQ0) {
      ParamStep_1 = 0.0F;
    }

    // DiscreteTransferFcn: '<S12>/Transfer Fcn1'
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
      (otter_2fixed_wp_mission_modif_B.sinlambda -
       otter_2fixed_wp_mission_modif_P.TransferFcn1_DenCoef[1] *
       otter_2fixed_wp_mission_modi_DW.TransferFcn1_states) /
      otter_2fixed_wp_mission_modif_P.TransferFcn1_DenCoef[0];

    // MATLABSystem: '<S12>/Read Parameter1'
    rEQ0 = MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_od.MW_PARAMHANDLE,
                         MW_SINGLE, &ParamStep_2);
    if (rEQ0) {
      ParamStep_2 = 0.0F;
    }

    // Sum: '<S12>/Sum9' incorporates:
    //   DiscreteTransferFcn: '<S12>/Transfer Fcn1'
    //   MATLABSystem: '<S12>/Read Parameter'
    //   MATLABSystem: '<S12>/Read Parameter1'
    //   Product: '<S12>/Product1'
    //   Product: '<S12>/Product2'
    //
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 =
      (otter_2fixed_wp_mission_modif_P.TransferFcn1_NumCoef[0] *
       otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
       otter_2fixed_wp_mission_modif_P.TransferFcn1_NumCoef[1] *
       otter_2fixed_wp_mission_modi_DW.TransferFcn1_states) * ParamStep_2 +
      (otter_2fixed_wp_mission_modif_B.sinlambda * ParamStep_1 +
       otter_2fixed_wp_mission_modif_B.Integrator3);

    // Saturate: '<S12>/sat1'
    if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >
        otter_2fixed_wp_mission_modif_P.Fx_max) {
      otter_2fixed_wp_mission_modif_B.Fx_sat =
        otter_2fixed_wp_mission_modif_P.Fx_max;
    } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 <
               otter_2fixed_wp_mission_modif_P.Fx_min) {
      otter_2fixed_wp_mission_modif_B.Fx_sat =
        otter_2fixed_wp_mission_modif_P.Fx_min;
    } else {
      otter_2fixed_wp_mission_modif_B.Fx_sat =
        otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
    }

    // End of Saturate: '<S12>/sat1'

    // Sum: '<S11>/Sum2' incorporates:
    //   DataTypeConversion: '<S2>/Data Type Conversion2'
    //   MATLAB Function: '<S11>/MATLAB Function'
    //   MATLABSystem: '<S11>/Read Parameter'
    //   MATLABSystem: '<S11>/Read Parameter1'
    //   Product: '<S11>/Product'
    //   Product: '<S11>/Product1'
    //
    otter_2fixed_wp_mission_modif_B.sinlambda =
      (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 - 3.1415926535897931) *
      ParamStep - static_cast<real_T>
      (otter_2fixed_wp_mission_modif_B.In1_h.angular_velocity[2]) * ParamStep_0;

    // SignalConversion generated from: '<S1>/tau_auto' incorporates:
    //   Constant: '<S1>/Constant'

    otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[0] =
      otter_2fixed_wp_mission_modif_B.Fx_sat;
    otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[1] =
      otter_2fixed_wp_mission_modif_P.Constant_Value_j;

    // Saturate: '<S11>/stern constraint'
    if (otter_2fixed_wp_mission_modif_B.sinlambda >
        otter_2fixed_wp_mission_modif_P.N_max) {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[2] =
        otter_2fixed_wp_mission_modif_P.N_max;
    } else if (otter_2fixed_wp_mission_modif_B.sinlambda <
               otter_2fixed_wp_mission_modif_P.N_min) {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[2] =
        otter_2fixed_wp_mission_modif_P.N_min;
    } else {
      // SignalConversion generated from: '<S1>/tau_auto'
      otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[2] =
        otter_2fixed_wp_mission_modif_B.sinlambda;
    }

    // End of Saturate: '<S11>/stern constraint'

    // Sum: '<S12>/Sum10' incorporates:
    //   UnitDelay: '<S12>/Unit Delay2'

    otter_2fixed_wp_mission_modi_DW.UnitDelay2_DSTATE =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
      otter_2fixed_wp_mission_modif_B.Fx_sat;

    // Update for DiscreteIntegrator: '<S12>/Integrator3'
    otter_2fixed_wp_mission_modi_DW.Integrator3_SYSTEM_ENABLE = 0U;
    otter_2fixed_wp_mission_modi_DW.Integrator3_DSTATE =
      otter_2fixed_wp_mission_modif_P.Integrator3_gainval *
      otter_2fixed_wp_mission_modif_B.coslambda +
      otter_2fixed_wp_mission_modif_B.Integrator3;

    // Update for DiscreteTransferFcn: '<S12>/Transfer Fcn1'
    otter_2fixed_wp_mission_modi_DW.TransferFcn1_states =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  } else if (otter_2fixed_wp_mission_modi_DW.Controller_MODE) {
    // Disable for DiscreteIntegrator: '<S12>/Integrator3'
    otter_2fixed_wp_mission_modi_DW.Integrator3_DSTATE =
      otter_2fixed_wp_mission_modif_B.Integrator3;
    otter_2fixed_wp_mission_modi_DW.Controller_MODE = false;
  }

  // End of DataTypeConversion: '<S2>/Data Type Conversion7'
  // End of Outputs for SubSystem: '<Root>/Controller'

  // MATLABSystem: '<S97>/SourceBlock'
  rEQ0 = uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj.orbMetadataObj,
                        &otter_2fixed_wp_mission_modi_DW.obj.eventStructObj,
                        &otter_2fixed_wp_mission_modif_B.r4, false, 5000.0);

  // Outputs for Enabled SubSystem: '<S97>/Enabled Subsystem' incorporates:
  //   EnablePort: '<S98>/Enable'

  // Start for MATLABSystem: '<S97>/SourceBlock'
  if (rEQ0) {
    // SignalConversion generated from: '<S98>/In1'
    otter_2fixed_wp_mission_modif_B.In1_d = otter_2fixed_wp_mission_modif_B.r4;
  }

  // End of Outputs for SubSystem: '<S97>/Enabled Subsystem'

  // Gain: '<S9>/Gain'
  otter_2fixed_wp_mission_modif_B.sinlambda = 1.0 /
    (otter_2fixed_wp_mission_modif_P.RC_max -
     otter_2fixed_wp_mission_modif_P.RC_min);

  // Sum: '<S9>/Sum' incorporates:
  //   Constant: '<S9>/Constant'
  //   Constant: '<S9>/Constant2'
  //   Gain: '<S9>/Gain'
  //   Gain: '<S9>/Gain1'
  //   Sum: '<S9>/Sum1'

  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 = (static_cast<real_T>
    (otter_2fixed_wp_mission_modif_B.In1_d.values[2]) +
    otter_2fixed_wp_mission_modif_P.Constant2_Value[0]) *
    otter_2fixed_wp_mission_modif_B.sinlambda *
    otter_2fixed_wp_mission_modif_P.Gain1_Gain_o +
    otter_2fixed_wp_mission_modif_P.Constant_Value_dl[0];
  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 = (static_cast<real_T>
    (otter_2fixed_wp_mission_modif_B.In1_d.values[0]) +
    otter_2fixed_wp_mission_modif_P.Constant2_Value[1]) *
    otter_2fixed_wp_mission_modif_B.sinlambda *
    otter_2fixed_wp_mission_modif_P.Gain1_Gain_o +
    otter_2fixed_wp_mission_modif_P.Constant_Value_dl[1];

  // DeadZone: '<S106>/Dead Zone'
  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >
      otter_2fixed_wp_mission_modif_P.DeadZone_End) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
      otter_2fixed_wp_mission_modif_P.DeadZone_End;
  } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >=
             otter_2fixed_wp_mission_modif_P.DeadZone_Start) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
      otter_2fixed_wp_mission_modif_P.DeadZone_Start;
  }

  // Switch: '<S106>/Switch1' incorporates:
  //   Abs: '<S106>/Abs'
  //   Constant: '<S108>/Constant'
  //   DeadZone: '<S106>/Dead Zone'
  //   RelationalOperator: '<S108>/Compare'

  if (fabs(otter_2fixed_wp_mission_modif_B.sinlambda) <=
      otter_2fixed_wp_mission_modif_P.Constant_Value_ex) {
    // SignalConversion generated from: '<S99>/ SFunction ' incorporates:
    //   Constant: '<S106>/Constant'
    //   MATLAB Function: '<S8>/MATLAB Function'

    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
      otter_2fixed_wp_mission_modif_P.Constant_Value_db;
  } else {
    // SignalConversion generated from: '<S99>/ SFunction ' incorporates:
    //   MATLAB Function: '<S8>/MATLAB Function'

    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  }

  // End of Switch: '<S106>/Switch1'

  // DeadZone: '<S105>/Dead Zone'
  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >
      otter_2fixed_wp_mission_modif_P.DeadZone_End_h) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
      otter_2fixed_wp_mission_modif_P.DeadZone_End_h;
  } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >=
             otter_2fixed_wp_mission_modif_P.DeadZone_Start_o) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
      otter_2fixed_wp_mission_modif_P.DeadZone_Start_o;
  }

  // Switch: '<S105>/Switch1' incorporates:
  //   Abs: '<S105>/Abs'
  //   Constant: '<S107>/Constant'
  //   DeadZone: '<S105>/Dead Zone'
  //   RelationalOperator: '<S107>/Compare'

  if (fabs(otter_2fixed_wp_mission_modif_B.sinlambda) <=
      otter_2fixed_wp_mission_modif_P.Constant_Value_bp) {
    // SignalConversion generated from: '<S99>/ SFunction ' incorporates:
    //   Constant: '<S105>/Constant'
    //   MATLAB Function: '<S8>/MATLAB Function'

    otter_2fixed_wp_mission_modif_B.coslambda =
      otter_2fixed_wp_mission_modif_P.Constant_Value_if;
  } else {
    // SignalConversion generated from: '<S99>/ SFunction ' incorporates:
    //   MATLAB Function: '<S8>/MATLAB Function'

    otter_2fixed_wp_mission_modif_B.coslambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  }

  // End of Switch: '<S105>/Switch1'

  // MATLAB Function: '<S8>/MATLAB Function' incorporates:
  //   Constant: '<S8>/Constant16'
  //   Constant: '<S8>/Constant17'

  if (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 < 0.0) {
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
      (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 + 1.0) * (0.0 -
      otter_2fixed_wp_mission_modif_P.Constant17_Value[0]) +
      otter_2fixed_wp_mission_modif_P.Constant17_Value[0];
  } else {
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 *=
      otter_2fixed_wp_mission_modif_P.Constant16_Value[0];
  }

  if (otter_2fixed_wp_mission_modif_B.coslambda < 0.0) {
    otter_2fixed_wp_mission_modif_B.coslambda =
      (otter_2fixed_wp_mission_modif_B.coslambda + 1.0) * (0.0 -
      otter_2fixed_wp_mission_modif_P.Constant17_Value[2]) +
      otter_2fixed_wp_mission_modif_P.Constant17_Value[2];
  } else {
    otter_2fixed_wp_mission_modif_B.coslambda *=
      otter_2fixed_wp_mission_modif_P.Constant16_Value[2];
  }

  // Switch: '<S6>/Switch' incorporates:
  //   Constant: '<S6>/Constant'
  //   Constant: '<S6>/Constant1'

  if (otter_2fixed_wp_mission_modif_B.In1_d.values[6] >=
      otter_2fixed_wp_mission_modif_P.Switch_Threshold_a) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant1_Value_l;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant_Value_ds;
  }

  // Switch: '<S8>/Switch2' incorporates:
  //   Gain: '<S8>/Gain4'
  //   Switch: '<S6>/Switch'

  if (otter_2fixed_wp_mission_modif_B.sinlambda >
      otter_2fixed_wp_mission_modif_P.Switch2_Threshold) {
    otter_2fixed_wp_mission_modif_B.coslambda *=
      otter_2fixed_wp_mission_modif_P.Gain4_Gain;
  } else {
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0 =
      otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[0];
    otter_2fixed_wp_mission_modif_B.coslambda =
      otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[2];
  }

  // End of Switch: '<S8>/Switch2'

  // MATLAB Function: '<S8>/MATLAB Function1' incorporates:
  //   Constant: '<S8>/Constant1'
  //   Constant: '<S8>/Constant2'
  //   Constant: '<S8>/Constant3'
  //   SignalConversion generated from: '<S100>/ SFunction '

  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_B.coslambda /
    otter_2fixed_wp_mission_modif_P.d;
  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
    (otter_2fixed_wp_mission_modif_B.sinlambda +
     otter_2fixed_wp_mission_modif_B.enuPos_idx_0) / 2.0;
  otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 =
    (otter_2fixed_wp_mission_modif_B.enuPos_idx_0 -
     otter_2fixed_wp_mission_modif_B.sinlambda) / 2.0;
  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  otter_2fixed_wp_mission_modif_B.Fx_sat =
    otter_2fixed_wp_mission_modif_P.Thrust_max -
    otter_2fixed_wp_mission_modif_P.Thrust_min;
  if (fabs(otter_2fixed_wp_mission_modif_B.sinlambda) >
      otter_2fixed_wp_mission_modif_B.Fx_sat) {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 =
      (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +
       otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1) / 2.0;
    if (rtIsNaN(otter_2fixed_wp_mission_modif_B.sinlambda)) {
      otter_2fixed_wp_mission_modif_B.sinlambda = (rtNaN);
    } else if (otter_2fixed_wp_mission_modif_B.sinlambda < 0.0) {
      otter_2fixed_wp_mission_modif_B.sinlambda = -1.0;
    } else {
      otter_2fixed_wp_mission_modif_B.sinlambda =
        (otter_2fixed_wp_mission_modif_B.sinlambda > 0.0);
    }

    otter_2fixed_wp_mission_modif_B.sinlambda *=
      otter_2fixed_wp_mission_modif_B.Fx_sat;
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 =
      otter_2fixed_wp_mission_modif_B.sinlambda / 2.0 +
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -=
      otter_2fixed_wp_mission_modif_B.sinlambda / 2.0;
  }

  if ((otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >=
       otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1) || rtIsNaN
      (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1)) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  }

  otter_2fixed_wp_mission_modif_B.sinlambda -=
    otter_2fixed_wp_mission_modif_P.Thrust_max;
  if (otter_2fixed_wp_mission_modif_B.sinlambda > 0.0) {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -=
      otter_2fixed_wp_mission_modif_B.sinlambda;
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -=
      otter_2fixed_wp_mission_modif_B.sinlambda;
  }

  if ((otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 <=
       otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1) || rtIsNaN
      (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1)) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  }

  otter_2fixed_wp_mission_modif_B.sinlambda =
    otter_2fixed_wp_mission_modif_P.Thrust_min -
    otter_2fixed_wp_mission_modif_B.sinlambda;
  if (otter_2fixed_wp_mission_modif_B.sinlambda > 0.0) {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 +=
      otter_2fixed_wp_mission_modif_B.sinlambda;
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 +=
      otter_2fixed_wp_mission_modif_B.sinlambda;
  }

  // Gain: '<S8>/1//k_pos'
  otter_2fixed_wp_mission_modif_B.sinlambda = 1.0 /
    otter_2fixed_wp_mission_modif_P.k_pos;

  // Gain: '<S8>/1//k_pos1'
  otter_2fixed_wp_mission_modif_B.Fx_sat = 1.0 /
    otter_2fixed_wp_mission_modif_P.k_neg;

  // Sqrt: '<S8>/Signed Square Root' incorporates:
  //   Gain: '<S8>/1//k_pos'
  //   Gain: '<S8>/1//k_pos1'
  //   MATLAB Function: '<S8>/MATLAB Function1'
  //   Switch: '<S8>/Switch'
  //
  //  About '<S8>/Signed Square Root':
  //   Operator: signedSqrt

  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >
      otter_2fixed_wp_mission_modif_P.Switch_Threshold_c) {
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp =
      otter_2fixed_wp_mission_modif_B.sinlambda *
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  } else {
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp =
      otter_2fixed_wp_mission_modif_B.Fx_sat *
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  }

  if (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp < 0.0) {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 = -sqrt(fabs
      (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp));
  } else {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 = sqrt
      (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp);
  }

  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >
      otter_2fixed_wp_mission_modif_P.Switch_Threshold_c) {
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp =
      otter_2fixed_wp_mission_modif_B.sinlambda *
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  } else {
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp =
      otter_2fixed_wp_mission_modif_B.Fx_sat *
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  }

  if (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp < 0.0) {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 = -sqrt(fabs
      (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp));
  } else {
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 = sqrt
      (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_tmp);
  }

  // End of Sqrt: '<S8>/Signed Square Root'

  // MATLABSystem: '<Root>/PX4 PWM Output1'
  for (i = 0; i < 8; i++) {
    otter_2fixed_wp_mission_modif_B.pwmValue[i] = 0U;
  }

  // DeadZone: '<S101>/Dead Zone'
  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >
      otter_2fixed_wp_mission_modif_P.DeadZone_End_e) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
      otter_2fixed_wp_mission_modif_P.DeadZone_End_e;
  } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 >=
             otter_2fixed_wp_mission_modif_P.DeadZone_Start_l) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0 -
      otter_2fixed_wp_mission_modif_P.DeadZone_Start_l;
  }

  // Switch: '<S101>/Switch1' incorporates:
  //   Abs: '<S101>/Abs'
  //   Constant: '<S101>/Constant'
  //   Constant: '<S103>/Constant'
  //   DeadZone: '<S101>/Dead Zone'
  //   RelationalOperator: '<S103>/Compare'

  if (fabs(otter_2fixed_wp_mission_modif_B.sinlambda) <=
      otter_2fixed_wp_mission_modif_P.Constant_Value_n) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant_Value_hc;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  }

  // Lookup_n-D: '<S8>/1-D Lookup Table' incorporates:
  //   Switch: '<S101>/Switch1'

  otter_2fixed_wp_mission_modif_B.sinlambda = look1_binlxpw
    (otter_2fixed_wp_mission_modif_B.sinlambda,
     otter_2fixed_wp_mission_modif_P.n_uniq,
     otter_2fixed_wp_mission_modif_P.pwm_uniq, 186U);

  // Saturate: '<S8>/Saturation'
  if (otter_2fixed_wp_mission_modif_B.sinlambda >
      otter_2fixed_wp_mission_modif_P.Saturation_UpperSat) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Saturation_UpperSat;
  } else if (otter_2fixed_wp_mission_modif_B.sinlambda <
             otter_2fixed_wp_mission_modif_P.Saturation_LowerSat) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Saturation_LowerSat;
  }

  // DataTypeConversion: '<Root>/Data Type Conversion2' incorporates:
  //   Saturate: '<S8>/Saturation'

  otter_2fixed_wp_mission_modif_B.sinlambda = floor
    (otter_2fixed_wp_mission_modif_B.sinlambda);
  if (rtIsNaN(otter_2fixed_wp_mission_modif_B.sinlambda) || rtIsInf
      (otter_2fixed_wp_mission_modif_B.sinlambda)) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda = fmod
      (otter_2fixed_wp_mission_modif_B.sinlambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion2'

  otter_2fixed_wp_mission_modif_B.pwmValue[0] = static_cast<uint16_T>
    (otter_2fixed_wp_mission_modif_B.sinlambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_wp_mission_modif_B.sinlambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_wp_mission_modif_B.sinlambda)));

  // DeadZone: '<S102>/Dead Zone'
  if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >
      otter_2fixed_wp_mission_modif_P.DeadZone_End_o) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
      otter_2fixed_wp_mission_modif_P.DeadZone_End_o;
  } else if (otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 >=
             otter_2fixed_wp_mission_modif_P.DeadZone_Start_m) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1 -
      otter_2fixed_wp_mission_modif_P.DeadZone_Start_m;
  }

  // Switch: '<S102>/Switch1' incorporates:
  //   Abs: '<S102>/Abs'
  //   Constant: '<S102>/Constant'
  //   Constant: '<S104>/Constant'
  //   DeadZone: '<S102>/Dead Zone'
  //   RelationalOperator: '<S104>/Compare'

  if (fabs(otter_2fixed_wp_mission_modif_B.sinlambda) <=
      otter_2fixed_wp_mission_modif_P.Constant_Value_ft) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant_Value_e;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  }

  // Lookup_n-D: '<S8>/1-D Lookup Table1' incorporates:
  //   Switch: '<S102>/Switch1'

  otter_2fixed_wp_mission_modif_B.sinlambda = look1_binlxpw
    (otter_2fixed_wp_mission_modif_B.sinlambda,
     otter_2fixed_wp_mission_modif_P.n_uniq,
     otter_2fixed_wp_mission_modif_P.pwm_uniq, 186U);

  // Saturate: '<S8>/Saturation1'
  if (otter_2fixed_wp_mission_modif_B.sinlambda >
      otter_2fixed_wp_mission_modif_P.Saturation1_UpperSat) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Saturation1_UpperSat;
  } else if (otter_2fixed_wp_mission_modif_B.sinlambda <
             otter_2fixed_wp_mission_modif_P.Saturation1_LowerSat) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Saturation1_LowerSat;
  }

  // DataTypeConversion: '<Root>/Data Type Conversion4' incorporates:
  //   Saturate: '<S8>/Saturation1'

  otter_2fixed_wp_mission_modif_B.sinlambda = floor
    (otter_2fixed_wp_mission_modif_B.sinlambda);
  if (rtIsNaN(otter_2fixed_wp_mission_modif_B.sinlambda) || rtIsInf
      (otter_2fixed_wp_mission_modif_B.sinlambda)) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda = fmod
      (otter_2fixed_wp_mission_modif_B.sinlambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion4'

  otter_2fixed_wp_mission_modif_B.pwmValue[1] = static_cast<uint16_T>
    (otter_2fixed_wp_mission_modif_B.sinlambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_wp_mission_modif_B.sinlambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_wp_mission_modif_B.sinlambda)));

  // DataTypeConversion: '<Root>/Data Type Conversion3' incorporates:
  //   Constant: '<Root>/Constant5'

  otter_2fixed_wp_mission_modif_B.sinlambda = floor
    (otter_2fixed_wp_mission_modif_P.Constant5_Value);
  if (rtIsNaN(otter_2fixed_wp_mission_modif_B.sinlambda) || rtIsInf
      (otter_2fixed_wp_mission_modif_B.sinlambda)) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda = fmod
      (otter_2fixed_wp_mission_modif_B.sinlambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion3'

  otter_2fixed_wp_mission_modif_B.pwmValue[2] = static_cast<uint16_T>
    (otter_2fixed_wp_mission_modif_B.sinlambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_wp_mission_modif_B.sinlambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_wp_mission_modif_B.sinlambda)));

  // DataTypeConversion: '<Root>/Data Type Conversion5' incorporates:
  //   Constant: '<Root>/Constant6'

  otter_2fixed_wp_mission_modif_B.sinlambda = floor
    (otter_2fixed_wp_mission_modif_P.Constant6_Value);
  if (rtIsNaN(otter_2fixed_wp_mission_modif_B.sinlambda) || rtIsInf
      (otter_2fixed_wp_mission_modif_B.sinlambda)) {
    otter_2fixed_wp_mission_modif_B.sinlambda = 0.0;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda = fmod
      (otter_2fixed_wp_mission_modif_B.sinlambda, 65536.0);
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   DataTypeConversion: '<Root>/Data Type Conversion5'

  otter_2fixed_wp_mission_modif_B.pwmValue[3] = static_cast<uint16_T>
    (otter_2fixed_wp_mission_modif_B.sinlambda < 0.0 ? static_cast<int32_T>(
      static_cast<uint16_T>(-static_cast<int16_T>(static_cast<uint16_T>
        (-otter_2fixed_wp_mission_modif_B.sinlambda)))) : static_cast<int32_T>(
      static_cast<uint16_T>(otter_2fixed_wp_mission_modif_B.sinlambda)));

  // Switch: '<S10>/Switch' incorporates:
  //   Constant: '<S10>/Constant'
  //   Constant: '<S10>/Constant1'

  if (otter_2fixed_wp_mission_modif_B.In1_d.values[4] >=
      otter_2fixed_wp_mission_modif_P.Switch_Threshold_i) {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant1_Value_h;
  } else {
    otter_2fixed_wp_mission_modif_B.sinlambda =
      otter_2fixed_wp_mission_modif_P.Constant_Value_du;
  }

  // MATLABSystem: '<Root>/PX4 PWM Output1' incorporates:
  //   Constant: '<Root>/Constant1'
  //   DataTypeConversion: '<Root>/Cast To Boolean1'
  //   DataTypeConversion: '<Root>/Cast To Boolean3'
  //   Switch: '<S10>/Switch'

  if (otter_2fixed_wp_mission_modif_B.sinlambda != 0.0) {
    if (!otter_2fixed_wp_mission_modi_DW.obj_fc.isArmed) {
      otter_2fixed_wp_mission_modi_DW.obj_fc.isArmed = true;
      pwm_arm(&otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
    }

    pwm_setServo(otter_2fixed_wp_mission_modi_DW.obj_fc.servoCount,
                 otter_2fixed_wp_mission_modi_DW.obj_fc.channelMask,
                 &otter_2fixed_wp_mission_modif_B.pwmValue[0],
                 otter_2fixed_wp_mission_modi_DW.obj_fc.isMain,
                 &otter_2fixed_wp_mission_modi_DW.obj_fc.actuatorAdvertiseObj);
  } else {
    pwm_disarm(&otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
    otter_2fixed_wp_mission_modi_DW.obj_fc.isArmed = false;
    pwm_resetServo(otter_2fixed_wp_mission_modi_DW.obj_fc.servoCount,
                   otter_2fixed_wp_mission_modi_DW.obj_fc.isMain,
                   &otter_2fixed_wp_mission_modi_DW.obj_fc.actuatorAdvertiseObj);
  }

  if (otter_2fixed_wp_mission_modi_DW.obj_fc.isMain) {
    if (otter_2fixed_wp_mission_modif_P.Constant1_Value_kc != 0.0) {
      pwm_disarm(&otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
    } else {
      pwm_arm(&otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
    }
  }

  // MATLABSystem: '<Root>/PX4 Timestamp1'
  otter_2fixed_wp_mission_modif_B.rtb_PX4Timestamp1_f = hrt_absolute_time();

  // BusAssignment: '<Root>/Bus Assignment1' incorporates:
  //   Constant: '<S4>/Constant'

  otter_2fixed_wp_mission_modif_B.BusAssignment1 =
    otter_2fixed_wp_mission_modif_P.Constant_Value_k;

  // BusAssignment: '<Root>/Bus Assignment1' incorporates:
  //   Constant: '<Root>/Constant'
  //   Constant: '<Root>/Constant2'
  //   Constant: '<Root>/Constant3'
  //   Constant: '<Root>/Constant4'
  //   DataTypeConversion: '<S2>/Data Type Conversion2'
  //   MATLAB Function: '<S2>/MATLAB Function'
  //   MATLABSystem: '<Root>/PX4 Timestamp1'

  otter_2fixed_wp_mission_modif_B.BusAssignment1.timestamp =
    otter_2fixed_wp_mission_modif_B.rtb_PX4Timestamp1_f;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.u_time_log =
    otter_2fixed_wp_mission_modif_B.uvw[0];
  otter_2fixed_wp_mission_modif_B.BusAssignment1.v_time_log =
    otter_2fixed_wp_mission_modif_B.uvw[1];
  otter_2fixed_wp_mission_modif_B.BusAssignment1.r_time_log =
    otter_2fixed_wp_mission_modif_B.In1_h.angular_velocity[2];
  otter_2fixed_wp_mission_modif_B.BusAssignment1.x_time_log =
    otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_0;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.y_time_log =
    otter_2fixed_wp_mission_modif_B.sinphi;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.psi_time_log =
    otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_c_idx_2;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.taux_time_log =
    otter_2fixed_wp_mission_modif_B.enuPos_idx_0;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.tauy_time_log =
    otter_2fixed_wp_mission_modif_P.Constant_Value_gh;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.taun_time_log =
    otter_2fixed_wp_mission_modif_B.coslambda;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.motor1_time_log =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_0;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.motor2_time_log =
    otter_2fixed_wp_mission_modif_B.rtb_cur_ne_idx_1;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.motor3_time_log =
    otter_2fixed_wp_mission_modif_P.Constant3_Value;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.motor4_time_log =
    otter_2fixed_wp_mission_modif_P.Constant4_Value_o;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.alpha1_time_log =
    otter_2fixed_wp_mission_modif_P.Constant2_Value_e;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.alpha2_time_log =
    otter_2fixed_wp_mission_modif_P.Constant2_Value_e;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.alpha3_time_log =
    otter_2fixed_wp_mission_modif_P.Constant2_Value_e;
  otter_2fixed_wp_mission_modif_B.BusAssignment1.alpha4_time_log =
    otter_2fixed_wp_mission_modif_P.Constant2_Value_e;

  // MATLABSystem: '<S5>/SinkBlock' incorporates:
  //   BusAssignment: '<Root>/Bus Assignment1'

  uORB_write_step(otter_2fixed_wp_mission_modi_DW.obj_c.orbMetadataObj,
                  &otter_2fixed_wp_mission_modi_DW.obj_c.orbAdvertiseObj,
                  &otter_2fixed_wp_mission_modif_B.BusAssignment1);

  // If: '<S49>/If1' incorporates:
  //   Constant: '<S49>/Constant'

  if (otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotati_l > 1) {
    // Outputs for IfAction SubSystem: '<S49>/If Warning//Error' incorporates:
    //   ActionPort: '<S58>/if'

    // Bias: '<S62>/Bias1' incorporates:
    //   Concatenate: '<S82>/Vector Concatenate'
    //   Math: '<S62>/Math Function'
    //   Product: '<S62>/Product'

    for (i = 0; i < 3; i++) {
      for (i_0 = 0; i_0 < 3; i_0++) {
        rtb_VectorConcatenate_e_tmp = 3 * i_0 + i;
        otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_m[rtb_VectorConcatenate_e_tmp]
          = ((otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i + 1] *
              otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i_0 + 1] +
              otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i] *
              otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i_0]) +
             otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i + 2] *
             otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3 * i_0 + 2]) +
          otter_2fixed_wp_mission_modif_P.Bias1_Bias[rtb_VectorConcatenate_e_tmp];
      }
    }

    // End of Bias: '<S62>/Bias1'

    // RelationalOperator: '<S70>/Compare' incorporates:
    //   Abs: '<S62>/Abs2'
    //   Constant: '<S70>/Constant'

    for (i = 0; i < 9; i++) {
      otter_2fixed_wp_mission_modif_B.Compare[i] = (fabs
        (otter_2fixed_wp_mission_modif_B.rtb_VectorConcatenate_e_m[i]) >
        otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotation);
    }

    // End of RelationalOperator: '<S70>/Compare'

    // Logic: '<S62>/Logical Operator1' incorporates:
    //   RelationalOperator: '<S70>/Compare'

    rEQ0 = otter_2fixed_wp_mission_modif_B.Compare[0];
    for (i = 0; i < 8; i++) {
      rEQ0 = (rEQ0 || otter_2fixed_wp_mission_modif_B.Compare[i + 1]);
    }

    // If: '<S58>/If' incorporates:
    //   Abs: '<S63>/Abs1'
    //   Bias: '<S63>/Bias'
    //   Constant: '<S72>/Constant'
    //   Logic: '<S62>/Logical Operator1'
    //   Product: '<S71>/Product'
    //   Product: '<S71>/Product1'
    //   Product: '<S71>/Product2'
    //   Product: '<S71>/Product3'
    //   Product: '<S71>/Product4'
    //   Product: '<S71>/Product5'
    //   RelationalOperator: '<S72>/Compare'
    //   Sum: '<S71>/Sum'

    if (fabs((((((otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 *
                  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 *
                  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3 -
                  otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_1 *
                  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[5] *
                  otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[7]) -
                 otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[1] *
                 otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3] *
                 otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_3) +
                otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[2] *
                otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[3] *
                otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[7]) +
               otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[1] *
               otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[5] *
               otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[6]) -
              otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[2] *
              otter_2fixed_wp_mission_modif_B.rtb_Switch_idx_2 *
              otter_2fixed_wp_mission_modif_B.VectorConcatenate_e[6]) +
             otter_2fixed_wp_mission_modif_P.Bias_Bias) >
        otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotation) {
      // Outputs for IfAction SubSystem: '<S58>/If Not Proper' incorporates:
      //   ActionPort: '<S61>/Action Port'

      // If: '<S61>/If' incorporates:
      //   Constant: '<S61>/Constant'

      if (otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotati_l == 2)
      {
        // Outputs for IfAction SubSystem: '<S61>/Warning' incorporates:
        //   ActionPort: '<S69>/Action Port'

        // Assertion: '<S69>/Assertion' incorporates:
        //   Constant: '<S61>/Constant1'

        utAssert(otter_2fixed_wp_mission_modif_P.Constant1_Value != 0.0);

        // End of Outputs for SubSystem: '<S61>/Warning'
      } else if (otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotati_l
                 == 3) {
        // Outputs for IfAction SubSystem: '<S61>/Error' incorporates:
        //   ActionPort: '<S67>/Action Port'

        // Assertion: '<S67>/Assertion' incorporates:
        //   Constant: '<S61>/Constant1'

        utAssert(otter_2fixed_wp_mission_modif_P.Constant1_Value != 0.0);

        // End of Outputs for SubSystem: '<S61>/Error'
      }

      // End of If: '<S61>/If'
      // End of Outputs for SubSystem: '<S58>/If Not Proper'
    } else if (rEQ0) {
      // Outputs for IfAction SubSystem: '<S58>/Else If Not Orthogonal' incorporates:
      //   ActionPort: '<S59>/Action Port'

      // If: '<S59>/If' incorporates:
      //   Constant: '<S59>/Constant'

      if (otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotati_l == 2)
      {
        // Outputs for IfAction SubSystem: '<S59>/Warning' incorporates:
        //   ActionPort: '<S66>/Action Port'

        // Assertion: '<S66>/Assertion' incorporates:
        //   Constant: '<S59>/Constant1'

        utAssert(otter_2fixed_wp_mission_modif_P.Constant1_Value_k != 0.0);

        // End of Outputs for SubSystem: '<S59>/Warning'
      } else if (otter_2fixed_wp_mission_modif_P.DirectionCosineMatrixtoRotati_l
                 == 3) {
        // Outputs for IfAction SubSystem: '<S59>/Error' incorporates:
        //   ActionPort: '<S64>/Action Port'

        // Assertion: '<S64>/Assertion' incorporates:
        //   Constant: '<S59>/Constant1'

        utAssert(otter_2fixed_wp_mission_modif_P.Constant1_Value_k != 0.0);

        // End of Outputs for SubSystem: '<S59>/Error'
      }

      // End of If: '<S59>/If'
      // End of Outputs for SubSystem: '<S58>/Else If Not Orthogonal'
    }

    // End of If: '<S58>/If'
    // End of Outputs for SubSystem: '<S49>/If Warning//Error'
  }

  // End of If: '<S49>/If1'

  // MATLABSystem: '<S21>/SourceBlock'
  uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_p.orbMetadataObj,
                 &otter_2fixed_wp_mission_modi_DW.obj_p.eventStructObj,
                 &otter_2fixed_wp_mission_modif_B.r10, false, 1.0);

  // MATLABSystem: '<S22>/SourceBlock'
  uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_b.orbMetadataObj,
                 &otter_2fixed_wp_mission_modi_DW.obj_b.eventStructObj,
                 &otter_2fixed_wp_mission_modif_B.r3, false, 1.0);

  // MATLABSystem: '<S18>/SourceBlock'
  uORB_read_step(otter_2fixed_wp_mission_modi_DW.obj_n.orbMetadataObj,
                 &otter_2fixed_wp_mission_modi_DW.obj_n.eventStructObj,
                 &otter_2fixed_wp_mission_modif_B.r5, false, 1.0);

  // MATLABSystem: '<S3>/Read Parameter2'
  MW_Param_Step(otter_2fixed_wp_mission_modi_DW.obj_j.MW_PARAMHANDLE, MW_SINGLE,
                &ParamStep);
}

// Model initialize function
void otter_2fixed_wp_mission_modify_260917_initialize(void)
{
  // Registration code

  // initialize non-finites
  rt_InitInfAndNaN(sizeof(real_T));

  {
    static const char_T ParameterNameStr[11] = "U_SETPOINT";
    static const char_T ParameterNameStr_0[6] = "LOS_L";
    static const char_T ParameterNameStr_1[10] = "HEADING_P";
    static const char_T ParameterNameStr_2[10] = "HEADING_D";
    static const char_T ParameterNameStr_3[12] = "SURGE_VEL_I";
    static const char_T ParameterNameStr_4[16] = "SURGE_VEL_KANTI";
    static const char_T ParameterNameStr_5[12] = "SURGE_VEL_P";
    static const char_T ParameterNameStr_6[12] = "SURGE_VEL_D";

    // SystemInitialize for Enabled SubSystem: '<S24>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S93>/In1' incorporates:
    //   Outport: '<S93>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_du =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_o;

    // End of SystemInitialize for SubSystem: '<S24>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S26>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S95>/In1' incorporates:
    //   Outport: '<S95>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_n =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_k;

    // End of SystemInitialize for SubSystem: '<S26>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S23>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S92>/In1' incorporates:
    //   Outport: '<S92>/Out1'

    otter_2fixed_wp_mission_modif_B.In1 =
      otter_2fixed_wp_mission_modif_P.Out1_Y0;

    // End of SystemInitialize for SubSystem: '<S23>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S25>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S94>/In1' incorporates:
    //   Outport: '<S94>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_e =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_d;

    // End of SystemInitialize for SubSystem: '<S25>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S17>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S86>/In1' incorporates:
    //   Outport: '<S86>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_i =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_c;

    // End of SystemInitialize for SubSystem: '<S17>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S19>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S88>/In1' incorporates:
    //   Outport: '<S88>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_p =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_h;

    // End of SystemInitialize for SubSystem: '<S19>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<S20>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S89>/In1' incorporates:
    //   Outport: '<S89>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_h =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_e;

    // End of SystemInitialize for SubSystem: '<S20>/Enabled Subsystem'

    // SystemInitialize for Enabled SubSystem: '<Root>/Controller'
    // InitializeConditions for UnitDelay: '<S12>/Unit Delay2'
    otter_2fixed_wp_mission_modi_DW.UnitDelay2_DSTATE =
      otter_2fixed_wp_mission_modif_P.UnitDelay2_InitialCondition;

    // InitializeConditions for DiscreteIntegrator: '<S12>/Integrator3'
    otter_2fixed_wp_mission_modi_DW.Integrator3_DSTATE =
      otter_2fixed_wp_mission_modif_P.Integrator3_IC;

    // InitializeConditions for DiscreteTransferFcn: '<S12>/Transfer Fcn1'
    otter_2fixed_wp_mission_modi_DW.TransferFcn1_states =
      otter_2fixed_wp_mission_modif_P.TransferFcn1_InitialStates;

    // Start for MATLABSystem: '<S11>/Read Parameter'
    otter_2fixed_wp_mission_modi_DW.obj_ja.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_ja.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_ja.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_1[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_ja.isSetupComplete = true;

    // Start for MATLABSystem: '<S11>/Read Parameter1'
    otter_2fixed_wp_mission_modi_DW.obj_je.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_je.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_je.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_2[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_je.isSetupComplete = true;

    // Start for MATLABSystem: '<S12>/Read Parameter2'
    otter_2fixed_wp_mission_modi_DW.obj_l.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_l.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_l.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_3[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_l.isSetupComplete = true;

    // Start for MATLABSystem: '<S12>/Read Parameter3'
    otter_2fixed_wp_mission_modi_DW.obj_p4.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_p4.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_p4.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_4[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_p4.isSetupComplete = true;

    // Start for MATLABSystem: '<S12>/Read Parameter'
    otter_2fixed_wp_mission_modi_DW.obj_l4.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_l4.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_l4.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_5[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_l4.isSetupComplete = true;

    // Start for MATLABSystem: '<S12>/Read Parameter1'
    otter_2fixed_wp_mission_modi_DW.obj_od.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_od.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_od.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_6[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_od.isSetupComplete = true;

    // SystemInitialize for SignalConversion generated from: '<S1>/tau_auto' incorporates:
    //   Outport: '<S1>/tau_auto'

    otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[0] =
      otter_2fixed_wp_mission_modif_P.tau_auto_Y0;
    otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[1] =
      otter_2fixed_wp_mission_modif_P.tau_auto_Y0;
    otter_2fixed_wp_mission_modif_B.OutportBufferFortau_auto[2] =
      otter_2fixed_wp_mission_modif_P.tau_auto_Y0;

    // End of SystemInitialize for SubSystem: '<Root>/Controller'

    // SystemInitialize for Enabled SubSystem: '<S97>/Enabled Subsystem'
    // SystemInitialize for SignalConversion generated from: '<S98>/In1' incorporates:
    //   Outport: '<S98>/Out1'

    otter_2fixed_wp_mission_modif_B.In1_d =
      otter_2fixed_wp_mission_modif_P.Out1_Y0_m;

    // End of SystemInitialize for SubSystem: '<S97>/Enabled Subsystem'

    // Start for MATLABSystem: '<S24>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_f.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_f.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_f.orbMetadataObj = ORB_ID
      (vehicle_attitude);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_f.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_f.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_f.isSetupComplete = true;

    // Start for MATLABSystem: '<S26>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_o.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_o.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_o.orbMetadataObj = ORB_ID
      (vehicle_local_position);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_o.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_o.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_o.isSetupComplete = true;

    // Start for MATLABSystem: '<S23>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_a.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_a.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_a.orbMetadataObj = ORB_ID
      (position_setpoint_triplet);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_a.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_a.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_a.isSetupComplete = true;

    // Start for MATLABSystem: '<S25>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_k.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_k.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_k.orbMetadataObj = ORB_ID
      (vehicle_global_position);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_k.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_k.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_k.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter1'
    otter_2fixed_wp_mission_modi_DW.obj_kn.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_kn.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_kn.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_kn.isSetupComplete = true;

    // Start for MATLABSystem: '<S17>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_nu.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_nu.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_nu.orbMetadataObj = ORB_ID
      (mission_result);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_nu.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_nu.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_nu.isSetupComplete = true;

    // Start for MATLABSystem: '<S19>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_e.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_e.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_e.orbMetadataObj = ORB_ID(actuator_armed);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_e.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_e.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_e.isSetupComplete = true;

    // Start for MATLABSystem: '<S20>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_b2.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_b2.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_b2.orbMetadataObj = ORB_ID
      (vehicle_odometry);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_b2.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_b2.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_b2.isSetupComplete = true;

    // Start for MATLABSystem: '<S97>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj.orbMetadataObj = ORB_ID(input_rc);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj.isSetupComplete = true;

    // Start for MATLABSystem: '<Root>/PX4 PWM Output1'
    otter_2fixed_wp_mission_modi_DW.obj_fc.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_fc.isSetupComplete = false;
    otter_2fixed_wp_mission_modi_DW.obj_fc.isInitialized = 1;
    otter_2fixed_wp_m_PWM_setupImpl(&otter_2fixed_wp_mission_modi_DW.obj_fc,
      false, false);
    otter_2fixed_wp_mission_modi_DW.obj_fc.isSetupComplete = true;

    // Start for MATLABSystem: '<Root>/PX4 Timestamp1'
    otter_2fixed_wp_mission_modi_DW.obj_ki.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_ki.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_ki.isSetupComplete = true;

    // Start for MATLABSystem: '<S5>/SinkBlock' incorporates:
    //   BusAssignment: '<Root>/Bus Assignment1'

    otter_2fixed_wp_mission_modi_DW.obj_c.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_c.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_c.orbMetadataObj = ORB_ID
      (states_and_actuators);
    uORB_write_initialize(otter_2fixed_wp_mission_modi_DW.obj_c.orbMetadataObj,
                          &otter_2fixed_wp_mission_modi_DW.obj_c.orbAdvertiseObj,
                          &otter_2fixed_wp_mission_modif_B.BusAssignment1, 1);
    otter_2fixed_wp_mission_modi_DW.obj_c.isSetupComplete = true;

    // Start for MATLABSystem: '<S21>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_p.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_p.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_p.orbMetadataObj = ORB_ID
      (offboard_control_mode);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_p.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_p.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_p.isSetupComplete = true;

    // Start for MATLABSystem: '<S22>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_b.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_b.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_b.orbMetadataObj = ORB_ID
      (position_setpoint);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_b.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_b.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_b.isSetupComplete = true;

    // Start for MATLABSystem: '<S18>/SourceBlock'
    otter_2fixed_wp_mission_modi_DW.obj_n.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_n.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_n.orbMetadataObj = ORB_ID
      (trajectory_setpoint);
    uORB_read_initialize(otter_2fixed_wp_mission_modi_DW.obj_n.orbMetadataObj,
                         &otter_2fixed_wp_mission_modi_DW.obj_n.eventStructObj);
    otter_2fixed_wp_mission_modi_DW.obj_n.isSetupComplete = true;

    // Start for MATLABSystem: '<S3>/Read Parameter2'
    otter_2fixed_wp_mission_modi_DW.obj_j.matlabCodegenIsDeleted = false;
    otter_2fixed_wp_mission_modi_DW.obj_j.isInitialized = 1;
    otter_2fixed_wp_mission_modi_DW.obj_j.MW_PARAMHANDLE = MW_Init_Param
      (&ParameterNameStr_0[0], true, 200.0);
    otter_2fixed_wp_mission_modi_DW.obj_j.isSetupComplete = true;
  }
}

// Model terminate function
void otter_2fixed_wp_mission_modify_260917_terminate(void)
{
  // Terminate for MATLABSystem: '<S24>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_f.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_f.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_f.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_f.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_f.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S24>/SourceBlock'

  // Terminate for MATLABSystem: '<S26>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_o.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_o.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_o.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_o.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_o.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S26>/SourceBlock'

  // Terminate for MATLABSystem: '<S23>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_a.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_a.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_a.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_a.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_a.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S23>/SourceBlock'

  // Terminate for MATLABSystem: '<S25>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_k.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_k.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_k.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_k.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_k.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S25>/SourceBlock'

  // Terminate for MATLABSystem: '<S3>/Read Parameter1'
  if (!otter_2fixed_wp_mission_modi_DW.obj_kn.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_kn.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter1'

  // Terminate for MATLABSystem: '<S17>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_nu.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_nu.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_nu.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_nu.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_nu.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S17>/SourceBlock'

  // Terminate for MATLABSystem: '<S19>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_e.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_e.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_e.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_e.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_e.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S19>/SourceBlock'

  // Terminate for MATLABSystem: '<S20>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_b2.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_b2.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_b2.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_b2.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_b2.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S20>/SourceBlock'

  // Terminate for Enabled SubSystem: '<Root>/Controller'
  // Terminate for MATLABSystem: '<S11>/Read Parameter'
  if (!otter_2fixed_wp_mission_modi_DW.obj_ja.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_ja.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S11>/Read Parameter'

  // Terminate for MATLABSystem: '<S11>/Read Parameter1'
  if (!otter_2fixed_wp_mission_modi_DW.obj_je.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_je.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S11>/Read Parameter1'

  // Terminate for MATLABSystem: '<S12>/Read Parameter2'
  if (!otter_2fixed_wp_mission_modi_DW.obj_l.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_l.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S12>/Read Parameter2'

  // Terminate for MATLABSystem: '<S12>/Read Parameter3'
  if (!otter_2fixed_wp_mission_modi_DW.obj_p4.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_p4.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S12>/Read Parameter3'

  // Terminate for MATLABSystem: '<S12>/Read Parameter'
  if (!otter_2fixed_wp_mission_modi_DW.obj_l4.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_l4.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S12>/Read Parameter'

  // Terminate for MATLABSystem: '<S12>/Read Parameter1'
  if (!otter_2fixed_wp_mission_modi_DW.obj_od.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_od.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S12>/Read Parameter1'
  // End of Terminate for SubSystem: '<Root>/Controller'

  // Terminate for MATLABSystem: '<S97>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S97>/SourceBlock'

  // Terminate for MATLABSystem: '<Root>/PX4 PWM Output1'
  if (!otter_2fixed_wp_mission_modi_DW.obj_fc.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_fc.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_fc.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_fc.isSetupComplete) {
      pwm_disarm(&otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
      pwm_resetServo(otter_2fixed_wp_mission_modi_DW.obj_fc.servoCount,
                     otter_2fixed_wp_mission_modi_DW.obj_fc.isMain,
                     &otter_2fixed_wp_mission_modi_DW.obj_fc.actuatorAdvertiseObj);
      pwm_close(otter_2fixed_wp_mission_modi_DW.obj_fc.servoCount,
                &otter_2fixed_wp_mission_modi_DW.obj_fc.actuatorAdvertiseObj,
                &otter_2fixed_wp_mission_modi_DW.obj_fc.armAdvertiseObj);
    }
  }

  // End of Terminate for MATLABSystem: '<Root>/PX4 PWM Output1'

  // Terminate for MATLABSystem: '<Root>/PX4 Timestamp1'
  if (!otter_2fixed_wp_mission_modi_DW.obj_ki.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_ki.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<Root>/PX4 Timestamp1'

  // Terminate for MATLABSystem: '<S5>/SinkBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_c.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_c.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_c.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_c.isSetupComplete) {
      uORB_write_terminate
        (&otter_2fixed_wp_mission_modi_DW.obj_c.orbAdvertiseObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S5>/SinkBlock'

  // Terminate for MATLABSystem: '<S21>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_p.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_p.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_p.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_p.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_p.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S21>/SourceBlock'

  // Terminate for MATLABSystem: '<S22>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_b.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_b.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_b.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_b.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_b.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S22>/SourceBlock'

  // Terminate for MATLABSystem: '<S18>/SourceBlock'
  if (!otter_2fixed_wp_mission_modi_DW.obj_n.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_n.matlabCodegenIsDeleted = true;
    if ((otter_2fixed_wp_mission_modi_DW.obj_n.isInitialized == 1) &&
        otter_2fixed_wp_mission_modi_DW.obj_n.isSetupComplete) {
      uORB_read_terminate(&otter_2fixed_wp_mission_modi_DW.obj_n.eventStructObj);
    }
  }

  // End of Terminate for MATLABSystem: '<S18>/SourceBlock'

  // Terminate for MATLABSystem: '<S3>/Read Parameter2'
  if (!otter_2fixed_wp_mission_modi_DW.obj_j.matlabCodegenIsDeleted) {
    otter_2fixed_wp_mission_modi_DW.obj_j.matlabCodegenIsDeleted = true;
  }

  // End of Terminate for MATLABSystem: '<S3>/Read Parameter2'
}

const char_T* RT_MODEL_otter_2fixed_wp_miss_T::getErrorStatus() const
{
  return (errorStatus);
}

void RT_MODEL_otter_2fixed_wp_miss_T::setErrorStatus(const char_T* const
  volatile aErrorStatus)
{
  (errorStatus = aErrorStatus);
}

//
// File trailer for generated code.
//
// [EOF]
//
