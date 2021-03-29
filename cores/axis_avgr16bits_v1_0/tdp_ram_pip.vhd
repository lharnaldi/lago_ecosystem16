-- Block RAM with Optional Output Registers
-- File: modified from rams_pipeline.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tdp_ram_pip is
  generic (
            AWIDTH       : integer := 16;
            DWIDTH       : integer := 16
          );
  port(
        clka  : in  std_logic;
        --rsta  : in  std_logic;
        --ena   : in  std_logic;
        wea   : in  std_logic;
        addra : in  std_logic_vector(AWIDTH-1 downto 0);
        dia   : in  std_logic_vector(DWIDTH-1 downto 0);
        --doa   : out std_logic_vector(DWIDTH-1 downto 0);
        clkb  : in  std_logic;
        rstb  : in  std_logic;
        enb   : in  std_logic;
        --web   : in  std_logic;
        addrb : in  std_logic_vector(AWIDTH-1 downto 0);
        --dib   : in  std_logic_vector(DWIDTH-1 downto 0);
        dob   : out std_logic_vector(DWIDTH-1 downto 0)
      );
end tdp_ram_pip;

architecture rtl of tdp_ram_pip is
  type ram_t is array (0 to 2**AWIDTH-1) of std_logic_vector(DWIDTH-1 downto 0);
  signal ram : ram_t := (others => (others => '0')); 
  signal a_reg, a_next : std_logic_vector(DWIDTH-1 downto 0);
  signal b_reg, b_next : std_logic_vector(DWIDTH-1 downto 0);

begin

  process(clka)
  begin
    if rising_edge(clka) then
      if wea = '1' then
        ram(to_integer(unsigned(addra))) <= dia;
      end if;
    --do1 <= ram(to_integer(unsigned(addra)));
    end if;
  end process;

  --process(clka)
  --begin
  --  if rising_edge(clka) then
  --    if rsta = '1' then
  --      a_reg <= (others => '0');
  --    else
  --      a_reg <= a_next;
  --    end if;
  --  end if;
  --end process;
  ----next state logic
  --a_next <= ram(to_integer(unsigned(addra))) when ena = '1' else a_reg;
  --doa <= a_reg;

  --process(clkb)
  --begin
  --  if rising_edge(clkb) then
  --    if web = '1' then
  --      ram(to_integer(unsigned(addrb))) <= dib;
  --    end if;
  --  --do2 <= ram(to_integer(unsigned(addrb)));
  --  end if;
  --end process;

  process(clkb)
  begin
    if rising_edge(clkb) then
      if rstb = '1' then
        b_reg <= (others => '0');
      else
        b_reg <= b_next;
      end if;
    end if;
  end process;
  --next state logic
  b_next <= ram(to_integer(unsigned(addrb))) when enb = '1' else b_reg;
  dob <= b_reg;

end rtl;
