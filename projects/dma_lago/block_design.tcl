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

# Create c_counter_binary
cell xilinx.com:ip:c_counter_binary:12.0 cntr_0 {
  Output_Width 32
} {
  CLK pll_0/clk_out1
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

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
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
#cell xilinx.com:ip:xlconstant:1.1 const_1 {
#  CONST_WIDTH 32
#  CONST_VAL 503316480
#}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_2 

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_3 

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn slice_1/Dout
}

# Create axis_clock_converter
#cell xilinx.com:ip:axis_data_fifo:1.1 axis_data_fifo_0 {
#  FIFO_DEPTH 4096
#} {
#  S_AXIS fifo_0/M_AXIS
#  s_axis_aclk ps_0/FCLK_CLK0
#  s_axis_aresetn slice_1/Dout
#}

# Create DMA
cell xilinx.com:ip:axi_dma:7.1 axi_dma_0 {
  c_sg_include_stscntrl_strm 0
  c_include_sg 0
  c_include_mm2s 0
  c_include_s2mm 1
} {
  s2mm_introut ps_0/IRQ_F2P
  axi_resetn slice_3/Dout
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger:1.0 axis_lago_trigger_0 {
  CLK_FREQ 142857132
} {
  S_AXIS fifo_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  trig_lvl_i slice_6/Dout
  subtrig_lvl_i slice_7/Dout
  gpsen_i const_3/dout
  pps_i const_2/dout
  false_pps_led_o led_o
}

# Create data FIFO
cell xilinx.com:ip:axis_data_fifo:1.1 fifo_1 {
  FIFO_DEPTH 16384
  FIFO_MODE 2
} {
  M_AXIS axi_dma_0/S_AXIS_S2MM
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_0/peripheral_aresetn
}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 16
} {
  M_AXIS fifo_1/S_AXIS
  S_AXIS axis_lago_trigger_0/M_AXIS
  pkt_length slice_5/Dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_2/Dout
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_axi_dma_0_reg]
set_property OFFSET 0x40400000 [get_bd_addr_segs ps_0/Data/SEG_axi_dma_0_reg]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /axi_dma_0/M_AXI_S2MM
  Clk Auto
} [get_bd_intf_pins ps_0/S_AXI_HP0]

set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_S2MM/SEG_ps_0_HP0_DDR_LOWOCM]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]

# Create axis_packetizer
#cell labdpr:user:axis_packetizer:1.0 pktzr_0 {
#  AXIS_TDATA_WIDTH 32
#  CNTR_WIDTH 32
#  CONTINUOUS FALSE
#} {
#  S_AXIS axis_lago_trigger_0/M_AXIS
#  cfg_data slice_5/Dout
#  aclk ps_0/FCLK_CLK0
#  aresetn slice_2/Dout
#}
#
## Create axis_dwidth_converter
#cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
#  S_TDATA_NUM_BYTES.VALUE_SRC USER
#  S_TDATA_NUM_BYTES 4
#  M_TDATA_NUM_BYTES 8
#} {
#  S_AXIS pktzr_0/M_AXIS
#  aclk ps_0/FCLK_CLK0
#  aresetn slice_3/Dout
#}
#
## Create axis_ram_writer
#cell labdpr:user:axis_ram_writer:1.0 writer_0 {
#  ADDR_WIDTH 22
#} {
#  S_AXIS conv_0/M_AXIS
#  M_AXI ps_0/S_AXI_HP0
#  cfg_data const_1/dout
#  aclk ps_0/FCLK_CLK0
#  aresetn slice_3/Dout
#}

#assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
