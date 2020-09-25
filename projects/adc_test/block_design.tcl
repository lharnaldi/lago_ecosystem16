# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 125.0
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 125.0
  CLKOUT2_USED true
  CLKOUT2_REQUESTED_OUT_FREQ 250.0
  CLKOUT2_REQUESTED_PHASE -112.5
  CLKOUT3_USED true
  CLKOUT3_REQUESTED_OUT_FREQ 250.0
  CLKOUT3_REQUESTED_PHASE -67.5
  USE_RESET false
} {
  clk_in1_p adc_clk_p_i
  clk_in1_n adc_clk_n_i
}

# Create processing_system7
cell xilinx.com:ip:processing_system7 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/red_pitaya.xml
  PCW_USE_S_AXI_HP0 1
} {
  M_AXI_GP0_ACLK pll_0/clk_out1
  S_AXI_HP0_ACLK pll_0/clk_out1
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master Disable
  Slave Disable
} [get_bd_cells ps_0]

# Create xlconstant
cell xilinx.com:ip:xlconstant const_0

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
}

# ADC

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc adc_0 {
  ADC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# DAC

# Create axis_rp_dac
cell labdpr:user:axis_rp_dac dac_0 {
  DAC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  wrt_clk pll_0/clk_out3
  locked pll_0/locked
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
  s_axis_tvalid const_0/dout
}

# CFG

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 128
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create port_slicer
cell labdpr:user:port_slicer slice_0 {
  DIN_WIDTH 128 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer slice_1 {
  DIN_WIDTH 128 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell labdpr:user:port_slicer slice_2 {
  DIN_WIDTH 128 DIN_FROM 31 DIN_TO 16
} {
  din cfg_0/cfg_data
}

# RX

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  TDATA_REMAP {tdata[15:0]}
} {
  S_AXIS adc_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create axis_constant
cell labdpr:user:axis_variable rate_0 {
  AXIS_TDATA_WIDTH 16
} {
  cfg_data slice_2/dout
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create cic_compiler
cell xilinx.com:ip:cic_compiler cic_0 {
  INPUT_DATA_WIDTH.VALUE_SRC USER
  FILTER_TYPE Decimation
  NUMBER_OF_STAGES 6
  SAMPLE_RATE_CHANGES Programmable
  MINIMUM_RATE 4
  MAXIMUM_RATE 6250
  FIXED_OR_INITIAL_RATE 4
  INPUT_SAMPLE_FREQUENCY 125
  CLOCK_FREQUENCY 125
  INPUT_DATA_WIDTH 16
  QUANTIZATION Truncation
  OUTPUT_DATA_WIDTH 16
  USE_XTREME_DSP_SLICE false
  HAS_ARESETN true
} {
  S_AXIS_DATA subset_0/M_AXIS
  S_AXIS_CONFIG rate_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 2
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS cic_0/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# DMA

# Create xlconstant
cell xilinx.com:ip:xlconstant const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer writer_0 {
  ADDR_WIDTH 16
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk pll_0/clk_out1
  aresetn slice_1/dout
}

# GEN

# Create axis_lfsr
cell labdpr:user:axis_lfsr lfsr_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

for {set i 0} {$i <= 1} {incr i} {

  # Create port_slicer
  cell labdpr:user:port_slicer slice_[expr $i + 3] {
    DIN_WIDTH 128 DIN_FROM [expr 32 * $i + 63] DIN_TO [expr 32 * $i + 32]
  } {
    din cfg_0/cfg_data
  }

  # Create port_slicer
  cell labdpr:user:port_slicer slice_[expr $i + 5] {
    DIN_WIDTH 128 DIN_FROM [expr 16 * $i + 111] DIN_TO [expr 16 * $i + 96]
  } {
    din cfg_0/cfg_data
  }

  # Create axis_constant
  cell labdpr:user:axis_constant phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 3]/dout
    aclk pll_0/clk_out1
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler dds_$i {
    DDS_CLOCK_RATE 125
    SPURIOUS_FREE_DYNAMIC_RANGE 138
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 24
    DSP48_USE Minimal
    NEGATIVE_SINE true
  } {
    S_AXIS_PHASE phase_$i/M_AXIS
    aclk pll_0/clk_out1
  }

  # Create xbip_dsp48_macro
  cell xilinx.com:ip:xbip_dsp48_macro mult_$i {
    INSTRUCTION1 RNDSIMPLE(A*B+CARRYIN)
    A_WIDTH.VALUE_SRC USER
    B_WIDTH.VALUE_SRC USER
    OUTPUT_PROPERTIES User_Defined
    A_WIDTH 24
    B_WIDTH 16
    P_WIDTH 15
  } {
    A dds_$i/m_axis_data_tdata
    B slice_[expr $i + 5]/dout
    CARRYIN lfsr_0/m_axis_tdata
    CLK pll_0/clk_out1
  }

}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 2
  IN0_WIDTH 16
  IN1_WIDTH 16
} {
  In0 mult_0/P
  In1 mult_1/P
  dout dac_0/s_axis_tdata
}

# STS

# Create dna_reader
cell labdpr:user:dna_reader dna_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_1 {
  NUM_PORTS 3
  IN0_WIDTH 32
  IN1_WIDTH 64
  IN2_WIDTH 32
} {
  In0 const_0/dout
  In1 dna_0/dna_data
  In2 writer_0/sts_data
}

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 128
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

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
group_bd_cells PS7 [get_bd_cells rst_0] [get_bd_cells pll_0] [get_bd_cells const_0] [get_bd_cells ps_0] [get_bd_cells ps_0_axi_periph]
group_bd_cells ACQ [get_bd_cells rate_0] [get_bd_cells adc_0] [get_bd_cells subset_0] [get_bd_cells slice_0] [get_bd_cells slice_1] [get_bd_cells conv_0] [get_bd_cells slice_2] [get_bd_cells cic_0] [get_bd_cells writer_0] [get_bd_cells const_1]
group_bd_cells CMPLX_GEN [get_bd_cells phase_1] [get_bd_cells mult_0] [get_bd_cells dds_0] [get_bd_cells dds_1] [get_bd_cells mult_1] [get_bd_cells slice_3] [get_bd_cells dac_0] [get_bd_cells slice_4] [get_bd_cells slice_5] [get_bd_cells concat_0] [get_bd_cells slice_6] [get_bd_cells phase_0] [get_bd_cells lfsr_0]
