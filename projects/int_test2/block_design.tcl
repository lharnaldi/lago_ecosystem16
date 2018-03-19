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
  int_o ps_0/IRQ_F2P
}

