library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity signal_split is
generic (
      ADC_DATA_WIDTH: natural := 16;
      AXIS_TDATA_WIDTH: natural := 32
);
port (
  -- System signals
  aclk               : in std_logic;
  aresetn            : in std_logic;
  S_AXIS_tdata       : in std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);        
  S_AXIS_tvalid      : in std_logic;                               

  M_AXIS_PORT1_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);  
  M_AXIS_PORT1_tvalid: out std_logic;                         

  M_AXIS_PORT2_tdata : out std_logic_vector(AXIS_TDATA_WIDTH-1 downto 0);  
  M_AXIS_PORT2_tvalid: out std_logic                         
);
end signal_split;

architecture rtl of signal_split is
begin

end rtl;
