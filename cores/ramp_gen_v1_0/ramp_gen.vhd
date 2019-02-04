library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ramp_gen is
	generic(
	  COUNT_NBITS : integer := 18;     -- number of bits of the counter
  	COUNT_MOD   : integer := 200000;		-- mod-n
		DATA_BITS   : integer := 12);			-- number of bits for the data
  port(
    aclk    : in  std_logic;
		aresetn	: in 	std_logic;
		data_i	: in 	std_logic_vector(DATA_BITS-1 downto 0);
		data_o	: out std_logic_vector(DATA_BITS-1 downto 0);
		pwm_o		: out	std_logic;
		led_o		: out std_logic);
end ramp_gen;

architecture rtl of ramp_gen is
  signal cnt_reg, cnt_next	 : std_logic_vector(COUNT_NBITS-1 downto 0);
  signal in_reg, in_next	   : std_logic_vector(DATA_BITS-1 downto 0);
  signal r_reg, r_next	     : std_logic_vector(DATA_BITS-1 downto 0);
  signal out_reg, out_next	 : std_logic_vector(DATA_BITS-1 downto 0);
	signal buff_reg, buff_next : std_logic;
	signal max_tick			       : std_logic;

begin
	-- Drive inputs
	in_next	<= data_i;

	--registers
 	process (aclk)
 	begin
    if rising_edge(aclk) then
      if (aresetn = '0') then
    	  cnt_reg 	<= (others => '0');
    	  in_reg 		<= (others => '0');
    	  out_reg 	<= (others => '0');
    	  r_reg		 	<= (others => '0');
    	  buff_reg 	<= '0';
      else
     	  cnt_reg 	<= cnt_next;
     	  r_reg 		<= r_next;
     	  buff_reg 	<= buff_next;
     	  in_reg 		<= in_next;
     	  out_reg 	<= out_next;
      end if;
    end if;
 	end process;
	--next-state logic for counter
	cnt_next	<= 	(others => '0') when unsigned(cnt_reg) = (COUNT_MOD-1) else
          			std_logic_vector(unsigned(cnt_reg) + 1);

	buff_next <= '1' when (unsigned(r_reg) < unsigned(out_reg)) else '0';          		

	r_next <= std_logic_vector(unsigned(r_reg) + 1);          		

	--output logic
	max_tick <= '1' when unsigned(cnt_reg) = (COUNT_MOD-1) else '0';

	process(max_tick, in_reg, out_reg)
	begin
		if (max_tick = '1') then
			if (unsigned(in_reg) > unsigned(out_reg)) then			
				out_next <= std_logic_vector(unsigned(out_reg) + 1);
			elsif (unsigned(in_reg) < unsigned(out_reg)) then
				out_next <= std_logic_vector(unsigned(out_reg) - 1);
			else
				out_next <= out_reg;	-- default
			end if;
		else
			out_next <= out_reg;
		end if;
	end process;
	
	--next-state logic for output
	data_o <= out_reg;
	led_o <= 	'0' when (unsigned(out_reg) = 0) else
						'1';
	pwm_o <= buff_reg;

end rtl;
