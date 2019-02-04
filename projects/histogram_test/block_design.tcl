source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create c_counter_binary
cell xilinx.com:ip:c_counter_binary:12.0 cntr_0 {
  Output_Width 32
} {
  CLK ps_0/FCLK_CLK0
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_0 {
  DIN_FROM 26
  DIN_TO 26
} {
  Din cntr_0/Q
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

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 1024 DIN_FROM 134 DIN_TO 128 DOUT_WIDTH 7
} {
  Din cfg_0/cfg_data
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {
  IN1_WIDTH 7
} {
  In0 slice_0/Dout
  In1 slice_1/Dout
  dout led_o
}
#cfg_test end
#
# Create xlslice. rst counter
cell xilinx.com:ip:xlslice:1.0 rst_cntr {
  DIN_WIDTH 1024 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create xlslice. rst histogramer
cell xilinx.com:ip:xlslice:1.0 rst_hist {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create xlslice. rst bram reader
cell xilinx.com:ip:xlslice:1.0 rst_bram_reader {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2
} {
  din cfg_0/cfg_data
}

# Create xlslice. rst conv and writer
cell xilinx.com:ip:xlslice:1.0 rst_conv_writer {
  DIN_WIDTH 1024 DIN_FROM 3 DIN_TO 3
} {
  din cfg_0/cfg_data
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_6 {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_7 {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# Create axis_counter
cell labdpr:user:axis_counter:1.0 cntr_1 {
  AXIS_TDATA_WIDTH 16
} {
  cfg_data slice_6/dout
  aclk ps_0/FCLK_CLK0
  aresetn rst_cntr/dout
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
cell labdpr:user:axis_histogram:1.0 hist_0 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AXIS_TDATA_WIDTH 16
} {
  S_AXIS cntr_1/M_AXIS
  BRAM_PORTA bram_0/BRAM_PORTA
  aclk ps_0/FCLK_CLK0
  aresetn rst_hist/dout
}

# Create axis_bram_reader
cell labdpr:user:axis_bram_reader:1.0 reader_0 {
  AXIS_TDATA_WIDTH 32
  BRAM_DATA_WIDTH 32
  BRAM_ADDR_WIDTH 14
  CONTINUOUS FALSE
} {
  BRAM_PORTA bram_0/BRAM_PORTB
  cfg_data slice_7/dout
  aclk ps_0/FCLK_CLK0
  aresetn rst_bram_reader/dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS reader_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn rst_conv_writer/dout
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_0/dout
  aclk ps_0/FCLK_CLK0
  aresetn rst_conv_writer/dout
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
