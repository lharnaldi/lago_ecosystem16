source projects/base_system/block_design.tcl

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

# Delete input/output port
delete_bd_objs [get_bd_ports exp_p_tri_io]
delete_bd_objs [get_bd_ports exp_n_tri_io]

# Create input port
create_bd_port -dir I -from 0 -to 0 exp_p_tri_io

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

# Create xlslice for reset fifo, pps_gen and trigger modules. off=0
cell xilinx.com:ip:xlslice:1.0 reset_0 {
  DIN_WIDTH 1024 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset tlast_gen. off=0
cell xilinx.com:ip:xlslice:1.0 reset_1 {
  DIN_WIDTH 1024 DIN_FROM 1 DIN_TO 1 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for reset conv_0 and writer_0. off=0
cell xilinx.com:ip:xlslice:1.0 reset_2 {
  DIN_WIDTH 1024 DIN_FROM 2 DIN_TO 2 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the # of samples to get. off=1
cell xilinx.com:ip:xlslice:1.0 nsamples {
  DIN_WIDTH 1024 DIN_FROM 63 DIN_TO 32 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_a. off=2
cell xilinx.com:ip:xlslice:1.0 trig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 95 DIN_TO 64 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the trigger_lvl_b. off=3
cell xilinx.com:ip:xlslice:1.0 trig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 127 DIN_TO 96 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_a. off=4
cell xilinx.com:ip:xlslice:1.0 subtrig_lvl_a {
  DIN_WIDTH 1024 DIN_FROM 159 DIN_TO 128 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for set the subtrigger_lvl_b. off=5
cell xilinx.com:ip:xlslice:1.0 subtrig_lvl_b {
  DIN_WIDTH 1024 DIN_FROM 191 DIN_TO 160 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the temperature data. off=6
cell xilinx.com:ip:xlslice:1.0 reg_temp {
  DIN_WIDTH 1024 DIN_FROM 223 DIN_TO 192 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the pressure data. off=7
cell xilinx.com:ip:xlslice:1.0 reg_pressure {
  DIN_WIDTH 1024 DIN_FROM 255 DIN_TO 224 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the time data. off=8
cell xilinx.com:ip:xlslice:1.0 reg_time {
  DIN_WIDTH 1024 DIN_FROM 287 DIN_TO 256 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the date data. off=9
cell xilinx.com:ip:xlslice:1.0 reg_date {
  DIN_WIDTH 1024 DIN_FROM 319 DIN_TO 288 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the latitude data. off=10
cell xilinx.com:ip:xlslice:1.0 reg_latitude {
  DIN_WIDTH 1024 DIN_FROM 351 DIN_TO 320 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the longitude data. off=11
cell xilinx.com:ip:xlslice:1.0 reg_longitude {
  DIN_WIDTH 1024 DIN_FROM 383 DIN_TO 352 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the altitude data. off=12
cell xilinx.com:ip:xlslice:1.0 reg_altitude {
  DIN_WIDTH 1024 DIN_FROM 415 DIN_TO 384 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the satellite data. off=13
cell xilinx.com:ip:xlslice:1.0 reg_satellite {
  DIN_WIDTH 1024 DIN_FROM 447 DIN_TO 416 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler a. off=14
cell xilinx.com:ip:xlslice:1.0 reg_trig_scaler_a {
  DIN_WIDTH 1024 DIN_FROM 479 DIN_TO 448 DOUT_WIDTH 32
} {
  Din cfg_0/cfg_data
}

# Create xlslice for the trigger scaler b. off=15
cell xilinx.com:ip:xlslice:1.0 reg_trig_scaler_b {
  DIN_WIDTH 1024 DIN_FROM 511 DIN_TO 480 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_0

# Create xlconstant
cell xilinx.com:ip:xlconstant:1.1 const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create xlslice for set the gpsen_i input
cell xilinx.com:ip:xlslice:1.0 gpsen {
  DIN_WIDTH 1024 DIN_FROM 4 DIN_TO 4 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create axis_clock_converter
cell xilinx.com:ip:axis_clock_converter:1.1 fifo_0 {} {
  S_AXIS adc_0/M_AXIS
  s_axis_aclk pll_0/clk_out1
  s_axis_aresetn const_0/dout
  m_axis_aclk ps_0/FCLK_CLK0
  m_axis_aresetn reset_0/Dout
}

#Create concatenator
cell xilinx.com:ip:xlconcat:2.1 xlconcat_0 {
  NUM_PORTS 6
} {
  dout led_o
}

# Create pps generator
cell labdpr:user:pps_gen:1.0 pps_0 {} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
  gpsen_i gpsen/Dout
  pps_i exp_p_tri_io
  pps_gps_led_o xlconcat_0/In0
  false_pps_led_o xlconcat_0/In1
}

# Create lago trigger
cell labdpr:user:axis_lago_trigger:1.2 trigger_0 {
  DATA_ARRAY_LENGTH 32
} {
  S_AXIS fifo_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_0/Dout
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

# Create axi_intc
cell xilinx.com:ip:axi_intc:4.1 axi_intc_0 {
  C_IRQ_CONNECTION 1
  C_S_AXI_ACLK_FREQ_MHZ 125
  C_PROCESSOR_CLK_FREQ_MHZ 125
} {
  irq ps_0/IRQ_F2P
  intr pps_0/int_o
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins axi_intc_0/s_axi]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_axi_intc_0_Reg]

# Create the tlast generator
cell labdpr:user:axis_tlast_gen:1.0 tlast_gen_0 {
  AXIS_TDATA_WIDTH 32
  PKT_CNTR_BITS 32
} {
  S_AXIS trigger_0/M_AXIS
  pkt_length nsamples/Dout
  aclk ps_0/FCLK_CLK0
  aresetn reset_1/Dout
}

# Create axis_dwidth_converter
cell xilinx.com:ip:axis_dwidth_converter:1.1 conv_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 4
  M_TDATA_NUM_BYTES 8
} {
  S_AXIS tlast_gen_0/M_AXIS
  aclk ps_0/FCLK_CLK0
  aresetn reset_2/Dout
}

# Create axis_ram_writer
cell labdpr:user:axis_ram_writer:1.0 writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS conv_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk ps_0/FCLK_CLK0
  aresetn reset_2/Dout
}

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]

# Create axi_sts_register
cell labdpr:user:axi_sts_register:1.0 sts_0 {
  STS_DATA_WIDTH 32
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data writer_0/sts_data
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40002000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

#Now all related to the DAC PWM
# Create xlslice. off=0
cell xilinx.com:ip:xlslice:1.0 reset_3 {
  DIN_WIDTH 1024 DIN_FROM 3 DIN_TO 3 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice. off=16 
cell xilinx.com:ip:xlslice:1.0 cfg_dac_pwm_0 {
  DIN_WIDTH 1024 DIN_FROM 543 DIN_TO 512 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=17
cell xilinx.com:ip:xlslice:1.0 cfg_dac_pwm_1 {
  DIN_WIDTH 1024 DIN_FROM 575 DIN_TO 544 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=18
cell xilinx.com:ip:xlslice:1.0 cfg_dac_pwm_2 {
  DIN_WIDTH 1024 DIN_FROM 607 DIN_TO 576 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

# Create xlslice.. off=19 
cell xilinx.com:ip:xlslice:1.0 cfg_dac_pwm_3 {
  DIN_WIDTH 1024 DIN_FROM 639 DIN_TO 608 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

#Create concatenator
cell xilinx.com:ip:xlconcat:2.1 xlconcat_1 {
  NUM_PORTS 4
} {
  dout dac_pwm_o
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_0 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_3/Dout
  data_i cfg_dac_pwm_0/Dout
  pwm_o xlconcat_1/In0
  led_o xlconcat_0/In2
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_1 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_3/Dout
  data_i cfg_dac_pwm_1/Dout
  pwm_o xlconcat_1/In1
  led_o xlconcat_0/In3
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_2 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_3/Dout
  data_i cfg_dac_pwm_2/Dout
  pwm_o xlconcat_1/In2
  led_o xlconcat_0/In4
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_3 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk ps_0/FCLK_CLK0
  aresetn reset_3/Dout
  data_i cfg_dac_pwm_3/Dout
  pwm_o xlconcat_1/In3
  led_o xlconcat_0/In5
}

group_bd_cells Fast_ADC [get_bd_cells reg_trig_scaler_a] [get_bd_cell reg_trig_scaler_b] [get_bd_cells reg_date] [get_bd_cells tlast_gen_0] [get_bd_cells reset_0] [get_bd_cells subtrig_lvl_a] [get_bd_cells subtrig_lvl_b] [get_bd_cells pps_0] [get_bd_cells pll_0] [get_bd_cells gpsen] [get_bd_cells conv_0] [get_bd_cells reset_1] [get_bd_cells trig_lvl_a] [get_bd_cells const_0] [get_bd_cells const_1] [get_bd_cells trig_lvl_b] [get_bd_cells fifo_0] [get_bd_cells reset_2] [get_bd_cells writer_0] [get_bd_cells nsamples] [get_bd_cells trigger_0] [get_bd_cells adc_0] [get_bd_cells axi_intc_0] [get_bd_cells reg_temp] [get_bd_cells reg_pressure] [get_bd_cells reg_time] [get_bd_cells reg_satellite] [get_bd_cells reg_longitude] [get_bd_cells reg_latitude] [get_bd_cells reg_altitude]

group_bd_cells Analog_Output [get_bd_cells cfg_dac_pwm_2] [get_bd_cells cfg_dac_pwm_3] [get_bd_cells gen_0] [get_bd_cells gen_1] [get_bd_cells gen_2] [get_bd_cells gen_3] [get_bd_cells reset_3] [get_bd_cells cfg_dac_pwm_0] [get_bd_cells cfg_dac_pwm_1] [get_bd_cells xlconcat_1]

#XADC related
# Create xadc
cell xilinx.com:ip:xadc_wiz:3.3 xadc_wiz_0 {
  XADC_STARUP_SELECTION channel_sequencer
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

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins xadc_wiz_0/s_axi_lite]

set_property range 4K [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]
set_property offset 0x40003000 [get_bd_addr_segs {ps_0/Data/SEG_xadc_wiz_0_Reg}]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
