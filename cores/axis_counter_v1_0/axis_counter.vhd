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
  m_axis_tready      : in std_logic;
  m_axis_tvalid      : out std_logic
);
end axis_counter;

architecture rtl of axis_counter is

  signal cntr_reg, cntr_next   : unsigned(CNTR_WIDTH-1 downto 0);
  signal tlast_reg, tlast_next : std_logic;
  signal comp_reg, comp_next  : std_logic;

begin

  process(aclk)
  begin
    if (rising_edge(aclk)) then
    if(aresetn = '0') then
      cntr_reg <= (others => '0');
      tlast_reg <= '0';
      comp_reg <= '0';
    else
      cntr_reg <= cntr_next;
      tlast_reg <= tlast_next;
      comp_reg <= comp_next;
    end if;
    end if;
  end process;

  tlast_next <= '1' when (cntr_reg = unsigned(cfg_data)-1) else '0';

  comp_next <= '0' when (cntr_reg = unsigned(cfg_data)) else '1';

  cntr_next <= cntr_reg + 1 when ((comp_reg = '1') and (m_axis_tready = '1')) else
               (others => '0') when (comp_reg = '0') else --reset
               cntr_reg;

  m_axis_tdata <= std_logic_vector(resize(cntr_reg, m_axis_tdata'length));
  m_axis_tlast <= tlast_reg;
  m_axis_tvalid <= comp_reg;

end rtl;
