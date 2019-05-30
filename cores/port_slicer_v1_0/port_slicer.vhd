library ieee;
  
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity port_slicer is
generic(
  DIN_WIDTH : integer := 32;
  DIN_FROM  : integer := 31;
  DIN_TO    : integer := 0
);
port (
  din     : in std_logic_vector(DIN_WIDTH-1 downto 0);
  dout    : out std_logic_vector(DIN_FROM-DIN_TO downto 0)
  );
end port_slicer;

architecture rtl of port_slicer is

begin
  dout <= din(DIN_FROM downto DIN_TO);

end rtl;
