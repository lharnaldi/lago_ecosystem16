library ieee;
  
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity port_selector is
generic(
  DOUT_WIDTH : integer := 32
);
port (
  cfg     : in std_logic;
  din     : in std_logic_vector(2*DOUT_WIDTH-1 downto 0);
  dout    : out std_logic_vector(DOUT_WIDTH-1 downto 0)
  );
end port_selector;

architecture rtl of port_selector is

begin

				process(cfg)
				begin
								if cfg = '1' then
												dout <= din(2*DOUT_WIDTH-1 downto DOUT_WIDTH);
								else
												dout <= din(DOUT_WIDTH-1 downto 0);
								end if;
				end process;

end rtl;
