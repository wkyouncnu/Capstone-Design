//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
//
// File: otter_2fixed_colA_mission_260921_data.cpp
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
#include "otter_2fixed_colA_mission_260921.h"

// Block parameters (default storage)
P_otter_2fixed_colA_mission_2_T otter_2fixed_colA_mission_260_P = {
  // Variable: Fx_max
  //  Referenced by: '<S10>/sat1'

  101.67501111929313,

  // Variable: Fx_min
  //  Referenced by: '<S10>/sat1'

  -78.106477638576621,

  // Variable: N_max
  //  Referenced by: '<S9>/stern constraint'

  26.96722331368046,

  // Variable: N_min
  //  Referenced by: '<S9>/stern constraint'

  -26.96722331368046,

  // Variable: RC_max
  //  Referenced by: '<S7>/Gain'

  2000.0,

  // Variable: RC_min
  //  Referenced by: '<S7>/Gain'

  1000.0,

  // Variable: Thrust_max
  //  Referenced by: '<S6>/Constant3'

  50.837505559646566,

  // Variable: Thrust_min
  //  Referenced by: '<S6>/Constant2'

  -39.05323881928831,

  // Variable: d
  //  Referenced by: '<S6>/Constant1'

  0.3,

  // Variable: k_neg
  //  Referenced by: '<S6>/1//k_pos1'

  0.00029610049888095796,

  // Variable: k_pos
  //  Referenced by: '<S6>/1//k_pos'

  0.000371304596569747,

  // Variable: n_uniq
  //  Referenced by:
  //    '<S6>/1-D Lookup Table'
  //    '<S6>/1-D Lookup Table1'

  { -363.16915795253129, -362.82393182648684, -361.185765790565,
    -358.25884863497043, -357.08912897028381, -355.5005302851186,
    -353.31712339087369, -351.46881971301173, -348.00050142344855,
    -346.26320068601342, -343.71641624150328, -340.08997112170943,
    -337.53690349189213, -335.84567944670965, -332.6904732249543,
    -330.17719910208251, -325.83028206706535, -323.196580225806,
    -320.58905832332641, -319.372214768836, -314.50693494597658,
    -312.87435396366106, -309.16727463242512, -305.59318939019113,
    -303.25375006081794, -299.99277688639171, -297.94026968604641,
    -295.43851473623772, -292.41839699858673, -288.87153889268387,
    -286.5519963167834, -284.00835346492687, -280.780890612139,
    -278.62156926157155, -275.30823620958557, -272.12894444415264,
    -269.7507588053852, -266.81232247672756, -263.61313395782196,
    -259.93223456536589, -255.53400485034018, -253.28462451036989,
    -248.13136536093145, -245.61494964540597, -241.5235488128809,
    -238.535894199317, -235.4257174722631, -232.72499498772711,
    -230.24941997669833, -225.87632300290136, -224.11598391933987,
    -220.51571873832597, -217.96055671340622, -213.61049808573557,
    -209.57250432832151, -206.10942202651438, -202.68508603410149,
    -199.25656125148382, -195.77986538151112, -192.68225502507158,
    -189.26943820572188, -185.67650340756634, -181.96104649592081,
    -178.54299368881513, -174.57411496978003, -170.72985275933729,
    -166.41749324350974, -162.72193308533696, -159.02113693940817,
    -155.17163874120945, -151.68132930307118, -147.61820280442839,
    -142.63668405338618, -138.71911801435971, -134.54813016794364,
    -130.49547564481284, -125.59877989541755, -120.73559446766053,
    -116.52271871919662, -111.43333862038115, -106.44553668403177,
    -101.54465214443168, -95.926437282261944, -90.959579296936482,
    -84.816718461617242, -79.393282343970043, -73.018990849836356,
    -67.152590168033029, -60.508121705690606, -53.747414315165379,
    -47.071529926287063, -40.681530468885427, -33.2139647313025, 0.0,
    32.279864515635126, 39.248964218848485, 46.160468056746026,
    53.198682798338361, 59.989758917848292, 66.018475220087112,
    72.073371461105836, 78.46860690626346, 84.153842411709789, 89.9961575498356,
    94.889711706577316, 100.69118614020647, 105.49258691244285,
    110.6531764447397, 115.64411997374266, 120.16591899980959,
    125.09926666349675, 129.5456674658775, 133.92504762498172,
    138.13373458324079, 142.33613835619278, 147.51348304930875,
    151.16296651522887, 154.94649126770221, 158.75829035405778,
    162.17320156850994, 165.77346674952381, 170.573820324209, 174.71653383674277,
    177.92828872626271, 182.20713792045203, 184.9539370972407,
    188.73850904726518, 192.17122262008763, 195.35156158307171,
    199.05654651920526, 202.086089034817, 205.33659023373124, 208.81956928901113,
    212.68477545047782, 216.91335916220964, 220.56912581343698,
    222.91694272321973, 226.23551176296175, 229.29437581000704,
    232.39198616644654, 234.96599774728782, 237.33161701544091,
    241.41568746510765, 245.21073139064416, 250.46871029520227,
    252.98303161562526, 256.14242662758539, 259.19500748932347,
    261.58052351094932, 265.76617212308213, 270.54453454919224,
    273.17823639045162, 276.38266089711328, 278.89488782243393,
    281.49926813225983, 283.87431217837371, 286.45879573472689, 289.644370685467,
    294.19968003317217, 295.56732003503492, 298.82829320946109,
    302.43065278557742, 304.01925147074269, 307.20901521168747,
    311.34963432911883, 314.33938333778514, 318.54283430828832,
    320.97547421971797, 325.42815820740589, 327.19792206892816,
    330.22118139923276, 333.04337879970757, 335.55770012013062,
    339.53495641957528, 341.39687366560281, 345.50502965894708,
    346.39619477501537, 350.92951297414544, 353.82291980810169,
    356.63359803551333, 358.96465978447696, 360.01709332342949,
    361.80570674087329, 365.87406922727212, 368.18942301296772,
    369.37066185071751, 370.02149512878623 },

  // Variable: pwm_uniq
  //  Referenced by:
  //    '<S6>/1-D Lookup Table'
  //    '<S6>/1-D Lookup Table1'

  { 1100.0, 1104.0, 1108.0, 1112.0, 1116.0, 1120.0, 1124.0, 1128.0, 1132.0,
    1136.0, 1140.0, 1144.0, 1148.0, 1152.0, 1156.0, 1160.0, 1164.0, 1168.0,
    1172.0, 1176.0, 1180.0, 1184.0, 1188.0, 1192.0, 1196.0, 1200.0, 1204.0,
    1208.0, 1212.0, 1216.0, 1220.0, 1224.0, 1228.0, 1232.0, 1236.0, 1240.0,
    1244.0, 1248.0, 1252.0, 1256.0, 1260.0, 1264.0, 1268.0, 1272.0, 1276.0,
    1280.0, 1284.0, 1288.0, 1292.0, 1296.0, 1300.0, 1304.0, 1308.0, 1312.0,
    1316.0, 1320.0, 1324.0, 1328.0, 1332.0, 1336.0, 1340.0, 1344.0, 1348.0,
    1352.0, 1356.0, 1360.0, 1364.0, 1368.0, 1372.0, 1376.0, 1380.0, 1384.0,
    1388.0, 1392.0, 1396.0, 1400.0, 1404.0, 1408.0, 1412.0, 1416.0, 1420.0,
    1424.0, 1428.0, 1432.0, 1436.0, 1440.0, 1444.0, 1448.0, 1452.0, 1456.0,
    1460.0, 1464.0, 1468.0, 1500.0, 1532.0, 1536.0, 1540.0, 1544.0, 1548.0,
    1552.0, 1556.0, 1560.0, 1564.0, 1568.0, 1572.0, 1576.0, 1580.0, 1584.0,
    1588.0, 1592.0, 1596.0, 1600.0, 1604.0, 1608.0, 1612.0, 1616.0, 1620.0,
    1624.0, 1628.0, 1632.0, 1636.0, 1640.0, 1644.0, 1648.0, 1652.0, 1656.0,
    1660.0, 1664.0, 1668.0, 1672.0, 1676.0, 1680.0, 1684.0, 1688.0, 1692.0,
    1696.0, 1700.0, 1704.0, 1708.0, 1712.0, 1716.0, 1720.0, 1724.0, 1728.0,
    1732.0, 1736.0, 1740.0, 1744.0, 1748.0, 1752.0, 1756.0, 1760.0, 1764.0,
    1768.0, 1772.0, 1776.0, 1780.0, 1784.0, 1788.0, 1792.0, 1796.0, 1800.0,
    1804.0, 1808.0, 1812.0, 1816.0, 1820.0, 1824.0, 1828.0, 1832.0, 1836.0,
    1840.0, 1844.0, 1848.0, 1852.0, 1856.0, 1860.0, 1864.0, 1868.0, 1872.0,
    1876.0, 1880.0, 1884.0, 1888.0, 1892.0, 1896.0, 1900.0 },

  // Variable: ref_lla
  //  Referenced by:
  //    '<S2>/Constant'
  //    '<S2>/Constant1'

  { 36.395991, 127.401794, 25.111 },

  // Mask Parameter: DirectionCosineMatrixtoRotation
  //  Referenced by:
  //    '<S68>/Constant'
  //    '<S70>/Constant'

  4.4408920985006262E-16,

  // Mask Parameter: DirectionCosineMatrixtoRotati_l
  //  Referenced by:
  //    '<S47>/Constant'
  //    '<S57>/Constant'
  //    '<S59>/Constant'

  1U,

  // Computed Parameter: Out1_Y0
  //  Referenced by: '<S90>/Out1'

  {
    (0ULL),                            // timestamp

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    },                                 // previous

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    },                                 // current

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    }                                  // next
  },

  // Computed Parameter: Constant_Value
  //  Referenced by: '<S21>/Constant'

  {
    (0ULL),                            // timestamp

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    },                                 // previous

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    },                                 // current

    {
      (0ULL),                          // timestamp
      0.0,                             // lat
      0.0,                             // lon
      0.0F,                            // vx
      0.0F,                            // vy
      0.0F,                            // vz
      0.0F,                            // alt
      0.0F,                            // yaw
      0.0F,                            // yawspeed
      0.0F,                            // loiter_radius
      0.0F,                            // acceptance_radius
      0.0F,                            // cruising_speed
      0.0F,                            // cruising_throttle
      false,                           // valid
      0U,                              // type
      false,                           // yaw_valid
      false,                           // yawspeed_valid
      false,                           // loiter_direction_counter_clockwise
      false,                           // gliding_enabled
      false,                           // disable_weather_vane
      0U                               // _padding0
    }                                  // next
  },

  // Computed Parameter: Out1_Y0_k
  //  Referenced by: '<S93>/Out1'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample
    (0ULL),                            // ref_timestamp
    0.0,                               // ref_lat
    0.0,                               // ref_lon
    0.0F,                              // x
    0.0F,                              // y
    0.0F,                              // z

    {
      0.0F, 0.0F }
    ,                                  // delta_xy
    0.0F,                              // delta_z
    0.0F,                              // vx
    0.0F,                              // vy
    0.0F,                              // vz
    0.0F,                              // z_deriv

    {
      0.0F, 0.0F }
    ,                                  // delta_vxy
    0.0F,                              // delta_vz
    0.0F,                              // ax
    0.0F,                              // ay
    0.0F,                              // az
    0.0F,                              // heading
    0.0F,                              // delta_heading
    0.0F,                              // ref_alt
    0.0F,                              // dist_bottom
    0.0F,                              // eph
    0.0F,                              // epv
    0.0F,                              // evh
    0.0F,                              // evv
    0.0F,                              // vxy_max
    0.0F,                              // vz_max
    0.0F,                              // hagl_min
    0.0F,                              // hagl_max
    false,                             // xy_valid
    false,                             // z_valid
    false,                             // v_xy_valid
    false,                             // v_z_valid
    0U,                                // xy_reset_counter
    0U,                                // z_reset_counter
    0U,                                // vxy_reset_counter
    0U,                                // vz_reset_counter
    0U,                                // heading_reset_counter
    false,                             // heading_good_for_control
    false,                             // xy_global
    false,                             // z_global
    false,                             // dist_bottom_valid
    0U,                                // dist_bottom_sensor_bitfield
    false,                             // dead_reckoning
    0U                                 // _padding0
  },

  // Computed Parameter: Constant_Value_h
  //  Referenced by: '<S24>/Constant'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample
    (0ULL),                            // ref_timestamp
    0.0,                               // ref_lat
    0.0,                               // ref_lon
    0.0F,                              // x
    0.0F,                              // y
    0.0F,                              // z

    {
      0.0F, 0.0F }
    ,                                  // delta_xy
    0.0F,                              // delta_z
    0.0F,                              // vx
    0.0F,                              // vy
    0.0F,                              // vz
    0.0F,                              // z_deriv

    {
      0.0F, 0.0F }
    ,                                  // delta_vxy
    0.0F,                              // delta_vz
    0.0F,                              // ax
    0.0F,                              // ay
    0.0F,                              // az
    0.0F,                              // heading
    0.0F,                              // delta_heading
    0.0F,                              // ref_alt
    0.0F,                              // dist_bottom
    0.0F,                              // eph
    0.0F,                              // epv
    0.0F,                              // evh
    0.0F,                              // evv
    0.0F,                              // vxy_max
    0.0F,                              // vz_max
    0.0F,                              // hagl_min
    0.0F,                              // hagl_max
    false,                             // xy_valid
    false,                             // z_valid
    false,                             // v_xy_valid
    false,                             // v_z_valid
    0U,                                // xy_reset_counter
    0U,                                // z_reset_counter
    0U,                                // vxy_reset_counter
    0U,                                // vz_reset_counter
    0U,                                // heading_reset_counter
    false,                             // heading_good_for_control
    false,                             // xy_global
    false,                             // z_global
    false,                             // dist_bottom_valid
    0U,                                // dist_bottom_sensor_bitfield
    false,                             // dead_reckoning
    0U                                 // _padding0
  },

  // Computed Parameter: Out1_Y0_e
  //  Referenced by: '<S87>/Out1'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // q

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // angular_velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position_variance

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // orientation_variance

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity_variance
    0U,                                // pose_frame
    0U,                                // velocity_frame
    0U,                                // reset_counter
    0,                                 // quality

    {
      0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_g
  //  Referenced by: '<S18>/Constant'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // q

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // angular_velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position_variance

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // orientation_variance

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity_variance
    0U,                                // pose_frame
    0U,                                // velocity_frame
    0U,                                // reset_counter
    0,                                 // quality

    {
      0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Out1_Y0_m
  //  Referenced by: '<S105>/Out1'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_last_signal
    0,                                 // rssi
    0.0F,                              // rssi_dbm
    0U,                                // rc_lost_frame_count
    0U,                                // rc_total_frame_count
    0U,                                // rc_ppm_frame_length

    {
      0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U }
    ,                                  // values
    0U,                                // channel_count
    false,                             // rc_failsafe
    false,                             // rc_lost
    0U,                                // input_source
    0,                                 // link_quality
    0U                                 // _padding0
  },

  // Computed Parameter: Constant_Value_m
  //  Referenced by: '<S104>/Constant'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_last_signal
    0,                                 // rssi
    0.0F,                              // rssi_dbm
    0U,                                // rc_lost_frame_count
    0U,                                // rc_total_frame_count
    0U,                                // rc_ppm_frame_length

    {
      0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U }
    ,                                  // values
    0U,                                // channel_count
    false,                             // rc_failsafe
    false,                             // rc_lost
    0U,                                // input_source
    0,                                 // link_quality
    0U                                 // _padding0
  },

  // Computed Parameter: Out1_Y0_a
  //  Referenced by: '<S89>/Out1'

  {
    (0ULL),                            // timestamp
    0.0,                               // lat
    0.0,                               // lon
    0.0F,                              // vx
    0.0F,                              // vy
    0.0F,                              // vz
    0.0F,                              // alt
    0.0F,                              // yaw
    0.0F,                              // yawspeed
    0.0F,                              // loiter_radius
    0.0F,                              // acceptance_radius
    0.0F,                              // cruising_speed
    0.0F,                              // cruising_throttle
    false,                             // valid
    0U,                                // type
    false,                             // yaw_valid
    false,                             // yawspeed_valid
    false,                             // loiter_direction_counter_clockwise
    false,                             // gliding_enabled
    false,                             // disable_weather_vane
    0U                                 // _padding0
  },

  // Computed Parameter: Constant_Value_b
  //  Referenced by: '<S20>/Constant'

  {
    (0ULL),                            // timestamp
    0.0,                               // lat
    0.0,                               // lon
    0.0F,                              // vx
    0.0F,                              // vy
    0.0F,                              // vz
    0.0F,                              // alt
    0.0F,                              // yaw
    0.0F,                              // yawspeed
    0.0F,                              // loiter_radius
    0.0F,                              // acceptance_radius
    0.0F,                              // cruising_speed
    0.0F,                              // cruising_throttle
    false,                             // valid
    0U,                                // type
    false,                             // yaw_valid
    false,                             // yawspeed_valid
    false,                             // loiter_direction_counter_clockwise
    false,                             // gliding_enabled
    false,                             // disable_weather_vane
    0U                                 // _padding0
  },

  // Computed Parameter: Out1_Y0_j
  //  Referenced by: '<S85>/Out1'

  {
    (0ULL),                            // timestamp

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // acceleration

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // jerk
    0.0F,                              // yaw
    0.0F                               // yawspeed
  },

  // Computed Parameter: Constant_Value_l
  //  Referenced by: '<S16>/Constant'

  {
    (0ULL),                            // timestamp

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // position

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // velocity

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // acceleration

    {
      0.0F, 0.0F, 0.0F }
    ,                                  // jerk
    0.0F,                              // yaw
    0.0F                               // yawspeed
  },

  // Computed Parameter: Out1_Y0_d
  //  Referenced by: '<S92>/Out1'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample
    0.0,                               // lat
    0.0,                               // lon
    0.0F,                              // alt
    0.0F,                              // alt_ellipsoid
    0.0F,                              // delta_alt
    0.0F,                              // eph
    0.0F,                              // epv
    0.0F,                              // terrain_alt
    0U,                                // lat_lon_reset_counter
    0U,                                // alt_reset_counter
    false,                             // terrain_alt_valid
    false,                             // dead_reckoning

    {
      0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_f
  //  Referenced by: '<S23>/Constant'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample
    0.0,                               // lat
    0.0,                               // lon
    0.0F,                              // alt
    0.0F,                              // alt_ellipsoid
    0.0F,                              // delta_alt
    0.0F,                              // eph
    0.0F,                              // epv
    0.0F,                              // terrain_alt
    0U,                                // lat_lon_reset_counter
    0U,                                // alt_reset_counter
    false,                             // terrain_alt_valid
    false,                             // dead_reckoning

    {
      0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Out1_Y0_o
  //  Referenced by: '<S91>/Out1'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // q

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // delta_q_reset
    0U,                                // quat_reset_counter

    {
      0U, 0U, 0U, 0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_hr
  //  Referenced by: '<S22>/Constant'

  {
    (0ULL),                            // timestamp
    (0ULL),                            // timestamp_sample

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // q

    {
      0.0F, 0.0F, 0.0F, 0.0F }
    ,                                  // delta_q_reset
    0U,                                // quat_reset_counter

    {
      0U, 0U, 0U, 0U, 0U, 0U, 0U }
    // _padding0
  },

  // Computed Parameter: Out1_Y0_c
  //  Referenced by: '<S84>/Out1'

  {
    (0ULL),                            // timestamp
    0U,                                // instance_count
    0,                                 // seq_reached
    0U,                                // seq_current
    0U,                                // seq_total
    0U,                                // item_changed_index
    0U,                                // item_do_jump_remaining
    false,                             // valid
    false,                             // warning
    false,                             // finished
    false,                             // failure
    false,                             // item_do_jump_changed
    0U,                                // execution_mode

    {
      0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_i
  //  Referenced by: '<S15>/Constant'

  {
    (0ULL),                            // timestamp
    0U,                                // instance_count
    0,                                 // seq_reached
    0U,                                // seq_current
    0U,                                // seq_total
    0U,                                // item_changed_index
    0U,                                // item_do_jump_remaining
    false,                             // valid
    false,                             // warning
    false,                             // finished
    false,                             // failure
    false,                             // item_do_jump_changed
    0U,                                // execution_mode

    {
      0U, 0U }
    // _padding0
  },

  // Computed Parameter: Out1_Y0_h
  //  Referenced by: '<S86>/Out1'

  {
    (0ULL),                            // timestamp
    false,                             // armed
    false,                             // prearmed
    false,                             // ready_to_arm
    false,                             // lockdown
    false,                             // manual_lockdown
    false,                             // force_failsafe
    false,                             // in_esc_calibration_mode
    0U                                 // _padding0
  },

  // Computed Parameter: Constant_Value_a
  //  Referenced by: '<S17>/Constant'

  {
    (0ULL),                            // timestamp
    false,                             // armed
    false,                             // prearmed
    false,                             // ready_to_arm
    false,                             // lockdown
    false,                             // manual_lockdown
    false,                             // force_failsafe
    false,                             // in_esc_calibration_mode
    0U                                 // _padding0
  },

  // Computed Parameter: Out1_Y0_b
  //  Referenced by: '<S88>/Out1'

  {
    (0ULL),                            // timestamp
    false,                             // position
    false,                             // velocity
    false,                             // acceleration
    false,                             // attitude
    false,                             // body_rate
    false,                             // actuator

    {
      0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_h1
  //  Referenced by: '<S19>/Constant'

  {
    (0ULL),                            // timestamp
    false,                             // position
    false,                             // velocity
    false,                             // acceleration
    false,                             // attitude
    false,                             // body_rate
    false,                             // actuator

    {
      0U, 0U }
    // _padding0
  },

  // Computed Parameter: Constant_Value_j
  //  Referenced by: '<S96>/Constant'

  {
    (0ULL),                            // timestamp
    0.0                                // operation_mode
  },

  // Computed Parameter: tau_auto_Y0
  //  Referenced by: '<S1>/tau_auto'

  0.0,

  // Expression: 0
  //  Referenced by: '<S1>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S10>/Unit Delay2'

  0.0,

  // Computed Parameter: Integrator3_gainval
  //  Referenced by: '<S10>/Integrator3'

  0.002,

  // Expression: 0
  //  Referenced by: '<S10>/Integrator3'

  0.0,

  // Expression: [1.960784313725490 -1.960784313725490 ]
  //  Referenced by: '<S10>/Transfer Fcn1'

  { 1.96078431372549, -1.96078431372549 },

  // Expression: [1.000000000000000 0.960784313725490 ]
  //  Referenced by: '<S10>/Transfer Fcn1'

  { 1.0, 0.96078431372549 },

  // Expression: 0
  //  Referenced by: '<S10>/Transfer Fcn1'

  0.0,

  // Expression: [1 0 0 0]
  //  Referenced by: '<S25>/Constant'

  { 1.0, 0.0, 0.0, 0.0 },

  // Expression: 1
  //  Referenced by: '<S53>/Constant'

  1.0,

  // Expression: 1
  //  Referenced by: '<S54>/Constant'

  1.0,

  // Expression: 1
  //  Referenced by: '<S49>/Constant'

  1.0,

  // Expression: 1
  //  Referenced by: '<S50>/Constant'

  1.0,

  // Expression: 0
  //  Referenced by: '<S59>/Constant1'

  0.0,

  // Expression: 0
  //  Referenced by: '<S57>/Constant1'

  0.0,

  // Expression: -eye(3)
  //  Referenced by: '<S60>/Bias1'

  { -1.0, -0.0, -0.0, -0.0, -1.0, -0.0, -0.0, -0.0, -1.0 },

  // Expression: -1
  //  Referenced by: '<S61>/Bias'

  -1.0,

  // Expression: 0
  //  Referenced by: '<S101>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S100>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S102>/Constant'

  0.0,

  // Expression: 0.5
  //  Referenced by: '<S95>/Switch'

  0.5,

  // Expression: 1
  //  Referenced by: '<S4>/Constant1'

  1.0,

  // Expression: 0
  //  Referenced by: '<S4>/Constant'

  0.0,

  // Expression: 1
  //  Referenced by: '<S6>/Gain4'

  1.0,

  // Expression: 0
  //  Referenced by: '<S108>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S109>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S112>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S113>/Constant'

  0.0,

  // Expression: 1
  //  Referenced by: '<S8>/Constant1'

  1.0,

  // Expression: 0
  //  Referenced by: '<S8>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S110>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S111>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S114>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S115>/Constant'

  0.0,

  // Expression: 0
  //  Referenced by: '<S25>/Switch'

  0.0,

  // Expression: 2
  //  Referenced by: '<S32>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S35>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S30>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S36>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S31>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S34>/Gain'

  2.0,

  // Expression: 1
  //  Referenced by: '<S2>/Constant2'

  1.0,

  // Expression: 2
  //  Referenced by: '<S74>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S77>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S72>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S78>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S73>/Gain'

  2.0,

  // Expression: 2
  //  Referenced by: '<S76>/Gain'

  2.0,

  // Expression: [1 1 -1]
  //  Referenced by: '<S46>/Gain1'

  { 1.0, 1.0, -1.0 },

  // Expression: [1 1]
  //  Referenced by: '<S46>/Gain2'

  { 1.0, 1.0 },

  // Expression: [-1 1]
  //  Referenced by: '<S46>/Gain3'

  { -1.0, 1.0 },

  // Expression: [-RC_min -RC_min]
  //  Referenced by: '<S7>/Constant2'

  { -1000.0, -1000.0 },

  // Expression: 2
  //  Referenced by: '<S7>/Gain1'

  2.0,

  // Expression: [-1 -1]
  //  Referenced by: '<S7>/Constant'

  { -1.0, -1.0 },

  // Expression: -0.1
  //  Referenced by: '<S113>/Dead Zone'

  -0.1,

  // Expression: 0.1
  //  Referenced by: '<S113>/Dead Zone'

  0.1,

  // Expression: 0
  //  Referenced by: '<S7>/Constant4'

  0.0,

  // Expression: -0.05
  //  Referenced by: '<S112>/Dead Zone'

  -0.05,

  // Expression: 0.05
  //  Referenced by: '<S112>/Dead Zone'

  0.05,

  // Expression: [Fx_min Fy_min N_min]
  //  Referenced by: '<S6>/Constant17'

  { -78.106477638576621, 0.0, -26.96722331368046 },

  // Expression: [Fx_max Fy_max N_max]
  //  Referenced by: '<S6>/Constant16'

  { 101.67501111929313, 0.0, 26.96722331368046 },

  // Expression: 0
  //  Referenced by: '<S6>/Switch2'

  0.0,

  // Expression: 0
  //  Referenced by: '<S6>/Switch'

  0.0,

  // Expression: -33
  //  Referenced by: '<S108>/Dead Zone'

  -33.0,

  // Expression: 33
  //  Referenced by: '<S108>/Dead Zone'

  33.0,

  // Expression: 1900
  //  Referenced by: '<S6>/Saturation'

  1900.0,

  // Expression: 1100
  //  Referenced by: '<S6>/Saturation'

  1100.0,

  // Expression: 0
  //  Referenced by: '<Root>/Constant1'

  0.0,

  // Expression: -33
  //  Referenced by: '<S109>/Dead Zone'

  -33.0,

  // Expression: 33
  //  Referenced by: '<S109>/Dead Zone'

  33.0,

  // Expression: 1800
  //  Referenced by: '<S6>/Saturation1'

  1800.0,

  // Expression: 1200
  //  Referenced by: '<S6>/Saturation1'

  1200.0,

  // Computed Parameter: Switch_Threshold_a
  //  Referenced by: '<S4>/Switch'

  1500U,

  // Computed Parameter: Switch_Threshold_i
  //  Referenced by: '<S8>/Switch'

  1500U,

  // Computed Parameter: Assertion_Enabled
  //  Referenced by: '<S67>/Assertion'

  true,

  // Computed Parameter: Assertion_Enabled_h
  //  Referenced by: '<S65>/Assertion'

  true,

  // Computed Parameter: Assertion_Enabled_b
  //  Referenced by: '<S64>/Assertion'

  true,

  // Computed Parameter: Assertion_Enabled_k
  //  Referenced by: '<S62>/Assertion'

  true
};

//
// File trailer for generated code.
//
// [EOF]
//
