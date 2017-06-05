set display_name {Ramp Signal Generator}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter COUNT_NBITS {COUNTER BITS} {Width of the counter in bits.}
core_parameter COUNT_MOD {MODULE OF COUNTER} {Module of the counter.}
core_parameter DATA_BITS {DATA WIDTH} {Width of the data bus.}
