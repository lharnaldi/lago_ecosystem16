-- Simple Dual-Port Block RAM with One Clock
-- Correct Modelization with a Shared Variable
-- File:simple_dual_one_clock.vhd
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity sdp_ram_oc is
  generic(
  AWIDTH : natural := 10;
  DWIDTH : natural := 32
);
  port(
        clk: in std_logic;
        ena: in std_logic;
        enb: in std_logic;
        wea: in std_logic;
        addra : in std_logic_vector(AWIDTH-1 downto 0);
        addrb : in std_logic_vector(AWIDTH-1 downto 0);
        dia: in std_logic_vector(DWIDTH-1 downto 0);
        dob: out std_logic_vector(DWIDTH-1 downto 0)
      );
end sdp_ram_oc;

architecture syn of sdp_ram_oc is

  type ram_t is array (2**AWIDTH-1 downto 0) of std_logic_vector(DWIDTH-1 downto 0);
  shared variable RAM : ram_t := (others => (others => '0'));
  signal do2 : std_logic_vector(DWIDTH-1 downto 0);

begin
  process(clk)
  begin
    if clk'event and clk = '1' then
        if wea = '1' then
          RAM(conv_integer(addra)) := dia;
        end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      do2 <= RAM(conv_integer(addrb));
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if enb = '1' then
        dob <= do2;
      end if;
    end if;
  end process;
end syn;
