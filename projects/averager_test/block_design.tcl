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

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 1024
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create port_slicer
cell labdpr:user:port_slicer rst_avg {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer user_trig {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer cfg_naverages {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer cfg_nsamples {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer cfg_trig_gen {
  DIN_WIDTH 1024 DIN_FROM 127 DIN_TO 96
} {
  din cfg_0/cfg_data
}

# Create concat
cell xilinx.com:ip:xlconcat concat_1 {
  IN0_WIDTH 32
  IN1_WIDTH 32
} {}

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
cell labdpr:user:time_trig_gen trig_gen_0 { } {
  aclk pll_0/clk_out1
  aresetn rst_avg/dout
  cfg_data cfg_trig_gen/dout
}

# Create blk_mem_gen
cell xilinx.com:ip:blk_mem_gen bram_0 {
  MEMORY_TYPE True_Dual_Port_RAM
  USE_BRAM_BLOCK Stand_Alone
  WRITE_WIDTH_A 32
  WRITE_DEPTH_A 16384
  ENABLE_A Always_Enabled
  ENABLE_B Always_Enabled
  REGISTER_PORTA_OUTPUT_OF_MEMORY_PRIMITIVES true
  REGISTER_PORTB_OUTPUT_OF_MEMORY_PRIMITIVES true
}

# Create axis_histogram
cell labdpr:user:axis_averager avg_0 {
  AXIS_TDATA_WIDTH 16
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AVERAGES_WIDTH 32
} {
  aclk pll_0/clk_out1
  aresetn rst_avg/dout
  S_AXIS bcast_0/M00_AXIS
  BRAM_PORTA bram_0/BRAM_PORTA
  trig_i trig_gen_0/trig_o
  user_trig user_trig/dout
  nsamples cfg_nsamples/dout
  naverages cfg_naverages/dout
  averages_out concat_1/In0
  finished concat_1/In1
}

# Create bram_selector
cell labdpr:user:bram_selector bram_sel_0 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
} {
  aclk pll_0/clk_out1
  BRAM_PORTB avg_0/BRAM_PORTB
  BRAM_PORTC bram_0/BRAM_PORTB
  sel avg_0/finished 
}

# Create axi_bram_reader
cell labdpr:user:axi_bram_reader reader_0 {
  AXI_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 14
} {
  BRAM_PORTA bram_sel_0/BRAM_PORTA
}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 5
} {
  In0 slice_0/dout
  In1 avg_0/finished
  In2 trig_gen_0/trig_o
  In3 rst_avg/dout
  In4 user_trig/dout
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

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins reader_0/S_AXI]

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]
set_property OFFSET 0x40010000 [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 64
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data concat_1/dout
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

group_bd_cells PS [get_bd_cells rst_0] [get_bd_cells pll_0] [get_bd_cells const_0] [get_bd_cells ps_0] [get_bd_cells ps_0_axi_periph]
group_bd_cells DAQ [get_bd_cells bcast_0] [get_bd_cells adc_0]
group_bd_cells SignalGenerator [get_bd_cells dac_0] [get_bd_cells dds_0] 
group_bd_cells Averager [get_bd_cells cfg_naverages] [get_bd_cells rst_avg] [get_bd_cells avg_0] [get_bd_cells cfg_nsamples] [get_bd_cells bram_0] [get_bd_cells bram_sel_0] [get_bd_cells reader_0] [get_bd_cells cfg_trig_gen] [get_bd_cells user_trig] [get_bd_cells trig_gen_0]
