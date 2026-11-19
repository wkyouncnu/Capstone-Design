function slBusOut = NavSatStatus(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    slBusOut.status = int8(msgIn.status);
    slBusOut.service = uint16(msgIn.service);
end
