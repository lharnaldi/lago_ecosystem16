# Create processing_system7
cell xilinx.com:ip:processing_system7:5.5 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/red_pitaya.xml
  PCW_USE_S_AXI_HP0 1
} {
  M_AXI_GP0_ACLK ps_0/FCLK_CLK0
  S_AXI_HP0_ACLK ps_0/FCLK_CLK0
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master Disable
  Slave Disable
} [get_bd_cells ps_0]

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create util_ds_buf
cell xilinx.com:ip:util_ds_buf:2.1 buf_0 {
  C_SIZE 2
  C_BUF_TYPE IBUFDS
} {
  IBUF_DS_P daisy_p_i
  IBUF_DS_N daisy_n_i
}

# Create util_ds_buf
cell xilinx.com:ip:util_ds_buf:2.1 buf_1 {
  C_SIZE 2
  C_BUF_TYPE OBUFDS
} {
  OBUF_DS_P daisy_p_o
  OBUF_DS_N daisy_n_o
}

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  adc_clk_p adc_clk_p_i
  adc_clk_n adc_clk_n_i
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create c_counter_binary
cell xilinx.com:ip:c_counter_binary:12.0 cntr_0 {
  Output_Width 32
} {
  CLK adc_0/adc_clk
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_0 {
  DIN_WIDTH 32 DIN_FROM 26 DIN_TO 26 DOUT_WIDTH 1
} {
  Din cntr_0/Q
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

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 128 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_2 {
  DIN_WIDTH 128 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_3 {
  DIN_WIDTH 128 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice
#cell xilinx.com:ip:xlslice:1.0 slice_4 {
#  DIN_WIDTH 128 DIN_FROM 3 DIN_TO 3 DOUT_WIDTH 1
#} {
#  Din cfg_0/cfg_data
#}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_5 {
  DIN_WIDTH 128 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice
# for the trigger level
cell xilinx.com:ip:xlslice:1.0 slice_6 {
  DIN_WIDTH 128 DIN_FROM 95 DIN_TO 64 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice
# for the sub-trigger level
cell xilinx.com:ip:xlslice:1.0 slice_7 {
  DIN_WIDTH 128 DIN_FROM 127 DIN_TO 96 DOUT_WIDTH 32
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

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_2 

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_3 

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_1 {} {
 slowest_sync_clk ps_0/FCLK_CLK0
 ext_reset_in ps_0/FCLK_RESET0_N
 aux_reset_in slice_1/Dout
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  s_axis_aclk adc_0/adc_clk
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn rst_1/peripheral_aresetn
}

# Create pps generator
cell labdpr:user:pps_gen:1.0 pps_gen_0 {} {
  aclk adc_0/adc_clk
  aresetn rst_1/peripheral_aresetn
  gpsen_i const_3/dout
  pps_i const_2/dout
  false_pps_led_o led_o
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger:1.0 axis_lago_trigger_0 {
  CLK_FREQ 142857132
} {
  S_AXIS adc_0/M_AXIS
  M_AXIS fifo_0/S_AXIS
  aclk adc_0/adc_clk
  aresetn rst_1/peripheral_aresetn
  trig_lvl_i slice_6/Dout
  subtrig_lvl_i slice_7/Dout
  pps_i pps_gen_0/pps_o
  clk_cnt_pps_i pps_gen_0/clk_cnt_pps_o
}

# Create axis_packetizer
cell labdpr:user:axis_packetizer:1.0 pktzr_0 {
  AXIS_TDATA_WIDTH 32
  CNTR_WIDTH 32
  CONTINUOUS FALSE
} {
  S_AXIS fifo_0/M_AXIS
  cfg_data slice_5/Dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_2/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS pktzr_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn slice_3/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 22
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_3/Dout
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
