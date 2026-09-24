%-------------------------------------------------------------------------
% Simulation of ship model
% Drawing a shape of ship, ssz, and heading dir.
% Date: 2022/05/18 @ KRISO (jeonghong@kriso.re.kr) 
%-------------------------------------------------------------------------
function h = shipModel(pos_x,pos_y, course_angle,speed)
    
    stParam.veh_info.L = 1.5;
    stParam.veh_info.B = 1.5/2;
    stParam.veh_info.buffer = 2.5*stParam.veh_info.L;
    stParam.veh_info.headDir = 5;
    stParam.veh_info.ssz = 10; % buffer = safe separation zone (ssz)

    stParam.dt = 0.1;
    stParam.tf = 10;
    
    veh = [ pos_x, pos_y, course_angle, speed] ; % pos_x, pos_y, heading (rad), speed (m/s)

%     for t = 0:stParam.dt:stParam.tf 
%         vehShape(stParam, veh);
%     end

    h = vehShape(stParam, veh);
    
    

end

% draw a shape of vehicle
function h = vehShape(stParam, veh)

    
    
    vehx = stParam.veh_info.L*[0.5,1,0.5,-1,-1,0.5]';
    vehy = stParam.veh_info.B*[1,0,-1,-1,1,1]';
    veh_x = veh(1);
    veh_y = veh(2);
    veh_psi = veh(3);
    veh_spd = veh(4);

    posx = veh_x + vehx*cos(veh_psi) - vehy*sin(veh_psi);
    posy = veh_y + vehx*sin(veh_psi) + vehy*cos(veh_psi);

    grid on;
    h(1) = plot(veh_x, veh_y, 'ro', 'LineWidth',1);   % center
    h(2) = plot(posx, posy, 'r-', 'LineWidth',1);     % shape
    h(3) = plot( [veh_x veh_x + (stParam.veh_info.headDir * veh_spd) * cos(veh_psi)], [veh_y veh_y + (stParam.veh_info.headDir * veh_spd) * sin(veh_psi)], 'r--', 'LineWidth',1 ); % heading line depending on speed
    h(4:5) = plot2Dssz(stParam, veh, 'c');
%     axis equal;
end

% draw a safe separation zone
function h = plot2Dssz(stParam, veh, color)
    
 
    ssz_r = stParam.veh_info.ssz; 
    theta = (0:360)/180*pi ;
    x = ssz_r*cos(theta) + veh(1) ;
    y = ssz_r*sin(theta) + veh(2) ;
    h(1) = plot(x, y,color,'LineWidth',1) ; 
    h(2) = plot(veh(1), veh(2), 'rs', 'linewidth', 1);       % center
end