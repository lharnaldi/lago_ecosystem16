source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  aclk pll_0/clk_out1
  adc_clk_n adc_clk_n_i
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
  Dout led_o
}

# Create DMA
cell xilinx.com:ip:axi_dma:7.1 axi_dma_0 {
  c_sg_include_stscntrl_strm 0 
  c_include_mm2s 1 
  c_include_s2mm 1
} {}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {} {
  In0 axi_dma_0/mm2s_introut
  In1 axi_dma_0/s2mm_introut
  dout ps_0/IRQ_F2P
}

# Create data loopback fifo
cell xilinx.com:ip:axis_data_fifo:1.1 data_fifo_0 {} {
  M_AXIS axi_dma_0/S_AXIS_S2MM
  S_AXIS axi_dma_0/M_AXIS_MM2S
  s_axis_aclk ps_0/FCLK_CLK0
  s_axis_aresetn rst_0/peripheral_aresetn
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_dma_0/S_AXI_LITE]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_dma_0_reg]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_axi_dma_0_reg]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /axi_dma_0/M_AXI_SG
  Clk Auto
} [get_bd_intf_pins ps_0/S_AXI_HP0]

set_property RANGE 2M [get_bd_addr_segs axi_dma_0/Data_SG/SEG_ps_0_HP0_DDR_LOWOCM]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Slave /ps_0/S_AXI_HP0
  Clk Auto
} [get_bd_intf_pins axi_dma_0/M_AXI_MM2S]

set_property RANGE 2M [get_bd_addr_segs axi_dma_0/Data_MM2S/SEG_ps_0_HP0_DDR_LOWOCM]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Slave /ps_0/S_AXI_HP0
  Clk Auto
} [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]

set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_S2MM/SEG_ps_0_HP0_DDR_LOWOCM]

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn rst_0/peripheral_aresetn
}

startgroup
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_include_stscntrl_strm {0}] [get_bd_cells axi_dma_0]
endgroup

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
