function slBusOut = Pose(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.position);
    for iter=1:currentlength
        slBusOut.position(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Point(msgIn.position(iter),slBusOut(1).position(iter),varargin{:});
    end
    slBusOut.position = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Point(msgIn.position,slBusOut(1).position,varargin{:});
    currentlength = length(slBusOut.orientation);
    for iter=1:currentlength
        slBusOut.orientation(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Quaternion(msgIn.orientation(iter),slBusOut(1).orientation(iter),varargin{:});
    end
    slBusOut.orientation = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Quaternion(msgIn.orientation,slBusOut(1).orientation,varargin{:});
end
