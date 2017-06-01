set display_name {PWM Signal Generator}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter TDATA_WIDTH {DATA WIDTH} {Width of the data bus.}
