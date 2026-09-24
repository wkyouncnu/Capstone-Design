function xdot = WAMV(states, control)


Tp = control(1);
Ts = control(2);

u = states(1);
v = states(2);
r = states(3);
x = states(4);
y = states(5);
psi = states(6);

xdot = [-1.1391*u+0.0028*(Tp+Ts)+0.6836;
       0.0161*v-0.0052*r+0.002*(Tp-Ts)*2.44/2+0.0068;
       8.2861*v-0.9860*r+0.0307*(Tp-Ts)*2.44/2+1.3276;  
       u*cos(psi)-v*sin(psi);
       u*sin(psi)+v*cos(psi);
       r]; 

end