close all; clc; clear;

here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '../..', 'tools')));   % 파라미터·게인·MSS

run("otter_gains.m")
% % run("otter_params_tilt.m")
run("otter_params_fixed.m")

% U_STOP_THRESH = 0.05;
% 
Ts = 0.02;
T_DETECT_HOLD     = 2.0;                       % 검출 전 정지 유지시간 [s]
DETECT_HOLD_STEPS = round(T_DETECT_HOLD/Ts);   % 3초 @ Ts=0.02 → 150 스텝
