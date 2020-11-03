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
  CLKOUT2_REQUESTED_PHASE -112.5
  CLKOUT3_USED true
  CLKOUT3_REQUESTED_OUT_FREQ 250.0
  CLKOUT3_REQUESTED_PHASE -67.5
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

# Create xlconstant
cell xilinx.com:ip:xlconstant const_1

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
}

# Create c_counter_binary
cell xilinx.com:ip:c_counter_binary cntr_0 {
  Output_Width 32
} {
  CLK pll_0/clk_out1
}

# Create port_slicer
cell labdpr:user:port_slicer slice_0 {
  DIN_FROM 26
  DIN_TO 26
} {
  din cntr_0/Q
}


# Create axis_rp_adc
cell labdpr:user:axis_rp_adc adc_0 {
  ADC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}
# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster bcast_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  NUM_MI 2
  M00_TDATA_REMAP {tdata[15:0]}
  M01_TDATA_REMAP {tdata[31:16]}
} {
  S_AXIS adc_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create trigger_generator
cell labdpr:user:axi_time_trig_gen axi_trig_gen_0 { } {
  s_axi_aclk pll_0/clk_out1
  data_clk pll_0/clk_out1
}

# Create all required interconnections config
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_trig_gen_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_trig_gen_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_axi_trig_gen_0_reg0]

# Create axis_averager
cell labdpr:user:axis_averager avg_0 {
  AXIS_TDATA_WIDTH 16
  AXI_DATA_WIDTH 32
  ADC_DATA_WIDTH 16
  MEM_ADDR_WIDTH 10
  AVERAGES_WIDTH 32
} {
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_1/dout
  s00_axi_aclk pll_0/clk_out1
  s01_axi_aclk pll_0/clk_out1
  S_AXIS bcast_0/M00_AXIS
  trig_i axi_trig_gen_0/trig_o
}

# Create all required interconnections config
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins avg_0/S00_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_avg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_avg_0_reg0]

# Create all required interconnections DP RAM
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins avg_0/S01_AXI]

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_avg_0_reg01]
set_property OFFSET 0x40010000 [get_bd_addr_segs ps_0/Data/SEG_avg_0_reg01]

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 3
} {
  In0 slice_0/dout
  In1 avg_0/done
  In2 axi_trig_gen_0/trig_o
  dout led_o
}

#signal generator

# Create dds_compiler
cell xilinx.com:ip:dds_compiler dds_0 {
  PartsPresent Phase_Generator_and_SIN_COS_LUT
  Parameter_Entry System_Parameters
  SPURIOUS_FREE_DYNAMIC_RANGE 84
  FREQUENCY_RESOLUTION 0.5
  AMPLITUDE_MODE Unit_Circle
  HAS_PHASE_OUT false
  DDS_CLOCK_RATE 125
  Noise_Shaping Auto
  Phase_Width 28 
  Output_Width 14
  DATA_Has_TLAST Not_Required
  S_PHASE_Has_TUSER Not_Required
  M_DATA_Has_TUSER Not_Required
  Latency 8
  OUTPUT_FREQUENCY1 3.90625
  PINC1 0
} {
  aclk pll_0/clk_out1
}

# Create axis_rp_dac
cell labdpr:user:axis_rp_dac dac_0 {} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  wrt_clk pll_0/clk_out3
  locked pll_0/locked
  S_AXIS dds_0/M_AXIS_DATA
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
}


group_bd_cells PS [get_bd_cells rst_0] [get_bd_cells pll_0] [get_bd_cells const_0] [get_bd_cells ps_0] [get_bd_cells ps_0_axi_periph]
group_bd_cells DAQ [get_bd_cells bcast_0] [get_bd_cells adc_0]
group_bd_cells SignalGenerator [get_bd_cells dac_0] [get_bd_cells dds_0] 
group_bd_cells Averager [get_bd_cells avg_0] [get_bd_cells axi_trig_gen_0]
