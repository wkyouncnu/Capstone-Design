close all; clc; clear;

here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '../..', 'tools')));   % 파라미터·게인·MSS

run("otter_gains.m")
run("otter_params_fixed.m")

% U_STOP_THRESH = 0.05;

Ts = 0.02;
T_DETECT_HOLD     = 2.0;                       % 검출 전 정지 유지시간 [s]
DETECT_HOLD_STEPS = round(T_DETECT_HOLD/Ts);   % 3초 @ Ts=0.02 → 150 스텝

U_REVERSE = -1.0;   % 후진 속도 [m/s] (음수)
D_REVERSE = 3.0;    % 후진 거리 [m]

T_DP_HOLD     = 50.0;                     % DP 유지시간 [s]
DP_HOLD_STEPS = round(T_DP_HOLD/Ts);      % Ts = 0.02 → 2500 스텝
