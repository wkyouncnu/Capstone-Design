function slBusOut = NavSatFix(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.header);
    for iter=1:currentlength
        slBusOut.header(iter) = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header(iter),slBusOut(1).header(iter),varargin{:});
    end
    slBusOut.header = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header,slBusOut(1).header,varargin{:});
    currentlength = length(slBusOut.status);
    for iter=1:currentlength
        slBusOut.status(iter) = bus_conv_fcns.ros2.msgToBus.sensor_msgs.NavSatStatus(msgIn.status(iter),slBusOut(1).status(iter),varargin{:});
    end
    slBusOut.status = bus_conv_fcns.ros2.msgToBus.sensor_msgs.NavSatStatus(msgIn.status,slBusOut(1).status,varargin{:});
    slBusOut.latitude = double(msgIn.latitude);
    slBusOut.longitude = double(msgIn.longitude);
    slBusOut.altitude = double(msgIn.altitude);
                    currentlength = length(slBusOut.position_covariance);
                    slBusOut.position_covariance = double(msgIn.position_covariance(1:currentlength));
    slBusOut.position_covariance_type = uint8(msgIn.position_covariance_type);
end
