source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create xadc
cell xilinx.com:ip:xadc_wiz:3.3 xadc_wiz_0 {
  XADC_STARUP_SELECTION channel_sequencer 
  OT_ALARM false
  USER_TEMP_ALARM false 
  VCCINT_ALARM false 
  VCCAUX_ALARM false
  ENABLE_VCCPINT_ALARM false 
  ENABLE_VCCPAUX_ALARM false
  ENABLE_VCCDDRO_ALARM false 
  CHANNEL_ENABLE_CALIBRATION true
  CHANNEL_ENABLE_TEMPERATURE true 
  CHANNEL_ENABLE_VCCINT true
  CHANNEL_ENABLE_VP_VN true
  CHANNEL_ENABLE_VAUXP0_VAUXN0 true 
  CHANNEL_ENABLE_VAUXP1_VAUXN1 true 
  CHANNEL_ENABLE_VAUXP8_VAUXN8 true
  CHANNEL_ENABLE_VAUXP9_VAUXN9 true 
  AVERAGE_ENABLE_VP_VN true
  AVERAGE_ENABLE_VAUXP0_VAUXN0 true 
  AVERAGE_ENABLE_VAUXP1_VAUXN1 true 
  AVERAGE_ENABLE_VAUXP8_VAUXN8 true
  AVERAGE_ENABLE_VAUXP9_VAUXN9 true 
  AVERAGE_ENABLE_TEMPERATURE true 
  AVERAGE_ENABLE_VCCINT true 
  EXTERNAL_MUX_CHANNEL VP_VN 
  SINGLE_CHANNEL_SELECTION TEMPERATURE 
} {}

connect_bd_intf_net [get_bd_intf_ports Vp_Vn] [get_bd_intf_pins xadc_wiz_0/Vp_Vn]
connect_bd_intf_net [get_bd_intf_ports Vaux0] [get_bd_intf_pins xadc_wiz_0/Vaux0]
connect_bd_intf_net [get_bd_intf_ports Vaux1] [get_bd_intf_pins xadc_wiz_0/Vaux1]
connect_bd_intf_net [get_bd_intf_ports Vaux8] [get_bd_intf_pins xadc_wiz_0/Vaux8]
connect_bd_intf_net [get_bd_intf_ports Vaux9] [get_bd_intf_pins xadc_wiz_0/Vaux9]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto 
} [get_bd_intf_pins xadc_wiz_0/s_axi_lite]

set_property range 4K [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]
set_property offset 0x40001000 [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]

