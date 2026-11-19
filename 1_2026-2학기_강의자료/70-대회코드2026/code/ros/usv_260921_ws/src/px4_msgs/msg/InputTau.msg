uint64 timestamp			# time since system start (microseconds)

uint64 timestamp_last_signal		# last valid reception time

uint8 channel_count			# number of channels actually being seen

int8 docking_type                       # docking method(1.sway,2.front,3.NED frame,4.SMC)
int8 wp_guid                            # waypoint following guidance algorithm(0.actangent, 1.LOS)
int8 docking_guid                       # docking guidance algorithm(0.actangent, 1.LOS)

float64[2] dock_x			# docking start and final x position
float64[2] dock_y			# docking start and final y position

int8 operation_type                     # operation method(0.Waypoint, 1.Berthing)
float64 ye                              # waypoint following and docking crosstrck error
float64[3] pos                          # USV pos data (x(m), y(m), psi(rad)) in NED frame

uint8 input_source			# Input source (RC or Auto)
float64[3] tau			        # tau(Fx, Fy, N)

