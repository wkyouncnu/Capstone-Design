function slBusOut = PoseWithCovariance(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.pose);
    for iter=1:currentlength
        slBusOut.pose(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Pose(msgIn.pose(iter),slBusOut(1).pose(iter),varargin{:});
    end
    slBusOut.pose = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Pose(msgIn.pose,slBusOut(1).pose,varargin{:});
                    currentlength = length(slBusOut.covariance);
                    slBusOut.covariance = double(msgIn.covariance(1:currentlength));
end
