library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dp_ram_sync is
  generic(
           ADDR_WIDTH: integer := 10;
           DATA_WIDTH: integer := 32
         );
  port(
        clk     : in std_logic;
        we      : in std_logic;
        addr_a  : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        addr_b  : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        din_a   : in std_logic_vector(DATA_WIDTH-1 downto 0);
        dout_a  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        dout_b  : out std_logic_vector(DATA_WIDTH-1 downto 0)
      );
end dp_ram_sync;

architecture rtl of dp_ram_sync is

  type ram_t is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram: ram_t;

  signal addra_reg, addrb_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin
  process(clk)
  begin
    if (rising_edge(clk)) then
      if (we = '1') then
        ram(to_integer(unsigned(addr_a))) <= din_a;
      end if;
      addra_reg <= addr_a;
      addrb_reg <= addr_b;
    end if;
  end process;

  dout_a <= ram(to_integer(unsigned(addra_reg)));
  dout_b <= ram(to_integer(unsigned(addrb_reg)));

end rtl;
