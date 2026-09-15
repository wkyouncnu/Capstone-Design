function slBusOut = Pose2D(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    slBusOut.x = double(msgIn.x);
    slBusOut.y = double(msgIn.y);
    slBusOut.theta = double(msgIn.theta);
end
