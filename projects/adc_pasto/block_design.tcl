source projects/base_system/block_design.tcl

set_property -dict [list CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100} CLKOUT2_REQUESTED_PHASE {0} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKOUT1_DIVIDE {10} CONFIG.CLKOUT2_JITTER {124.615}] [get_bd_cells pll_0]

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

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

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

# Create xlslice for reset fifo, pps_gen and trigger modules
cell xilinx.com:ip:xlslice:1.0 slice_0 {
  DIN_WIDTH 128 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 128 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0
cell xilinx.com:ip:xlslice:1.0 slice_2 {
  DIN_WIDTH 128 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get
cell xilinx.com:ip:xlslice:1.0 slice_3 {
  DIN_WIDTH 128 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for controlling the MUX select pin
#cell xilinx.com:ip:xlslice:1.0 slice_4 {
#  DIN_WIDTH 128 DIN_FROM 3 DIN_TO 3 DOUT_WIDTH 1
#} {
#  Din cfg_0/cfg_data
#}

# Create c_counter_binary
cell xilinx.com:ip:c_counter_binary:12.0 cntr_0 {
  Output_Width 32
} {
  CLK pll_0/clk_out1
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_5 {
  DIN_WIDTH 32 DIN_FROM 26 DIN_TO 26 DOUT_WIDTH 1
} { 
  Din cntr_0/Q
  Dout led_o
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1 {
  CONST_VAL 0
} {}

# Create dna_reader
cell labdpr:user:dna_reader:1.0 dna_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn rst_0/peripheral_aresetn
}

# Create xlconcat
cell xilinx.com:ip:xlconcat:2.1 concat_0 {
  NUM_PORTS 2
  IN0_WIDTH 64
  IN1_WIDTH 32
} {
  In0 dna_0/dna_data
}

# Create axi_sts_register
cell labdpr:user:axi_sts_register:1.0 sts_0 {
  STS_DATA_WIDTH 128
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data concat_0/dout
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

# Delete input/output port
delete_bd_objs [get_bd_ports exp_p_tri_io]

# Create input port
create_bd_port -dir IO -from 7 -to 6 exp_p_tri_io
create_bd_port -dir O -from 5 -to 5 exp_p_mux
create_bd_port -dir O -from 4 -to 4 exp_p_clk

cell xilinx.com:ip:xlconcat:2.1 concat_1 {} {
  In0 exp_n_tri_io
  In1 exp_p_tri_io
}

# Create axis_gpio_reader
cell labdpr:user:axis_gpio_reader_i:1.0 gpio_0 {
  AXIS_TDATA_WIDTH 10
} {
  gpio_data concat_1/dout
  aclk pll_0/clk_out2
}
 
cell xilinx.com:ip:selectio_wiz:5.1 selio_wiz_0 {
  BUS_DIR OUTPUTS
  BUS_IO_STD LVCMOS33
  SELIO_CLK_BUF BUFIO 
  SERIALIZATION_FACTOR 4
  SELIO_CLK_IO_STD LVCMOS33 
  CLK_FWD_IO_STD LVCMOS33
} {
  clk_in pll_0/clk_out2
  io_reset const_1/dout
  data_out_to_pins exp_p_mux
  clk_out exp_p_clk
  data_out_from_device const_0/dout
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS gpio_0/M_AXIS
  s_axis_aclk pll_0/clk_out2
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn slice_0/Dout
}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS fifo_0/M_AXIS
  pkt_length slice_3/Dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn slice_2/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk ps_0/FCLK_CLK0
  aresetn slice_2/Dout
  sts_data concat_0/In1
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]


