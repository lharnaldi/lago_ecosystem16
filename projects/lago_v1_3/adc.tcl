# Create xlconstant
cell xilinx.com:ip:xlconstant const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create xlconstant
cell xilinx.com:ip:xlconstant const_2 {
  CONST_WIDTH 16
  CONST_VAL 1
}

# Create dc removal circuit
cell labdpr:user:axis_dc_removal dc_removal_0 {} {
  aclk /pll_0/clk_out1
  aresetn /reset_0/Dout
  S_AXIS /adc_0/M_AXIS
	k1_i const_2/dout
	k2_i const_2/dout
}

# Create pps generator
cell labdpr:user:pps_gen pps_0 {} {
  aclk /pll_0/clk_out1
  aresetn /reset_0/Dout
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger trigger_0 {
  DATA_ARRAY_LENGTH 32
} {
  S_AXIS dc_removal_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /reset_0/Dout
  trig_lvl_a_i /trig_lvl_a/dout
  trig_lvl_b_i /trig_lvl_b/dout
  subtrig_lvl_a_i /subtrig_lvl_a/dout
  subtrig_lvl_b_i /subtrig_lvl_b/dout
  pps_i pps_0/pps_o
  clk_cnt_pps_i pps_0/clk_cnt_pps_o
  temp_i /reg_temp/dout
  pressure_i /reg_pressure/dout
  time_i /reg_time/dout
  date_i /reg_date/dout
  latitude_i /reg_latitude/dout
  longitude_i /reg_longitude/dout
  altitude_i  /reg_altitude/dout 
  satellites_i /reg_satellite/dout     
  scaler_a_i /reg_trig_scaler_a/dout
  scaler_b_i /reg_trig_scaler_b/dout
}

# Create the tlast generator
cell labdpr:user:axis_tlast_gen tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS trigger_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /reset_1/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk /pll_0/clk_out1
  aresetn /reset_2/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer writer_0 {
  ADDR_WIDTH 20
} {
  aclk /pll_0/clk_out1
  aresetn /reset_2/Dout
  S_AXIS conv_0/M_AXIS
  M_AXI /ps_0/S_AXI_HP0
  cfg_data const_1/dout
}

