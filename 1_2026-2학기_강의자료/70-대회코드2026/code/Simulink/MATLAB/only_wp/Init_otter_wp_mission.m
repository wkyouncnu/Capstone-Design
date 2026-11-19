close all; clc; clear;

here = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(here, '../..', 'tools')));   % 파라미터·게인·MSS

run("otter_gains.m")
% run("otter_params_tilt.m")
run("otter_params_fixed.m")


