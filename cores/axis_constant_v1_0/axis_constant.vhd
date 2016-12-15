library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_constant is
  generic (
  AXIS_TDATA_WIDTH: natural := 32
);
port (
  -- System signals
  aclk : in std_logic;

  cfg_data : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);

  -- Master side
  m_axis_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);
  m_axis_tvalid : out std_logic
);
end axis_constant;

architecture rtl of axis_constant is

begin
 
  m_axis_tdata <= cfg_data;
  m_axis_tvalid <= '1';

end rtl;
