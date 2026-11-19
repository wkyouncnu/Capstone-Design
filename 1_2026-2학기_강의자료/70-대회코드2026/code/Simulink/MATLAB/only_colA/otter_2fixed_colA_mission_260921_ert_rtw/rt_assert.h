//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: rt_assert.h
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
#ifndef rt_assert_h_
#define rt_assert_h_

//=========*
//  Asserts *
// =========
#ifndef utAssert
#if defined(DOASSERTS)
#if !defined(PRINT_ASSERTS)
#include <assert.h>
#define utAssert(exp)                  assert(exp)
#else
#include <stdio.h>

static void _assert(char_T *statement, char_T *file, int line)
{
  printf("%s in %s on line %d\n", statement, file, line);
}

#define utAssert(_EX)                  ((_EX) ? (void)0 : _assert(#_EX, __FILE__, __LINE__))
#endif

#else
#define utAssert(exp)                                            // do nothing
#endif
#endif
#endif                                 // rt_assert_h_

//
// File trailer for generated code.
//
// [EOF]
//
