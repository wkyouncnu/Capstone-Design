function circle_draw(x,y,r)  
% input:
% x: latitude or North position
% y: longditude or East position
% r: radius of obstacle
% type: coordniate type (LL or NED)

    ang=0:0.01:2*pi; 
    xp=r*cos(ang);
    yp=r*sin(ang);
   
    lat = x;
    lon = y;
    [x,y,~] = deg2utm(lat,lon);
    utmzone=[];
    for i = 1:length(xp)
        utmzone = [utmzone; '52 S'];
    end
    figure(1)
    [Lat, Lon] = utm2deg(x+xp, y+yp, utmzone);
    geoplot(Lat, Lon, 'w-', 'LineWidth',1); 

end