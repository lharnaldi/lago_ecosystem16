source projects/base_system/block_design.tcl

#Enable interrupts
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells ps_0]

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0 {} {
 slowest_sync_clk ps_0/FCLK_CLK0
 ext_reset_in ps_0/FCLK_RESET0_N
}

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc:1.0 adc_0 {} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Create axis_rp_adc
cell labdpr:user:int_counter:1.0 counter_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_0/peripheral_aresetn
}

# Create axi_intc
cell xilinx.com:ip:axi_intc:4.1 axi_intc_0 {
  C_IRQ_CONNECTION 1
  C_S_AXI_ACLK_FREQ_MHZ 143
  C_PROCESSOR_CLK_FREQ_MHZ 143
} {
  intr counter_0/int_o
  irq ps_0/IRQ_F2P
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_intc_0/s_axi]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]


