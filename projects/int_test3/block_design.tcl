source projects/base_system/block_design.tcl

# Change clock frequency of PS
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {50}] [get_bd_cells ps_0]

#Enable interrupts
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells ps_0]

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0 

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axis_rp_adc
cell xilinx.com:ip:axi_timer:2.0 axi_timer_0 {
  enable_timer2 0
} {
 interrupt ps_0/IRQ_F2P
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_timer_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_timer_0_Reg]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_axi_timer_0_Reg]

