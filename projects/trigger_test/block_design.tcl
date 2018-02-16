source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register:1.0 cfg_0 {
  CFG_DATA_WIDTH 128
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create xlslice for reset fifo, pps_gen and trigger modules
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 128 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen
cell xilinx.com:ip:xlslice:1.0 slice_2 {
  DIN_WIDTH 128 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0
cell xilinx.com:ip:xlslice:1.0 slice_3 {
  DIN_WIDTH 128 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get
cell xilinx.com:ip:xlslice:1.0 slice_4 {
  DIN_WIDTH 128 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_a
cell xilinx.com:ip:xlslice:1.0 trig_lvl_a {
  DIN_WIDTH 128 DIN_FROM 79 DIN_TO 64 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_b
cell xilinx.com:ip:xlslice:1.0 trig_lvl_b {
  DIN_WIDTH 128 DIN_FROM 95 DIN_TO 80 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_a
cell xilinx.com:ip:xlslice:1.0 subtrig_lvl_a {
  DIN_WIDTH 128 DIN_FROM 111 DIN_TO 96 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_b
cell xilinx.com:ip:xlslice:1.0 subtrig_lvl_b {
  DIN_WIDTH 128 DIN_FROM 127 DIN_TO 112 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create xlconstant for gpsen_i
cell xilinx.com:ip:xlconstant:1.1 pps_gen_en 

# Create xlconstant for pps_i
cell xilinx.com:ip:xlconstant:1.1 pps_in 

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn slice_1/Dout
}

# Create pps generator
cell labdpr:user:pps_gen:1.0 pps_gen_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  gpsen_i pps_gen_en/dout
  pps_i pps_in/dout
  false_pps_led_o led_o
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger:1.0 axis_lago_trigger_0 {
  DATA_ARRAY_LENGTH 32
} {
  S_AXIS fifo_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  trig_lvl_a_i trig_lvl_a/dout
  trig_lvl_b_i trig_lvl_b/dout
  subtrig_lvl_a_i subtrig_lvl_a/dout
  subtrig_lvl_b_i subtrig_lvl_b/dout
  pps_i pps_gen_0/pps_o
  clk_cnt_pps_i pps_gen_0/clk_cnt_pps_o
}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS axis_lago_trigger_0/M_AXIS
  pkt_length slice_4/Dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_2/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn slice_3/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_3/Dout
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]

# Create axi_sts_register
cell labdpr:user:axi_sts_register:1.0 sts_0 {
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

