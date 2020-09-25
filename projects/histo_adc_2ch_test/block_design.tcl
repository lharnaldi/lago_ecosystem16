source projects/cfg_test/block_design.tcl

# Create port_slicer
cell labdpr:user:port_slicer rst_hst_0 {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer cfg_hst_0 {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer rst_hst_1 {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer cfg_hst_1 {
  DIN_WIDTH 1024 DIN_FROM 127 DIN_TO 96
} {
  din cfg_0/cfg_data
}

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc adc_0 {
  ADC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}
# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster bcast_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  NUM_MI 2
  M00_TDATA_REMAP {tdata[15:0]}
  M01_TDATA_REMAP {tdata[31:16]}
} {
  S_AXIS adc_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create blk_mem_gen
cell xilinx.com:ip:blk_mem_gen bram_0 {
  MEMORY_TYPE True_Dual_Port_RAM
  USE_BRAM_BLOCK Stand_Alone
  WRITE_WIDTH_A 32
  WRITE_DEPTH_A 16384
  ENABLE_A Always_Enabled
  ENABLE_B Always_Enabled
  REGISTER_PORTB_OUTPUT_OF_MEMORY_PRIMITIVES false
}

# Create axis_histogram
cell labdpr:user:axis_histogram:1.1 hist_0 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AXIS_TDATA_WIDTH 16
} {
  S_AXIS bcast_0/M00_AXIS
  BRAM_PORTA bram_0/BRAM_PORTA
  cfg_data cfg_hst_0/dout
  aclk pll_0/clk_out1
  aresetn rst_hst_0/dout
}

# Create axi_bram_reader
cell labdpr:user:axi_bram_reader reader_0 {
  AXI_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 14
} {
  BRAM_PORTA bram_0/BRAM_PORTB
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins reader_0/S_AXI]

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]
set_property OFFSET 0x40010000 [get_bd_addr_segs ps_0/Data/SEG_reader_0_reg0]

# Create blk_mem_gen
cell xilinx.com:ip:blk_mem_gen bram_1 {
  MEMORY_TYPE True_Dual_Port_RAM
  USE_BRAM_BLOCK Stand_Alone
  WRITE_WIDTH_A 32
  WRITE_DEPTH_A 16384
  ENABLE_A Always_Enabled
  ENABLE_B Always_Enabled
  REGISTER_PORTB_OUTPUT_OF_MEMORY_PRIMITIVES false
}

# Create axis_histogram
cell labdpr:user:axis_histogram:1.1 hist_1 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AXIS_TDATA_WIDTH 16
} {
  S_AXIS bcast_0/M01_AXIS
  BRAM_PORTA bram_1/BRAM_PORTA
  cfg_data cfg_hst_1/dout
  aclk pll_0/clk_out1
  aresetn rst_hst_1/dout
}

# Create axi_bram_reader
cell labdpr:user:axi_bram_reader reader_1 {
  AXI_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 14
} {
  BRAM_PORTA bram_1/BRAM_PORTB
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins reader_1/S_AXI]

set_property RANGE 64K [get_bd_addr_segs ps_0/Data/SEG_reader_1_reg0]
set_property OFFSET 0x40020000 [get_bd_addr_segs ps_0/Data/SEG_reader_1_reg0]

# Create axis_broadcaster
cell xilinx.com:ip:xlconcat concat_1 {
  IN0_WIDTH.VALUE_SRC USER 
  IN1_WIDTH.VALUE_SRC USER
  IN0_WIDTH 32
  IN1_WIDTH 32
} {
  In0 hist_0/sts_data
  In1 hist_1/sts_data
}

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 64
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data concat_1/dout
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

group_bd_cells PS [get_bd_cells rst_0] [get_bd_cells pll_0] [get_bd_cells const_0] [get_bd_cells ps_0] [get_bd_cells ps_0_axi_periph]
group_bd_cells hst0 [get_bd_cells hist_0] [get_bd_cells cfg_hst_0] [get_bd_cells reader_0] [get_bd_cells bram_0] [get_bd_cells rst_hst_0]
group_bd_cells hst1 [get_bd_cells hist_1] [get_bd_cells cfg_hst_1] [get_bd_cells reader_1] [get_bd_cells bram_1] [get_bd_cells rst_hst_1]
