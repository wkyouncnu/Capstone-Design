function slBusOut = Imu(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.header);
    for iter=1:currentlength
        slBusOut.header(iter) = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header(iter),slBusOut(1).header(iter),varargin{:});
    end
    slBusOut.header = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header,slBusOut(1).header,varargin{:});
    currentlength = length(slBusOut.orientation);
    for iter=1:currentlength
        slBusOut.orientation(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Quaternion(msgIn.orientation(iter),slBusOut(1).orientation(iter),varargin{:});
    end
    slBusOut.orientation = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Quaternion(msgIn.orientation,slBusOut(1).orientation,varargin{:});
                    currentlength = length(slBusOut.orientation_covariance);
                    slBusOut.orientation_covariance = double(msgIn.orientation_covariance(1:currentlength));
    currentlength = length(slBusOut.angular_velocity);
    for iter=1:currentlength
        slBusOut.angular_velocity(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.angular_velocity(iter),slBusOut(1).angular_velocity(iter),varargin{:});
    end
    slBusOut.angular_velocity = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.angular_velocity,slBusOut(1).angular_velocity,varargin{:});
                    currentlength = length(slBusOut.angular_velocity_covariance);
                    slBusOut.angular_velocity_covariance = double(msgIn.angular_velocity_covariance(1:currentlength));
    currentlength = length(slBusOut.linear_acceleration);
    for iter=1:currentlength
        slBusOut.linear_acceleration(iter) = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.linear_acceleration(iter),slBusOut(1).linear_acceleration(iter),varargin{:});
    end
    slBusOut.linear_acceleration = bus_conv_fcns.ros2.msgToBus.geometry_msgs.Vector3(msgIn.linear_acceleration,slBusOut(1).linear_acceleration,varargin{:});
                    currentlength = length(slBusOut.linear_acceleration_covariance);
                    slBusOut.linear_acceleration_covariance = double(msgIn.linear_acceleration_covariance(1:currentlength));
end
