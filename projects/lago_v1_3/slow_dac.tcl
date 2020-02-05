#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_0 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
	aclk /pll_0/clk_out1
  aresetn /reset_3/Dout
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_1 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
	aclk /pll_0/clk_out1
  aresetn /reset_3/Dout
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_2 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
	aclk /pll_0/clk_out1
  aresetn /reset_3/Dout
}

#Create PWM generator
cell labdpr:user:ramp_gen:1.0 gen_3 {
  COUNT_NBITS 20
  COUNT_MOD 5000
  DATA_BITS 16
} {
	aclk /pll_0/clk_out1
  aresetn /reset_3/Dout
}

