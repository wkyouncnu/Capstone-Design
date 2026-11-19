clear; clc; close all;


Voltage = '16 V';
t200_data = readtable("T200-Public-Performance-Data-10-20V-September-2019.xlsx", 'Sheet', Voltage);

pwm = t200_data.PWM__s_;
rpm = t200_data.RPM;
newton = t200_data.Force_KgF_ .*9.80665;

% figure()
% subplot(1,3,1); plot(pwm); ylabel('pwm')
% subplot(1,3,2); plot(rpm); ylabel('rpm')
% subplot(1,3,3); plot(newton); ylabel('Force (N)')

max_pwm = 1900;
min_pwm = 1100;
max_idx = find(pwm == max_pwm);
min_idx = find(pwm == min_pwm);
pwm = pwm(min_idx:max_idx);
rpm = rpm(min_idx:max_idx);
newton = newton(min_idx:max_idx);

rpm_pn = rpm;
len_rpm = length(rpm);
rpm_pn(1:fix(len_rpm/2)) = -rpm(1:fix(len_rpm/2));
rpm_pn = sort(rpm_pn);

rps = rpm_pn./60;
n = rps.*(2*pi);  % rad/s

% figure()
% subplot(1,3,1); plot(rpm); hold on; plot(rpm_pn); ylabel('rpm')
% subplot(1,3,2); plot(pwm, rpm_pn); ylabel('rpm_{pn}')
% subplot(1,3,3); plot(pwm, newton); ylabel('Force (N)')
 
% figure()
% subplot(2,2,1); plot(pwm, rpm_pn); xlabel('pwm'); ylabel('rpm_{pn}')
% subplot(2,2,2); plot(pwm, newton); xlabel('pwm'); ylabel('Force (N)')
% subplot(2,2,3); plot(rpm_pn, pwm); xlabel('rpm_{pn}'); ylabel('pwm')
% subplot(2,2,4); plot(newton, pwm); xlabel('Force (N)'); ylabel('pwm')

% pwm_uniq = pwm;
% pwm_uniq(95:100) = [];   
% pwm_uniq(102-6:108-6) = []; 
% rpm_pn_uniq = rpm_pn;
% rpm_pn_uniq(95:100) = [];   
% rpm_pn_uniq(102-6:108-6) = []; 
% newton_uniq = newton;
% newton_uniq(95:100) = [];   
% newton_uniq(102-6:108-6) = [];
[rpm_pn_uniq, indices_to_keep] = unique_data_extraction(rpm_pn);
pwm_uniq = pwm(indices_to_keep);
newton_uniq = newton(indices_to_keep);
rps_uniq = rpm_pn./60;
n_uniq = rps_uniq.*(2*pi);  % rad/s
% n_uniq(95:107) = [];
% n_uniq(95) = 1;
n_uniq = n_uniq(indices_to_keep);

% figure()
% subplot(2,2,1); plot(pwm_uniq, rpm_pn_uniq); xlabel('pwm'); ylabel('rpm_{pn}'); title('data unique values')
% subplot(2,2,2); plot(pwm_uniq, newton_uniq); xlabel('pwm'); ylabel('Force (N)')
% subplot(2,2,3); plot(rpm_pn_uniq, pwm_uniq); xlabel('rpm_{pn}'); ylabel('pwm')
% subplot(2,2,4); plot(newton_uniq, pwm_uniq); xlabel('Force (N)'); ylabel('pwm')

file_name = strcat('T200_thruster_pwm_', Voltage, '_', num2str(max_pwm), '.mat');
save(file_name, 'pwm', 'rpm_pn', 'n', 'newton', ...
                              'pwm_uniq', 'rpm_pn_uniq', 'newton_uniq', 'n_uniq')
