function rosmsgOut = Twist(slBusIn, rosmsgOut)
%#codegen
%   Copyright 2021 The MathWorks, Inc.
    rosmsgOut.linear = bus_conv_fcns.ros2.busToMsg.geometry_msgs.Vector3(slBusIn.linear,rosmsgOut.linear(1));
    rosmsgOut.angular = bus_conv_fcns.ros2.busToMsg.geometry_msgs.Vector3(slBusIn.angular,rosmsgOut.angular(1));
end
