library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_counter is
  generic (
    AXIS_TDATA_WIDTH : integer := 32;
    CNTR_WIDTH       : integer := 32
);
port (
  -- System signals
  aclk               : in std_logic;
  aresetn            : in std_logic;

  cfg_data           : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  -- Master side
  m_axis_tdata       : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid      : out std_logic
);
end axis_counter;

architecture rtl of axis_counter is

  signal int_cntr_reg, int_cntr_next : unsigned(CNTR_WIDTH-1 downto 0);
  signal int_enbl_reg, int_enbl_next : std_logic;

  signal int_comp_wire               : std_logic;

begin

  process(aclk)
  begin
    if(aresetn = '0') then
      int_cntr_reg <= (others => '0');
      int_enbl_reg <= '0';
    elsif (rising_edge(aclk)) then
      int_cntr_reg <= int_cntr_next;
      int_enbl_reg <= int_enbl_next;
    end if;
  end process;

  int_comp_wire <= '1' when (int_cntr_reg < unsigned(cfg_data)) else '0';

  int_enbl_next <= '1' when (int_enbl_reg = '0') and (int_comp_wire = '1') else 
                   '0' when (int_enbl_reg = '1') and (int_comp_wire = '0') else
                   int_enbl_reg;

  int_cntr_next <= int_cntr_reg + 1 when (int_enbl_reg = '1') and (int_comp_wire = '1') else
                   int_cntr_reg;

  m_axis_tdata <= std_logic_vector(resize(int_cntr_reg, m_axis_tdata'length));
  m_axis_tvalid <= int_enbl_reg;

end rtl;
