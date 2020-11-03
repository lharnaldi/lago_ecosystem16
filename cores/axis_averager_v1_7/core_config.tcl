set display_name {AXI4-Stream Averager v1.7}

set core [ipx::current_core]

set_property DISPLAY_NAME $display_name $core
set_property DESCRIPTION $display_name $core

core_parameter AXIS_TDATA_WIDTH {AXIS TDATA WIDTH} {Width of the S_AXIS data bus.}
core_parameter AXI_DATA_WIDTH {AXI DATA WIDTH} {Width of the AXI data bus.}
core_parameter ADC_DATA_WIDTH {ADC DATA WIDTH} {Width of the ADC data.}
core_parameter MEM_ADDR_WIDTH {BRAM ADDR WIDTH} {Width of the BRAM address.}

set bus [ipx::get_bus_interfaces -of_objects $core s00_axi]
set_property NAME S00_AXI $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces s00_axi_aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE S00_AXI $parameter

set bus [ipx::get_bus_interfaces -of_objects $core s01_axi]
set_property NAME S01_AXI $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces s01_axi_aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE S01_AXI $parameter

set bus [ipx::get_bus_interfaces -of_objects $core s_axis]
set_property NAME S_AXIS $bus
set_property INTERFACE_MODE slave $bus

set bus [ipx::get_bus_interfaces s_axis_aclk]
set parameter [ipx::get_bus_parameters -of_objects $bus ASSOCIATED_BUSIF]
set_property VALUE S_AXIS $parameter
