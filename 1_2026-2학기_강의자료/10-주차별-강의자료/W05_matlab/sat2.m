function [y] = sat2(x,xmin , xmax )
    if x< xmin
        y = xmin ;
    elseif x> xmax
        y= xmax ;
    else
    y = x;
    end
end