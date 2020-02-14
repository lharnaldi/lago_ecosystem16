source projects/packetizer_test/block_design.tcl

# Create dds_compiler
cell xilinx.com:ip:dds_compiler dds_0 {
  DDS_CLOCK_RATE 125
  SPURIOUS_FREE_DYNAMIC_RANGE 84
  FREQUENCY_RESOLUTION 0.5
  AMPLITUDE_MODE Unit_Circle
  HAS_PHASE_OUT false
  OUTPUT_FREQUENCY1 0.9765625
} {
  aclk pll_0/clk_out1
}

# Create axis_rp_dac
cell labdpr:user:axis_rp_dac dac_0 {} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  locked pll_0/locked
  S_AXIS dds_0/M_AXIS_DATA
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
}
