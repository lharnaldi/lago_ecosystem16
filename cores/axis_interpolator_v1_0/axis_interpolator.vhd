library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_interpolator is
  generic (
    AXIS_TDATA_WIDTH : natural  := 32;
    CNTR_WIDTH : natural  := 32
);
port (
  -- System signals
  aclk : in std_logic;
  aresetn : in std_logic;

  cfg_data : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tready : out std_logic;
  s_axis_tdata : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid : in std_logic;

  -- Master side
  m_axis_tready : in std_logic;
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid : out std_logic
);
end axis_interpolator;

architecture rtl of axis_interpolator is

  signal int_tdata_reg, int_tdata_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal int_cntr_reg, int_cntr_next: unsigned(CNTR_WIDTH-1 downto 0);
  signal int_tvalid_reg, int_tvalid_next: std_logic;

begin

  process(aclk, aresetn)
  begin
  if (aresetn = '0') then
    int_tdata_reg <= (others => '0');
    int_tvalid_reg <= '0';
    int_cntr_reg <= (others => '0');
  elsif (rising_edge(aclk)) then
    int_tdata_reg <= int_tdata_next;
    int_tvalid_reg <= int_tvalid_next;
    int_cntr_reg <= int_cntr_next;
  end if;
  end process;

  int_tdata_next <= s_axis_tdata when (s_axis_tvalid = '1') and (int_tvalid_reg = '0') else
                        int_tdata_reg;

  int_cntr_next <= int_cntr_reg + 1 when (m_axis_tready = '1') and (int_tvalid_reg = '1') and (int_cntr_reg < unsigned(cfg_data)) else
                   (others => '0') when (m_axis_tready = '1') and (int_tvalid_reg = '1') and not(int_cntr_reg < unsigned(cfg_data)) else
                   int_cntr_reg;

  int_tvalid_next <= '1' when (s_axis_tvalid = '1') and (int_tvalid_reg = '0') else
                    '0' when (m_axis_tready = '1') and (int_tvalid_reg = '1') and not(int_cntr_reg < unsigned(cfg_data)) else
                    int_tvalid_reg;

  s_axis_tready <= not(int_tvalid_reg);
  m_axis_tdata <= int_tdata_reg;
  m_axis_tvalid <= int_tvalid_reg;

end rtl;
