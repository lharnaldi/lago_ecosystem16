library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_decimator is
  generic (
    AXIS_TDATA_WIDTH : natural  := 32;
    CNTR_WIDTH       : natural  := 32
);
port (
  -- System signals
  aclk           : in std_logic;
  aresetn        : in std_logic;

  cfg_data       : in std_logic_vector(CNTR_WIDTH-1 downto 0);

  -- Slave side
  s_axis_tready  : out std_logic;
  s_axis_tdata   : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  s_axis_tvalid  : in std_logic;

  -- Master side
  m_axis_tready  : in std_logic;
  m_axis_tdata   : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid  : out std_logic
);
end axis_decimator;

architecture rtl of axis_decimator is

  signal int_tdata_reg, int_tdata_next : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal int_cntr_reg, int_cntr_next: unsigned(CNTR_WIDTH-1 downto 0);
  signal int_tvalid_reg, int_tvalid_next: std_logic;
  signal int_tready_reg, int_tready_next: std_logic;

  signal int_comp_wire, int_tvalid_wire: std_logic;

begin

  int_comp_wire <= '1' when (int_cntr_reg < unsigned(cfg_data)) else '0';
  int_tvalid_wire <= int_tready_reg and s_axis_tvalid;

  process(aclk, aresetn)
  begin
  if (aresetn = '0') then
    int_tdata_reg <= (others => '0');
    int_tvalid_reg <= '0';
    int_tready_reg <= '0';
    int_cntr_reg <= (others => '0');
  elsif (rising_edge(aclk)) then
    int_tdata_reg <= int_tdata_next;
    int_tvalid_reg <= int_tvalid_next;
    int_tready_reg <= int_tready_next;
    int_cntr_reg <= int_cntr_next;
  end if;
  end process;


  int_tready_next <= '1' when (int_tready_reg = '0') and (int_comp_wire = '1') else
                     int_tready_reg;

  int_cntr_next <= int_cntr_reg + 1 when (int_tvalid_wire = '1') and (int_comp_wire = '1') else
                   (others => '0') when (int_tvalid_wire = '1') and (int_comp_wire = '0') else
                   int_cntr_reg;

  int_tdata_next <= s_axis_tdata when (int_tvalid_wire = '1') and (int_comp_wire = '0') else
                        int_tdata_reg;

  int_tvalid_next <= '1' when (int_tvalid_wire = '1') and (int_comp_wire = '0') else
                    '0' when (m_axis_tready = '1') and (int_tvalid_reg = '1') else
                    int_tvalid_reg;

  s_axis_tready <= int_tready_reg;
  m_axis_tdata <= int_tdata_reg;
  m_axis_tvalid <= int_tvalid_reg;

end rtl;
