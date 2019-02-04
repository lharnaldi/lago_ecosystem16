source projects/base_system/block_design.tcl

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset:5.0 rst_0

# Create axi_cfg_register
cell labdpr:user:axi_cfg_register:1.0 cfg_0 {
  CFG_DATA_WIDTH 96
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create xlslice
cell xilinx.com:ip:xlslice:1.0 slice_1 {
  DIN_WIDTH 96 DIN_FROM 0 DIN_TO 0 DOUT_WIDTH 1
} {
  Din cfg_0/cfg_data
}

# Create xlslice. Change the frequency
cell xilinx.com:ip:xlslice:1.0 slice_2 {
  DIN_WIDTH 96 DIN_FROM 47 DIN_TO 32 DOUT_WIDTH 16
} {
  Din cfg_0/cfg_data
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 ramp_gen_0 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
  aclk ps_0/FCLK_CLK0
  aresetn slice_1/Dout
  data_i slice_2/Dout
  pwm_o dac_pwm_o
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

