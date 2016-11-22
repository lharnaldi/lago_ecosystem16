library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_variable is
  generic (
  AXIS_TDATA_WIDTH: natural := 32
);
port (
  -- System signals
  aclk : in std_logic;
  aresetn : in std_logic;

  cfg_data : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  -- Master side
  m_axis_tready : in std_logic;
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid : out std_logic
);
end axis_variable;

architecture rtl of axis_variable is

  signal int_tdata_reg : std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  signal int_tvalid_reg, int_tvalid_next: std_logic;

begin

  process(aclk, aresetn)
  begin
    if(aresetn = '0') then
      int_tdata_reg <= (others => '0');
      int_tvalid_reg <= '0';
    elsif (rising_edge(aclk)) then
      int_tdata_reg <= cfg_data;
      int_tvalid_reg <= int_tvalid_next;
    end if;
  end process;

  int_tvalid_next <= '1' when (int_tdata_reg /= cfg_data) else
                     '0' when (m_axis_tready = '1') and (int_tvalid_reg = '1') else
                     int_tvalid_reg;        

  m_axis_tdata <= int_tdata_reg;
  m_axis_tvalid <= int_tvalid_reg;

end rtl;
