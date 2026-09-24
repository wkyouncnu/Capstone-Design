% function [y] = sat(s,e)
%     sign = s/(abs(sx)+ e);
%     
%     if abs(s/e)<= 1
%         y = s/e;
%     else
%         y= sign;
%     end
% end

function [y] = sat(x, xmax )
    if abs(x) >= xmax
        y = sign (x)* xmax ;
    else
        y = x;
    end
end