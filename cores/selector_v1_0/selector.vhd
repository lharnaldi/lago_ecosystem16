library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity selector is
generic (
    A_WIDTH   : natural := 32;
    DIV_WIDTH : natural := 5;
    OFFSET    : natural := 26; -- Slice bit position 26 ... 1.07 s
    SCALE     : integer := -1 
);
port (
  -- System signals
  a   : in std_logic_vector(A_WIDTH-1 downto 0);
  div : in std_logic_vector(DIV_WIDTH-1 downto 0);
  s   : out std_logic
);
end selector;

architecture rtl of selector is

begin

        s <= a(OFFSET + SCALE*div);
    
end rtl;
