library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_gen is
	port(
	aclk   : in std_logic;
  freq_i : in std_logic_vector(32-1 downto 0);
	div_o  : out std_logic
);
end clk_gen;

architecture rtl of clk_gen is

signal cnt : integer := 0;
signal div_temp : std_logic := '0';
signal div_value : std_logic_vector(32-1 downto 0);

begin

div_value <= std_logic_vector(to_unsigned(125000000,32)/(unsigned(freq_i)+1)); --the +1 is to avoid zero division
process(aclk) 
begin
if rising_edge(aclk) then
  --if cnt >= unsigned(freq_i)/2 then
  if cnt >= unsigned(div_value)/2 then
    div_temp <= not(div_temp);
    cnt <= 0;
  else              
    div_temp <= div_temp;
    cnt <= cnt + 1;
  end if;
  div_o <= div_temp;
end if;
end process;

end rtl;
