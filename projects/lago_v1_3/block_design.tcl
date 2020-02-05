#source projects/base_system/block_design.tcl
# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 125.0
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 125.0
  CLKOUT2_USED true
  CLKOUT2_REQUESTED_OUT_FREQ 250.0
  CLKOUT2_REQUESTED_PHASE -90.0
  USE_RESET false
} {
  clk_in1_p adc_clk_p_i
  clk_in1_n adc_clk_n_i
}

# Create processing_system7
cell xilinx.com:ip:processing_system7 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/red_pitaya.xml
  PCW_USE_S_AXI_HP0 1
} {
  M_AXI_GP0_ACLK pll_0/clk_out1
  S_AXI_HP0_ACLK pll_0/clk_out1
} 

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master Disable
  Slave Disable
} [get_bd_cells ps_0]

# Create xlconstant
cell xilinx.com:ip:xlconstant const_0

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
}

#Enable interrupts
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells ps_0]

# Delete input/output port
delete_bd_objs [get_bd_ports exp_p_tri_io]
delete_bd_objs [get_bd_ports exp_n_tri_io]

# Create input port
create_bd_port -dir I -from 7 -to 7 exp_n_tri_io
create_bd_port -dir O -from 7 -to 7 exp_p_tri_io
create_bd_port -dir I -from 0 -to 0 ext_resetn

# Create proc_sys_reset
#cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 1024
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

#Create concatenator
cell xilinx.com:ip:xlconcat xlconcat_0 {
  NUM_PORTS 6
} {
  dout led_o
}

#Create concatenator
cell xilinx.com:ip:xlconcat xlconcat_1 {
  NUM_PORTS 4
} {
  dout dac_pwm_o
}

# Create axi_intc
cell xilinx.com:ip:axi_intc axi_intc_0 {
  C_IRQ_CONNECTION 1
  C_S_AXI_ACLK_FREQ_MHZ 125.0
  C_PROCESSOR_CLK_FREQ_MHZ 125.0
} {
  irq ps_0/IRQ_F2P
}

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} { }

# Create xlslice for reset fifo, pps_gen and trigger modules. off=0
cell labdpr:user:port_slicer reset_0 {
  DIN_WIDTH 1024 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen. off=0
cell labdpr:user:port_slicer reset_1 {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0. off=0
cell labdpr:user:port_slicer reset_2 {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get. off=1
cell labdpr:user:port_slicer nsamples {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_a. off=2
cell labdpr:user:port_slicer trig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_b. off=3
cell labdpr:user:port_slicer trig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 127 DIN_TO 96
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_a. off=4
cell labdpr:user:port_slicer subtrig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 159 DIN_TO 128
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_b. off=5
cell labdpr:user:port_slicer subtrig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 191 DIN_TO 160
} {
  din cfg_0/cfg_data
}

# Create xlslice for the temperature data. off=6
cell labdpr:user:port_slicer reg_temp {
  DIN_WIDTH 1024 DIN_FROM 223 DIN_TO 192
} {
  din cfg_0/cfg_data
}

# Create xlslice for the pressure data. off=7
cell labdpr:user:port_slicer reg_pressure {
  DIN_WIDTH 1024 DIN_FROM 255 DIN_TO 224
} {
  din cfg_0/cfg_data
}

# Create xlslice for the time data. off=8
cell labdpr:user:port_slicer reg_time {
  DIN_WIDTH 1024 DIN_FROM 287 DIN_TO 256
} {
  din cfg_0/cfg_data
}

# Create xlslice for the date data. off=9
cell labdpr:user:port_slicer reg_date {
  DIN_WIDTH 1024 DIN_FROM 319 DIN_TO 288
} {
  din cfg_0/cfg_data
}

# Create xlslice for the latitude data. off=10
cell labdpr:user:port_slicer reg_latitude {
  DIN_WIDTH 1024 DIN_FROM 351 DIN_TO 320
} {
  din cfg_0/cfg_data
}

# Create xlslice for the longitude data. off=11
cell labdpr:user:port_slicer reg_longitude {
  DIN_WIDTH 1024 DIN_FROM 383 DIN_TO 352
} {
  din cfg_0/cfg_data
}

# Create xlslice for the altitude data. off=12
cell labdpr:user:port_slicer reg_altitude {
  DIN_WIDTH 1024 DIN_FROM 415 DIN_TO 384
} {
  din cfg_0/cfg_data
}

# Create xlslice for the satellite data. off=13
cell labdpr:user:port_slicer reg_satellite {
  DIN_WIDTH 1024 DIN_FROM 447 DIN_TO 416
} {
  din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler a. off=14
cell labdpr:user:port_slicer reg_trig_scaler_a {
  DIN_WIDTH 1024 DIN_FROM 479 DIN_TO 448
} {
  din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler b. off=15
cell labdpr:user:port_slicer reg_trig_scaler_b {
  DIN_WIDTH 1024 DIN_FROM 511 DIN_TO 480
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the gpsen_i input
cell labdpr:user:port_slicer gpsen {
  DIN_WIDTH 1024 DIN_FROM 4 DIN_TO 4
} {
  din cfg_0/cfg_data
}

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_1 {} {
  slowest_sync_clk pll_0/clk_out1
  ext_reset_in ext_resetn
}

module fadc_0 {
  source projects/lago_v1_3/adc.tcl
} {
  writer_0/sts_data sts_0/sts_data 
  pps_0/resetn_i rst_1/peripheral_aresetn 
  pps_0/int_o axi_intc_0/intr
	writer_0/M_AXI ps_0/S_AXI_HP0
	tlast_gen_0/pkt_length nsamples/Dout
	pps_0/gpsen_i gpsen/Dout
  pps_0/pps_i exp_n_tri_io
  pps_0/pps_sig_o exp_p_tri_io
  pps_0/pps_gps_led_o xlconcat_0/In0
  pps_0/false_pps_led_o xlconcat_0/In1
}

#Now all related to the DAC PWM
# Create xlslice. off=0
cell labdpr:user:port_slicer reset_3 {
  DIN_WIDTH 1024 DIN_FROM 3 DIN_TO 3
} {
  din cfg_0/cfg_data
}

# Create xlslice. off=16
cell labdpr:user:port_slicer cfg_dac_pwm_0 {
  DIN_WIDTH 1024 DIN_FROM 543 DIN_TO 512
} {
  din cfg_0/cfg_data
}

# Create xlslice.. off=17
cell labdpr:user:port_slicer cfg_dac_pwm_1 {
  DIN_WIDTH 1024 DIN_FROM 575 DIN_TO 544
} {
  din cfg_0/cfg_data
}

# Create xlslice.. off=18
cell labdpr:user:port_slicer cfg_dac_pwm_2 {
  DIN_WIDTH 1024 DIN_FROM 607 DIN_TO 576
} {
  din cfg_0/cfg_data
}

# Create xlslice.. off=19
cell labdpr:user:port_slicer cfg_dac_pwm_3 {
  DIN_WIDTH 1024 DIN_FROM 639 DIN_TO 608
} {
  din cfg_0/cfg_data
}

module slow_dac_0 {
  source projects/lago_v1_3/slow_dac.tcl
} {
	gen_0/pwm_o	xlconcat_1/In0
	gen_0/led_o xlconcat_0/In2
	gen_0/data_i cfg_dac_pwm_0/Dout
	gen_1/pwm_o	xlconcat_1/In1
	gen_1/led_o xlconcat_0/In3
	gen_1/data_i cfg_dac_pwm_1/Dout
	gen_2/pwm_o	xlconcat_1/In2
	gen_2/led_o xlconcat_0/In4
	gen_2/data_i cfg_dac_pwm_2/Dout
	gen_3/pwm_o	xlconcat_1/In3
	gen_3/led_o xlconcat_0/In5
	gen_3/data_i cfg_dac_pwm_3/Dout
}

#XADC related
# Create xadc
cell xilinx.com:ip:xadc_wiz:3.3 xadc_wiz_0 {
	DCLK_FREQUENCY 125
	ADC_CONVERSION_RATE 500
  XADC_STARUP_SELECTION channel_sequencer
	CHANNEL_AVERAGING 64
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
} [get_bd_intf_pins axi_intc_0/s_axi]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins xadc_wiz_0/s_axi_lite]

set_property range 4K [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]
set_property offset 0x40003000 [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
