function slBusOut = Float32(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    slBusOut.data = single(msgIn.data);
end
