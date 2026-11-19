function slBusOut = Twist(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.linear);
    for iter=1:currentlength
        slBusOut.linear(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.linear(iter),slBusOut(1).linear(iter),varargin{:});
    end
    slBusOut.linear = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.linear,slBusOut(1).linear,varargin{:});
    currentlength = length(slBusOut.angular);
    for iter=1:currentlength
        slBusOut.angular(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.angular(iter),slBusOut(1).angular(iter),varargin{:});
    end
    slBusOut.angular = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.angular,slBusOut(1).angular,varargin{:});
end
