library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity tdp_bram is
  generic (
            AWIDTH       : integer := 16;
            DWIDTH       : integer := 16
          );
  port (
         clka  : in std_logic;
         clkb  : in std_logic;
         ena   : in std_logic;
         enb   : in std_logic;
         wea   : in std_logic;
         addra : in std_logic_vector(AWIDTH-1 downto 0);
         addrb : in std_logic_vector(AWIDTH-1 downto 0);
         dia   : in std_logic_vector(DWIDTH-1 downto 0);
         doa   : out std_logic_vector(DWIDTH-1 downto 0);
         dob   : out std_logic_vector(DWIDTH-1 downto 0)
       );
end tdp_bram;

architecture rtl of tdp_bram is

  type ram_t is array (2**AWIDTH-1 downto 0) of std_logic_vector(DWIDTH-1 downto 0);
  shared variable RAM : ram_t := (others => (others => '0'));
  signal do1 : std_logic_vector(DWIDTH-1 downto 0);
  signal do2 : std_logic_vector(DWIDTH-1 downto 0);

begin

  process(clka)
  begin
    if rising_edge(clka) then
      if wea = '1' then
        RAM(to_integer(unsigned(addra))) := dia;
      end if;
      do1 <= RAM(to_integer(unsigned(addra)));
    end if;
  end process;

  process(clkb)
  begin
    if rising_edge(clkb) then
      do2 <= RAM(to_integer(unsigned(addrb)));
    end if;
  end process;

  process(clka)
  begin
    if rising_edge(clka) then
      if ena = '1' then
        doa <= do1;
      end if;
    end if;
  end process;

  process(clkb)
  begin
    if rising_edge(clkb) then
      if enb = '1' then
        dob <= do2;
      end if;
    end if;
  end process;

end rtl;
