set display_name {AXI4-Stream LAGO Trigger v1r3}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter AXIS_TDATA_WIDTH {AXIS TDATA WIDTH} {Width of the S_AXIS data bus.}
core_parameter ADC_DATA_WIDTH {ADC_DATA_WIDTH} {Number of ADC data bits.}
core_parameter DATA_ARRAY_LENGTH {DATA_ARRAY_LENGTH} {Length of the data array.}
core_parameter METADATA_ARRAY_LENGTH {METADATA_ARRAY_LENGTH} {Length of the metadata array.}
core_parameter SUBTRIG_ARRAY_LENGTH {SUBTRIG_ARRAY_LENGTH} {Length of the sub-trigger array.}

set bus [ipx::get_bus_interfaces -of_objects $core m_axis]
set_property NAME M_AXIS $bus
set_property INTERFACE_MODE master $bus

set bus [ipx::get_bus_interfaces -of_objects $core s_axis]
set_property NAME S_AXIS $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE M_AXIS:S_AXIS $parameter

