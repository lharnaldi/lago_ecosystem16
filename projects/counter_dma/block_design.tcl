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

# Create clk_wiz
cell xilinx.com:ip:clk_wiz:5.3 pll_0 {
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

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create DMA
cell xilinx.com:ip:axi_dma:7.1 axi_dma_0 {
  c_sg_include_stscntrl_strm 0 
  c_include_sg 0
  c_include_s2mm_dre 0
  c_include_mm2s 0 
  c_include_s2mm 1
} {
  s2mm_introut ps_0/IRQ_F2P
}

# Create counter
cell labdpr:user:axis_counter:1.0 axis_counter_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_0/peripheral_aresetn
  M_AXIS axi_dma_0/S_AXIS_S2MM
} 

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1 {
 CONST_VAL 65536
 CONST_WIDTH 32
} {
 dout axis_counter_0/cfg_data 
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
  Master /axi_dma_0/M_AXI_S2MM
  Clk Auto
} [get_bd_intf_pins ps_0/S_AXI_HP0]

set_property RANGE 512M [get_bd_addr_segs axi_dma_0/Data_S2MM/SEG_ps_0_HP0_DDR_LOWOCM]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
