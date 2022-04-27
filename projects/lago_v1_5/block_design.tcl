source projects/base_system/block_design.tcl


# Create xlconstant
cell xilinx.com:ip:xlconstant const_0

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
}

#Enable interrupts
set_property -dict [list CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells ps_0]

# Create axis_rp_adc
cell labdpr:user:axis_rp_adc adc_0 {
  ADC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# Delete input/output port
delete_bd_objs [get_bd_ports exp_p_tri_io]
delete_bd_objs [get_bd_ports exp_n_tri_io]

# Create input port
create_bd_port -dir I -from 7 -to 7 exp_n_tri_io
create_bd_port -dir O -from 7 -to 7 exp_p_tri_io
create_bd_port -dir I -from 0 -to 0 ext_resetn

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 1024
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

addr 0x40001000 4K cfg_0/S_AXI /ps_0/M_AXI_GP0

# Create xlslice for reset fifo, pps_gen and trigger modules. off=0
cell labdpr:user:port_slicer reset_0 {
  DIN_WIDTH 1024 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen. off=0
cell labdpr:user:port_slicer reset_1 {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0. off=0
cell labdpr:user:port_slicer reset_2 {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get. off=4
cell labdpr:user:port_slicer nsamples {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_a. off=8
cell labdpr:user:port_slicer trig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_b. off=C
cell labdpr:user:port_slicer trig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 127 DIN_TO 96
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_a. off=10
cell labdpr:user:port_slicer subtrig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 159 DIN_TO 128
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_b. off=14
cell labdpr:user:port_slicer subtrig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 191 DIN_TO 160
} {
  din cfg_0/cfg_data
}

# Create xlslice for the temperature data. off=18
cell labdpr:user:port_slicer reg_temp {
  DIN_WIDTH 1024 DIN_FROM 223 DIN_TO 192
} {
  din cfg_0/cfg_data
}

# Create xlslice for the pressure data. off=1C
cell labdpr:user:port_slicer reg_pressure {
  DIN_WIDTH 1024 DIN_FROM 255 DIN_TO 224
} {
  din cfg_0/cfg_data
}

# Create xlslice for the time data. off=20
cell labdpr:user:port_slicer reg_time {
  DIN_WIDTH 1024 DIN_FROM 287 DIN_TO 256
} {
  din cfg_0/cfg_data
}

# Create xlslice for the date data. off=24
cell labdpr:user:port_slicer reg_date {
  DIN_WIDTH 1024 DIN_FROM 319 DIN_TO 288
} {
  din cfg_0/cfg_data
}

# Create xlslice for the latitude data. off=28
cell labdpr:user:port_slicer reg_latitude {
  DIN_WIDTH 1024 DIN_FROM 351 DIN_TO 320
} {
  din cfg_0/cfg_data
}

# Create xlslice for the longitude data. off=2C
cell labdpr:user:port_slicer reg_longitude {
  DIN_WIDTH 1024 DIN_FROM 383 DIN_TO 352
} {
  din cfg_0/cfg_data
}

# Create xlslice for the altitude data. off=30
cell labdpr:user:port_slicer reg_altitude {
  DIN_WIDTH 1024 DIN_FROM 415 DIN_TO 384
} {
  din cfg_0/cfg_data
}

# Create xlslice for the satellite data. off=34
cell labdpr:user:port_slicer reg_satellite {
  DIN_WIDTH 1024 DIN_FROM 447 DIN_TO 416
} {
  din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler a. off=38
cell labdpr:user:port_slicer reg_trig_scaler_a {
  DIN_WIDTH 1024 DIN_FROM 479 DIN_TO 448
} {
  din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler b. off=3C
cell labdpr:user:port_slicer reg_trig_scaler_b {
  DIN_WIDTH 1024 DIN_FROM 511 DIN_TO 480
} {
  din cfg_0/cfg_data
}

# Create port_slicer for cfg RAM writer. off=58
cell labdpr:user:port_slicer cfg_ram_wr {
  DIN_WIDTH 1024 DIN_FROM 735 DIN_TO 704
} {
  din cfg_0/cfg_data
}

# Create xlslice for set the gpsen_i input. off=0
cell labdpr:user:port_slicer gpsen {
  DIN_WIDTH 1024 DIN_FROM 4 DIN_TO 4
} {
  din cfg_0/cfg_data
}

# Create xlconstant
cell xilinx.com:ip:xlconstant const_2 {
  CONST_WIDTH 16
  CONST_VAL 1
}

#Create concatenator
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 6
} {
  dout led_o
}

# Create pps generator
cell labdpr:user:pps_gen pps_0 {} {
  aclk pll_0/clk_out1
  aresetn reset_0/dout
  gpsen_i gpsen/dout
  pps_i exp_n_tri_io
  pps_sig_o exp_p_tri_io
  pps_gps_led_o concat_0/In0
  false_pps_led_o concat_0/In1
}
# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_1 {} {
  slowest_sync_clk pll_0/clk_out1
  dcm_locked pll_0/locked
  ext_reset_in ext_resetn
  peripheral_aresetn pps_0/resetn_i
}

# Create dc removal circuit
cell labdpr:user:axis_dc_removal dc_removal_0 {} {
  aclk pll_0/clk_out1
  aresetn reset_0/dout
  S_AXIS adc_0/M_AXIS
	k1_i const_2/dout
	k2_i const_2/dout
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger trigger_0 {
  DATA_ARRAY_LENGTH 32
} {
  S_AXIS dc_removal_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn reset_0/dout
  trig_lvl_a_i trig_lvl_a/dout
  trig_lvl_b_i trig_lvl_b/dout
  subtrig_lvl_a_i subtrig_lvl_a/dout
  subtrig_lvl_b_i subtrig_lvl_b/dout
  pps_i pps_0/pps_o
  clk_cnt_pps_i pps_0/clk_cnt_pps_o
  temp_i reg_temp/dout
  pressure_i reg_pressure/dout
  time_i reg_time/dout
  date_i reg_date/dout
  latitude_i reg_latitude/dout
  longitude_i reg_longitude/dout
  altitude_i  reg_altitude/dout 
  satellites_i reg_satellite/dout     
  scaler_a_i reg_trig_scaler_a/dout
  scaler_b_i reg_trig_scaler_b/dout
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster bcast_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 4
  NUM_MI 2
  M00_TDATA_REMAP {tdata[31:0]}
  M01_TDATA_REMAP {tdata[31:0]}
} {
  S_AXIS trigger_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn rst_1/peripheral_aresetn
}

# Create axi_intc
cell xilinx.com:ip:axi_intc axi_intc_0 {
  C_IRQ_CONNECTION 1
  C_S_AXI_ACLK_FREQ_MHZ 125
  C_PROCESSOR_CLK_FREQ_MHZ 125
} {
  irq ps_0/IRQ_F2P
  intr pps_0/int_o
}

addr 0x40000000 4K axi_intc_0/s_axi /ps_0/M_AXI_GP0

# Create the tlast generator
cell labdpr:user:axis_tlast_gen tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS bcast_0/M00_AXIS
  pkt_length nsamples/dout
  aclk pll_0/clk_out1
  aresetn reset_1/dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn reset_2/dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer writer_0 {
  ADDR_WIDTH 22
  AXI_ID_WIDTH 3
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_ACP
  cfg_data cfg_ram_wr/dout
  aclk pll_0/clk_out1
  aresetn reset_2/dout
}

#Now all related to the DAC PWM
# Create xlslice. off=0
cell labdpr:user:port_slicer reset_3 {
  DIN_WIDTH 1024 DIN_FROM 3 DIN_TO 3 
} {
  Din cfg_0/cfg_data
}

# Create xlslice. off=40 
cell labdpr:user:port_slicer cfg_dac_pwm_0 {
  DIN_WIDTH 1024 DIN_FROM 543 DIN_TO 512 
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=44
cell labdpr:user:port_slicer cfg_dac_pwm_1 {
  DIN_WIDTH 1024 DIN_FROM 575 DIN_TO 544 
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=48
cell labdpr:user:port_slicer cfg_dac_pwm_2 {
  DIN_WIDTH 1024 DIN_FROM 607 DIN_TO 576 
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=4C 
cell labdpr:user:port_slicer cfg_dac_pwm_3 {
  DIN_WIDTH 1024 DIN_FROM 639 DIN_TO 608 
} {
  Din cfg_0/cfg_data
}

#Create concatenator
cell xilinx.com:ip:xlconcat concat_1 {
  NUM_PORTS 4
} {
  dout dac_pwm_o
}

#Create PWM generator
cell labdpr:user:ramp_gen gen_0 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk pll_0/clk_out1
  aresetn reset_3/dout
  data_i cfg_dac_pwm_0/dout
  pwm_o concat_1/In0
  led_o concat_0/In2
}

#Create PWM generator
cell labdpr:user:ramp_gen gen_1 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk pll_0/clk_out1
  aresetn reset_3/dout
  data_i cfg_dac_pwm_1/dout
  pwm_o concat_1/In1
  led_o concat_0/In3
}

#Create PWM generator
cell labdpr:user:ramp_gen gen_2 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk pll_0/clk_out1
  aresetn reset_3/dout
  data_i cfg_dac_pwm_2/dout
  pwm_o concat_1/In2
  led_o concat_0/In4
}

#Create PWM generator
cell labdpr:user:ramp_gen gen_3 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk pll_0/clk_out1
  aresetn reset_3/dout
  data_i cfg_dac_pwm_3/dout
  pwm_o concat_1/In3
  led_o concat_0/In5
}

#XADC related
# Create xadc
cell xilinx.com:ip:xadc_wiz xadc_wiz_0 {
	DCLK_FREQUENCY 125
	ADC_CONVERSION_RATE 500
  XADC_STARUP_SELECTION channel_sequencer
	CHANNEL_AVERAGING 64
  OT_ALARM false
  USER_TEMP_ALARM false
  VCCINT_ALARM false
  VCCAUX_ALARM false
  ENABLE_VCCPINT_ALARM false
  ENABLE_VCCPAUX_ALARM false
  ENABLE_VCCDDRO_ALARM false
  CHANNEL_ENABLE_CALIBRATION true
  CHANNEL_ENABLE_TEMPERATURE true
  CHANNEL_ENABLE_VCCINT true
  CHANNEL_ENABLE_VP_VN true
  CHANNEL_ENABLE_VAUXP0_VAUXN0 true
  CHANNEL_ENABLE_VAUXP1_VAUXN1 true
  CHANNEL_ENABLE_VAUXP8_VAUXN8 true
  CHANNEL_ENABLE_VAUXP9_VAUXN9 true
  AVERAGE_ENABLE_VP_VN true
  AVERAGE_ENABLE_VAUXP0_VAUXN0 true
  AVERAGE_ENABLE_VAUXP1_VAUXN1 true
  AVERAGE_ENABLE_VAUXP8_VAUXN8 true
  AVERAGE_ENABLE_VAUXP9_VAUXN9 true
  AVERAGE_ENABLE_TEMPERATURE true
  AVERAGE_ENABLE_VCCINT true
  EXTERNAL_MUX_CHANNEL VP_VN
  SINGLE_CHANNEL_SELECTION TEMPERATURE
} {}

connect_bd_intf_net [get_bd_intf_ports Vp_Vn] [get_bd_intf_pins xadc_wiz_0/Vp_Vn]
connect_bd_intf_net [get_bd_intf_ports Vaux0] [get_bd_intf_pins xadc_wiz_0/Vaux0]
connect_bd_intf_net [get_bd_intf_ports Vaux1] [get_bd_intf_pins xadc_wiz_0/Vaux1]
connect_bd_intf_net [get_bd_intf_ports Vaux8] [get_bd_intf_pins xadc_wiz_0/Vaux8]
connect_bd_intf_net [get_bd_intf_ports Vaux9] [get_bd_intf_pins xadc_wiz_0/Vaux9]

addr 0x40003000 4K xadc_wiz_0/s_axi_lite /ps_0/M_AXI_GP0

#Histogramers
# Create port_slicer for reset hist0. off=0
cell labdpr:user:port_slicer rst_hst_0 {
  DIN_WIDTH 1024 DIN_FROM 5 DIN_TO 5
} {
  din cfg_0/cfg_data
}

# Create port_slicer for cfg hist0. off=50
cell labdpr:user:port_slicer cfg_hst_0 {
  DIN_WIDTH 1024 DIN_FROM 671 DIN_TO 640
} {
  din cfg_0/cfg_data
}

# Create port_slicer for reset hist0. off=0
cell labdpr:user:port_slicer rst_hst_1 {
  DIN_WIDTH 1024 DIN_FROM 6 DIN_TO 6
} {
  din cfg_0/cfg_data
}

# Create port_slicer for cfg hist1. off=54
cell labdpr:user:port_slicer cfg_hst_1 {
  DIN_WIDTH 1024 DIN_FROM 703 DIN_TO 672
} {
  din cfg_0/cfg_data
}

# Create axis_broadcaster
cell xilinx.com:ip:axis_broadcaster bcast_1 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 2
  NUM_MI 2
  M00_TDATA_REMAP {tdata[15:0]}
  M01_TDATA_REMAP {tdata[31:16]}
} {
  S_AXIS bcast_0/M01_AXIS
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
cell labdpr:user:axis_histogram hist_0 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AXIS_TDATA_WIDTH 16
} {
  S_AXIS bcast_1/M00_AXIS
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

addr 0x40010000 64K reader_0/S_AXI /ps_0/M_AXI_GP0

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
cell labdpr:user:axis_histogram hist_1 {
  BRAM_ADDR_WIDTH 14
  BRAM_DATA_WIDTH 32
  AXIS_TDATA_WIDTH 16
} {
  S_AXIS bcast_1/M01_AXIS
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

addr 0x40020000 64K reader_1/S_AXI /ps_0/M_AXI_GP0

# Create axis_broadcaster
cell xilinx.com:ip:xlconcat concat_2 {
  NUM_PORTS 3
  IN0_WIDTH.VALUE_SRC USER 
  IN1_WIDTH.VALUE_SRC USER
  IN2_WIDTH.VALUE_SRC USER
  IN0_WIDTH 32
  IN1_WIDTH 32
  IN2_WIDTH 32
} {
  In0 writer_0/sts_data
  In1 hist_0/sts_data
  In2 hist_1/sts_data
}

# Create axi_sts_register
cell labdpr:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 96
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data concat_2/dout
}

addr 0x40002000 4K sts_0/S_AXI /ps_0/M_AXI_GP0

group_bd_cells PS [get_bd_cells axi_intc_0] [get_bd_cells rst_0] [get_bd_cells pll_0] [get_bd_cells const_0] [get_bd_cells ps_0] [get_bd_cells ps_0_axi_periph]
group_bd_cells hst0 [get_bd_cells hist_0] [get_bd_cells cfg_hst_0] [get_bd_cells reader_0] [get_bd_cells bram_0] [get_bd_cells rst_hst_0]
group_bd_cells hst1 [get_bd_cells hist_1] [get_bd_cells cfg_hst_1] [get_bd_cells reader_1] [get_bd_cells bram_1] [get_bd_cells rst_hst_1]

group_bd_cells FADC [get_bd_cells bcast_0] [get_bd_cells rst_1] [get_bd_cells const_2] [get_bd_cells dc_removal_0] [get_bd_cells reg_trig_scaler_a] [get_bd_cell reg_trig_scaler_b] [get_bd_cells reg_date] [get_bd_cells tlast_gen_0] [get_bd_cells reset_0] [get_bd_cells subtrig_lvl_a] [get_bd_cells subtrig_lvl_b] [get_bd_cells pps_0] [get_bd_cells gpsen] [get_bd_cells conv_0] [get_bd_cells reset_1] [get_bd_cells trig_lvl_a] [get_bd_cells const_0] [get_bd_cells cfg_ram_wr] [get_bd_cells trig_lvl_b] [get_bd_cells fifo_0] [get_bd_cells reset_2] [get_bd_cells writer_0] [get_bd_cells nsamples] [get_bd_cells trigger_0] [get_bd_cells adc_0] [get_bd_cells reg_temp] [get_bd_cells reg_pressure] [get_bd_cells reg_time] [get_bd_cells reg_satellite] [get_bd_cells reg_longitude] [get_bd_cells reg_latitude] [get_bd_cells reg_altitude]

group_bd_cells AO [get_bd_cells concat_0] [get_bd_cells cfg_dac_pwm_2] [get_bd_cells cfg_dac_pwm_3] [get_bd_cells gen_0] [get_bd_cells gen_1] [get_bd_cells gen_2] [get_bd_cells gen_3] [get_bd_cells reset_3] [get_bd_cells cfg_dac_pwm_0] [get_bd_cells cfg_dac_pwm_1] [get_bd_cells concat_1]

