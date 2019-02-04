source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register:1.0 cfg_0 {
  CFG_DATA_WIDTH 160
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 160 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice. 
cell xilinx.com:ip:xlslice:1.0 slice_2 {
  DIN_WIDTH 160 DIN_FROM 55 DIN_TO 32 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice.
cell xilinx.com:ip:xlslice:1.0 slice_3 {
  DIN_WIDTH 160 DIN_FROM 87 DIN_TO 64 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice.
cell xilinx.com:ip:xlslice:1.0 slice_4 {
  DIN_WIDTH 160 DIN_FROM 119 DIN_TO 96 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

# Create xlslice. 
cell xilinx.com:ip:xlslice:1.0 slice_5 {
  DIN_WIDTH 160 DIN_FROM 151 DIN_TO 128 DOUT_WIDTH 24
} {
  Din cfg_0/cfg_data
}

#Create concatenator
cell xilinx.com:ip:xlconcat:2.1 xlconcat_0 {
  NUM_PORTS 4
} {
  dout dac_pwm_o
}
#Create PWM generator
cell labdpr:user:pwm_gen:1.0 pwm_gen_0 {
  DATA_WIDTH 24
  MAX_CNT 156
} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  cfg_i slice_2/Dout
  pwm_o xlconcat_0/In0
}

#Create PWM generator
cell labdpr:user:pwm_gen:1.0 pwm_gen_1 {
  DATA_WIDTH 24
  MAX_CNT 156
} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  cfg_i slice_3/Dout
  pwm_o xlconcat_0/In1
}

#Create PWM generator
cell labdpr:user:pwm_gen:1.0 pwm_gen_2 {
  DATA_WIDTH 24
  MAX_CNT 156
} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  cfg_i slice_4/Dout
  pwm_o xlconcat_0/In2
}

#Create PWM generator
cell labdpr:user:pwm_gen:1.0 pwm_gen_3 {
  DATA_WIDTH 24
  MAX_CNT 156
} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  cfg_i slice_5/Dout
  pwm_o xlconcat_0/In3
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

