# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 125.0
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 125.0
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

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 128
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create xlslice for reset fifo, pps_gen and trigger modules
cell xilinx.com:ip:xlslice slice_0 {
  DIN_WIDTH 128 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in slice_0/dout
}

# Create axis_red_pitaya_adc
cell labdpr:user:axis_rp_adc adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_data_fifo dfifo_0 {
} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn rst_0/peripheral_aresetn
}

# Create xlslice for set the trigger_lvl_a
cell xilinx.com:ip:xlslice trig_lvl_a {
  DIN_WIDTH 128 DIN_FROM 79 DIN_TO 64 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_b
cell xilinx.com:ip:xlslice trig_lvl_b {
  DIN_WIDTH 128 DIN_FROM 95 DIN_TO 80 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_a
cell xilinx.com:ip:xlslice subtrig_lvl_a {
  DIN_WIDTH 128 DIN_FROM 111 DIN_TO 96 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_b
cell xilinx.com:ip:xlslice subtrig_lvl_b {
  DIN_WIDTH 128 DIN_FROM 127 DIN_TO 112 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlconstant for gpsen_i
cell xilinx.com:ip:xlconstant pps_gen_en

# Create xlconstant for pps_i
cell xilinx.com:ip:xlconstant pps_in

# Create pps generator
cell labdpr:user:pps_gen pps_gen_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
  gpsen_i pps_gen_en/dout
  pps_i pps_in/dout
  false_pps_led_o led_o
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger axis_lago_trigger_0 {} {
  S_AXIS dfifo_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
  trig_lvl_a_i trig_lvl_a/dout
  trig_lvl_b_i trig_lvl_b/dout
  subtrig_lvl_a_i subtrig_lvl_a/dout
  subtrig_lvl_b_i subtrig_lvl_b/dout
  pps_i pps_gen_0/pps_o
  clk_cnt_pps_i pps_gen_0/clk_cnt_pps_o
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create blk_mem_gen
cell xilinx.com:ip:blk_mem_gen bram_0 {
  MEMORY_TYPE True_Dual_Port_RAM
  USE_BRAM_BLOCK Stand_Alone
  USE_BYTE_WRITE_ENABLE true
  BYTE_SIZE 8
  WRITE_WIDTH_A 32
  WRITE_DEPTH_A 1024
  WRITE_WIDTH_B 32
  WRITE_DEPTH_B 1024
  ENABLE_A Always_Enabled
  ENABLE_B Always_Enabled
  REGISTER_PORTB_OUTPUT_OF_MEMORY_PRIMITIVES false
}

# Create axis_bram_writer
cell labdpr:user:axis_bram_writer writer_0 {
  AXIS_TDATA_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 10
} {
  S_AXIS axis_lago_trigger_0/M_AXIS
  BRAM_PORTA bram_0/BRAM_PORTA
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create axi_bram_reader
cell labdpr:user:axi_bram_reader reader_0 {
  AXI_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 10
} {
  BRAM_PORTA bram_0/BRAM_PORTB
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins reader_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data writer_0/sts_data
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

