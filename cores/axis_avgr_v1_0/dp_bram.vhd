library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity dp_ram is
  generic (
            AWIDTH       : integer := 16;
            DWIDTH       : integer := 16
          );
  port ( 
         clka    : in std_logic;
         clkb    : in std_logic;
         ena     : in std_logic;
         enb     : in std_logic;
         wea     : in std_logic;
         web     : in std_logic;
         addra   : in std_logic_vector (AWIDTH-1 downto 0);
         addrb   : in std_logic_vector (AWIDTH-1 downto 0);
         dia     : in std_logic_vector (DWIDTH-1 downto 0);
         dib     : in std_logic_vector (DWIDTH-1 downto 0);
         doa     : out std_logic_vector (DWIDTH-1 downto 0);
         dob     : out std_logic_vector (DWIDTH-1 downto 0)
       );
end dp_ram;

architecture rtl of dp_ram is

  type ram_t is array (2**AWIDTH-1 downto 0) of std_logic_vector (DWIDTH-1 downto 0);
  shared variable ram : ram_t;

begin

  -- clka port.
  process (clka)
  begin
    if rising_edge(clka) then
      if (ena = '1') then
        doa <= ram(conv_integer(addra));
        if (wea = '1') then
          ram(conv_integer(addra)) := dia;
        end if;
      end if;
    end if;
  end process;

  -- clkb port.
  process (clkb)
  begin
    if rising_edge(clkb) then
      if (enb = '1') then
        dob <= ram(conv_integer(addrb));
        if (web = '1') then
          ram(conv_integer(addrb)) := dib;
        end if;
      end if;
    end if;
  end process;

end rtl;

