library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity op_ram_sync is
  generic(
           ADDR_WIDTH: integer:=10;
           DATA_WIDTH: integer:=32
         );
  port(
        clk    : in std_logic;
        we      : in std_logic;
        addr    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        din     : in std_logic_vector(DATA_WIDTH-1 downto 0);
        dout    : out std_logic_vector(DATA_WIDTH-1 downto 0)
      );
end op_ram_sync;

architecture rtl of op_ram_sync is

  type ram_t is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal ram: ram_t;

  signal addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin

  process(clk)
  begin
    if (rising_edge(clk)) then
        if (we = '1') then
          ram(to_integer(unsigned(addr))) <= din;
        end if;
        addr_reg <= addr;
      end if;
  end process;

  dout <= ram(to_integer(unsigned(addr_reg)));
end rtl;
