function slBusOut = Vector3(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    slBusOut.x = double(msgIn.x);
    slBusOut.y = double(msgIn.y);
    slBusOut.z = double(msgIn.z);
end
