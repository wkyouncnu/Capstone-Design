uint64 timestamp			# time since system start (microseconds)

uint64 timestamp_last_signal		# last valid reception time

float64[9] sates                        # States(u;v;w;p;q;r;x;y;psi)
float64[7] command                      # Command(u_cmd; psi_cmd; wp_mode; ye; d_pos_x; d_pos_y; d_psi;)

float64 estimated_d                     # estimated disturbance about N using ESO
int8 eso_type                           # ESO enabled(0.disabled, 1.enabled)

float32 nomoto_t                        # Nomoto model T value
float32 nomoto_k                        # Nomoto model k value



