function [chi_d, waypoint_index] = Simple_guidance(x,y,R_switch, wpt, waypoint_index)


% Outputs:  
%    chi_d:       desired course angle (rad)

persistent k;   % active waypoint index (initialized by: clear LOSchi)
persistent xk;  % active waypoint (xk, yk) corresponding to integer k
persistent yk;

%% Initialization of (xk, yk) and (xk_next, yk_next)
if isempty(k)   
    % check if R_switch is smaller than the minimum distance between the waypoints
    if R_switch > min( sqrt( diff(wpt.pos.x).^2 + diff(wpt.pos.y).^2 ) )
        error("The distances between the waypoints must be larger than R_switch");
    end
    
    % check input parameters
    if (R_switch < 0)
        error("R_switch must be larger than zero");
    end    
    k = 1;              % set first waypoint as the active waypoint
    xk = wpt.pos.x(k);
    yk = wpt.pos.y(k);     
end

%% Read next waypoint (xk_next, yk_next) from wpt.pos 
n = length(wpt.pos.x);
if k < n                        % if there are more waypoints, read next one 
    xk_next = wpt.pos.x(k+1);  
    yk_next = wpt.pos.y(k+1);    
else                            % else, use the last one in the array
    xk_next = wpt.pos.x(end);
    yk_next = wpt.pos.y(end); 
end

%% Print active waypoint 
% fprintf('Active waypoint:\n')
% fprintf('  (x%1.0f, y%1.0f) = (%.2f, %.2f) \n',k,k,xk,yk);

%% Waypoint update
x_error = -xk_next + x;
y_error = -yk_next + y;
R = sqrt(x_error^2 + y_error^2);
if ( (R < R_switch) && (k < n) )
    k = k + 1;
    waypoint_index= waypoint_index+1;
    xk = xk_next;       % update active waypoint
    yk = yk_next; 
end

chi_d = atan2(yk_next - y, xk_next - x);

end

