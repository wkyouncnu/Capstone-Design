function slBusOut = TwistWithCovariance(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.twist);
    for iter=1:currentlength
        slBusOut.twist(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Twist(msgIn.twist(iter),slBusOut(1).twist(iter),varargin{:});
    end
    slBusOut.twist = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Twist(msgIn.twist,slBusOut(1).twist,varargin{:});
                    currentlength = length(slBusOut.covariance);
                    slBusOut.covariance = double(msgIn.covariance(1:currentlength));
end
