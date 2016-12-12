library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity dna_reader is
port (
  aclk 		: in std_logic;
  aresetn 	: in std_logic;

  dna_data 	: out std_logic_vector(56 downto 0)
);
end dna_reader;

architecture rtl of dna_reader is

  constant CNTR_WIDTH : integer := 16;
  constant DATA_WIDTH : integer := 57;

  signal int_enbl_reg, int_enbl_next : std_logic;
  signal int_read_reg, int_read_next: std_logic;
  signal int_shift_reg, int_shift_next : std_logic;
  signal int_cntr_reg, int_cntr_next: unsigned(CNTR_WIDTH-1 downto 0);
  signal int_data_reg, int_data_next: std_logic_vector(DATA_WIDTH-1 downto 0);
  signal int_comp_wire, int_data_wire: std_logic;

begin

  int_comp_wire <= '1' when (int_cntr_reg < 64*DATA_WIDTH) else '0';

  dna_0: DNA_PORT
   port map (
      DOUT => int_data_wire,
      CLK => int_cntr_reg(5),
      DIN => '0',    
      READ => int_read_reg,  
      SHIFT => int_shift_reg
   );

  process(aclk)
  begin
    if rising_edge(aclk) then
    if(aresetn = '0') then
      int_enbl_reg <= '0';
      int_read_reg <= '0';
      int_shift_reg <= '0';
      int_cntr_reg <= (others => '0');
      int_data_reg <= (others => '0');
    else
      int_enbl_reg <= int_enbl_next;
      int_read_reg <= int_read_next;
      int_shift_reg <= int_shift_next;
      int_cntr_reg <= int_cntr_next;
      int_data_reg <= int_data_next;
    end if;
    end if;
  end process;

  int_enbl_next <= '1' when (int_enbl_reg = '0') and (int_comp_wire = '1') else 
                   '0' when (int_comp_wire = '0') else
		     	         int_enbl_reg;

  int_read_next <= '1' when (int_enbl_reg = '0') and (int_comp_wire = '1') else
                   '0' when (int_cntr_reg(5 downto 0) = "111111") else
                   int_read_reg;

  int_data_next <= int_data_reg(DATA_WIDTH-2 downto 0) & int_data_wire when (int_cntr_reg(5 downto 0) = "111111") else
                   int_data_reg;

  int_cntr_next <= int_cntr_reg + 1 when (int_enbl_reg = '1') else int_cntr_reg;

  int_shift_next <= '0' when (int_comp_wire = '0') else 
                    '1' when (int_cntr_reg(5 downto 0) = "111111") else 
                    int_shift_reg;

  dna_data <= int_data_reg;

end rtl;
