function rosmsgOut = Vector3(slBusIn, rosmsgOut)
%#codegen
%   Copyright 2021 The MathWorks, Inc.
    rosmsgOut.x = double(slBusIn.x);
    rosmsgOut.y = double(slBusIn.y);
    rosmsgOut.z = double(slBusIn.z);
end
