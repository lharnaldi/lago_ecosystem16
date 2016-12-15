# Create processing_system7
cell xilinx.com:ip:processing_system7:5.5 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/red_pitaya.xml
  PCW_USE_S_AXI_HP0 1
  PCW_USE_FABRIC_INTERRUPT 1
  PCW_IRQ_F2P_INTR 1
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
  Dout led_o
}

# Create DMA
cell xilinx.com:ip:axi_dma:7.1 axi_dma_0 {
  c_sg_include_stscntrl_strm 0 
  c_include_mm2s 0 
  c_include_s2mm 1
} {
  s2mm_introut ps_0/IRQ_F2P
}

# Create xlconcat
#cell xilinx.com:ip:xlconcat:2.1 concat_0 {} {
#  In0 axi_dma_0/mm2s_introut
#  In1 axi_dma_0/s2mm_introut
#  dout ps_0/IRQ_F2P
#}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk adc_0/adc_clk
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn rst_0/peripheral_aresetn
}

# Create data FIFO
cell xilinx.com:ip:axis_data_fifo:1.1 fifo_1 {
  FIFO_DEPTH 4096
  FIFO_MODE 2
} {
  S_AXIS fifo_0/M_AXIS
  M_AXIS axi_dma_0/S_AXIS_S2MM
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_0/peripheral_aresetn
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
  Master /axi_dma_0/M_AXI_SG
  Clk Auto
} [get_bd_intf_pins ps_0/S_AXI_HP0]

set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_SG/SEG_ps_0_HP0_DDR_LOWOCM]

# Create all required interconnections
#apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
#  Slave /ps_0/S_AXI_HP0
#  Clk Auto
#} [get_bd_intf_pins axi_dma_0/M_AXI_MM2S]
#
#set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_MM2S/SEG_ps_0_HP0_DDR_LOWOCM]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Slave /ps_0/S_AXI_HP0
  Clk Auto
} [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]

set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_S2MM/SEG_ps_0_HP0_DDR_LOWOCM]

startgroup
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_include_stscntrl_strm {0}] [get_bd_cells axi_dma_0]
endgroup

startgroup
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_mem_intercon]
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Slave "/ps_0/S_AXI_HP0" Clk "Auto" }  [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
