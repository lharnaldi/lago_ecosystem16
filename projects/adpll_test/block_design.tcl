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

# Create xlslice for reset fifo, adpll and bcast, asc. off=0
cell xilinx.com:ip:xlslice:1.0 reset_0 {
  DIN_WIDTH 1024 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen. off=0
cell xilinx.com:ip:xlslice:1.0 reset_1 {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0. off=0
cell xilinx.com:ip:xlslice:1.0 reset_2 {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get. off=1
cell xilinx.com:ip:xlslice:1.0 nsamples {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_a. off=2
#cell xilinx.com:ip:xlslice:1.0 trig_lvl_a {
#  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64 DOUT_WIDTH 16
#} {
#  Din cfg_0/cfg_data
#}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 wr_offset {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn reset_0/Dout
}

# Create xlconstant k_p constant
cell xilinx.com:ip:xlconstant:1.1 k_p {
  CONST_WIDTH 32
  CONST_VAL 2097152
}

# Create xlconstant k_i constant
cell xilinx.com:ip:xlconstant:1.1 k_i {
  CONST_WIDTH 32
  CONST_VAL 32
}

# Create xlconstant gen enable signal
cell xilinx.com:ip:xlconstant:1.1 gen_en {
  CONST_WIDTH 1
  CONST_VAL 1
}

# Create xlconstant freq value constant 
cell xilinx.com:ip:xlconstant:1.1 freq_val {
  CONST_WIDTH 32
  CONST_VAL 92387
}

# Create xlconstant filter time constant 
# 2147376429 = 0.1111111111111100101110100101101
# = 0.999949735 -> for fc=0.008e-3
cell xilinx.com:ip:xlconstant:1.1 time_const {
  CONST_WIDTH 32
  CONST_VAL 2147376429
}

# Create axis_adpll
cell labdpr:user:axis_adpll:1.0 adpll_0 {
 AXIS_TDATA_WIDTH 32
 ADC_DATA_WIDTH 14
} {
 aclk ps_0/FCLK_CLK0
 aresetn reset_0/Dout
 kp_i k_p/dout
 ki_i k_i/dout
 gen_en_i gen_en/dout
 freq_i freq_val/dout
 locked_o led_o
}

# Create axis_broadcaster
#cell xilinx.com:ip:axis_broadcaster:1.1 bcast_0 {
#  S_TDATA_NUM_BYTES.VALUE_SRC USER
#  M_TDATA_NUM_BYTES.VALUE_SRC USER
#  S_TDATA_NUM_BYTES 4
#  M_TDATA_NUM_BYTES 2
#  M00_TDATA_REMAP {tdata[13:0],2'b00}
#  M01_TDATA_REMAP {tdata[29:16],2'b00}
#} {
#  S_AXIS fifo_0/M_AXIS
#  aclk ps_0/FCLK_CLK0
#  aresetn rst_0/peripheral_aresetn
#}
#
# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 4
  M00_TDATA_REMAP {tdata[31:0]}
  M01_TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS fifo_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  M00_TDATA_REMAP {tdata[15:0]}
  M01_TDATA_REMAP {tdata[15:0]}
} {
  S_AXIS bcast_0/M00_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
}

# Create zero_crossing_det
cell labdpr:user:axis_zero_crossing_det:1.0 zcd_0 {
  HYST_CONST 2048
  AXIS_TDATA_WIDTH 32
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS bcast_0/M01_AXIS
  det_b_o adpll_0/ref_i 
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_0 {
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 2 
  M_TDATA_NUM_BYTES 4 
  TDATA_REMAP {16'b0000000000000000,tdata[15:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS bcast_1/M00_AXIS
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_1 {
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 2 
  M_TDATA_NUM_BYTES 4 
  TDATA_REMAP {16'b0000000000000000,tdata[15:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS bcast_1/M01_AXIS
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster:1.1 bcast_2 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  M00_TDATA_REMAP {tdata[31:16]}
  M01_TDATA_REMAP {tdata[15:0]}
} {
  S_AXIS adpll_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_2 {
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 2 
  M_TDATA_NUM_BYTES 4 
  TDATA_REMAP {16'b0000000000000000,tdata[15:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS bcast_2/M00_AXIS
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_3 { 
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 2 
  M_TDATA_NUM_BYTES 4 
  TDATA_REMAP {16'b0000000000000000,tdata[15:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS bcast_2/M01_AXIS
}

# Create complex multiplier
cell xilinx.com:ip:cmpy:6.0 cmpy_0 {
  OutputWidth 32
} {
  aclk ps_0/FCLK_CLK0
  S_AXIS_A asc_0/M_AXIS
  S_AXIS_B asc_2/M_AXIS
}

# Create complex multiplier
cell xilinx.com:ip:cmpy:6.0 cmpy_1 {
  OutputWidth 32
} {
  aclk ps_0/FCLK_CLK0
  S_AXIS_A asc_1/M_AXIS
  S_AXIS_B asc_3/M_AXIS

}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_4 {
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 8
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS cmpy_0/M_AXIS_DOUT
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter:1.1 asc_5 {
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 8
  M_TDATA_NUM_BYTES 4
  TDATA_REMAP {tdata[31:0]}
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  S_AXIS cmpy_1/M_AXIS_DOUT
}

# Create axis_clock_converter
#cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {
#  TDATA_NUM_BYTES.VALUE_SRC USER
#  TDATA_NUM_BYTES 4
#} {
#  s_axis_aclk pll_0/clk_out1
#  s_axis_aresetn const_0/dout
#  m_axis_aclk ps_0/FCLK_CLK0
#  m_axis_aresetn slice_1/Dout
#}

# Create axis_clock_converter
#cell xilinx.com:ip:axis_clock_converter:1.1 fifo_1 {
#  TDATA_NUM_BYTES.VALUE_SRC USER
#  TDATA_NUM_BYTES 4
#} {
#  s_axis_aclk pll_0/clk_out1
#  s_axis_aresetn const_0/dout
#  m_axis_aclk ps_0/FCLK_CLK0
#  m_axis_aresetn slice_1/Dout
#}

# Create axis_lpf
cell labdpr:user:axis_lpf:1.0 lpf_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  tc_i time_const/dout
  S_AXIS asc_4/M_AXIS
}

# Create axis_lpf
cell labdpr:user:axis_lpf:1.0 lpf_1 {} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  tc_i time_const/dout
  S_AXIS asc_5/M_AXIS
}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner:1.1 comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 2
} {
  S00_AXIS lpf_0/M_AXIS
  S01_AXIS lpf_1/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  pkt_length nsamples/Dout
  aclk ps_0/FCLK_CLK0
  aresetn reset_1/Dout
  S_AXIS comb_0/M_AXIS
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_2/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data wr_offset/dout
  aclk ps_0/FCLK_CLK0
  aresetn reset_2/Dout
}

# Create status register
cell labdpr:user:axi_sts_register:1.0 sts_0 {
  STS_DATA_WIDTH 32
} {
  sts_data writer_0/sts_data
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
