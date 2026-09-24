function [v_ref, psi_ref, x_ref, y_ref] = VF_Loiter_guidance( ...
    pn, pe, wp_north, wp_east, v_setpoint, curr_index, Total_wp, mission_done, ...
    vf_rd, vf_pc)

% VF_Loiter_guidance
% Ackermann UGV용 Vector Field Loiter Guidance
%
% pn, pe       : current UGV position [north, east]
% wp_north/east : loiter center waypoint list
% v_setpoint   : desired forward speed
% curr_index   : current loiter waypoint index
% Total_wp     : total number of waypoints
% mission_done : mission complete flag
% vf_rd        : desired loiter radius
% vf_pc        : convergence/tangential shaping gain
%
% Outputs
% v_ref   : reference speed
% psi_ref : reference heading angle [rad]
% x_ref   : loiter center north
% y_ref   : loiter center east

    % default outputs
    v_ref = v_setpoint;

    % protect empty case
    if Total_wp <= 0
        x_ref = pn;
        y_ref = pe;
        psi_ref = 0;
        v_ref = 0;
        return;
    end

    % bound index
    idx = max(1, curr_index);
    idx = min(idx, Total_wp);

    % loiter center waypoint
    x_ref = wp_north(idx);
    y_ref = wp_east(idx);

    % relative position from loiter center to UGV
    dn = pn - x_ref;
    de = pe - y_ref;

    % distance and bearing angle from center
    r = sqrt(dn^2 + de^2);
    theta = atan2(de, dn);   % north-east frame heading angle convention

    % avoid singularity near center
    if r < 1e-6
        psi_ref = theta;
        return;
    end

    % Vector Field Loiter Guidance
    %
    % Original UAV form:
    % cmd_chi = theta + atan2(vf_pc*r, -(r - vf_rd));
    %
    % Here:
    % r > vf_rd  : vehicle is outside the circle -> command turns inward
    % r < vf_rd  : vehicle is inside the circle  -> command turns outward
    % r = vf_rd  : command becomes tangential direction

    psi_ref = theta + atan2(vf_pc * r, -(r - vf_rd));

    % wrap heading reference
    psi_ref = wrapToPi(psi_ref);

    % mission complete
    if mission_done == 1
        v_ref = 0;
    end

end