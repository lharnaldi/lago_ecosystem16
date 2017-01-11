library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_counter is
  generic (
    AXIS_TDATA_WIDTH : natural := 32;
    CNTR_WIDTH       : natural := 32
);
port (
  -- System signals
  aclk               : in std_logic;
  aresetn            : in std_logic;

  cfg_data           : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  -- Master side
  m_axis_tdata       : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tlast       : out std_logic;
  m_axis_tvalid      : out std_logic
);
end axis_counter;

architecture rtl of axis_counter is

  signal cntr_reg, cntr_next : unsigned(CNTR_WIDTH-1 downto 0);
  signal int_comp_wire               : std_logic;
  signal int_tlast_wire              : std_logic;

begin

  process(aclk)
  begin
    if (rising_edge(aclk)) then
    if(aresetn = '0') then
      cntr_reg <= (others => '0');
    else
      cntr_reg <= cntr_next;
    end if;
    end if;
  end process;

  int_tlast_wire <= '1' when (cntr_reg = unsigned(cfg_data)-1) else '0';

  int_comp_wire <= '1' when (cntr_reg < unsigned(cfg_data)) else '0';

  cntr_next <= cntr_reg + 1 when (int_comp_wire = '1') else
               (others => '0') when (int_comp_wire = '0') else --reset
               cntr_reg;

  m_axis_tdata <= std_logic_vector(resize(cntr_reg, m_axis_tdata'length));
  m_axis_tlast <= int_tlast_wire;
  m_axis_tvalid <= int_comp_wire;

end rtl;
